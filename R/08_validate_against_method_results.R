source(file.path("R", "00_config.R"))
load_required_packages(c("dplyr", "purrr", "readr", "xml2"))
make_output_dirs()

method_results_docx <- file.path("Data and Models", "6.22", "Method_Results.docx")

if (!file.exists(file.path(paths$intermediate, "main_mundlak_models.rds"))) {
  source(file.path("R", "04_models_main_mundlak.R"))
}

main_models <- readRDS(file.path(paths$intermediate, "main_mundlak_models.rds"))

docx_dir <- tempdir()
utils::unzip(method_results_docx, files = "word/document.xml", exdir = docx_dir, overwrite = TRUE)
doc_xml <- xml2::read_xml(file.path(docx_dir, "word/document.xml"))
doc_ns <- xml2::xml_ns(doc_xml)
doc_tables <- xml2::xml_find_all(doc_xml, ".//w:tbl", doc_ns)

table_to_matrix <- function(tbl) {
  rows <- xml2::xml_find_all(tbl, "./w:tr", doc_ns)
  max_cols <- max(vapply(rows, function(row) length(xml2::xml_find_all(row, "./w:tc", doc_ns)), integer(1)))
  cells <- lapply(rows, function(row) {
    text <- vapply(
      xml2::xml_find_all(row, "./w:tc", doc_ns),
      function(cell) paste(xml2::xml_text(xml2::xml_find_all(cell, ".//w:t", doc_ns)), collapse = ""),
      character(1)
    )
    length(text) <- max_cols
    text
  })
  do.call(rbind, cells)
}

method_tables <- lapply(doc_tables[1:6], table_to_matrix)

numeric_cell <- function(x) {
  cleaned <- gsub(",", "", x)
  cleaned <- gsub("[()*]", "", cleaned)
  cleaned <- gsub("[^0-9.\\-]", "", cleaned)
  suppressWarnings(as.numeric(cleaned))
}

doc_value <- function(table_number, row_label, model_number) {
  mat <- method_tables[[table_number]]
  row_index <- which(trimws(mat[, 1]) == row_label)[1]
  if (is.na(row_index)) {
    stop("Could not find row in Method_Results.docx table ", table_number, ": ", row_label, call. = FALSE)
  }
  numeric_cell(mat[row_index, model_number + 1])
}

doc_n <- function(table_number, model_number) {
  mat <- method_tables[[table_number]]
  row_index <- which(trimws(mat[, 1]) == "N")[1]
  numeric_cell(mat[row_index, model_number + 1])
}

r_coef <- function(table_name, model_name, term) {
  unname(stats::coef(main_models[[table_name]][[model_name]]$model)[[term]])
}

r_n <- function(table_name, model_name) {
  nrow(main_models[[table_name]][[model_name]]$data)
}

checks <- tibble::tribble(
  ~doc_table, ~doc_model, ~doc_label, ~r_table, ~r_model, ~r_term,
  1, 1, "Binary for any override attempt", "table_1", "binary_attempt", "binaryover",
  1, 2, "Binary for any successful override", "table_1", "binary_success", "binarysucc",
  1, 3, "Binary for any override failure", "table_1", "binary_failure", "binaryfail",
  2, 1, "Binary for any override attempt", "table_2", "attempt_low_reserve", "binaryover",
  2, 1, "Fiscal stress indicator (less fiscal reserve)", "table_2", "attempt_low_reserve", "highfiscal1",
  2, 1, "Binary for any override attempt # Fiscal stress indicator (less fiscal reserve)", "table_2", "attempt_low_reserve", "binaryover:highfiscal1",
  2, 5, "Binary for any successful override", "table_2", "success_high_debt", "binarysucc",
  2, 5, "Fiscal stress indicator (higher debt level)", "table_2", "success_high_debt", "highfiscal3",
  2, 5, "Binary for any successful override # Fiscal stress indicator (higher debt level)", "table_2", "success_high_debt", "binarysucc:highfiscal3",
  3, 1, "Total override attempt (count)", "table_3", "success_count", "num_attempt",
  3, 2, "3-year-cumulative override attempts (count)", "table_3", "success_count_3yr", "over_cumu_3yr",
  3, 3, "Total override attempt (count)", "table_3", "success_percent_count", "num_attempt",
  3, 4, "3-year-cumulative override attempts (count)", "table_3", "success_percent_count_3yr", "over_cumu_3yr",
  4, 1, "Total override attempt (count)", "table_4", "turnout_count", "num_attempt",
  4, 2, "3-year-cumulative override attempts (count)", "table_4", "turnout_count_3yr", "over_cumu_3yr",
  4, 3, "Total amounts by override attempts (log)", "table_4", "turnout_amount", "amount_all",
  4, 4, "Total amounts by successful overrides (log)", "table_4", "turnout_amount_success", "amount_win",
  4, 5, "3-year-cumulative amounts by override attempts (log)", "table_4", "turnout_amount_3yr", "amount_all_cumu_3yr",
  4, 6, "3-year-cumulative amounts by successful overrides (log)", "table_4", "turnout_amount_success_3yr", "amount_win_cumu_3yr",
  5, 1, "Total override attempt (count)", "table_5", "nonzero_attempt", "num_attempt1",
  5, 2, "Total successful overrides (count)", "table_5", "nonzero_success", "num_success1",
  5, 3, "Total override failures (count)", "table_5", "nonzero_failure", "num_fail1",
  5, 4, "3-year-cumulative override attempts (count)", "table_5", "nonzero_attempt_3yr", "over_cumu_3yr1",
  5, 5, "3-year-cumulative override failures (count)", "table_5", "nonzero_failure_3yr", "fail_cumu_3yr1",
  6, 1, "Total override attempt (count)", "table_6", "attempt_lag1", "num_attempt1",
  6, 1, "L.Total override attempt (count)", "table_6", "attempt_lag1", "l1_num_attempt1",
  6, 3, "Total override failures (count)", "table_6", "failure_lag1", "num_fail1",
  6, 3, "L.Total override failures (count)", "table_6", "failure_lag1", "l1_num_fail1",
  6, 4, "Total override attempt (count)", "table_6", "attempt_lag2", "num_attempt1",
  6, 4, "L.Total override attempt (count)", "table_6", "attempt_lag2", "l1_num_attempt1",
  6, 4, "L2.Total override attempt (count)", "table_6", "attempt_lag2", "l2_num_attempt1",
  6, 6, "Total override failures (count)", "table_6", "failure_lag2", "num_fail1",
  6, 6, "L.Total override failures (count)", "table_6", "failure_lag2", "l1_num_fail1",
  6, 6, "L2.Total override failures (count)", "table_6", "failure_lag2", "l2_num_fail1"
)

coefficient_results <- checks |>
  dplyr::mutate(
    doc_value = purrr::pmap_dbl(list(doc_table, doc_label, doc_model), doc_value),
    r_value = purrr::pmap_dbl(list(r_table, r_model, r_term), r_coef),
    r_value_rounded = round(r_value, 3),
    absolute_difference = abs(doc_value - r_value_rounded),
    matched = absolute_difference <= 0.0005
  )

n_checks <- checks |>
  dplyr::distinct(doc_table, doc_model, r_table, r_model) |>
  dplyr::mutate(
    doc_n = purrr::map2_dbl(doc_table, doc_model, doc_n),
    r_n = purrr::map2_dbl(r_table, r_model, r_n),
    matched = doc_n == r_n
  )

readr::write_csv(coefficient_results, file.path(paths$intermediate, "method_results_coefficient_validation.csv"))
readr::write_csv(n_checks, file.path(paths$intermediate, "method_results_n_validation.csv"))

summary <- tibble::tibble(
  check_type = c("focal_coefficients", "model_n"),
  checks = c(nrow(coefficient_results), nrow(n_checks)),
  matched = c(sum(coefficient_results$matched), sum(n_checks$matched)),
  mismatched = c(sum(!coefficient_results$matched), sum(!n_checks$matched))
)

readr::write_csv(summary, file.path(paths$intermediate, "method_results_validation_summary.csv"))

if (any(!coefficient_results$matched) || any(!n_checks$matched)) {
  stop("Validation against Method_Results.docx found mismatches. See outputs/intermediate/method_results_*_validation.csv", call. = FALSE)
}

summary
