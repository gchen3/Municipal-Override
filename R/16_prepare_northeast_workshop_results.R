source(file.path("R", "00_config.R"))
load_required_packages(c("dplyr", "tidyr", "purrr", "readr"))
make_output_dirs()

active_models <- readRDS(file.path(paths$intermediate, "active_operating_mundlak_models.rds"))
did_main <- readr::read_csv(
  file.path(paths$tables, "active_operating_repeated_event_binary_did_main.csv"),
  show_col_types = FALSE
)
sample_counts <- readr::read_csv(
  file.path(paths$tables, "active_operating_repeated_event_sample_counts.csv"),
  show_col_types = FALSE
)

stars <- function(p_value) {
  dplyr::case_when(
    is.na(p_value) ~ "",
    p_value < 0.01 ~ "***",
    p_value < 0.05 ~ "**",
    p_value < 0.10 ~ "*",
    TRUE ~ ""
  )
}

fmt_num <- function(x, digits = 3) {
  x <- ifelse(abs(x) < 0.5 * 10^-digits, 0, x)
  ifelse(is.na(x), "", formatC(x, format = "f", digits = digits))
}

fmt_int <- function(x) {
  formatC(as.integer(round(x)), format = "d", big.mark = ",")
}

coef_row <- function(fit, term) {
  estimate <- unname(stats::coef(fit$model)[[term]])
  std_error <- sqrt(diag(fit$vcov))[[term]]
  p_value <- 2 * stats::pnorm(abs(estimate / std_error), lower.tail = FALSE)

  dplyr::tibble(
    estimate = estimate,
    std_error = std_error,
    p_value = p_value,
    nobs = nrow(fit$data),
    n_municipalities = dplyr::n_distinct(fit$data$code)
  )
}

write_tex <- function(file_name, lines) {
  writeLines(lines, file.path(paths$tables, file_name), useBytes = TRUE)
}

cell_with_se <- function(estimate, std_error, p_value) {
  paste0(fmt_num(estimate), stars(p_value), " (", fmt_num(std_error), ")")
}

moodys_specs <- dplyr::tibble(
  model = c("attempt", "success", "failure"),
  term = c("oper_binary", "oper_binary_win", "oper_binary_fail"),
  label = c("Attempt", "Success", "Failure")
)

moodys_rows <- moodys_specs |>
  dplyr::mutate(stats = purrr::map2(model, term, ~ coef_row(active_models$fits$moodys_main[[.x]], .y))) |>
  tidyr::unnest(stats)

write_tex(
  "northeast_moodys_main.tex",
  c(
    "\\begin{center}",
    "\\scriptsize",
    "\\begin{tabular}{lccc}",
    "\\toprule",
    paste0(" & ", paste(moodys_rows$label, collapse = " & "), " \\\\"),
    "\\midrule",
    paste0(
      "Override term & ",
      paste(cell_with_se(moodys_rows$estimate, moodys_rows$std_error, moodys_rows$p_value), collapse = " & "),
      " \\\\"
    ),
    paste0("Observations & ", paste(fmt_int(moodys_rows$nobs), collapse = " & "), " \\\\"),
    paste0(
      "Municipalities & ",
      paste(fmt_int(moodys_rows$n_municipalities), collapse = " & "),
      " \\\\"
    ),
    "Controls, Mundlak means & Yes & Yes & Yes \\\\",
    "Year indicators & Yes & Yes & Yes \\\\",
    "\\bottomrule",
    "\\end{tabular}",
    "\\vspace{0.05cm}",
    "\\parbox{0.94\\textwidth}{\\tiny Ordered probit models for Moody's ordered rating outcome. Standard errors in parentheses are clustered by municipality. Moody's complete-case years are 2003--2015, 2017, and 2019--2021. * p $<$ 0.10, ** p $<$ 0.05, *** p $<$ 0.01.}",
    "\\end{center}"
  )
)

moodys_frequency_specs <- dplyr::tibble(
  model = c("attempt_cumu_3yr", "success_cumu_3yr", "failure_cumu_3yr"),
  term = c("oper_attempt_cumu_3yr", "oper_success_cumu_3yr", "oper_failure_cumu_3yr"),
  label = c("3-year attempt", "3-year success", "3-year failure")
)

moodys_frequency_rows <- moodys_frequency_specs |>
  dplyr::mutate(stats = purrr::map2(model, term, ~ coef_row(active_models$fits$moodys_frequency[[.x]], .y))) |>
  tidyr::unnest(stats)

write_tex(
  "northeast_moodys_frequency.tex",
  c(
    "\\begin{center}",
    "\\scriptsize",
    "\\begin{tabular}{lccc}",
    "\\toprule",
    paste0(" & ", paste(moodys_frequency_rows$label, collapse = " & "), " \\\\"),
    "\\midrule",
    paste0(
      "Frequency term & ",
      paste(cell_with_se(moodys_frequency_rows$estimate, moodys_frequency_rows$std_error, moodys_frequency_rows$p_value), collapse = " & "),
      " \\\\"
    ),
    paste0("Observations & ", paste(fmt_int(moodys_frequency_rows$nobs), collapse = " & "), " \\\\"),
    paste0(
      "Municipalities & ",
      paste(fmt_int(moodys_frequency_rows$n_municipalities), collapse = " & "),
      " \\\\"
    ),
    "Controls, Mundlak means & Yes & Yes & Yes \\\\",
    "Year indicators & Yes & Yes & Yes \\\\",
    "\\bottomrule",
    "\\end{tabular}",
    "\\vspace{0.05cm}",
    "\\parbox{0.94\\textwidth}{\\tiny Ordered probit models for Moody's ordered rating outcome using three-year cumulative operating override counts. Standard errors in parentheses are clustered by municipality. Moody's complete-case years are 2003--2015, 2017, and 2019--2021. * p $<$ 0.10, ** p $<$ 0.05, *** p $<$ 0.01.}",
    "\\end{center}"
  )
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
  label = c("Annual attempt", "Annual success", "Annual failure", "3-year attempt", "3-year success", "3-year failure")
)

vote_rows <- vote_specs |>
  dplyr::mutate(stats = purrr::map2(model, term, ~ coef_row(active_models$fits$vote_share_main[[.x]], .y))) |>
  tidyr::unnest(stats)

write_vote_share_table <- function(rows, filename, note) {
  write_tex(
    filename,
    c(
      "\\begin{center}",
      "\\scriptsize",
      "\\begin{tabular}{lccc}",
      "\\toprule",
      paste0(" & ", paste(rows$label, collapse = " & "), " \\\\"),
      "\\midrule",
      paste0(
        "Frequency term & ",
        paste(cell_with_se(rows$estimate, rows$std_error, rows$p_value), collapse = " & "),
        " \\\\"
      ),
      paste0("Observations & ", paste(fmt_int(rows$nobs), collapse = " & "), " \\\\"),
      paste0(
        "Municipalities & ",
        paste(fmt_int(rows$n_municipalities), collapse = " & "),
        " \\\\"
      ),
      "Municipality FE & Yes & Yes & Yes \\\\",
      "Year FE & Yes & Yes & Yes \\\\",
      "\\bottomrule",
      "\\end{tabular}",
      "\\vspace{0.05cm}",
      paste0(
        "\\parbox{0.94\\textwidth}{\\tiny ",
        note,
        " Standard errors in parentheses are clustered by municipality. Complete-case years are 2003--2021. * p $<$ 0.10, ** p $<$ 0.05, *** p $<$ 0.01.}"
      ),
      "\\end{center}"
    )
  )
}

write_vote_share_table(
  dplyr::filter(vote_rows, model %in% c("attempt_count", "success_count", "failure_count")),
  "northeast_vote_share_annual.tex",
  "Linear fixed-effects models for annual operating yes-vote percentage using annual operating override counts."
)

write_vote_share_table(
  dplyr::filter(vote_rows, model %in% c("attempt_cumu_3yr", "success_cumu_3yr", "failure_cumu_3yr")),
  "northeast_vote_share_cumulative.tex",
  "Linear fixed-effects models for annual operating yes-vote percentage using three-year cumulative operating override counts."
)

count_metrics <- c(
  focal_event_years = "Focal event years",
  municipalities_with_focal_event = "Event municipalities",
  clean_treatment_events = "Clean events",
  clean_treated_municipalities = "Clean municipalities"
)

control_metrics <- c(
  control_event_municipality_pairs = "Window-clean control pairs",
  unique_control_municipalities = "Window-clean control municipalities"
)

event_labels <- c(
  operating_attempt = "Attempt",
  operating_success = "Success",
  operating_failure = "Failure"
)

overall_counts <- sample_counts |>
  dplyr::filter(sample == "overall", group == "all", metric %in% names(count_metrics)) |>
  dplyr::mutate(metric = count_metrics[metric])

control_counts <- sample_counts |>
  dplyr::filter(sample == "window_clean", group == "control", metric %in% names(control_metrics)) |>
  dplyr::mutate(metric = control_metrics[metric])

counts_wide <- dplyr::bind_rows(overall_counts, control_counts) |>
  dplyr::mutate(event = event_labels[event_type]) |>
  dplyr::select(event, metric, value) |>
  tidyr::pivot_wider(names_from = metric, values_from = value) |>
  dplyr::arrange(match(event, unname(event_labels)))

write_tex(
  "northeast_repeated_event_counts.tex",
  c(
    "\\begin{center}",
    "\\scriptsize",
    "\\resizebox{0.98\\textwidth}{!}{%",
    "\\begin{tabular}{lrrrrrr}",
    "\\toprule",
    "Event & Focal yrs & Event munis. & Clean evts & Clean munis. & Ctrl pairs & Ctrl munis. \\\\",
    "\\midrule",
    apply(
      counts_wide,
      1,
      \(row) paste(
        row[["event"]],
        fmt_int(as.numeric(row[["Focal event years"]])),
        fmt_int(as.numeric(row[["Event municipalities"]])),
        fmt_int(as.numeric(row[["Clean events"]])),
        fmt_int(as.numeric(row[["Clean municipalities"]])),
        fmt_int(as.numeric(row[["Window-clean control pairs"]])),
        fmt_int(as.numeric(row[["Window-clean control municipalities"]])),
        sep = " & "
      )
    ) |>
      paste0(" \\\\"),
    "\\bottomrule",
    "\\end{tabular}",
    "}",
    "\\vspace{0.05cm}",
    "\\parbox{0.94\\textwidth}{\\tiny Clean treated events have no same-type event inside the local event window. The comparison pool is window-clean controls. Event years are 2005--2019; stacked panel years are 2003--2021.}",
    "\\end{center}"
  )
)

did_labels <- c(
  rating_downgrade = "Downgrade",
  rating_upgrade = "Upgrade"
)

did_rows <- did_main |>
  dplyr::filter(event_time != -1) |>
  dplyr::mutate(
    event = event_labels[event_type],
    outcome_label = did_labels[outcome],
    event_time = paste0("$h=", event_time, "$"),
    cell = cell_with_se(estimate, std_error, p_value)
  ) |>
  dplyr::select(event, outcome_label, event_time, cell) |>
  tidyr::pivot_wider(names_from = event_time, values_from = cell) |>
  dplyr::arrange(match(event, unname(event_labels)), match(outcome_label, unname(did_labels)))

write_tex(
  "northeast_repeated_event_did_main.tex",
  c(
    "\\begin{center}",
    "\\tiny",
    "\\begin{tabular}{llcccc}",
    "\\toprule",
    "Event & Outcome & $h=-2$ & $h=0$ & $h=1$ & $h=2$ \\\\",
    "\\midrule",
    apply(
      did_rows,
      1,
      \(row) paste(
        row[["event"]],
        row[["outcome_label"]],
        row[["$h=-2$"]],
        row[["$h=0$"]],
        row[["$h=1$"]],
        row[["$h=2$"]],
        sep = " & "
      )
    ) |>
      paste0(" \\\\"),
    "\\bottomrule",
    "\\end{tabular}",
    "\\vspace{0.05cm}",
    "\\parbox{0.94\\textwidth}{\\tiny Repeated-event linear probability models with stack-by-municipality and stack-by-year fixed effects. Coefficients are relative to $h=-1$; standard errors in parentheses are clustered by municipality. * p $<$ 0.10, ** p $<$ 0.05, *** p $<$ 0.01.}",
    "\\end{center}"
  )
)

write_did_outcome_table <- function(outcome_label, file_name) {
  rows <- did_rows |>
    dplyr::filter(.data$outcome_label == .env$outcome_label)

  write_tex(
    file_name,
    c(
      "\\begin{center}",
      "\\scriptsize",
      "\\begin{tabular}{lcccc}",
      "\\toprule",
      "Event & $h=-2$ & $h=0$ & $h=1$ & $h=2$ \\\\",
      "\\midrule",
      apply(
        rows,
        1,
        \(row) paste(
          row[["event"]],
          row[["$h=-2$"]],
          row[["$h=0$"]],
          row[["$h=1$"]],
          row[["$h=2$"]],
          sep = " & "
        )
      ) |>
        paste0(" \\\\"),
      "\\bottomrule",
      "\\end{tabular}",
      "\\vspace{0.05cm}",
      paste0(
        "\\parbox{0.94\\textwidth}{\\tiny Repeated-event linear probability models for ",
        tolower(outcome_label),
        " outcomes with stack-by-municipality and stack-by-year fixed effects. Coefficients are relative to $h=-1$; standard errors in parentheses are clustered by municipality. * p $<$ 0.10, ** p $<$ 0.05, *** p $<$ 0.01.}"
      ),
      "\\end{center}"
    )
  )
}

write_did_outcome_table("Downgrade", "northeast_repeated_event_did_downgrade.tex")
write_did_outcome_table("Upgrade", "northeast_repeated_event_did_upgrade.tex")
