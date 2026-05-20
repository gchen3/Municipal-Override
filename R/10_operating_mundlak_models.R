source(file.path("R", "00_config.R"))
load_required_packages(c("dplyr", "tidyr", "purrr", "haven", "MASS", "sandwich", "fixest", "modelsummary", "readr"))
make_output_dirs()

if (!file.exists(file.path(paths$intermediate, "data_for_regression.rds"))) {
  source(file.path("R", "02_build_regression_data.R"))
}

data_for_regression <- readRDS(file.path(paths$intermediate, "data_for_regression.rds"))

override_files <- c(
  "override_override.dta",
  "override_capital.dta",
  "override_debt.dta",
  "override_stable.dta"
)

operating_counts <- purrr::map_dfr(
  data_65_file(override_files),
  haven::read_dta
) |>
  dplyr::mutate(year = FiscalYear) |>
  dplyr::filter(Override == "operating") |>
  dplyr::group_by(code, year) |>
  dplyr::summarise(
    oper_attempt_count = dplyr::n(),
    oper_success_count = sum(WinLoss == "WIN", na.rm = TRUE),
    oper_failure_count = sum(WinLoss == "LOSS", na.rm = TRUE),
    oper_yes_votes = sum(YesVotes, na.rm = TRUE),
    oper_total_votes = sum(YesVotes + NoVotes, na.rm = TRUE),
    oper_yes_vote_percent = dplyr::if_else(
      oper_total_votes > 0,
      100 * oper_yes_votes / oper_total_votes,
      NA_real_
    ),
    .groups = "drop"
  ) |>
  dplyr::mutate(year = year + 1)

operating_count_panel <- tidyr::expand_grid(
  code = sort(unique(data_for_regression$code)),
  year = (min(data_for_regression$year, na.rm = TRUE) - 2L):max(data_for_regression$year, na.rm = TRUE)
) |>
  dplyr::left_join(operating_counts, by = c("code", "year")) |>
  dplyr::mutate(
    dplyr::across(
      c(oper_attempt_count, oper_success_count, oper_failure_count),
      ~ tidyr::replace_na(.x, 0)
    )
  ) |>
  dplyr::arrange(code, year) |>
  dplyr::group_by(code) |>
  dplyr::mutate(
    l1_oper_attempt_count = lag_panel(oper_attempt_count, year, 1),
    l2_oper_attempt_count = lag_panel(oper_attempt_count, year, 2),
    l1_oper_success_count = lag_panel(oper_success_count, year, 1),
    l2_oper_success_count = lag_panel(oper_success_count, year, 2),
    l1_oper_failure_count = lag_panel(oper_failure_count, year, 1),
    l2_oper_failure_count = lag_panel(oper_failure_count, year, 2),
    oper_attempt_cumu_3yr = l2_oper_attempt_count + l1_oper_attempt_count + oper_attempt_count,
    oper_success_cumu_3yr = l2_oper_success_count + l1_oper_success_count + oper_success_count,
    oper_failure_cumu_3yr = l2_oper_failure_count + l1_oper_failure_count + oper_failure_count
  ) |>
  dplyr::ungroup() |>
  dplyr::filter(year >= min(data_for_regression$year, na.rm = TRUE)) |>
  dplyr::select(
    code, year,
    oper_yes_vote_percent,
    oper_attempt_count, oper_success_count, oper_failure_count,
    oper_attempt_cumu_3yr, oper_success_cumu_3yr, oper_failure_cumu_3yr
  )

data_for_regression <- data_for_regression |>
  dplyr::left_join(operating_count_panel, by = c("code", "year"))

ordered_outcome <- "MOO_ordered"
vote_share_outcome <- "oper_yes_vote_percent"

controls <- c(
  "logpopu", "debtbudg", "unemploy", "revstab", "revperca",
  "excessperca", "unabsorbedratio", "balance"
)

operating_terms <- c(
  attempt = "oper_binary",
  success = "oper_binary_win",
  failure = "oper_binary_fail"
)

operating_vote_share_terms <- c(
  attempt_count = "oper_attempt_count",
  success_count = "oper_success_count",
  failure_count = "oper_failure_count",
  attempt_cumu_3yr = "oper_attempt_cumu_3yr",
  success_cumu_3yr = "oper_success_cumu_3yr",
  failure_cumu_3yr = "oper_failure_cumu_3yr"
)

active_variable_labels <- c(
  variable_labels,
  oper_binary = "Override attempt",
  oper_binary_win = "Successful override",
  oper_binary_fail = "Failed override",
  oper_yes_vote_percent = "Yes vote percentage",
  oper_attempt_count = "Override attempts (count)",
  oper_success_count = "Successful overrides (count)",
  oper_failure_count = "Failed overrides (count)",
  oper_attempt_cumu_3yr = "3-year cumulative override attempts",
  oper_success_cumu_3yr = "3-year cumulative successful overrides",
  oper_failure_cumu_3yr = "3-year cumulative failed overrides"
)

term_variables <- function(terms) {
  unique(all.vars(stats::as.formula(paste("~", paste(terms, collapse = " + ")))))
}

available_con_terms <- function(main_terms, controls_used = controls) {
  candidates <- c(term_variables(main_terms), controls_used)
  con_candidates <- paste0(candidates, "con")
  unique(con_candidates[con_candidates %in% names(data_for_regression)])
}

ordered_mundlak_formula <- function(main_terms, controls_used = controls) {
  rhs_formula(
    ordered_outcome,
    c(main_terms, controls_used, available_con_terms(main_terms, controls_used)),
    include_year = TRUE
  )
}

vote_share_fe_formula <- function(main_terms, controls_used = controls) {
  fe_formula(vote_share_outcome, c(main_terms, controls_used))
}

fit_operating_ordered <- function(main_terms, controls_used = controls) {
  fit_ordered_probit(
    ordered_mundlak_formula(main_terms, controls_used),
    data_for_regression
  )
}

fit_operating_vote_share <- function(main_terms, controls_used = controls) {
  fit_fe_lm(
    vote_share_fe_formula(main_terms, controls_used),
    data_for_regression
  )
}

operating_moodys_main_fits <- purrr::map(
  operating_terms,
  fit_operating_ordered
)

operating_vote_share_main_fits <- purrr::map(
  operating_vote_share_terms,
  fit_operating_vote_share
)

operating_mundlak_formulas <- list(
  moodys_main = purrr::map(operating_terms, ordered_mundlak_formula),
  vote_share_main = purrr::map(operating_vote_share_terms, vote_share_fe_formula)
)

active_operating_models <- list(
  moodys_main = operating_moodys_main_fits,
  vote_share_main = operating_vote_share_main_fits
)

saveRDS(
  list(
    fits = active_operating_models,
    formulas = operating_mundlak_formulas,
    outcomes = c(ordered_outcome, vote_share_outcome),
    controls = controls,
    operating_terms = operating_terms,
    operating_vote_share_terms = operating_vote_share_terms,
    mundlak_terms = list(
      main = purrr::map(operating_terms, available_con_terms)
    )
  ),
  file.path(paths$intermediate, "active_operating_mundlak_models.rds")
)

write_active_model_table <- function(fits, file_name, title) {
  models <- lapply(fits, `[[`, "model")
  vcovs <- lapply(fits, `[[`, "vcov")
  names(models) <- names(fits)
  names(vcovs) <- names(fits)

  modelsummary::modelsummary(
    models,
    vcov = vcovs,
    stars = TRUE,
    title = title,
    coef_rename = active_variable_labels,
    gof_omit = "AIC|BIC|Log.Lik.|RMSE",
    output = file.path(paths$tables, file_name)
  )
}

write_active_model_table(
  operating_moodys_main_fits,
  "active_operating_moodys_main.html",
  "Active Models: Overrides and Moody's Ratings"
)

write_active_model_table(
  operating_vote_share_main_fits,
  "active_operating_vote_share_main.html",
  "Active Models: Override Frequency and Yes Vote Share"
)
