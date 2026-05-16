source(file.path("R", "09_build_rd_data.R"))
source(file.path("R", "10_rd_main_models.R"))
source(file.path("R", "11_rd_validity_checks.R"))

quarto_bin <- Sys.which("quarto")
if (nzchar(quarto_bin)) {
  report_dir <- normalizePath(paths$report, winslash = "/", mustWork = FALSE)
  system2(
    quarto_bin,
    c("render", file.path("doc", "rd_results_report.qmd"), "--to", "html", "--output-dir", report_dir)
  )
  system2(
    quarto_bin,
    c("render", file.path("doc", "rd_results_report.qmd"), "--to", "docx", "--output-dir", report_dir)
  )
}
