source(file.path("R", "00_config.R"))
load_required_packages(c("dplyr", "tidyr", "purrr", "haven", "readr"))
make_output_dirs()

override_files <- c(
  "override_override.dta",
  "override_capital.dta",
  "override_debt.dta",
  "override_stable.dta"
)

override_all <- purrr::map_dfr(
  data_65_file(override_files),
  haven::read_dta
) |>
  dplyr::mutate(
    year = FiscalYear,
    turnout = YesVotes + NoVotes
  ) |>
  dplyr::group_by(code, year) |>
  dplyr::summarise(
    num_attempt = dplyr::n(),
    num_success = sum(WinLoss == "WIN", na.rm = TRUE),
    num_fail = sum(WinLoss == "LOSS", na.rm = TRUE),
    amount_all = sum(Amount, na.rm = TRUE),
    amount_win = sum(dplyr::if_else(WinLoss == "WIN", Amount, 0), na.rm = TRUE),
    oper_binary = as.numeric(any(Override == "operating", na.rm = TRUE)),
    oper_binary_win = as.numeric(any(Override == "operating" & WinLoss == "WIN", na.rm = TRUE)),
    oper_binary_fail = as.numeric(any(Override == "operating" & WinLoss == "LOSS", na.rm = TRUE)),
    debtbinary = as.numeric(any(Override == "debt", na.rm = TRUE)),
    debtbinary_win = as.numeric(any(Override == "debt" & WinLoss == "WIN", na.rm = TRUE)),
    debtbinary_fail = as.numeric(any(Override == "debt" & WinLoss == "LOSS", na.rm = TRUE)),
    capitalbinary = as.numeric(any(Override == "capital", na.rm = TRUE)),
    capitalbinary_win = as.numeric(any(Override == "capital" & WinLoss == "WIN", na.rm = TRUE)),
    capitalbinary_fail = as.numeric(any(Override == "capital" & WinLoss == "LOSS", na.rm = TRUE)),
    stablebinary = as.numeric(any(Override == "stable", na.rm = TRUE)),
    stablebinary_win = as.numeric(any(Override == "stable" & WinLoss == "WIN", na.rm = TRUE)),
    stablebinary_fail = as.numeric(any(Override == "stable" & WinLoss == "LOSS", na.rm = TRUE)),
    turnout_avg = mean_na(turnout),
    .groups = "drop"
  ) |>
  dplyr::mutate(
    binaryover = as.numeric(num_attempt > 0),
    binarysucc = as.numeric(num_success > 0),
    binaryfail = as.numeric(num_fail > 0),
    yes_percent = num_success * 100 / num_attempt,
    year = year + 1
  )

saveRDS(override_all, file.path(paths$intermediate, "override_all.rds"))

validation <- tibble::tibble(
  step = "override_all",
  rows = nrow(override_all),
  municipalities = dplyr::n_distinct(override_all$code),
  min_year = min(override_all$year, na.rm = TRUE),
  max_year = max(override_all$year, na.rm = TRUE)
)

readr::write_csv(validation, file.path(paths$intermediate, "override_all_validation.csv"))
