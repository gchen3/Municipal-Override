required_packages <- c(
  "dplyr", "tidyr", "purrr", "haven", "MASS", "sandwich", "fixest",
  "modelsummary", "gt", "ggplot2", "readr", "broom"
)

load_required_packages <- function(packages = required_packages) {
  missing_packages <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing_packages) > 0) {
    stop(
      "Missing required packages: ",
      paste(missing_packages, collapse = ", "),
      call. = FALSE
    )
  }

  invisible(suppressWarnings(suppressPackageStartupMessages(
    lapply(packages, library, character.only = TRUE)
  )))
  if ("fixest" %in% packages && requireNamespace("fixest", quietly = TRUE)) {
    fixest::setFixest_notes(FALSE)
  }
}

paths <- list(
  data_65 = file.path("Data and Models", "6.5"),
  intermediate = file.path("outputs", "intermediate"),
  tables = file.path("outputs", "tables"),
  figures = file.path("outputs", "figures"),
  report = file.path("outputs", "report")
)

make_output_dirs <- function() {
  invisible(lapply(paths[c("intermediate", "tables", "figures", "report")], dir.create, recursive = TRUE, showWarnings = FALSE))
}

data_65_file <- function(...) {
  file.path(paths$data_65, ...)
}

moody_file <- function() {
  matches <- list.files(paths$data_65, pattern = "^MOO.*[.]dta$", full.names = TRUE)
  if (length(matches) != 1) {
    stop("Expected exactly one Moody's data file under ", paths$data_65, call. = FALSE)
  }
  matches
}

cpi_lookup <- c(
  "1992" = 140.3, "1993" = 144.5, "1994" = 148.2, "1995" = 152.4,
  "1996" = 156.9, "1997" = 160.5, "1998" = 163.0, "1999" = 166.6,
  "2000" = 172.2, "2001" = 177.1, "2002" = 179.9, "2003" = 184.0,
  "2004" = 188.9, "2005" = 195.3, "2006" = 201.6, "2007" = 207.3,
  "2008" = 215.3, "2009" = 214.5, "2010" = 218.1, "2011" = 224.9,
  "2012" = 229.6, "2013" = 233.0, "2014" = 236.7, "2015" = 237.0,
  "2016" = 240.0, "2017" = 245.1, "2018" = 251.1, "2019" = 255.7,
  "2020" = 258.8, "2021" = 271.0, "2022" = 292.7, "2023" = 304.7
)

variable_labels <- c(
  MOO_num = "Credit ratings by Moody's",
  SP = "Credit ratings by S&P",
  binaryover = "Binary for any override attempt",
  binarysucc = "Binary for any successful override",
  binaryfail = "Binary for any override failure",
  yes_percent1 = "Successful overrides (%)",
  num_attempt = "Total override attempts (count)",
  num_success = "Total successful overrides (count)",
  num_fail = "Total override failures (count)",
  over_cumu_3yr = "3-year cumulative override attempts (count)",
  fail_cumu_3yr = "3-year cumulative override failures (count)",
  amount_all = "Total amounts by override attempts (log)",
  amount_win = "Total amounts by successful overrides (log)",
  amount_all_cumu_3yr = "3-year cumulative amounts by override attempts (log)",
  amount_win_cumu_3yr = "3-year cumulative amounts by successful overrides (log)",
  logpopu = "Population size (log)",
  debtbudg = "Outstanding debt level (%)",
  unemploy = "Unemployment rate (%)",
  revstab = "Revenue stability (%)",
  revperca = "Government revenue (per capita)",
  expperca = "Government expenditure (per capita)",
  taxperca = "Tax effort (per capita)",
  excessperca = "Excess property tax capacity",
  unabsorbedratio = "Fiscal reserve (%)",
  balance = "Budget balance (%)",
  turnoutrate = "Override turnout rate",
  approval_rate = "Override approval rate"
)

mean_na <- function(x) {
  if (all(is.na(x))) {
    NA_real_
  } else {
    mean(x, na.rm = TRUE)
  }
}

lag_panel <- function(x, year, n = 1L) {
  lag_x <- dplyr::lag(x, n)
  lag_year <- dplyr::lag(year, n)
  dplyr::if_else(year - lag_year == n, lag_x, NA_real_)
}

window_sum_if_any <- function(...) {
  values <- data.frame(..., check.names = FALSE)
  any_observed <- rowSums(!is.na(values)) > 0
  sums <- rowSums(dplyr::mutate(values, dplyr::across(dplyr::everything(), ~ tidyr::replace_na(.x, 0))))
  dplyr::if_else(any_observed, sums, NA_real_)
}

tercile_indicator <- function(x, target = c("bottom", "top")) {
  target <- match.arg(target)
  ranks <- rep(NA_integer_, length(x))
  observed <- !is.na(x)
  ranks[observed] <- dplyr::ntile(x[observed], 3)

  dplyr::case_when(
    target == "bottom" & ranks == 1L ~ 1,
    target == "bottom" & ranks %in% c(2L, 3L) ~ 0,
    target == "top" & ranks == 3L ~ 1,
    target == "top" & ranks %in% c(1L, 2L) ~ 0,
    TRUE ~ NA_real_
  )
}

recode_sp_rating <- function(x) {
  x_chr <- as.character(haven::as_factor(x))
  recoded <- dplyr::recode(
    x_chr,
    "AAA" = "10", "AA+" = "9", "AA" = "8", "A+" = "7", "AA-" = "6",
    "A" = "5", "A-" = "4", "BBB+" = "3", "BBB" = "2", "BBB-" = "1",
    "aa" = "8", "Confidential" = NA_character_, "NR" = NA_character_,
    "-" = NA_character_, .default = x_chr
  )
  suppressWarnings(as.numeric(recoded))
}

complete_model_data <- function(data, formula, cluster = "code") {
  vars <- unique(c(all.vars(formula), cluster))
  missing_vars <- setdiff(vars, names(data))
  if (length(missing_vars) > 0) {
    stop("Missing model variables: ", paste(missing_vars, collapse = ", "), call. = FALSE)
  }

  data |>
    dplyr::select(dplyr::all_of(vars)) |>
    tidyr::drop_na()
}

cluster_vcov <- function(model, cluster) {
  tryCatch(
    suppressWarnings(sandwich::vcovCL(model, cluster = cluster)),
    error = function(e) stats::vcov(model)
  )
}

fit_ordered_probit <- function(formula, data, cluster = "code") {
  df <- complete_model_data(data, formula, cluster)
  outcome <- all.vars(formula)[1]
  df[[outcome]] <- ordered(df[[outcome]], levels = sort(unique(df[[outcome]])))
  model <- tryCatch(
    suppressWarnings(MASS::polr(formula, data = df, method = "probit", Hess = TRUE, model = TRUE)),
    error = function(e) {
      terms_obj <- stats::terms(formula, data = df)
      x <- stats::model.matrix(terms_obj, data = df)
      intercept <- match("(Intercept)", colnames(x), nomatch = 0L)
      coefficient_count <- ncol(x) - as.integer(intercept > 0)
      cutpoint_count <- length(levels(df[[outcome]])) - 1L
      start <- c(rep(0, coefficient_count), stats::qnorm(seq_len(cutpoint_count) / (cutpoint_count + 1)))
      suppressWarnings(MASS::polr(formula, data = df, method = "probit", Hess = TRUE, model = TRUE, start = start))
    }
  )
  list(model = model, vcov = cluster_vcov(model, df[[cluster]]), data = df)
}

fit_probit <- function(formula, data, cluster = "code") {
  df <- complete_model_data(data, formula, cluster)
  model <- suppressWarnings(stats::glm(formula, data = df, family = stats::binomial(link = "probit")))
  list(model = model, vcov = cluster_vcov(model, df[[cluster]]), data = df)
}

fit_fe_lm <- function(formula, data, cluster = "code") {
  df <- complete_model_data(data, formula, cluster)
  model <- fixest::feols(formula, data = df, vcov = stats::as.formula(paste0("~", cluster)))
  list(model = model, vcov = stats::vcov(model), data = df)
}

rhs_formula <- function(outcome, terms, include_year = TRUE) {
  rhs <- terms
  if (include_year) {
    rhs <- c(rhs, "factor(year)")
  }
  stats::as.formula(paste(outcome, "~", paste(rhs, collapse = " + ")))
}

fe_formula <- function(outcome, terms) {
  stats::as.formula(paste(outcome, "~", paste(terms, collapse = " + "), "| code + year"))
}

con_terms <- function(terms) {
  paste0(terms, "con")
}

write_model_table <- function(fits, file_name, title) {
  models <- lapply(fits, `[[`, "model")
  vcovs <- lapply(fits, `[[`, "vcov")
  names(models) <- names(fits)
  names(vcovs) <- names(fits)

  modelsummary::modelsummary(
    models,
    vcov = vcovs,
    stars = TRUE,
    title = title,
    coef_rename = variable_labels,
    gof_omit = "AIC|BIC|Log.Lik.|RMSE",
    output = file.path(paths$tables, file_name)
  )
}
