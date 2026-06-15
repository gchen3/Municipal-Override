# Repeated-Event DID Design Plan for Operating Override Passage

## Purpose

This plan develops a repeated-event difference-in-differences design for estimating whether successful operating override events are followed by changes in Moody's municipal credit ratings.

The design treats each successful operating override municipality-year as a separate treatment event. This matches the substantive idea that every successful operating override may affect the municipality's fiscal position or credit signal, even when the same municipality has passed earlier overrides.

## Core Research Question

What happens to Moody's credit ratings around successful operating override events?

Primary outcomes:

- `rating_downgrade`: indicator for a lower Moody's rating than the municipality's own pre-event rating at `h = -1`.
- `rating_upgrade`: indicator for a higher Moody's rating than the municipality's own pre-event rating at `h = -1`.
- `rating_any_change`: indicator for any Moody's rating change relative to the municipality's own pre-event rating at `h = -1`.

Secondary rating-notch sensitivity outcome:

- `MOO_num`: numeric Moody's rating from the existing municipality-year regression panel. Higher values indicate better Moody's ratings, so positive estimates mean rating improvement in rating-notch units. This is retained as a sensitivity check, not as the preferred outcome.

Primary treatment event:

- A municipality-year with `oper_binary_win == 1`.

Primary event window:

- `h = -2, -1, 0, 1, 2`

Reference period:

- `h = -1`

The short event window is intentional. Successful operating overrides often recur within a few years, so long windows such as `h = -5` through `h = 5` would mix multiple treatment events and make the event-time path difficult to interpret.

Treatment timing convention:

- Treat the annual Moody's rating as measured around the middle of the year.
- Interpret `h = 0` as a contemporaneous, partial-year event estimate.
- Interpret `h = 1` as the first full post-treatment year.

## Empirical Feasibility Counts

Counts are based on the existing generated panel `outputs/intermediate/data_for_regression.rds`.

Overall successful operating override exposure:

- Successful operating override event-years: 535.
- Municipalities with at least one successful operating override: 184.
- Treated municipalities with only one successful operating override year: 62.
- Treated municipalities with multiple successful operating override years: 122.

Repeat-event spacing:

- Repeat-event gaps: 351.
- Gaps of 1 or 2 years: 211.
- Gaps of 5 years or less: 303.

These counts justify using a repeated-event design with a short clean window.

## Clean Treatment Events

Primary clean treatment definition:

- Treatment event is a municipality-year with `oper_binary_win == 1`.
- The event year must allow the full `[-2, +2]` panel window, so event years are restricted to 2005-2019.
- The same municipality must not have another successful operating override within `+/- 2` years of the event.
- The same municipality must not have a failed operating override attempt within `+/- 2` years of the event.

Under this definition:

- Clean treatment events: 176.
- Clean treated municipalities: 129.
- Treatment stacked rows: 880.
- Treatment stacked rows with nonmissing Moody's rating: 567.

Treatment observations by event time:

| Event time | Treatment rows | Nonmissing Moody's |
|---:|---:|---:|
| -2 | 176 | 120 |
| -1 | 176 | 112 |
| 0 | 176 | 116 |
| 1 | 176 | 110 |
| 2 | 176 | 109 |

## Control Group Definitions

### Primary Control Pool: Window-Clean Controls

For each treatment event, controls are municipalities that do not have a successful operating override or failed operating override attempt within the same `[-2, +2]` calendar window.

This allows municipalities to serve as controls for one event even if they are treated in a different, non-overlapping period. Controls with prior successful operating overrides outside the focal window are allowed in the main window-clean control pool.

Counts:

- Control event-municipality pairs: 45,051.
- Unique control municipalities: 340.
- Control stacked rows: 225,255.
- Control stacked rows with nonmissing Moody's rating: 130,512.

Control observations by event time:

| Event time | Control rows | Nonmissing Moody's |
|---:|---:|---:|
| -2 | 45,051 | 28,735 |
| -1 | 45,051 | 26,348 |
| 0 | 45,051 | 26,113 |
| 1 | 45,051 | 25,176 |
| 2 | 45,051 | 24,140 |

### Robustness Control Pool: Never-Treated Controls

For robustness, controls can be restricted to municipalities that never have a successful operating override in the panel.

Counts:

- Never-treated control municipalities: 167.
- Control event-municipality pairs: 29,392.
- Control stacked rows: 146,960.
- Control stacked rows with nonmissing Moody's rating: 84,649.

Control observations by event time:

| Event time | Control rows | Nonmissing Moody's |
|---:|---:|---:|
| -2 | 29,392 | 18,418 |
| -1 | 29,392 | 17,114 |
| 0 | 29,392 | 16,909 |
| 1 | 29,392 | 16,408 |
| 2 | 29,392 | 15,800 |

## Stacked Data Construction

Add a new script:

- `R/13_build_did_repeated_event_data.R`

Inputs:

- `outputs/intermediate/data_for_regression.rds`

Core steps:

1. Read the municipality-year regression panel.
2. Treat missing `oper_binary_win` and `oper_binary` values as genuinely missing election data, not as zeros.
3. Identify successful operating override event-years.
4. Keep clean treatment events:
   - full `[-2, +2]` calendar support;
   - no other successful operating override for the same municipality within `+/- 2` years;
   - no failed operating override attempt for the same municipality within `+/- 2` years.
5. Create a stacked treatment panel with one stack per clean treatment event.
6. Create the primary window-clean control pool for each stack.
7. Create the never-treated robustness control pool.
8. Attach outcome and covariates by municipality-year.
9. Construct prior override history variables measured before the focal event year and attach them to all rows in that event stack.
10. Construct rating-change indicators relative to each municipality-stack's `h = -1` Moody's rating.
11. Use all available rows with nonmissing baseline and event-time ratings for binary rating-change models; do not require a balanced full Moody's rating window for the main analysis.

Recommended saved outputs:

- `outputs/intermediate/did_repeated_event_treatment_events.rds`
- `outputs/intermediate/did_repeated_event_stack_window_clean.rds`
- `outputs/intermediate/did_repeated_event_stack_never_treated.rds`
- `outputs/tables/did_repeated_event_sample_counts.csv`

## Prior Override History Variables

Repeated treatment means the design should condition on treatment history where possible, but the history variables must be measured before the focal event.

Construct these variables at the stack baseline, as of `event_year - 1`, and then carry the same values across all rows in that event stack:

- `prior_oper_success_count`: cumulative successful operating override years before the focal event year.
- `prior_oper_attempt_count`: cumulative operating override attempt years before the focal event year.
- `years_since_last_oper_success`: years since the previous successful operating override as of the year before the focal event, missing or large-coded if none.
- `post_prior_success`: indicator for whether the municipality had any prior successful operating override before the focal event year.

These variables should be included as robustness controls, not as the only identification strategy. They should not be recomputed separately for each event-window row, because doing so would cause post-event rows to include the focal treatment event in the control variables.

## Main Model

Estimate stacked event-study DID robustness models with the clean treatment events and the window-clean control pool. The preferred repeated-event outcomes are binary rating-change indicators, estimated as fixed-effect linear probability models.

Recommended binary rating-change specification:

```r
did_fit <- fixest::feols(
  rating_downgrade ~ i(rel_year, treated_event, ref = -1) |
    stack_id^code + stack_id^year,
  data = did_stack,
  vcov = ~ code
)
```

Where:

- `stack_id` identifies the treatment event stack.
- `code` is the municipality.
- `year` is calendar year.
- `rel_year` is event time from `-2` to `2`.
- `treated_event` equals 1 for the treated municipality in its own stack and 0 for controls.

The coefficients on `i(rel_year, treated_event, ref = -1)` estimate within-stack changes in the probability of downgrade, upgrade, or any rating change for the treated municipality relative to controls in the same stack and calendar year, normalized to the year before treatment.

Numeric rating-notch sensitivity models use the same stacked specification with `MOO_num` as the outcome. These estimates are easier to interpret in rating-notch units, but they impose a stronger cardinal-rating assumption.

## Alternative Fixed Effects

Depending on collinearity and support, compare these specifications:

1. Preferred stacked DID specification with stack-specific municipality and calendar-year fixed effects:

```r
rating_downgrade ~ i(rel_year, treated_event, ref = -1) | stack_id^code + stack_id^year
```

2. Slightly less saturated specification with municipality fixed effects and stack-specific calendar-year fixed effects:

```r
rating_downgrade ~ i(rel_year, treated_event, ref = -1) | code + stack_id^year
```

3. Simpler specification with stack, municipality, and calendar-year fixed effects:

```r
rating_downgrade ~ i(rel_year, treated_event, ref = -1) | stack_id + code + year
```

Use the preferred stacked DID specification for binary rating-change robustness checks if it has adequate support and stable estimation. If the saturated fixed effects create collinearity or instability, use `code + stack_id^year` as the fallback specification and report the limitation explicitly.

## Robustness Checks

Recommended robustness checks:

1. Use never-treated controls only.
2. Add prior override history controls.
3. Exclude events from municipalities with any prior successful operating override.
4. Use a narrower `[-1, +1]` event window.
5. Use a broader `[-3, +3]` event window only as a sensitivity check, with explicit overlap diagnostics.
6. Exclude treatment and control windows with nearby successful or failed non-operating override events.
7. Re-run with all successful override types, not only operating overrides, as a secondary design.
8. Cluster by municipality; optionally compare two-way clustering by municipality and stack if stable.

## Diagnostics

Create sample diagnostics before interpreting model results:

- Number of clean treatment events by event year.
- Number of treated observations with nonmissing Moody's rating by event time.
- Number of observations dropped because override-attempt status is missing in the relevant clean window.
- Number of control municipalities per stack.
- Share of controls that are never treated.
- Distribution of prior successful operating overrides among treated events.
- Distribution of years since prior successful operating override.
- Pre-treatment event-time estimate at `h = -2`.

The `h = -2` estimate is the main pre-trend diagnostic in the primary `[-2, +2]` design because `h = -1` is the reference period.

## Output Plan

Add a model script:

- `R/14_did_repeated_event_models.R`

Save:

- `outputs/intermediate/did_repeated_event_models.rds`
- `outputs/tables/did_repeated_event_binary_rating_main.csv`
- `outputs/tables/did_repeated_event_binary_rating_robustness.csv`
- `outputs/tables/did_repeated_event_main.csv`
- `outputs/tables/did_repeated_event_robustness.csv`
- `outputs/figures/did_repeated_event_moodys.png`

Optional report:

- `docs/did_repeated_event_report.qmd`
- `outputs/report/did_repeated_event_report.html`
- `outputs/report/did_repeated_event_report.docx`

## Interpretation

The preferred interpretation is:

> The repeated-event DID estimates compare Moody's rating changes around clean successful operating override events with changes for municipalities that did not have a successful operating override in the same local calendar window.

The estimand is event-based: it describes changes around successful operating override events, not a one-time transition into treated status.

The main limitation is that override timing remains endogenous. The design improves on simple panel regressions by using local event timing and fixed effects, but it should still be interpreted as a panel event-study design rather than a fully exogenous timing design.

## Recommended Starting Point

The first implementation should use:

- Treatment event: successful operating override municipality-year.
- Clean event window: `[-2, +2]`.
- Clean treatment rule: no other successful operating override or failed operating attempt within `+/- 2` years.
- Main controls: window-clean control pool.
- Robustness controls: never-treated control pool.
- Preferred outcomes: `rating_downgrade`, `rating_upgrade`, and `rating_any_change`.
- Secondary outcome: `MOO_num`.
- Main repeated-event robustness model: stacked event-study DID with stack-specific municipality and calendar-year fixed effects.
- Fallback model if needed: municipality fixed effects and stack-specific calendar-year fixed effects.
- Reference period: `h = -1`.
- Estimation sample: all observations with nonmissing `MOO_num`.
- Clustered standard errors: municipality level.

This design aligns with the substantive claim that each successful operating override may affect Moody's ratings while avoiding the most severe overlap problems from repeated treatment.
