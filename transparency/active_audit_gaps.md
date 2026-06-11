# Active Audit Gaps

## Files Inspected

- `README.md`
- `AGENTS.md`
- `R/run_active_workflow.R`
- `R/00_config.R`
- `R/01_build_override_panel.R`
- `R/02_build_regression_data.R`
- `R/active_helpers.R`
- `R/10_operating_mundlak_models.R`
- `R/11_build_operating_repeated_event_data.R`
- `R/12_operating_repeated_event_binary_models.R`
- `R/13_prepare_slide_tables.R`
- `R/14_prepare_slide_figures.R`
- `slides/NorthEast_workshop.qmd`
- relevant file names under `outputs/tables/`

## Files Created

- `transparency/active_model_registry.md`
- `transparency/active_variable_dictionary.md`
- `transparency/active_audit_gaps.md`

## Active Model Families Found

- Moody's ordered probit models for annual operating override indicators and three-year cumulative operating counts.
- Operating yes-vote percentage two-way fixed-effect linear models for annual and three-year cumulative operating counts.
- Repeated-event binary rating-change linear probability models for downgrade and upgrade outcomes, across preferred and robustness variants.

## Important UNKNOWN Fields

1. Raw source-data coding for Moody's ratings is not documented in inspected code.
2. The substantive direction and label mapping of `MOO_num` are not documented, though downgrade/upgrade code treats lower values as downgrades and higher values as upgrades.
3. Source construction for several controls imported from source data is not explicit in inspected active code: `debtbudg`, `unemploy`, and `revstab`.
4. Raw source coding for `Override` and `WinLoss` was not audited beyond the code expressions using `"operating"`, `"WIN"`, and `"LOSS"`.
5. Exact source-data units for per-capita variables using `popu * 1000` need human/source review.

## Model Details Needing Human Review

1. `history_controls` repeated-event models change fixed effects from `stack_id^code + stack_id^year` to `code + stack_id^year`. This is explicit in code, but the substantive reason should be reviewed.
2. `years_since_last_focal_event_filled` uses `99` for no prior focal event. This is explicit in code, but the fill value should be reviewed.
3. Window-clean controls exclude same-focal events in the event window. They may still have other operating event types in the window; the script records those counts but does not exclude them unless they are the focal type.
4. Ordered probit clustered standard errors have fallback behavior: if `sandwich::vcovCL()` errors, `stats::vcov()` is used. The active outputs do not appear to record whether fallback occurred.

## Sample Restrictions That Are Unclear Or Need Review

1. `complete_model_data()` drops rows with missing model variables and `code`; this is clear in code, but final complete-case samples were not recomputed in this audit.
2. Moody's table notes report complete-case years as 2003-2015, 2017, and 2019-2021. This was taken from table-writing code rather than recalculated.
3. Vote-share table notes report complete-case years as 2003-2021. This was taken from table-writing code rather than recalculated.
4. Repeated-event table notes report event years 2005-2019 and stacked panel years 2003-2021. This was taken from table-writing code and event-window logic rather than recalculated.

## Standard Error Or Clustering Details Needing Review

1. Ordered probit models use `sandwich::vcovCL()` clustered by `code`, but fallback to unclustered `stats::vcov()` is possible if `vcovCL()` errors.
2. Vote-share and repeated-event DiD models use `fixest::feols(..., vcov = ~ code)`, which clusters by municipality code.
3. No weights are explicit in the active fit commands.

## Output Files That Could Not Be Mapped To Models

1. The requested `outputs/report/main_results/main_results_10_14.md` was not present when this audit was written.
2. Figure outputs are linked to model families but are not fitted models: `northeast_annual_override_amounts.png` is descriptive, while event-study figures are rendered from preferred repeated-event DiD results.
3. Sample-count outputs are linked to repeated-event data construction, not fitted models.

## Risks Of Unsupported Interpretation

1. Do not interpret ordered-probit coefficient magnitudes as probability-point effects without additional marginal-effect calculations.
2. Do not infer causal effects from the Moody's ordered-probit or vote-share FE models without additional design assumptions not encoded in this audit.
3. Do not treat repeated-event robustness variants as headline results unless the preferred/main flag is explicitly added in a later registry.
4. Do not infer raw data definitions from variable names when construction is not explicit in code.
