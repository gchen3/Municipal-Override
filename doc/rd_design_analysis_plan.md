# Regression Discontinuity Design Plan for Override Passage Effects

## Purpose

This plan develops a regression discontinuity (RD) design for estimating the causal effect of passing a municipal override on downstream outcomes. The design uses the institutional voting rule that an override passes when the approval rate crosses the 50% threshold.

The core comparison is between override votes that narrowly fail and narrowly pass. A proposal receiving 49% approval and a proposal receiving 51% approval are plausibly similar in voter support, local fiscal context, and political environment, but differ in whether the override legally passes. That near-threshold discontinuity can identify the local effect of override passage.

## Core Research Question

What is the causal effect of passing an override, relative to narrowly failing one, on municipal outcomes?

Outcome:

- Moody's credit rating is the only outcome for the RD analysis.
- The RD design should not estimate fiscal, electoral, or future override outcomes in the first implementation. Those can be discussed as possible mechanisms or future extensions, but the empirical RD plan should stay focused on Moody's rating.

The main estimand should be interpreted as a local average treatment effect for close override elections, not necessarily the average effect of all override passages.

## Running Variable and Treatment

Running variable:

- `margin = yes_vote_share - 0.50`
- In percentage-point form: `margin_pp = yes_percent_vote - 50`

Treatment:

- `pass = 1` if approval rate is at least 50%.
- `pass = 0` if approval rate is below 50%.

Important implementation detail:

- The existing workflow has `yes_percent = num_success * 100 / num_attempt`, which is the share of override questions that succeeded in a municipality-year. That is not the RD running variable.
- The RD running variable must be built at the individual override-question level from vote counts:
  - `approval_rate = YesVotes / (YesVotes + NoVotes)`
  - `margin = approval_rate - 0.50`

## Unit of Analysis

Preferred primary unit:

- Override question-election.

Reason:

- The treatment threshold applies to each ballot question, not to the municipality-year aggregate.

Required identifiers:

- Municipality code.
- Fiscal year or election year.
- Override type or purpose.
- Vote date, if available.
- Question identifier if available; otherwise construct a within-municipality-date-type identifier.

Potential secondary unit:

- Municipality-year, using the closest override election to the cutoff in that year or aggregating close elections.

This should be treated as a robustness or extension, because aggregation can blur the discontinuity when multiple override questions occur in the same municipality-year.

## Multiple Override Questions in the Same Municipality-Year

Primary recommendation:

- If a municipality has multiple operating override questions in the same year, keep the operating override question closest to the 50% cutoff.

Reason:

- Moody's rating is observed at the municipality-year level, so multiple ballot questions in the same municipality-year would attach the same outcome to several running-variable values.
- The RD identification is strongest for the election nearest the cutoff.
- Keeping the closest election avoids overweighting municipality-years with many override questions.

Robustness checks:

- Treat each question as its own observation and cluster by municipality.
- Treat each question as its own observation but cluster by municipality-year if enough clusters exist.
- Use all override types with type fixed effects, again keeping the closest question to 50% within municipality-year for the secondary model.

## Outcome Timing and Event-Study Design

The outcome must be measured after the override vote. The primary RD analysis should use an event-study structure for Moody's rating:

- `h = 1`: Moody's rating in the next fiscal year after the override vote.
- `h = 2`: Moody's rating two fiscal years after the override vote.
- `h = 3+`: Moody's rating three or more fiscal years after the override vote, implemented either as separate horizons if sample size allows or as a pooled longer-run outcome.

The baseline event-time specification should estimate separate RD effects by horizon:

```text
MOO_{i,t+h} = alpha_h + tau_h Pass_i + beta_{1h} Margin_i + beta_{2h} Pass_i x Margin_i + epsilon_{i,h}
```

Where `tau_h` is the effect of passing an operating override on Moody's rating at horizon `h`.

Recommended horizons for the first implementation:

- `h = 1`
- `h = 2`
- `h = 3`
- `h = 4`
- `h = 5`

The main event-study RD table and figure should report separate horizons from `h = 1` through `h = 5`. A pooled `h >= 3` estimate can be added as a robustness or summary measure, but it should not replace the annual horizon estimates.

Avoid using same-year Moody's rating as a treatment outcome unless the rating date is known to occur after the vote. Same-year rating is better treated as a sensitivity analysis or omitted from the first RD design.

Pre-treatment Moody's rating, such as `h = -1`, should be used as a validity check rather than as an outcome.

## Baseline RD Specification

Use local linear RD around the 50% cutoff:

```text
Y_{i,t+h} = alpha + tau Pass_i + beta_1 Margin_i + beta_2 Pass_i x Margin_i + epsilon_i
```

Where:

- `i` is an override question.
- `t` is the election or fiscal year.
- `h` is the post-election horizon.
- `tau` is the causal effect of passage at the 50% cutoff.

Recommended primary estimator:

- Local linear RD with robust bias-corrected inference, using `rdrobust` in R.

Recommended robustness estimators:

- Local quadratic RD.
- Different kernels, with triangular as the main kernel.
- Manual fixed-bandwidth regressions using `fixest::feols()`.
- Specifications with and without predetermined covariates.

## Bandwidth Strategy

Primary bandwidth:

- Use data-driven bandwidth selection from `rdrobust`.

Robustness bandwidths:

- Within 2.5 percentage points of the cutoff.
- Within 5 percentage points.
- Within 10 percentage points.
- Half and double the `rdrobust` selected bandwidth.

Interpretation should emphasize stability across reasonable bandwidths, not a single preferred bandwidth.

## Covariates and Fixed Effects

Covariates should improve precision and support balance checks, but should not be required for identification.

Candidate predetermined covariates:

- Lagged Moody's rating.
- Lagged population.
- Lagged debt level.
- Lagged unemployment.
- Lagged revenue stability.
- Lagged revenue and expenditure per capita.
- Lagged fiscal reserve.
- Lagged budget balance.
- Override type indicators.

Fixed effects to consider:

- Year fixed effects.
- Override type fixed effects.
- Municipality fixed effects only as a robustness check, because close-election RD identification is already local and municipality fixed effects may reduce usable variation sharply.

Do not control for variables that could be affected by override passage before the outcome is measured.

## Clustering

Cluster standard errors at the municipality level when using manual regressions.

For `rdrobust`, use its cluster option if supported in the installed version:

```r
rdrobust::rdrobust(y = outcome, x = margin, c = 0, cluster = code)
```

If the close-election sample is small, report both conventional robust RD inference and municipality-clustered inference where feasible.

## Validity Checks

### 1. Running Variable Density

Test whether observations bunch just above or below 50%.

Recommended check:

- McCrary-style density test using `rddensity`.

Concern:

- If municipalities, campaigners, or election administrators can precisely manipulate vote shares around 50%, RD validity weakens.

### 2. Covariate Balance

Test whether predetermined covariates are smooth at the threshold.

Balance outcomes:

- Prior credit rating.
- Prior fiscal reserve.
- Prior debt.
- Prior population.
- Prior unemployment.
- Prior revenue stability.
- Override type composition.

### 3. Placebo Cutoffs

Estimate placebo discontinuities at false thresholds:

- 40%.
- 45%.
- 55%.
- 60%.

The effect should be concentrated at 50%, not at arbitrary cutoffs.

### 4. Donut RD

Drop observations extremely close to 50%, such as:

- Within 0.25 percentage points.
- Within 0.5 percentage points.

This checks sensitivity to recounts, ties, rounding, or ambiguous passage rules.

### 5. Outcome Pre-Trends

Estimate RD effects on pre-treatment outcomes:

- Moody's rating in the year before the vote.
- Fiscal variables in the year before the vote.

There should not be discontinuities in pre-treatment outcomes at the 50% threshold.

## Main Outputs

Recommended tables:

1. RD sample descriptive statistics.
2. Main event-study RD effects of operating override passage on Moody's ratings.
3. Secondary event-study RD effects using all override types.
4. Validity and balance checks.
5. Robustness across bandwidths and specifications.

Recommended figures:

1. RD plot for Moody's rating.
2. Event-study coefficient plot for Moody's rating effects from `h = 1` through `h = 5`.
3. Density plot of the running variable around 50%.
4. Coefficient plot across bandwidths.

## Proposed R Workflow Extension

The RD implementation should be added as a separate extension after the existing replication workflow. Do not rewrite the validated Mundlak replication scripts, because those scripts already reproduce the existing `Method_Results.docx` tables.

### Existing Scripts to Leave Unchanged

Keep these scripts stable except for optional shared helper additions in `R/00_config.R`:

- `R/01_build_override_panel.R`
  - This aggregates override votes to municipality-year.
  - RD needs question-level vote data, so this script is not the right place to build the RD running variable.
- `R/02_build_regression_data.R`
  - This builds the municipality-year panel and should continue to produce `outputs/intermediate/data_for_regression.rds`.
  - RD should reuse this panel only to attach Moody's rating outcomes and predetermined covariates.
- `R/04_models_main_mundlak.R` through `R/08_validate_against_method_results.R`
  - These should remain the original panel/Mundlak replication workflow.

### Change 1: Update `R/00_config.R`

Add RD packages to the expected package list or load them only in the RD scripts:

```r
"rdrobust", "rddensity", "broom"
```

Add RD variable labels:

```r
approval_rate = "Override approval rate"
margin_pp = "Approval margin from 50% cutoff"
passed = "Override passed"
```

Do not add package installation code.

### Change 2: Add `R/09_build_rd_data.R`

This is the main RD data construction script.

Read the four raw override files directly:

- `override_override.dta`
- `override_capital.dta`
- `override_debt.dta`
- `override_stable.dta`

Build question-level RD variables before municipality-year aggregation:

```r
approval_rate = YesVotes / (YesVotes + NoVotes)
margin = approval_rate - 0.50
margin_pp = 100 * margin
passed = as.numeric(approval_rate >= 0.50)
vote_year = FiscalYear
```

Important distinction:

- The existing municipality-year `yes_percent` is the percent of override questions that succeeded in a municipality-year.
- The RD running variable must instead be built from question-level vote counts.

Attach Moody's rating outcomes from `outputs/intermediate/data_for_regression.rds` using event-time horizons:

```r
h = -1, 1, 2, 3, 4, 5
outcome_year = vote_year + h
```

Create the primary RD sample:

```r
rd_sample_operating = Override == "operating"
```

For multiple operating overrides in the same municipality-year:

```r
group_by(code, vote_year)
slice_min(abs(margin), n = 1, with_ties = FALSE)
```

Create the secondary all-types sample:

- Use all override types.
- Keep the closest-to-50% question within municipality-year unless a later design decision specifies closest question within each override type.
- Keep override type as a covariate or fixed effect in manual robustness specifications.

Save:

- `outputs/intermediate/rd_question_level_data.rds`
- `outputs/intermediate/rd_data_validation.csv`

### Change 3: Add `R/10_rd_main_models.R`

Estimate the main event-study RD models for Moody's rating.

Primary model:

- Sample: operating overrides only.
- Horizons: `h = 1`, `h = 2`, `h = 3`, `h = 4`, `h = 5`.
- Outcome: `MOO_num`.
- Running variable: `margin`.
- Cutoff: `0`.
- Treatment: `passed`.

Preferred estimator:

```r
rdrobust::rdrobust(
  y = MOO_num,
  x = margin,
  c = 0,
  p = 1,
  kernel = "triangular",
  cluster = code
)
```

Secondary model:

- Sample: all override types.
- Same horizons.
- Add override type as covariates if using `rdrobust`, or type fixed effects in manual `fixest` robustness models.

Also estimate manual local linear regressions as robustness and for easier table/plot construction:

```r
MOO_num ~ passed + margin + passed:margin
```

within selected bandwidths, clustered by municipality.

Save:

- `outputs/intermediate/rd_main_models.rds`
- `outputs/tables/rd_event_study_operating.csv`
- `outputs/tables/rd_event_study_all_types.csv`
- `outputs/figures/rd_event_study_moodys.png`

### Change 4: Add `R/11_rd_validity_checks.R`

Implement RD diagnostics:

- Density test around 50% using `rddensity`.
- Pre-treatment Moody's rating balance at `h = -1`.
- Placebo cutoffs at 40%, 45%, 55%, and 60%.
- Donut RD excluding observations within 0.25 and 0.5 percentage points of the cutoff.
- Bandwidth sensitivity:
  - +/- 2.5 percentage points.
  - +/- 5 percentage points.
  - +/- 10 percentage points.
  - Half and double the `rdrobust` selected bandwidth.

Save:

- `outputs/tables/rd_density_test.csv`
- `outputs/tables/rd_balance_checks.csv`
- `outputs/tables/rd_placebo_cutoffs.csv`
- `outputs/tables/rd_donut_checks.csv`
- `outputs/tables/rd_bandwidth_sensitivity.csv`
- `outputs/figures/rd_density_margin.png`
- `outputs/figures/rd_moodys_binned_plot.png`

### Change 5: Add `doc/rd_results_report.qmd`

Create a readable Quarto report for the RD analysis.

Include:

- RD design summary.
- Operating-override event-study table.
- All-types secondary event-study table.
- Event-study coefficient plot.
- RD binned scatterplot.
- Density and balance checks.
- Bandwidth and donut robustness checks.

Render:

- `outputs/report/rd_results_report.html`
- `outputs/report/rd_results_report.docx`

### Optional Change 6: Add a Separate RD Runner

Do not mix the RD analysis into `R/07_render_results.R` by default. Keep the RD workflow separate:

```r
Rscript R/09_build_rd_data.R
Rscript R/10_rd_main_models.R
Rscript R/11_rd_validity_checks.R
quarto render doc/rd_results_report.qmd
```

If one-command execution is desired later, add a separate `R/12_run_rd_workflow.R` that sources the RD scripts in order.

## Key Design Decisions to Resolve

These are the decisions I need from you before implementing the RD analysis.

### Interview Questions

Resolved decisions:

- Primary outcome: Moody's rating only.
- Primary sample: operating overrides.
- Secondary sample: all override types.
- Timing: event-study design using post-vote Moody's ratings at horizons `h = 1` through `h = 5`.
- Multiple operating overrides in the same municipality-year: primary analysis keeps the question closest to the 50% cutoff.
- Role in the paper: causal supplement to the existing panel/Mundlak results.

Remaining questions:

1. Are all operating override questions legally decided by a simple 50% cutoff?
   - If any override type requires a different threshold, it should be excluded or modeled separately.

2. Should all-override secondary models also keep only the closest question to 50% within municipality-year, or should they keep the closest question within each override type?

3. Should close failures be interpreted as a failed fiscal policy treatment or as a signal of voter resistance?
   - This affects the theory section and outcome choice.

4. What is the expected mechanism?
   - Passing an override improves fiscal capacity.
   - Passing an override signals political support for revenue increases.
   - Passing an override increases tax burden and may affect ratings negatively.
   - Passing an override changes future turnout or voter mobilization.

5. What bandwidth range would be substantively convincing to reviewers?
   - Very close elections only, such as +/- 2.5 percentage points.
   - A broader close-election window, such as +/- 5 or +/- 10 percentage points.
   - Data-driven bandwidth as primary.

6. Should Moody's rating use the numeric 1-10 scale as continuous for RD?
   - This is common for RD plots and local linear models.
   - Ordered models near the cutoff are possible but less standard and harder to interpret.

7. Should the RD report include an `h = 0` placebo/sensitivity estimate if the vote date clearly precedes the rating measurement date?

## Recommended Starting Point

My recommended first RD design is:

- Unit: individual override question.
- Running variable: `YesVotes / (YesVotes + NoVotes) - 0.50`.
- Treatment: passage at or above 50%.
- Primary sample: operating overrides only.
- Secondary sample: all override types, with type fixed effects and type-specific robustness checks.
- Primary outcome: Moody's rating only.
- Event-time outcomes: Moody's rating at `h = 1`, `h = 2`, `h = 3`, `h = 4`, and `h = 5`.
- Multiple operating overrides: keep the operating override question closest to 50% within municipality-year.
- Estimator: local linear RD using `rdrobust`, triangular kernel, data-driven bandwidth.
- Validation: density test, covariate balance, placebo cutoffs, and bandwidth sensitivity.
- Paper role: causal supplement to the panel/Mundlak models, not the sole identification strategy.

This design is cleanest because it directly uses the institutional threshold and avoids aggregating the vote-level running variable into municipality-year measures.
