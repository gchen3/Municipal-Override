source(file.path("R", "00_config.R"))
load_required_packages(c("dplyr", "tidyr", "purrr", "readr"))
make_output_dirs()
source(file.path("R", "active_helpers.R"))
source(file.path("R", "close_election_helpers.R"))

# Post-Northeast RDD publication tables for the close-election follow-up.
# Mirrors the LaTeX style of R/15_prepare_publication_tables.R and is consumed
# by docs/post_northeast_rdd_tables.qmd. Reports the +/- 5pp working bandwidth.
if (!file.exists(file.path(paths$tables, "active_operating_close_election_rating_models.csv")) ||
    !file.exists(file.path(paths$tables, "active_operating_close_election_control_coefs.csv"))) {
  source(file.path("R", "17_close_election_rating_models.R"))
}
if (!file.exists(file.path(paths$tables, "active_operating_close_election_balance.csv"))) {
  source(file.path("R", "18_close_election_diagnostics.R"))
}
if (!file.exists(file.path(paths$tables, "active_operating_close_election_event_study.csv"))) {
  source(file.path("R", "19_close_election_event_study.R"))
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

working_band <- close_election_working_band
outcome_order <- close_election_outcomes

rating <- readr::read_csv(
  file.path(paths$tables, "active_operating_close_election_rating_models.csv"),
  show_col_types = FALSE
) |>
  dplyr::filter(band == working_band)

# Pull a spec's rows in the fixed outcome order.
spec_cells <- function(spec_key) {
  rows <- rating |> dplyr::filter(spec == spec_key)
  rows <- rows[match(outcome_order, rows$outcome), ]
  list(
    estimate = paste0(fmt_num(rows$estimate), stars(rows$p_value)),
    std_error = paste0("(", fmt_num(rows$std_error), ")"),
    ame = paste0(fmt_num(rows$ame), stars(rows$p_value)),
    nobs = rows$nobs,
    n_clusters = rows$n_clusters
  )
}

# Control coefficients from the main-spec models (working-band LPM with controls).
control_coefs <- readr::read_csv(
  file.path(paths$tables, "active_operating_close_election_control_coefs.csv"),
  show_col_types = FALSE
)

control_rows <- function(term) {
  rows <- control_coefs |> dplyr::filter(term == .env$term)
  rows <- rows[match(outcome_order, rows$outcome), ]
  c(
    paste0(
      escape_latex_text(unname(active_variable_labels[[term]])), " & ",
      paste(paste0(fmt_num(rows$estimate), stars(rows$p_value)), collapse = " & "), " \\\\"
    ),
    paste0(" & ", paste(paste0("(", fmt_num(rows$std_error), ")"), collapse = " & "), " \\\\")
  )
}

outcome_header <- c(
  " & \\multicolumn{2}{c}{Rating downgrade} & \\multicolumn{2}{c}{Rating upgrade} \\\\",
  "\\cmidrule(lr){2-3}\\cmidrule(lr){4-5}",
  " & Within 1 yr & Within 2 yr & Within 1 yr & Within 2 yr \\\\",
  "\\midrule"
)

control_note <- paste(
  escape_latex_text(active_variable_labels[active_controls]),
  collapse = "; "
)

# Table 1: main results (primary LPM with controls).
primary <- spec_cells("lpm_controls")
main_body <- c(
  outcome_header,
  paste0("Close success & ", paste(primary$estimate, collapse = " & "), " \\\\"),
  paste0(" & ", paste(primary$std_error, collapse = " & "), " \\\\"),
  "\\midrule",
  "\\multicolumn{5}{l}{Controls} \\\\",
  unlist(lapply(active_controls, control_rows)),
  "\\midrule",
  paste0("Model-year fixed effects & ", paste(rep("Yes", 4), collapse = " & "), " \\\\"),
  paste0("Observations & ", paste(fmt_int(primary$nobs), collapse = " & "), " \\\\"),
  paste0("Municipalities & ", paste(fmt_int(primary$n_clusters), collapse = " & "), " \\\\")
)

main_note <- paste0(
  "The sample is operating override municipality-years within a $\\pm 5$ percentage-point yes-vote margin of the 50\\% passage threshold, ",
  "collapsed to one observation per municipality-year (single close elections and same-direction multiples; mixed win-and-loss years dropped). ",
  "\\emph{Close success} equals one for a barely-passed override and zero for a barely-failed override; there is no no-election control group. ",
  "Outcomes are indicators for any Moody's rating change within one or two years relative to a pre-vote baseline rating two years before the model year. ",
  "Models are linear probability models with model-year fixed effects; coefficients are changes in probability. ",
  "All columns include the listed controls measured at the election fiscal year: ", control_note, ". ",
  "Standard errors in parentheses are clustered by municipality. ",
  "* p $<$ 0.10, ** p $<$ 0.05, *** p $<$ 0.01."
)

write_publication_tex(
  "post_northeast_rdd_main_pub.tex",
  publication_table(
    "Close-Election Effects on Near-Term Moody's Rating Changes",
    "tab:post_northeast_rdd_main",
    "lcccc",
    main_body,
    main_note
  )
)

# Table 2: robustness across estimators.
lpm_block <- function(spec_key, label) {
  cells <- spec_cells(spec_key)
  c(
    paste0(label, " & ", paste(cells$estimate, collapse = " & "), " \\\\"),
    paste0(" & ", paste(cells$std_error, collapse = " & "), " \\\\")
  )
}
probit_cells <- spec_cells("probit_no_fe")
robust_body <- c(
  outcome_header,
  lpm_block("lpm_bare", "LPM, no controls"),
  lpm_block("lpm_controls", "LPM, with controls"),
  lpm_block("lpm_local_linear", "LPM, local-linear margin"),
  "\\midrule",
  paste0("Probit, average marginal effect & ", paste(probit_cells$ame, collapse = " & "), " \\\\")
)

robust_note <- paste0(
  "Each cell is the \\emph{close success} effect on the row outcome at the $\\pm 5$ percentage-point bandwidth. ",
  "Linear probability rows report the coefficient with the municipality-clustered standard error in parentheses. ",
  "The local-linear row adds the signed vote margin and its interaction with close success, so the reported effect is at the threshold. ",
  "The probit row reports the average marginal effect, estimated without year fixed effects to avoid separation on rare outcomes; ",
  "its significance markers come from the municipality-clustered latent coefficient. ",
  "* p $<$ 0.10, ** p $<$ 0.05, *** p $<$ 0.01."
)

write_publication_tex(
  "post_northeast_rdd_robustness_pub.tex",
  publication_table(
    "Close-Election Rating-Change Models: Robustness Across Estimators",
    "tab:post_northeast_rdd_robustness",
    "lcccc",
    robust_body,
    robust_note
  )
)

# Table 3: event-study pre-trend diagnostic.
event_study <- readr::read_csv(
  file.path(paths$tables, "active_operating_close_election_event_study.csv"),
  show_col_types = FALSE
) |>
  dplyr::arrange(rel_year)

event_row <- function(h) {
  row <- event_study |> dplyr::filter(rel_year == h)
  if (h == -1) {
    return(paste0("$h=", h, "$ & 0 (reference) \\\\"))
  }
  c(
    paste0("$h=", h, "$ & ", fmt_num(row$estimate), stars(row$p_value), " \\\\"),
    paste0(" & (", fmt_num(row$std_error), ") \\\\")
  )
}

event_body <- c(
  " & Rating gap (notches) \\\\",
  "\\midrule",
  unlist(lapply(c(-2, -1, 0, 1, 2), event_row)),
  "\\midrule",
  paste0("Observations & ", fmt_int(event_study$nobs[1]), " \\\\"),
  paste0("Events & ", fmt_int(event_study$n_events[1]), " \\\\"),
  "Calendar-year fixed effects & Yes \\\\"
)

event_note <- paste0(
  "Two-group event study of the Moody's rating level (notches) on event-time indicators interacted with \\emph{close success}, ",
  "the common event-time path, and the close-success level, with calendar-year fixed effects and standard errors clustered by municipality. ",
  "The reference period is $h=-1$ (the election fiscal year). Positive values mean close successes hold higher ratings than close failures. ",
  "The $h=-2$ coefficient is the pre-trend test. * p $<$ 0.10, ** p $<$ 0.05, *** p $<$ 0.01."
)

write_publication_tex(
  "post_northeast_rdd_event_study_pub.tex",
  publication_table(
    "Close-Election Event Study of Moody's Rating Levels (Pre-Trend Diagnostic)",
    "tab:post_northeast_rdd_event_study",
    "lc",
    event_body,
    event_note
  )
)

# Table 4: covariate balance.
balance <- readr::read_csv(
  file.path(paths$tables, "active_operating_close_election_balance.csv"),
  show_col_types = FALSE
)
placebo <- readr::read_csv(
  file.path(paths$tables, "active_operating_close_election_placebo.csv"),
  show_col_types = FALSE
)

balance_labels <- c(
  active_variable_labels,
  moo_baseline = "Baseline Moody's rating"
)
balance <- balance |>
  dplyr::mutate(label = escape_latex_text(unname(balance_labels[variable])))

balance_body <- c(
  "Variable & Close failure & Close success & Difference & $p$-value \\\\",
  "\\midrule",
  paste0(
    balance$label, " & ",
    fmt_num(balance$mean_failure), " & ",
    fmt_num(balance$mean_success), " & ",
    fmt_num(balance$difference), " & ",
    fmt_num(balance$p_value), " \\\\"
  )
)

placebo_text <- paste0(
  "Pre-election placebo (rating change in the two years before the model year, regressed on close success): ",
  "downgrade ", fmt_num(placebo$estimate[placebo$outcome == "pre_downgrade"]),
  " (p $=$ ", fmt_num(placebo$p_value[placebo$outcome == "pre_downgrade"]), "), ",
  "upgrade ", fmt_num(placebo$estimate[placebo$outcome == "pre_upgrade"]),
  " (p $=$ ", fmt_num(placebo$p_value[placebo$outcome == "pre_upgrade"]), ")."
)

balance_note <- paste0(
  "Group means at the $\\pm 5$ percentage-point bandwidth for close successes versus close failures, with the difference and a two-sample t-test p-value. ",
  "Controls are measured at the election fiscal year. ", placebo_text, " ",
  "The baseline rating and most controls are balanced; unemployment and excess tax capacity differ across groups."
)

write_publication_tex(
  "post_northeast_rdd_balance_pub.tex",
  publication_table(
    "Close-Election Covariate Balance and Placebo Checks",
    "tab:post_northeast_rdd_balance",
    "lrrrr",
    balance_body,
    balance_note
  )
)
