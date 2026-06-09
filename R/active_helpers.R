override_source_files <- c(
  "override_override.dta",
  "override_capital.dta",
  "override_debt.dta",
  "override_stable.dta"
)

active_controls <- c(
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

operating_moodys_frequency_terms <- c(
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

active_event_window <- 2L
active_event_times <- -active_event_window:active_event_window

operating_event_definitions <- tibble::tribble(
  ~event_type, ~event_variable, ~event_label, ~file_stub,
  "operating_attempt", "oper_attempt_event", "Operating Override Attempt", "oper_attempt",
  "operating_success", "oper_success_event", "Successful Operating Override", "oper_success",
  "operating_failure", "oper_failure_event", "Failed Operating Override", "oper_failure"
)

event_table_labels <- c(
  operating_attempt = "Attempt",
  operating_success = "Success",
  operating_failure = "Failure"
)

event_plot_labels <- c(
  operating_attempt = "Override Attempt",
  operating_success = "Successful Overrides",
  operating_failure = "Failed Overrides"
)

did_outcome_labels <- c(
  rating_downgrade = "Downgrade",
  rating_upgrade = "Upgrade"
)

event_study_files <- c(
  operating_attempt = "northeast_event_study_operating_attempt.png",
  operating_success = "northeast_event_study_operating_success.png",
  operating_failure = "northeast_event_study_operating_failure.png"
)

repeated_event_count_metrics <- c(
  focal_event_years = "Focal event years",
  municipalities_with_focal_event = "Event municipalities",
  clean_treatment_events = "Clean events",
  clean_treated_municipalities = "Clean municipalities"
)

repeated_event_control_metrics <- c(
  control_event_municipality_pairs = "Window-clean control pairs",
  unique_control_municipalities = "Window-clean control municipalities"
)

override_amount_years <- 2010:2025

did_binary_outcomes <- c("rating_downgrade", "rating_upgrade")

stars <- function(p_value) {
  dplyr::case_when(
    is.na(p_value) ~ "",
    p_value < 0.01 ~ "***",
    p_value < 0.05 ~ "**",
    p_value < 0.10 ~ "*",
    TRUE ~ ""
  )
}

fmt_num <- function(x, digits = 3) {
  x <- ifelse(abs(x) < 0.5 * 10^-digits, 0, x)
  ifelse(is.na(x), "", formatC(x, format = "f", digits = digits))
}

fmt_int <- function(x) {
  formatC(as.integer(round(x)), format = "d", big.mark = ",")
}

write_tex <- function(file_name, lines) {
  writeLines(lines, file.path(paths$tables, file_name), useBytes = TRUE)
}

cell_with_se <- function(estimate, std_error, p_value) {
  paste0(fmt_num(estimate), stars(p_value), " (", fmt_num(std_error), ")")
}

coef_row <- function(fit, term) {
  estimate <- unname(stats::coef(fit$model)[[term]])
  std_error <- sqrt(diag(fit$vcov))[[term]]
  p_value <- 2 * stats::pnorm(abs(estimate / std_error), lower.tail = FALSE)

  dplyr::tibble(
    estimate = estimate,
    std_error = std_error,
    p_value = p_value,
    nobs = nrow(fit$data),
    n_municipalities = dplyr::n_distinct(fit$data$code)
  )
}

add_rating_change_outcomes <- function(data, rating_var = "MOO_num", reference_year = -1L) {
  data |>
    dplyr::group_by(stack_id, code) |>
    dplyr::mutate(
      baseline_moo_num = .data[[rating_var]][rel_year == reference_year][1],
      rating_downgrade = dplyr::if_else(
        !is.na(.data[[rating_var]]) & !is.na(baseline_moo_num),
        as.numeric(.data[[rating_var]] < baseline_moo_num),
        NA_real_
      ),
      rating_upgrade = dplyr::if_else(
        !is.na(.data[[rating_var]]) & !is.na(baseline_moo_num),
        as.numeric(.data[[rating_var]] > baseline_moo_num),
        NA_real_
      )
    ) |>
    dplyr::ungroup()
}

did_event_formula <- function(
    outcome,
    fixed_effects = "stack_id^code + stack_id^year",
    covariates = character()) {
  rhs <- "i(rel_year, treated_event, ref = -1)"
  if (length(covariates) > 0) {
    rhs <- paste(rhs, paste(covariates, collapse = " + "), sep = " + ")
  }

  stats::as.formula(paste0(outcome, " ~ ", rhs, " | ", fixed_effects))
}

fit_binary_did <- function(data, outcome, formula, model_name) {
  required_vars <- unique(c(all.vars(formula), "code"))
  df <- data |>
    tidyr::drop_na(dplyr::all_of(required_vars))

  fit_result <- tryCatch(
    list(
      model = fixest::feols(formula, data = df, vcov = ~ code),
      error_message = NA_character_
    ),
    error = function(e) {
      list(
        model = NULL,
        error_message = conditionMessage(e)
      )
    }
  )

  list(
    outcome = outcome,
    model_name = model_name,
    model = fit_result$model,
    model_failed = is.null(fit_result$model),
    error_message = fit_result$error_message,
    nobs = nrow(df),
    n_municipalities = dplyr::n_distinct(df$code),
    n_stacks = dplyr::n_distinct(df$stack_id)
  )
}

coefficient_table <- function(model) {
  if (is.null(model)) {
    return(tibble::tibble())
  }

  table <- as.data.frame(fixest::coeftable(model))
  table$term <- rownames(table)
  table |>
    dplyr::as_tibble() |>
    dplyr::rename(
      estimate = Estimate,
      std_error = `Std. Error`,
      p_value = `Pr(>|t|)`
    )
}

extract_event_estimates <- function(fit, event_type, control_pool) {
  base_row <- tibble::tibble(
    event_type = event_type,
    control_pool = control_pool,
    outcome = fit$outcome,
    model = fit$model_name,
    event_time = -1L,
    term = "reference",
    estimate = 0,
    std_error = NA_real_,
    p_value = NA_real_,
    ci_lower = NA_real_,
    ci_upper = NA_real_,
    nobs = fit$nobs,
    n_municipalities = fit$n_municipalities,
    n_stacks = fit$n_stacks,
    model_failed = isTRUE(fit$model_failed),
    error_message = fit$error_message
  )

  if (is.null(fit$model)) {
    return(base_row)
  }

  estimates <- coefficient_table(fit$model) |>
    dplyr::filter(grepl("rel_year::", term), grepl("treated_event", term)) |>
    dplyr::mutate(
      event_type = event_type,
      control_pool = control_pool,
      outcome = fit$outcome,
      model = fit$model_name,
      event_time = as.integer(sub(".*rel_year::(-?[0-9]+).*", "\\1", term)),
      ci_lower = estimate - stats::qnorm(0.975) * std_error,
      ci_upper = estimate + stats::qnorm(0.975) * std_error,
      nobs = fit$nobs,
      n_municipalities = fit$n_municipalities,
      n_stacks = fit$n_stacks,
      model_failed = isTRUE(fit$model_failed),
      error_message = fit$error_message,
      .before = term
    ) |>
    dplyr::select(
      event_type, control_pool, outcome, model, event_time, term, estimate,
      std_error, p_value, ci_lower, ci_upper, nobs, n_municipalities, n_stacks,
      model_failed, error_message
    )

  dplyr::bind_rows(base_row, estimates) |>
    dplyr::arrange(event_type, control_pool, outcome, model, event_time)
}
