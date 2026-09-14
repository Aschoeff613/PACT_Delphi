# Round 2 — methods

A paragraph for the manuscript, then the map from each claim to the code that
produces it. Companion to `round1/docs/methods.md`.

---

## Draft methods statement

> **Round 2: ranking.** Round 1 rated each candidate task in isolation, which
> left more tasks eligible than the final taxonomy could hold and gave no
> ordering within the eligible set. Panellists were therefore asked in Round 2
> to place all 17 candidate tasks in a single order, from 1 (highest priority
> for inclusion in the benchmark) to 17. Every panellist was shown the same
> starting order — the 12 tasks adopted at the leadership consensus meeting
> first, then the 5 that were not selected, each group in descending Round 1
> composite score — together with each task's Round 1 group means on the three
> rating dimensions, and was asked to move any task whose position they
> disagreed with. Presenting the group's Round 1 results back to the panel is
> the controlled feedback step of a modified Delphi.
>
> **Inclusion consensus.** Consensus for inclusion was defined, in line with
> the Round 1 rule, as at least 80% of panellists submitting a complete ranking
> placing the task within the top 12 positions of their own ordering. The
> denominator is complete rankings rather than the number invited. Proportions
> are reported with Wilson 95% intervals, since a point estimate on a panel of
> this size overstates precision. Mean and median positions are reported
> alongside but were not the decision rule: two tasks can share a mean position
> with quite different spreads, and only a split panel is a disagreement.
>
> **Agreement and movement.** Concordance across panellists was summarised with
> Kendall's coefficient of concordance (W) over the 17 × panellists matrix of
> positions, without tie correction since a complete ranking has no ties, and
> with a bootstrap confidence interval over panellists. Because panellists
> adjusted a presented order rather than building one, each task's displacement
> from its presented position was also recorded, along with movements across the
> 12-task cut in either direction.
>
> **Limitations.** Panellists were shown an order rather than asked to construct
> one, so the result measures adjustment from an anchor: agreement with the
> presented order is weaker evidence than an unanchored ranking would provide,
> and the Round 2 ordering correlates with the Round 1 composite partly because
> the composite was shown. Round 2 was fielded once, so stability across
> repetitions could not be assessed. The size of the set (12) was inherited from
> the leadership round rather than derived from the data.

---

## The instrument

Panellists signed in with the same credentials as Round 1 and were shown a
single page: 17 bars in a fixed vertical order, dragged to reorder, with a
labelled line drawn after position 12. Each bar carried that task's Round 1
group means for clinical relevance, performance variance and AI augmentation
potential, plus the unweighted mean of the three. Nothing was saved until
submission, and panellists could return and revise.

Source: [PACT_Delphi_Round2](https://github.com/Aschoeff613/PACT_Delphi_Round2).

The order as presented is declared in `CONFIG$presented_order` and also
recorded per submission as `initial_rank`. `02_load_clean.R` checks the two
against each other and warns if they disagree, rather than trusting either.

## Claim to code

| Claim | Where | Output |
| --- | --- | --- |
| All 17 placed in one order, 1 to 17 | `CONFIG$n_tasks`, `rank_min`, `rank_max` | report §0 |
| Same starting order for every panellist | `CONFIG$presented_order`; `presented_order_from_data()` | report §0 |
| Complete rankings only; partials excluded | `audit_rankings()`, `complete_rankings_only()` | `s2`, report §1 |
| Response rate against >80% | `response_rate()` in `06_response_rate.R` | `table4` |
| ≥80% placing a task in the top 12 | `CONFIG$inclusion_threshold`, `CONFIG$n_selected`; `inclusion_summary()` | `table1`, report §2 |
| Wilson 95% intervals | `wilson_ci()` in `01_setup.R` | `table1`, `fig1` |
| Mean / median / IQR position | `inclusion_summary()` via `median_iqr()` | `table1`, `fig2` |
| Panel verdict against the proposed 12 | `compare_with_presented()` | `table2`, report §3 |
| Consensus set reported as found, not trimmed to 12 | `consensus_set()` | report §2 |
| Kendall's W, no tie correction, bootstrap CI | `CONFIG$kendall_correct = FALSE`; `kendall_w()` | `table3`, report §4 |
| Per-panellist concordance, leave-one-out | `per_rater_concordance()` | `s5` |
| Displacement from the presented position | `displacement_summary()` | `table5`, `fig3` |
| Movements across the 12-task cut | `cut_crossings()` | `s3` |
| Panellists who changed nothing | `per_rater_displacement()` | `s4`, report §5 |
| Anchoring, single round, inherited set size | Stated in report §6 | report §6 |

## Input format

One row per panellist × task, as the instrument's export produces:

```
reviewer_code,task_code,task_name,rank,initial_rank,submitted_at
```

`rank` is the position the panellist assigned, 1 to 17. `initial_rank` is the
position the task held in the list as presented. Optional and passed through if
present: `display_name`, `institution`, `title`, `updated_at`.

The export query is in the instrument repository's README. Put the CSV in
`data/raw/` — one file — or pass a path:

```bash
Rscript run_all.R /path/to/pact_round2_rankings.csv
```

## Verdict categories

`table2_panel_vs_proposed.csv` assigns every task one of four verdicts. The two
disagreements are what the round hands back to the leadership group:

| Verdict | Meaning |
| --- | --- |
| `confirmed` | Proposed for the benchmark, and reached consensus |
| `challenged` | Proposed for the benchmark, but did **not** reach consensus |
| `promoted` | Not proposed, but reached consensus |
| `excluded` | Not proposed, and did not reach consensus |

## What is deliberately absent

- **Kappa.** As in Round 1: the data are ordinal and kappa scores a one-place
  disagreement and a sixteen-place disagreement alike.
- **ICC.** It treats positions as measurements on a common scale with
  meaningful spacing. Ranks are not that, and every panellist uses exactly the
  same set of numbers, so the between-target variance it relies on is an
  artefact of the format.
- **A composite of Round 1 and Round 2 into one score.** The two rounds asked
  different questions of the same panel; averaging them would hide which round
  produced which part of the answer.
