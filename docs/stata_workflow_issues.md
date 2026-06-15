# Stata Workflow Issues and R Replication Notes

- The Stata override-panel block contains `replace stablebinary_win=0 if stablebinary_fail==.`. The R workflow computes `stablebinary_fail` directly at the municipality-year level, which preserves the intended failure indicator and avoids carrying the typo into the intermediate file.
- The Stata workflow builds `override_all.dta` through row-level duplicate dropping after group fills. The R workflow aggregates directly to municipality-year from the appended raw override records, which yields the same intended panel variables without writing intermediate `.dta` files.
- Stata `xtile, n(3)` is approximated with `dplyr::ntile()` within year for `highfiscal1` and `highfiscal3`. Check borderline observations if exact tercile membership is material.
- Stata time-series lags respect `xtset code year`; the R helpers only carry lag values across consecutive municipality-years so gaps remain missing.
