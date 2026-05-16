source(file.path("R", "00_config.R"))
load_required_packages(c("dplyr", "tidyr", "haven", "readr"))
make_output_dirs()

if (!file.exists(file.path(paths$intermediate, "override_all.rds"))) {
  source(file.path("R", "01_build_override_panel.R"))
}

override_all <- readRDS(file.path(paths$intermediate, "override_all.rds"))

base_data <- haven::read_dta(data_65_file("data_extended from PPMRdata for override project.dta"))
moody_data <- haven::read_dta(moody_file())
has_sp_rating <- "SP" %in% union(names(base_data), names(moody_data))

regression_data <- base_data |>
  dplyr::left_join(moody_data, by = c("year", "code")) |>
  dplyr::left_join(override_all, by = c("year", "code")) |>
  dplyr::filter(year <= 2021) |>
  dplyr::mutate(
    CPI = unname(cpi_lookup[as.character(year)]),
    amount_all = amount_all / (CPI / 184),
    amount_win = amount_win / (CPI / 184),
    Taxes = Taxes / (CPI / 184),
    taxperca = Taxes / (popu * 1000),
    excess = excess / (CPI / 184),
    excessperca = excess / (popu * 1000),
    rev = rev / (CPI / 184),
    revperca = rev / (popu * 1000),
    exp = exp / (CPI / 184),
    expperca = exp / (popu * 1000),
    balance = (rev - exp) * 100 / rev,
    unabsorbedratio = (stabilization + freecash) * 100 / Operating_Budget_Prior_Year_stab,
    logpopu = dplyr::if_else(is.na(logpopu), log(popu), logpopu),
    MOO_num = suppressWarnings(as.numeric(MOO)),
    SP = if (has_sp_rating) recode_sp_rating(.data$SP) else NA_real_,
    num_attempt1 = num_attempt,
    num_success1 = num_success,
    num_fail1 = num_fail,
    binaryover1 = binaryover,
    binarysucc1 = binarysucc
  ) |>
  dplyr::mutate(
    dplyr::across(
      dplyr::any_of(c(
        "num_attempt", "num_success", "num_fail", "amount_all", "amount_win",
        "oper_binary", "debtbinary", "capitalbinary", "stablebinary",
        "oper_binary_win", "debtbinary_win", "capitalbinary_win", "stablebinary_win",
        "oper_binary_fail", "debtbinary_fail", "capitalbinary_fail", "stablebinary_fail",
        "binaryover", "binarysucc", "binaryfail"
      )),
      ~ tidyr::replace_na(.x, 0)
    )
  ) |>
  dplyr::arrange(code, year) |>
  dplyr::group_by(code) |>
  dplyr::mutate(
    l1_popu = lag_panel(popu, year, 1),
    turnoutrate = log(turnout_avg / l1_popu),
    yes_percent = dplyr::if_else(is.na(yes_percent) & binaryover == 1, 0, yes_percent),
    yes_percent1 = tidyr::replace_na(yes_percent, 0),
    l1_binaryover = lag_panel(binaryover, year, 1),
    l2_binaryover = lag_panel(binaryover, year, 2),
    l1_binarysucc = lag_panel(binarysucc, year, 1),
    l2_binarysucc = lag_panel(binarysucc, year, 2),
    l1_binaryfail = lag_panel(binaryfail, year, 1),
    l2_binaryfail = lag_panel(binaryfail, year, 2),
    l1_num_attempt = lag_panel(num_attempt, year, 1),
    l2_num_attempt = lag_panel(num_attempt, year, 2),
    l1_num_success = lag_panel(num_success, year, 1),
    l2_num_success = lag_panel(num_success, year, 2),
    l1_num_fail = lag_panel(num_fail, year, 1),
    l2_num_fail = lag_panel(num_fail, year, 2),
    l1_num_attempt1 = lag_panel(num_attempt1, year, 1),
    l2_num_attempt1 = lag_panel(num_attempt1, year, 2),
    l1_num_success1 = lag_panel(num_success1, year, 1),
    l2_num_success1 = lag_panel(num_success1, year, 2),
    l1_num_fail1 = lag_panel(num_fail1, year, 1),
    l2_num_fail1 = lag_panel(num_fail1, year, 2),
    l1_amount_all = lag_panel(amount_all, year, 1),
    l2_amount_all = lag_panel(amount_all, year, 2),
    l1_amount_win = lag_panel(amount_win, year, 1),
    l2_amount_win = lag_panel(amount_win, year, 2),
    over_cumu_3yr = l2_num_attempt + l1_num_attempt + num_attempt,
    over_cumu_3yr1 = window_sum_if_any(l2_num_attempt1, l1_num_attempt1, num_attempt1),
    amount_all_cumu_3yr = l2_amount_all + l1_amount_all + amount_all,
    amount_win_cumu_3yr = l2_amount_win + l1_amount_win + amount_win,
    fail_cumu_3yr = l2_num_fail + l1_num_fail + num_fail,
    fail_cumu_3yr1 = window_sum_if_any(l2_num_fail1, l1_num_fail1, num_fail1)
  ) |>
  dplyr::ungroup() |>
  dplyr::mutate(
    amount_all = log(amount_all + 0.0000000001),
    amount_win = log(amount_win + 0.0000000001),
    amount_all_cumu_3yr = log(amount_all_cumu_3yr + 0.0000000001),
    amount_win_cumu_3yr = log(amount_win_cumu_3yr + 0.0000000001)
  ) |>
  dplyr::filter(year >= 2003) |>
  dplyr::group_by(code) |>
  dplyr::mutate(
    l1_binaryover = lag_panel(binaryover, year, 1),
    l2_binaryover = lag_panel(binaryover, year, 2),
    l1_binarysucc = lag_panel(binarysucc, year, 1),
    l2_binarysucc = lag_panel(binarysucc, year, 2),
    l1_binaryfail = lag_panel(binaryfail, year, 1),
    l2_binaryfail = lag_panel(binaryfail, year, 2),
    l1_num_attempt = lag_panel(num_attempt, year, 1),
    l2_num_attempt = lag_panel(num_attempt, year, 2),
    l1_num_success = lag_panel(num_success, year, 1),
    l2_num_success = lag_panel(num_success, year, 2),
    l1_num_fail = lag_panel(num_fail, year, 1),
    l2_num_fail = lag_panel(num_fail, year, 2),
    l1_num_attempt1 = lag_panel(num_attempt1, year, 1),
    l2_num_attempt1 = lag_panel(num_attempt1, year, 2),
    l1_num_success1 = lag_panel(num_success1, year, 1),
    l2_num_success1 = lag_panel(num_success1, year, 2),
    l1_num_fail1 = lag_panel(num_fail1, year, 1),
    l2_num_fail1 = lag_panel(num_fail1, year, 2)
  ) |>
  dplyr::ungroup() |>
  dplyr::group_by(year) |>
  dplyr::mutate(
    highfiscal3 = tercile_indicator(debtbudg, "top"),
    highfiscal1 = tercile_indicator(unabsorbedratio, "bottom")
  ) |>
  dplyr::ungroup()

mundlak_vars <- c(
  "highfiscal3", "logpopu", "debtbudg", "unemploy", "revstab", "taxperca",
  "excessperca", "unabsorbedratio", "revperca", "expperca", "num_attempt",
  "num_success", "num_fail", "amount_all", "amount_win", "oper_binary",
  "debtbinary", "capitalbinary", "stablebinary", "oper_binary_win",
  "debtbinary_win", "capitalbinary_win", "stablebinary_win", "oper_binary_fail",
  "debtbinary_fail", "capitalbinary_fail", "stablebinary_fail", "binaryover",
  "binarysucc", "binaryfail", "yes_percent", "balance", "over_cumu_3yr",
  "amount_all_cumu_3yr", "amount_win_cumu_3yr", "num_attempt1", "num_success1",
  "num_fail1", "over_cumu_3yr1", "binarysucc1", "fail_cumu_3yr", "highfiscal1"
)

regression_data <- regression_data |>
  dplyr::group_by(code) |>
  dplyr::mutate(
    dplyr::across(
      dplyr::all_of(intersect(mundlak_vars, names(regression_data))),
      mean_na,
      .names = "{.col}con"
    ),
    amount_win_cumu_3yrcon = mean_na(amount_win_cumu_3yr + 0.0000000001),
    binaryover1con = mean_na(binaryover)
  ) |>
  dplyr::ungroup() |>
  dplyr::mutate(
    MOO_ordered = MOO_num,
    sample = NA_real_
  )

saveRDS(regression_data, file.path(paths$intermediate, "data_for_regression.rds"))

validation <- tibble::tibble(
  step = c("base_after_joins", "regression_final"),
  rows = c(nrow(base_data), nrow(regression_data)),
  municipalities = c(dplyr::n_distinct(base_data$code), dplyr::n_distinct(regression_data$code)),
  min_year = c(min(base_data$year, na.rm = TRUE), min(regression_data$year, na.rm = TRUE)),
  max_year = c(max(base_data$year, na.rm = TRUE), max(regression_data$year, na.rm = TRUE))
)

readr::write_csv(validation, file.path(paths$intermediate, "regression_data_validation.csv"))
