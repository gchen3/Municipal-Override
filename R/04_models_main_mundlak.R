source(file.path("R", "00_config.R"))
load_required_packages(c("dplyr", "tidyr", "MASS", "sandwich", "fixest", "modelsummary"))
make_output_dirs()

if (!file.exists(file.path(paths$intermediate, "data_for_regression.rds"))) {
  source(file.path("R", "02_build_regression_data.R"))
}

data_for_regression <- readRDS(file.path(paths$intermediate, "data_for_regression.rds"))

ordered_outcome <- "MOO_ordered"
controls <- c("logpopu", "debtbudg", "unemploy", "revstab", "revperca", "excessperca", "unabsorbedratio", "balance")
controls_low_reserve <- c("logpopu", "debtbudg", "unemploy", "revstab", "revperca", "excessperca", "balance")
controls_high_debt <- c("logpopu", "unemploy", "revstab", "revperca", "excessperca", "unabsorbedratio", "balance")

available_con_terms <- function(main_terms, controls_used = controls) {
  candidates <- c(main_terms[!grepl("[*]", main_terms)], controls_used)
  con_candidates <- paste0(candidates, "con")
  con_candidates <- dplyr::recode(
    con_candidates,
    "num_attempt1con" = "num_attemptcon",
    "num_success1con" = "num_successcon",
    "num_fail1con" = "num_failcon",
    "over_cumu_3yr1con" = "over_cumu_3yrcon",
    "fail_cumu_3yr1con" = "fail_cumu_3yrcon",
    .default = con_candidates
  )
  unique(con_candidates[con_candidates %in% names(data_for_regression)])
}

ordered_mundlak <- function(main_terms, controls_used = controls) {
  rhs_formula(
    ordered_outcome,
    c(main_terms, controls_used, available_con_terms(main_terms, controls_used))
  )
}

probit_mundlak <- function(outcome, main_terms, controls_used = controls) {
  rhs_formula(
    outcome,
    c(main_terms, controls_used, available_con_terms(main_terms, controls_used))
  )
}

table_1 <- list(
  binary_attempt = fit_ordered_probit(ordered_mundlak("binaryover"), data_for_regression),
  binary_success = fit_ordered_probit(ordered_mundlak("binarysucc"), data_for_regression),
  binary_failure = fit_ordered_probit(ordered_mundlak("binaryfail"), data_for_regression),
  operating_success = fit_ordered_probit(ordered_mundlak("oper_binary_win"), data_for_regression),
  debt_success = fit_ordered_probit(ordered_mundlak("debtbinary_win"), data_for_regression),
  capital_success = fit_ordered_probit(ordered_mundlak("capitalbinary_win"), data_for_regression),
  stabilization_success = fit_ordered_probit(ordered_mundlak("stablebinary_win"), data_for_regression)
)

table_2 <- list(
  attempt_low_reserve = fit_ordered_probit(
    rhs_formula(ordered_outcome, c("binaryover * highfiscal1", controls_low_reserve, "binaryovercon", con_terms(controls_low_reserve), "highfiscal1con")),
    data_for_regression
  ),
  success_low_reserve = fit_ordered_probit(
    rhs_formula(ordered_outcome, c("binarysucc * highfiscal1", controls_low_reserve, "binarysucccon", con_terms(controls_low_reserve), "highfiscal1con")),
    data_for_regression
  ),
  failure_low_reserve = fit_ordered_probit(
    rhs_formula(ordered_outcome, c("binaryfail * highfiscal1", controls_low_reserve, "binaryfailcon", con_terms(controls_low_reserve), "highfiscal1con")),
    data_for_regression
  ),
  attempt_high_debt = fit_ordered_probit(
    rhs_formula(ordered_outcome, c("binaryover * highfiscal3", controls_high_debt, "binaryovercon", con_terms(controls_high_debt), "highfiscal3con")),
    data_for_regression
  ),
  success_high_debt = fit_ordered_probit(
    rhs_formula(ordered_outcome, c("binarysucc * highfiscal3", controls_high_debt, "binarysucccon", con_terms(controls_high_debt), "highfiscal3con")),
    data_for_regression
  ),
  failure_high_debt = fit_ordered_probit(
    rhs_formula(ordered_outcome, c("binaryfail * highfiscal3", controls_high_debt, "binaryfailcon", con_terms(controls_high_debt), "highfiscal3con")),
    data_for_regression
  )
)

table_3 <- list(
  success_count = fit_probit(probit_mundlak("binarysucc1", "num_attempt"), data_for_regression),
  success_count_3yr = fit_probit(probit_mundlak("binarysucc1", "over_cumu_3yr"), data_for_regression),
  success_percent_count = fit_fe_lm(fe_formula("yes_percent", c("num_attempt", controls)), data_for_regression),
  success_percent_count_3yr = fit_fe_lm(fe_formula("yes_percent", c("over_cumu_3yr", controls)), data_for_regression)
)

table_4 <- list(
  turnout_count = fit_fe_lm(fe_formula("turnoutrate", c("num_attempt", controls)), data_for_regression),
  turnout_count_3yr = fit_fe_lm(fe_formula("turnoutrate", c("over_cumu_3yr", controls)), data_for_regression),
  turnout_amount = fit_fe_lm(fe_formula("turnoutrate", c("amount_all", controls)), data_for_regression),
  turnout_amount_success = fit_fe_lm(fe_formula("turnoutrate", c("amount_win", controls)), data_for_regression),
  turnout_amount_3yr = fit_fe_lm(fe_formula("turnoutrate", c("amount_all_cumu_3yr", controls)), data_for_regression),
  turnout_amount_success_3yr = fit_fe_lm(fe_formula("turnoutrate", c("amount_win_cumu_3yr", controls)), data_for_regression)
)

table_5 <- list(
  nonzero_attempt = fit_ordered_probit(ordered_mundlak("num_attempt1"), data_for_regression),
  nonzero_success = fit_ordered_probit(ordered_mundlak("num_success1"), data_for_regression),
  nonzero_failure = fit_ordered_probit(ordered_mundlak("num_fail1"), data_for_regression),
  nonzero_attempt_3yr = fit_ordered_probit(ordered_mundlak("over_cumu_3yr1"), data_for_regression),
  nonzero_failure_3yr = fit_ordered_probit(ordered_mundlak("fail_cumu_3yr1"), data_for_regression)
)

table_6 <- list(
  attempt_lag1 = fit_ordered_probit(ordered_mundlak(c("num_attempt1", "l1_num_attempt1")), data_for_regression),
  success_lag1 = fit_ordered_probit(ordered_mundlak(c("num_success1", "l1_num_success1")), data_for_regression),
  failure_lag1 = fit_ordered_probit(ordered_mundlak(c("num_fail1", "l1_num_fail1")), data_for_regression),
  attempt_lag2 = fit_ordered_probit(ordered_mundlak(c("num_attempt1", "l1_num_attempt1", "l2_num_attempt1")), data_for_regression),
  success_lag2 = fit_ordered_probit(ordered_mundlak(c("num_success1", "l1_num_success1", "l2_num_success1")), data_for_regression),
  failure_lag2 = fit_ordered_probit(ordered_mundlak(c("num_fail1", "l1_num_fail1", "l2_num_fail1")), data_for_regression)
)

main_mundlak_fits <- list(
  table_1 = table_1,
  table_2 = table_2,
  table_3 = table_3,
  table_4 = table_4,
  table_5 = table_5,
  table_6 = table_6
)

saveRDS(main_mundlak_fits, file.path(paths$intermediate, "main_mundlak_models.rds"))

write_model_table(table_1, "table_1_effects_of_overrides_on_credit_ratings.html", "Table 1. Effects of Overrides on Credit Ratings")
write_model_table(table_2, "table_2_fiscal_stress.html", "Table 2. Effects of Overrides on Credit Ratings Under Fiscal Stress")
write_model_table(table_3, "table_3_override_success.html", "Table 3. Effects of Override Attempts on Override Success")
write_model_table(table_4, "table_4_turnout.html", "Table 4. Effects of Overrides on Turnout Rate")
write_model_table(table_5, "table_5_frequency_nonzero.html", "Table 5. Effects of Override Frequency on Credit Ratings")
write_model_table(table_6, "table_6_lagged_frequency.html", "Table 6. Effects of Override Frequency in the Past Few Years on Credit Ratings")
