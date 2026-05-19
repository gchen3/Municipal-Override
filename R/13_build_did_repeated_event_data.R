source(file.path("R", "00_config.R"))
load_required_packages(c("dplyr", "tidyr", "purrr", "readr"))
make_output_dirs()

if (!file.exists(file.path(paths$intermediate, "data_for_regression.rds"))) {
  source(file.path("R", "02_build_regression_data.R"))
}

event_window <- 2L
event_times <- -event_window:event_window

panel <- readRDS(file.path(paths$intermediate, "data_for_regression.rds")) |>
  dplyr::arrange(code, year) |>
  dplyr::mutate(
    oper_success_event = oper_binary_win == 1,
    oper_attempt_event = oper_binary == 1,
    oper_failed_event = oper_binary_fail == 1,
    oper_status_missing = is.na(oper_binary) | is.na(oper_binary_win)
  )

all_codes <- sort(unique(panel$code))
never_treated_codes <- panel |>
  dplyr::group_by(code) |>
  dplyr::summarise(ever_oper_success = any(oper_success_event, na.rm = TRUE), .groups = "drop") |>
  dplyr::filter(!ever_oper_success) |>
  dplyr::pull(code)

event_candidates <- panel |>
  dplyr::filter(oper_success_event, year >= min(panel$year) + event_window, year <= max(panel$year) - event_window) |>
  dplyr::transmute(event_code = code, event_year = year) |>
  dplyr::arrange(event_code, event_year) |>
  dplyr::mutate(
    other_successes_in_window = purrr::map2_int(
      event_code,
      event_year,
      ~ sum(
        panel$code == .x &
          abs(panel$year - .y) <= event_window &
          panel$year != .y &
          panel$oper_success_event,
        na.rm = TRUE
      )
    ),
    failed_attempts_in_window = purrr::map2_int(
      event_code,
      event_year,
      ~ sum(
        panel$code == .x &
          abs(panel$year - .y) <= event_window &
          panel$oper_failed_event,
        na.rm = TRUE
      )
    ),
    missing_oper_status_in_window = purrr::map2_int(
      event_code,
      event_year,
      ~ sum(
        panel$code == .x &
          abs(panel$year - .y) <= event_window &
          panel$oper_status_missing,
        na.rm = TRUE
      )
    )
  )

# The count-matching clean event rule excludes overlapping successful operating
# events. Nearby failed attempts are retained as diagnostics because excluding
# them does not match the design-plan feasibility counts.
clean_treatment_events <- event_candidates |>
  dplyr::filter(other_successes_in_window == 0) |>
  dplyr::mutate(
    stack_id = paste0("oper_", event_code, "_", event_year),
    .before = event_code
  )

event_windows <- clean_treatment_events |>
  dplyr::select(stack_id, event_code, event_year) |>
  tidyr::expand_grid(rel_year = event_times) |>
  dplyr::mutate(year = event_year + rel_year)

pair_window_status <- event_windows |>
  dplyr::select(stack_id, event_year, year) |>
  tidyr::expand_grid(code = all_codes) |>
  dplyr::left_join(
    panel |>
      dplyr::select(code, year, oper_success_event, oper_failed_event, oper_status_missing),
    by = c("code", "year")
  ) |>
  dplyr::group_by(stack_id, event_year, code) |>
  dplyr::summarise(
    success_events_in_window = sum(oper_success_event, na.rm = TRUE),
    failed_attempts_in_window = sum(oper_failed_event, na.rm = TRUE),
    missing_oper_status_in_window = sum(oper_status_missing, na.rm = TRUE),
    .groups = "drop"
  ) |>
  dplyr::left_join(
    clean_treatment_events |> dplyr::select(stack_id, event_code),
    by = "stack_id"
  ) |>
  dplyr::mutate(
    is_event_municipality = code == event_code,
    is_never_treated = code %in% never_treated_codes
  )

history_source <- panel |>
  dplyr::select(code, history_year = year, oper_success_event, oper_attempt_event)

attach_prior_history <- function(stack_rows) {
  stack_base <- stack_rows |>
    dplyr::distinct(stack_id, event_year, code)

  history <- stack_base |>
    dplyr::left_join(history_source, by = "code", relationship = "many-to-many") |>
    dplyr::filter(history_year < event_year) |>
    dplyr::group_by(stack_id, event_year, code) |>
    dplyr::summarise(
      prior_oper_success_count = sum(oper_success_event, na.rm = TRUE),
      prior_oper_attempt_count = sum(oper_attempt_event, na.rm = TRUE),
      last_oper_success_year = {
        success_years <- history_year[oper_success_event %in% TRUE]
        if (length(success_years) == 0) NA_real_ else max(success_years)
      },
      .groups = "drop"
    ) |>
    dplyr::mutate(
      years_since_last_oper_success = event_year - last_oper_success_year,
      post_prior_success = as.numeric(prior_oper_success_count > 0)
    )

  stack_rows |>
    dplyr::left_join(
      history |>
        dplyr::select(
          stack_id, code, prior_oper_success_count, prior_oper_attempt_count,
          years_since_last_oper_success, post_prior_success
        ),
      by = c("stack_id", "code")
    )
}

build_stack <- function(control_pool) {
  treatment_rows <- event_windows |>
    dplyr::transmute(
      stack_id, event_code, event_year, code = event_code, year, rel_year,
      treated_event = 1,
      control_pool = "treated",
      control_failed_attempts_in_window = NA_integer_,
      control_missing_oper_status_in_window = NA_integer_,
      control_is_never_treated = FALSE
    )

  control_pairs <- pair_window_status |>
    dplyr::filter(!is_event_municipality)

  if (control_pool == "window_clean") {
    control_pairs <- control_pairs |>
      dplyr::filter(success_events_in_window == 0)
  } else if (control_pool == "never_treated") {
    control_pairs <- control_pairs |>
      dplyr::filter(is_never_treated)
  } else {
    stop("Unknown control pool: ", control_pool, call. = FALSE)
  }

  control_rows <- control_pairs |>
    dplyr::select(
      stack_id, event_code, event_year, code,
      control_failed_attempts_in_window = failed_attempts_in_window,
      control_missing_oper_status_in_window = missing_oper_status_in_window,
      control_is_never_treated = is_never_treated
    ) |>
    tidyr::expand_grid(rel_year = event_times) |>
    dplyr::mutate(
      year = event_year + rel_year,
      treated_event = 0,
      control_pool = control_pool,
      .before = control_failed_attempts_in_window
    )

  dplyr::bind_rows(treatment_rows, control_rows) |>
    attach_prior_history() |>
    dplyr::left_join(
      panel |> dplyr::select(-oper_success_event, -oper_attempt_event, -oper_failed_event, -oper_status_missing),
      by = c("code", "year")
    ) |>
    dplyr::arrange(stack_id, dplyr::desc(treated_event), code, rel_year)
}

did_stack_window_clean <- build_stack("window_clean")
did_stack_never_treated <- build_stack("never_treated")

treatment_event_history <- did_stack_window_clean |>
  dplyr::filter(treated_event == 1, rel_year == 0) |>
  dplyr::select(
    stack_id, prior_oper_success_count, prior_oper_attempt_count,
    years_since_last_oper_success, post_prior_success
  )

clean_treatment_events <- clean_treatment_events |>
  dplyr::left_join(treatment_event_history, by = "stack_id")

overall_counts <- panel |>
  dplyr::group_by(code) |>
  dplyr::summarise(success_years = sum(oper_success_event, na.rm = TRUE), .groups = "drop")

summary_counts <- tibble::tibble(
  sample = "overall",
  group = "all",
  rel_year = NA_integer_,
  metric = c(
    "successful_operating_event_years",
    "municipalities_with_successful_operating_event",
    "treated_municipalities_one_success_year",
    "treated_municipalities_multiple_success_years",
    "clean_treatment_events",
    "clean_treated_municipalities",
    "clean_events_with_nearby_failed_oper_attempt",
    "candidate_events_dropped_for_nearby_success",
    "candidate_events_with_missing_oper_status_in_window"
  ),
  value = c(
    sum(panel$oper_success_event, na.rm = TRUE),
    sum(overall_counts$success_years > 0),
    sum(overall_counts$success_years == 1),
    sum(overall_counts$success_years > 1),
    nrow(clean_treatment_events),
    dplyr::n_distinct(clean_treatment_events$event_code),
    sum(clean_treatment_events$failed_attempts_in_window > 0),
    sum(event_candidates$other_successes_in_window > 0),
    sum(event_candidates$missing_oper_status_in_window > 0)
  )
)

stack_counts <- function(stack_data, sample_name) {
  row_counts <- stack_data |>
    dplyr::mutate(group = dplyr::if_else(treated_event == 1, "treated", "control")) |>
    dplyr::group_by(group, rel_year) |>
    dplyr::summarise(
      rows = dplyr::n(),
      nonmissing_moodys = sum(!is.na(MOO_num)),
      .groups = "drop"
    ) |>
    tidyr::pivot_longer(c(rows, nonmissing_moodys), names_to = "metric", values_to = "value") |>
    dplyr::mutate(sample = sample_name, .before = group)

  control_pairs <- stack_data |>
    dplyr::filter(treated_event == 0) |>
    dplyr::distinct(stack_id, code, control_is_never_treated, control_failed_attempts_in_window)

  pair_counts <- tibble::tibble(
    sample = sample_name,
    group = "control",
    rel_year = NA_integer_,
    metric = c(
      "control_event_municipality_pairs",
      "unique_control_municipalities",
      "share_control_pairs_never_treated",
      "control_pairs_with_nearby_failed_oper_attempt"
    ),
    value = c(
      nrow(control_pairs),
      dplyr::n_distinct(control_pairs$code),
      mean(control_pairs$control_is_never_treated),
      sum(control_pairs$control_failed_attempts_in_window > 0, na.rm = TRUE)
    )
  )

  dplyr::bind_rows(pair_counts, row_counts)
}

sample_counts <- dplyr::bind_rows(
  summary_counts,
  stack_counts(did_stack_window_clean, "window_clean"),
  stack_counts(did_stack_never_treated, "never_treated")
)

saveRDS(
  clean_treatment_events,
  file.path(paths$intermediate, "did_repeated_event_treatment_events.rds")
)
saveRDS(
  did_stack_window_clean,
  file.path(paths$intermediate, "did_repeated_event_stack_window_clean.rds")
)
saveRDS(
  did_stack_never_treated,
  file.path(paths$intermediate, "did_repeated_event_stack_never_treated.rds")
)
readr::write_csv(
  sample_counts,
  file.path(paths$tables, "did_repeated_event_sample_counts.csv")
)
