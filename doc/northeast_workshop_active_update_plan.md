# NorthEast Workshop Active-Results Update Plan

## Purpose

Update the data, methods, results, robustness, and slide-ready result portions of `slides/NorthEast_workshop.qmd` so they match the active operating-override methods summarized in `R/Methods.md`, then generate slide-ready results from the active workflow outputs.

Front-section scope decision: do not plan Codex edits for the motivation, Massachusetts Proposition 2 1/2, research questions, or dual-signal framework slides. Those front sections will be updated manually by the user.

The current slide deck is still largely organized around the older Stata-replication framing: all override types, fiscal-stress moderation, turnout, override amounts, lagged frequency effects on ratings, and placeholder tables. The active methods now focus on operating overrides, ordered probit Moody's models with Mundlak controls, a three-year cumulative frequency-on-rating test, fixed-effects models for annual operating yes-vote percentage, and repeated-event DiD models for binary Moody's rating changes.

Settled scope decision: the updated deck will drop fiscal-stress moderation/H3 models, turnout models, broad all-override results, and DiD models with voter-support outcomes. These will not be regenerated for this workshop update.

## Source Files Reviewed

- `R/Methods.md`
- `slides/NorthEast_workshop.qmd`
- `outputs/tables/active_workflow_outputs.csv`
- `outputs/tables/active_operating_repeated_event_binary_did_main.csv`
- `outputs/tables/active_operating_repeated_event_sample_counts.csv`

## Main Discrepancies To Resolve

1. **Scope of override treatment**
   - The active estimates are operating-override analyses.
   - The slide deck can continue using the broader "property tax overrides" language where it reads naturally.
   - No special terminology cleanup is needed solely to distinguish operating overrides from property tax overrides.

2. **Data and sample**
   - Current slide says 256 municipalities and 3,550 observations for selected years.
   - Active methods say the constructed regression panel covers 2003-2021, with override activity shifted forward one year from source `FiscalYear`.
   - The Moody's complete-case models use 2003-2015, 2017, and 2019-2021 because Moody's ratings are unavailable in 2016 and 2018.
   - Current verified counts:
     - Constructed regression panel: 6,669 municipality-year rows, 351 municipalities, continuous 2003-2021.
     - Moody's ordered probit complete cases: 3,550 rows, 265 municipalities, 2003-2015, 2017, 2019-2021.
     - Operating yes-vote-percentage fixed-effects complete cases: 730 rows, 221 municipalities, continuous 2003-2021.
     - Repeated-event DiD clean event years: 2005-2019, with stacked panel years 2003-2021.
   - Regenerate or verify the data slide from the active workflow rather than relying on the old hard-coded municipality count.

3. **Outcomes**
   - Current slides list Moody's ratings, override success indicators/percentages, and voter turnout.
   - Active models use:
     - `MOO_ordered` for Moody's ratings.
     - `oper_yes_vote_percent`, total operating override yes votes as a percentage of yes plus no votes in a municipality-year.
     - Binary Moody's rating-change outcomes for repeated-event DiD.
   - Remove turnout as a current outcome.

4. **Independent variables**
   - Current slides include override amounts and fiscal-stress interactions.
   - Active results use operating attempt/success/failure indicators for ratings, three-year cumulative operating counts for the frequency-on-rating test, and operating annual/three-year counts for operating yes-vote percentage.
   - Remove fiscal-stress interaction claims from the active results narrative.

5. **Model specifications**
   - Current credit-rating equation is a generic linear model with lagged override terms.
   - Active rating models are ordered probit specifications with Mundlak controls, year indicators, and municipality-clustered standard errors.
   - Current voter-support equation lacks municipality fixed effects and uses generic `Success`.
   - Active voter-support models are fixed-effects linear models for `oper_yes_vote_percent` with municipality and year fixed effects.
   - Add the repeated-event DiD specification from `R/Methods.md`.

6. **Results claims**
   - Current result slides state support for H1a, H1b, H3, H4a, and H4b.
   - These claims are not all supported by the active workflow because H3 fiscal-stress moderation, turnout, broad all-override models, voter-support DiD models, and amount models are not currently active.
   - Replace unsupported claims with active-result summaries after regenerating tables.

7. **Placeholder tables**
   - The deck contains placeholders for six Stata-era tables.
   - Replace them with slide-ready active outputs:
     - Operating Moody's ordered probit summary.
     - Operating passage-percentage FE summary.
     - Repeated-event sample-count summary.
     - Preferred repeated-event binary DiD estimates.

## Result Generation Plan

1. **Regenerate active workflow outputs**
   - Run `R/15_run_all_active_workflow.R`.
   - Expected active outputs:
     - `outputs/tables/active_operating_moodys_main.html`
     - `outputs/tables/active_operating_moodys_frequency.html`
     - `outputs/tables/active_operating_vote_share_main.html`
     - `outputs/tables/active_operating_repeated_event_sample_counts.csv`
     - `outputs/tables/active_operating_repeated_event_binary_did.csv`
     - `outputs/tables/active_operating_repeated_event_binary_did_main.csv`
     - `outputs/tables/active_workflow_outputs.csv`
     - related `.rds` model objects under `outputs/intermediate/`

2. **Create slide-ready result assets**
   - Add a small slide-results script if needed, likely `R/16_prepare_northeast_workshop_results.R`.
   - Read active `.rds` model objects and active DiD/sample-count CSVs.
   - Produce compact, publication-quality Beamer-friendly tables, not full HTML tables.
   - Candidate outputs:
     - `outputs/tables/northeast_moodys_main.tex`
     - `outputs/tables/northeast_moodys_frequency.tex`
     - `outputs/tables/northeast_vote_share_annual.tex`
     - `outputs/tables/northeast_vote_share_cumulative.tex`
     - `outputs/tables/northeast_repeated_event_counts.tex`
     - `outputs/tables/northeast_repeated_event_did_main.tex`
     - `outputs/tables/northeast_repeated_event_did_downgrade.tex`
     - `outputs/tables/northeast_repeated_event_did_upgrade.tex`
   - Keep tables narrow: show the main operating terms, standard errors, significance markers, observations, municipalities, and model notes.
   - Apply publication-quality table standards:
     - Use clear model titles and column labels tied to the estimands, not raw object names.
     - Use readable variable labels, such as "Attempt", "Success", "Failure", "Annual count", and "3-year cumulative count".
     - Report coefficient estimates with standard errors in parentheses.
     - Use consistent rounding, preferably three decimals for estimates and standard errors.
     - Include significance notes and identify municipality-clustered standard errors.
     - Include model controls/FE notes: controls, Mundlak means, year indicators, municipality fixed effects, stack-by-municipality fixed effects, or stack-by-year fixed effects as applicable.
     - Include sample notes where years differ across models, especially the Moody's complete-case years excluding 2016 and 2018.
     - Avoid overcrowding: split tables across slides rather than shrinking to unreadable text.
     - Do not expose intermediate/raw variable names in the final slide tables unless needed for reproducibility.
     - Preserve enough information for the table to stand alone in the slide deck.

3. **Create result summary text**
   - Generate or manually prepare concise bullets from the active estimates.
   - Avoid old hypothesis language until the active signs, magnitudes, and uncertainty are checked.
   - Suggested summaries:
     - Rating models: operating attempt, success, and failure associations with ordered Moody's ratings.
     - Frequency-on-rating models: three-year cumulative operating override frequency associations with ordered Moody's ratings.
     - Yes-vote-percentage models: annual and three-year operating override frequency associations with `oper_yes_vote_percent`.
     - Repeated-event DiD: event-time patterns for downgrade, upgrade, and any rating change around operating attempts, successes, and failures.

4. **File validation**
   - Render the active workflow first.
   - Confirm the slide-ready table/figure files exist.
   - Confirm `slides/NorthEast_workshop.qmd` references the expected generated result files.
   - Do not render the Beamer deck as part of this update.

## Slide Revision Plan

1. **Front sections reserved for manual update**
   - Do not edit or plan substantive changes for:
     - Motivation.
     - Massachusetts Proposition 2 1/2.
     - Research questions.
     - Dual-signal framework.
   - Begin Codex-supported slide updates at the data/design portion of the deck.

2. **Data and variables**
   - Replace old hard-coded sample bullets with active workflow counts.
   - State:
     - Constructed regression panel years: 2003-2021.
     - Moody's rating model complete-case years: 2003-2015, 2017, and 2019-2021.
     - Yes-vote-percentage model complete-case years: 2003-2021.
     - Repeated-event DiD event years: 2005-2019, with stacked observations from 2003-2021.
     - Override timing: source `FiscalYear` shifted forward one year.
     - Main rating outcome: `MOO_ordered`.
     - Voter-support outcome: `oper_yes_vote_percent`.
     - Repeated-event outcomes: `rating_downgrade`, `rating_upgrade`.
   - Remove voter turnout variables and broad all-override variables from the active empirical slides.

3. **Model specification slides**
   - Replace the generic credit-rating equation with ordered probit plus Mundlak controls:
     - `MOO_ordered ~ operating term + controls + Mundlak controls + factor(year)`
   - Replace the generic voter-support equation with:
     - `oper_yes_vote_percent ~ operating frequency + controls | code + year`
   - Add the repeated-event DiD formula:
     - `rating_change_outcome ~ i(rel_year, treated_event, ref = -1) | stack_id^code + stack_id^year`
   - Add notes for municipality-clustered standard errors.

4. **Results section**
   - Replace "Direct Effects of Property Tax Overrides" with "Operating Overrides and Moody's Ratings."
   - Replace fiscal-stress result slides with active result slides:
     - Recommended replacement: one slide for repeated-event sample construction and one slide for binary rating-change DiD.
   - Replace "Frequent Overrides and Voter Support" with "Operating Override Frequency and Yes Votes."
   - Add "Frequent Overrides and Credit Ratings" for the three-year cumulative frequency-on-rating model.

5. **Robustness and conclusion**
   - Replace the old robustness checklist with active robustness checks:
     - Never-treated controls.
     - Prior operating-event history controls.
     - First-time events only.
     - Narrow `h = -1, 0, 1` window.
   - Update conclusions to match active results only.
   - Avoid claiming H3/H4b support unless those models are reintroduced and regenerated.

## Proposed Deck Structure

User-maintained front sections:

1. Motivation
2. Massachusetts Proposition 2 1/2
3. Research questions
4. Dual-signal framework

Codex-supported update sections:

5. Data and active sample
6. Main rating model: ordered probit with Mundlak controls
7. Yes-vote-percentage model: fixed effects
8. Repeated-event DiD design
9. Operating overrides and Moody's ratings
10. Operating override frequency and Moody's ratings
11. Operating override frequency and yes-vote percentage
12. Repeated-event sample construction
13. Binary rating-change DiD results
14. Robustness checks
15. Discussion and conclusion

## Implementation Checklist

- [x] Run `R/15_run_all_active_workflow.R`.
- [x] Confirm all active outputs listed in `outputs/tables/active_workflow_outputs.csv` exist.
- [x] Create publication-quality slide-specific table outputs rather than relying on oversized active HTML tables.
- [x] Update `slides/NorthEast_workshop.qmd` section by section.
- [x] Remove all placeholder boxes.
- [x] Remove unsupported Stata-era result claims.
- [x] Confirm the deck references the generated result files.
- [x] Do not render the deck.

## Open Decisions Before Editing Slides

- Resolved for this update: the repeated-event DiD results are shown as compact coefficient tables, with event-study figures generated as supporting slide/report artifacts.
