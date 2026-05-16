source(file.path("R", "00_config.R"))
load_required_packages(c("dplyr", "tidyr", "purrr", "MASS", "sandwich", "ggplot2", "readr", "scales"))
make_output_dirs()

if (!file.exists(file.path(paths$intermediate, "data_for_regression.rds"))) {
  source(file.path("R", "02_build_regression_data.R"))
}

data_for_regression <- readRDS(file.path(paths$intermediate, "data_for_regression.rds"))

controls_low_reserve <- c("logpopu", "debtbudg", "unemploy", "revstab", "revperca", "excessperca", "balance")

figure_formula <- rhs_formula(
  "MOO_ordered",
  c(
    "binaryover * highfiscal1",
    controls_low_reserve,
    "binaryovercon",
    con_terms(controls_low_reserve),
    "highfiscal1con"
  )
)

figure_fit <- fit_ordered_probit(figure_formula, data_for_regression)
model_data <- figure_fit$data

prediction_grid <- tidyr::expand_grid(
  binaryover = c(0, 1),
  highfiscal1 = c(0, 1)
) |>
  dplyr::mutate(
    group = dplyr::case_when(
      binaryover == 0 & highfiscal1 == 0 ~ "No override / no fiscal stress",
      binaryover == 0 & highfiscal1 == 1 ~ "No override / fiscal stress",
      binaryover == 1 & highfiscal1 == 0 ~ "Override / no fiscal stress",
      TRUE ~ "Override / fiscal stress"
    )
  )

predicted_probabilities <- purrr::map_dfr(seq_len(nrow(prediction_grid)), function(i) {
  newdata <- model_data
  newdata$binaryover <- prediction_grid$binaryover[i]
  newdata$highfiscal1 <- prediction_grid$highfiscal1[i]
  probs <- stats::predict(figure_fit$model, newdata = newdata, type = "probs")
  tibble::as_tibble(probs) |>
    dplyr::summarise(dplyr::across(dplyr::everything(), ~ mean(.x, na.rm = TRUE))) |>
    tidyr::pivot_longer(dplyr::everything(), names_to = "moody_rating", values_to = "predicted_probability") |>
    dplyr::mutate(
      moody_rating = as.numeric(moody_rating),
      binaryover = prediction_grid$binaryover[i],
      highfiscal1 = prediction_grid$highfiscal1[i],
      group = prediction_grid$group[i]
    )
})

readr::write_csv(predicted_probabilities, file.path(paths$figures, "figure_1_predicted_probabilities.csv"))

figure_1 <- ggplot2::ggplot(
  predicted_probabilities,
  ggplot2::aes(x = moody_rating, y = predicted_probability, color = group, linetype = group)
) +
  ggplot2::geom_line(linewidth = 0.8) +
  ggplot2::geom_point(size = 1.8) +
  ggplot2::scale_x_continuous(breaks = sort(unique(predicted_probabilities$moody_rating))) +
  ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  ggplot2::labs(
    x = "Moody's rating category",
    y = "Predicted probability",
    color = NULL,
    linetype = NULL,
    title = "Figure 1. Predicted Moody's Rating Probabilities by Override and Fiscal Stress"
  ) +
  ggplot2::theme_minimal(base_size = 11) +
  ggplot2::theme(legend.position = "bottom")

ggplot2::ggsave(
  filename = file.path(paths$figures, "figure_1_predicted_probabilities.png"),
  plot = figure_1,
  width = 8,
  height = 5,
  dpi = 300
)

saveRDS(figure_fit, file.path(paths$intermediate, "figure_1_model.rds"))
