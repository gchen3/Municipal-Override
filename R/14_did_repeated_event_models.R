source(file.path("R", "00_config.R"))
load_required_packages(c("dplyr", "tidyr", "purrr", "fixest", "ggplot2", "readr"))
make_output_dirs()

if (!file.exists(file.path(paths$intermediate, "did_repeated_event_stack_window_clean.rds"))) {
  source(file.path("R", "13_build_did_repeated_event_data.R"))
}

did_stack <- readRDS(file.path(paths$intermediate, "did_repeated_event_stack_window_clean.rds")) |>
  dplyr::mutate(
    years_since_last_oper_success_filled = tidyr::replace_na(years_since_last_oper_success, 99)
  )
did_stack_never <- readRDS(file.path(paths$intermediate, "did_repeated_event_stack_never_treated.rds")) |>
  dplyr::mutate(
    years_since_last_oper_success_filled = tidyr::replace_na(years_since_last_oper_success, 99)
  )
treatment_events <- readRDS(file.path(paths$intermediate, "did_repeated_event_treatment_events.rds"))

preferred_formula <- MOO_num ~ i(rel_year, treated_event, ref = -1) | stack_id^code + stack_id^year
municipality_formula <- MOO_num ~ i(rel_year, treated_event, ref = -1) | code + stack_id^year
simple_formula <- MOO_num ~ i(rel_year, treated_event, ref = -1) | stack_id + code + year
history_formula <- MOO_num ~
  i(rel_year, treated_event, ref = -1) +
  prior_oper_success_count + prior_oper_attempt_count +
  years_since_last_oper_success_filled + post_prior_success |
  code + stack_id^year

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

extract_event_estimates <- function(fit) {
  if (is.null(fit$model)) {
    return(tibble::tibble(
      model = fit$model_name,
      event_time = integer(),
      term = character(),
      estimate = numeric(),
      std_error = numeric(),
      p_value = numeric(),
      ci_lower = numeric(),
      ci_upper = numeric(),
      nobs = integer(),
      n_municipalities = integer(),
      n_stacks = integer()
    ))
  }

  estimates <- coefficient_table(fit$model) |>
    dplyr::filter(grepl("rel_year::", term), grepl("treated_event", term)) |>
    dplyr::mutate(
      event_time = as.integer(sub(".*rel_year::(-?[0-9]+).*", "\\1", term)),
      ci_lower = estimate - stats::qnorm(0.975) * std_error,
      ci_upper = estimate + stats::qnorm(0.975) * std_error,
      model = fit$model_name,
      nobs = fit$nobs,
      n_municipalities = fit$n_municipalities,
      n_stacks = fit$n_stacks,
      .before = event_time
    ) |>
    dplyr::select(
      model, event_time, term, estimate, std_error, p_value, ci_lower, ci_upper,
      nobs, n_municipalities, n_stacks
    )

  dplyr::bind_rows(
    tibble::tibble(
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
    dplyr::arrange(model, event_time)
}

first_time_treated_stacks <- treatment_events |>
  dplyr::filter(prior_oper_success_count == 0) |>
  dplyr::pull(stack_id)

no_nearby_failed_stacks <- treatment_events |>
  dplyr::filter(failed_attempts_in_window == 0) |>
  dplyr::pull(stack_id)

main_fits <- list(
  window_clean_preferred = fit_did(did_stack, preferred_formula, "window_clean_preferred"),
  window_clean_municipality_fe = fit_did(did_stack, municipality_formula, "window_clean_municipality_fe"),
  window_clean_simple_fe = fit_did(did_stack, simple_formula, "window_clean_simple_fe")
)

robustness_fits <- list(
  never_treated_controls = fit_did(did_stack_never, preferred_formula, "never_treated_controls"),
  history_controls = fit_did(did_stack, history_formula, "history_controls"),
  first_time_treated_events = fit_did(
    did_stack |> dplyr::filter(stack_id %in% first_time_treated_stacks),
    preferred_formula,
    "first_time_treated_events"
  ),
  narrow_window = fit_did(
    did_stack |> dplyr::filter(rel_year %in% -1:1),
    preferred_formula,
    "narrow_window"
  ),
  exclude_nearby_failed_oper_attempts = fit_did(
    did_stack |> dplyr::filter(stack_id %in% no_nearby_failed_stacks),
    preferred_formula,
    "exclude_nearby_failed_oper_attempts"
  )
)

main_results <- purrr::map_dfr(main_fits, extract_event_estimates)
robustness_results <- purrr::map_dfr(robustness_fits, extract_event_estimates)

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
      x = "Years relative to successful operating override",
      y = "Estimated change in Moody's rating",
      title = "Repeated-Event DID: Operating Override Passage and Moody's Ratings",
      subtitle = "Reference period is h = -1; controls have no successful operating override in the local window"
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())

  ggplot2::ggsave(
    file.path(paths$figures, "did_repeated_event_moodys.png"),
    did_plot,
    width = 7.5,
    height = 4.8,
    dpi = 300
  )
}

readr::write_csv(
  main_results,
  file.path(paths$tables, "did_repeated_event_main.csv")
)
readr::write_csv(
  robustness_results,
  file.path(paths$tables, "did_repeated_event_robustness.csv")
)
saveRDS(
  list(
    main_fits = main_fits,
    robustness_fits = robustness_fits,
    main_results = main_results,
    robustness_results = robustness_results
  ),
  file.path(paths$intermediate, "did_repeated_event_models.rds")
)
