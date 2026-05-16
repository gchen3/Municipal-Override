source(file.path("R", "00_config.R"))
load_required_packages(c("dplyr", "tidyr", "purrr", "fixest", "ggplot2", "readr", "rdrobust", "rddensity"))
make_output_dirs()

if (!file.exists(file.path(paths$intermediate, "rd_question_level_data.rds"))) {
  source(file.path("R", "09_build_rd_data.R"))
}

rd_data <- readRDS(file.path(paths$intermediate, "rd_question_level_data.rds"))
main_horizons <- 1:5

empty_rd_row <- function(check, outcome, sample_name, horizon = NA_integer_, bandwidth = NA_real_) {
  tibble::tibble(
    check = check,
    outcome = outcome,
    rd_sample = sample_name,
    h = horizon,
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
  if (is.matrix(fit$bws) || is.data.frame(fit$bws)) {
    row_id <- match("h", rownames(fit$bws), nomatch = 1L)
    return(mean(abs(as.numeric(fit$bws[row_id, ])), na.rm = TRUE))
  }
  as.numeric(utils::head(fit$bws, 1))
}

density_test_values <- function(fit) {
  test <- fit$test
  if (is.null(test)) {
    return(c(statistic = NA_real_, p_value = NA_real_))
  }
  if (is.matrix(test) || is.data.frame(test)) {
    statistic_column <- intersect(c("t_jk", "t_asy", "statistic", "t"), colnames(test))[1]
    p_value_column <- intersect(c("p_jk", "p_asy", "p_value", "pv", "p"), colnames(test))[1]
    row_id <- if ("Robust" %in% rownames(test)) match("Robust", rownames(test)) else nrow(test)
    return(c(
      statistic = if (!is.na(statistic_column)) as.numeric(test[row_id, statistic_column]) else NA_real_,
      p_value = if (!is.na(p_value_column)) as.numeric(test[row_id, p_value_column]) else NA_real_
    ))
  }
  if (!is.null(names(test))) {
    statistic_name <- intersect(c("t_jk", "t_asy", "statistic", "t"), names(test))[1]
    p_value_name <- intersect(c("p_jk", "p_asy", "p_value", "pv", "p"), names(test))[1]
    return(c(
      statistic = if (!is.na(statistic_name)) as.numeric(test[statistic_name]) else NA_real_,
      p_value = if (!is.na(p_value_name)) as.numeric(test[p_value_name]) else NA_real_
    ))
  }
  c(statistic = NA_real_, p_value = NA_real_)
}

fit_rdrobust_outcome <- function(data, outcome, sample_name, horizon = NA_integer_,
                                 check = "rdrobust", running_var = "margin",
                                 donut = 0, cutoff = 0) {
  df <- data |>
    dplyr::filter(rd_sample == sample_name) |>
    dplyr::filter(if (is.na(horizon)) TRUE else h == horizon) |>
    dplyr::filter(abs(.data[[running_var]] - cutoff) > donut) |>
    tidyr::drop_na(dplyr::all_of(c(outcome, running_var, "code")))

  if (nrow(df) < 20 || sum(df[[running_var]] < cutoff) == 0 || sum(df[[running_var]] >= cutoff) == 0) {
    return(empty_rd_row(check, outcome, sample_name, horizon))
  }

  fit <- tryCatch(
    rdrobust::rdrobust(
      y = df[[outcome]],
      x = df[[running_var]],
      c = cutoff,
      p = 1,
      kernel = "triangular",
      cluster = df$code
    ),
    error = function(e) {
      tryCatch(
        rdrobust::rdrobust(
          y = df[[outcome]],
          x = df[[running_var]],
          c = cutoff,
          p = 1,
          kernel = "triangular"
        ),
        error = function(e) NULL
      )
    }
  )
  if (is.null(fit)) {
    return(empty_rd_row(check, outcome, sample_name, horizon))
  }

  tibble::tibble(
    check = check,
    outcome = outcome,
    rd_sample = sample_name,
    h = horizon,
    bandwidth = rd_bandwidth(fit),
    estimate = rd_matrix_value(fit$coef),
    std_error = rd_matrix_value(fit$se),
    p_value = rd_matrix_value(fit$pv),
    ci_lower = rd_matrix_value(fit$ci, column = 1L),
    ci_upper = rd_matrix_value(fit$ci, column = 2L),
    nobs = nrow(df),
    n_left = sum(df[[running_var]] < cutoff),
    n_right = sum(df[[running_var]] >= cutoff)
  )
}

fit_manual_bandwidth <- function(data, outcome, sample_name, horizon, bandwidth,
                                 check = "bandwidth_sensitivity") {
  df <- data |>
    dplyr::filter(rd_sample == sample_name, h == horizon, abs(margin) <= bandwidth) |>
    tidyr::drop_na(dplyr::all_of(c(outcome, "margin", "passed", "code")))

  if (nrow(df) < 20 || dplyr::n_distinct(df$passed) < 2) {
    return(empty_rd_row(check, outcome, sample_name, horizon, bandwidth))
  }

  formula <- stats::as.formula(paste(outcome, "~ passed + margin + passed:margin"))
  fit <- tryCatch(fixest::feols(formula, data = df, vcov = ~ code), error = function(e) NULL)
  if (is.null(fit) || !"passed" %in% rownames(fixest::coeftable(fit))) {
    return(empty_rd_row(check, outcome, sample_name, horizon, bandwidth))
  }

  coefficient_table <- fixest::coeftable(fit)
  estimate <- coefficient_table["passed", "Estimate"]
  std_error <- coefficient_table["passed", "Std. Error"]

  tibble::tibble(
    check = check,
    outcome = outcome,
    rd_sample = sample_name,
    h = horizon,
    bandwidth = bandwidth,
    estimate = estimate,
    std_error = std_error,
    p_value = coefficient_table["passed", "Pr(>|t|)"],
    ci_lower = estimate - stats::qnorm(0.975) * std_error,
    ci_upper = estimate + stats::qnorm(0.975) * std_error,
    nobs = nrow(df),
    n_left = sum(df$margin < 0),
    n_right = sum(df$margin >= 0)
  )
}

operating_questions <- rd_data |>
  dplyr::filter(rd_sample == "operating") |>
  dplyr::distinct(question_id, .keep_all = TRUE)

density_fit <- rddensity::rddensity(X = operating_questions$margin, c = 0)
density_values <- density_test_values(density_fit)
density_test <- tibble::tibble(
  statistic = density_values[["statistic"]],
  p_value = density_values[["p_value"]],
  n_left = sum(operating_questions$margin < 0),
  n_right = sum(operating_questions$margin >= 0)
)

readr::write_csv(density_test, file.path(paths$tables, "rd_density_test.csv"))

balance_outcomes <- intersect(
  c(
    "MOO_num", "pre_MOO_num", "pre_logpopu", "pre_debtbudg", "pre_unemploy",
    "pre_revstab", "pre_revperca", "pre_expperca", "pre_unabsorbedratio",
    "pre_balance"
  ),
  names(rd_data)
)

balance_checks <- purrr::map_dfr(
  balance_outcomes,
  ~ fit_rdrobust_outcome(
    rd_data,
    outcome = .x,
    sample_name = "operating",
    horizon = if (.x == "MOO_num") -1L else NA_integer_,
    check = "balance"
  )
)
readr::write_csv(balance_checks, file.path(paths$tables, "rd_balance_checks.csv"))

placebo_cutoffs <- c(0.40, 0.45, 0.55, 0.60)
placebo_data <- rd_data |>
  dplyr::mutate(approval_rate_centered = approval_rate)

placebo_checks <- purrr::map_dfr(
  placebo_cutoffs,
  function(cutoff) {
    purrr::map_dfr(
      main_horizons,
      ~ fit_rdrobust_outcome(
        placebo_data,
        outcome = "MOO_num",
        sample_name = "operating",
        horizon = .x,
        check = paste0("placebo_cutoff_", cutoff),
        running_var = "approval_rate_centered",
        cutoff = cutoff
      )
    )
  }
)
readr::write_csv(placebo_checks, file.path(paths$tables, "rd_placebo_cutoffs.csv"))

donut_widths <- c(0.0025, 0.005)
donut_checks <- purrr::map_dfr(
  donut_widths,
  function(width) {
    purrr::map_dfr(
      main_horizons,
      ~ fit_rdrobust_outcome(
        rd_data,
        outcome = "MOO_num",
        sample_name = "operating",
        horizon = .x,
        check = paste0("donut_", 100 * width, "pp"),
        donut = width
      )
    )
  }
)
readr::write_csv(donut_checks, file.path(paths$tables, "rd_donut_checks.csv"))

selected_bandwidths <- c(0.025, 0.05, 0.10)
fixed_bandwidths <- tibble::tibble(
  bandwidth_type = paste0(100 * selected_bandwidths, "pp"),
  bandwidth = selected_bandwidths
)
primary_bandwidths <- purrr::map_dfr(
  main_horizons,
  ~ fit_rdrobust_outcome(
    rd_data,
    outcome = "MOO_num",
    sample_name = "operating",
    horizon = .x,
    check = "primary_bandwidth"
  )
) |>
  dplyr::transmute(
    h,
    bandwidth_type = "rdrobust",
    bandwidth
  )

bandwidth_grid <- dplyr::bind_rows(
  tidyr::expand_grid(
    h = main_horizons,
    fixed_bandwidths
  ),
  primary_bandwidths |>
    dplyr::filter(is.finite(bandwidth)) |>
    dplyr::mutate(bandwidth_type = "half_rdrobust", bandwidth = bandwidth / 2),
  primary_bandwidths |>
    dplyr::filter(is.finite(bandwidth)) |>
    dplyr::mutate(bandwidth_type = "double_rdrobust", bandwidth = bandwidth * 2)
)

bandwidth_sensitivity <- purrr::pmap_dfr(
  bandwidth_grid,
  function(h, bandwidth_type, bandwidth) {
    fit_manual_bandwidth(
      rd_data,
      outcome = "MOO_num",
      sample_name = "operating",
      horizon = h,
      bandwidth = bandwidth,
      check = bandwidth_type
    )
  }
)
readr::write_csv(bandwidth_sensitivity, file.path(paths$tables, "rd_bandwidth_sensitivity.csv"))

density_plot <- ggplot2::ggplot(operating_questions, ggplot2::aes(x = margin_pp)) +
  ggplot2::geom_histogram(binwidth = 2.5, boundary = 0, fill = "#6f8aa6", color = "white") +
  ggplot2::geom_vline(xintercept = 0, linewidth = 0.5, color = "#7a2e2e") +
  ggplot2::labs(
    x = "Approval margin from 50% cutoff (percentage points)",
    y = "Operating override questions",
    title = "Density of Operating Override Vote Margins"
  ) +
  ggplot2::theme_minimal(base_size = 11) +
  ggplot2::theme(panel.grid.minor = ggplot2::element_blank())

ggplot2::ggsave(
  file.path(paths$figures, "rd_density_margin.png"),
  density_plot,
  width = 7,
  height = 4.5,
  dpi = 300
)

binned_plot_data <- rd_data |>
  dplyr::filter(rd_sample == "operating", h == 1, abs(margin_pp) <= 20) |>
  tidyr::drop_na(MOO_num, margin_pp) |>
  dplyr::mutate(bin = floor(margin_pp / 2.5) * 2.5 + 1.25) |>
  dplyr::group_by(bin) |>
  dplyr::summarise(
    MOO_num = mean(MOO_num, na.rm = TRUE),
    observations = dplyr::n(),
    .groups = "drop"
  )

if (nrow(binned_plot_data) > 0) {
  binned_plot <- ggplot2::ggplot(binned_plot_data, ggplot2::aes(x = bin, y = MOO_num)) +
    ggplot2::geom_vline(xintercept = 0, linewidth = 0.5, color = "#7a2e2e") +
    ggplot2::geom_point(ggplot2::aes(size = observations), color = "#23395b", alpha = 0.85) +
    ggplot2::geom_smooth(data = rd_data |>
      dplyr::filter(rd_sample == "operating", h == 1, margin < 0, abs(margin_pp) <= 20),
    ggplot2::aes(x = margin_pp, y = MOO_num),
    method = "lm", formula = y ~ x, se = FALSE, color = "#4f6f8f"
    ) +
    ggplot2::geom_smooth(data = rd_data |>
      dplyr::filter(rd_sample == "operating", h == 1, margin >= 0, abs(margin_pp) <= 20),
    ggplot2::aes(x = margin_pp, y = MOO_num),
    method = "lm", formula = y ~ x, se = FALSE, color = "#4f6f8f"
    ) +
    ggplot2::scale_size_continuous(range = c(1.5, 5), guide = "none") +
    ggplot2::labs(
      x = "Approval margin from 50% cutoff (percentage points)",
      y = "Moody's rating, h = 1",
      title = "Binned RD Plot for Moody's Rating"
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())

  ggplot2::ggsave(
    file.path(paths$figures, "rd_moodys_binned_plot.png"),
    binned_plot,
    width = 7,
    height = 4.5,
    dpi = 300
  )
}
