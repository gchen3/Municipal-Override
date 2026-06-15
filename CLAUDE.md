# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

An R analysis project on Massachusetts municipal override elections and their relationship to municipal credit ratings (Moody's, S&P) and voter support. There is no build step or test suite — "running" means sourcing R scripts that read source data and write tables/figures/reports under `outputs/`.

## Running the workflows

Both entry points are plain `source()` driver scripts run from the **project root** (paths are project-relative; never `setwd()`).

Active workflow (current model path, feeds the slide deck and publication drafts):
```r
source(file.path("R", "run_active_workflow.R"))   # runs R/10 -> R/15 in order
```

Frozen Stata-replication track (archival comparison only):
```r
source(file.path("R", "09_run_stata_replication.R"))   # runs R/01 -> R/08 in order
```

Run or debug a single stage by sourcing it directly, e.g. `source(file.path("R", "12_operating_repeated_event_binary_models.R"))`. Each active stage re-sources its own setup (see below), so individual stages are runnable on their own.

The slide deck is rendered separately from `slides/NorthEast_workshop.qmd` (Quarto), which consumes the slide-ready outputs listed in `README.md`.

## Architecture

**Two parallel tracks, one shared config.** `R/00_config.R` is the common foundation for *both* tracks: it defines `paths`, `load_required_packages()`, `make_output_dirs()`, the `cpi_lookup` deflator, `variable_labels`, the model-fitting helpers (`fit_ordered_probit`, `fit_probit`, `fit_fe_lm`), and `write_model_table()`. Active scripts additionally source `R/active_helpers.R` for active-only term lists, labels, the repeated-event/DiD helpers, and LaTeX table writers (`write_tex`, `cell_with_se`, etc.).

**Numbered pipeline stages.** Scripts run in numeric order and pass state through cached `.rds` files in `outputs/intermediate/`, not in-memory objects. The canonical example: stages check `if (!file.exists(...))` for `data_for_regression.rds` and source `R/02_build_regression_data.R` to rebuild it on demand. So the dependency graph is: data-build stages produce intermediate `.rds`; model stages read them and write `.tex`/figures.

- `R/00`–`R/09`: **frozen** Stata-replication track. Builds the municipality-year panel (`01`, `02`), descriptives (`03`), main + robustness Mundlak tables (`04`, `05`), Figure 1 margins (`06`), report render (`07`), and validation against `Data and Models/6.22/Method_Results.docx` (`08`).
- `R/10`–`R/15`: **active** operating-override track. Mundlak ordered-probit rating models + two-way FE voter-support models (`10`), repeated-event stack construction (`11`), binary downgrade/upgrade DiD models (`12`), slide tables (`13`), slide figures (`14`), publication-table drafts (`15`).

**Modeling conventions worth knowing:**
- Rating outcomes are **ordinal** → ordered probit (`MASS::polr`, `method = "probit"`). `fit_ordered_probit` has a fallback path with explicit starting values for models that fail to converge.
- Standard errors are **municipality-clustered** (`cluster = "code"`) throughout — via `sandwich::vcovCL` for GLM/polr models and `fixest` `vcov = ~code` for FE/DiD models. The `fit_*` helpers return a `list(model, vcov, data)` so the clustered vcov travels with the model into `write_model_table`/`coef_row`.
- "Mundlak" specs add municipality-mean covariates (the `con`-suffixed terms; see `con_terms()`) as a correlated-random-effects device.
- The repeated-event DiD uses **stacked** event windows (`h = -2..2`, `ref = -1`) with `stack_id^code` and `stack_id^year` fixed effects (`fixest::i(rel_year, treated_event, ref = -1)`). Downgrade/upgrade outcomes are defined relative to each event's `h = -1` baseline rating in `add_rating_change_outcomes()`.

**Data location.** Source `.dta` files live under `Data and Models/` (active track reads `Data and Models/6.5/`, resolved via `data_65_file()` and `moody_file()`). These are read-only inputs — do not modify them.

**Outputs.** Everything generated lands under `outputs/` (`intermediate/`, `tables/`, `tables/slides/`, `tables/publication/`, `figures/`, `report/`) and is largely gitignored. Treat it as regenerable; don't hand-edit generated tables/figures.

## Conventions (from AGENTS.md — apply these)

- Keep changes small, localized, and easy to review; avoid unrelated refactors.
- Project-relative paths only; never absolute paths or `setwd()`.
- Descriptive `snake_case` names; concise modern R (tidyverse + `fixest`/`MASS`).
- Explain the *why* in comments, not the obvious *what*; keep scripts flat and easy to review.
- Assume the environment is prepared and let it error out by design (e.g. missing packages/files stop loudly) — avoid repetitive defensive `tryCatch`/`file.exists` guards unless the requested logic needs them.
- Do **not** include package installation code (`load_required_packages` only checks/loads; missing packages error out by design).
- Do **not** add `cat()`/`print()`/`message()` unless requested; minimize console clutter.
- Do not open large data, `.RData`/`.rds`, `.csv`/`.xlsx`, `.docx`, or image files unless explicitly asked. Do not scan the whole repo unless asked.
- Do not modify raw data or generated result files unless explicitly asked.

## Documentation

Planning/audit docs live in `docs/`; the reproducibility record (results registry, variable dictionary, freeze/reproduce scripts) lives in `transparency/`. `README.md` has the full file-by-file workflow description and the canonical list of slide-deck output paths.
