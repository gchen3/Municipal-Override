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

ordered_no_mundlak <- function(main_terms, controls_used = controls) {
  rhs_formula(ordered_outcome, c(main_terms, controls_used))
}

probit_no_mundlak <- function(outcome, main_terms, controls_used = controls) {
  rhs_formula(outcome, c(main_terms, controls_used))
}

appendix_A3 <- list(
  binary_attempt = fit_ordered_probit(ordered_no_mundlak("binaryover"), data_for_regression),
  binary_success = fit_ordered_probit(ordered_no_mundlak("binarysucc"), data_for_regression),
  binary_failure = fit_ordered_probit(ordered_no_mundlak("binaryfail"), data_for_regression),
  operating_success = fit_ordered_probit(ordered_no_mundlak("oper_binary_win"), data_for_regression),
  debt_success = fit_ordered_probit(ordered_no_mundlak("debtbinary_win"), data_for_regression),
  capital_success = fit_ordered_probit(ordered_no_mundlak("capitalbinary_win"), data_for_regression),
  stabilization_success = fit_ordered_probit(ordered_no_mundlak("stablebinary_win"), data_for_regression)
)

appendix_A4 <- list(
  attempt_low_reserve = fit_ordered_probit(rhs_formula(ordered_outcome, c("binaryover * highfiscal1", controls_low_reserve)), data_for_regression),
  success_low_reserve = fit_ordered_probit(rhs_formula(ordered_outcome, c("binarysucc * highfiscal1", controls_low_reserve)), data_for_regression),
  failure_low_reserve = fit_ordered_probit(rhs_formula(ordered_outcome, c("binaryfail * highfiscal1", controls_low_reserve)), data_for_regression),
  attempt_high_debt = fit_ordered_probit(rhs_formula(ordered_outcome, c("binaryover * highfiscal3", controls_high_debt)), data_for_regression),
  success_high_debt = fit_ordered_probit(rhs_formula(ordered_outcome, c("binarysucc * highfiscal3", controls_high_debt)), data_for_regression),
  failure_high_debt = fit_ordered_probit(rhs_formula(ordered_outcome, c("binaryfail * highfiscal3", controls_high_debt)), data_for_regression)
)

appendix_A5 <- list(
  attempt_lag1 = fit_ordered_probit(ordered_no_mundlak(c("binaryover", "l1_binaryover")), data_for_regression),
  success_lag1 = fit_ordered_probit(ordered_no_mundlak(c("binarysucc", "l1_binarysucc")), data_for_regression),
  failure_lag1 = fit_ordered_probit(ordered_no_mundlak(c("binaryfail", "l1_binaryfail")), data_for_regression),
  attempt_lag2 = fit_ordered_probit(ordered_no_mundlak(c("binaryover", "l1_binaryover", "l2_binaryover")), data_for_regression),
  success_lag2 = fit_ordered_probit(ordered_no_mundlak(c("binarysucc", "l1_binarysucc", "l2_binarysucc")), data_for_regression),
  failure_lag2 = fit_ordered_probit(ordered_no_mundlak(c("binaryfail", "l1_binaryfail", "l2_binaryfail")), data_for_regression)
)

appendix_A6 <- list(
  operating_attempt = fit_ordered_probit(ordered_no_mundlak("oper_binary"), data_for_regression),
  capital_attempt = fit_ordered_probit(ordered_no_mundlak("capitalbinary"), data_for_regression),
  debt_attempt = fit_ordered_probit(ordered_no_mundlak("debtbinary"), data_for_regression),
  stabilization_attempt = fit_ordered_probit(ordered_no_mundlak("stablebinary"), data_for_regression),
  operating_failure = fit_ordered_probit(ordered_no_mundlak("oper_binary_fail"), data_for_regression),
  debt_failure = fit_ordered_probit(ordered_no_mundlak("debtbinary_fail"), data_for_regression),
  capital_failure = fit_ordered_probit(ordered_no_mundlak("capitalbinary_fail"), data_for_regression),
  stabilization_failure = fit_ordered_probit(ordered_no_mundlak("stablebinary_fail"), data_for_regression)
)

appendix_A7 <- list(
  attempt_count = fit_ordered_probit(ordered_no_mundlak("num_attempt"), data_for_regression),
  success_count = fit_ordered_probit(ordered_no_mundlak("num_success"), data_for_regression),
  failure_count = fit_ordered_probit(ordered_no_mundlak("num_fail"), data_for_regression),
  attempt_count_3yr = fit_ordered_probit(ordered_no_mundlak("over_cumu_3yr"), data_for_regression),
  failure_count_3yr = fit_ordered_probit(ordered_no_mundlak("fail_cumu_3yr"), data_for_regression)
)

appendix_A8 <- list(
  attempt_lag1 = fit_ordered_probit(ordered_no_mundlak(c("num_attempt", "l1_num_attempt")), data_for_regression),
  success_lag1 = fit_ordered_probit(ordered_no_mundlak(c("num_success", "l1_num_success")), data_for_regression),
  failure_lag1 = fit_ordered_probit(ordered_no_mundlak(c("num_fail", "l1_num_fail")), data_for_regression),
  attempt_lag2 = fit_ordered_probit(ordered_no_mundlak(c("num_attempt", "l1_num_attempt", "l2_num_attempt")), data_for_regression),
  success_lag2 = fit_ordered_probit(ordered_no_mundlak(c("num_success", "l1_num_success", "l2_num_success")), data_for_regression),
  failure_lag2 = fit_ordered_probit(ordered_no_mundlak(c("num_fail", "l1_num_fail", "l2_num_fail")), data_for_regression)
)

appendix_A9 <- list(
  amount_all = fit_ordered_probit(ordered_no_mundlak("amount_all"), data_for_regression),
  amount_win = fit_ordered_probit(ordered_no_mundlak("amount_win"), data_for_regression),
  amount_all_3yr = fit_ordered_probit(ordered_no_mundlak("amount_all_cumu_3yr"), data_for_regression),
  amount_win_3yr = fit_ordered_probit(ordered_no_mundlak("amount_win_cumu_3yr"), data_for_regression)
)

appendix_A10 <- list(
  success_amount = fit_probit(probit_no_mundlak("binarysucc1", "amount_all"), data_for_regression),
  success_amount_3yr = fit_probit(probit_no_mundlak("binarysucc1", "amount_all_cumu_3yr"), data_for_regression),
  success_percent_amount = fit_fe_lm(fe_formula("yes_percent", c("amount_all", controls)), data_for_regression),
  success_percent_amount_3yr = fit_fe_lm(fe_formula("yes_percent", c("amount_all_cumu_3yr", controls)), data_for_regression)
)

appendix_A11 <- list(
  turnout_count = fit_fe_lm(fe_formula("turnoutrate", c("num_attempt", controls)), data_for_regression),
  turnout_count_3yr = fit_fe_lm(fe_formula("turnoutrate", c("over_cumu_3yr", controls)), data_for_regression),
  turnout_amount = fit_fe_lm(fe_formula("turnoutrate", c("amount_all", controls)), data_for_regression),
  turnout_amount_success = fit_fe_lm(fe_formula("turnoutrate", c("amount_win", controls)), data_for_regression),
  turnout_amount_3yr = fit_fe_lm(fe_formula("turnoutrate", c("amount_all_cumu_3yr", controls)), data_for_regression),
  turnout_amount_success_3yr = fit_fe_lm(fe_formula("turnoutrate", c("amount_win_cumu_3yr", controls)), data_for_regression)
)

robustness_fits <- list(
  appendix_A3 = appendix_A3,
  appendix_A4 = appendix_A4,
  appendix_A5 = appendix_A5,
  appendix_A6 = appendix_A6,
  appendix_A7 = appendix_A7,
  appendix_A8 = appendix_A8,
  appendix_A9 = appendix_A9,
  appendix_A10 = appendix_A10,
  appendix_A11 = appendix_A11
)

saveRDS(robustness_fits, file.path(paths$intermediate, "robustness_models.rds"))

write_model_table(appendix_A3, "appendix_A3_no_mundlak_overrides.html", "Appendix Table A3. No-Mundlak Override Models")
write_model_table(appendix_A4, "appendix_A4_no_mundlak_fiscal_stress.html", "Appendix Table A4. No-Mundlak Fiscal Stress Models")
write_model_table(appendix_A5, "appendix_A5_lagged_binary_overrides.html", "Appendix Table A5. Lagged Binary Override Models")
write_model_table(appendix_A6, "appendix_A6_override_types.html", "Appendix Table A6. Override Type Models")
write_model_table(appendix_A7, "appendix_A7_full_sample_frequency.html", "Appendix Table A7. Full-Sample Frequency Models")
write_model_table(appendix_A8, "appendix_A8_lagged_frequency.html", "Appendix Table A8. Lagged Frequency Models")
write_model_table(appendix_A9, "appendix_A9_amount_credit.html", "Appendix Table A9. Override Amount Models for Credit Ratings")
write_model_table(appendix_A10, "appendix_A10_amount_success.html", "Appendix Table A10. Override Amount Models for Override Success")
write_model_table(appendix_A11, "appendix_A11_turnout.html", "Appendix Table A11. Turnout Models")
