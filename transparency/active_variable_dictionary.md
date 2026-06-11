# Active Variable Dictionary

## Scope

This dictionary records important variables used by the active operating-override models. `UNKNOWN` means the inspected code did not make the detail explicit. Raw lineage is shown with source aliases so each row can be traced back to raw data files and raw field names.

## Source File Index

| Alias | Raw data file(s) | Notes |
| --- | --- | --- |
| `base_data` | `Data and Models/6.5/data_extended from PPMRdata for override project.dta` | Main municipal-year fiscal and demographic panel. |
| `moody_data` | `Data and Models/6.5/MOO*.dta` | Loaded through `moody_file()`; current data folder has one matching file. |
| `override_files` | `Data and Models/6.5/override_override.dta`; `Data and Models/6.5/override_capital.dta`; `Data and Models/6.5/override_debt.dta`; `Data and Models/6.5/override_stable.dta` | Active override files read together by `override_source_files`. |
| `model-derived` | Not a raw file | Constructed after raw joins for model formulas, repeated-event stacks, or rating-change outcomes. |

## Audit Status Values

| Status | Meaning |
| --- | --- |
| `direct` | Variable exists directly in at least one raw data file. |
| `derived` | Variable is constructed from raw data variables before modeling. |
| `model-derived` | Variable is constructed for formulas, Mundlak means, repeated-event stacks, or model outcomes. |
| `needs review` | Variable exists or is constructed in code, but source meaning, coding, or interpretation needs human review. |

## Source Lineage

| Variable | Audit status | Label | Source alias(es) | Raw variable(s) | Construction rule |
| --- | --- | --- | --- | --- | --- |
| code | direct | municipality identifier | `base_data`; `moody_data`; `override_files` | `code` | used as merge key and panel identifier |
| year | derived | fiscal/calendar year variable used in panel models | `base_data`; `moody_data`; `override_files` | `year`; `FiscalYear` | override panel sets `year = FiscalYear` then later `year = year + 1`; operating count panel in active script also shifts `FiscalYear` by one year |
| MOO | needs review | Moody's raw rating field | `moody_data` | `MOO` | read from `moody_file()` and joined by `year` and `code` |
| MOO_num | derived | numeric Moody's rating | `moody_data` | `MOO` | `suppressWarnings(as.numeric(MOO))` |
| MOO_ordered | model-derived | ordered Moody's rating outcome | `moody_data` | `MOO` | assigned equal to `MOO_num`; converted to ordered factor inside `fit_ordered_probit()` |
| baseline_moo_num | model-derived | stack-specific baseline Moody's numeric rating | `moody_data` | `MOO` via `MOO_num` | first `MOO_num` for each `stack_id` and `code` where `rel_year == -1` |
| rating_downgrade | model-derived | binary indicator for downgrade relative to `h = -1` | `moody_data` | `MOO` via `MOO_num` and `baseline_moo_num` | `as.numeric(MOO_num < baseline_moo_num)` when both current and baseline ratings are non-missing |
| rating_upgrade | model-derived | binary indicator for upgrade relative to `h = -1` | `moody_data` | `MOO` via `MOO_num` and `baseline_moo_num` | `as.numeric(MOO_num > baseline_moo_num)` when both current and baseline ratings are non-missing |
| oper_binary | derived | annual indicator for any operating override attempt | `override_files` | `Override`; `WinLoss`; `FiscalYear`; `code` | `as.numeric(any(Override == "operating", na.rm = TRUE))` by municipality-year, then missing values replaced with zero in regression data |
| oper_binary_win | derived | annual indicator for any successful operating override | `override_files` | `Override`; `WinLoss`; `FiscalYear`; `code` | `as.numeric(any(Override == "operating" & WinLoss == "WIN", na.rm = TRUE))`, then missing values replaced with zero in regression data |
| oper_binary_fail | derived | annual indicator for any failed operating override | `override_files` | `Override`; `WinLoss`; `FiscalYear`; `code` | `as.numeric(any(Override == "operating" & WinLoss == "LOSS", na.rm = TRUE))`, then missing values replaced with zero in regression data |
| oper_attempt_count | derived | count of operating override attempts | `override_files` | `Override`; `FiscalYear`; `code` | count of rows where `Override == "operating"` grouped by `code` and shifted year |
| oper_success_count | derived | count of successful operating overrides | `override_files` | `Override`; `WinLoss`; `FiscalYear`; `code` | sum of `WinLoss == "WIN"` among operating overrides grouped by `code` and shifted year |
| oper_failure_count | derived | count of failed operating overrides | `override_files` | `Override`; `WinLoss`; `FiscalYear`; `code` | sum of `WinLoss == "LOSS"` among operating overrides grouped by `code` and shifted year |
| oper_yes_vote_percent | derived | operating yes-vote percentage | `override_files` | `Override`; `YesVotes`; `NoVotes`; `FiscalYear`; `code` | `100 * oper_yes_votes / oper_total_votes` when `oper_total_votes > 0` |
| oper_attempt_cumu_3yr | derived | three-year cumulative operating attempt count | `override_files` | `Override`; `FiscalYear`; `code` via `oper_attempt_count` | `l2_oper_attempt_count + l1_oper_attempt_count + oper_attempt_count` |
| oper_success_cumu_3yr | derived | three-year cumulative successful operating override count | `override_files` | `Override`; `WinLoss`; `FiscalYear`; `code` via `oper_success_count` | `l2_oper_success_count + l1_oper_success_count + oper_success_count` |
| oper_failure_cumu_3yr | derived | three-year cumulative failed operating override count | `override_files` | `Override`; `WinLoss`; `FiscalYear`; `code` via `oper_failure_count` | `l2_oper_failure_count + l1_oper_failure_count + oper_failure_count` |
| logpopu | derived | population size, log | `base_data` | `logpopu`; fallback from `popu` | `if_else(is.na(logpopu), log(popu), logpopu)` |
| debtbudg | needs review | outstanding debt level | `base_data` | `debtbudg` | not transformed in inspected active construction code |
| unemploy | needs review | unemployment rate | `base_data` | `unemploy` | not transformed in inspected active construction code |
| revstab | needs review | revenue stability | `base_data` | `revstab` | not transformed in inspected active construction code |
| revperca | derived | government revenue per capita | `base_data` | `rev` and `popu` | revenue deflated by CPI and divided by `popu * 1000` |
| excessperca | derived | excess property tax capacity | `base_data` | `excess` and `popu` | `excess` deflated by CPI and divided by `popu * 1000` |
| unabsorbedratio | derived | fiscal reserve | `base_data` | `stabilization`; `freecash`; `Operating_Budget_Prior_Year_stab` | `(stabilization + freecash) * 100 / Operating_Budget_Prior_Year_stab` |
| balance | derived | budget balance | `base_data` | `rev`; `exp` | `(rev - exp) * 100 / rev` after revenue and expenditure are CPI-adjusted |
| *_con variables | model-derived | municipality-level means used as Mundlak controls | derived from model variables after joins | source variables vary by `{variable}con` | grouped by `code`, apply `mean_na`, name as `{variable}con`; active cumulative operating count means are added in `R/10` |
| event_type | model-derived | operating repeated-event type | derived from active event definitions | not raw; based on `oper_binary`, `oper_binary_win`, `oper_binary_fail` | one of `operating_attempt`, `operating_success`, or `operating_failure` |
| event_year | model-derived | focal event year | `override_files` | `FiscalYear` shifted to `year` through operating event variables | `event_year = year` for clean focal events |
| stack_id | model-derived | repeated-event stack identifier | derived from repeated-event stacks | `file_stub`; `event_code`; `event_year` | `paste0(file_stub, "_", event_code, "_", event_year)` |
| rel_year | model-derived | year relative to focal event | derived from repeated-event stacks | `event_year` and configured event window | expanded over `active_event_times`, which equals `-2:2` |
| treated_event | model-derived | treated municipality row indicator within a repeated-event stack | derived from repeated-event stacks | `event_code`; `code`; `event_year` | treatment rows use event municipality and `treated_event = 1`; control rows use non-event municipalities and `treated_event = 0` |
| control_pool | model-derived | control pool type | derived from repeated-event stacks | `oper_binary`; `oper_binary_win`; `oper_binary_fail`; `code`; `year` | `window_clean` controls have no same-focal event in the stack window; `never_treated` controls never have the focal event; treatment rows use `"treated"` |
| prior_focal_event_count | model-derived | count of prior same-focal events before the stack event year | `override_files` | focal event variable derived from `Override`; `WinLoss`; `FiscalYear`; `code` | sum prior `focal_event` for each stack and code where `history_year < event_year` |
| prior_oper_attempt_count | model-derived | count of prior operating override attempts | `override_files` | `Override`; `FiscalYear`; `code` via `oper_binary` | sum prior `oper_attempt_event` for each stack and code |
| prior_oper_success_count | model-derived | count of prior successful operating overrides | `override_files` | `Override`; `WinLoss`; `FiscalYear`; `code` via `oper_binary_win` | sum prior `oper_success_event` for each stack and code |
| prior_oper_failure_count | model-derived | count of prior failed operating overrides | `override_files` | `Override`; `WinLoss`; `FiscalYear`; `code` via `oper_binary_fail` | sum prior `oper_failure_event` for each stack and code |
| years_since_last_focal_event_filled | model-derived | years since last same-focal event, filled for no prior event | `override_files` | focal event variable derived from `Override`; `WinLoss`; `FiscalYear`; `code` | `event_year - last_focal_event_year`, with missing values replaced by `99` |
| post_prior_focal_event | model-derived | indicator for any prior same-focal event before the stack event year | `override_files` | focal event variable derived from `Override`; `WinLoss`; `FiscalYear`; `code` | `as.numeric(prior_focal_event_count > 0)` |

## Model Use And Audit Notes

| Variable | Transformation | Unit | Models where used | Source-code evidence | Unresolved questions |
| --- | --- | --- | --- | --- | --- |
| code | none found | municipality code | cluster variable in all active models; fixed effect in vote-share and repeated-event models | `R/02_build_regression_data.R:15-18`; `R/00_config.R:137-147`; `R/00_config.R:181-197`; `R/active_helpers.R:169-177` | raw source coding scheme is UNKNOWN |
| year | one-year shift for override measures | year | year indicators or year fixed effects; repeated-event stack years | `R/01_build_override_panel.R:16-18`; `R/01_build_override_panel.R:42-48`; `R/10_operating_mundlak_models.R:16-32`; `R/00_config.R:187-197`; `R/11_build_operating_repeated_event_data.R:126-129` | substantive reason for one-year shift is not stated in code |
| MOO | converted to numeric `MOO_num` | Moody's rating scale, raw coding UNKNOWN | source for `MOO_num` and `MOO_ordered` | `R/00_config.R:40-45`; `R/02_build_regression_data.R:11-18`; `R/02_build_regression_data.R:34` | raw rating labels and numeric direction are UNKNOWN from inspected code |
| MOO_num | numeric coercion from `MOO` | numeric Moody's rating code | repeated-event downgrade/upgrade construction; source for `MOO_ordered` | `R/02_build_regression_data.R:34`; `R/02_build_regression_data.R:151-153`; `R/active_helpers.R:138-155` | whether higher values always mean better ratings is inferred from downgrade/upgrade code but not documented in labels |
| MOO_ordered | ordered levels sorted from observed `MOO_num` | ordered Moody's rating code | all Moody's ordered probit models | `R/02_build_regression_data.R:151-153`; `R/00_config.R:156-172`; `R/10_operating_mundlak_models.R:82-111` | substantive mapping from numeric code to rating labels is UNKNOWN |
| baseline_moo_num | within-stack baseline extraction | numeric Moody's rating code | source for `rating_downgrade` and `rating_upgrade` | `R/active_helpers.R:138-155` | behavior with multiple `rel_year == -1` rows is implicit in `[1]` |
| rating_downgrade | binary indicator | 0/1 | repeated-event DiD downgrade models | `R/active_helpers.R:138-155`; `R/active_helpers.R:95`; `R/12_operating_repeated_event_binary_models.R:25-27` | depends on numeric rating direction from source data |
| rating_upgrade | binary indicator | 0/1 | repeated-event DiD upgrade models | `R/active_helpers.R:138-155`; `R/active_helpers.R:95`; `R/12_operating_repeated_event_binary_models.R:25-27` | depends on numeric rating direction from source data |
| oper_binary | binary indicator; override year shifted by one year | 0/1 | Moody's annual attempt model; operating attempt event definition | `R/01_build_override_panel.R:20-48`; `R/02_build_regression_data.R:42-52`; `R/11_build_operating_repeated_event_data.R:13-20` | source coding of `Override` is not audited beyond code expression |
| oper_binary_win | binary indicator; override year shifted by one year | 0/1 | Moody's annual success model; operating success event definition | `R/01_build_override_panel.R:20-48`; `R/02_build_regression_data.R:42-52`; `R/11_build_operating_repeated_event_data.R:13-20` | source coding of `WinLoss` is not audited beyond code expression |
| oper_binary_fail | binary indicator; override year shifted by one year | 0/1 | Moody's annual failure model; operating failure event definition | `R/01_build_override_panel.R:20-48`; `R/02_build_regression_data.R:42-52`; `R/11_build_operating_repeated_event_data.R:13-20` | source coding of `WinLoss` is not audited beyond code expression |
| oper_attempt_count | missing counts replaced with zero | count | annual vote-share attempt model; source for `oper_attempt_cumu_3yr` | `R/10_operating_mundlak_models.R:12-44`; `R/active_helpers.R:19-26` | none identified beyond source data provenance |
| oper_success_count | missing counts replaced with zero | count | annual vote-share success model; source for `oper_success_cumu_3yr` | `R/10_operating_mundlak_models.R:12-44`; `R/active_helpers.R:19-26` | none identified beyond source data provenance |
| oper_failure_count | missing counts replaced with zero | count | annual vote-share failure model; source for `oper_failure_cumu_3yr` | `R/10_operating_mundlak_models.R:12-44`; `R/active_helpers.R:19-26` | none identified beyond source data provenance |
| oper_yes_vote_percent | percentage | percent | all operating yes-vote share models | `R/10_operating_mundlak_models.R:20-32`; `R/10_operating_mundlak_models.R:82-119` | treatment of multi-question municipality-years is aggregation by sums; substantive interpretation should be reviewed |
| oper_attempt_cumu_3yr | rolling current plus two lag years; municipality-specific lags require consecutive years through `lag_panel()` | count | Moody's cumulative attempt model; vote-share cumulative attempt model | `R/10_operating_mundlak_models.R:45-65`; `R/00_config.R:103-108` | none identified |
| oper_success_cumu_3yr | rolling current plus two lag years; municipality-specific lags require consecutive years through `lag_panel()` | count | Moody's cumulative success model; vote-share cumulative success model | `R/10_operating_mundlak_models.R:45-65`; `R/00_config.R:103-108` | none identified |
| oper_failure_cumu_3yr | rolling current plus two lag years; municipality-specific lags require consecutive years through `lag_panel()` | count | Moody's cumulative failure model; vote-share cumulative failure model | `R/10_operating_mundlak_models.R:45-65`; `R/00_config.R:103-108` | none identified |
| logpopu | log population where missing | log population | Moody's and vote-share models | `R/00_config.R:75`; `R/02_build_regression_data.R:31-34`; `R/active_helpers.R:8-11` | original source definition of `logpopu` is UNKNOWN |
| debtbudg | UNKNOWN | percent, per label | Moody's and vote-share models | `R/00_config.R:75-83`; `R/active_helpers.R:8-11` | source construction is UNKNOWN |
| unemploy | UNKNOWN | percent, per label | Moody's and vote-share models | `R/00_config.R:75-83`; `R/active_helpers.R:8-11` | source construction is UNKNOWN |
| revstab | UNKNOWN | percent, per label | Moody's and vote-share models | `R/00_config.R:75-83`; `R/active_helpers.R:8-11` | source construction is UNKNOWN |
| revperca | real per-capita value using CPI base 184 | revenue per capita | Moody's and vote-share models | `R/02_build_regression_data.R:20-30`; `R/00_config.R:75-83`; `R/active_helpers.R:8-11` | exact dollar unit after `popu * 1000` requires source data review |
| excessperca | real per-capita value using CPI base 184 | excess capacity per capita | Moody's and vote-share models | `R/02_build_regression_data.R:20-30`; `R/00_config.R:75-83`; `R/active_helpers.R:8-11` | exact dollar unit after `popu * 1000` requires source data review |
| unabsorbedratio | ratio times 100 | percent | Moody's and vote-share models | `R/02_build_regression_data.R:31-33`; `R/00_config.R:75-83`; `R/active_helpers.R:8-11` | source definitions of `stabilization`, `freecash`, and budget field are UNKNOWN |
| balance | percent of revenue | percent | Moody's and vote-share models | `R/02_build_regression_data.R:20-33`; `R/00_config.R:75-84`; `R/active_helpers.R:8-11` | source definitions of `rev` and `exp` are UNKNOWN |
| *_con variables | municipality-level mean over observed panel values | same as source variable | Moody's ordered probit models; not used in active vote-share FE or DiD models | `R/02_build_regression_data.R:127-149`; `R/10_operating_mundlak_models.R:67-80`; `R/10_operating_mundlak_models.R:89-100` | exact time span included in each upstream mean depends on available `data_for_regression` |
| event_type | assigned from event definitions | category | separates repeated-event model families | `R/active_helpers.R:51-56`; `R/11_build_operating_repeated_event_data.R:70-124` | none identified |
| event_year | filtered to allow full `-2:2` window | year | repeated-event stacks and stack-by-year fixed effects | `R/11_build_operating_repeated_event_data.R:74-129` | none identified |
| stack_id | constructed string id | stack id | repeated-event fixed effects | `R/11_build_operating_repeated_event_data.R:117-129`; `R/active_helpers.R:157-167` | none identified |
| rel_year | `year = event_year + rel_year` | relative year | repeated-event DiD event-time indicators | `R/active_helpers.R:48-49`; `R/11_build_operating_repeated_event_data.R:126-129`; `R/active_helpers.R:157-167` | none identified |
| treated_event | binary indicator | 0/1 | repeated-event DiD interaction with `rel_year` | `R/11_build_operating_repeated_event_data.R:169-213`; `R/active_helpers.R:157-167` | none identified |
| control_pool | category | category | repeated-event model variants | `R/11_build_operating_repeated_event_data.R:183-213`; `R/12_operating_repeated_event_binary_models.R:28-58` | window-clean controls may still have other operating event types; counts are tracked but not excluded unless they are the focal type |
| prior_focal_event_count | count | count | repeated-event `history_controls` variant and first-time event filter | `R/11_build_operating_repeated_event_data.R:22-68`; `R/12_operating_repeated_event_binary_models.R:14-23`; `R/12_operating_repeated_event_binary_models.R:39-51` | none identified |
| prior_oper_attempt_count | count | count | repeated-event `history_controls` variant | `R/11_build_operating_repeated_event_data.R:22-68`; `R/12_operating_repeated_event_binary_models.R:14-18` | none identified |
| prior_oper_success_count | count | count | repeated-event `history_controls` variant | `R/11_build_operating_repeated_event_data.R:22-68`; `R/12_operating_repeated_event_binary_models.R:14-18` | none identified |
| prior_oper_failure_count | count | count | repeated-event `history_controls` variant | `R/11_build_operating_repeated_event_data.R:22-68`; `R/12_operating_repeated_event_binary_models.R:14-18` | none identified |
| years_since_last_focal_event_filled | numeric fill value 99 | years | repeated-event `history_controls` variant | `R/11_build_operating_repeated_event_data.R:36-55`; `R/12_operating_repeated_event_binary_models.R:14-18` | substantive meaning of fill value 99 should be reviewed |
| post_prior_focal_event | binary indicator | 0/1 | repeated-event `history_controls` variant | `R/11_build_operating_repeated_event_data.R:51-55`; `R/12_operating_repeated_event_binary_models.R:14-18` | none identified |
