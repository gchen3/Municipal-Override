source(file.path("R", "00_config.R"))
load_required_packages(c("dplyr", "tidyr", "purrr", "haven", "readr"))
make_output_dirs()
source(file.path("R", "active_helpers.R"))
source(file.path("R", "close_election_helpers.R"))

if (!file.exists(file.path(paths$intermediate, "data_for_regression.rds"))) {
  source(file.path("R", "02_build_regression_data.R"))
}

panel <- readRDS(file.path(paths$intermediate, "data_for_regression.rds"))
elections <- build_close_election_elections()

# Verify WinLoss aligns with the sign of the vote margin before proceeding.
mismatches <- sum(
  (elections$win & elections$vote_margin <= 0) |
    (!elections$win & elections$vote_margin > 0)
)
ties <- sum(elections$vote_margin == 0)
if (mismatches > 0) {
  stop("WinLoss does not match the vote-margin sign in ", mismatches, " elections.", call. = FALSE)
}

moo_vec <- moo_lookup(panel)
available_moo_years <- sort(unique(panel$year[!is.na(panel$MOO_num)]))

collapsed <- purrr::map(close_election_bandwidths, ~ collapse_close_muni_years(elections, .x))

build_band <- function(band_collapsed) {
  band_collapsed |>
    dplyr::filter(keep) |>
    add_close_election_outcomes(moo_vec, baseline_offset = 2L, suffix = "") |>
    add_close_election_outcomes(moo_vec, baseline_offset = 1L, suffix = "_rb") |>
    attach_controls(panel, control_year_offset = 1L)
}

analysis_data <- purrr::map_dfr(collapsed, build_band)

count_outcomes <- function(df) {
  purrr::map_dfr(close_election_outcomes, function(outcome) {
    tibble::tibble(metric = paste0("n_", outcome), value = sum(!is.na(df[[outcome]])))
  })
}

band_counts <- purrr::map2_dfr(
  collapsed,
  close_election_bandwidths,
  function(band_collapsed, band) {
    kept <- analysis_data |> dplyr::filter(band == !!band)
    dplyr::bind_rows(
      tibble::tibble(
        metric = c("muni_years_with_close", "kept", "dropped_mixed"),
        value = c(nrow(band_collapsed), sum(band_collapsed$keep), sum(!band_collapsed$keep))
      ),
      count_outcomes(kept)
    ) |>
      dplyr::mutate(band = band, .before = metric)
  }
)

build_checks <- tibble::tibble(
  metric = c("operating_elections", "winloss_margin_mismatches", "exact_ties", "available_moo_years"),
  value = c(
    nrow(elections),
    mismatches,
    ties,
    paste(available_moo_years, collapse = ";")
  )
)

readr::write_csv(band_counts, file.path(paths$tables, "active_operating_close_election_counts.csv"))
readr::write_csv(build_checks, file.path(paths$tables, "active_operating_close_election_build_checks.csv"))
saveRDS(analysis_data, file.path(paths$intermediate, "active_operating_close_election_data.rds"))
