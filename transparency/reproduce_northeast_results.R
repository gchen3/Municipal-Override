args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 1L || !nzchar(args[[1]])) {
  stop("Usage: Rscript --vanilla transparency/reproduce_northeast_results.R <freeze_id>", call. = FALSE)
}

freeze_id <- args[[1]]
if (!grepl("^[A-Za-z0-9._-]+$", freeze_id)) {
  stop("freeze_id may contain only letters, numbers, dots, underscores, and hyphens.", call. = FALSE)
}

if (!file.exists(file.path("R", "run_active_workflow.R"))) {
  stop("Run this script from the project root.", call. = FALSE)
}

bundle_type <- "reproduced"
bundle_dir <- file.path("outputs", bundle_type, freeze_id)
workflow_command <- "source(file.path(\"R\", \"run_active_workflow.R\"))"

headline_outputs <- c(
  "outputs/figures/northeast_annual_override_amounts.png",
  "outputs/tables/slides/northeast_moodys_main.tex",
  "outputs/tables/slides/northeast_moodys_frequency.tex",
  "outputs/tables/slides/northeast_vote_share_annual.tex",
  "outputs/tables/slides/northeast_vote_share_cumulative.tex",
  "outputs/tables/slides/northeast_repeated_event_counts.tex",
  "outputs/tables/slides/northeast_repeated_event_did_downgrade.tex",
  "outputs/tables/slides/northeast_repeated_event_did_upgrade.tex",
  "outputs/figures/northeast_event_study_operating_attempt.png",
  "outputs/figures/northeast_event_study_operating_success.png",
  "outputs/figures/northeast_event_study_operating_failure.png"
)

machine_readable_outputs <- c(
  "outputs/tables/active_operating_repeated_event_binary_did.csv",
  "outputs/tables/active_operating_repeated_event_binary_did_main.csv",
  "outputs/tables/active_operating_repeated_event_sample_counts.csv",
  "outputs/figures/northeast_annual_override_amounts.csv",
  "outputs/report/northeast_event_study_figures.html"
)

audit_files <- c(
  "transparency/northeast_results_registry.md",
  "transparency/northeast_variable_dictionary.md"
)

expected_outputs <- c(headline_outputs, machine_readable_outputs)

ensure_parent_dir <- function(path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
}

copy_project_file <- function(source, bundle_root) {
  destination <- file.path(bundle_root, source)
  ensure_parent_dir(destination)
  ok <- file.copy(source, destination, overwrite = FALSE, copy.mode = FALSE, copy.date = TRUE)
  if (!ok) {
    stop("Failed to copy ", source, " to ", destination, call. = FALSE)
  }
  destination
}

csv_escape <- function(x) {
  x <- as.character(x)
  needs_quotes <- grepl("[\",\n\r]", x)
  x <- gsub("\"", "\"\"", x, fixed = TRUE)
  ifelse(needs_quotes, paste0("\"", x, "\""), x)
}

write_csv_base <- function(data, path) {
  ensure_parent_dir(path)
  con <- file(path, open = "w", encoding = "UTF-8")
  on.exit(close(con), add = TRUE)
  writeLines(paste(names(data), collapse = ","), con, useBytes = TRUE)
  if (nrow(data) > 0L) {
    rows <- apply(data, 1L, function(row) paste(csv_escape(row), collapse = ","))
    writeLines(rows, con, useBytes = TRUE)
  }
}

yaml_list <- function(values, indent = "  ") {
  if (length(values) == 0L) {
    return(paste0(indent, "[]"))
  }
  paste0(indent, "- ", values)
}

capture_text <- function(expr) {
  paste(utils::capture.output(expr), collapse = "\n")
}

git_output <- function(args) {
  repo <- normalizePath(".", winslash = "/", mustWork = TRUE)
  out <- tryCatch(
    system2("git", c("-c", paste0("safe.directory=", repo), args), stdout = TRUE, stderr = TRUE),
    error = function(e) paste("UNKNOWN:", conditionMessage(e))
  )
  if (length(out) == 0L) {
    ""
  } else {
    paste(out, collapse = "\n")
  }
}

if (dir.exists(bundle_dir) || file.exists(bundle_dir)) {
  stop("Bundle already exists: ", bundle_dir, call. = FALSE)
}

source(file.path("R", "run_active_workflow.R"))

dir.create(bundle_dir, recursive = TRUE, showWarnings = FALSE)

existing_outputs <- expected_outputs[file.exists(expected_outputs)]
missing_outputs <- setdiff(expected_outputs, existing_outputs)
missing_headline <- setdiff(headline_outputs, existing_outputs)

if (length(existing_outputs) == 0L) {
  stop("No expected Northeast outputs were found after reproduction.", call. = FALSE)
}
if (length(missing_headline) == length(headline_outputs)) {
  stop("All expected headline outputs are missing after reproduction.", call. = FALSE)
}

copied_outputs <- vapply(existing_outputs, copy_project_file, character(1), bundle_root = bundle_dir)
existing_audit_files <- audit_files[file.exists(audit_files)]
missing_audit_files <- setdiff(audit_files, existing_audit_files)
copied_audit <- vapply(existing_audit_files, copy_project_file, character(1), bundle_root = bundle_dir)

missing_data <- data.frame(
  path = c(missing_outputs, missing_audit_files),
  category = c(rep("output", length(missing_outputs)), rep("audit", length(missing_audit_files))),
  stringsAsFactors = FALSE
)
write_csv_base(missing_data, file.path(bundle_dir, "missing_outputs.csv"))

writeLines(capture_text(sessionInfo()), file.path(bundle_dir, "sessionInfo.txt"), useBytes = TRUE)
git_commit <- git_output(c("rev-parse", "HEAD"))
writeLines(git_commit, file.path(bundle_dir, "git_commit.txt"), useBytes = TRUE)
git_status <- git_output(c("status", "--short"))
writeLines(git_status, file.path(bundle_dir, "git_status_short.txt"), useBytes = TRUE)

manifest <- c(
  paste0("freeze_id: ", freeze_id),
  paste0("bundle_type: ", bundle_type),
  paste0("timestamp: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %z")),
  paste0("workflow_command: ", workflow_command),
  "expected_output_files:",
  yaml_list(expected_outputs),
  "copied_output_files:",
  yaml_list(existing_outputs),
  "copied_audit_files:",
  yaml_list(existing_audit_files),
  "missing_output_files:",
  yaml_list(missing_outputs),
  "missing_audit_files:",
  yaml_list(missing_audit_files),
  paste0("git_commit: ", git_commit),
  "git_status_summary_file: git_status_short.txt",
  "hash_file: file_hashes.csv"
)
writeLines(manifest, file.path(bundle_dir, "MANIFEST.yml"), useBytes = TRUE)

bundle_files <- list.files(bundle_dir, recursive = TRUE, all.files = FALSE, full.names = FALSE)
bundle_files <- setdiff(bundle_files, "file_hashes.csv")
source_paths <- ifelse(
  startsWith(bundle_files, "outputs/") | startsWith(bundle_files, "transparency/"),
  bundle_files,
  NA_character_
)
absolute_bundle_files <- file.path(bundle_dir, bundle_files)
hashes <- as.character(tools::md5sum(absolute_bundle_files))
hash_data <- data.frame(
  bundle_relative_path = bundle_files,
  source_path = source_paths,
  size_bytes = file.info(absolute_bundle_files)$size,
  md5 = hashes,
  stringsAsFactors = FALSE
)
write_csv_base(hash_data, file.path(bundle_dir, "file_hashes.csv"))

message("Reproduced Northeast outputs to ", bundle_dir)
if (length(missing_outputs) > 0L || length(missing_audit_files) > 0L) {
  message("Missing files recorded in ", file.path(bundle_dir, "missing_outputs.csv"))
}
