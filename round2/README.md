# PACT Delphi — Round 2 analysis

Inclusion consensus and agreement statistics for Round 2 of the PACT Delphi,
in which panellists placed all 17 candidate cognitive tasks in a single order,
1 (highest priority for inclusion) to 17.

The Round 1 analysis is in [`../round1/`](../round1/). Neither round depends on
the other having been run.

---

## Quick start

```bash
cd round2
Rscript run_all.R
```

No panel data ships with this repository, so a fresh clone has nothing to
analyse until you supply an export. The pipeline stops with an instruction if
`data/raw/` is empty.

```bash
cp /path/to/pact_round2_rankings.csv data/raw/
Rscript run_all.R
# or point at a file directly:
Rscript run_all.R /path/to/pact_round2_rankings.csv
```

Requires R (developed against 4.4.1) and the `irr` package, installed on first
run if missing. Base graphics, no tidyverse — the analysis reproduces from a
bare R install.

## The headline statistic

For each task, the share of panellists who placed it in the **top 12** of their
own ranking:

```
p_top = panellists ranking the task <= 12  /  panellists submitting a complete ranking
```

A task reaches **inclusion consensus** when `p_top >= 0.80`, matching the
Round 1 consensus rule. Proportions carry Wilson 95% intervals.

Mean position is reported alongside but is deliberately not the rule. Two tasks
can share a mean position with quite different spreads — one placed 12th by
everybody, one placed 1st by half the panel and 17th by the other half — and
only the second is a disagreement.

## Configuration

Every study decision is in `R/00_config.R`:

```r
inclusion_threshold     = 0.80,   # >=80% placing the task in the top n_selected
n_selected              = 12L,    # size of the set the leadership round adopted
n_tasks                 = 17L,
response_rate_threshold = 0.80,   # >80% of those invited
n_invited               = 50L,
kendall_correct         = FALSE,  # a complete ranking has no ties to correct
presented_order         = c("T4", "T15", ...)   # the order every panellist saw
```

`field_open` and `field_close` are `NA` until the round's dates are set; the
report omits the fielding line while they are.

## What it computes

**Inclusion consensus** — `03_inclusion.R`. Per task: the count and share
placing it in the top 12, Wilson interval, mean / median / IQR / range of
positions, and the threshold verdict. Then the comparison that the round exists
to produce: each task is `confirmed`, `challenged`, `promoted` or `excluded`
relative to the 12 the leadership round proposed.

The number of tasks reaching consensus is reported as found. If it is not 12,
that is the finding — the set is not padded with tasks that failed the rule or
trimmed of tasks that passed it.

**Agreement** — `04_agreement.R`. Kendall's W over the 17 × panellists matrix
with a bootstrap CI, plus each panellist's leave-one-out Spearman correlation
against the rest of the panel. W measures agreement about the whole ordering,
not about the cut, which is why it is reported alongside the inclusion
proportions and never instead of them.

**Movement** — `05_displacement.R`. Because panellists adjusted a presented
order rather than building one, `rank - initial_rank` per panellist × task is
the informative quantity: how far the panel moved each task from where it was
put in front of them, which tasks crossed the 12-task cut in either direction,
and how many panellists changed nothing at all.

## Input format

One row per panellist × task:

```
reviewer_code,task_code,task_name,rank,initial_rank,submitted_at
```

Required: `reviewer_code`, `task_code`, `rank`. Optional and passed through:
`task_name`, `initial_rank`, `display_name`, `institution`, `title`,
`submitted_at`, `updated_at`. Without `initial_rank`, everything except the
displacement section still runs.

**Partial rankings are excluded whole, and reported.** Round 1 retained partial
responses for the dimensions answered, because rating task A says nothing about
task B. A partial ranking is different: positions are defined relative to one
another, so a panellist who placed nine tasks has not said where the other
eight sit and "top 12" is undefined for them.

## Output

Written to `output/`, all reproducible from `run_all.R`:

| File | Contents |
| --- | --- |
| `results_report.txt` | Every number quoted in the Round 2 results paragraph |
| `tables/table1_inclusion_consensus.csv` | The headline table, best first |
| `tables/table2_panel_vs_proposed.csv` | Confirmed / challenged / promoted / excluded |
| `tables/table3_agreement.csv` | Kendall's W with CI |
| `tables/table4_response_rate.csv` | Response rate vs the >80% threshold |
| `tables/table5_displacement.csv` | Movement from the presented order |
| `tables/s1`–`s5` | Long-format inclusion, completeness, crossings, per-panellist movement and concordance |
| `figures/fig1_inclusion_by_task.png` | Share in the top 12, threshold marked |
| `figures/fig2_rank_distribution.png` | Position distributions, cut marked |
| `figures/fig3_displacement.png` | Presented position vs mean assigned position |
| `results.rds` | The whole result object, for ad hoc follow-up |

## Layout of this folder

```
round2/
├── run_all.R              the whole analysis, top to bottom
├── R/
│   ├── 00_config.R        every study decision
│   ├── 01_setup.R         packages and shared helpers
│   ├── 02_load_clean.R    read, validate permutations, audit completeness
│   ├── 03_inclusion.R     the top-12 rule and the verdicts
│   ├── 04_agreement.R     Kendall's W, per-panellist concordance
│   ├── 05_displacement.R  movement from the presented order
│   ├── 06_response_rate.R response rate vs the 80% threshold
│   ├── 07_figures.R       base-graphics figures
│   └── 08_report.R        the plain-text results report
├── data/raw/              put the export here; gitignored
└── docs/methods.md        draft methods statement and claim-to-code map
```

## A note on the helpers

`01_setup.R` duplicates a few small helpers from `round1/R/01_setup.R`
(`wilson_ci`, `median_iqr`, the formatters) rather than sharing them through a
common file. That is deliberate: each round stays a self-contained analysis
that can be run, archived or cited on its own, and Round 1 is the analysis the
Methods statement points at, so it is not refactored to suit Round 2. Keep the
two in step if either changes.
