source(file.path("R", "00_config.R"))
load_required_packages(c("dplyr", "tidyr", "purrr", "haven", "ggplot2", "readr", "scales"))
make_output_dirs()
source(file.path("R", "active_helpers.R"))

annual_override_amounts <- purrr::map_dfr(
  data_65_file(override_source_files),
  haven::read_dta
) |>
  dplyr::filter(
    .data$Override == "operating",
    .data$FiscalYear %in% override_amount_years
  ) |>
  dplyr::group_by(year = .data$FiscalYear) |>
  dplyr::summarise(
    attempt_amount_millions = sum(.data$Amount, na.rm = TRUE) / 1e6,
    success_amount_millions = sum(dplyr::if_else(.data$WinLoss == "WIN", .data$Amount, 0), na.rm = TRUE) / 1e6,
    .groups = "drop"
  ) |>
  tidyr::complete(
    year = override_amount_years,
    fill = list(attempt_amount_millions = 0, success_amount_millions = 0)
  )

amount_plot_data <- annual_override_amounts |>
  tidyr::pivot_longer(
    cols = c("attempt_amount_millions", "success_amount_millions"),
    names_to = "series",
    values_to = "amount_millions"
  ) |>
  dplyr::mutate(
    series = dplyr::recode(
      .data$series,
      attempt_amount_millions = "Attempt amount",
      success_amount_millions = "Successful amount"
    )
  )

readr::write_csv(
  annual_override_amounts,
  file.path(paths$figures, "northeast_annual_override_amounts.csv")
)

override_amount_plot <- ggplot2::ggplot(
  amount_plot_data,
  ggplot2::aes(x = .data$year, y = .data$amount_millions, color = .data$series)
) +
  ggplot2::geom_line(linewidth = 1) +
  ggplot2::geom_point(size = 2) +
  ggplot2::scale_x_continuous(breaks = override_amount_years) +
  ggplot2::scale_y_continuous(
    labels = function(x) paste0("$", scales::comma(x)),
    breaks = scales::breaks_width(10),
    expand = ggplot2::expansion(mult = c(0, 0.08))
  ) +
  ggplot2::scale_color_manual(
    values = c("Attempt amount" = "#2f5597", "Successful amount" = "#3a7f5f")
  ) +
  ggplot2::labs(
    title = "Override attempts and successful overrides, 2010-2025",
    x = NULL,
    y = "Nominal amount ($ millions)",
    color = NULL
  ) +
  ggplot2::theme_minimal(base_size = 14) +
  ggplot2::theme(
    plot.title = ggplot2::element_text(face = "bold", size = 18),
    plot.subtitle = ggplot2::element_text(size = 12, color = "gray30"),
    legend.position = "bottom",
    legend.text = ggplot2::element_text(size = 12),
    panel.grid.minor = ggplot2::element_blank(),
    axis.text.x = ggplot2::element_text(angle = 45, hjust = 1)
  )

ggplot2::ggsave(
  filename = file.path(paths$figures, "northeast_annual_override_amounts.png"),
  plot = override_amount_plot,
  width = 10,
  height = 5.625,
  dpi = 300
)

did_main <- readr::read_csv(
  file.path(paths$tables, "active_operating_repeated_event_binary_did_main.csv"),
  show_col_types = FALSE
)

event_plot_data <- did_main |>
  dplyr::mutate(
    event_label = event_plot_labels[event_type],
    outcome_label = did_outcome_labels[outcome],
    ci_lower = dplyr::if_else(term == "reference", 0, ci_lower),
    ci_upper = dplyr::if_else(term == "reference", 0, ci_upper)
  )

make_event_plot <- function(event_type) {
  event_data <- event_plot_data |>
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

for (event_type in names(event_study_files)) {
  ggplot2::ggsave(
    filename = file.path(paths$figures, event_study_files[[event_type]]),
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
    "  <h2>", unname(event_plot_labels[names(event_study_files)]), "</h2>",
    "  <img src=\"../figures/", unname(event_study_files), "\" alt=\"", unname(event_plot_labels[names(event_study_files)]), " event-study figure\">"
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
