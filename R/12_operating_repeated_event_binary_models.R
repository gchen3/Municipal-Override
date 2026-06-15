source(file.path("R", "00_config.R"))
load_required_packages(c("dplyr", "tidyr", "purrr", "fixest", "gt", "readr"))
make_output_dirs()
source(file.path("R", "active_helpers.R"))

if (!file.exists(file.path(paths$intermediate, "active_operating_repeated_event_data.rds"))) {
  source(file.path("R", "11_build_operating_repeated_event_data.R"))
}

operating_repeated_event_data <- readRDS(
  file.path(paths$intermediate, "active_operating_repeated_event_data.rds")
)

fit_event_binary_models <- function(event_data, event_type) {
  first_time_stacks <- event_data$events |>
    dplyr::filter(prior_focal_event_count == 0) |>
    dplyr::pull(stack_id)

  stack_window_clean <- add_rating_change_outcomes(event_data$stack_window_clean)
  stack_never_treated <- add_rating_change_outcomes(event_data$stack_never_treated)

  model_specs <- list(
    window_clean_preferred = list(
      data = stack_window_clean,
      control_pool = "window_clean",
      formula = \(outcome) did_event_formula(outcome)
    ),
    never_treated_controls = list(
      data = stack_never_treated,
      control_pool = "never_treated",
      formula = \(outcome) did_event_formula(outcome)
    ),
    active_controls_preferred = list(
      data = stack_window_clean,
      control_pool = "window_clean",
      formula = \(outcome) did_event_formula(
        outcome,
        covariates = active_controls
      )
    ),
    first_time_events = list(
      data = stack_window_clean |> dplyr::filter(stack_id %in% first_time_stacks),
      control_pool = "window_clean",
      formula = \(outcome) did_event_formula(outcome)
    ),
    narrow_window = list(
      data = stack_window_clean |> dplyr::filter(rel_year %in% -1:1),
      control_pool = "window_clean",
      formula = \(outcome) did_event_formula(outcome)
    )
  )

  fits <- purrr::imap(
    model_specs,
    function(spec, model_name) {
      purrr::map(
        did_binary_outcomes,
        \(outcome) fit_binary_did(
          spec$data,
          outcome,
          spec$formula(outcome),
          model_name
        )
      ) |>
        stats::setNames(did_binary_outcomes)
    }
  )

  results <- purrr::imap_dfr(
    model_specs,
    function(spec, model_name) {
      purrr::map_dfr(
        fits[[model_name]],
        extract_event_estimates,
        event_type = event_type,
        control_pool = spec$control_pool
      )
    }
  )

  list(fits = fits, results = results)
}

operating_binary_did <- purrr::imap(
  operating_repeated_event_data,
  fit_event_binary_models
)

binary_did_results <- dplyr::bind_rows(purrr::map(operating_binary_did, "results"))
binary_did_main_results <- binary_did_results |>
  dplyr::filter(model == "window_clean_preferred")

preferred_failures <- binary_did_main_results |>
  dplyr::filter(model_failed) |>
  dplyr::distinct(event_type, outcome, error_message)

if (nrow(preferred_failures) > 0) {
  stop(
    "Preferred repeated-event DiD models failed: ",
    paste(
      paste(
        preferred_failures$event_type,
        preferred_failures$outcome,
        preferred_failures$error_message,
        sep = " / "
      ),
      collapse = "; "
    ),
    call. = FALSE
  )
}

format_binary_did_table <- function(results) {
  results |>
    dplyr::arrange(event_type, outcome, model, event_time) |>
    dplyr::mutate(
      estimate = round(estimate, 3),
      std_error = round(std_error, 3),
      p_value = signif(p_value, 3),
      ci_lower = round(ci_lower, 3),
      ci_upper = round(ci_upper, 3)
    )
}

readr::write_csv(
  binary_did_results,
  file.path(paths$tables, "active_operating_repeated_event_binary_did.csv")
)
gt::gtsave(
  format_binary_did_table(binary_did_results) |>
    gt::gt() |>
    gt::tab_header(title = "Active Repeated-Event Binary DiD Estimates"),
  file.path(paths$tables, "active_operating_repeated_event_binary_did.html")
)

readr::write_csv(
  binary_did_main_results,
  file.path(paths$tables, "active_operating_repeated_event_binary_did_main.csv")
)
gt::gtsave(
  format_binary_did_table(binary_did_main_results) |>
    gt::gt() |>
    gt::tab_header(title = "Active Repeated-Event Binary DiD Estimates"),
  file.path(paths$tables, "active_operating_repeated_event_binary_did_main.html")
)

saveRDS(
  list(
    results = binary_did_results,
    outcomes = did_binary_outcomes,
    active_control_covariates = active_controls,
    model_failures = binary_did_results |>
      dplyr::filter(model_failed) |>
      dplyr::distinct(event_type, control_pool, outcome, model, error_message)
  ),
  file.path(paths$intermediate, "active_operating_repeated_event_binary_models.rds")
)
