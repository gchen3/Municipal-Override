# Helpers for the Cumulative Stacked DiD follow-up.
# See docs/post_northeast_stacked_did_improvement_plan.md. This track reuses the
# R/11 repeated-event stacks but defines RDD-comparable cumulative outcomes.

cumulative_stacked_outcomes <- c(
  "cum_downgrade_within_0", "cum_downgrade_within_1", "cum_downgrade_within_2",
  "cum_upgrade_within_0", "cum_upgrade_within_1", "cum_upgrade_within_2"
)

# Available-case cumulative "any": 1 if any observed horizon is 1, 0 if all
# observed are 0, NA if none observed (e.g. missing baseline).
cum_any <- function(...) {
  m <- cbind(...)
  observed <- rowSums(!is.na(m)) > 0
  out <- as.numeric(rowSums(m == 1, na.rm = TRUE) > 0)
  out[!observed] <- NA_real_
  out
}

# Collapse a stack to one row per (stack_id, code) and build cumulative
# downgrade/upgrade outcomes vs the rel_year == -2 baseline, plus the
# t-1-vs-t-2 pre-period change indicators for the placebo.
add_stacked_cumulative_outcomes <- function(stack) {
  collapsed <- stack |>
    dplyr::group_by(stack_id, code) |>
    dplyr::summarise(
      treated_event = dplyr::first(treated_event),
      moo_m2 = MOO_num[rel_year == -2][1],
      moo_m1 = MOO_num[rel_year == -1][1],
      moo_0 = MOO_num[rel_year == 0][1],
      moo_1 = MOO_num[rel_year == 1][1],
      moo_2 = MOO_num[rel_year == 2][1],
      # Pre-treatment controls at the election fiscal year (rel_year == -1),
      # matching the close-election RDD. active_controls is from active_helpers.
      dplyr::across(dplyr::all_of(active_controls), ~ .x[rel_year == -1][1]),
      .groups = "drop"
    )

  down <- function(h) as.numeric(h < collapsed$moo_m2)
  up <- function(h) as.numeric(h > collapsed$moo_m2)
  d0 <- down(collapsed$moo_0); d1 <- down(collapsed$moo_1); d2 <- down(collapsed$moo_2)
  u0 <- up(collapsed$moo_0); u1 <- up(collapsed$moo_1); u2 <- up(collapsed$moo_2)

  collapsed |>
    dplyr::mutate(
      baseline = moo_m2,
      cum_downgrade_within_0 = cum_any(d0),
      cum_downgrade_within_1 = cum_any(d0, d1),
      cum_downgrade_within_2 = cum_any(d0, d1, d2),
      cum_upgrade_within_0 = cum_any(u0),
      cum_upgrade_within_1 = cum_any(u0, u1),
      cum_upgrade_within_2 = cum_any(u0, u1, u2),
      pre_downgrade = as.numeric(moo_m1 < moo_m2),
      pre_upgrade = as.numeric(moo_m1 > moo_m2)
    )
}

# Build the fully-clean, no-override-control stacked data for one event type.
# other_type_col is failures_in_window (success events) or successes_in_window
# (failure events): treated events must have zero of the other type in window so
# the success and failure contrasts are not cross-contaminated.
build_cumulative_stacked_data <- function(stack, events, other_type_col) {
  fully_clean <- events$stack_id[events[[other_type_col]] == 0]
  stack |>
    dplyr::filter(
      stack_id %in% fully_clean,
      treated_event == 1 | control_attempts_in_window == 0
    ) |>
    add_stacked_cumulative_outcomes()
}
