source(file.path("R", "00_config.R"))
load_required_packages(c("dplyr", "tidyr", "purrr", "readr"))
make_output_dirs()
source(file.path("R", "active_helpers.R"))
source(file.path("R", "stacked_did_helpers.R"))

# Post-Northeast Cumulative Stacked DiD publication tables. Mirrors the LaTeX
# style of R/20_close_election_publication_tables.R and is consumed by
# docs/post_northeast_did_tables.qmd. Reports the fully-clean primary sample
# with controls. Run R/21 first if the result CSVs are missing.
did_csv <- file.path(paths$tables, "active_operating_cumulative_stacked_did.csv")
if (!file.exists(did_csv) ||
    !file.exists(file.path(paths$tables, "active_operating_cumulative_stacked_did_controls.csv"))) {
  source(file.path("R", "21_cumulative_stacked_did_models.R"))
}

publication_table_dir <- file.path(paths$tables, "publication")
dir.create(publication_table_dir, recursive = TRUE, showWarnings = FALSE)

escape_latex_text <- function(x) {
  x <- gsub("\\", "\\textbackslash{}", x, fixed = TRUE)
  x <- gsub("&", "\\&", x, fixed = TRUE)
  x <- gsub("%", "\\%", x, fixed = TRUE)
  x
}

write_publication_tex <- function(file_name, lines) {
  writeLines(lines, file.path(publication_table_dir, file_name), useBytes = TRUE)
}

table_note <- function(note) {
  c(
    "\\vspace{0.05in}",
    paste0(
      "\\begin{minipage}{0.96\\textwidth}\\footnotesize\\emph{Notes:} ",
      note,
      "\\end{minipage}"
    )
  )
}

publication_table <- function(caption, label, column_spec, body_lines, note, size = "\\small") {
  c(
    "\\begin{table}[!htbp]",
    "\\centering",
    paste0("\\caption{", caption, "}"),
    paste0("\\label{", label, "}"),
    size,
    paste0("\\begin{tabular}{", column_spec, "}"),
    "\\toprule",
    body_lines,
    "\\bottomrule",
    "\\end{tabular}",
    table_note(note),
    "\\end{table}"
  )
}

# ---------------------------------------------------------------------------
# Tables 1-2: one table per rating direction (downgrade, upgrade). Each shows
# the override treatment effect across horizons and the control coefficients
# from the within-2 model, in two columns: success-vs-no-override and
# failure-vs-no-override. No success-minus-failure bridge -- the comparison of
# interest is override vs. no override (a failed override is still an override
# and signals a municipality that cannot balance its budget within current
# resources).
# ---------------------------------------------------------------------------
contrast_cols <- c("success_vs_no_override", "failure_vs_no_override", "any_override_vs_no_override")

did <- readr::read_csv(did_csv, show_col_types = FALSE) |>
  dplyr::filter(spec == "with_controls")
placebo <- readr::read_csv(
  file.path(paths$tables, "active_operating_cumulative_stacked_did_placebo.csv"),
  show_col_types = FALSE
)
controls <- readr::read_csv(
  file.path(paths$tables, "active_operating_cumulative_stacked_did_controls.csv"),
  show_col_types = FALSE
)

treat_long <- dplyr::bind_rows(
  did |> dplyr::select(contrast, outcome, estimate, std_error, p_value),
  placebo |> dplyr::select(contrast, outcome, estimate, std_error, p_value)
)

# A label row plus its standard-error row, across the success/failure columns.
# `getter(ct)` returns list(est, se) already formatted for contrast `ct`.
two_line_row <- function(label, getter) {
  cells <- lapply(contrast_cols, getter)
  c(
    paste0(label, " & ", paste(vapply(cells, `[[`, character(1), "est"), collapse = " & "), " \\\\"),
    paste0(" & ", paste(vapply(cells, `[[`, character(1), "se"), collapse = " & "), " \\\\")
  )
}

fmt_cell <- function(r) {
  list(est = paste0(fmt_num(r$estimate), stars(r$p_value)),
       se = paste0("(", fmt_num(r$std_error), ")"))
}

build_direction_table <- function(direction) {
  pre <- paste0("pre_", direction)
  w0 <- paste0("cum_", direction, "_within_0")
  w1 <- paste0("cum_", direction, "_within_1")
  w2 <- paste0("cum_", direction, "_within_2")

  treat_row <- function(label, outcome) {
    two_line_row(label, function(ct) {
      fmt_cell(treat_long |> dplyr::filter(contrast == ct, outcome == !!outcome))
    })
  }
  ctrl_row <- function(v) {
    label <- paste0("\\quad ", escape_latex_text(unname(active_variable_labels[v])))
    two_line_row(label, function(ct) {
      fmt_cell(controls |> dplyr::filter(contrast == ct, outcome == w2, term == v))
    })
  }
  count_cells <- function(field) {
    vapply(contrast_cols, function(ct) {
      r <- did |> dplyr::filter(contrast == ct, outcome == w2)
      fmt_int(r[[field]])
    }, character(1))
  }

  c(
    " & Success vs. & Failure vs. & Any override \\\\",
    " & no override & no override & vs.\\ no override \\\\",
    "\\midrule",
    "\\multicolumn{4}{l}{\\textit{Override effect (treated vs.\\ no override)}} \\\\",
    treat_row("\\quad Pre-period (placebo)", pre),
    treat_row("\\quad Within 0 yr", w0),
    treat_row("\\quad Within 1 yr", w1),
    treat_row("\\quad Within 2 yr", w2),
    "\\midrule",
    "\\multicolumn{4}{l}{\\textit{Controls (within-2 yr model)}} \\\\",
    unlist(lapply(active_controls, ctrl_row)),
    "\\midrule",
    paste0("Stack fixed effects & ", paste(rep("Yes", 3), collapse = " & "), " \\\\"),
    paste0("Observations & ", paste(count_cells("nobs"), collapse = " & "), " \\\\"),
    paste0("Municipalities & ", paste(count_cells("n_clusters"), collapse = " & "), " \\\\"),
    paste0("Stacks & ", paste(count_cells("n_stacks"), collapse = " & "), " \\\\")
  )
}

direction_note <- function(direction) {
  paste0(
    "Stacked difference-in-differences on the repeated-event sample. Each column is a separate stacked linear probability model comparing clean operating override events ",
    "(event years 2005--2019; treated events fully clean of the opposite outcome) against municipalities with no operating override of either type in the $[-2,+2]$ window. ",
    "The first two columns restrict treated events to successful and failed overrides respectively; the \\emph{Any override} column pools both (any override vs.\\ no override). ",
    "The outcome is an indicator for a Moody's rating ", direction, " relative to the pre-vote baseline rating two years before the event ($t-2$), cumulated through the event year (within 0), ",
    "the following year (within 1), and two years out (within 2). The pre-period row is a placebo: a $t-1$-versus-$t-2$ rating change regressed on treatment, which should be zero. ",
    "The override-effect rows report the treatment coefficient at each horizon; the control coefficients below are from the within-2-year model, whose treatment coefficient is the Within 2 yr row. ",
    "Both columns are override-vs.-no-override contrasts: a failed override is still an override and signals a municipality unable to balance its budget within current resources. ",
    "All models include the fiscal controls measured at the election fiscal year. Stack fixed effects throughout; standard errors in parentheses clustered by municipality. ",
    "* p $<$ 0.10, ** p $<$ 0.05, *** p $<$ 0.01."
  )
}

write_publication_tex(
  "post_northeast_did_downgrade_pub.tex",
  publication_table(
    "Operating Overrides and Near-Term Moody's Rating Downgrades",
    "tab:post_northeast_did_downgrade",
    "lccc",
    build_direction_table("downgrade"),
    direction_note("downgrade")
  )
)

write_publication_tex(
  "post_northeast_did_upgrade_pub.tex",
  publication_table(
    "Operating Overrides and Near-Term Moody's Rating Upgrades",
    "tab:post_northeast_did_upgrade",
    "lccc",
    build_direction_table("upgrade"),
    direction_note("upgrade")
  )
)

# ---------------------------------------------------------------------------
# Table 3: pre-treatment balance of the fiscal fundamentals.
# ---------------------------------------------------------------------------
balance <- readr::read_csv(
  file.path(paths$tables, "active_operating_cumulative_stacked_did_balance.csv"),
  show_col_types = FALSE
)

balance_row <- function(v) {
  s <- balance |> dplyr::filter(variable == v, contrast == "success_vs_no_override")
  f <- balance |> dplyr::filter(variable == v, contrast == "failure_vs_no_override")
  label <- escape_latex_text(unname(active_variable_labels[v]))
  c(
    paste0(label, " & ", fmt_num(s$estimate), stars(s$p_value), " & ", fmt_num(f$estimate), stars(f$p_value), " \\\\"),
    paste0(" & (", fmt_num(s$std_error), ") & (", fmt_num(f$std_error), ") \\\\")
  )
}

balance_body <- c(
  " & Success vs. & Failure vs. \\\\",
  " & no override & no override \\\\",
  "\\midrule",
  unlist(lapply(active_controls, balance_row))
)

balance_note <- paste0(
  "Each cell is the coefficient from regressing the listed control (measured at the election fiscal year, $t-1$) on the treatment indicator within stacks, ",
  "i.e.\\ the pre-treatment difference between treated events and their no-override controls; standard errors in parentheses are clustered by municipality. ",
  "A significant coefficient indicates pre-treatment imbalance (selection). Override municipalities of both types are lower on excess property tax capacity and fiscal reserve; ",
  "successful-override municipalities are additionally higher on revenue stability and lower on unemployment. The two imbalanced reserve/capacity measures are also the controls that carry signal in the rating-change models (Tables~\\ref{tab:post_northeast_did_downgrade} and~\\ref{tab:post_northeast_did_upgrade}). ",
  "* p $<$ 0.10, ** p $<$ 0.05, *** p $<$ 0.01."
)

write_publication_tex(
  "post_northeast_did_balance_pub.tex",
  publication_table(
    "Pre-Treatment Balance of Fiscal Fundamentals",
    "tab:post_northeast_did_balance",
    "lcc",
    balance_body,
    balance_note
  )
)
