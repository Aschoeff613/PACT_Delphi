# PACT_Delphi

Analysis code for the PACT Delphi, the modified Delphi process used to select
the final set of high-risk clinical cognitive tasks for the PACT human–AI
teaming benchmark.

This is the repository referenced by the Methods statement *"analysis code is
available at [repository]."*

Stanford HealthRex — PACT.

---

## The two rounds

The Delphi ran in two rounds, which ask different questions and so need
different statistics. Each round is a self-contained analysis in its own
folder, with its own config, pipeline, docs and output.

| Folder | Round | What panellists did | Headline statistic |
| --- | --- | --- | --- |
| [`round1/`](round1/) | Round 1 | Rated all 17 candidate tasks on three 1–5 dimensions | Share rating a task 4 or 5 on a dimension, against the 80% consensus rule |
| [`round2/`](round2/) | Round 2 | Placed all 17 tasks in a single order, 1 to 17 | Share placing a task in the top 12, against the same 80% rule |

```bash
cd round1 && Rscript run_all.R     # consensus and agreement on the ratings
cd round2 && Rscript run_all.R     # inclusion consensus on the rankings
```

Each round installs what it needs on first run and writes to its own
`output/`. Neither needs the other to have been run.

## Consensus threshold

**80% throughout, in both rounds.** A task has consensus on a dimension
(Round 1) or for inclusion (Round 2) when at least 80% of *responding*
panellists put it there.

The threshold was prespecified at 80%, briefly lowered to 70% in this
repository, and restored to 80% at reviewer request. Supplementary Table S1
reports 80%, so the code and the supplement now agree. Both rounds read the
value from their own config — `round1/R/00_config.R`
(`consensus_threshold`) and `round2/R/00_config.R` (`inclusion_threshold`) —
and nothing hardcodes it.

The response-rate threshold is a separate thing and remains at >70% in both
rounds. It is not a consensus threshold, and the reviewer request was about
consensus.

## Why Round 2 is not just Round 1 with different numbers

Round 1 asked how good each task was in isolation, which left the eligible set
larger than the final taxonomy and gave no ordering inside it. Round 2 asked
panellists to order all 17 against one another, starting from the set the
leadership round had adopted.

That changes what the analysis has to do, and three differences are worth
knowing before reading `round2/`:

- **Partial responses are dropped, not retained.** Round 1 kept a partial
  response for the dimensions answered, because rating task A says nothing
  about task B. Positions are relative, so a partial ranking leaves "top 12"
  undefined for that panellist.
- **No ICC, and no tie correction on Kendall's W.** A complete 1–17 ranking has
  no ties, and the intraclass correlation assumes spacing between values that
  ranks do not have.
- **Anchoring is part of the design.** Round 2 showed every panellist the same
  proposed order and asked them to adjust it — the controlled feedback step of
  a Delphi. So agreement with that order is weaker evidence than an unanchored
  ranking would give, and `round2/` records how far each task moved
  (`initial_rank`) precisely so that can be measured rather than assumed.

## Data and privacy

No panel data is tracked in this repository, de-identified or otherwise.
Reviewer codes, timestamps and free-text comments are re-identifying in a
panel this small, so ratings and ranking files stay out of version control
entirely: `*/data/raw/` is gitignored and a fresh clone has nothing to analyse
until an export is supplied.

## Requirements

R 4.4.1 or later. Round 1 uses `irr` and `psych`; Round 2 uses `irr`. Both
install what is missing on first run. No tidyverse dependency in either, so
the analyses reproduce from a bare R install.

## Related repositories

| Repository | Role |
| --- | --- |
| [expert-case-review-PACT](https://github.com/perezcodex/expert-case-review-PACT) | The Round 1 instrument — the web app panellists rated in |
| [PACT_Delphi_Round2](https://github.com/Aschoeff613/PACT_Delphi_Round2) | The Round 2 instrument — the ranking app |
| [PACT_Literature_Review](https://github.com/Aschoeff613/PACT_Literature_Review) | Task taxonomy derivation, including `taxonomy/pact_17_tasks.json` |
