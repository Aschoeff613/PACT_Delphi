# ---------------------------------------------------------------------------
# 03_consensus.R -- per-dimension summaries, the 80% rule, and eligibility
#
# Consensus was defined before Round 1 as at least 80% of *responding*
# panellists rating a task 4 or 5 on a given dimension. The denominator is
# therefore the number of panellists who answered that task on that dimension,
# not the number invited and not the number who answered anything at all.
#
# A task is eligible for the final taxonomy only if it clears the threshold on
# all three dimensions. Tasks clearing one dimension or none are recorded as
# non-consensus and retained -- nothing is dropped from the record.
# ---------------------------------------------------------------------------

#' Per-task, per-dimension summary.
#'
#' Returns one row per task x dimension with n, median, IQR, the count and
#' proportion rating 4-5, its Wilson interval, and the consensus flag.
summarise_dimension <- function(d, dim_col, config = CONFIG) {

  tasks <- unique(d[order(d$task_order), c("task_code", "task_name", "task_order")])

  rows <- lapply(seq_len(nrow(tasks)), function(i) {
    x  <- d[[dim_col]][d$task_code == tasks$task_code[i]]
    x  <- x[!is.na(x)]
    n  <- length(x)
    k  <- sum(x >= config$consensus_rating_min)
    mi <- median_iqr(x)
    ci <- wilson_ci(k, n)

    data.frame(
      task_code   = tasks$task_code[i],
      task_name   = tasks$task_name[i],
      task_order  = tasks$task_order[i],
      dimension   = dim_col,
      dim_label   = unname(config$dimensions[dim_col]),
      n           = n,
      n_missing   = sum(d$task_code == tasks$task_code[i]) - n,
      median      = mi$median,
      q1          = mi$q1,
      q3          = mi$q3,
      median_iqr  = mi$label,
      n_agree     = k,
      prop_agree  = if (n > 0) k / n else NA_real_,
      pct_agree   = if (n > 0) 100 * k / n else NA_real_,
      agree_ci_lo = 100 * ci[["lower"]],
      agree_ci_hi = 100 * ci[["upper"]],
      agree_label = n_pct(k, n),
      consensus   = if (n > 0) (k / n) >= config$consensus_threshold else NA,
      stringsAsFactors = FALSE
    )
  })

  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' All three dimensions, stacked long.
summarise_all_dimensions <- function(d, config = CONFIG) {
  out <- do.call(rbind, lapply(DIM_COLS, function(v)
    summarise_dimension(d, v, config)))
  out$dimension <- factor(out$dimension, levels = DIM_COLS)
  out <- out[order(out$task_order, out$dimension), ]
  rownames(out) <- NULL
  out
}

#' Eligibility: consensus on all three dimensions.
#'
#' `n_dimensions_met` is the number of dimensions (0-3) on which the task
#' cleared the threshold. Tasks are classified so that the non-consensus ones
#' stay in the record with a reason attached, rather than vanishing.
classify_tasks <- function(dim_summary, config = CONFIG) {

  tasks <- unique(dim_summary[order(dim_summary$task_order),
                              c("task_code", "task_name", "task_order")])

  wide <- lapply(DIM_COLS, function(v) {
    s <- dim_summary[dim_summary$dimension == v, ]
    s <- s[match(tasks$task_code, s$task_code), ]
    setNames(
      data.frame(s$n, s$median_iqr, s$agree_label, s$pct_agree, s$consensus,
                 stringsAsFactors = FALSE),
      paste0(v, c("_n", "_median_iqr", "_agree", "_pct_agree", "_consensus"))
    )
  })

  out <- cbind(tasks, do.call(cbind, wide))

  met <- vapply(DIM_COLS, function(v) {
    x <- out[[paste0(v, "_consensus")]]
    ifelse(is.na(x), FALSE, x)
  }, logical(nrow(out)))
  if (is.null(dim(met))) met <- matrix(met, nrow = nrow(out))

  out$n_dimensions_met <- rowSums(met)
  out$eligible <- out$n_dimensions_met == length(DIM_COLS)

  out$status <- ifelse(
    out$eligible, "Eligible (consensus on all three dimensions)",
    ifelse(out$n_dimensions_met == 2, "Non-consensus (two dimensions)",
    ifelse(out$n_dimensions_met == 1, "Non-consensus (one dimension)",
                                      "Non-consensus (no dimension)")))

  # Which dimensions failed, so the record says why rather than just that.
  out$dimensions_not_met <- apply(met, 1, function(r) {
    f <- DIM_LABELS[!r]
    if (!length(f)) "" else paste(f, collapse = "; ")
  })

  # Ranking used by the leadership round to pick the final taxonomy from the
  # eligible set: mean of the three agreement proportions, ties broken by the
  # lowest of the three (a task strong on all three outranks a lopsided one).
  pct <- as.matrix(out[, paste0(DIM_COLS, "_pct_agree")])
  out$mean_pct_agree <- rowMeans(pct, na.rm = TRUE)
  out$min_pct_agree  <- suppressWarnings(apply(pct, 1, min, na.rm = TRUE))
  out$min_pct_agree[!is.finite(out$min_pct_agree)] <- NA_real_

  out$selection_rank <- NA_integer_
  el <- which(out$eligible)
  if (length(el)) {
    ord <- el[order(-out$mean_pct_agree[el], -out$min_pct_agree[el],
                    out$task_order[el])]
    out$selection_rank[ord] <- seq_along(ord)
  }

  rownames(out) <- NULL
  out
}

#' Per-dimension ranking of tasks, which is what the leadership round was given.
rank_within_dimension <- function(dim_summary) {
  out <- do.call(rbind, lapply(split(dim_summary, dim_summary$dimension), function(s) {
    s <- s[order(-s$prop_agree, -s$median, s$task_order), ]
    s$rank <- seq_len(nrow(s))
    s
  }))
  rownames(out) <- NULL
  out[, c("dimension", "dim_label", "rank", "task_code", "task_name",
          "n", "median_iqr", "agree_label", "pct_agree", "consensus")]
}

#' One-line-per-task consensus summary, formatted for the manuscript.
consensus_table <- function(classified, config = CONFIG) {
  data.frame(
    Task        = classified$task_code,
    Description = classified$task_name,
    `Clinical relevance, n`        = classified$clinical_relevance_n,
    `Clinical relevance, median (IQR)`  = classified$clinical_relevance_median_iqr,
    `Clinical relevance, 4-5`      = classified$clinical_relevance_agree,
    `Performance variance, n`      = classified$performance_variance_n,
    `Performance variance, median (IQR)`= classified$performance_variance_median_iqr,
    `Performance variance, 4-5`    = classified$performance_variance_agree,
    `AI relevance, n`              = classified$ai_relevance_n,
    `AI relevance, median (IQR)`   = classified$ai_relevance_median_iqr,
    `AI relevance, 4-5`            = classified$ai_relevance_agree,
    `Dimensions meeting threshold` = classified$n_dimensions_met,
    Status      = classified$status,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
}
