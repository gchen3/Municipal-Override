source(file.path("R", "00_config.R"))
load_required_packages(c("dplyr", "tidyr", "purrr", "fixest", "sandwich", "readr"))
make_output_dirs()
source(file.path("R", "active_helpers.R"))
source(file.path("R", "close_election_helpers.R"))

if (!file.exists(file.path(paths$intermediate, "active_operating_close_election_data.rds"))) {
  source(file.path("R", "16_build_close_election_data.R"))
}

analysis_data <- readRDS(file.path(paths$intermediate, "active_operating_close_election_data.rds"))

# Linear probability models: close_success coefficient = change in the
# probability of the rating-change outcome, with model-year fixed effects and
# municipality-clustered standard errors.
lpm_specs <- list(
  lpm_bare = function(outcome) {
    stats::as.formula(paste(outcome, "~ close_success | model_year"))
  },
  lpm_controls = function(outcome) {
    stats::as.formula(paste(
      outcome, "~", paste(c("close_success", active_controls), collapse = " + "),
      "| model_year"
    ))
  },
  lpm_local_linear = function(outcome) {
    stats::as.formula(paste(
      outcome, "~",
      paste(c("close_success", "vote_margin", "close_success:vote_margin", active_controls), collapse = " + "),
      "| model_year"
    ))
  }
)

extract_close_success <- function(model, vcov_matrix, nobs, n_clusters) {
  coefs <- stats::coef(model)
  if (!"close_success" %in% names(coefs)) {
    return(tibble::tibble(
      estimate = NA_real_, std_error = NA_real_, p_value = NA_real_,
      nobs = nobs, n_clusters = n_clusters
    ))
  }
  estimate <- unname(coefs[["close_success"]])
  std_error <- sqrt(diag(vcov_matrix))[["close_success"]]
  tibble::tibble(
    estimate = estimate,
    std_error = std_error,
    p_value = 2 * stats::pnorm(abs(estimate / std_error), lower.tail = FALSE),
    nobs = nobs,
    n_clusters = n_clusters
  )
}

fit_lpm <- function(data, outcome, spec_name, formula_fun) {
  fit <- tryCatch(fit_fe_lm(formula_fun(outcome), data), error = function(e) e)
  if (inherits(fit, "error")) {
    return(tibble::tibble(
      spec = spec_name, outcome = outcome, estimate = NA_real_, std_error = NA_real_,
      p_value = NA_real_, nobs = 0L, n_clusters = 0L, ame = NA_real_,
      note = conditionMessage(fit)
    ))
  }
  extract_close_success(
    fit$model, fit$vcov, nrow(fit$data), dplyr::n_distinct(fit$data$code)
  ) |>
    dplyr::mutate(spec = spec_name, outcome = outcome, ame = NA_real_, note = NA_character_, .before = estimate)
}

# Probit robustness at the working bandwidth, without year fixed effects to
# avoid separation on rare outcomes. Report the coefficient (clustered) and the
# average marginal effect of close_success.
fit_probit_robustness <- function(data, outcome) {
  formula <- stats::as.formula(paste(
    outcome, "~", paste(c("close_success", active_controls), collapse = " + ")
  ))
  fit <- tryCatch(fit_probit(formula, data), error = function(e) e)
  if (inherits(fit, "error")) {
    return(tibble::tibble(
      spec = "probit_no_fe", outcome = outcome, estimate = NA_real_, std_error = NA_real_,
      p_value = NA_real_, nobs = 0L, n_clusters = 0L, ame = NA_real_,
      note = conditionMessage(fit)
    ))
  }
  d1 <- dplyr::mutate(fit$data, close_success = 1)
  d0 <- dplyr::mutate(fit$data, close_success = 0)
  ame <- mean(
    stats::predict(fit$model, newdata = d1, type = "response") -
      stats::predict(fit$model, newdata = d0, type = "response")
  )
  extract_close_success(
    fit$model, fit$vcov, nrow(fit$data), dplyr::n_distinct(fit$data$code)
  ) |>
    dplyr::mutate(spec = "probit_no_fe", outcome = outcome, ame = ame, note = NA_character_, .before = estimate)
}

run_band <- function(band_value) {
  data_band <- analysis_data |> dplyr::filter(band == band_value)
  lpm_results <- purrr::imap_dfr(lpm_specs, function(formula_fun, spec_name) {
    purrr::map_dfr(close_election_outcomes, ~ fit_lpm(data_band, .x, spec_name, formula_fun))
  })
  results <- lpm_results
  if (band_value == close_election_working_band) {
    probit_results <- purrr::map_dfr(close_election_outcomes, ~ fit_probit_robustness(data_band, .x))
    results <- dplyr::bind_rows(lpm_results, probit_results)
  }
  results |> dplyr::mutate(band = band_value, .before = spec)
}

model_results <- purrr::map_dfr(close_election_bandwidths, run_band) |>
  dplyr::mutate(
    dplyr::across(c(estimate, std_error, ame), ~ round(.x, 4)),
    p_value = signif(p_value, 3)
  ) |>
  dplyr::arrange(band, spec, outcome)

readr::write_csv(
  model_results,
  file.path(paths$tables, "active_operating_close_election_rating_models.csv")
)
saveRDS(
  model_results,
  file.path(paths$intermediate, "active_operating_close_election_rating_models.rds")
)

# Control coefficients from the main specification (working-band LPM with
# controls), for the publication main table.
extract_controls <- function(model, vcov_matrix) {
  coefs <- stats::coef(model)
  ses <- sqrt(diag(vcov_matrix))
  terms <- intersect(active_controls, names(coefs))
  tibble::tibble(
    term = terms,
    estimate = unname(coefs[terms]),
    std_error = unname(ses[terms]),
    p_value = 2 * stats::pnorm(abs(unname(coefs[terms]) / unname(ses[terms])), lower.tail = FALSE)
  )
}

control_coefficients <- analysis_data |>
  dplyr::filter(band == close_election_working_band) |>
  (\(data_band) purrr::map_dfr(close_election_outcomes, function(outcome) {
    fit <- fit_fe_lm(lpm_specs$lpm_controls(outcome), data_band)
    extract_controls(fit$model, fit$vcov) |>
      dplyr::mutate(outcome = outcome, .before = 1)
  }))() |>
  dplyr::mutate(
    dplyr::across(c(estimate, std_error), ~ round(.x, 4)),
    p_value = signif(p_value, 3)
  )

readr::write_csv(
  control_coefficients,
  file.path(paths$tables, "active_operating_close_election_control_coefs.csv")
)
