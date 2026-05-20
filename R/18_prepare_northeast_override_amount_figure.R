source(file.path("R", "00_config.R"))
load_required_packages(c("dplyr", "tidyr", "purrr", "haven", "ggplot2", "readr", "scales"))
make_output_dirs()

override_files <- c(
  "override_override.dta",
  "override_capital.dta",
  "override_debt.dta",
  "override_stable.dta"
)

annual_override_amounts <- purrr::map_dfr(
  data_65_file(override_files),
  haven::read_dta
) |>
  dplyr::filter(
    .data$Override == "operating",
    .data$FiscalYear >= 2010,
    .data$FiscalYear <= 2025
  ) |>
  dplyr::group_by(year = .data$FiscalYear) |>
  dplyr::summarise(
    attempt_amount_millions = sum(.data$Amount, na.rm = TRUE) / 1e6,
    success_amount_millions = sum(dplyr::if_else(.data$WinLoss == "WIN", .data$Amount, 0), na.rm = TRUE) / 1e6,
    .groups = "drop"
  ) |>
  tidyr::complete(
    year = 2010:2025,
    fill = list(attempt_amount_millions = 0, success_amount_millions = 0)
  )

plot_data <- annual_override_amounts |>
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
  plot_data,
  ggplot2::aes(x = .data$year, y = .data$amount_millions, color = .data$series)
) +
  ggplot2::geom_line(linewidth = 1) +
  ggplot2::geom_point(size = 2) +
  ggplot2::scale_x_continuous(breaks = 2010:2025) +
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
    y = "Amount ($ millions)",
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
