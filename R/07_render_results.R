source(file.path("R", "00_config.R"))
load_required_packages(c("dplyr", "purrr", "modelsummary"))
make_output_dirs()

if (!file.exists(file.path(paths$intermediate, "main_mundlak_models.rds"))) {
  source(file.path("R", "04_models_main_mundlak.R"))
}

if (!file.exists(file.path(paths$intermediate, "robustness_models.rds"))) {
  source(file.path("R", "05_models_robustness.R"))
}

if (!file.exists(file.path(paths$figures, "figure_1_predicted_probabilities.csv"))) {
  source(file.path("R", "06_figure_margins.R"))
}

main_mundlak_fits <- readRDS(file.path(paths$intermediate, "main_mundlak_models.rds"))
robustness_fits <- readRDS(file.path(paths$intermediate, "robustness_models.rds"))
docx_available <- requireNamespace("officer", quietly = TRUE) && requireNamespace("flextable", quietly = TRUE)

render_docx_table <- function(fits, file_name, title) {
  output_path <- file.path(paths$tables, file_name)
  if (docx_available) {
    try(write_model_table(fits, file_name, title), silent = TRUE)
  }
  output_path
}

purrr::iwalk(
  main_mundlak_fits,
  ~ render_docx_table(.x, paste0(.y, ".docx"), paste("Municipal Override", gsub("_", " ", .y)))
)

purrr::iwalk(
  robustness_fits,
  ~ render_docx_table(.x, paste0(.y, ".docx"), paste("Municipal Override", gsub("_", " ", .y)))
)

render_notes <- tibble::tibble(
  note = dplyr::if_else(
    docx_available,
    "DOCX table export attempted with officer and flextable available.",
    "DOCX table export skipped because officer and flextable are not available; HTML and CSV outputs were written."
  )
)

readr::write_csv(render_notes, file.path(paths$intermediate, "render_notes.csv"))

manifest <- tibble::tibble(
  output = c(
    list.files(paths$tables, full.names = FALSE),
    list.files(paths$figures, full.names = FALSE)
  ),
  folder = c(
    rep(paths$tables, length(list.files(paths$tables))),
    rep(paths$figures, length(list.files(paths$figures)))
  )
)

readr::write_csv(manifest, file.path(paths$intermediate, "output_manifest.csv"))
