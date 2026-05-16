# AGENTS.md

## Scope and cost control

- Do not scan the whole repository unless explicitly asked.
- Read only files directly relevant to the current task.
- Do not open large data, result, archive, session, or binary files unless explicitly asked.
- Treat `data/`, `.RData`, `.rds`, `.RDS`, `.csv`, `.xlsx`, and image files as off-limits unless specifically requested.
- If command output is long, summarize only the relevant part.

## Project type

- This is an R project.
- Prefer inspecting `.R`, `.Rmd`, `.qmd`, `.Rproj`, and small `.md` files.

## R coding style

- Prefer concise, readable, modern R.
- Make small, localized changes; avoid unrelated refactors.
- Use project-relative paths; never use absolute paths or `setwd()`.
- Keep scripts flat and easy to review.
- Use descriptive snake_case names.
- Do not include package installation code.
- Explain the “why” in comments, not the obvious “what.”

## Output and validation

- Minimize console clutter.
- Do not add `cat()`, `print()`, or `message()` unless requested.
- Assume the project environment is prepared.
- Avoid repetitive defensive checks unless needed for the requested logic.

## Workflow

- Before editing, summarize which files you intend to inspect.
- Keep changes small and scoped.
- Do not modify raw data or generated result files unless explicitly asked.