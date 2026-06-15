source(file.path("R", "00_config.R"))
load_required_packages(c("dplyr", "tidyr", "purrr", "fixest", "ggplot2", "readr"))
make_output_dirs()
source(file.path("R", "active_helpers.R"))
source(file.path("R", "close_election_helpers.R"))

if (!file.exists(file.path(paths$intermediate, "active_operating_close_election_data.rds"))) {
  source(file.path("R", "16_build_close_election_data.R"))
}

panel <- readRDS(file.path(paths$intermediate, "data_for_regression.rds"))
analysis_data <- readRDS(file.path(paths$intermediate, "active_operating_close_election_data.rds"))
moo_vec <- moo_lookup(panel)

working <- analysis_data |> dplyr::filter(band == close_election_working_band)

# Covariate balance across close successes and close failures.
balance_var <- function(df, variable) {
  by_group <- df |>
    dplyr::filter(!is.na(.data[[variable]])) |>
    dplyr::group_by(close_success) |>
    dplyr::summarise(mean = mean(.data[[variable]]), n = dplyr::n(), .groups = "drop")
  mean_success <- by_group$mean[by_group$close_success == 1]
  mean_failure <- by_group$mean[by_group$close_success == 0]
  p_value <- tryCatch(
    stats::t.test(df[[variable]] ~ df$close_success)$p.value,
    error = function(e) NA_real_
  )
  tibble::tibble(
    variable = variable,
    mean_failure = mean_failure,
    mean_success = mean_success,
    difference = mean_success - mean_failure,
    p_value = p_value,
    n_failure = by_group$n[by_group$close_success == 0],
    n_success = by_group$n[by_group$close_success == 1]
  )
}

balance_table <- purrr::map_dfr(
  c("moo_baseline", active_controls),
  ~ balance_var(working, .x)
) |>
  dplyr::mutate(dplyr::across(c(mean_failure, mean_success, difference), ~ round(.x, 3)),
                p_value = signif(p_value, 3))

# Pre-election rating-change placebo: a downgrade or upgrade in the two years
# before the model year (t0 - 3 to t0 - 1, fully pre-outcome) should not be
# predicted by close_success.
pre_base <- rating_at(moo_vec, working$code, working$model_year - 3L)
pre_end <- rating_at(moo_vec, working$code, working$model_year - 1L)
working <- working |>
  dplyr::mutate(
    pre_downgrade = as.numeric(pre_end < pre_base),
    pre_upgrade = as.numeric(pre_end > pre_base)
  )

placebo_table <- purrr::map_dfr(c("pre_downgrade", "pre_upgrade"), function(outcome) {
  fit <- tryCatch(
    fit_fe_lm(stats::as.formula(paste(outcome, "~ close_success | model_year")), working),
    error = function(e) e
  )
  if (inherits(fit, "error")) {
    return(tibble::tibble(outcome = outcome, estimate = NA_real_, std_error = NA_real_,
                          p_value = NA_real_, nobs = 0L))
  }
  estimate <- unname(stats::coef(fit$model)[["close_success"]])
  std_error <- sqrt(diag(fit$vcov))[["close_success"]]
  tibble::tibble(
    outcome = outcome,
    estimate = round(estimate, 4),
    std_error = round(std_error, 4),
    p_value = signif(2 * stats::pnorm(abs(estimate / std_error), lower.tail = FALSE), 3),
    nobs = nrow(fit$data)
  )
})

readr::write_csv(balance_table, file.path(paths$tables, "active_operating_close_election_balance.csv"))
readr::write_csv(placebo_table, file.path(paths$tables, "active_operating_close_election_placebo.csv"))

# Yes-vote margin distribution around the 50% threshold.
elections <- build_close_election_elections()
margin_plot <- ggplot2::ggplot(
  elections |> dplyr::filter(abs_margin <= 15),
  ggplot2::aes(x = vote_margin)
) +
  ggplot2::geom_histogram(binwidth = 1, fill = "grey40", colour = "white") +
  ggplot2::geom_vline(xintercept = 0, linetype = "dashed") +
  ggplot2::labs(
    x = "Yes-vote margin from 50%",
    y = "Operating override elections",
    title = "Operating Override Yes-Vote Margins Around the Threshold"
  ) +
  ggplot2::theme_minimal()

ggplot2::ggsave(
  file.path(paths$figures, "active_operating_close_election_margin_distribution.png"),
  margin_plot,
  width = 7, height = 4.5, dpi = 150
)
