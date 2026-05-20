# Methods Summary

The active workflow preserves `R/00` through `R/09` as the frozen Stata-replication track. Scripts `R/10` through `R/15` estimate, summarize, and run the current operating-override analyses. `R/15_run_all_active_workflow.R` runs the active workflow end to end.

## Operating Override Models

The active cross-sectional panel models focus on operating overrides. The regression panel covers 2003 through 2021. Override activity is shifted forward one year from the source `FiscalYear` before it is joined to the regression panel, so override activity is aligned with the following regression year.

The Moody's rating outcome is `MOO_ordered`, an ordered version of the numeric Moody's rating score. The voter-support outcome is `yes_percent`, the percentage of override attempts that passed in a municipality-year. Municipality-years with no override attempts have missing `yes_percent` and are dropped from the complete-case voter-support models.

The shared time-varying controls are:

```r
logpopu + debtbudg + unemploy + revstab + revperca +
  excessperca + unabsorbedratio + balance
```

### Moody's Ratings

Moody's ratings are estimated with ordered probit models because the rating scale is ordinal. The active specifications are:

```r
MOO_ordered ~ oper_binary + controls + Mundlak controls + factor(year)
MOO_ordered ~ oper_binary_win + controls + Mundlak controls + factor(year)
MOO_ordered ~ oper_binary_fail + controls + Mundlak controls + factor(year)
```

`oper_binary` indicates any operating override attempt, `oper_binary_win` indicates any successful operating override, and `oper_binary_fail` indicates any failed operating override. The Mundlak controls are municipality-level means of the operating term and the time-varying controls. They adjust for persistent municipality differences that may be correlated with override behavior, while year indicators absorb common shocks. Standard errors are clustered by municipality.

These models are written by `R/10_operating_mundlak_models.R` to:

```r
outputs/tables/active_operating_moodys_main.html
outputs/intermediate/active_operating_mundlak_models.rds
```

### Voter Support

The voter-support models follow the Stata-replication logic: the annual passage percentage is modeled using the frequency of override activity, not contemporaneous binary passage indicators. The active operating-specific variables are:

```r
oper_attempt_count
oper_success_count
oper_failure_count
oper_attempt_cumu_3yr
oper_success_cumu_3yr
oper_failure_cumu_3yr
```

The three-year cumulative variables equal the current year plus the two prior years. These operating frequency variables are rebuilt inside `R/10_operating_mundlak_models.R` from the original override source files, shifted forward one year from source `FiscalYear`, and joined to the regression panel.

The voter-support models are fixed-effects linear models with municipality and year fixed effects and municipality-clustered standard errors:

```r
yes_percent ~ oper_attempt_count + controls | code + year
yes_percent ~ oper_success_count + controls | code + year
yes_percent ~ oper_failure_count + controls | code + year
yes_percent ~ oper_attempt_cumu_3yr + controls | code + year
yes_percent ~ oper_success_cumu_3yr + controls | code + year
yes_percent ~ oper_failure_cumu_3yr + controls | code + year
```

These models are written to:

```r
outputs/tables/active_operating_vote_share_main.html
outputs/intermediate/active_operating_mundlak_models.rds
```

## Repeated-Event DiD for Binary Rating Changes

As a robustness design, the active workflow estimates repeated-event DiD models for binary Moody's rating-change outcomes. The event types are:

```r
operating_attempt
operating_success
operating_failure
```

For each clean event, the stacked panel keeps an event window of `h = -2, -1, 0, 1, 2`. Event candidates must have a full two-year pre- and post-window inside the available panel. A clean treated event has no other same-type operating event for the treated municipality inside that local event window. Two control pools are built:

```r
window_clean   # controls with no same-type event in the local window
never_treated  # controls that never have that same event type
```

The binary rating-change outcomes compare each municipality-year rating to its rating at `h = -1` within the stack:

```r
rating_downgrade
rating_upgrade
rating_any_change
```

The preferred repeated-event DiD specification is a fixed-effects linear probability model:

```r
rating_change_outcome ~ i(rel_year, treated_event, ref = -1) |
  stack_id^code + stack_id^year
```

Standard errors are clustered by municipality. The workflow also estimates robustness variants using never-treated controls, prior operating-event history controls, first-time events only, and a narrower `h = -1, 0, 1` window. The history-control robustness model uses `code + stack_id^year` fixed effects because the prior-history variables vary at the stack-by-municipality level.

These models are written by `R/12_build_operating_repeated_event_data.R` and `R/13_operating_repeated_event_binary_models.R` to:

```r
outputs/tables/active_operating_repeated_event_sample_counts.csv
outputs/tables/active_operating_repeated_event_sample_counts.html
outputs/tables/active_operating_repeated_event_binary_did.csv
outputs/tables/active_operating_repeated_event_binary_did.html
outputs/tables/active_operating_repeated_event_binary_did_main.csv
outputs/tables/active_operating_repeated_event_binary_did_main.html
outputs/intermediate/active_operating_repeated_event_data.rds
outputs/intermediate/active_operating_repeated_event_binary_models.rds
```

`R/12_build_operating_repeated_event_data.R` also writes event-specific sample-count tables and stack files for operating attempts, successes, and failures. `R/14_write_active_results_index.R` writes:

```r
outputs/tables/active_workflow_outputs.csv
```

## Current Empirical Design

The preferred main rating models are ordered probit specifications with Mundlak controls and year indicators. The voter-support models use operating override frequency and municipality and year fixed effects. The repeated-event DiD models are robustness checks for binary rating-change outcomes and avoid treating Moody's ratings as cardinal. All active estimation models use municipality-clustered standard errors.
