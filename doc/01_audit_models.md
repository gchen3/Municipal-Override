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
doc/active_model_registry.md
doc/active_variable_dictionary.md
doc/active_audit_gaps.md
```

Do not create YAML, CSV, or generated registry files in this step. The Markdown files are the reviewable audit record.

## What to include in `doc/active_model_registry.md`

For every fitted active model, create one registry entry. If several models belong to the same family, include a `model_family` field rather than collapsing them into one entry.

Use this template for each entry:

```md
## model_id

- Label / model family:
- Source script / main fit command:
- Model type / R function or package:
- Outcome:
- Key variables or event indicators:
- Controls / Mundlak controls:
- Fixed effects / year indicators:
- Standard errors: type, cluster, implementation, fallback behavior
- Sample: weights, restrictions, missing-data rule
- Event design: window, treatment, comparison group, downgrade/upgrade definition
- Output files:
- Source-code evidence:
- Unresolved questions:
```

At minimum, each model entry should record:

- `model_id`
- model identity: label and model family
- estimation source: script, main fit command, model type, and R function/package
- specification: outcome, key variables or event indicators, controls, Mundlak controls, fixed effects, and year indicators
- inference: standard error type, clustering variable, implementation function, and fallback behavior, if any
- sample: weights, restrictions, and missing-data rule
- event design, if applicable: event window, treatment definition, comparison group, and downgrade/upgrade definition
- output files
- source-code evidence
- unresolved questions

Every non-`UNKNOWN` factual claim should be tied to source-code evidence, preferably with file path, line number if available, and the relevant code expression.

## What to include in `doc/active_variable_dictionary.md`

For every important model variable, record:

```md
## variable_name

- Plain-English label:
- Source or construction script:
- Construction rule:
- Transformation:
- Unit:
- Models where used:
- Source-code evidence:
- Unresolved questions:
```

Use `UNKNOWN` for anything not explicit in inspected code or outputs.

## What to include in `doc/active_audit_gaps.md`

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
- important `UNKNOWN` fields,
- items requiring human review.

Do not run the full R workflow in this step.

This audit should be reviewed before any implementation. A later task may convert the reviewed Markdown registry into CSV, YAML, or generated reports.
