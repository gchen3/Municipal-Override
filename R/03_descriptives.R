source(file.path("R", "00_config.R"))
load_required_packages(c("dplyr", "tidyr", "gt", "readr"))
make_output_dirs()

if (!file.exists(file.path(paths$intermediate, "data_for_regression.rds"))) {
  source(file.path("R", "02_build_regression_data.R"))
}

data_for_regression <- readRDS(file.path(paths$intermediate, "data_for_regression.rds"))

core_model_vars <- c(
  "MOO_num", "binaryover", "binarysucc", "binaryfail", "num_attempt",
  "num_success", "num_fail", "over_cumu_3yr", "amount_all", "amount_win",
  "logpopu", "debtbudg", "unemploy", "revstab", "revperca", "excessperca",
  "unabsorbedratio", "balance"
)

model_sample <- data_for_regression |>
  dplyr::filter(dplyr::if_all(dplyr::all_of(intersect(core_model_vars, names(data_for_regression))), ~ !is.na(.x)))

descriptives <- model_sample |>
  dplyr::summarise(
    dplyr::across(
      dplyr::all_of(intersect(core_model_vars, names(model_sample))),
      list(
        n = ~ sum(!is.na(.x)),
        mean = ~ mean(.x, na.rm = TRUE),
        sd = ~ stats::sd(.x, na.rm = TRUE),
        min = ~ min(.x, na.rm = TRUE),
        max = ~ max(.x, na.rm = TRUE)
      ),
      .names = "{.col}_{.fn}"
    )
  ) |>
  tidyr::pivot_longer(
    dplyr::everything(),
    names_to = c("variable", ".value"),
    names_pattern = "^(.*)_(n|mean|sd|min|max)$"
  ) |>
  dplyr::mutate(label = dplyr::recode(variable, !!!variable_labels, .default = variable)) |>
  dplyr::select(label, variable, n, mean, sd, min, max)

credit_rating_observations <- data_for_regression |>
  dplyr::summarise(
    municipalities = dplyr::n_distinct(code),
    municipalities_with_moody = dplyr::n_distinct(code[!is.na(MOO_num)]),
    municipalities_with_override = dplyr::n_distinct(code[binaryover == 1]),
    years = dplyr::n_distinct(year),
    moody_observations = sum(!is.na(MOO_num)),
    sp_observations = sum(!is.na(SP))
  )

credit_rating_by_year <- data_for_regression |>
  dplyr::group_by(year) |>
  dplyr::summarise(
    moody_observations = sum(!is.na(MOO_num)),
    sp_observations = sum(!is.na(SP)),
    override_observations = sum(binaryover == 1, na.rm = TRUE),
    .groups = "drop"
  )

readr::write_csv(descriptives, file.path(paths$tables, "appendix_A2_descriptives.csv"))
readr::write_csv(credit_rating_observations, file.path(paths$tables, "appendix_A1_credit_rating_observations.csv"))
readr::write_csv(credit_rating_by_year, file.path(paths$tables, "appendix_A1_credit_rating_by_year.csv"))

descriptives |>
  gt::gt() |>
  gt::fmt_number(columns = c(mean, sd, min, max), decimals = 2) |>
  gt::tab_header(title = "Appendix Table A2. Descriptive Statistics") |>
  suppressWarnings(gt::gtsave(file.path(paths$tables, "appendix_A2_descriptives.html")))
