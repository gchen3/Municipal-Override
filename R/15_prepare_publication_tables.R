source(file.path("R", "00_config.R"))
load_required_packages(c("dplyr", "tidyr", "purrr", "readr"))
make_output_dirs()
source(file.path("R", "active_helpers.R"))

publication_table_dir <- file.path(paths$tables, "publication")
dir.create(publication_table_dir, recursive = TRUE, showWarnings = FALSE)

active_models <- readRDS(file.path(paths$intermediate, "active_operating_mundlak_models.rds"))
did_main <- readr::read_csv(
  file.path(paths$tables, "active_operating_repeated_event_binary_did_main.csv"),
  show_col_types = FALSE
)

escape_latex_text <- function(x) {
  x <- gsub("\\", "\\textbackslash{}", x, fixed = TRUE)
  x <- gsub("&", "\\&", x, fixed = TRUE)
  x <- gsub("%", "\\%", x, fixed = TRUE)
  x
}

control_note <- paste(
  escape_latex_text(active_variable_labels[active_controls]),
  collapse = "; "
)

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

coef_rows_for_terms <- function(fits, terms, labels) {
  purrr::map2_dfr(
    terms,
    labels,
    function(term, label) {
      stats <- purrr::map_dfr(fits, coef_row, term = term)
      dplyr::tibble(
        label = label,
        estimates = list(paste0(fmt_num(stats$estimate), stars(stats$p_value))),
        standard_errors = list(paste0("(", fmt_num(stats$std_error), ")"))
      )
    }
  )
}

diagonal_treatment_rows <- function(rows) {
  purrr::pmap_dfr(
    list(rows$label, rows$estimate, rows$std_error, rows$p_value, seq_len(nrow(rows))),
    function(label, estimate, std_error, p_value, column_index) {
      estimates <- rep("", nrow(rows))
      standard_errors <- rep("", nrow(rows))
      estimates[column_index] <- paste0(fmt_num(estimate), stars(p_value))
      standard_errors[column_index] <- paste0("(", fmt_num(std_error), ")")
      dplyr::tibble(
        label = label,
        estimates = list(estimates),
        standard_errors = list(standard_errors)
      )
    }
  )
}

coefficient_body_lines <- function(fits, treatment_rows) {
  control_rows <- coef_rows_for_terms(
    fits,
    active_controls,
    escape_latex_text(active_variable_labels[active_controls])
  )

  dplyr::bind_rows(treatment_rows, control_rows) |>
    dplyr::mutate(
      estimate_line = paste0(label, " & ", vapply(estimates, paste, character(1), collapse = " & "), " \\\\"),
      se_line = paste0(" & ", vapply(standard_errors, paste, character(1), collapse = " & "), " \\\\")
    ) |>
    tidyr::pivot_longer(
      cols = c(estimate_line, se_line),
      values_to = "line"
    ) |>
    dplyr::pull(line)
}

stats_rows <- function(rows, include_mundlak = FALSE, include_muni_fe = FALSE, include_year_fe = TRUE) {
  yes_row <- function(label) paste0(label, " & ", paste(rep("Yes", nrow(rows)), collapse = " & "), " \\\\")
  c(
    paste0("Observations & ", paste(fmt_int(rows$nobs), collapse = " & "), " \\\\"),
    paste0("Municipalities & ", paste(fmt_int(rows$n_municipalities), collapse = " & "), " \\\\"),
    if (include_mundlak) yes_row("Mundlak means"),
    if (include_muni_fe) yes_row("Municipality fixed effects"),
    if (include_year_fe) yes_row("Year indicators")
  )
}

moodys_note <- paste0(
  "The dependent variable is Moody's ordered municipal credit rating. ",
  "Models are ordered probit regressions. Ordered-probit cutpoints are omitted. ",
  "All columns include the listed controls. ",
  "Standard errors in parentheses are clustered by municipality. ",
  "Moody's complete-case years are 2003--2015, 2017, and 2019--2021. ",
  "* p $<$ 0.10, ** p $<$ 0.05, *** p $<$ 0.01."
)

vote_share_note <- paste0(
  "The dependent variable is operating override yes-vote percentage. ",
  "Models are linear fixed-effects regressions. All columns include the listed controls. ",
  "Standard errors in parentheses are clustered by municipality. ",
  "Complete-case years are 2003--2021. ",
  "* p $<$ 0.10, ** p $<$ 0.05, *** p $<$ 0.01."
)

write_three_model_table <- function(file_name, caption, label, rows, fits, dependent_variable_label, note,
                                    include_mundlak = FALSE, include_muni_fe = FALSE,
                                    include_year_fe = TRUE) {
  treatment_rows <- diagonal_treatment_rows(rows)

  body <- c(
    paste0(" & \\multicolumn{3}{c}{", dependent_variable_label, "} \\\\"),
    "\\cmidrule(lr){2-4}",
    " & (1) & (2) & (3) \\\\",
    "\\midrule",
    coefficient_body_lines(fits, treatment_rows),
    "\\midrule",
    stats_rows(
      rows,
      include_mundlak = include_mundlak,
      include_muni_fe = include_muni_fe,
      include_year_fe = include_year_fe
    )
  )

  write_publication_tex(
    file_name,
    publication_table(caption, label, "lccc", body, note)
  )
}

moodys_specs <- dplyr::tibble(
  model = c("attempt", "success", "failure"),
  term = c("oper_binary", "oper_binary_win", "oper_binary_fail"),
  label = c("Override attempt", "Successful override", "Failed override")
)

moodys_rows <- moodys_specs |>
  dplyr::mutate(stats = purrr::map2(model, term, ~ coef_row(active_models$fits$moodys_main[[.x]], .y))) |>
  tidyr::unnest(stats)

write_three_model_table(
  "northeast_moodys_main_pub.tex",
  "Operating Overrides and Moody's Ratings",
  "tab:northeast_moodys_main",
  moodys_rows,
  active_models$fits$moodys_main[moodys_specs$model],
  "Moody's credit rating",
  moodys_note,
  include_mundlak = TRUE
)

moodys_frequency_specs <- dplyr::tibble(
  model = c("attempt_cumu_3yr", "success_cumu_3yr", "failure_cumu_3yr"),
  term = c("oper_attempt_cumu_3yr", "oper_success_cumu_3yr", "oper_failure_cumu_3yr"),
  label = c(
    "3-year override attempts",
    "3-year successful overrides",
    "3-year failed overrides"
  )
)

moodys_frequency_rows <- moodys_frequency_specs |>
  dplyr::mutate(stats = purrr::map2(model, term, ~ coef_row(active_models$fits$moodys_frequency[[.x]], .y))) |>
  tidyr::unnest(stats)

write_three_model_table(
  "northeast_moodys_frequency_pub.tex",
  "Override Frequency and Moody's Ratings",
  "tab:northeast_moodys_frequency",
  moodys_frequency_rows,
  active_models$fits$moodys_frequency[moodys_frequency_specs$model],
  "Moody's credit rating",
  moodys_note,
  include_mundlak = TRUE
)

vote_specs <- dplyr::tibble(
  model = c(
    "attempt_count", "success_count", "failure_count",
    "attempt_cumu_3yr", "success_cumu_3yr", "failure_cumu_3yr"
  ),
  term = c(
    "oper_attempt_count", "oper_success_count", "oper_failure_count",
    "oper_attempt_cumu_3yr", "oper_success_cumu_3yr", "oper_failure_cumu_3yr"
  ),
  label = c(
    "Annual override attempts",
    "Annual successful overrides",
    "Annual failed overrides",
    "3-year override attempts",
    "3-year successful overrides",
    "3-year failed overrides"
  )
)

vote_rows <- vote_specs |>
  dplyr::mutate(stats = purrr::map2(model, term, ~ coef_row(active_models$fits$vote_share_main[[.x]], .y))) |>
  tidyr::unnest(stats)

write_three_model_table(
  "northeast_vote_share_annual_pub.tex",
  "Annual Override Frequency and Yes-Vote Percentage",
  "tab:northeast_vote_share_annual",
  dplyr::filter(vote_rows, model %in% c("attempt_count", "success_count", "failure_count")),
  active_models$fits$vote_share_main[c("attempt_count", "success_count", "failure_count")],
  "Yes-vote percentage",
  vote_share_note,
  include_muni_fe = TRUE
)

write_three_model_table(
  "northeast_vote_share_cumulative_pub.tex",
  "Three-Year Override Frequency and Yes-Vote Percentage",
  "tab:northeast_vote_share_cumulative",
  dplyr::filter(vote_rows, model %in% c("attempt_cumu_3yr", "success_cumu_3yr", "failure_cumu_3yr")),
  active_models$fits$vote_share_main[c("attempt_cumu_3yr", "success_cumu_3yr", "failure_cumu_3yr")],
  "Yes-vote percentage",
  vote_share_note,
  include_muni_fe = TRUE
)

did_publication_rows <- did_main |>
  dplyr::filter(event_time != -1) |>
  dplyr::mutate(
    event = event_table_labels[event_type],
    outcome_label = did_outcome_labels[outcome],
    event_time_label = paste0("$h=", event_time, "$"),
    estimate_cell = paste0(fmt_num(estimate), stars(p_value)),
    se_cell = paste0("(", fmt_num(std_error), ")")
  )

did_note <- paste0(
  "Models are repeated-event linear probability models using the window-clean preferred specification. ",
  "The omitted reference period is $h=-1$. The event window is $h=-2$ to $h=2$. ",
  "The comparison pool is window-clean controls. Models include stack-by-municipality and stack-by-year fixed effects, ",
  "with no additional covariates. Standard errors in parentheses are clustered by municipality. ",
  "* p $<$ 0.10, ** p $<$ 0.05, *** p $<$ 0.01."
)

did_sample_rows <- function(rows) {
  metadata <- rows |>
    dplyr::distinct(event, nobs, n_municipalities, n_stacks) |>
    dplyr::arrange(match(event, unname(event_table_labels)))

  c(
    paste0("Observations & ", paste(fmt_int(metadata$nobs), collapse = " & "), " \\\\"),
    paste0("Municipalities & ", paste(fmt_int(metadata$n_municipalities), collapse = " & "), " \\\\"),
    paste0("Stacks & ", paste(fmt_int(metadata$n_stacks), collapse = " & "), " \\\\"),
    paste0("Stack-by-municipality fixed effects & ", paste(rep("Yes", nrow(metadata)), collapse = " & "), " \\\\"),
    paste0("Stack-by-year fixed effects & ", paste(rep("Yes", nrow(metadata)), collapse = " & "), " \\\\"),
    paste0("Covariates & ", paste(rep("No", nrow(metadata)), collapse = " & "), " \\\\")
  )
}

write_did_publication_table <- function(outcome_label, file_name, caption, label) {
  rows <- did_publication_rows |>
    dplyr::filter(.data$outcome_label == .env$outcome_label)

  wide_rows <- rows |>
    dplyr::select(event, event_time_label, estimate_cell, se_cell) |>
    tidyr::pivot_wider(
      names_from = event_time_label,
      values_from = c(estimate_cell, se_cell)
    ) |>
    dplyr::arrange(match(event, unname(event_table_labels)))

  body <- c(
    paste0(" & \\multicolumn{3}{c}{Rating ", tolower(outcome_label), "} \\\\"),
    "\\cmidrule(lr){2-4}",
    " & Attempt & Success & Failure \\\\",
    "\\midrule",
    paste0("$h=-2$ & ", paste(wide_rows[["estimate_cell_$h=-2$"]], collapse = " & "), " \\\\"),
    paste0(" & ", paste(wide_rows[["se_cell_$h=-2$"]], collapse = " & "), " \\\\"),
    paste0("$h=0$ & ", paste(wide_rows[["estimate_cell_$h=0$"]], collapse = " & "), " \\\\"),
    paste0(" & ", paste(wide_rows[["se_cell_$h=0$"]], collapse = " & "), " \\\\"),
    paste0("$h=1$ & ", paste(wide_rows[["estimate_cell_$h=1$"]], collapse = " & "), " \\\\"),
    paste0(" & ", paste(wide_rows[["se_cell_$h=1$"]], collapse = " & "), " \\\\"),
    paste0("$h=2$ & ", paste(wide_rows[["estimate_cell_$h=2$"]], collapse = " & "), " \\\\"),
    paste0(" & ", paste(wide_rows[["se_cell_$h=2$"]], collapse = " & "), " \\\\"),
    "\\midrule",
    did_sample_rows(rows)
  )

  write_publication_tex(
    file_name,
    publication_table(caption, label, "lccc", body, did_note)
  )
}

write_did_publication_table(
  "Downgrade",
  "northeast_repeated_event_did_downgrade_pub.tex",
  "Repeated-Event DiD Estimates for Rating Downgrades",
  "tab:northeast_did_downgrade"
)

write_did_publication_table(
  "Upgrade",
  "northeast_repeated_event_did_upgrade_pub.tex",
  "Repeated-Event DiD Estimates for Rating Upgrades",
  "tab:northeast_did_upgrade"
)

combined_did_rows <- did_publication_rows |>
  dplyr::select(event, outcome_label, event_time_label, estimate_cell, se_cell) |>
  tidyr::pivot_wider(
    names_from = event_time_label,
    values_from = c(estimate_cell, se_cell)
  ) |>
  dplyr::arrange(match(event, unname(event_table_labels)), match(outcome_label, unname(did_outcome_labels)))

combined_body <- c(
  "Event & Dependent variable & $h=-2$ & $h=0$ & $h=1$ & $h=2$ \\\\",
  "\\midrule",
  unlist(lapply(
    seq_len(nrow(combined_did_rows)),
    function(i) {
      row <- combined_did_rows[i, ]
      c(
        paste(
          row[["event"]],
          row[["outcome_label"]],
          row[["estimate_cell_$h=-2$"]],
          row[["estimate_cell_$h=0$"]],
          row[["estimate_cell_$h=1$"]],
          row[["estimate_cell_$h=2$"]],
          sep = " & "
        ),
        paste(
          "",
          "",
          row[["se_cell_$h=-2$"]],
          row[["se_cell_$h=0$"]],
          row[["se_cell_$h=1$"]],
          row[["se_cell_$h=2$"]],
          sep = " & "
        )
      )
    }
  )) |>
    paste0(" \\\\")
)

write_publication_tex(
  "northeast_repeated_event_did_main_pub.tex",
  publication_table(
    "Repeated-Event DiD Estimates for Rating Changes",
    "tab:northeast_did_main",
    "llcccc",
    combined_body,
    did_note,
    size = "\\footnotesize"
  )
)
