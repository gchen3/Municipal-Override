# Northeast Close-Election Causal Analysis Plan

## Goal

Investigate whether operating override success or failure affects the probability of Moody's rating upgrades and downgrades. The follow-up analysis should focus on designs that compare successful and failed override attempts more directly than the current repeated-event models.

## Motivation

The current repeated-event models estimate successful and failed override events separately. That is useful descriptively, but it does not directly compare successful attempts with failed attempts. A closer causal design should use the vote outcome margin around the passage threshold, because close successful and close failed elections are more comparable.

This is a close-election success-vs-failure comparison with a local-linear margin robustness check, not a formal regression-discontinuity design: there is no optimal-bandwidth selection or `rdrobust` machinery. Treat the estimates as suggestive and quasi-experimental, leaning on the balance and pre-trend diagnostics for credibility.

## Starting Sample Counts

These counts use individual operating override vote records with valid vote totals and define closeness as the absolute distance between the yes-vote percentage and 50%.

| close-election band       | all operating elections | successful | failed | Moody's complete model sample |
| ---------------------------| ------------------------:| -----------:| -------:| ------------------------------:|
| +/- 1 percentage point    | 290                     | 147        | 143    | 50                            |
| +/- 2.5 percentage points | 692                     | 352        | 340    | 124                           |
| +/- 5 percentage points   | 1,302                  | 677        | 625    | 253                           |
| +/- 10 percentage points  | 2,421                  | 1,166     | 1,255 | 464                           |

The first working bandwidth should be +/- 5 percentage points. It is narrow enough to focus on close elections but large enough to provide a usable sample for sparse rating-change outcomes.

### Municipality-Year Sample Under the Collapse Rule

Treatment is assigned at the municipality-year level, so the election counts above must be collapsed to municipality-years before merging with the rating panel. The counts below are measured directly from the operating override source files (before requiring a non-missing Moody's rating) and define `close_success` from `WinLoss`, which aligns exactly with the sign of the vote margin (the 12 exact ties are coded as failures, consistent with the simple-majority rule).

| close-election band | muni-years with >= 1 close election | kept under rule (a'): single + same-direction multiples | dropped: mixed win-and-loss |
| --- | ---: | ---: | ---: |
| +/- 1 percentage point | 244 | 223 | 21 |
| +/- 2.5 percentage points | 494 | 414 | 80 |
| +/- 5 percentage points | 782 | 624 | 158 |
| +/- 10 percentage points | 1,189 | 923 | 266 |

The dropped municipality-years are only those with both a close success and a close failure in the same year, where `close_success` would be undefined. At the +/- 5 percentage-point working bandwidth this drops 158 of 782 municipality-years (about 20 percent). The Moody's complete-case sample is smaller still, after requiring non-missing baseline and horizon ratings.

## Proposed Analyses

### 1. Close-Election Success vs Failure Models

Estimate the effect of barely successful overrides relative to barely failed overrides.

Core treatment:

- The analysis sample is restricted to operating override elections within the chosen bandwidth. The comparison is barely-successful versus barely-failed overrides; there is no separate no-election control group, and municipality-years without a close operating election are excluded.
- `close_success = 1` for a municipality-year whose close operating override(s) passed.
- `close_success = 0` for a municipality-year whose close operating override(s) failed. `close_success = 0` means a close *failure*, never the absence of an election.
- Treatment is assigned at the municipality-year level to match the rating panel. When a municipality-year has multiple close operating elections, keep it only if they all went the same way and collapse to a single `close_success`; drop municipality-years with mixed win-and-loss close elections (rule a'), and report the number dropped by bandwidth. Take `close_success` from `WinLoss`.

Core outcomes (cumulative near-term rating changes vs a fixed pre-vote baseline):

- Timing convention. The election occurs in source `FiscalYear` `F`; the project shifts override activity forward one year, so the model year is `t0 = F + 1` (matching `R/10` and the repeated-event event year).
- Baseline rating: `MOO_num` in the year before the election fiscal year, `t0 - 2` (i.e. `F - 1`). This is a fully pre-vote baseline. Observations with a missing baseline rating are dropped.
- Modeled outcomes (cumulative only; there is no point-in-time outcome set):
  - `any_downgrade_within_1yr`, `any_upgrade_within_1yr`: any change vs baseline across panel years `t0` and `t0 + 1`.
  - `any_downgrade_within_2yr`, `any_upgrade_within_2yr`: any change vs baseline across panel years `t0`, `t0 + 1`, and `t0 + 2`.
  - Cumulative outcomes are chosen because Moody's ratings are sticky and rating changes are sparse in these small close-election samples; pooling the window years gives the rare changes enough variation to model.
  - Each outcome is defined when the baseline and at least one horizon-year rating in its window are observed (available-case). Downgrade and upgrade are kept as separate, non-mutually-exclusive outcomes (a rating can fall then recover within the window).
- Do not impute or carry forward ratings. Moody's ratings are unavailable in some years (e.g. 2016 and 2018), which makes the baseline or some horizon ratings missing; confirm the available rating years from the data rather than hard-coding them. Report N per outcome.
- Robustness baseline: also construct the same cumulative outcomes against the `t0 - 1` (election-year) baseline, which equals the repeated-event design's `h = -1` reference, so the two designs can be compared on one clock.

Preferred first specification (linear probability model):

```text
any_change_outcome ~ close_success + active_controls | calendar_year   (feols, cluster by code)
```

- Estimate with `fixest::feols` as a linear probability model: the `close_success` coefficient is the change in the probability of the rating-change outcome, in percentage points. This is consistent with the repeated-event binary rating-change track.
- Include the active controls and calendar-year fixed effects; cluster standard errors by municipality (`code`).
- Run each cumulative outcome (`any_downgrade_within_1yr`, `any_downgrade_within_2yr`, `any_upgrade_within_1yr`, `any_upgrade_within_2yr`) separately.
- Do **not** use municipality fixed effects as the primary specification: under rule (a') most municipalities contribute at most one close-election observation, so municipality fixed effects absorb the treatment and leave little variation. Report this as a design limitation rather than forcing within-municipality identification.
- Robustness estimator: re-estimate the working-bandwidth models with probit (`fit_probit`). Because probit with year fixed effects separates on rare outcomes, run the probit robustness **without** year fixed effects and report average marginal effects; if a probit model fails to converge or separates, report that instead of forcing it.

### 2. Bandwidth Sensitivity

Estimate the same success-vs-failure models for multiple bandwidths:

- +/- 1 percentage point
- +/- 2.5 percentage points
- +/- 5 percentage points
- +/- 10 percentage points

The +/- 5 percentage-point model should be the main working specification unless diagnostics support a narrower or wider bandwidth.

### 3. Local Linear Margin Models

Use the yes-vote margin as a running variable:

```text
any_change_outcome ~ close_success + vote_margin + close_success:vote_margin + active_controls | calendar_year
```

Estimate as a linear probability model (`feols`, cluster by `code`), consistent with Analysis 1, so the interaction is directly interpretable as a difference in the probability slope on each side of the threshold. Run this within the same bandwidths. This checks whether the estimated success effect is sensitive to accounting for the slope of the vote margin on each side of the threshold.

### 4. Event-Time Close-Election Models (Pre-Trend / Placebo Diagnostic)

Build a close-election event-time sample around each retained close override and compare the rating *paths* of close successes versus close failures. This is a diagnostic, not a headline causal estimate; its main purpose is the pre-period coefficient.

This design does **not** reuse the repeated-event DiD fixed effects (`stack_id^code + stack_id^year`). Those rely on a pool of control municipalities per stack. The close-election comparison is success-events versus failure-events, so each event is a single municipality and stack-interacted fixed effects collapse to singletons (one row per stack-by-year cell), leaving nothing to estimate.

Event-time panel: for each retained close election, set `event_year = t0` (the model year `F + 1`) and stack `rel_year = -2, -1, 0, 1, 2`, so the calendar year is `t0 + rel_year`. Reference period `h = -1` (the election fiscal year `F`, matching the repeated-event reference). This `h = -1` reference is the conventional event-study normalization on rating *levels* and is intentionally distinct from the `t0 - 2` baseline used for the cumulative outcomes in Analysis 1; the event study and the cumulative models are separate tools and need not share a reference year.

Outcome:

- Rating level `MOO_num` at each event-time year. The cumulative within-1yr/within-2yr outcomes from Analysis 1 have no event-time decomposition and are not used here.

Preferred contrast (two-group event study, calendar-year fixed effects only):

```text
MOO_num ~ i(rel_year, close_success, ref = -1) + i(rel_year, ref = -1) + close_success | calendar_year
```

- `i(rel_year, close_success, ref = -1)`: the success-versus-failure differential rating path, the coefficients of interest.
- `i(rel_year, ref = -1)`: the common event-time path for the failure group.
- `close_success`: average level gap between the groups.
- Calendar-year fixed effects absorb macro shocks (for example 2008-2009 and COVID).
- Cluster standard errors by municipality.

Do **not** add municipality fixed effects in the primary specification. Under collapse rule (a') most municipalities contribute a single close election, so `rel_year = calendar_year - event_year` is collinear with municipality and calendar-year fixed effects; adding municipality fixed effects makes the event-time terms degenerate. Treat any municipality-fixed-effects variant as a fragile secondary check at most.

Primary read: the `h = -2` pre-period coefficient. If close successes and close failures already have diverging rating paths before the election, report the close-election design as suggestive rather than causal. Treat post-period coefficients as secondary given the thin sample.

### 5. Placebo and Balance Checks

Before interpreting any close-election estimate causally, run diagnostics:

- Balance on the `active_controls` set across close successes and close failures.
- Balance on lagged Moody's rating level.
- Balance on pre-election downgrade and upgrade indicators.
- Placebo effects for pre-election outcomes.
- Distribution of yes-vote margins around the 50% threshold.

If close successes and close failures differ strongly before the election, report the close-election design as suggestive rather than causal.

### 6. Mechanism Checks

If close success affects ratings, test whether fiscal channels move in the expected direction:

- government revenue per capita
- excess property tax capacity
- fiscal reserve
- budget balance
- debt burden

Use post-election windows such as one-year and two-year changes. These are supporting mechanism checks, not primary rating outcomes.

These mechanism checks are an optional later extension, conditional on finding a rating effect. They are not part of the initial `R/16`-`R/19` build and have no dedicated stage yet.

## Implementation Stages

### Reuse Existing Infrastructure

These scripts should build on the active workflow rather than re-implement it:

- Vote-level read: reuse the `purrr::map_dfr(data_65_file(override_source_files), haven::read_dta)` then `filter(Override == "operating")` pattern and the `YesVotes`/`NoVotes` and `FiscalYear + 1` handling from `R/10`.
- Controls and labels: use `active_controls`, `active_variable_labels`, and `variable_labels` from `R/active_helpers.R` / `R/00_config.R`; do not re-list control variables.
- Model fits: use `fit_fe_lm` and `fit_probit` (with `complete_model_data` and `cluster_vcov`), which return `list(model, vcov, data)` and already attach municipality-clustered standard errors.
- Paths and output: use `paths`, `make_output_dirs()`, `data_65_file()`, and `moody_file()`; write through `paths$intermediate` and `paths$tables`.
- Formatting and tables: use `fmt_num`, `fmt_int`, `cell_with_se`, `write_tex`, and `write_model_table` for output.

### Script Conventions

- Each new script (`R/16` through `R/19`) opens with the standard header: `source("R/00_config.R")`, `load_required_packages(...)`, `make_output_dirs()`, `source("R/active_helpers.R")`, then `source("R/close_election_helpers.R")`.
- Use dependency guards so each stage runs independently: source `R/02_build_regression_data.R` if `data_for_regression.rds` is missing, and source `R/16_build_close_election_data.R` if the close-election dataset is missing.
- Put new close-election logic (margin and bandwidth construction, the rule (a') collapse, the cumulative-outcome builder, and the event-time stacker) in a dedicated `R/close_election_helpers.R`, not in `active_helpers.R`, to keep the shared workflow file focused.
- Do **not** add `R/16` through `R/19` to `R/run_active_workflow.R`. That driver feeds the workshop slide deck; the close-election analysis is a separate follow-up track. Run these scripts on their own (for example through a separate `R/run_close_election_followup.R` driver that sources `R/16` through `R/19` in order), mirroring how the Stata-replication and active tracks each have their own driver.

### Stage 1. Build Close-Election Analysis Dataset

Create a script such as `R/16_build_close_election_data.R`.

Tasks:

- Read the same override source files used by the active workflow.
- Keep only operating override records with valid yes and no vote counts.
- Compute:
  - total votes
  - yes-vote percentage
  - vote margin from 50% (signed running variable, `yes_percent - 50`)
  - absolute vote margin
  - close-election bandwidth flags
  - success indicator from `WinLoss`
  - model year using the existing one-year shift, `FiscalYear + 1`
- Verify `WinLoss == "WIN"` matches `vote_margin > 0` and report any mismatches or ties before proceeding.
- Collapse to municipality-year using rule (a'): keep single-close-election years and same-direction multiples, drop mixed win-and-loss years, and write the per-bandwidth kept/dropped counts.
- Merge with `data_for_regression.rds`.
- Construct the rating outcomes defined in Analysis 1: a `t0 - 2` pre-vote baseline and the cumulative `any_downgrade_within_1yr`/`within_2yr` and `any_upgrade_within_1yr`/`within_2yr` outcomes (available-case over each window's observed horizon years), plus the `t0 - 1` robustness-baseline variants. Require a non-missing baseline; do not impute. Report N per outcome and the available Moody's rating years detected from the data.
- Save the analysis dataset to `outputs/intermediate/active_operating_close_election_data.rds`.
- Write a sample-count table to `outputs/tables/active_operating_close_election_counts.csv`.

### Stage 2. Run Baseline Close-Election Models

Create a script such as `R/17_close_election_rating_models.R`.

Tasks:

- Estimate success-vs-failure linear probability models (`fixest::feols`) for the cumulative downgrade and upgrade outcomes.
- Run models for each bandwidth.
- Include active controls and calendar-year fixed effects; cluster standard errors by municipality.
- Report the number of municipalities (clusters) and N for every model so few-cluster bandwidths are flagged.
- Add a probit robustness check (`fit_probit`) at the working bandwidth, without year fixed effects, reporting average marginal effects and any convergence/separation failures.
- Save model summaries to `outputs/tables/active_operating_close_election_rating_models.csv`.

### Stage 3. Add Local Linear Margin Specifications

Extend `R/17_close_election_rating_models.R`.

Tasks:

- Add vote-margin controls.
- Add success-by-margin interactions.
- Compare estimates with and without local linear margin terms.
- Save results with clear model labels such as:
  - `close_success_only`
  - `local_linear_margin`

### Stage 4. Run Diagnostics (Analysis 5)

Create a script such as `R/18_close_election_diagnostics.R`.

Tasks:

- Produce covariate-balance tables by close success/failure.
- Test pre-election rating-change placebo outcomes.
- Summarize the yes-vote margin distribution around the threshold.
- Save the covariate-balance table to `outputs/tables/active_operating_close_election_balance.csv`, and other diagnostic outputs (placebo tests, margin-distribution figure) under `outputs/tables/` and `outputs/figures/`.

### Stage 5. Optional Close-Election Event-Time Diagnostic (Analysis 4)

Create a script such as `R/19_close_election_event_study.R` only after Stage 1 through Stage 4 are reviewed.

Tasks:

- Build an event-time panel: for each retained close election (rule a'), set `event_year = t0` and stack `MOO_num` at `rel_year = -2..2` (calendar year `= t0 + rel_year`), tolerating missing rating years without imputation.
- Estimate the **full** two-group event study from Analysis 4 - `i(rel_year, close_success, ref = -1)` plus the `i(rel_year, ref = -1)` common event-time path and the `close_success` level term - with calendar-year fixed effects, clustered by municipality. No `stack^code`/`stack^year` and no municipality fixed effects in the primary spec.
- Report the `h = -2` pre-period coefficient as the primary pre-trend/placebo read; report post-period coefficients as secondary.
- Save event-study estimates and an event-study figure under `outputs/tables/` and `outputs/figures/`.
- Treat results as secondary/appendix unless pre-trends are flat and the sample is adequate.

### Stage 6. Review First, Defer Publication and Incorporation

This track is a self-contained follow-up. Produce results for review before any incorporation into the main Northeast results.

- Keep all close-election outputs in their own namespace (`active_operating_close_election_*` files and any `outputs/tables/`/`outputs/figures/` review tables and figures). Do **not** write into `outputs/tables/publication/`, do **not** touch the `northeast_*` main-result or slide tables, and do **not** wire anything into the slide deck.
- Produce compact, review-oriented result and diagnostic summaries so the estimates can be inspected first.
- Do **not** incorporate close-election findings into the main Northeast results or the manuscript until the results are reviewed and there is an explicit decision to promote them.
- Only after that decision: build publication-ready tables following the convention in `docs/northeast_publication_tables_plan.md` (full `table`/`booktabs` environments with `\caption`/`\label` and notes, written to `outputs/tables/publication/` as `northeast_close_election_*_pub.tex`), and label them as a close-election causal follow-up or robustness analysis depending on diagnostic strength.
- Transparency bookkeeping is deferred: during the standalone phase rely on the interpretation memo in `docs/`, and add entries to `transparency/northeast_results_registry.md` and `transparency/northeast_variable_dictionary.md` only at promotion.

## Recommended First Deliverables

1. `outputs/tables/active_operating_close_election_counts.csv`
2. `outputs/tables/active_operating_close_election_rating_models.csv`
3. `outputs/tables/active_operating_close_election_balance.csv`
4. A short interpretation memo in `docs/` after reviewing the results.

## Key Interpretation Rules

- Treat +/- 1 percentage point as the cleanest but likely underpowered bandwidth.
- Treat +/- 5 percentage points as the first practical working bandwidth.
- Report the number of municipalities (clusters) and N for every model. Cluster-robust standard errors are unreliable with few clusters, so treat the +/- 1 and +/- 2.5 percentage-point estimates as descriptive and underpowered, and let +/- 5 percentage points and wider carry the statistical claims. No bootstrap inference is used.
- Do not interpret success coefficients causally if there are strong pre-election rating or fiscal differences.
- Separate downgrade and upgrade outcomes throughout the analysis.
- Keep close-election results separate from the current Northeast main results until the design diagnostics are reviewed.
