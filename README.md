# Municipal Override Project

This project analyzes Massachusetts municipal override elections and their relationship to municipal credit ratings, fiscal conditions, voter turnout, and close-election discontinuities. The current codebase is organized as a reproducible R workflow under `R/`, with intermediate data, tables, figures, and reports written under `outputs/`.

## Current Workflow

The numbered scripts in `R/00_config.R` through `R/12_run_rd_workflow.R` implement two connected analysis tracks.

### Panel and Mundlak Models

The main panel workflow builds a municipality-year analysis file and estimates the core models used in the main tables and appendix tables.

- `R/00_config.R` defines package loading, project-relative paths, variable labels, CPI values, panel helpers, model wrappers, clustered variance estimators, and table-writing utilities.
- `R/01_build_override_panel.R` combines operating, capital, debt, and stabilization override files into municipality-year override measures.
- `R/02_build_regression_data.R` merges the override panel with fiscal data and Moody's/S&P ratings, constructs inflation-adjusted fiscal variables, lagged override measures, 3-year cumulative measures, fiscal-stress indicators, and Mundlak municipality means.
- `R/03_descriptives.R` produces descriptive statistics and credit-rating observation summaries.
- `R/04_models_main_mundlak.R` estimates the main Tables 1-6.
- `R/05_models_robustness.R` estimates appendix robustness tables.
- `R/06_figure_margins.R` estimates predicted Moody's rating probabilities for override/fiscal-stress groups and writes Figure 1.
- `R/07_render_results.R` renders available model outputs and writes an output manifest.
- `R/08_validate_against_method_results.R` checks focal model coefficients and model sample sizes against `Method_Results.docx`.

### Regression Discontinuity Models

The RD workflow studies close override elections around the 50 percent passage cutoff.

- `R/09_build_rd_data.R` builds question-level RD data using vote margins and links each vote to Moody's ratings before and after the election.
- `R/10_rd_main_models.R` estimates operating-only and all-type RD event-study models, including pre/post paths and fiscal-stress splits.
- `R/11_rd_validity_checks.R` runs RD validity and robustness checks: density tests, balance checks, placebo cutoffs, donut specifications, bandwidth sensitivity, and diagnostic plots.
- `R/12_run_rd_workflow.R` runs the RD workflow and renders the RD report when Quarto is available.

## Progress and Current Status

The workflow has been run successfully through the main panel models, robustness models, RD models, validity checks, and report rendering.

Current generated data status:

- Override panel: 4,003 municipality-year rows, 330 municipalities, years 1989-2026.
- Regression panel: 6,669 rows, 351 municipalities, years 2003-2021.
- Moody's rating observations: 3,754 across 266 municipalities.
- S&P rating observations: 2,702.
- RD question data: 11,487 raw override questions across 330 municipalities.
- RD event-study data: 57,960 event rows.

Validation status:

- Validation against `Method_Results.docx` passed for the checked main-model outputs.
- Focal coefficients matched: 34 of 34.
- Model sample sizes matched: 24 of 24.
- RD density test for operating override margins did not reject continuity at the cutoff.
- RD balance checks are broadly clean for the listed pre-treatment covariates.

Output status:

- Main HTML tables exist in `outputs/tables/`.
- Appendix HTML and CSV outputs exist in `outputs/tables/`.
- Main figures and RD diagnostic/event-study figures exist in `outputs/figures/`.
- Rendered reports exist in `outputs/report/`:
  - `main_results_report.html`
  - `main_results_report.docx`
  - `rd_results_report.html`
  - `rd_results_report.docx`
- DOCX table export in `R/07_render_results.R` was skipped in the recorded run because `officer` and `flextable` were not available, but HTML and CSV outputs were written.

## Main Results So Far

The panel/Mundlak models suggest a positive association between override activity and Moody's rating order.

- Any override attempt is positively associated with Moody's rating order.
- Successful overrides are also positively associated with Moody's rating order.
- Failed overrides are not statistically significant in the main credit-rating model.
- Operating override success shows a positive and statistically significant association with Moody's rating order.
- Debt and capital override successes are not statistically significant in the main model.
- Stabilization override success is positive but only marginal in the current estimates.
- Low-reserve fiscal stress strengthens the positive association between overrides and ratings.
- High-debt fiscal-stress interactions are not statistically significant in the checked main results.
- Override activity is positively related to turnout in the fixed-effects turnout models.
- Override frequency and lagged-frequency models for credit ratings are weaker and mostly not statistically significant.

The RD results are more cautious and differ from the panel associations.

- For operating overrides alone, close passage does not show a statistically significant Moody's rating effect at horizons 1 through 5.
- For all override types pooled, close passage is associated with negative and statistically significant Moody's rating effects in years 4 and 5.
- Pre-treatment placebo horizons in the main RD event-study files are not statistically significant.
- Operating-only bandwidth sensitivity checks remain non-significant across the fixed and rdrobust-derived bandwidths.

Overall, the current evidence points to a descriptive panel association between overrides and better credit-rating outcomes, especially for successful operating overrides and low-reserve municipalities. The close-election RD evidence is weaker for operating overrides and suggests that the panel association should not be interpreted as a simple causal effect of close operating-override passage.

## Key Outputs

Important intermediate files:

- `outputs/intermediate/override_all.rds`
- `outputs/intermediate/data_for_regression.rds`
- `outputs/intermediate/main_mundlak_models.rds`
- `outputs/intermediate/robustness_models.rds`
- `outputs/intermediate/rd_question_level_data.rds`
- `outputs/intermediate/rd_main_models.rds`

Important table outputs:

- `outputs/tables/table_1_effects_of_overrides_on_credit_ratings.html`
- `outputs/tables/table_2_fiscal_stress.html`
- `outputs/tables/table_3_override_success.html`
- `outputs/tables/table_4_turnout.html`
- `outputs/tables/table_5_frequency_nonzero.html`
- `outputs/tables/table_6_lagged_frequency.html`
- `outputs/tables/rd_event_study_operating.csv`
- `outputs/tables/rd_event_study_all_types.csv`
- `outputs/tables/rd_balance_checks.csv`
- `outputs/tables/rd_bandwidth_sensitivity.csv`

Important figure outputs:

- `outputs/figures/figure_1_predicted_probabilities.png`
- `outputs/figures/rd_event_study_moodys.png`
- `outputs/figures/rd_event_study_moodys_pre_post.png`
- `outputs/figures/rd_density_margin.png`
- `outputs/figures/rd_moodys_binned_plot.png`

## Reproducibility Notes

The scripts use project-relative paths and assume the project environment and source data are already prepared. Package installation code is intentionally not included. The raw and source data under `Data and Models/` are read by the workflow but are not modified by these scripts.

