source(file.path("R", "00_config.R"))
load_required_packages(c("dplyr", "tidyr", "purrr", "fixest", "ggplot2", "readr", "rdrobust"))
make_output_dirs()

if (!file.exists(file.path(paths$intermediate, "rd_question_level_data.rds"))) {
  source(file.path("R", "09_build_rd_data.R"))
}

rd_data <- readRDS(file.path(paths$intermediate, "rd_question_level_data.rds"))
main_horizons <- 1:5
event_horizons <- c(-5:-1, 1:5)
stress_definitions <- tibble::tibble(
  stress_variable = c("pre_highfiscal1", "pre_highfiscal3"),
  stress_definition = c("low_reserve", "high_debt"),
  stress_label = c("Low fiscal reserve", "High debt")
)

empty_estimate <- function(sample_name, horizon, estimator, bandwidth = NA_real_) {
  tibble::tibble(
    rd_sample = sample_name,
    h = horizon,
    estimator = estimator,
    bandwidth = bandwidth,
    estimate = NA_real_,
    std_error = NA_real_,
    p_value = NA_real_,
    ci_lower = NA_real_,
    ci_upper = NA_real_,
    nobs = 0L,
    n_left = NA_integer_,
    n_right = NA_integer_
  )
}

rd_matrix_value <- function(x, row_name = "Robust", column = 1L) {
  if (is.null(x)) {
    return(NA_real_)
  }
  if (is.matrix(x) || is.data.frame(x)) {
    row_id <- match(row_name, rownames(x), nomatch = nrow(x))
    return(as.numeric(x[row_id, column]))
  }
  as.numeric(utils::tail(x, 1))
}

rd_bandwidth <- function(fit) {
  if (is.null(fit$bws)) {
    return(NA_real_)
  }
  bws <- fit$bws
  if (is.matrix(bws) || is.data.frame(bws)) {
    row_id <- match("h", rownames(bws), nomatch = 1L)
    return(mean(abs(as.numeric(bws[row_id, ])), na.rm = TRUE))
  }
  as.numeric(utils::head(bws, 1))
}

rd_n_side <- function(fit, side) {
  if (!is.null(fit$N_h)) {
    return(as.integer(fit$N_h[side]))
  }
  if (!is.null(fit$N)) {
    return(as.integer(fit$N[side]))
  }
  NA_integer_
}

fit_rdrobust_estimate <- function(data, sample_name, horizon, covariates = NULL) {
  df <- data |>
    dplyr::filter(rd_sample == sample_name, h == horizon) |>
    tidyr::drop_na(MOO_num, margin, passed, code)

  if (nrow(df) < 20 || dplyr::n_distinct(df$passed) < 2) {
    return(list(result = empty_estimate(sample_name, horizon, "rdrobust"), model = NULL))
  }

  covs <- NULL
  if (!is.null(covariates)) {
    covs <- covariates(df)
  }

  fit <- tryCatch(
    rdrobust::rdrobust(
      y = df$MOO_num,
      x = df$margin,
      c = 0,
      p = 1,
      kernel = "triangular",
      cluster = df$code,
      covs = covs
    ),
    error = function(e) {
      tryCatch(
        rdrobust::rdrobust(
          y = df$MOO_num,
          x = df$margin,
          c = 0,
          p = 1,
          kernel = "triangular",
          covs = covs
        ),
        error = function(e) NULL
      )
    }
  )
  if (is.null(fit)) {
    return(list(result = empty_estimate(sample_name, horizon, "rdrobust"), model = NULL))
  }

  estimate <- rd_matrix_value(fit$coef)
  std_error <- rd_matrix_value(fit$se)
  p_value <- rd_matrix_value(fit$pv)
  ci_lower <- rd_matrix_value(fit$ci, column = 1L)
  ci_upper <- rd_matrix_value(fit$ci, column = 2L)

  result <- tibble::tibble(
    rd_sample = sample_name,
    h = horizon,
    estimator = "rdrobust",
    bandwidth = rd_bandwidth(fit),
    estimate = estimate,
    std_error = std_error,
    p_value = p_value,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    nobs = nrow(df),
    n_left = rd_n_side(fit, 1L),
    n_right = rd_n_side(fit, 2L)
  )

  list(result = result, model = fit)
}

fit_manual_estimate <- function(data, sample_name, horizon, bandwidth = 0.05) {
  df <- data |>
    dplyr::filter(rd_sample == sample_name, h == horizon, abs(margin) <= bandwidth) |>
    tidyr::drop_na(MOO_num, margin, passed, code)

  if (nrow(df) < 20 || dplyr::n_distinct(df$passed) < 2) {
    return(list(result = empty_estimate(sample_name, horizon, "manual_local_linear", bandwidth), model = NULL))
  }

  formula <- if (sample_name == "all_types" && dplyr::n_distinct(df$Override) > 1) {
    MOO_num ~ passed + margin + passed:margin + factor(Override)
  } else {
    MOO_num ~ passed + margin + passed:margin
  }

  fit <- tryCatch(
    fixest::feols(formula, data = df, vcov = ~ code),
    error = function(e) NULL
  )
  if (is.null(fit) || !"passed" %in% rownames(fixest::coeftable(fit))) {
    return(list(result = empty_estimate(sample_name, horizon, "manual_local_linear", bandwidth), model = fit))
  }

  coefficient_table <- fixest::coeftable(fit)
  estimate <- coefficient_table["passed", "Estimate"]
  std_error <- coefficient_table["passed", "Std. Error"]
  p_value <- coefficient_table["passed", "Pr(>|t|)"]

  result <- tibble::tibble(
    rd_sample = sample_name,
    h = horizon,
    estimator = "manual_local_linear",
    bandwidth = bandwidth,
    estimate = estimate,
    std_error = std_error,
    p_value = p_value,
    ci_lower = estimate - stats::qnorm(0.975) * std_error,
    ci_upper = estimate + stats::qnorm(0.975) * std_error,
    nobs = nrow(df),
    n_left = sum(df$margin < 0),
    n_right = sum(df$margin >= 0)
  )

  list(result = result, model = fit)
}

type_covariates <- function(df) {
  if (dplyr::n_distinct(df$Override) <= 1) {
    return(NULL)
  }
  stats::model.matrix(~ factor(Override), data = df)[, -1, drop = FALSE]
}

fit_sample <- function(sample_name) {
  rdrobust_fits <- purrr::map(
    main_horizons,
    ~ fit_rdrobust_estimate(
      rd_data,
      sample_name,
      .x,
      covariates = if (sample_name == "all_types") type_covariates else NULL
    )
  )
  manual_fits <- purrr::map(main_horizons, ~ fit_manual_estimate(rd_data, sample_name, .x, 0.05))

  list(
    estimates = dplyr::bind_rows(
      purrr::map(rdrobust_fits, "result"),
      purrr::map(manual_fits, "result")
    ),
    rdrobust_models = purrr::map(rdrobust_fits, "model"),
    manual_models = purrr::map(manual_fits, "model")
  )
}

operating_models <- fit_sample("operating")
all_type_models <- fit_sample("all_types")

fit_event_path <- function(sample_name) {
  event_fits <- purrr::map(
    event_horizons,
    ~ fit_rdrobust_estimate(
      rd_data,
      sample_name,
      .x,
      covariates = if (sample_name == "all_types") type_covariates else NULL
    )
  )
  dplyr::bind_rows(purrr::map(event_fits, "result"))
}

operating_event_path <- fit_event_path("operating")
all_type_event_path <- fit_event_path("all_types")

readr::write_csv(
  operating_models$estimates,
  file.path(paths$tables, "rd_event_study_operating.csv")
)
readr::write_csv(
  all_type_models$estimates,
  file.path(paths$tables, "rd_event_study_all_types.csv")
)
readr::write_csv(
  operating_event_path,
  file.path(paths$tables, "rd_event_study_operating_pre_post.csv")
)
readr::write_csv(
  all_type_event_path,
  file.path(paths$tables, "rd_event_study_all_types_pre_post.csv")
)

plot_data <- operating_models$estimates |>
  dplyr::filter(estimator == "rdrobust", is.finite(estimate), h %in% main_horizons)

if (nrow(plot_data) == 0) {
  plot_data <- operating_models$estimates |>
    dplyr::filter(estimator == "manual_local_linear", is.finite(estimate), h %in% main_horizons)
}

if (nrow(plot_data) > 0) {
  event_study_plot <- ggplot2::ggplot(plot_data, ggplot2::aes(x = h, y = estimate)) +
    ggplot2::geom_hline(yintercept = 0, linewidth = 0.4, color = "grey55") +
    ggplot2::geom_errorbar(
      ggplot2::aes(ymin = ci_lower, ymax = ci_upper),
      width = 0.12,
      color = "#4f6f8f"
    ) +
    ggplot2::geom_point(size = 2.4, color = "#23395b") +
    ggplot2::scale_x_continuous(breaks = main_horizons) +
    ggplot2::labs(
      x = "Years after override vote",
      y = "RD estimate for Moody's rating",
      title = "Operating Override Passage and Moody's Ratings"
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())

  ggplot2::ggsave(
    file.path(paths$figures, "rd_event_study_moodys.png"),
    event_study_plot,
    width = 7,
    height = 4.5,
    dpi = 300
  )
}

pre_post_plot_data <- operating_event_path |>
  dplyr::filter(estimator == "rdrobust", is.finite(estimate), h %in% event_horizons)

if (nrow(pre_post_plot_data) > 0) {
  pre_post_plot <- ggplot2::ggplot(pre_post_plot_data, ggplot2::aes(x = h, y = estimate)) +
    ggplot2::geom_hline(yintercept = 0, linewidth = 0.4, color = "grey55") +
    ggplot2::geom_vline(xintercept = 0, linewidth = 0.4, color = "grey70", linetype = "dashed") +
    ggplot2::geom_errorbar(
      ggplot2::aes(ymin = ci_lower, ymax = ci_upper),
      width = 0.12,
      color = "#4f6f8f"
    ) +
    ggplot2::geom_point(
      ggplot2::aes(shape = h < 0),
      size = 2.4,
      color = "#23395b",
      show.legend = FALSE
    ) +
    ggplot2::scale_x_continuous(breaks = event_horizons) +
    ggplot2::labs(
      x = "Years relative to override vote",
      y = "RD estimate for Moody's rating",
      title = "Operating Override Passage and Moody's Ratings",
      subtitle = "Negative horizons are pre-treatment placebo outcomes"
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())

  ggplot2::ggsave(
    file.path(paths$figures, "rd_event_study_moodys_pre_post.png"),
    pre_post_plot,
    width = 7.5,
    height = 4.8,
    dpi = 300
  )
}

stress_group_estimates <- purrr::pmap_dfr(
  stress_definitions,
  function(stress_variable, stress_definition, stress_label) {
    purrr::map_dfr(
      c(0, 1),
      function(stress_value) {
        stress_data <- rd_data |>
          dplyr::filter(.data[[stress_variable]] == stress_value)

        purrr::map_dfr(
          event_horizons,
          function(horizon) {
            fit_rdrobust_estimate(stress_data, "operating", horizon)$result |>
              dplyr::mutate(
                stress_definition = stress_definition,
                stress_label = stress_label,
                stress_variable = stress_variable,
                stress_value = stress_value,
                stress_group = dplyr::if_else(stress_value == 1, "Stressed", "Not stressed"),
                .before = rd_sample
              )
          }
        )
      }
    )
  }
)

fit_stress_interaction <- function(data, stress_variable, stress_definition, stress_label,
                                   horizon, bandwidth) {
  df <- data |>
    dplyr::filter(
      rd_sample == "operating",
      h == horizon,
      abs(margin) <= bandwidth
    ) |>
    dplyr::mutate(stress = .data[[stress_variable]]) |>
    tidyr::drop_na(MOO_num, margin, passed, stress, code)

  empty_result <- tibble::tibble(
    stress_definition = stress_definition,
    stress_label = stress_label,
    stress_variable = stress_variable,
    h = horizon,
    bandwidth = bandwidth,
    estimate = NA_real_,
    std_error = NA_real_,
    p_value = NA_real_,
    ci_lower = NA_real_,
    ci_upper = NA_real_,
    nobs = nrow(df),
    n_stressed = sum(df$stress == 1),
    n_not_stressed = sum(df$stress == 0),
    n_left = sum(df$margin < 0),
    n_right = sum(df$margin >= 0)
  )

  if (
    nrow(df) < 30 ||
      dplyr::n_distinct(df$passed) < 2 ||
      dplyr::n_distinct(df$stress) < 2 ||
      any(table(df$passed, df$stress) == 0)
  ) {
    return(empty_result)
  }

  fit <- tryCatch(
    fixest::feols(
      MOO_num ~ passed * stress + margin * stress + passed:margin + passed:stress:margin,
      data = df,
      vcov = ~ code
    ),
    error = function(e) NULL
  )
  if (is.null(fit) || !"passed:stress" %in% rownames(fixest::coeftable(fit))) {
    return(empty_result)
  }

  coefficient_table <- fixest::coeftable(fit)
  term_estimate <- coefficient_table["passed:stress", "Estimate"]
  term_std_error <- coefficient_table["passed:stress", "Std. Error"]

  empty_result |>
    dplyr::mutate(
      estimate = term_estimate,
      std_error = term_std_error,
      p_value = coefficient_table["passed:stress", "Pr(>|t|)"],
      ci_lower = term_estimate - stats::qnorm(0.975) * term_std_error,
      ci_upper = term_estimate + stats::qnorm(0.975) * term_std_error
    )
}

stress_interaction_tests <- purrr::pmap_dfr(
  stress_definitions,
  function(stress_variable, stress_definition, stress_label) {
    tidyr::expand_grid(h = event_horizons, bandwidth = c(0.025, 0.05, 0.10)) |>
      purrr::pmap_dfr(
        ~ fit_stress_interaction(
          rd_data,
          stress_variable = stress_variable,
          stress_definition = stress_definition,
          stress_label = stress_label,
          horizon = ..1,
          bandwidth = ..2
        )
      )
  }
)

stress_sample_counts <- purrr::pmap_dfr(
  stress_definitions,
  function(stress_variable, stress_definition, stress_label) {
    rd_data |>
      dplyr::filter(rd_sample == "operating", h %in% event_horizons) |>
      dplyr::mutate(
        stress_definition = stress_definition,
        stress_label = stress_label,
        stress_variable = stress_variable,
        stress_value = .data[[stress_variable]],
        stress_group = dplyr::case_when(
          stress_value == 1 ~ "Stressed",
          stress_value == 0 ~ "Not stressed",
          TRUE ~ "Missing stress"
        ),
        cutoff_side = dplyr::if_else(margin < 0, "Below cutoff", "At/above cutoff")
      ) |>
      dplyr::group_by(stress_definition, stress_label, stress_variable, stress_value, stress_group, h, cutoff_side) |>
      dplyr::summarise(
        observations = dplyr::n(),
        nonmissing_moodys = sum(!is.na(MOO_num)),
        close_5pp = sum(abs(margin) <= 0.05 & !is.na(MOO_num)),
        .groups = "drop"
      )
  }
)

readr::write_csv(
  stress_group_estimates,
  file.path(paths$tables, "rd_event_study_operating_by_stress.csv")
)
readr::write_csv(
  stress_interaction_tests,
  file.path(paths$tables, "rd_stress_interaction_tests.csv")
)
readr::write_csv(
  stress_sample_counts,
  file.path(paths$tables, "rd_stress_sample_counts.csv")
)

plot_stress_event_study <- function(stress_definition, output_file, title) {
  plot_df <- stress_group_estimates |>
    dplyr::filter(
      .data$stress_definition == stress_definition,
      estimator == "rdrobust",
      is.finite(estimate)
    )

  if (nrow(plot_df) == 0) {
    return(invisible(NULL))
  }

  plot <- ggplot2::ggplot(
    plot_df,
    ggplot2::aes(x = h, y = estimate, color = stress_group)
  ) +
    ggplot2::geom_hline(yintercept = 0, linewidth = 0.4, color = "grey55") +
    ggplot2::geom_vline(xintercept = 0, linewidth = 0.4, color = "grey70", linetype = "dashed") +
    ggplot2::geom_errorbar(
      ggplot2::aes(ymin = ci_lower, ymax = ci_upper),
      width = 0.12,
      position = ggplot2::position_dodge(width = 0.35)
    ) +
    ggplot2::geom_point(
      ggplot2::aes(shape = h < 0),
      size = 2.2,
      position = ggplot2::position_dodge(width = 0.35)
    ) +
    ggplot2::scale_color_manual(values = c("Not stressed" = "#4f6f8f", "Stressed" = "#8f4f4f")) +
    ggplot2::scale_x_continuous(breaks = event_horizons) +
    ggplot2::labs(
      x = "Years relative to override vote",
      y = "RD estimate for Moody's rating",
      color = NULL,
      shape = NULL,
      title = title,
      subtitle = "Negative horizons are pre-treatment placebo outcomes"
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      legend.position = "bottom",
      panel.grid.minor = ggplot2::element_blank()
    )

  ggplot2::ggsave(
    file.path(paths$figures, output_file),
    plot,
    width = 8,
    height = 5,
    dpi = 300
  )
}

plot_stress_event_study(
  "low_reserve",
  "rd_event_study_moodys_low_reserve_stress.png",
  "Operating Override RD by Low-Reserve Fiscal Stress"
)
plot_stress_event_study(
  "high_debt",
  "rd_event_study_moodys_high_debt_stress.png",
  "Operating Override RD by High-Debt Fiscal Stress"
)

stress_contrasts <- stress_group_estimates |>
  dplyr::filter(is.finite(estimate)) |>
  dplyr::select(stress_definition, stress_label, h, stress_group, estimate) |>
  tidyr::pivot_wider(names_from = stress_group, values_from = estimate) |>
  dplyr::filter(!is.na(Stressed), !is.na(`Not stressed`)) |>
  dplyr::mutate(estimate_difference = Stressed - `Not stressed`)

if (nrow(stress_contrasts) > 0) {
  contrast_plot <- ggplot2::ggplot(
    stress_contrasts,
    ggplot2::aes(x = h, y = estimate_difference, color = stress_label)
  ) +
    ggplot2::geom_hline(yintercept = 0, linewidth = 0.4, color = "grey55") +
    ggplot2::geom_vline(xintercept = 0, linewidth = 0.4, color = "grey70", linetype = "dashed") +
    ggplot2::geom_line(linewidth = 0.5) +
    ggplot2::geom_point(size = 2) +
    ggplot2::scale_color_manual(values = c("Low fiscal reserve" = "#8f4f4f", "High debt" = "#4f6f8f")) +
    ggplot2::scale_x_continuous(breaks = event_horizons) +
    ggplot2::labs(
      x = "Years relative to override vote",
      y = "Stressed minus non-stressed RD estimate",
      color = NULL,
      title = "Exploratory Fiscal-Stress RD Contrasts"
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      legend.position = "bottom",
      panel.grid.minor = ggplot2::element_blank()
    )

  ggplot2::ggsave(
    file.path(paths$figures, "rd_event_study_moodys_stress_contrasts.png"),
    contrast_plot,
    width = 8,
    height = 4.8,
    dpi = 300
  )
}

saveRDS(
  list(
    operating = operating_models,
    all_types = all_type_models,
    operating_event_path = operating_event_path,
    all_type_event_path = all_type_event_path,
    stress_group_estimates = stress_group_estimates,
    stress_interaction_tests = stress_interaction_tests,
    stress_sample_counts = stress_sample_counts
  ),
  file.path(paths$intermediate, "rd_main_models.rds")
)
