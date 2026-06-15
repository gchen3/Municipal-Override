# Municipal Override Project

This project analyzes Massachusetts municipal override elections and their relationship to municipal credit ratings and voter support. The codebase is organized as a numbered R workflow under `R/`, with generated intermediate files, tables, figures, and reports written under `outputs/`.

## Current Active Workflow

The current active analysis focuses on operating overrides. It estimates ordered-response Moody's rating models, voter-support models, repeated-event DiD robustness checks for binary Moody's rating changes, and publication-table drafts. Run the active workflow with:

```r
source(file.path("R", "run_active_workflow.R"))
```

`R/run_active_workflow.R` runs these scripts in order:

1. `R/10_operating_mundlak_models.R`
   - Builds operating-override annual and three-year cumulative measures.
   - Estimates ordered probit Moody's models with Mundlak controls and year indicators.
   - Estimates two-way fixed-effects voter-support models for operating yes-vote percentage.
2. `R/11_build_operating_repeated_event_data.R`
   - Builds repeated-event stacks for operating override attempts, successes, and failures.
   - Uses a five-year event window from `h = -2` through `h = 2`.
3. `R/12_operating_repeated_event_binary_models.R`
   - Estimates binary downgrade and upgrade DiD models with stack-by-municipality and stack-by-year fixed effects.
   - Writes preferred estimates and robustness variants.
4. `R/13_prepare_slide_tables.R`
   - Converts active model results into compact slide-ready LaTeX tables.
5. `R/14_prepare_slide_figures.R`
   - Writes the annual override-amount figure, event-study figures, and event-study preview report.
6. `R/15_prepare_publication_tables.R`
   - Writes publication-oriented LaTeX table drafts under `outputs/tables/publication/`.

`R/active_helpers.R` supplies shared active workflow definitions, labels, formatting helpers, and repeated-event model helpers.

The Northeast workshop slide deck is `slides/NorthEast_workshop.qmd`. It uses the slide-ready outputs:

- `outputs/figures/northeast_annual_override_amounts.png`
- `outputs/tables/northeast_moodys_main.tex`
- `outputs/tables/northeast_moodys_frequency.tex`
- `outputs/tables/northeast_vote_share_annual.tex`
- `outputs/tables/northeast_vote_share_cumulative.tex`
- `outputs/tables/northeast_repeated_event_counts.tex`
- `outputs/tables/northeast_repeated_event_did_downgrade.tex`
- `outputs/tables/northeast_repeated_event_did_upgrade.tex`
- `outputs/figures/northeast_event_study_operating_attempt.png`
- `outputs/figures/northeast_event_study_operating_success.png`
- `outputs/figures/northeast_event_study_operating_failure.png`

Publication-table drafts are generated from the same Northeast workflow and written to `outputs/tables/publication/`. That folder is generated output and is ignored by Git.

## Frozen Stata-Replication Track

Scripts `R/00` through `R/09` preserve the earlier Stata-replication workflow. They build the municipality-year regression panel, estimate the main and appendix replication tables, render reports, and validate selected results against `Data and Models/6.22/Method_Results.docx`.

Run the frozen replication workflow with:

```r
source(file.path("R", "09_run_stata_replication.R"))
```

The main frozen scripts are:

- `R/00_config.R`: shared paths, package loading, labels, model helpers, and table-writing utilities.
- `R/01_build_override_panel.R`: combines override source files into municipality-year override measures.
- `R/02_build_regression_data.R`: merges override, fiscal, and rating data and constructs regression variables.
- `R/03_descriptives.R`: writes descriptive and credit-rating summary tables.
- `R/04_models_main_mundlak.R`: estimates main replication tables.
- `R/05_models_robustness.R`: estimates appendix robustness tables.
- `R/06_figure_margins.R`: writes the older Figure 1 predicted-probability output.
- `R/07_render_results.R`: renders replication outputs and an output manifest.
- `R/08_validate_against_method_results.R`: checks focal replication results against `Method_Results.docx`.

The frozen replication outputs are retained for comparison and archival use. The active Northeast workflow should be treated as the current model path for the slide deck.

## Empirical Strategy

The active rating models use ordered probit specifications because Moody's ratings are ordinal. They include time-varying controls, Mundlak municipality means, year indicators, and municipality-clustered standard errors.

The active voter-support models use operating yes-vote percentage as the outcome and estimate two-way fixed-effects linear models with municipality and year fixed effects.

The active repeated-event design estimates binary rating-change outcomes:

- downgrade relative to the municipality's `h = -1` Moody's rating,
- upgrade relative to the municipality's `h = -1` Moody's rating.

The preferred repeated-event comparison pool uses window-clean controls with no same-type operating override event inside the local event window. Robustness variants use never-treated controls, the preferred specification with active controls added, first-time events, and a narrower event window.

## Documentation And Transparency

Project documentation lives under `docs/`. The main planning and audit documents are:

- `docs/r_replication_workflow_plan.md`
- `docs/northeast_workshop_active_update_plan.md`
- `docs/northeast_publication_tables_plan.md`
- `docs/northeast_close_election_causal_analysis_plan.md`
- `docs/stata_workflow_issues.md`

The Northeast transparency record lives under `transparency/`:

- `transparency/northeast_results_registry.md`
- `transparency/northeast_variable_dictionary.md`
- `transparency/freeze_northeast_results.R`
- `transparency/reproduce_northeast_results.R`
- `transparency/northeast_freeze_and_reproduce.md`

## Reproducibility Notes

The scripts use project-relative paths and assume the project environment and source data are already prepared. Package installation code is intentionally not included. The raw and source data under `Data and Models/` are read by the workflow but are not modified by these scripts.
