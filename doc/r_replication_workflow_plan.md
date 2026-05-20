# R Replication Plan for the Municipal Override Stata Workflow

## Big Picture Review

The newest substantive Stata workflow is `Data and Models/6.5/5.4 most latest [confirmed by 4.1.2026].do`. It was last modified June 6, 2025, and is the only `.do` file that starts from raw override files, builds the regression dataset, runs descriptives, estimates the main and appendix models, and exports tables.

The newer-timestamped `Data and Models/6.5/5.4_1画不出的图1.do` from May 2, 2026 is a figure-only troubleshooting script. It should be used only to reconstruct Figure 1 logic, not as the main workflow.

Older scripts are superseded:

- `Data and Models/6.2/5.3_1 clean for share.do`: regression-only, starts from `data for regression.dta`, older than 6.5.
- `Data and Models/5.27/*.do`: older model ordering/subsample variants.
- `Data and Models/5.14/2.5 clear for share.do`: older specification with different controls.
- `Data and Models/6.2/GC/*.do`: small exploratory/attempt files.

The target document `Data and Models/6.22/Method_Results.docx` was modified August 12, 2025. It reports Figure 1, Tables 1-6, and Appendix Tables A1-A11. The R workflow should prioritize reproducing those outputs, using the 6.5 `.do` file as source logic.

## Key Workflow

Build a clean R pipeline with `targets` or a simple numbered-script workflow. Use these scripts:

1. `R/00_config.R`
   - Define paths, CPI lookup, package loading, common variable labels, and reusable helpers.
   - Use `haven::read_dta()` during implementation/runtime; no data contents were inspected while developing this plan.
   - Use `dplyr`, `tidyr`, `fixest`, `ordinal` or `MASS`, `sandwich`, `lmtest`, `marginaleffects`, `modelsummary`, `gt`, and `officer`/`flextable`.

2. `R/01_build_override_panel.R`
   - Read the four override files: `override_override.dta`, `override_capital.dta`, `override_debt.dta`, `override_stable.dta`.
   - Append them and aggregate to municipality-year.
   - Reproduce Stata variables:
     - `num_attempt`, `num_success`, `num_fail`
     - `amount_all`, `amount_win`
     - type indicators for operating, debt, capital, stable; each with attempt/win/fail variants
     - `turnout_avg`
     - `binaryover`, `binarysucc`, `binaryfail`
     - `yes_percent`
   - Shift override fiscal year forward by one year, matching `replace year = year + 1`.
   - Save an intermediate `override_all.rds`; do not write intermediate `.dta` files.

3. `R/02_build_regression_data.R`
   - Read `data_extended from PPMRdata for override project.dta`.
   - Left join Moody's data from `MOO(补充2011credit).dta` by `year, code`.
   - Left join `override_all`.
   - Drop `year > 2021`, then drop `year < 2003` after lag/cumulative construction, matching the Stata order.
   - Apply CPI real-dollar conversion to 2003 dollars.
   - Construct fiscal controls:
     - `taxperca`, `excessperca`, `revperca`, `expperca`
     - `balance`
     - `unabsorbedratio`
     - `turnoutrate = log(turnout_avg / lag(popu))`
   - Construct lagged and 3-year cumulative override measures by municipality.
   - Create `highfiscal1`: bottom tercile of `unabsorbedratio` within year.
   - Create `highfiscal3`: top tercile of `debtbudg` within year.
   - Recode Moody's and S&P ratings exactly as in Stata, with Moody's as ordered 1-10.
   - Create Mundlak means: municipality-level means of each time-varying predictor used in ordered probit models.
   - Save `data_for_regression.rds`.

4. `R/03_descriptives.R`
   - Reproduce Appendix Table A2 descriptive statistics from the document.
   - Also produce the credit-rating observation table corresponding to Appendix Table A1.
   - Use the Stata `sample` logic carefully: mark observations included in at least one relevant model before producing model-sample descriptives.

5. `R/04_models_main_mundlak.R`
   - Reproduce main document Tables 1-6.
   - Ordered probit models use Moody's rating as ordered outcome, year fixed effects, cluster-robust SEs by municipality, and Mundlak municipality means.
   - Linear fixed-effect models for `yes_percent` and `turnoutrate` use municipality and year fixed effects with clustered SEs.
   - Table mapping:
     - Table 1: binary override attempt/success/failure and successful-type models.
     - Table 2: interactions with low reserve stress and high debt stress.
     - Table 3: override frequency predicting success outcomes.
     - Table 4: override activity predicting turnout.
     - Table 5: frequency/count measures using nonzero-only variables.
     - Table 6: lagged frequency/count models.

6. `R/05_models_robustness.R`
   - Reproduce Appendix Tables A3-A11.
   - Run the non-Mundlak/random-effects-style versions from the earlier section of the 6.5 `.do`.
   - Include:
     - no-Mundlak versions of Tables 1-6
     - lagged binary override models
     - full-sample frequency models
     - amount models for override success

7. `R/06_figure_margins.R`
   - Reproduce Figure 1 from the ordered probit interaction model:
     - `MOO ~ binaryover * highfiscal1 + controls + Mundlak means + factor(year)`
   - Compute predicted probabilities for Moody's outcomes 1-10 across four groups:
     - no override / no fiscal stress
     - no override / fiscal stress
     - override / no fiscal stress
     - override / fiscal stress
   - Use `marginaleffects` or simulation from the fitted ordered probit model.
   - Export a publication-ready PNG and a CSV of plotted estimates.

8. `R/07_render_results.R`
   - Export standalone R outputs using `modelsummary`, `gt`, `flextable`, and `officer` or Quarto-ready table files.
   - Use clear table titles and notes, but do not require exact visual matching to `Method_Results.docx`.
   - Save all outputs under `outputs/tables/`, `outputs/figures/`, and `outputs/intermediate/`.

9. `R/09_run_stata_replication.R`
   - Run the original Stata-replication workflow from `R/01` through `R/08`.
   - This track should pass validation against `Method_Results.docx`.

10. `R/10_run_did_workflow.R`
   - Run the repeated-event DiD extension workflow from `R/13` through `R/16`.

11. `R/11_run_all_active_workflow.R`
   - Run both active tracks in order.

12. `R/12_did_rating_change_helpers.R`
   - Define shared downgrade, upgrade, and any-change helpers for repeated-event scripts.

13. `R/13_build_did_repeated_event_data.R`
   - Build stacked repeated-event samples for successful operating override events.
   - Use clean event windows that reduce overlap from repeated operating override events.

14. `R/14_did_repeated_event_models.R`
   - Estimate repeated-event robustness models.
   - Treat binary downgrade, upgrade, and any rating change outcomes as the main repeated-event robustness checks.
   - Keep numeric Moody's rating models only as secondary rating-notch sensitivity checks.

15. `R/15_did_repeated_event_attempt_failure_models.R`
   - Estimate attempt and failure repeated-event specifications as exploratory or appendix robustness checks.

16. `R/16_did_repeated_event_all_override_models.R`
   - Estimate all-override repeated-event specifications as exploratory or appendix robustness checks.

## Modeling Decisions

Use the 6.5 Mundlak section as the primary model source because the Word document describes Mundlak as the main specification. Treat the earlier non-Mundlak block in the same `.do` file as robustness output.

For ordered probit with clustered SEs, use `MASS::polr(method = "probit")` or `ordinal::clm(link = "probit")`, then compute municipality-clustered covariance with `sandwich` where supported. If clustered SE extraction is unstable for ordered models, use a documented bootstrap-by-municipality fallback.

For linear fixed-effect models, use `fixest::feols()` with `vcov = ~ code`.

For binary probit models, use `glm(..., family = binomial(link = "probit"))` with clustered covariance by `code`.

## R Coding Style

Follow the project guidance in `AGENTS.md`:

- Use project-relative paths through a central config helper; do not use absolute paths or `setwd()`.
- Keep scripts flat and reviewable, with descriptive `snake_case` object names.
- Do not include package installation code.
- Keep console output minimal; avoid `cat()`, `print()`, or `message()` unless a validation step needs explicit output.
- Comment on why a Stata behavior is replicated or why a workaround is needed, not on obvious transformations.
- Do not modify raw data files or generated result files except through the planned R output folders.

## Test Plan

Validate the R workflow against Stata logic. Reading `.dta` files in R to run the workflow is acceptable, but avoid manual browsing or summarizing raw data beyond validation counts and model outputs.

- Check row counts after each major join and after year restrictions.
- Check key created variables against Stata formulas: override counts, cumulative 3-year measures, fiscal stress terciles, CPI-adjusted variables, and Moody's recode.
- Confirm output coverage: Figure 1, Tables 1-6, and Appendix Tables A1-A11.
- Compare model `N`, pseudo-R2/R2, coefficient signs, and stars against `Method_Results.docx`.
- Replicate Stata behavior first. Document known Stata quirks and suggested fixes in `doc/stata_workflow_issues.md` rather than silently changing the initial R replication.

## Assumptions

The R implementation should replicate the newest Stata workflow first, including questionable Stata behavior where needed for parity. Suggested corrections belong in `doc/stata_workflow_issues.md`.

The target is reproduction of `Method_Results.docx`, so `Tables_mundlak.rtf` logic from the 6.5 script takes priority over older `Tables.rtf` logic.

The separate 2026 figure `.do` file should inform Figure 1 formatting only; the model specification should come from the main 6.5 script and the Word document.

Regression-discontinuity work is not part of the active workflow.

Intermediate workflow outputs should be R-native files such as `.rds` and `.csv`; do not write intermediate `.dta` files unless specifically requested later.
