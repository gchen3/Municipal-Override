source(file.path("R", "00_config.R"))
load_required_packages(c("dplyr", "tidyr", "purrr", "fixest", "readr"))
make_output_dirs()
source(file.path("R", "active_helpers.R"))
source(file.path("R", "stacked_did_helpers.R"))

if (!file.exists(file.path(paths$intermediate, "active_operating_repeated_event_data.rds"))) {
  source(file.path("R", "11_build_operating_repeated_event_data.R"))
}

repeated_event_data <- readRDS(
  file.path(paths$intermediate, "active_operating_repeated_event_data.rds")
)

success_data <- build_cumulative_stacked_data(
  repeated_event_data$operating_success$stack_window_clean,
  repeated_event_data$operating_success$events,
  "failures_in_window"
) |>
  dplyr::mutate(event_kind = "success", is_success = 1)

failure_data <- build_cumulative_stacked_data(
  repeated_event_data$operating_failure$stack_window_clean,
  repeated_event_data$operating_failure$events,
  "successes_in_window"
) |>
  dplyr::mutate(event_kind = "failure", is_success = 0)

pooled_data <- dplyr::bind_rows(success_data, failure_data)

extract_term <- function(fit, term) {
  if (inherits(fit, "error") || is.null(fit$model)) {
    return(tibble::tibble(
      estimate = NA_real_, std_error = NA_real_, p_value = NA_real_,
      nobs = 0L, n_clusters = 0L, n_stacks = 0L
    ))
  }
  coefs <- stats::coef(fit$model)
  nobs <- nrow(fit$data)
  n_clusters <- dplyr::n_distinct(fit$data$code)
  n_stacks <- dplyr::n_distinct(fit$data$stack_id)
  if (!term %in% names(coefs)) {
    return(tibble::tibble(
      estimate = NA_real_, std_error = NA_real_, p_value = NA_real_,
      nobs = nobs, n_clusters = n_clusters, n_stacks = n_stacks
    ))
  }
  estimate <- unname(coefs[[term]])
  std_error <- sqrt(diag(fit$vcov))[[term]]
  tibble::tibble(
    estimate = estimate,
    std_error = std_error,
    p_value = 2 * stats::pnorm(abs(estimate / std_error), lower.tail = FALSE),
    nobs = nobs, n_clusters = n_clusters, n_stacks = n_stacks
  )
}

safe_fit <- function(formula, data) {
  tryCatch(fit_fe_lm(formula, data), error = function(e) e)
}

# Both specs: baseline-differencing + stack FE only, and the same plus the
# active controls (measured at the election fiscal year, rel_year == -1).
stacked_formula <- function(outcome, rhs_extra = character(), use_controls = FALSE) {
  terms <- c("treated_event", rhs_extra)
  if (use_controls) terms <- c(terms, active_controls)
  stats::as.formula(paste(outcome, "~", paste(terms, collapse = " + "), "| stack_id"))
}

specs <- c(no_controls = FALSE, with_controls = TRUE)

# Run all stages: (2a) separate success/failure-vs-no-override effects, (2b) the
# pooled any-override-vs-no-override effect (success and failure events both
# treated, no interaction), and (2c) the pooled success-minus-failure bridge.
run_did_models <- function(success_data, failure_data, pooled_data) {
  main_results <- purrr::imap_dfr(specs, function(use_controls, spec_name) {
    purrr::map_dfr(c("success", "failure"), function(kind) {
      data_kind <- if (kind == "success") success_data else failure_data
      purrr::map_dfr(cumulative_stacked_outcomes, function(outcome) {
        formula <- stacked_formula(outcome, use_controls = use_controls)
        extract_term(safe_fit(formula, data_kind), "treated_event") |>
          dplyr::mutate(spec = spec_name, contrast = paste0(kind, "_vs_no_override"),
                        outcome = outcome, .before = 1)
      })
    })
  })
  any_results <- purrr::imap_dfr(specs, function(use_controls, spec_name) {
    purrr::map_dfr(cumulative_stacked_outcomes, function(outcome) {
      formula <- stacked_formula(outcome, use_controls = use_controls)
      extract_term(safe_fit(formula, pooled_data), "treated_event") |>
        dplyr::mutate(spec = spec_name, contrast = "any_override_vs_no_override",
                      outcome = outcome, .before = 1)
    })
  })
  bridge_results <- purrr::imap_dfr(specs, function(use_controls, spec_name) {
    purrr::map_dfr(cumulative_stacked_outcomes, function(outcome) {
      formula <- stacked_formula(outcome, rhs_extra = "treated_event:is_success", use_controls = use_controls)
      extract_term(safe_fit(formula, pooled_data), "treated_event:is_success") |>
        dplyr::mutate(spec = spec_name, contrast = "success_minus_failure", outcome = outcome, .before = 1)
    })
  })
  dplyr::bind_rows(main_results, any_results, bridge_results)
}

did_results <- run_did_models(success_data, failure_data, pooled_data) |>
  dplyr::mutate(
    dplyr::across(c(estimate, std_error), ~ round(.x, 4)),
    p_value = signif(p_value, 3)
  )

readr::write_csv(
  did_results,
  file.path(paths$tables, "active_operating_cumulative_stacked_did.csv")
)
saveRDS(
  list(success_data = success_data, failure_data = failure_data, results = did_results),
  file.path(paths$intermediate, "active_operating_cumulative_stacked_did.rds")
)

# Stage 3: t-1 vs t-2 pre-period placebo. Mirrors the main table's three
# contrasts so it can sit as a leading "pre-period" row per panel: the two
# separate effects, the pooled any-override effect, and the success-minus-failure
# differential.
run_placebo <- function(success_data, failure_data, pooled_data) {
  separate <- purrr::map_dfr(c(success = "success", failure = "failure"), function(kind) {
    data_kind <- if (kind == "success") success_data else failure_data
    purrr::map_dfr(c("pre_downgrade", "pre_upgrade"), function(outcome) {
      formula <- stats::as.formula(paste(outcome, "~ treated_event | stack_id"))
      extract_term(safe_fit(formula, data_kind), "treated_event") |>
        dplyr::mutate(contrast = paste0(kind, "_vs_no_override"), outcome = outcome, .before = 1)
    })
  })
  any_override <- purrr::map_dfr(c("pre_downgrade", "pre_upgrade"), function(outcome) {
    formula <- stats::as.formula(paste(outcome, "~ treated_event | stack_id"))
    extract_term(safe_fit(formula, pooled_data), "treated_event") |>
      dplyr::mutate(contrast = "any_override_vs_no_override", outcome = outcome, .before = 1)
  })
  bridge <- purrr::map_dfr(c("pre_downgrade", "pre_upgrade"), function(outcome) {
    formula <- stats::as.formula(paste(outcome, "~ treated_event + treated_event:is_success | stack_id"))
    extract_term(safe_fit(formula, pooled_data), "treated_event:is_success") |>
      dplyr::mutate(contrast = "success_minus_failure", outcome = outcome, .before = 1)
  })
  dplyr::bind_rows(separate, any_override, bridge)
}

placebo_results <- run_placebo(success_data, failure_data, pooled_data) |>
  dplyr::mutate(
    dplyr::across(c(estimate, std_error), ~ round(.x, 4)),
    p_value = signif(p_value, 3)
  )

readr::write_csv(
  placebo_results,
  file.path(paths$tables, "active_operating_cumulative_stacked_did_placebo.csv")
)

# Stage 4: triangulation against the close-election RDD.
rdd_file <- file.path(paths$tables, "active_operating_close_election_rating_models.csv")
if (!file.exists(rdd_file)) {
  source(file.path("R", "17_close_election_rating_models.R"))
}
rdd <- readr::read_csv(rdd_file, show_col_types = FALSE) |>
  dplyr::filter(band == 5, spec == "lpm_controls")

triangulation <- tibble::tibble(
  comparison = c("downgrade_within_1", "downgrade_within_2", "upgrade_within_1", "upgrade_within_2"),
  rdd_outcome = c("any_downgrade_within_1yr", "any_downgrade_within_2yr",
                  "any_upgrade_within_1yr", "any_upgrade_within_2yr"),
  did_outcome = c("cum_downgrade_within_1", "cum_downgrade_within_2",
                  "cum_upgrade_within_1", "cum_upgrade_within_2")
) |>
  dplyr::left_join(
    rdd |> dplyr::select(rdd_outcome = outcome, rdd_estimate = estimate,
                         rdd_std_error = std_error, rdd_p_value = p_value),
    by = "rdd_outcome"
  ) |>
  dplyr::left_join(
    did_results |>
      dplyr::filter(contrast == "success_minus_failure", spec == "with_controls") |>
      dplyr::select(did_outcome = outcome, did_estimate = estimate,
                    did_std_error = std_error, did_p_value = p_value),
    by = "did_outcome"
  ) |>
  dplyr::mutate(
    dplyr::across(c(rdd_estimate, rdd_std_error, did_estimate, did_std_error), ~ round(.x, 4)),
    dplyr::across(c(rdd_p_value, did_p_value), ~ signif(.x, 3))
  )

readr::write_csv(
  triangulation,
  file.path(paths$tables, "active_operating_cumulative_stacked_did_vs_rdd.csv")
)

# Stage 5: which fiscal fundamentals predict the rating outcomes. Control
# coefficients from the same with-controls models behind the main table, taken
# separately for the success-vs-no-override and failure-vs-no-override
# regressions at the fullest cumulative horizon.
control_data <- list(
  success_vs_no_override = success_data,
  failure_vs_no_override = failure_data,
  any_override_vs_no_override = pooled_data
)
control_predictors <- purrr::imap_dfr(
  control_data,
  function(data_kind, contrast_name) {
    purrr::map_dfr(c("cum_downgrade_within_2", "cum_upgrade_within_2"), function(outcome) {
      fit <- safe_fit(stacked_formula(outcome, use_controls = TRUE), data_kind)
      purrr::map_dfr(active_controls, function(v) {
        extract_term(fit, v) |>
          dplyr::mutate(contrast = contrast_name, outcome = outcome, term = v, .before = 1)
      })
    })
  }
) |>
  dplyr::mutate(
    dplyr::across(c(estimate, std_error), ~ round(.x, 4)),
    p_value = signif(p_value, 3)
  )

readr::write_csv(
  control_predictors,
  file.path(paths$tables, "active_operating_cumulative_stacked_did_controls.csv")
)

# Stage 6: pre-treatment balance. Regress each control (measured at the election
# fiscal year, rel_year == -1) on treated_event within stacks; a non-zero
# coefficient means treated and no-override-control towns differ before treatment.
balance_results <- purrr::imap_dfr(
  c(success_vs_no_override = "success", failure_vs_no_override = "failure"),
  function(kind, contrast_name) {
    data_kind <- if (kind == "success") success_data else failure_data
    purrr::map_dfr(active_controls, function(v) {
      formula <- stats::as.formula(paste(v, "~ treated_event | stack_id"))
      extract_term(safe_fit(formula, data_kind), "treated_event") |>
        dplyr::mutate(contrast = contrast_name, variable = v, .before = 1)
    })
  }
) |>
  dplyr::mutate(
    dplyr::across(c(estimate, std_error), ~ round(.x, 4)),
    p_value = signif(p_value, 3)
  )

readr::write_csv(
  balance_results,
  file.path(paths$tables, "active_operating_cumulative_stacked_did_balance.csv")
)
