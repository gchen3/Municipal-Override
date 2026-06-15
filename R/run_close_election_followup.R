# Driver for the close-election success-vs-failure follow-up track.
# Separate from R/run_active_workflow.R: this analysis does not feed the
# workshop slide deck. See docs/northeast_close_election_causal_analysis_plan.md.
source(file.path("R", "16_build_close_election_data.R"))
source(file.path("R", "17_close_election_rating_models.R"))
source(file.path("R", "18_close_election_diagnostics.R"))
source(file.path("R", "19_close_election_event_study.R"))
source(file.path("R", "20_close_election_publication_tables.R"))
