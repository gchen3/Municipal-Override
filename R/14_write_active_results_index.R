source(file.path("R", "00_config.R"))
load_required_packages(c("dplyr", "readr"))
make_output_dirs()

active_results_index <- tibble::tribble(
  ~step, ~artifact_type, ~path, ~description,
  "operating_mundlak", "model_table",
  file.path(paths$tables, "active_operating_moodys_main.html"),
  "Ordered probit models for override attempt, success, and failure on Moody's ratings with Mundlak controls and year indicators.",
  "operating_vote_share", "model_table",
  file.path(paths$tables, "active_operating_vote_share_main.html"),
  "Fixed-effects linear models for override counts and three-year cumulative counts on yes-vote percentage.",
  "operating_mundlak", "model_object",
  file.path(paths$intermediate, "active_operating_mundlak_models.rds"),
  "Saved override Moody's and yes-vote-percentage model fits and formulas.",
  "repeated_event_data", "sample_counts",
  file.path(paths$tables, "active_operating_repeated_event_sample_counts.csv"),
  "Repeated-event override sample counts by event type and control pool.",
  "repeated_event_data", "sample_counts_html",
  file.path(paths$tables, "active_operating_repeated_event_sample_counts.html"),
  "HTML table of repeated-event override sample counts by event type and control pool.",
  "repeated_event_data", "stack_data",
  file.path(paths$intermediate, "active_operating_repeated_event_data.rds"),
  "Stacked repeated-event data for override attempt, success, and failure events.",
  "binary_did", "estimates",
  file.path(paths$tables, "active_operating_repeated_event_binary_did.csv"),
  "Repeated-event DID estimates for binary Moody's rating-change outcomes.",
  "binary_did", "estimates_html",
  file.path(paths$tables, "active_operating_repeated_event_binary_did.html"),
  "HTML table of repeated-event DID estimates for binary Moody's rating-change outcomes.",
  "binary_did", "main_estimates",
  file.path(paths$tables, "active_operating_repeated_event_binary_did_main.csv"),
  "Window-clean repeated-event DID estimates for binary Moody's rating-change outcomes.",
  "binary_did", "main_estimates_html",
  file.path(paths$tables, "active_operating_repeated_event_binary_did_main.html"),
  "HTML table of window-clean repeated-event DID estimates for binary Moody's rating-change outcomes.",
  "binary_did", "model_object",
  file.path(paths$intermediate, "active_operating_repeated_event_binary_models.rds"),
  "Saved repeated-event DID estimate tables and model metadata."
)

readr::write_csv(
  active_results_index,
  file.path(paths$tables, "active_workflow_outputs.csv")
)
