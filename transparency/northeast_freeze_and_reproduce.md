# Northeast Freeze And Reproduce Workflow

This document describes the transparency utilities for freezing and reproducing the Northeast operating-override result outputs. These scripts are not part of the numbered model workflow in `R/`.

## Scripts

- `transparency/freeze_northeast_results.R` freezes the current Northeast outputs on disk.
- `transparency/reproduce_northeast_results.R` reruns the workflow that generates the Northeast outputs and then copies the newly generated files.

Both scripts preserve project-relative paths inside the bundle and refuse to overwrite an existing bundle.

## User Workflow

From the project root:

```bash
Rscript --vanilla -e 'source(file.path("R", "run_active_workflow.R"))'
Rscript --vanilla transparency/freeze_northeast_results.R northeast_v1
Rscript --vanilla transparency/reproduce_northeast_results.R northeast_v1
```

The first command is a manual fresh run before freezing. The freeze script itself does not rerun the workflow; it copies the current files from `outputs/`.

## Frozen Bundle

The freeze script writes:

```text
outputs/frozen_original/<freeze_id>/
```
For the example above, the folder is:

```text
outputs/frozen_original/northeast_v1/
```

It copies the expected Northeast output files and these transparency files:

```text
transparency/northeast_results_registry.md
transparency/northeast_variable_dictionary.md
```

It also writes:

```text
MANIFEST.yml
sessionInfo.txt
git_commit.txt
git_status_short.txt
file_hashes.csv
missing_outputs.csv
```

## Reproduced Bundle

The reproduce script reruns:

```r
source(file.path("R", "run_active_workflow.R"))
```

Then it writes:

```text
outputs/reproduced/<freeze_id>/
```
For the example above, the folder is:

```text
outputs/reproduced/northeast_v1/
```

with the same output inventory, audit files, manifest, session info, git metadata, hashes, and missing-output report.

## Northeast Output Inventory

The core slide outputs are:

```text
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

The machine-readable outputs copied when present are:

```text
outputs/tables/active_operating_repeated_event_binary_did.csv
outputs/tables/active_operating_repeated_event_binary_did_main.csv
outputs/tables/active_operating_repeated_event_sample_counts.csv
outputs/figures/northeast_annual_override_amounts.csv
outputs/report/northeast_event_study_figures.html
```

Some machine-readable source files keep the `active_` prefix because that is how the upstream workflow names them; this utility treats them as Northeast supporting outputs.

Missing expected files are recorded in `missing_outputs.csv` and listed in `MANIFEST.yml`.

## Immutability

Freeze and reproduction folders are audit bundles. Do not edit files inside them manually. Do not overwrite an existing bundle.

If results need to be refreshed, use a new freeze id:

```bash
Rscript --vanilla transparency/freeze_northeast_results.R northeast_v2
Rscript --vanilla transparency/reproduce_northeast_results.R northeast_v2
```

## Verification

The next transparency step should compare:

```text
outputs/frozen_original/northeast_v1/
outputs/reproduced/northeast_v1/
```
or the matching folders for the Northeast freeze id you used, using the saved file inventories, hashes, manifests, and copied transparency files.
