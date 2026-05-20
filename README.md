# Municipal Override Project

This project analyzes Massachusetts municipal override elections and their relationship to municipal credit ratings, fiscal conditions, and voter turnout. The current codebase is organized as a reproducible R workflow under `R/`, with intermediate data, tables, figures, and reports written under `outputs/`.

## Current Workflow

The active workflow builds a municipality-year analysis file, estimates ordered-response panel models, and runs repeated-event robustness checks for operating overrides.

### Panel and Mundlak Models

- `R/00_config.R` defines package loading, project-relative paths, variable labels, CPI values, panel helpers, model wrappers, clustered variance estimators, and table-writing utilities.
- `R/01_build_override_panel.R` combines operating, capital, debt, and stabilization override files into municipality-year override measures.
- `R/02_build_regression_data.R` merges the override panel with fiscal data and Moody's/S&P ratings, constructs inflation-adjusted fiscal variables, lagged override measures, 3-year cumulative measures, fiscal-stress indicators, and Mundlak municipality means.
- `R/03_descriptives.R` produces descriptive statistics and credit-rating observation summaries.
- `R/04_models_main_mundlak.R` estimates the main ordered probit models with Mundlak controls and year indicators.
- `R/05_models_robustness.R` estimates appendix robustness tables.
- `R/06_figure_margins.R` estimates predicted Moody's rating probabilities for override/fiscal-stress groups and writes Figure 1.
- `R/07_render_results.R` renders available model outputs and writes an output manifest.
- `R/08_validate_against_method_results.R` checks focal model coefficients and model sample sizes against `Method_Results.docx`.

### Repeated-Event Robustness

- `R/13_build_did_repeated_event_data.R` builds stacked repeated-event samples for successful operating override events.
- `R/14_did_repeated_event_models.R` estimates repeated-event robustness models, including binary downgrade, upgrade, and any-change outcomes relative to the pre-event rating.
- `R/15_did_repeated_event_attempt_failure_models.R` estimates repeated-event attempt and failure specifications.
- `R/16_did_repeated_event_all_override_models.R` estimates repeated-event specifications using all override types.

## Current Empirical Strategy

The main credit-rating results use ordered probit models with Mundlak controls and year indicators. This treats Moody's ratings as ordered categories rather than as a continuous scale.

The repeated-event robustness checks use binary rating-change outcomes:

- downgrade relative to the municipality's pre-event rating,
- upgrade relative to the municipality's pre-event rating,
- any rating change relative to the municipality's pre-event rating.

These binary outcomes are estimated with fixed-effect linear probability models in a stacked repeated-event design.

Numeric Moody's rating models are retained only as secondary rating-notch sensitivity checks.

## Reproducibility Notes

The scripts use project-relative paths and assume the project environment and source data are already prepared. Package installation code is intentionally not included. The raw and source data under `Data and Models/` are read by the workflow but are not modified by these scripts.
