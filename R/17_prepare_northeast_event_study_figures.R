source(file.path("R", "00_config.R"))
load_required_packages(c("dplyr", "ggplot2", "readr"))
make_output_dirs()

did_main <- readr::read_csv(
  file.path(paths$tables, "active_operating_repeated_event_binary_did_main.csv"),
  show_col_types = FALSE
)

event_labels <- c(
  operating_attempt = "Override Attempt",
  operating_success = "Successful Overrides",
  operating_failure = "Failed Overrides"
)

outcome_labels <- c(
  rating_downgrade = "Downgrade",
  rating_upgrade = "Upgrade"
)

plot_data <- did_main |>
  dplyr::mutate(
    event_label = event_labels[event_type],
    outcome_label = outcome_labels[outcome],
    ci_lower = dplyr::if_else(term == "reference", 0, ci_lower),
    ci_upper = dplyr::if_else(term == "reference", 0, ci_upper)
  )

event_files <- c(
  operating_attempt = "northeast_event_study_operating_attempt.png",
  operating_success = "northeast_event_study_operating_success.png",
  operating_failure = "northeast_event_study_operating_failure.png"
)

make_event_plot <- function(event_type) {
  event_data <- plot_data |>
    dplyr::filter(.data$event_type == .env$event_type)

  ggplot2::ggplot(
    event_data,
    ggplot2::aes(x = event_time, y = estimate)
  ) +
    ggplot2::geom_hline(yintercept = 0, color = "gray45", linewidth = 0.35) +
    ggplot2::geom_vline(xintercept = -1, color = "gray65", linetype = "dashed", linewidth = 0.35) +
    ggplot2::geom_errorbar(
      ggplot2::aes(ymin = ci_lower, ymax = ci_upper),
      width = 0.12,
      linewidth = 0.45,
      color = "#2f5597"
    ) +
    ggplot2::geom_point(size = 2.2, color = "#2f5597") +
    ggplot2::geom_line(linewidth = 0.45, color = "#2f5597") +
    ggplot2::facet_wrap(~ outcome_label, nrow = 1) +
    ggplot2::scale_x_continuous(breaks = -2:2) +
    ggplot2::labs(
      title = unique(event_data$event_label),
      subtitle = "Window-clean repeated-event DiD; coefficients relative to h = -1",
      x = "Relative year",
      y = "Estimated probability-point change"
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold"),
      panel.grid.minor = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold")
    )
}

for (event_type in names(event_files)) {
  ggplot2::ggsave(
    filename = file.path(paths$figures, event_files[[event_type]]),
    plot = make_event_plot(event_type),
    width = 10,
    height = 4.8,
    dpi = 300
  )
}

html_lines <- c(
  "<!doctype html>",
  "<html>",
  "<head>",
  "  <meta charset=\"utf-8\">",
  "  <title>NorthEast Workshop Event-Study Figures</title>",
  "  <style>",
  "    body { font-family: Arial, sans-serif; margin: 32px; color: #222; }",
  "    h1 { font-size: 24px; margin-bottom: 8px; }",
  "    h2 { font-size: 18px; margin-top: 28px; }",
  "    p { max-width: 900px; line-height: 1.45; }",
  "    img { max-width: 100%; border: 1px solid #ddd; }",
  "    .note { color: #555; font-size: 14px; }",
  "  </style>",
  "</head>",
  "<body>",
  "  <h1>NorthEast Workshop Event-Study Figures</h1>",
  "  <p>Repeated-event DiD estimates using window-clean controls. Points are coefficients relative to h = -1; intervals are 95% confidence intervals with municipality-clustered standard errors.</p>",
  paste0(
    "  <h2>", unname(event_labels[names(event_files)]), "</h2>",
    "  <img src=\"../figures/", unname(event_files), "\" alt=\"", unname(event_labels[names(event_files)]), " event-study figure\">"
  ),
  "  <p class=\"note\">Generated from outputs/tables/active_operating_repeated_event_binary_did_main.csv.</p>",
  "</body>",
  "</html>"
)

writeLines(
  html_lines,
  file.path(paths$report, "northeast_event_study_figures.html"),
  useBytes = TRUE
)
