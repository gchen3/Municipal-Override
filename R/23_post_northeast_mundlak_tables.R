source(file.path("R", "00_config.R"))
load_required_packages(c("dplyr", "tidyr", "purrr", "MASS", "sandwich", "readr"))
make_output_dirs()
source(file.path("R", "active_helpers.R"))

# Post-Northeast Mundlak rating tables, kept explicitly correlational and framed
# to sit next to the stacked DiD (R/21-22) and close-election RDD (R/16-20).
# Two full-Mundlak ordered-probit tables, identical in structure, differing only
# in the rating horizon: the Moody's rating in the override year (t) and one year
# later (t+1). Treatment terms are harmonized to the DiD/RDD framing (any
# override, then the success/failure decomposition). Each override definition is
# a separate model shown in its own column with its own control coefficients.
if (!file.exists(file.path(paths$intermediate, "data_for_regression.rds"))) {
  source(file.path("R", "02_build_regression_data.R"))
}
dfr <- readRDS(file.path(paths$intermediate, "data_for_regression.rds"))

# Lead the rating within municipality for the t+1 horizon.
lead_panel <- function(x, year, n = 1L) {
  lead_x <- dplyr::lead(x, n)
  lead_year <- dplyr::lead(year, n)
  dplyr::if_else(lead_year - year == n, lead_x, NA_real_)
}
dfr <- dfr |>
  dplyr::arrange(code, year) |>
  dplyr::group_by(code) |>
  dplyr::mutate(MOO_lead1 = lead_panel(MOO_ordered, year, 1)) |>
  dplyr::ungroup()

# Harmonized treatment terms: any override (= attempt), then success / failure.
treatment_var <- c(
  "Any override" = "oper_binary",
  "Successful override" = "oper_binary_win",
  "Failed override" = "oper_binary_fail"
)

# Mundlak municipality means available for a given main term plus the controls.
mundlak_con <- function(term) {
  candidates <- paste0(c(term, active_controls), "con")
  unique(candidates[candidates %in% names(dfr)])
}

# Full-Mundlak right-hand side: override term + controls + Mundlak means.
mundlak_terms <- function(term) c(term, active_controls, mundlak_con(term))

fit_ordered_on <- function(outcome, term_set) {
  fit_ordered_probit(rhs_formula(outcome, term_set, include_year = TRUE), dfr)
}

# One full-Mundlak model per override definition, at a given rating horizon.
fit_models <- function(outcome) {
  setNames(
    lapply(treatment_var, function(term) fit_ordered_on(outcome, mundlak_terms(term))),
    names(treatment_var)
  )
}
fits_t <- fit_models("MOO_ordered")
fits_t1 <- fit_models("MOO_lead1")

# --- LaTeX helpers (local, mirroring R/20 / R/22) ---------------------------
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

# Formatted (estimate, SE) for a term in one fit, or blank if the term is absent.
safe_cell <- function(fit, term) {
  coefs <- stats::coef(fit$model)
  if (!term %in% names(coefs)) return(list(est = "", se = ""))
  r <- coef_row(fit, term)
  list(est = paste0(fmt_num(r$estimate), stars(r$p_value)), se = paste0("(", fmt_num(r$std_error), ")"))
}

# A label row (estimate line + SE line) for `term` across an ordered list of fits.
term_row <- function(label, fits, term) {
  cells <- lapply(fits, safe_cell, term = term)
  est <- vapply(cells, `[[`, character(1), "est")
  se <- vapply(cells, `[[`, character(1), "se")
  c(
    paste0(escape_latex_text(label), " & ", paste(est, collapse = " & "), " \\\\"),
    paste0(" & ", paste(se, collapse = " & "), " \\\\")
  )
}

# Diagonal treatment rows: each override coefficient appears only in its own
# column (its own model); the other columns are blank in that row.
diagonal_treatment_rows <- function(fits) {
  labels <- names(fits)
  unlist(lapply(seq_along(labels), function(i) {
    cell <- safe_cell(fits[[i]], treatment_var[[labels[i]]])
    est <- se <- rep("", length(labels))
    est[i] <- cell$est
    se[i] <- cell$se
    c(
      paste0(escape_latex_text(labels[i]), " & ", paste(est, collapse = " & "), " \\\\"),
      paste0(" & ", paste(se, collapse = " & "), " \\\\")
    )
  }))
}

# Control coefficient rows: each control across the three models (own coef).
control_rows <- function(fits) {
  unlist(lapply(active_controls, function(v) term_row(unname(active_variable_labels[[v]]), fits, v)))
}

mundlak_table_body <- function(fits) {
  nobs <- vapply(names(fits), function(l) fmt_int(coef_row(fits[[l]], treatment_var[[l]])$nobs), character(1))
  nmun <- vapply(names(fits), function(l) fmt_int(coef_row(fits[[l]], treatment_var[[l]])$n_municipalities), character(1))
  c(
    " & \\multicolumn{3}{c}{Moody's credit rating} \\\\",
    "\\cmidrule(lr){2-4}",
    " & (1) & (2) & (3) \\\\",
    "\\midrule",
    diagonal_treatment_rows(fits),
    "\\midrule",
    control_rows(fits),
    "\\midrule",
    "Mundlak means & Yes & Yes & Yes \\\\",
    "Year indicators & Yes & Yes & Yes \\\\",
    paste0("Observations & ", paste(nobs, collapse = " & "), " \\\\"),
    paste0("Municipalities & ", paste(nmun, collapse = " & "), " \\\\")
  )
}

base_note <- paste0(
  "Each column is a separate full-Mundlak ordered-probit regression on one override definition, with the fiscal controls (",
  escape_latex_text(paste(active_variable_labels[active_controls], collapse = "; ")),
  "), Mundlak municipality means of the override term and controls, and year indicators; ordered-probit cutpoints are omitted and a higher rating is better. ",
  "The override coefficient appears in its own column. Control coefficients are model adjustment terms and are not to be interpreted causally -- for example the unemployment coefficient turns positive only after conditioning on the revenue controls and year effects, whereas its raw correlation with the rating is negative. ",
  "Any override association is cross-sectional, not causal: the stacked DiD (override vs.\\ no override) and the close-election RDD find no effect of overrides on near-term rating changes. ",
  "Standard errors in parentheses are clustered by municipality. * p $<$ 0.10, ** p $<$ 0.05, *** p $<$ 0.01."
)

write_publication_tex(
  "post_northeast_mundlak_rating_t_pub.tex",
  publication_table(
    "Operating Overrides and Moody's Ratings (Full Mundlak Specification)",
    "tab:post_northeast_mundlak_rating_t",
    "lccc",
    mundlak_table_body(fits_t),
    paste0("The dependent variable is the Moody's rating in the override year ($t$). ", base_note)
  )
)

write_publication_tex(
  "post_northeast_mundlak_rating_t1_pub.tex",
  publication_table(
    "Operating Overrides and the Moody's Rating One Year Later",
    "tab:post_northeast_mundlak_rating_t1",
    "lccc",
    mundlak_table_body(fits_t1),
    paste0("The dependent variable is the Moody's rating one year after the override year ($t+1$), so the association is not confined to the override year. ", base_note)
  )
)
