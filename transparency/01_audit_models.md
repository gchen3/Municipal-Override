# Codex Task 1: Audit active models and variables

## Goal

Create a transparent audit of the active operating-override workflow.

The active workflow is:

```r
source(file.path("R", "run_active_workflow.R"))
```

It runs:

1. `R/10_operating_mundlak_models.R`
2. `R/11_build_operating_repeated_event_data.R`
3. `R/12_operating_repeated_event_binary_models.R`
4. `R/13_prepare_slide_tables.R`
5. `R/14_prepare_slide_figures.R`

## Important constraints

Do not edit:

- `R/`
- `Data and Models/`
- `outputs/`

This is an audit-only task.

Do not add new registry-generation scripts, modify workflow scripts, regenerate model outputs, or implement any model changes in this step.

Do not invent model details. Use `UNKNOWN` for any field that is not explicit in inspected code or outputs. Do not infer from memory.

Treat `R/00` through `R/09` as the older frozen Stata-replication workflow. The current active workflow is `R/10` through `R/14`.

## Files to inspect

Inspect:

- `README.md`
- `AGENTS.md`
- `R/run_active_workflow.R`
- `R/active_helpers.R`
- `R/10_operating_mundlak_models.R`
- `R/11_build_operating_repeated_event_data.R`
- `R/12_operating_repeated_event_binary_models.R`
- `R/13_prepare_slide_tables.R`
- `R/14_prepare_slide_figures.R`
- `slides/NorthEast_workshop.qmd`
- `outputs/report/main_results/main_results_10_14.md`
- relevant files under `outputs/tables/`

## Create these files

Create:

```text
transparency/active_model_registry.md
transparency/active_variable_dictionary.md
transparency/active_audit_gaps.md
```

Do not create YAML, CSV, or generated registry files in this step. The Markdown files are the reviewable audit record.

## What to include in `transparency/active_model_registry.md`

Use compact Markdown tables instead of one long section per model. Keep repeated details in shared tables and put one row per fitted model in the model-family tables.

Use this structure:

1. `# Active Model Registry`
2. `## Scope`
3. `## Model Family Index`
4. `## Status Values`
5. `## Shared Specifications`
6. `## Repeated-Event Variant Index`
7. `## Moody's Ordered Probit Models`
8. `## Vote-Share Fixed-Effect Models`
9. `## Repeated-Event DiD Models`
10. `## Review Flags`

In `Model Family Index`, create one row per model family with:

- `model_family`
- number of fitted models
- status
- outcome or outcomes
- estimator
- main script
- standard errors
- primary outputs

Use these status values:

- `headline`: main result model or preferred repeated-event DiD specification,
- `robustness`: alternative sensitivity specification,
- `needs review`: explicit in code but requiring human review,
- `supporting`: supporting/descriptive artifact, not a fitted model.

In `Shared Specifications`, create one row per shared specification with:

- `shared_spec`
- formula or design
- sample rule
- fixed effects
- weights
- source-code evidence

In `Repeated-Event Variant Index`, create one row for each repeated-event variant:

- `window_clean_preferred`
- `never_treated_controls`
- `history_controls`
- `first_time_events`
- `narrow_window`

For each variant, record:

- status
- data object or filter
- control pool
- fixed effects
- covariates
- formula expression
- audit note

In the three fitted-model sections, create exactly one row per fitted model:

- Moody's ordered probit models: 6 rows
- vote-share fixed-effect models: 6 rows
- repeated-event DiD models: 30 rows

For Moody's and vote-share rows, include:

- `model_id`
- status
- label
- outcome
- focal variable
- shared specification id
- main fit command
- variable links
- output files
- source-code evidence

For repeated-event DiD rows, include:

- `model_id`
- status
- event type
- outcome
- variant
- control pool
- fixed effects
- covariates
- main fit command
- outputs
- source-code evidence

In `Review Flags`, list cross-cutting model audit issues such as:

- fixed-effect changes in `history_controls`,
- Moody's rating numeric coding,
- ordered-probit standard-error fallback behavior,
- one-year override timing shift.

Every non-`UNKNOWN` factual claim should be tied to source-code evidence, preferably with file path, line number if available, and the relevant code expression.

## What to include in `transparency/active_variable_dictionary.md`

Use compact Markdown tables and source aliases so each variable can be traced back to raw files and raw field names without repeating long file paths in every row.

Use this structure:

1. `# Active Variable Dictionary`
2. `## Scope`
3. `## Source File Index`
4. `## Audit Status Values`
5. `## Source Lineage`
6. `## Model Use And Audit Notes`

In `Source File Index`, define aliases for raw file groups, including:

- `base_data`: the main municipal-year fiscal and demographic panel,
- `moody_data`: the file matched by `moody_file()`, shown as `Data and Models/6.5/MOO*.dta`,
- `override_files`: the active override files read by `override_source_files`,
- `model-derived`: variables not directly read from a raw data file.

To identify raw variable names, inspect Stata file headers only. Do not read raw rows unless explicitly asked.

In `Audit Status Values`, define:

- `direct`: variable exists directly in at least one raw data file,
- `derived`: variable is constructed from raw variables before modeling,
- `model-derived`: variable is constructed for formulas, Mundlak means, repeated-event stacks, or model outcomes,
- `needs review`: variable exists or is constructed in code, but source meaning, coding, or interpretation needs human review.

In `Source Lineage`, create exactly one row per important model variable with:

- variable
- audit status
- label
- source alias or aliases
- raw variable or variables
- construction rule

In `Model Use And Audit Notes`, create exactly one row per important model variable with:

- variable
- transformation
- unit
- models where used
- source-code evidence
- unresolved questions

Use `UNKNOWN` for anything not explicit in inspected code, file headers, or outputs.

## What to include in `transparency/active_audit_gaps.md`

List:

1. model details that need human review,
2. variables whose construction is unclear,
3. sample restrictions that are unclear,
4. standard error or clustering details that are unclear,
5. output files that could not be mapped to models,
6. possible risks of AI hallucination or unsupported interpretation.

## Done when

You have created the three requested files and summarized:

- files inspected,
- files created,
- active model families found,
- model rows created by family,
- variable rows created in each variable-dictionary table,
- important `UNKNOWN` or `needs review` fields,
- items requiring human review.

Before summarizing, verify:

- `transparency/active_model_registry.md` has 6 Moody's model rows, 6 vote-share model rows, and 30 repeated-event DiD model rows.
- `transparency/active_variable_dictionary.md` has matching row counts in `Source Lineage` and `Model Use And Audit Notes`.
- Markdown files are ASCII-only unless a raw filename requires non-ASCII characters; if a raw filename contains non-ASCII characters, use a code-level alias or wildcard such as `MOO*.dta` and explain it in the source index.

Do not run the full R workflow in this step.

This audit should be reviewed before any implementation. A later task may convert the reviewed Markdown registry into CSV, YAML, or generated reports.
