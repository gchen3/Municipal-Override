source(file.path("R", "00_config.R"))
load_required_packages(c("dplyr", "tidyr", "purrr", "haven", "readr"))
make_output_dirs()

if (!file.exists(file.path(paths$intermediate, "data_for_regression.rds"))) {
  source(file.path("R", "02_build_regression_data.R"))
}

override_files <- c(
  "override_override.dta",
  "override_capital.dta",
  "override_debt.dta",
  "override_stable.dta"
)

override_questions <- purrr::map_dfr(
  data_65_file(override_files),
  haven::read_dta,
  .id = "source_file_id"
) |>
  dplyr::mutate(
    source_file = override_files[as.integer(source_file_id)],
    Override = as.character(Override),
    WinLoss = as.character(WinLoss),
    vote_year = FiscalYear,
    total_votes = YesVotes + NoVotes,
    approval_rate = dplyr::if_else(total_votes > 0, YesVotes / total_votes, NA_real_),
    margin = approval_rate - 0.50,
    margin_pp = 100 * margin,
    passed = as.numeric(approval_rate >= 0.50)
  ) |>
  dplyr::filter(!is.na(code), !is.na(vote_year), !is.na(margin)) |>
  dplyr::arrange(code, vote_year, VoteDate, Override, source_file, dplyr::desc(total_votes)) |>
  dplyr::group_by(code, vote_year, VoteDate, Override) |>
  dplyr::mutate(question_number = dplyr::row_number()) |>
  dplyr::ungroup() |>
  dplyr::mutate(
    question_id = paste(code, vote_year, VoteDate, Override, question_number, sep = "_")
  )

primary_questions <- override_questions |>
  dplyr::filter(Override == "operating") |>
  dplyr::group_by(code, vote_year) |>
  dplyr::slice_min(abs(margin), n = 1, with_ties = FALSE) |>
  dplyr::ungroup() |>
  dplyr::mutate(rd_sample = "operating")

all_type_questions <- override_questions |>
  dplyr::group_by(code, vote_year) |>
  dplyr::slice_min(abs(margin), n = 1, with_ties = FALSE) |>
  dplyr::ungroup() |>
  dplyr::mutate(rd_sample = "all_types")

rd_questions <- dplyr::bind_rows(primary_questions, all_type_questions)

regression_data <- readRDS(file.path(paths$intermediate, "data_for_regression.rds"))

outcome_panel <- regression_data |>
  dplyr::select(
    code, outcome_year = year, MOO_num,
    dplyr::any_of(c(
      "logpopu", "popu", "debtbudg", "unemploy", "revstab", "revperca",
      "expperca", "taxperca", "excessperca", "unabsorbedratio", "balance"
    ))
  )

predetermined_panel <- regression_data |>
  dplyr::select(
    code, vote_year = year, MOO_num,
    dplyr::any_of(c(
      "logpopu", "popu", "debtbudg", "unemploy", "revstab", "revperca",
      "expperca", "taxperca", "excessperca", "unabsorbedratio", "balance",
      "highfiscal1", "highfiscal3"
    ))
  ) |>
  dplyr::mutate(vote_year = vote_year + 1) |>
  dplyr::rename_with(~ paste0("pre_", .x), .cols = -c(code, vote_year))

horizons <- c(-5L:-1L, 1L:5L)

rd_data <- rd_questions |>
  tidyr::expand_grid(h = horizons) |>
  dplyr::mutate(outcome_year = vote_year + h) |>
  dplyr::left_join(outcome_panel, by = c("code", "outcome_year")) |>
  dplyr::left_join(predetermined_panel, by = c("code", "vote_year")) |>
  dplyr::arrange(rd_sample, code, vote_year, h)

saveRDS(rd_data, file.path(paths$intermediate, "rd_question_level_data.rds"))

validation <- dplyr::bind_rows(
  tibble::tibble(
    metric = c(
      "raw_questions",
      "question_municipalities",
      "question_min_vote_year",
      "question_max_vote_year",
      "operating_municipality_years",
      "all_type_municipality_years",
      "event_rows"
    ),
    value = as.character(c(
      nrow(override_questions),
      dplyr::n_distinct(override_questions$code),
      min(override_questions$vote_year, na.rm = TRUE),
      max(override_questions$vote_year, na.rm = TRUE),
      nrow(primary_questions),
      nrow(all_type_questions),
      nrow(rd_data)
    ))
  ),
  rd_data |>
    dplyr::group_by(rd_sample, h) |>
    dplyr::summarise(
      value = as.character(sum(!is.na(MOO_num))),
      .groups = "drop"
    ) |>
    dplyr::mutate(metric = paste0("nonmissing_moodys_", rd_sample, "_h", h)) |>
    dplyr::select(metric, value)
)

readr::write_csv(validation, file.path(paths$intermediate, "rd_data_validation.csv"))
