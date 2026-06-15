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
event_panel <- build_close_election_event_panel(working, moo_vec)

# Two-group event study on rating levels: success-vs-failure differential path
# (i(rel_year, close_success)), the common event-time path (i(rel_year)), and
# the close_success level, with calendar-year fixed effects clustered by
# municipality. No stack^code/stack^year and no municipality fixed effects.
event_model <- fixest::feols(
  MOO_num ~ i(rel_year, close_success, ref = -1) + i(rel_year, ref = -1) + close_success |
    calendar_year,
  data = event_panel,
  vcov = ~ code
)

coef_table <- as.data.frame(fixest::coeftable(event_model))
coef_table$term <- rownames(coef_table)

differential_path <- coef_table |>
  dplyr::filter(grepl("rel_year::", term), grepl("close_success", term)) |>
  dplyr::transmute(
    rel_year = as.integer(sub(".*rel_year::(-?[0-9]+).*", "\\1", term)),
    estimate = Estimate,
    std_error = `Std. Error`,
    p_value = `Pr(>|t|)`
  ) |>
  dplyr::bind_rows(
    tibble::tibble(rel_year = -1L, estimate = 0, std_error = NA_real_, p_value = NA_real_)
  ) |>
  dplyr::arrange(rel_year) |>
  dplyr::mutate(
    ci_lower = estimate - stats::qnorm(0.975) * std_error,
    ci_upper = estimate + stats::qnorm(0.975) * std_error,
    nobs = event_model$nobs,
    n_events = dplyr::n_distinct(event_panel$event_id[!is.na(event_panel$MOO_num)])
  )

event_output <- differential_path |>
  dplyr::mutate(dplyr::across(c(estimate, std_error, ci_lower, ci_upper), ~ round(.x, 4)),
                p_value = signif(p_value, 3))

readr::write_csv(
  event_output,
  file.path(paths$tables, "active_operating_close_election_event_study.csv")
)

event_plot <- ggplot2::ggplot(differential_path, ggplot2::aes(x = rel_year, y = estimate)) +
  ggplot2::geom_hline(yintercept = 0, linetype = "dashed") +
  ggplot2::geom_vline(xintercept = -1, linetype = "dotted", colour = "grey50") +
  ggplot2::geom_errorbar(ggplot2::aes(ymin = ci_lower, ymax = ci_upper), width = 0.1) +
  ggplot2::geom_point() +
  ggplot2::geom_line() +
  ggplot2::labs(
    x = "Event time relative to model year (h)",
    y = "Close-success vs close-failure rating gap (notches)",
    title = "Close-Election Event Study: Moody's Rating Path",
    subtitle = "Reference h = -1; positive = higher rating for close successes"
  ) +
  ggplot2::theme_minimal()

ggplot2::ggsave(
  file.path(paths$figures, "active_operating_close_election_event_study.png"),
  event_plot,
  width = 7, height = 4.5, dpi = 150
)
