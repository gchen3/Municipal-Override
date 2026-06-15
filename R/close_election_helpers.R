# Shared helpers for the close-election success-vs-failure follow-up analysis.
# This track is separate from the active workshop workflow; see
# docs/northeast_close_election_causal_analysis_plan.md.

close_election_bandwidths <- c(1, 2.5, 5, 10)
close_election_working_band <- 5

# Cumulative binary rating-change outcomes, defined against the pre-vote
# baseline. The robustness-baseline variants take the "_rb" suffix.
close_election_outcomes <- c(
  "any_downgrade_within_1yr", "any_downgrade_within_2yr",
  "any_upgrade_within_1yr", "any_upgrade_within_2yr"
)

# Operating override elections with valid vote totals and the signed yes-vote
# margin from the 50% passage threshold. Mirrors the vote-level read in R/10.
build_close_election_elections <- function() {
  purrr::map_dfr(data_65_file(override_source_files), haven::read_dta) |>
    dplyr::filter(Override == "operating") |>
    dplyr::transmute(
      code,
      fiscal_year = FiscalYear,
      total_votes = YesVotes + NoVotes,
      yes_pct = dplyr::if_else(total_votes > 0, 100 * YesVotes / total_votes, NA_real_),
      vote_margin = yes_pct - 50,
      abs_margin = abs(vote_margin),
      win = WinLoss == "WIN"
    ) |>
    dplyr::filter(!is.na(yes_pct))
}

# Collapse close elections to municipality-years under rule (a'): keep
# single-close-election years and same-direction multiples; flag mixed
# win-and-loss years (keep == FALSE) for dropping. The representative running
# variable is the margin of the election closest to the threshold.
collapse_close_muni_years <- function(elections, band) {
  elections |>
    dplyr::filter(abs_margin <= band) |>
    dplyr::group_by(code, fiscal_year) |>
    dplyr::summarise(
      n_close = dplyr::n(),
      n_win = sum(win),
      n_loss = sum(!win),
      vote_margin = vote_margin[which.min(abs_margin)],
      .groups = "drop"
    ) |>
    dplyr::mutate(
      band = band,
      model_year = fiscal_year + 1L,
      same_direction = n_win == 0 | n_loss == 0,
      keep = same_direction,
      close_success = dplyr::if_else(n_win > 0, 1, 0)
    )
}

# Named MOO_num lookup keyed by "code year"; missing keys return NA.
moo_lookup <- function(panel) {
  lookup <- panel |> dplyr::distinct(code, year, MOO_num)
  stats::setNames(lookup$MOO_num, paste(lookup$code, lookup$year))
}

rating_at <- function(moo_vec, code, year) {
  unname(moo_vec[paste(code, year)])
}

# Available-case cumulative "any" over horizon indicators: 1 if any observed
# horizon equals 1; 0 if all observed horizons are 0; NA if none observed.
cumulative_any <- function(...) {
  m <- cbind(...)
  observed <- rowSums(!is.na(m)) > 0
  any_one <- rowSums(m == 1, na.rm = TRUE) > 0
  out <- as.numeric(any_one)
  out[!observed] <- NA_real_
  out
}

# Attach cumulative downgrade/upgrade outcomes vs a baseline at
# model_year - baseline_offset (2 = pre-vote primary, 1 = election-year
# robustness). Column names take an optional suffix.
add_close_election_outcomes <- function(muni_years, moo_vec, baseline_offset = 2L, suffix = "") {
  base <- rating_at(moo_vec, muni_years$code, muni_years$model_year - baseline_offset)
  h0 <- rating_at(moo_vec, muni_years$code, muni_years$model_year)
  h1 <- rating_at(moo_vec, muni_years$code, muni_years$model_year + 1L)
  h2 <- rating_at(moo_vec, muni_years$code, muni_years$model_year + 2L)

  down <- function(h) as.numeric(h < base)
  up <- function(h) as.numeric(h > base)

  cols <- list(
    base,
    cumulative_any(down(h0), down(h1)),
    cumulative_any(down(h0), down(h1), down(h2)),
    cumulative_any(up(h0), up(h1)),
    cumulative_any(up(h0), up(h1), up(h2))
  )
  names(cols) <- paste0(
    c("moo_baseline", close_election_outcomes), suffix
  )
  dplyr::bind_cols(muni_years, tibble::as_tibble(cols))
}

# Merge active controls measured at the election fiscal year (model_year - 1),
# the last pre-outcome observation.
attach_controls <- function(muni_years, panel, control_year_offset = 1L) {
  controls <- panel |>
    dplyr::select(code, year, dplyr::all_of(active_controls))
  muni_years |>
    dplyr::mutate(control_year = model_year - control_year_offset) |>
    dplyr::left_join(controls, by = c("code", "control_year" = "year"))
}

# Event-time panel: one row per retained close election x rel_year, with the
# MOO_num level at the corresponding calendar year.
build_close_election_event_panel <- function(muni_years, moo_vec, event_times = -2:2) {
  muni_years |>
    dplyr::transmute(
      event_id = paste(code, model_year, sep = "_"),
      code, model_year, close_success, vote_margin
    ) |>
    tidyr::expand_grid(rel_year = event_times) |>
    dplyr::mutate(
      calendar_year = model_year + rel_year,
      MOO_num = rating_at(moo_vec, code, calendar_year)
    )
}
