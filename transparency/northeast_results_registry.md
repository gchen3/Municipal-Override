# Northeast Results Registry

## Scope

This registry covers only the models and supporting artifacts presented in `slides/NorthEast_workshop.qmd`. Variable lineage for these models is documented in `transparency/northeast_variable_dictionary.md`.

## Northeast Main Result Models

| result_block | model_family | override_variables | fitted_models | outcome | estimator | specification | slide_artifacts |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Moody's annual override indicators | `moodys_ordered_probit` | `oper_binary`; `oper_binary_win`; `oper_binary_fail` | `active_moodys_annual_attempt`; `active_moodys_annual_success`; `active_moodys_annual_failure` | `MOO_ordered` | `MASS::polr(..., method = "probit")` | Each override variable is estimated in a separate model with active controls, available Mundlak means, and year indicators; municipality-clustered SEs. | `outputs/tables/slides/northeast_moodys_main.tex` |
| Moody's three-year override frequency | `moodys_ordered_probit` | `oper_attempt_cumu_3yr`; `oper_success_cumu_3yr`; `oper_failure_cumu_3yr` | `active_moodys_cumulative_attempt_3yr`; `active_moodys_cumulative_success_3yr`; `active_moodys_cumulative_failure_3yr` | `MOO_ordered` | `MASS::polr(..., method = "probit")` | Each override variable is estimated in a separate model with active controls, available Mundlak means, and year indicators; municipality-clustered SEs. | `outputs/tables/slides/northeast_moodys_frequency.tex` |
| Annual override frequency and yes votes | `vote_share_fe_lm` | `oper_attempt_count`; `oper_success_count`; `oper_failure_count` | `active_vote_share_annual_attempt_count`; `active_vote_share_annual_success_count`; `active_vote_share_annual_failure_count` | `oper_yes_vote_percent` | `fixest::feols` | Each override variable is estimated in a separate model with active controls, municipality fixed effects, and year fixed effects; municipality-clustered SEs. | `outputs/tables/slides/northeast_vote_share_annual.tex` |
| Three-year override frequency and yes votes | `vote_share_fe_lm` | `oper_attempt_cumu_3yr`; `oper_success_cumu_3yr`; `oper_failure_cumu_3yr` | `active_vote_share_cumulative_attempt_3yr`; `active_vote_share_cumulative_success_3yr`; `active_vote_share_cumulative_failure_3yr` | `oper_yes_vote_percent` | `fixest::feols` | Each override variable is estimated in a separate model with active controls, municipality fixed effects, and year fixed effects; municipality-clustered SEs. | `outputs/tables/slides/northeast_vote_share_cumulative.tex` |
| Repeated-event DiD for override attempts | `repeated_event_lpm` | `operating_attempt` event indicator interacted with relative year | `active_did_operating_attempt_rating_downgrade_window_clean_preferred`; `active_did_operating_attempt_rating_upgrade_window_clean_preferred` | `rating_downgrade`; `rating_upgrade` | `fixest::feols` | `window_clean_preferred`; event window `-2:2`; reference year `h = -1`; fixed effects `stack_id^code + stack_id^year`; municipality-clustered SEs. | `outputs/tables/slides/northeast_repeated_event_did_downgrade.tex`; `outputs/tables/slides/northeast_repeated_event_did_upgrade.tex`; `outputs/figures/northeast_event_study_operating_attempt.png` |
| Repeated-event DiD for successful overrides | `repeated_event_lpm` | `operating_success` event indicator interacted with relative year | `active_did_operating_success_rating_downgrade_window_clean_preferred`; `active_did_operating_success_rating_upgrade_window_clean_preferred` | `rating_downgrade`; `rating_upgrade` | `fixest::feols` | `window_clean_preferred`; event window `-2:2`; reference year `h = -1`; fixed effects `stack_id^code + stack_id^year`; municipality-clustered SEs. | `outputs/tables/slides/northeast_repeated_event_did_downgrade.tex`; `outputs/tables/slides/northeast_repeated_event_did_upgrade.tex`; `outputs/figures/northeast_event_study_operating_success.png` |
| Repeated-event DiD for failed overrides | `repeated_event_lpm` | `operating_failure` event indicator interacted with relative year | `active_did_operating_failure_rating_downgrade_window_clean_preferred`; `active_did_operating_failure_rating_upgrade_window_clean_preferred` | `rating_downgrade`; `rating_upgrade` | `fixest::feols` | `window_clean_preferred`; event window `-2:2`; reference year `h = -1`; fixed effects `stack_id^code + stack_id^year`; municipality-clustered SEs. | `outputs/tables/slides/northeast_repeated_event_did_downgrade.tex`; `outputs/tables/slides/northeast_repeated_event_did_upgrade.tex`; `outputs/figures/northeast_event_study_operating_failure.png` |

## Publication Tables

| result_block | publication_table |
| --- | --- |
| Moody's annual override indicators | `outputs/tables/publication/northeast_moodys_main_pub.tex` |
| Moody's three-year override frequency | `outputs/tables/publication/northeast_moodys_frequency_pub.tex` |
| Annual override frequency and yes votes | `outputs/tables/publication/northeast_vote_share_annual_pub.tex` |
| Three-year override frequency and yes votes | `outputs/tables/publication/northeast_vote_share_cumulative_pub.tex` |
| Repeated-event DiD downgrade models | `outputs/tables/publication/northeast_repeated_event_did_downgrade_pub.tex` |
| Repeated-event DiD upgrade models | `outputs/tables/publication/northeast_repeated_event_did_upgrade_pub.tex` |

## Supporting Slide Artifacts

| artifact | category | note |
| --- | --- | --- |
| `northeast_annual_override_amounts.png` | `supporting` | Descriptive figure, not a fitted model. |
| `outputs/tables/slides/northeast_repeated_event_counts.tex` | `supporting` | Sample-construction table, not a fitted model. |

## Relevant Audit Notes

| topic | affected_northeast_models | note | evidence |
| --- | --- | --- | --- |
| Moody's rating coding | `moodys_ordered_probit`; `repeated_event_lpm` | Raw numeric direction and rating-label mapping are not documented in inspected code. | `R/02_build_regression_data.R:34`; `R/active_helpers.R:138-155` |
| Ordered-probit SE fallback | `moodys_ordered_probit` | `cluster_vcov()` falls back to `stats::vcov()` if `sandwich::vcovCL()` errors; outputs do not record whether fallback occurred. | `R/00_config.R:149-153` |
| Override one-year shift | all Northeast operating-override models | Override records are shifted from `FiscalYear` to `year + 1`; substantive reason is not stated in code. | `R/01_build_override_panel.R:16-48`; `R/10_operating_mundlak_models.R:16-32` |
| Active-control repeated-event robustness | `repeated_event_lpm` robustness models | `active_controls_preferred` adds the Table 1/3 active controls while keeping the preferred fixed effects, `stack_id^code + stack_id^year`; it is not part of the Northeast main result model table above. | `R/12_operating_repeated_event_binary_models.R:33-40` |
