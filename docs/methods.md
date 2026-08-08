# Methods text implemented by this repository

The paragraph below is the prespecified analysis plan. Each sentence is
annotated with where in the code it is implemented, so a reader can check that
the code does what the manuscript says.

---

> **Consensus and analysis.** Consensus was defined before Round 1 as at least
> 80% of responding panellists rating a task 4 or 5 on a given dimension. A
> task was eligible for the final taxonomy only if it met that threshold on all
> three dimensions; the leadership round then selected 12 from the eligible set
> using the dimension rankings. Tasks meeting the threshold on one dimension or
> none were recorded as non-consensus and retained in the record rather than
> deleted.
>
> For each dimension we report the number of respondents, the median and IQR,
> and the proportion rating 4 or 5, with exact counts alongside percentages.
> Agreement among panellists is reported as Kendall coefficient of concordance
> (W) on the item rankings, with the intraclass correlation coefficient (two-way
> random effects, absolute agreement, average measures) as a secondary measure.
> We report Spearman rank correlations between the three dimensions. Ratings are
> ordinal, so we do not report kappa statistics, which score a one-point and a
> four-point disagreement alike. A single rating round means stability of
> ratings across rounds could not be assessed.
>
> Panel response rate is reported as respondents divided by invited, against the
> prespecified threshold of more than 70%. Partially completed responses were
> retained for the dimensions answered and excluded elsewhere, and the number
> affected is reported. Analyses were conducted in R version 4.4.1 (R Foundation
> for Statistical Computing) using the irr and psych packages; analysis code is
> available at https://github.com/Aschoeff613/PACT_Delphi.

---

## Sentence-by-sentence mapping

| Methods statement | Implementation | Output |
|---|---|---|
| Consensus = ≥80% rating 4 or 5 | `CONFIG$consensus_threshold`, `CONFIG$consensus_rating_min`; `summarise_dimension()` in `R/03_consensus.R` | `table1`, `s1` |
| Denominator is *responding* panellists | `summarise_dimension()` drops `NA` before counting, so `n` is per task × dimension | `n` column in every table |
| Eligible only if threshold met on all three dimensions | `classify_tasks()`, `eligible` column | `s2` |
| Leadership round selects 12 from the eligible set using dimension rankings | `CONFIG$n_final_taxonomy`; `rank_within_dimension()` and `selection_rank` | `s3`, report §3 |
| Non-consensus tasks retained, not deleted | `classify_tasks()` keeps every task and records `status` and `dimensions_not_met` | `s2`, report §3 |
| Number of respondents, median and IQR, proportion 4–5 | `median_iqr()` (type 6 quantiles), `n_pct()`, `wilson_ci()` in `R/01_setup.R` | `table1`, `s1` |
| Exact counts alongside percentages | `agree_label`, formatted `13/17 (76.5%)` | `table1` |
| Kendall's W on item rankings | `kendall_w()` → `irr::kendall(..., correct = TRUE)` | `table2`, report §4 |
| ICC, two-way random, absolute agreement, average measures | `icc_agreement()` → `irr::icc(model = "twoway", type = "agreement", unit = "average")` | `table2` |
| Spearman between the three dimensions | `spearman_dimensions()`, task level primary, rating level as sensitivity | `s4`, `s5` |
| Kappa not reported | Not implemented, by design; the reason is printed in report §4 | report §4 |
| Single round, stability not assessable | Stated in report §6 | report §6 |
| Response rate vs >70% | `response_rate()` in `R/05_response_rate.R` | `table3` |
| Partial responses retained per dimension, number reported | `audit_completeness()`; per-dimension `NA` handling throughout | `s6`, report §1 |
| R 4.4.1, irr and psych | `REQUIRED_PKGS` in `R/01_setup.R`; actual versions recorded at run time | `session_info.txt` |

## Additions beyond the Methods text

Three things the code reports that the paragraph does not promise. Each is
supplementary and can be dropped from the manuscript without affecting
anything above.

1. **Wilson 95% intervals** on the agreement proportions and the response rate.
   A point estimate from a panel this size overstates precision.
2. **Bootstrap interval on Kendall's W** (2000 replicates over panellists,
   seeded). Upward-biased with a small panel because resampling duplicates
   panellists — indicative of spread, not a calibrated interval.
3. **Rating-level Spearman** alongside the task-level correlations, as a
   sensitivity check. It treats each panellist × task as independent, which
   they are not, so the task-level version is the one to report.
