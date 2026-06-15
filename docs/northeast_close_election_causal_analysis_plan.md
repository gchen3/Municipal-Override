# Northeast Close-Election Causal Analysis Plan

## Goal

Investigate whether operating override success or failure affects the probability of Moody's rating upgrades and downgrades. The follow-up analysis should focus on designs that compare successful and failed override attempts more directly than the current repeated-event models.

## Motivation

The current repeated-event models estimate successful and failed override events separately. That is useful descriptively, but it does not directly compare successful attempts with failed attempts. A closer causal design should use the vote outcome margin around the passage threshold, because close successful and close failed elections are more comparable.

## Starting Sample Counts

These counts use individual operating override vote records with valid vote totals and define closeness as the absolute distance between the yes-vote percentage and 50%.

| close-election band | all operating elections | successful | failed | Moody's complete model sample |
| --- | ---: | ---: | ---: | ---: |
| +/- 1 percentage point | 290 | 147 | 143 | 50 |
| +/- 2.5 percentage points | 692 | 352 | 340 | 124 |
| +/- 5 percentage points | 1,302 | 677 | 625 | 253 |
| +/- 10 percentage points | 2,421 | 1,166 | 1,255 | 464 |

The first working bandwidth should be +/- 5 percentage points. It is narrow enough to focus on close elections but large enough to provide a usable sample for sparse rating-change outcomes.

## Proposed Analyses

### 1. Close-Election Success vs Failure Models

Estimate the effect of barely successful overrides relative to barely failed overrides.

Core treatment:

- `close_success = 1` for successful operating overrides within the chosen bandwidth.
- `close_success = 0` for failed operating overrides within the chosen bandwidth.

Core outcomes:

- rating downgrade in the model year
- rating upgrade in the model year
- any downgrade within one year after the election
- any upgrade within one year after the election
- any downgrade within two years after the election
- any upgrade within two years after the election

Preferred first specification:

```text
rating_outcome ~ close_success + active_controls + year fixed effects
```

Consider municipality fixed effects only if there is enough within-municipality variation in close success/failure outcomes. Otherwise, use year fixed effects and controls, and report the limitation clearly.

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
rating_outcome ~ close_success + vote_margin + close_success:vote_margin + active_controls + year fixed effects
```

Run this within the same bandwidths. This checks whether the estimated success effect is sensitive to accounting for the slope of the vote margin on each side of the threshold.

### 4. Event-Time Close-Election Models

Build a close-election event-study sample that includes only operating override attempts near the threshold. Compare successful and failed attempts over event time.

Core event-time outcomes:

- rating downgrade
- rating upgrade

Suggested event window:

- `h = -2, -1, 0, 1, 2`

Reference period:

- `h = -1`

Preferred contrast:

```text
rating_change ~ i(relative_year, close_success, ref = -1) + active_controls + fixed effects
```

This design should be treated as a follow-up robustness analysis unless the sample size remains adequate.

### 5. Placebo and Balance Checks

Before interpreting any close-election estimate causally, run diagnostics:

- Balance on Table 1/3 controls across close successes and close failures.
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

## Implementation Stages

### Stage 1. Build Close-Election Analysis Dataset

Create a script such as `R/16_build_close_election_data.R`.

Tasks:

- Read the same override source files used by the active workflow.
- Keep only operating override records with valid yes and no vote counts.
- Compute:
  - total votes
  - yes-vote percentage
  - vote margin from 50%
  - absolute vote margin
  - close-election bandwidth flags
  - success indicator
  - model year using the existing one-year shift, `FiscalYear + 1`
- Merge with `data_for_regression.rds`.
- Construct rating outcomes for `t`, `t + 1`, and `t + 2`.
- Save the analysis dataset to `outputs/intermediate/active_operating_close_election_data.rds`.
- Write a sample-count table to `outputs/tables/active_operating_close_election_counts.csv`.

### Stage 2. Run Baseline Close-Election Models

Create a script such as `R/17_close_election_rating_models.R`.

Tasks:

- Estimate success-vs-failure models for downgrade and upgrade outcomes.
- Run models for each bandwidth.
- Include active controls and year fixed effects.
- Cluster standard errors by municipality.
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

### Stage 4. Run Diagnostics

Create a script such as `R/18_close_election_diagnostics.R`.

Tasks:

- Produce covariate-balance tables by close success/failure.
- Test pre-election rating-change placebo outcomes.
- Summarize the yes-vote margin distribution around the threshold.
- Save diagnostic outputs under `outputs/tables/` and `outputs/figures/`.

### Stage 5. Optional Close-Election Event Study

Create a script such as `R/19_close_election_event_study.R` only after Stage 1 through Stage 4 are reviewed.

Tasks:

- Build an event-time panel around close operating override attempts.
- Estimate event-time success-vs-failure models.
- Report downgrade and upgrade outcomes separately.
- Treat results as secondary unless sample size and pre-trends are acceptable.

### Stage 6. Publication Tables and Interpretation

After the model diagnostics are reviewed:

- Add publication-ready close-election tables only for specifications that pass basic diagnostics.
- Keep these tables separate from the current Northeast main-result tables.
- Label them as close-election causal follow-up or robustness analyses, depending on diagnostic strength.

## Recommended First Deliverables

1. `outputs/tables/active_operating_close_election_counts.csv`
2. `outputs/tables/active_operating_close_election_rating_models.csv`
3. `outputs/tables/active_operating_close_election_balance.csv`
4. A short interpretation memo in `docs/` after reviewing the results.

## Key Interpretation Rules

- Treat +/- 1 percentage point as the cleanest but likely underpowered bandwidth.
- Treat +/- 5 percentage points as the first practical working bandwidth.
- Do not interpret success coefficients causally if there are strong pre-election rating or fiscal differences.
- Separate downgrade and upgrade outcomes throughout the analysis.
- Keep close-election results separate from the current Northeast main results until the design diagnostics are reviewed.
