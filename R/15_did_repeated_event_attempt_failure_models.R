source(file.path("R", "00_config.R"))
load_required_packages(c("dplyr", "tidyr", "purrr", "fixest", "ggplot2", "readr"))
make_output_dirs()

if (!file.exists(file.path(paths$intermediate, "data_for_regression.rds"))) {
  source(file.path("R", "02_build_regression_data.R"))
}

event_window <- 2L
event_times <- -event_window:event_window

panel <- readRDS(file.path(paths$intermediate, "data_for_regression.rds")) |>
  dplyr::arrange(code, year) |>
  dplyr::mutate(
    oper_attempt_event = oper_binary == 1,
    oper_success_event = oper_binary_win == 1,
    oper_failure_event = oper_binary_fail == 1,
    oper_status_missing = is.na(oper_binary) | is.na(oper_binary_win) | is.na(oper_binary_fail)
  )

event_definitions <- tibble::tribble(
  ~event_type, ~event_variable, ~event_label, ~file_stub,
  "operating_attempt", "oper_attempt_event", "Operating Override Attempt", "oper_attempt",
  "operating_failure", "oper_failure_event", "Operating Override Failure", "oper_failure"
)

preferred_formula <- MOO_num ~ i(rel_year, treated_event, ref = -1) | stack_id^code + stack_id^year
municipality_formula <- MOO_num ~ i(rel_year, treated_event, ref = -1) | code + stack_id^year
simple_formula <- MOO_num ~ i(rel_year, treated_event, ref = -1) | stack_id + code + year
history_formula <- MOO_num ~
  i(rel_year, treated_event, ref = -1) +
  prior_focal_event_count + prior_oper_attempt_count + prior_oper_success_count +
  prior_oper_failure_count + years_since_last_focal_event_filled |
  code + stack_id^year

count_prior_history <- function(stack_rows, focal_variable) {
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
      post_prior_focal_event = as.numeric(prior_focal_event_count > 0)
    )

  stack_rows |>
    dplyr::left_join(
      history |>
        dplyr::select(
          stack_id, code, prior_focal_event_count, prior_oper_attempt_count,
          prior_oper_success_count, prior_oper_failure_count,
          years_since_last_focal_event, post_prior_focal_event
        ),
      by = c("stack_id", "code")
    )
}

build_event_stack <- function(event_type, event_variable, file_stub) {
  all_codes <- sort(unique(panel$code))
  focal_event <- panel[[event_variable]]
  never_treated_codes <- panel |>
    dplyr::mutate(focal_event = .data[[event_variable]]) |>
    dplyr::group_by(code) |>
    dplyr::summarise(ever_focal_event = any(focal_event, na.rm = TRUE), .groups = "drop") |>
    dplyr::filter(!ever_focal_event) |>
    dplyr::pull(code)

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
      successes_in_window = purrr::map2_int(
        event_code,
        event_year,
        ~ sum(
          panel$code == .x &
            abs(panel$year - .y) <= event_window &
            panel$oper_success_event,
          na.rm = TRUE
        )
      ),
      failures_in_window = purrr::map2_int(
        event_code,
        event_year,
        ~ sum(
          panel$code == .x &
            abs(panel$year - .y) <= event_window &
            panel$oper_failure_event,
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

  clean_treatment_events <- event_candidates |>
    dplyr::filter(other_focal_events_in_window == 0) |>
    dplyr::mutate(
      event_type = event_type,
      stack_id = paste0(file_stub, "_", event_code, "_", event_year),
      .before = event_code
    )

  event_windows <- clean_treatment_events |>
    dplyr::select(stack_id, event_type, event_code, event_year) |>
    tidyr::expand_grid(rel_year = event_times) |>
    dplyr::mutate(year = event_year + rel_year)

  pair_window_status <- event_windows |>
    dplyr::select(stack_id, event_year, year) |>
    tidyr::expand_grid(code = all_codes) |>
    dplyr::left_join(
      panel |>
        dplyr::transmute(
          code,
          year,
          focal_event = .data[[event_variable]],
          oper_success_event,
          oper_failure_event,
          oper_status_missing
        ),
      by = c("code", "year")
    ) |>
    dplyr::group_by(stack_id, event_year, code) |>
    dplyr::summarise(
      focal_events_in_window = sum(focal_event, na.rm = TRUE),
      successes_in_window = sum(oper_success_event, na.rm = TRUE),
      failures_in_window = sum(oper_failure_event, na.rm = TRUE),
      missing_oper_status_in_window = sum(oper_status_missing, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::left_join(
      clean_treatment_events |> dplyr::select(stack_id, event_type, event_code),
      by = "stack_id"
    ) |>
    dplyr::mutate(
      is_event_municipality = code == event_code,
      is_never_treated = code %in% never_treated_codes
    )

  build_stack <- function(control_pool) {
    treatment_rows <- event_windows |>
      dplyr::transmute(
        stack_id, event_type, event_code, event_year, code = event_code, year, rel_year,
        treated_event = 1,
        control_pool = "treated",
        control_successes_in_window = NA_integer_,
        control_failures_in_window = NA_integer_,
        control_missing_oper_status_in_window = NA_integer_,
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
        stack_id, event_type, event_code, event_year, code,
        control_successes_in_window = successes_in_window,
        control_failures_in_window = failures_in_window,
        control_missing_oper_status_in_window = missing_oper_status_in_window,
        control_is_never_treated = is_never_treated
      ) |>
      tidyr::expand_grid(rel_year = event_times) |>
      dplyr::mutate(
        year = event_year + rel_year,
        treated_event = 0,
        control_pool = control_pool,
        .before = control_successes_in_window
      )

    dplyr::bind_rows(treatment_rows, control_rows) |>
      count_prior_history(event_variable) |>
      dplyr::left_join(
        panel |>
          dplyr::select(
            -oper_attempt_event, -oper_success_event, -oper_failure_event,
            -oper_status_missing
          ),
        by = c("code", "year")
      ) |>
      dplyr::mutate(
        years_since_last_focal_event_filled = tidyr::replace_na(years_since_last_focal_event, 99)
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

  clean_treatment_events <- clean_treatment_events |>
    dplyr::left_join(event_history, by = "stack_id")

  overall_counts <- panel |>
    dplyr::mutate(focal_event = .data[[event_variable]]) |>
    dplyr::group_by(code) |>
    dplyr::summarise(focal_event_years = sum(focal_event, na.rm = TRUE), .groups = "drop")

  stack_counts <- function(stack_data, sample_name) {
    row_counts <- stack_data |>
      dplyr::mutate(group = dplyr::if_else(treated_event == 1, "treated", "control")) |>
      dplyr::group_by(event_type, group, rel_year) |>
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
        control_successes_in_window, control_failures_in_window
      )

    pair_counts <- tibble::tibble(
      event_type = event_type,
      sample = sample_name,
      group = "control",
      rel_year = NA_integer_,
      metric = c(
        "control_event_municipality_pairs",
        "unique_control_municipalities",
        "share_control_pairs_never_treated",
        "control_pairs_with_success_oper_event",
        "control_pairs_with_failed_oper_event"
      ),
      value = c(
        nrow(control_pairs),
        dplyr::n_distinct(control_pairs$code),
        mean(control_pairs$control_is_never_treated),
        sum(control_pairs$control_successes_in_window > 0, na.rm = TRUE),
        sum(control_pairs$control_failures_in_window > 0, na.rm = TRUE)
      )
    )

    dplyr::bind_rows(pair_counts, row_counts)
  }

  sample_counts <- dplyr::bind_rows(
    tibble::tibble(
      event_type = event_type,
      sample = "overall",
      group = "all",
      rel_year = NA_integer_,
      metric = c(
        "focal_operating_event_years",
        "municipalities_with_focal_event",
        "treated_municipalities_one_focal_event_year",
        "treated_municipalities_multiple_focal_event_years",
        "clean_treatment_events",
        "clean_treated_municipalities",
        "candidate_events_dropped_for_nearby_focal_event",
        "clean_events_with_success_oper_event_in_window",
        "clean_events_with_failed_oper_event_in_window",
        "candidate_events_with_missing_oper_status_in_window"
      ),
      value = c(
        sum(panel[[event_variable]], na.rm = TRUE),
        sum(overall_counts$focal_event_years > 0),
        sum(overall_counts$focal_event_years == 1),
        sum(overall_counts$focal_event_years > 1),
        nrow(clean_treatment_events),
        dplyr::n_distinct(clean_treatment_events$event_code),
        sum(event_candidates$other_focal_events_in_window > 0),
        sum(clean_treatment_events$successes_in_window > 0),
        sum(clean_treatment_events$failures_in_window > 0),
        sum(event_candidates$missing_oper_status_in_window > 0)
      )
    ),
    stack_counts(stack_window_clean, "window_clean"),
    stack_counts(stack_never_treated, "never_treated")
  )

  list(
    events = clean_treatment_events,
    stack_window_clean = stack_window_clean,
    stack_never_treated = stack_never_treated,
    sample_counts = sample_counts
  )
}

fit_did <- function(data, formula, model_name) {
  df <- data |>
    tidyr::drop_na(MOO_num, code, year, stack_id, rel_year, treated_event)

  model <- tryCatch(
    fixest::feols(formula, data = df, vcov = ~ code),
    error = function(e) NULL
  )

  list(
    model_name = model_name,
    model = model,
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

extract_event_estimates <- function(fit, event_type) {
  if (is.null(fit$model)) {
    return(tibble::tibble())
  }

  estimates <- coefficient_table(fit$model) |>
    dplyr::filter(grepl("rel_year::", term), grepl("treated_event", term)) |>
    dplyr::mutate(
      event_type = event_type,
      event_time = as.integer(sub(".*rel_year::(-?[0-9]+).*", "\\1", term)),
      ci_lower = estimate - stats::qnorm(0.975) * std_error,
      ci_upper = estimate + stats::qnorm(0.975) * std_error,
      model = fit$model_name,
      nobs = fit$nobs,
      n_municipalities = fit$n_municipalities,
      n_stacks = fit$n_stacks,
      .before = model
    ) |>
    dplyr::select(
      event_type, model, event_time, term, estimate, std_error, p_value,
      ci_lower, ci_upper, nobs, n_municipalities, n_stacks
    )

  dplyr::bind_rows(
    tibble::tibble(
      event_type = event_type,
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
      n_stacks = fit$n_stacks
    ),
    estimates
  ) |>
    dplyr::arrange(event_type, model, event_time)
}

run_event_models <- function(event_type, event_label, file_stub, stack_data) {
  first_time_stacks <- stack_data$events |>
    dplyr::filter(prior_focal_event_count == 0) |>
    dplyr::pull(stack_id)

  main_fits <- list(
    window_clean_preferred = fit_did(
      stack_data$stack_window_clean,
      preferred_formula,
      "window_clean_preferred"
    ),
    window_clean_municipality_fe = fit_did(
      stack_data$stack_window_clean,
      municipality_formula,
      "window_clean_municipality_fe"
    ),
    window_clean_simple_fe = fit_did(
      stack_data$stack_window_clean,
      simple_formula,
      "window_clean_simple_fe"
    )
  )

  robustness_fits <- list(
    never_treated_controls = fit_did(
      stack_data$stack_never_treated,
      preferred_formula,
      "never_treated_controls"
    ),
    history_controls = fit_did(
      stack_data$stack_window_clean,
      history_formula,
      "history_controls"
    ),
    first_time_events = fit_did(
      stack_data$stack_window_clean |> dplyr::filter(stack_id %in% first_time_stacks),
      preferred_formula,
      "first_time_events"
    ),
    narrow_window = fit_did(
      stack_data$stack_window_clean |> dplyr::filter(rel_year %in% -1:1),
      preferred_formula,
      "narrow_window"
    )
  )

  main_results <- purrr::map_dfr(main_fits, extract_event_estimates, event_type = event_type)
  robustness_results <- purrr::map_dfr(robustness_fits, extract_event_estimates, event_type = event_type)

  plot_data <- main_results |>
    dplyr::filter(model == "window_clean_preferred", event_time %in% -2:2) |>
    dplyr::mutate(reference_period = event_time == -1)

  if (nrow(plot_data) > 0) {
    did_plot <- ggplot2::ggplot(plot_data, ggplot2::aes(x = event_time, y = estimate)) +
      ggplot2::geom_hline(yintercept = 0, linewidth = 0.4, color = "grey55") +
      ggplot2::geom_vline(xintercept = -1, linewidth = 0.4, color = "grey70", linetype = "dashed") +
      ggplot2::geom_errorbar(
        data = plot_data |> dplyr::filter(!reference_period),
        ggplot2::aes(ymin = ci_lower, ymax = ci_upper),
        width = 0.12,
        color = "#4f6f8f"
      ) +
      ggplot2::geom_point(size = 2.4, color = "#23395b") +
      ggplot2::scale_x_continuous(breaks = -2:2) +
      ggplot2::labs(
        x = paste("Years relative to", tolower(event_label)),
        y = "Estimated change in Moody's rating",
        title = paste("Repeated-Event DID:", event_label, "and Moody's Ratings"),
        subtitle = "Reference period is h = -1; controls have no same-type operating event in the local window"
      ) +
      ggplot2::theme_minimal(base_size = 11) +
      ggplot2::theme(panel.grid.minor = ggplot2::element_blank())

    ggplot2::ggsave(
      file.path(paths$figures, paste0("did_repeated_event_", file_stub, "_moodys.png")),
      did_plot,
      width = 7.5,
      height = 4.8,
      dpi = 300
    )
  }

  readr::write_csv(
    stack_data$sample_counts,
    file.path(paths$tables, paste0("did_repeated_event_", file_stub, "_sample_counts.csv"))
  )
  readr::write_csv(
    main_results,
    file.path(paths$tables, paste0("did_repeated_event_", file_stub, "_main.csv"))
  )
  readr::write_csv(
    robustness_results,
    file.path(paths$tables, paste0("did_repeated_event_", file_stub, "_robustness.csv"))
  )
  saveRDS(
    stack_data$events,
    file.path(paths$intermediate, paste0("did_repeated_event_", file_stub, "_events.rds"))
  )
  saveRDS(
    stack_data$stack_window_clean,
    file.path(paths$intermediate, paste0("did_repeated_event_", file_stub, "_stack_window_clean.rds"))
  )
  saveRDS(
    stack_data$stack_never_treated,
    file.path(paths$intermediate, paste0("did_repeated_event_", file_stub, "_stack_never_treated.rds"))
  )

  list(
    main_fits = main_fits,
    robustness_fits = robustness_fits,
    main_results = main_results,
    robustness_results = robustness_results,
    sample_counts = stack_data$sample_counts
  )
}

all_results <- purrr::pmap(
  event_definitions,
  function(event_type, event_variable, event_label, file_stub) {
    stack_data <- build_event_stack(event_type, event_variable, file_stub)
    run_event_models(event_type, event_label, file_stub, stack_data)
  }
)
names(all_results) <- event_definitions$event_type

readr::write_csv(
  dplyr::bind_rows(purrr::map(all_results, "sample_counts")),
  file.path(paths$tables, "did_repeated_event_attempt_failure_sample_counts.csv")
)
readr::write_csv(
  dplyr::bind_rows(purrr::map(all_results, "main_results")),
  file.path(paths$tables, "did_repeated_event_attempt_failure_main.csv")
)
readr::write_csv(
  dplyr::bind_rows(purrr::map(all_results, "robustness_results")),
  file.path(paths$tables, "did_repeated_event_attempt_failure_robustness.csv")
)
saveRDS(
  all_results,
  file.path(paths$intermediate, "did_repeated_event_attempt_failure_models.rds")
)
