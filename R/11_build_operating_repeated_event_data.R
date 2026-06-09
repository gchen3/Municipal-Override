source(file.path("R", "00_config.R"))
load_required_packages(c("dplyr", "tidyr", "purrr", "gt", "readr"))
make_output_dirs()
source(file.path("R", "active_helpers.R"))

if (!file.exists(file.path(paths$intermediate, "data_for_regression.rds"))) {
  source(file.path("R", "02_build_regression_data.R"))
}

event_window <- active_event_window
event_times <- active_event_times

panel <- readRDS(file.path(paths$intermediate, "data_for_regression.rds")) |>
  dplyr::arrange(code, year) |>
  dplyr::mutate(
    oper_attempt_event = oper_binary == 1,
    oper_success_event = oper_binary_win == 1,
    oper_failure_event = oper_binary_fail == 1,
    oper_status_missing = is.na(oper_binary) | is.na(oper_binary_win) | is.na(oper_binary_fail)
  )

attach_prior_history <- function(stack_rows, focal_variable) {
  stack_base <- stack_rows |>
    dplyr::distinct(stack_id, event_year, code)

  history_source <- panel |>
    dplyr::transmute(
      code,
      history_year = year,
      focal_event = .data[[focal_variable]],
      oper_attempt_event,
      oper_success_event,
      oper_failure_event
    )

  history <- stack_base |>
    dplyr::left_join(history_source, by = "code", relationship = "many-to-many") |>
    dplyr::filter(history_year < event_year) |>
    dplyr::group_by(stack_id, event_year, code) |>
    dplyr::summarise(
      prior_focal_event_count = sum(focal_event, na.rm = TRUE),
      prior_oper_attempt_count = sum(oper_attempt_event, na.rm = TRUE),
      prior_oper_success_count = sum(oper_success_event, na.rm = TRUE),
      prior_oper_failure_count = sum(oper_failure_event, na.rm = TRUE),
      last_focal_event_year = {
        focal_years <- history_year[focal_event %in% TRUE]
        if (length(focal_years) == 0) NA_real_ else max(focal_years)
      },
      .groups = "drop"
    ) |>
    dplyr::mutate(
      years_since_last_focal_event = event_year - last_focal_event_year,
      years_since_last_focal_event_filled = tidyr::replace_na(years_since_last_focal_event, 99),
      post_prior_focal_event = as.numeric(prior_focal_event_count > 0)
    )

  stack_rows |>
    dplyr::left_join(
      history |>
        dplyr::select(
          stack_id, code, prior_focal_event_count, prior_oper_attempt_count,
          prior_oper_success_count, prior_oper_failure_count,
          years_since_last_focal_event, years_since_last_focal_event_filled,
          post_prior_focal_event
        ),
      by = c("stack_id", "code")
    )
}

build_operating_event_stack <- function(event_type, event_variable, event_label, file_stub) {
  all_codes <- sort(unique(panel$code))
  focal_event <- panel[[event_variable]]

  event_candidates <- panel |>
    dplyr::mutate(focal_event = .data[[event_variable]]) |>
    dplyr::filter(
      focal_event,
      year >= min(panel$year) + event_window,
      year <= max(panel$year) - event_window
    ) |>
    dplyr::transmute(event_code = code, event_year = year) |>
    dplyr::arrange(event_code, event_year) |>
    dplyr::mutate(
      other_focal_events_in_window = purrr::map2_int(
        event_code,
        event_year,
        ~ sum(
          panel$code == .x &
            abs(panel$year - .y) <= event_window &
            panel$year != .y &
            focal_event,
          na.rm = TRUE
        )
      ),
      attempts_in_window = purrr::map2_int(
        event_code,
        event_year,
        ~ sum(panel$code == .x & abs(panel$year - .y) <= event_window & panel$oper_attempt_event, na.rm = TRUE)
      ),
      successes_in_window = purrr::map2_int(
        event_code,
        event_year,
        ~ sum(panel$code == .x & abs(panel$year - .y) <= event_window & panel$oper_success_event, na.rm = TRUE)
      ),
      failures_in_window = purrr::map2_int(
        event_code,
        event_year,
        ~ sum(panel$code == .x & abs(panel$year - .y) <= event_window & panel$oper_failure_event, na.rm = TRUE)
      ),
      missing_status_in_window = purrr::map2_int(
        event_code,
        event_year,
        ~ sum(panel$code == .x & abs(panel$year - .y) <= event_window & panel$oper_status_missing, na.rm = TRUE)
      )
    )

  clean_events <- event_candidates |>
    dplyr::filter(other_focal_events_in_window == 0) |>
    dplyr::mutate(
      event_type = event_type,
      event_label = event_label,
      stack_id = paste0(file_stub, "_", event_code, "_", event_year),
      .before = event_code
    )

  event_windows <- clean_events |>
    dplyr::select(stack_id, event_type, event_label, event_code, event_year) |>
    tidyr::expand_grid(rel_year = event_times) |>
    dplyr::mutate(year = event_year + rel_year)

  never_treated_codes <- panel |>
    dplyr::mutate(focal_event = .data[[event_variable]]) |>
    dplyr::group_by(code) |>
    dplyr::summarise(ever_focal_event = any(focal_event, na.rm = TRUE), .groups = "drop") |>
    dplyr::filter(!ever_focal_event) |>
    dplyr::pull(code)

  pair_window_status <- event_windows |>
    dplyr::select(stack_id, event_year, year) |>
    tidyr::expand_grid(code = all_codes) |>
    dplyr::left_join(
      panel |>
        dplyr::transmute(
          code, year,
          focal_event = .data[[event_variable]],
          oper_attempt_event, oper_success_event, oper_failure_event,
          oper_status_missing
        ),
      by = c("code", "year")
    ) |>
    dplyr::group_by(stack_id, event_year, code) |>
    dplyr::summarise(
      focal_events_in_window = sum(focal_event, na.rm = TRUE),
      attempts_in_window = sum(oper_attempt_event, na.rm = TRUE),
      successes_in_window = sum(oper_success_event, na.rm = TRUE),
      failures_in_window = sum(oper_failure_event, na.rm = TRUE),
      missing_status_in_window = sum(oper_status_missing, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::left_join(
      clean_events |> dplyr::select(stack_id, event_type, event_label, event_code),
      by = "stack_id"
    ) |>
    dplyr::mutate(
      is_event_municipality = code == event_code,
      is_never_treated = code %in% never_treated_codes
    )

  build_stack <- function(control_pool) {
    treatment_rows <- event_windows |>
      dplyr::transmute(
        stack_id, event_type, event_label, event_code, event_year,
        code = event_code, year, rel_year,
        treated_event = 1,
        control_pool = "treated",
        control_attempts_in_window = NA_integer_,
        control_successes_in_window = NA_integer_,
        control_failures_in_window = NA_integer_,
        control_missing_status_in_window = NA_integer_,
        control_is_never_treated = FALSE
      )

    control_pairs <- pair_window_status |>
      dplyr::filter(!is_event_municipality)

    if (control_pool == "window_clean") {
      control_pairs <- control_pairs |>
        dplyr::filter(focal_events_in_window == 0)
    } else if (control_pool == "never_treated") {
      control_pairs <- control_pairs |>
        dplyr::filter(is_never_treated)
    } else {
      stop("Unknown control pool: ", control_pool, call. = FALSE)
    }

    control_rows <- control_pairs |>
      dplyr::select(
        stack_id, event_type, event_label, event_code, event_year, code,
        control_attempts_in_window = attempts_in_window,
        control_successes_in_window = successes_in_window,
        control_failures_in_window = failures_in_window,
        control_missing_status_in_window = missing_status_in_window,
        control_is_never_treated = is_never_treated
      ) |>
      tidyr::expand_grid(rel_year = event_times) |>
      dplyr::mutate(
        year = event_year + rel_year,
        treated_event = 0,
        control_pool = control_pool,
        .before = control_attempts_in_window
      )

    dplyr::bind_rows(treatment_rows, control_rows) |>
      attach_prior_history(event_variable) |>
      dplyr::left_join(
        panel |>
          dplyr::select(
            -oper_attempt_event, -oper_success_event, -oper_failure_event,
            -oper_status_missing
          ),
        by = c("code", "year")
      ) |>
      dplyr::arrange(stack_id, dplyr::desc(treated_event), code, rel_year)
  }

  stack_window_clean <- build_stack("window_clean")
  stack_never_treated <- build_stack("never_treated")

  event_history <- stack_window_clean |>
    dplyr::filter(treated_event == 1, rel_year == 0) |>
    dplyr::select(
      stack_id, prior_focal_event_count, prior_oper_attempt_count,
      prior_oper_success_count, prior_oper_failure_count,
      years_since_last_focal_event, post_prior_focal_event
    )

  clean_events <- clean_events |>
    dplyr::left_join(event_history, by = "stack_id")

  overall_counts <- panel |>
    dplyr::mutate(focal_event = .data[[event_variable]]) |>
    dplyr::group_by(code) |>
    dplyr::summarise(focal_event_years = sum(focal_event, na.rm = TRUE), .groups = "drop")

  stack_counts <- function(stack_data, sample_name) {
    row_counts <- stack_data |>
      dplyr::mutate(group = dplyr::if_else(treated_event == 1, "treated", "control")) |>
      dplyr::group_by(event_type, event_label, group, rel_year) |>
      dplyr::summarise(
        rows = dplyr::n(),
        nonmissing_moodys = sum(!is.na(MOO_num)),
        .groups = "drop"
      ) |>
      tidyr::pivot_longer(c(rows, nonmissing_moodys), names_to = "metric", values_to = "value") |>
      dplyr::mutate(sample = sample_name, .before = group)

    control_pairs <- stack_data |>
      dplyr::filter(treated_event == 0) |>
      dplyr::distinct(
        stack_id, code, control_is_never_treated,
        control_attempts_in_window, control_successes_in_window,
        control_failures_in_window
      )

    pair_counts <- tibble::tibble(
      event_type = event_type,
      event_label = event_label,
      sample = sample_name,
      group = "control",
      rel_year = NA_integer_,
      metric = c(
        "control_event_municipality_pairs",
        "unique_control_municipalities",
        "share_control_pairs_never_treated",
        "control_pairs_with_oper_attempt_in_window",
        "control_pairs_with_oper_success_in_window",
        "control_pairs_with_oper_failure_in_window"
      ),
      value = c(
        nrow(control_pairs),
        dplyr::n_distinct(control_pairs$code),
        mean(control_pairs$control_is_never_treated),
        sum(control_pairs$control_attempts_in_window > 0, na.rm = TRUE),
        sum(control_pairs$control_successes_in_window > 0, na.rm = TRUE),
        sum(control_pairs$control_failures_in_window > 0, na.rm = TRUE)
      )
    )

    dplyr::bind_rows(pair_counts, row_counts)
  }

  sample_counts <- dplyr::bind_rows(
    tibble::tibble(
      event_type = event_type,
      event_label = event_label,
      sample = "overall",
      group = "all",
      rel_year = NA_integer_,
      metric = c(
        "focal_event_years",
        "municipalities_with_focal_event",
        "treated_municipalities_one_focal_event_year",
        "treated_municipalities_multiple_focal_event_years",
        "clean_treatment_events",
        "clean_treated_municipalities",
        "candidate_events_dropped_for_nearby_focal_event",
        "clean_events_with_oper_attempt_in_window",
        "clean_events_with_oper_success_in_window",
        "clean_events_with_oper_failure_in_window",
        "candidate_events_with_missing_status_in_window"
      ),
      value = c(
        sum(panel[[event_variable]], na.rm = TRUE),
        sum(overall_counts$focal_event_years > 0),
        sum(overall_counts$focal_event_years == 1),
        sum(overall_counts$focal_event_years > 1),
        nrow(clean_events),
        dplyr::n_distinct(clean_events$event_code),
        sum(event_candidates$other_focal_events_in_window > 0),
        sum(clean_events$attempts_in_window > 0),
        sum(clean_events$successes_in_window > 0),
        sum(clean_events$failures_in_window > 0),
        sum(event_candidates$missing_status_in_window > 0)
      )
    ),
    stack_counts(stack_window_clean, "window_clean"),
    stack_counts(stack_never_treated, "never_treated")
  )

  list(
    events = clean_events,
    stack_window_clean = stack_window_clean,
    stack_never_treated = stack_never_treated,
    sample_counts = sample_counts
  )
}

operating_repeated_event_data <- purrr::pmap(
  operating_event_definitions,
  build_operating_event_stack
)
names(operating_repeated_event_data) <- operating_event_definitions$event_type

combined_sample_counts <- dplyr::bind_rows(
  purrr::map(operating_repeated_event_data, "sample_counts")
)

readr::write_csv(
  combined_sample_counts,
  file.path(paths$tables, "active_operating_repeated_event_sample_counts.csv")
)
gt::gtsave(
  combined_sample_counts |>
    dplyr::arrange(event_type, sample, group, metric, rel_year) |>
    dplyr::mutate(value = round(value, 3)) |>
    gt::gt() |>
    gt::tab_header(title = "Active Operating Repeated-Event Sample Counts"),
  file.path(paths$tables, "active_operating_repeated_event_sample_counts.html")
)

purrr::iwalk(
  operating_repeated_event_data,
  function(event_data, event_type) {
    readr::write_csv(
      event_data$sample_counts,
      file.path(paths$tables, paste0("active_", event_type, "_sample_counts.csv"))
    )
    gt::gtsave(
      event_data$sample_counts |>
        dplyr::arrange(sample, group, metric, rel_year) |>
        dplyr::mutate(value = round(value, 3)) |>
        gt::gt() |>
        gt::tab_header(title = paste("Active", event_data$events$event_label[1], "Sample Counts")),
      file.path(paths$tables, paste0("active_", event_type, "_sample_counts.html"))
    )
    saveRDS(
      event_data$events,
      file.path(paths$intermediate, paste0("active_", event_type, "_events.rds"))
    )
    saveRDS(
      event_data$stack_window_clean,
      file.path(paths$intermediate, paste0("active_", event_type, "_stack_window_clean.rds"))
    )
    saveRDS(
      event_data$stack_never_treated,
      file.path(paths$intermediate, paste0("active_", event_type, "_stack_never_treated.rds"))
    )
  }
)

saveRDS(
  operating_repeated_event_data,
  file.path(paths$intermediate, "active_operating_repeated_event_data.rds")
)
