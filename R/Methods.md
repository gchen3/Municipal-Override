# Methods Summary

The active workflow preserves `R/00` through `R/09` as the frozen Stata-replication track. Scripts `R/10` through `R/15` estimate, summarize, and prepare the current operating-override analyses for `slides/NorthEast_workshop.qmd` and publication-table drafts. `R/run_active_workflow.R` runs the active workflow end to end.

## Active Workflow

The active runner sources:

```r
R/10_operating_mundlak_models.R
R/11_build_operating_repeated_event_data.R
R/12_operating_repeated_event_binary_models.R
R/13_prepare_slide_tables.R
R/14_prepare_slide_figures.R
R/15_prepare_publication_tables.R
```

`R/active_helpers.R` supplies shared active workflow definitions, labels, formatting helpers, and repeated-event model helpers. The active scripts reuse the regression panel produced by the frozen replication track when `outputs/intermediate/data_for_regression.rds` is already available; otherwise they rebuild it from `R/02_build_regression_data.R`.

## Operating Override Models

The active cross-sectional panel models focus on operating overrides. The regression panel covers 2003 through 2021. Override activity is shifted forward one year from the source `FiscalYear` before it is joined to the regression panel, so override activity is aligned with the following regression year.

The Moody's rating outcome is `MOO_ordered`, an ordered version of the numeric Moody's rating score. The voter-support outcome is `oper_yes_vote_percent`, the operating override yes-vote percentage in a municipality-year. It is calculated as total yes votes divided by total yes plus no votes across operating override questions. Municipality-years with no operating override vote have missing `oper_yes_vote_percent` and are dropped from the complete-case voter-support models.

The shared time-varying controls are:

```r
logpopu + debtbudg + unemploy + revstab + revperca +
  excessperca + unabsorbedratio + balance
```

### Moody's Ratings

Moody's ratings are estimated with ordered probit models because the rating scale is ordinal. The active main specifications are:

```r
MOO_ordered ~ oper_binary + controls + Mundlak controls + factor(year)
MOO_ordered ~ oper_binary_win + controls + Mundlak controls + factor(year)
MOO_ordered ~ oper_binary_fail + controls + Mundlak controls + factor(year)
```

The frequency-on-rating test uses three-year cumulative operating override counts:

```r
MOO_ordered ~ oper_attempt_cumu_3yr + controls + Mundlak controls + factor(year)
MOO_ordered ~ oper_success_cumu_3yr + controls + Mundlak controls + factor(year)
MOO_ordered ~ oper_failure_cumu_3yr + controls + Mundlak controls + factor(year)
```

`oper_binary` indicates any operating override attempt, `oper_binary_win` indicates any successful operating override, and `oper_binary_fail` indicates any failed operating override. The Mundlak controls are municipality-level means of the operating term and the time-varying controls. They adjust for persistent municipality differences that may be correlated with override behavior, while year indicators absorb common shocks. Standard errors are clustered by municipality.

`R/10_operating_mundlak_models.R` writes:

```r
outputs/tables/active_operating_moodys_main.html
outputs/tables/active_operating_moodys_frequency.html
outputs/intermediate/active_operating_mundlak_models.rds
```

`R/13_prepare_slide_tables.R` converts those model objects into slide-ready tables:

```r
outputs/tables/slides/northeast_moodys_main.tex
outputs/tables/slides/northeast_moodys_frequency.tex
```

### Voter Support

The voter-support models depart from the older Stata-replication outcome by using the actual operating yes-vote percentage rather than the percentage of override questions that passed. The annual yes-vote percentage is modeled using the frequency of override activity, not contemporaneous binary passage indicators. The active operating-specific variables are:

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
oper_yes_vote_percent ~ oper_attempt_count + controls | code + year
oper_yes_vote_percent ~ oper_success_count + controls | code + year
oper_yes_vote_percent ~ oper_failure_count + controls | code + year
oper_yes_vote_percent ~ oper_attempt_cumu_3yr + controls | code + year
oper_yes_vote_percent ~ oper_success_cumu_3yr + controls | code + year
oper_yes_vote_percent ~ oper_failure_cumu_3yr + controls | code + year
```

`R/10_operating_mundlak_models.R` writes:

```r
outputs/tables/active_operating_vote_share_main.html
outputs/intermediate/active_operating_mundlak_models.rds
```

`R/13_prepare_slide_tables.R` converts these results into:

```r
outputs/tables/slides/northeast_vote_share_annual.tex
outputs/tables/slides/northeast_vote_share_cumulative.tex
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

The binary rating-change outcomes compare each municipality-year Moody's rating to its rating at `h = -1` within the stack:

```r
rating_downgrade
rating_upgrade
```

The preferred repeated-event DiD specification is a fixed-effects linear probability model:

```r
rating_change_outcome ~ i(rel_year, treated_event, ref = -1) |
  stack_id^code + stack_id^year
```

Standard errors are clustered by municipality. The workflow also estimates robustness variants using never-treated controls, the preferred specification with the active control set added, first-time events only, and a narrower `h = -1, 0, 1` window. The active-control robustness model keeps the preferred `stack_id^code + stack_id^year` fixed effects and adds the same fiscal and demographic controls used in the panel models.

`R/11_build_operating_repeated_event_data.R` and `R/12_operating_repeated_event_binary_models.R` write:

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

`R/11_build_operating_repeated_event_data.R` also writes event-specific sample-count tables and stack files for operating attempts, successes, and failures.

`R/13_prepare_slide_tables.R` converts the preferred repeated-event estimates and sample counts into slide-ready tables:

```r
outputs/tables/slides/northeast_repeated_event_counts.tex
outputs/tables/slides/northeast_repeated_event_did_main.tex
outputs/tables/slides/northeast_repeated_event_did_downgrade.tex
outputs/tables/slides/northeast_repeated_event_did_upgrade.tex
```

`R/14_prepare_slide_figures.R` writes slide-ready event-study figures and an HTML preview report:

```r
outputs/figures/northeast_event_study_operating_attempt.png
outputs/figures/northeast_event_study_operating_success.png
outputs/figures/northeast_event_study_operating_failure.png
outputs/report/northeast_event_study_figures.html
```

## Override Amount Figure

`R/14_prepare_slide_figures.R` also aggregates annual nominal Massachusetts override amounts and writes the opening slide figure:

```r
outputs/figures/northeast_annual_override_amounts.csv
outputs/figures/northeast_annual_override_amounts.png
```

Only the PNG is used directly by `slides/NorthEast_workshop.qmd`.

## Slide Deck Inputs

`slides/NorthEast_workshop.qmd` currently reads these active outputs:

```r
outputs/figures/northeast_annual_override_amounts.png
outputs/tables/slides/northeast_moodys_main.tex
outputs/tables/slides/northeast_moodys_frequency.tex
outputs/tables/slides/northeast_vote_share_annual.tex
outputs/tables/slides/northeast_vote_share_cumulative.tex
outputs/tables/slides/northeast_repeated_event_counts.tex
outputs/tables/slides/northeast_repeated_event_did_downgrade.tex
outputs/tables/slides/northeast_repeated_event_did_upgrade.tex
outputs/figures/northeast_event_study_operating_attempt.png
outputs/figures/northeast_event_study_operating_success.png
outputs/figures/northeast_event_study_operating_failure.png
```

`outputs/tables/slides/northeast_repeated_event_did_main.tex` is generated by the active workflow but is not currently included in the slide deck.

## Publication Tables

`R/15_prepare_publication_tables.R` writes publication-oriented LaTeX drafts under:

```r
outputs/tables/publication/
```

The publication-table outputs are:

```r
outputs/tables/publication/northeast_moodys_main_pub.tex
outputs/tables/publication/northeast_moodys_frequency_pub.tex
outputs/tables/publication/northeast_vote_share_annual_pub.tex
outputs/tables/publication/northeast_vote_share_cumulative_pub.tex
outputs/tables/publication/northeast_repeated_event_did_downgrade_pub.tex
outputs/tables/publication/northeast_repeated_event_did_upgrade_pub.tex
outputs/tables/publication/northeast_repeated_event_did_main_pub.tex
```

These tables use the fitted model objects and machine-readable repeated-event results created earlier in the active workflow. They are manuscript-facing drafts, not additional fitted models.

## Current Empirical Design

The preferred main rating models are ordered probit specifications with Mundlak controls and year indicators. The frequency-on-rating models test three-year cumulative operating override counts using the same ordered-probit structure. The voter-support models use operating override frequency and municipality and year fixed effects. The repeated-event DiD models are robustness checks for binary rating-change outcomes and avoid treating Moody's ratings as cardinal. All active estimation models use municipality-clustered standard errors.
