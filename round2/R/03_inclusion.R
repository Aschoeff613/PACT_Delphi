# ---------------------------------------------------------------------------
# 03_inclusion.R -- the top-n consensus rule, and eligibility
#
# The Round 2 question is not "what is the average rank" but "does the panel
# agree this task belongs in the benchmark". So the headline statistic is the
# share of panellists who placed a task in the top n_selected positions of
# their own ranking:
#
#     p_top = (panellists ranking the task <= 12) / (panellists submitting a
#              complete ranking)
#
# A task reaches inclusion consensus when p_top >= inclusion_threshold (0.80).
#
# The denominator is complete submissions, not the number invited: a panellist
# who did not answer tells us nothing about where they would have put a task.
# That matches Round 1, where the consensus denominator was panellists who
# answered that task on that dimension.
#
# Mean rank is reported alongside but is deliberately not the rule. Two tasks
# can share a mean rank with quite different spreads -- one placed 12th by
# everybody, one placed 1st by half the panel and 17th by the other half -- and
# only the second is a disagreement. The proportion crossing the cut, with its
# interval, is the quantity the selection decision actually turns on.
# ---------------------------------------------------------------------------

#' Per-task inclusion consensus, rank summary, and threshold verdict.
inclusion_summary <- function(d, config = CONFIG) {

  n_raters <- length(unique(d$reviewer_code))
  by_task  <- split(d, d$task_code)

  rows <- lapply(names(by_task), function(code) {
    r  <- by_task[[code]]
    rk <- r$rank[!is.na(r$rank)]

    k  <- sum(rk <= config$n_selected)
    n  <- length(rk)
    ci <- wilson_ci(k, n)
    mi <- median_iqr(rk, digits = 1)

    data.frame(
      task_code     = code,
      task_name     = r$task_name[1],
      task_order    = r$task_order[1],
      n_raters      = n,
      n_top         = k,
      p_top         = if (n > 0) k / n else NA_real_,
      ci_lower      = ci[["lower"]],
      ci_upper      = ci[["upper"]],
      mean_rank     = if (n > 0) mean(rk) else NA_real_,
      median_rank   = mi$median,
      q1_rank       = mi$q1,
      q3_rank       = mi$q3,
      best_rank     = if (n > 0) min(rk) else NA_integer_,
      worst_rank    = if (n > 0) max(rk) else NA_integer_,
      stringsAsFactors = FALSE
    )
  })

  out <- do.call(rbind, rows)
  out$consensus <- !is.na(out$p_top) & out$p_top >= config$inclusion_threshold

  # Ordered by the rule, best first, with mean rank breaking ties: two tasks on
  # the same proportion are not equally placed if one sits higher in the lists
  # that included it.
  out <- out[order(-out$p_top, out$mean_rank, out$task_order), , drop = FALSE]
  out$consensus_rank <- seq_len(nrow(out))
  rownames(out) <- NULL

  attr(out, "n_raters") <- n_raters
  out
}

#' Compare the panel's verdict with the set the team proposed.
#'
#' This is the output the round exists to produce. Four cases, and the two
#' disagreements are what the leadership round has to decide about:
#'
#'   confirmed  -- presented in the top 12 and reaches consensus
#'   challenged -- presented in the top 12 but does not reach consensus
#'   promoted   -- presented below the line but reaches consensus
#'   excluded   -- presented below the line and does not reach consensus
compare_with_presented <- function(inclusion, presented, config = CONFIG) {

  proposed <- presented$order[seq_len(config$n_selected)]

  out <- inclusion[, c("task_code", "task_name", "n_raters", "n_top", "p_top",
                       "ci_lower", "ci_upper", "mean_rank", "median_rank",
                       "consensus", "consensus_rank")]
  out$presented_rank <- match(out$task_code, presented$order)
  out$was_proposed   <- out$task_code %in% proposed

  out$verdict <- ifelse(out$was_proposed & out$consensus,  "confirmed",
                 ifelse(out$was_proposed & !out$consensus, "challenged",
                 ifelse(!out$was_proposed & out$consensus, "promoted",
                                                            "excluded")))

  out <- out[order(out$presented_rank), , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' The set the panel's own rule would adopt.
#'
#' Reported as a set rather than a ranking. If the number reaching consensus is
#' not n_selected, that is the finding and it is not quietly trimmed to 12:
#' padding the set with tasks that failed the rule, or dropping tasks that
#' passed it, would substitute the analyst's judgement for the panel's.
consensus_set <- function(inclusion, config = CONFIG) {
  passing <- inclusion[inclusion$consensus, , drop = FALSE]
  list(
    tasks        = passing$task_code,
    names        = passing$task_name,
    n            = nrow(passing),
    n_expected   = config$n_selected,
    matches_size = nrow(passing) == config$n_selected
  )
}

#' Printable inclusion table for the supplement.
inclusion_table <- function(inclusion, config = CONFIG) {
  out <- data.frame(
    Rank      = inclusion$consensus_rank,
    `Task ID` = inclusion$task_code,
    Task      = inclusion$task_name,
    n         = inclusion$n_raters,
    `In top n` = mapply(n_pct, inclusion$n_top, inclusion$n_raters),
    `95% CI`  = sprintf("%s-%s",
                        fmt_num(100 * inclusion$ci_lower, 1),
                        fmt_num(100 * inclusion$ci_upper, 1)),
    `Mean rank`   = fmt_num(inclusion$mean_rank, 2),
    `Median (IQR)` = sprintf("%s (%s-%s)",
                             fmt_num(inclusion$median_rank, 1),
                             fmt_num(inclusion$q1_rank, 1),
                             fmt_num(inclusion$q3_rank, 1)),
    Range = sprintf("%d-%d", inclusion$best_rank, inclusion$worst_rank),
    `Consensus` = ifelse(inclusion$consensus, "yes", "no"),
    check.names = FALSE, stringsAsFactors = FALSE
  )

  # The column heading follows n_selected rather than hardcoding 12, so a
  # changed cut cannot leave the table mislabelled.
  names(out)[names(out) == "In top n"] <- sprintf("In top %d", config$n_selected)
  out
}
