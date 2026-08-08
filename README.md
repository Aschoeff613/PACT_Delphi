# PACT_Delphi

Analysis code for the consensus and agreement analysis of the PACT Delphi
panel: a single-round rating exercise in which panellists rated candidate
high-risk cognitive tasks on three dimensions, used to select the final task
taxonomy.

This is the repository referenced by the Methods statement *"analysis code is
available at [repository]."*

Stanford HealthRex — PACT (human–AI teaming benchmark).

---

## Quick start

```bash
git clone https://github.com/Aschoeff613/PACT_Delphi.git
cd PACT_Delphi
Rscript run_all.R
```

With no data in `data/raw/`, the pipeline runs on the de-identified sample
shipped in `data/sample/` and says so loudly in the console and at the top of
the report. To run on the real panel export:

```bash
cp /path/to/panel_export.csv data/raw/
Rscript run_all.R
# or point at a file directly:
Rscript run_all.R /path/to/panel_export.csv
```

Requires R (developed against 4.4.1) and the `irr` and `psych` packages.
`run_all.R` installs them on first run if they are missing. No other
dependencies — base graphics, no tidyverse — so the analysis reproduces from a
bare R install.

---

## Before running on the real data

Open `R/00_config.R` and set:

```r
n_invited = NA_integer_,   # <- the number of panellists invited to Round 1
```

Everything else is already set to the prespecified values. The response rate
cannot be computed until `n_invited` is filled in; the pipeline warns rather
than guessing.

---

## What it computes

**Consensus.** Prespecified before Round 1 as **≥80% of responding panellists
rating a task 4 or 5** on a given dimension. The denominator is the number who
answered *that task on that dimension* — not the number invited, and not the
number who answered anything.

**Eligibility.** A task is eligible for the final taxonomy only if it meets the
threshold on **all three** dimensions. The leadership round then selects 12
from the eligible set using the dimension rankings, which the pipeline
produces. Tasks meeting the threshold on one dimension or none are recorded as
non-consensus and **retained in the record with the failing dimensions named**,
not deleted.

**Per dimension** the pipeline reports the number of respondents, the median
and IQR, and the proportion rating 4 or 5, with **exact counts alongside
percentages** (`13/17 (76.5%)`) and a Wilson 95% interval.

**Agreement** among panellists: Kendall's coefficient of concordance (*W*) on
the item rankings, tie-corrected, as the primary measure; the intraclass
correlation coefficient (**two-way random effects, absolute agreement, average
measures** — ICC(2,k)) as secondary.

**Between dimensions:** Spearman rank correlations, reported at task level
(task-mean rating across tasks) with a rating-level version as sensitivity.

**Response rate:** respondents / invited against the prespecified >70%
threshold, with the number of partial responses reported alongside.

**Not computed: kappa.** The ratings are ordinal and kappa scores a one-point
and a four-point disagreement alike. This is a deliberate omission, stated in
the Methods.

---

## Handling decisions worth knowing about

These are the places where a reasonable person could have done it differently,
so they are written down rather than buried.

**Partial responses.** Retained for the dimensions answered and excluded
elsewhere, per protocol. `output/tables/s6_respondent_completeness.csv` and
section 1 of the report give the count and the reviewer codes affected.

**Missing data in W and ICC.** Both need a complete tasks × panellists matrix.
The pipeline drops *panellists* with any missing rating on that dimension and
keeps all tasks, then names the excluded panellists in the report. Dropping
tasks instead would silently change which items the concordance is measured
over.

**Bootstrap interval on W.** Computed by resampling panellists with
replacement (2000 replicates, seeded). With a small panel this duplicates
panellists within a replicate and tends to pull *W* upward, so read it as
indicative of spread rather than a calibrated 95% interval. The chi-square
*p* value does not depend on it. Set `n_boot = 0` in the config to turn it off.

**Quantiles.** Type 6 (Minitab/SPSS definition) — the conventional choice for
small-sample ordinal survey data, and what a reader reproducing the IQR by hand
will get.

**Duplicate submissions.** If a panellist appears twice for the same task, the
most recent by `completed_at` is kept and a warning is raised. Never silent.

**Selection ranking.** Eligible tasks are ranked by the mean of the three
agreement proportions, ties broken by the lowest of the three, so a task strong
on all three outranks a lopsided one. This ranking informs the leadership
round; it does not replace it.

---

## Input format

One row per panellist × task. Required columns:

| Column | Meaning |
|---|---|
| `reviewer_code` | Panellist identifier (pseudonymous) |
| `task_code` | Task identifier, e.g. `T1` |
| `task_name` | Task description |
| `clinical_relevance` | Rating 1–5 |
| `performance_variance` | Rating 1–5 |
| `ai_relevance` | Rating 1–5 |

Optional and passed through if present: `specialty`, `institution`,
`flagged_for_discussion`, `comment`, `completed_at`.

This is the shape the Supabase export produces. `null`, `NA`, and empty strings
are all read as missing. Off-scale values are set to missing with a warning
rather than silently averaged.

---

## Output

Written to `output/`, which is gitignored — everything there is reproducible
from `run_all.R`, and committing it invites a stale table reaching the
manuscript.

```
output/
├── results_report.txt                 <- every number in the Results paragraph
├── results.rds                        <- all objects, for further analysis
├── session_info.txt                   <- R and package versions actually used
├── figures/
│   ├── fig1_consensus_by_task.png     <- % rating 4–5 by task, 80% line marked
│   └── fig2_rating_distribution.png
└── tables/
    ├── table1_consensus_by_task.csv   <- main consensus table
    ├── table2_agreement.csv           <- Kendall W and ICC
    ├── table3_response_rate.csv
    ├── s1_dimension_summary_long.csv
    ├── s2_task_classification.csv     <- eligibility, ranks, failing dimensions
    ├── s3_rankings_within_dimension.csv
    ├── s4_spearman_task_level.csv
    ├── s5_spearman_rating_level.csv
    └── s6_respondent_completeness.csv
```

`output/results_report.txt` is the one to read first — it is written so the
numbers in the manuscript can be generated rather than transcribed.

---

## Repository layout

```
R/
├── 00_config.R        thresholds, dimensions, paths — all study decisions
├── 01_setup.R         packages, formatting and small stats helpers
├── 02_load_clean.R    read, coerce, de-duplicate, audit completeness
├── 03_consensus.R     per-dimension summaries, 80% rule, eligibility
├── 04_agreement.R     Kendall W, ICC(2,k), Spearman
├── 05_response_rate.R response rate vs the 70% threshold
├── 06_figures.R       figures (base graphics)
└── 07_report.R        assembles output/results_report.txt
run_all.R              runs everything
data/
├── raw/               real panel data (gitignored)
└── sample/            de-identified sample, tracked
docs/methods.md        the Methods text this code implements
```

---

## Data and privacy

Real panel data — anything with panellist names, emails, or institutions — goes
in `data/raw/`, which is gitignored. The sample in `data/sample/` has names,
emails, and institutions removed; reviewer codes, specialty, ratings, and
free-text comments are retained.

Sample results are illustrative only. With six respondents, the 80% threshold
requires 5 of 5 or 5 of 6, so the eligible set from the sample is not
informative about what the full panel will produce.

---

## Reproducibility

`run_all.R` writes `output/session_info.txt` with the R and package versions
actually used. The bootstrap is seeded (`CONFIG$boot_seed`), so repeated runs
on the same data give identical intervals.

The Methods text states R 4.4.1; if you run under a different version, the
session info records it and the Methods should be updated to match rather than
the other way round.
