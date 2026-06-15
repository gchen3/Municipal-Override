# Post-Northeast Stacked DiD Improvement Plan

> **Status: planned, not implemented.** This is a follow-up extension that complements, and does not replace, the existing event-study repeated-event DiD (`R/12`) or the close-election RDD (`R/16`-`R/20`). It is a deliberate post-Northeast addition beyond the frozen Stata-replication scope.

## Goal

Add a **Cumulative Stacked DiD**: a stacked difference-in-differences that reuses the repeated-event stacks but is defined to be directly comparable to the close-election RDD. It estimates whether a successful (or failed) operating override changes the probability of a near-term Moody's rating change relative to municipalities with no operating override in the same local window, using cumulative outcomes against a fully pre-vote baseline.

The design keeps all three lenses side by side:

- **Event-study DiD (`R/12`, unchanged):** the dynamic, per-event-time path of being below/above an `h = -1` baseline, treated vs. a no-same-type-event control. Shows the shape and timing of the response and retains the `h = -2` pre-trend test.
- **Close-election RDD (`R/16`-`R/20`, unchanged):** the clean passage effect among close elections (barely-passed vs. barely-failed). Isolates passage but is small and underpowered.
- **Cumulative Stacked DiD (this plan, new):** an RDD-comparable summary on the larger repeated-event sample, plus a built-in success-vs-failure bridge.

## Relationship and Why It Helps

The event-study DiD and the RDD answer different questions, and neither is directly comparable to the other (different outcome definitions, baselines, and contrasts). The Cumulative Stacked DiD adopts the RDD's outcome definition and baseline inside the stacked DiD framework, so the three results can be read on common terms. Its **success-minus-failure difference** approximates the RDD's barely-passed-vs-barely-failed contrast on the much larger repeated-event sample, providing a powered triangulation of the RDD result.

## Design

### Treatment contrasts

Two stacked comparisons, run separately:

- `success_vs_no_override`: treated = clean successful operating override events; controls = municipalities with no operating override of either type in the window.
- `failure_vs_no_override`: treated = clean failed operating override events; controls = municipalities with no operating override of either type in the window.

The bridge to the RDD is the **difference** of the two treated effects, estimated directly via a pooled model with a success indicator (below).

The combined **attempt** contrast (any attempt vs. no override) is deliberately **excluded**: the attempt category pools successes and failures together, so it is not interpretable for a success-vs-failure-focused improvement and is not used anywhere in this design.

### Control group

Controls are municipalities with **no operating override of either type** (no success and no failure) inside the event window. This is stricter than the event-study DiD's window-clean pool, which only excludes same-type events. It is derivable from the existing stacks by keeping control rows with `control_attempts_in_window == 0`.

### Treated-event cleanliness

Treated events are restricted to **fully clean** windows: a success event must have no failure in its window (`failures_in_window == 0`) and a failure event must have no success (`successes_in_window == 0`). This is required for the success-vs-failure bridge to be interpretable: under the looser same-type-clean rule, 39% of success events also contain a failure and 49% of failure events also contain a success, which would mix the two treatments. Fully clean leaves 64 usable success and 44 usable failure treated events (vs. 117 and 95 under same-type-clean). The looser same-type-clean rule is retained as a higher-N robustness check, explicitly flagged as cross-contaminated.

### Baseline

`t - 2` (i.e. `rel_year == -2`, the fully pre-vote year `F - 1`), matching the close-election RDD. Observations with a missing baseline rating are dropped.

### Outcomes (cumulative)

Per municipality within a stack, relative to the `t - 2` baseline rating:

- `cum_downgrade_within_0`, `_within_1`, `_within_2`: any rating below baseline at `rel_year` in `{0}`, `{0,1}`, `{0,1,2}`.
- `cum_upgrade_within_0`, `_within_1`, `_within_2`: any rating above baseline over the same windows.

Outcomes are available-case (defined when the baseline and at least one horizon-year rating are observed); do not impute. Downgrade and upgrade are kept separate. This collapses the event-time dimension into one cumulative observation per municipality-stack.

### Estimation

A stacked linear probability model. After collapsing to one row per municipality-stack, calendar time is absorbed by the stack, so the fixed effect is the stack itself:

```r
cum_outcome ~ treated_event | stack_id      # feols, vcov = ~ code
```

- `treated_event = 1` for the event municipality, 0 for its no-override controls.
- The `t - 2` baseline differences out the municipality's fixed rating level; `stack_id` absorbs the stack's calendar window and common shocks.
- Standard errors clustered by municipality; report the number of municipalities (clusters), stacks, and N for every model.

### Success-vs-failure bridge

Pool the success and failure stacks and estimate the difference directly:

```r
cum_outcome ~ treated_event + treated_event:is_success | stack_id   # feols, vcov = ~ code
```

The `treated_event:is_success` coefficient is the success-vs-failure differential and is the quantity to compare against the close-election RDD estimate.

### Pre-trend and placebo

The `t - 2` baseline removes the `h = -2` pre-trend test available in the event-study DiD. The design keeps the existing `[-2, +2]` stacks (no rebuild) and uses a **`t - 1` vs `t - 2` placebo** instead: a pre-period rating-change indicator (any change between `rel_year = -2` and `rel_year = -1`) regressed on `treated_event`. Treatment should not predict the pre-period change. Widening the window to `h = -3` for a stronger pre-trend test was considered and not adopted (it would require rebuilding the stacks and would worsen rating-gap attrition).

## Caveats and Honest Framing

- The separate `success_vs_no_override` and `failure_vs_no_override` estimates still **bundle selection** (override-holders differ from non-holders); they are event-associations, not clean passage effects. The **difference** of the two is the cleaner, RDD-comparable quantity.
- This is a **stacked cumulative treated-vs-control comparison**, not a dynamic event study. Label it as such; the dynamic path remains the job of `R/12`.
- It is a quasi-experimental panel design; override timing remains endogenous. Treat estimates as suggestive and lean on the placebo and the RDD triangulation.

## Implementation Stages

### Reuse Existing Infrastructure

- Stacks: reuse the saved `active_operating_*_stack_window_clean.rds` from `R/11`; derive the no-override control pool by filtering control rows to `control_attempts_in_window == 0`. Restrict treated events to fully clean windows using the `failures_in_window` / `successes_in_window` columns on the events tibble (the same-type-clean set is the robustness variant).
- Outcomes: add a cumulative-outcome helper to `R/close_election_helpers.R` (or a small `R/stacked_did_helpers.R`) analogous to `add_close_election_outcomes`, but operating on stack rows grouped by `stack_id` and `code` with a `rel_year == -2` baseline.
- Models, formatting, paths: reuse `fit_fe_lm`, `fmt_num`, `stars`, `fmt_int`, `write_tex`, `paths`, and `make_output_dirs`.

### Stage 1. Build the Cumulative Stacked DiD data

Create `R/21_cumulative_stacked_did_models.R` (or split build/model if it grows). Tasks:

- Load the `R/11` success and failure window-clean stacks.
- Restrict controls to `control_attempts_in_window == 0` (no override of either type in window).
- Construct the cumulative within-0/1/2-year downgrade and upgrade outcomes vs the `rel_year == -2` baseline; report N per outcome.
- Collapse to one row per `stack_id` x `code`.

### Stage 2. Estimate the models

- For each event type (`success_vs_no_override`, `failure_vs_no_override`) and each cumulative outcome, fit `cum_outcome ~ treated_event | stack_id`, clustered by `code`.
- Fit the pooled bridge model with `treated_event:is_success`.
- Report estimate, SE, p-value, N, municipalities (clusters), and stacks for every model.
- Save to `outputs/tables/active_operating_cumulative_stacked_did.csv` and a `.rds`.

### Stage 3. Placebo

- Build the `t - 1` vs `t - 2` pre-period change indicator and regress on `treated_event` for each event type.
- Save to `outputs/tables/active_operating_cumulative_stacked_did_placebo.csv`.

### Stage 4. Triangulation summary

- Assemble a small table placing the success-vs-failure bridge estimate next to the close-election RDD estimate for the same outcomes, so the two designs can be compared directly.
- Save to `outputs/tables/active_operating_cumulative_stacked_did_vs_rdd.csv`.

### Stage 5. Review first; defer publication and incorporation

- Keep all outputs in their own `active_operating_cumulative_stacked_did_*` namespace. Do not write into `outputs/tables/publication/`, do not touch the `northeast_*` main-result or slide tables, and do not wire anything into `R/run_active_workflow.R`.
- Only after review and an explicit decision to promote: build publication tables mirroring `R/15` / `R/20` (full `table`/`booktabs` with `\caption`/`\label` and notes) under `outputs/tables/publication/` as `post_northeast_stacked_did_*_pub.tex`, assembled by a `docs/post_northeast_stacked_did_tables.qmd` rendered to `outputs/tables/`.
- Transparency bookkeeping deferred to promotion, as with the close-election track.

## Script Conventions

- `R/21` opens with the standard header (`source("R/00_config.R")`, `load_required_packages(...)`, `make_output_dirs()`, `source("R/active_helpers.R")`, helpers), with a dependency guard that sources `R/11_build_operating_repeated_event_data.R` if the stacks are missing.
- Do **not** add `R/21` to `R/run_active_workflow.R`. Provide a separate driver (for example `R/run_post_northeast_stacked_did.R`) or run it on its own.

## Resolved Decisions (from a pre-implementation feasibility probe)

A feasibility probe on the existing `R/11` stacks settled the two open design choices:

- **Treated-event cleanliness: fully clean is the primary spec.** Same-type-clean cross-contaminates the success-vs-failure bridge (39% of success events also have a failure; 49% of failure events also have a success). Fully clean yields 64 usable success and 44 usable failure treated events; same-type-clean (117 / 95) is kept as a higher-N robustness check.
- **Window: keep `[-2, +2]` with a `t - 1` placebo.** Widening to `[-3, +3]` was not adopted.

Probe counts (window-clean stacks, no-override control pool):

| | Success | Failure |
| --- | ---: | ---: |
| Clean treated events (same-type rule) | 176 | 144 |
| Fully clean treated events | 108 | 74 |
| Usable (baseline + at least one horizon rating) | 117 | 95 |
| Usable and fully clean (primary sample) | 64 | 44 |
| Unique no-override control municipalities | 333 | 333 |

These are pre-model counts; final model N reflects available-case cumulative outcomes and is reported per model.
