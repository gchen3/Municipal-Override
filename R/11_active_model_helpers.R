did_binary_outcomes <- c("rating_downgrade", "rating_upgrade")

add_rating_change_outcomes <- function(data, rating_var = "MOO_num", reference_year = -1L) {
  data |>
    dplyr::group_by(stack_id, code) |>
    dplyr::mutate(
      baseline_moo_num = .data[[rating_var]][rel_year == reference_year][1],
      rating_downgrade = dplyr::if_else(
        !is.na(.data[[rating_var]]) & !is.na(baseline_moo_num),
        as.numeric(.data[[rating_var]] < baseline_moo_num),
        NA_real_
      ),
      rating_upgrade = dplyr::if_else(
        !is.na(.data[[rating_var]]) & !is.na(baseline_moo_num),
        as.numeric(.data[[rating_var]] > baseline_moo_num),
        NA_real_
      )
    ) |>
    dplyr::ungroup()
}

did_event_formula <- function(
    outcome,
    fixed_effects = "stack_id^code + stack_id^year",
    covariates = character()) {
  rhs <- "i(rel_year, treated_event, ref = -1)"
  if (length(covariates) > 0) {
    rhs <- paste(rhs, paste(covariates, collapse = " + "), sep = " + ")
  }

  stats::as.formula(paste0(outcome, " ~ ", rhs, " | ", fixed_effects))
}

fit_binary_did <- function(data, outcome, formula, model_name) {
  required_vars <- unique(c(all.vars(formula), "code"))
  df <- data |>
    tidyr::drop_na(dplyr::all_of(required_vars))

  fit_result <- tryCatch(
    list(
      model = fixest::feols(formula, data = df, vcov = ~ code),
      error_message = NA_character_
    ),
    error = function(e) {
      list(
        model = NULL,
        error_message = conditionMessage(e)
      )
    }
  )

  list(
    outcome = outcome,
    model_name = model_name,
    model = fit_result$model,
    model_failed = is.null(fit_result$model),
    error_message = fit_result$error_message,
    nobs = nrow(df),
    n_municipalities = dplyr::n_distinct(df$code),
    n_stacks = dplyr::n_distinct(df$stack_id)
  )
}

coefficient_table <- function(model) {
  if (is.null(model)) {
    return(tibble::tibble())
  }

  table <- as.data.frame(fixest::coeftable(model))
  table$term <- rownames(table)
  table |>
    dplyr::as_tibble() |>
    dplyr::rename(
      estimate = Estimate,
      std_error = `Std. Error`,
      p_value = `Pr(>|t|)`
    )
}

extract_event_estimates <- function(fit, event_type, control_pool) {
  base_row <- tibble::tibble(
    event_type = event_type,
    control_pool = control_pool,
    outcome = fit$outcome,
    model = fit$model_name,
    event_time = -1L,
    term = "reference",
    estimate = 0,
    std_error = NA_real_,
    p_value = NA_real_,
    ci_lower = NA_real_,
    ci_upper = NA_real_,
    nobs = fit$nobs,
    n_municipalities = fit$n_municipalities,
    n_stacks = fit$n_stacks,
    model_failed = isTRUE(fit$model_failed),
    error_message = fit$error_message
  )

  if (is.null(fit$model)) {
    return(base_row)
  }

  estimates <- coefficient_table(fit$model) |>
    dplyr::filter(grepl("rel_year::", term), grepl("treated_event", term)) |>
    dplyr::mutate(
      event_type = event_type,
      control_pool = control_pool,
      outcome = fit$outcome,
      model = fit$model_name,
      event_time = as.integer(sub(".*rel_year::(-?[0-9]+).*", "\\1", term)),
      ci_lower = estimate - stats::qnorm(0.975) * std_error,
      ci_upper = estimate + stats::qnorm(0.975) * std_error,
      nobs = fit$nobs,
      n_municipalities = fit$n_municipalities,
      n_stacks = fit$n_stacks,
      model_failed = isTRUE(fit$model_failed),
      error_message = fit$error_message,
      .before = term
    ) |>
    dplyr::select(
      event_type, control_pool, outcome, model, event_time, term, estimate,
      std_error, p_value, ci_lower, ci_upper, nobs, n_municipalities, n_stacks,
      model_failed, error_message
    )

  dplyr::bind_rows(base_row, estimates) |>
    dplyr::arrange(event_type, control_pool, outcome, model, event_time)
}
