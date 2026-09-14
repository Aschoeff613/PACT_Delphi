# ---------------------------------------------------------------------------
# 04_agreement.R -- Kendall's W over the rankings
#
# Concordance among panellists, computed on the tasks x panellists matrix of
# ranks. W = 1 is perfect agreement on the ordering, W = 0 is none.
#
# Two differences from Round 1's agreement module, both because the input is a
# ranking rather than a rating:
#
#   - No tie correction. A complete 1..17 ranking has no ties by construction,
#     so there is nothing to correct. Round 1 needed it: a 5-point scale over
#     17 tasks produces many ties.
#
#   - No ICC. The intraclass correlation treats the numbers as measurements on
#     a common scale with meaningful spacing. Ranks are not that: the gap
#     between 1st and 2nd is not comparable to the gap between 9th and 10th,
#     and every panellist uses exactly the same set of numbers, so the
#     between-target variance ICC relies on is an artefact of the format.
#
# One thing W will not tell you: whether the panel agrees about the *cut*. Two
# panels can share a W while disagreeing entirely about which tasks make the
# top 12, so W is reported alongside the inclusion proportions in
# 03_inclusion.R, never instead of them.
# ---------------------------------------------------------------------------

#' Keep only panellists with a complete column of ranks.
complete_raters <- function(m) {
  keep <- apply(m, 2, function(col) !anyNA(col))
  list(
    matrix        = m[, keep, drop = FALSE],
    n_raters_used = sum(keep),
    n_raters_all  = ncol(m),
    dropped       = colnames(m)[!keep]
  )
}

#' Kendall's W with a bootstrap CI over panellists.
#'
#' irr::kendall() takes objects in rows and raters in columns.
kendall_w <- function(m, config = CONFIG) {

  cr <- complete_raters(m)
  if (cr$n_raters_used < 2L || nrow(cr$matrix) < 2L) {
    return(list(W = NA_real_, chisq = NA_real_, df = NA_real_, p = NA_real_,
                n_raters = cr$n_raters_used, n_items = nrow(m),
                dropped = cr$dropped, ci = c(NA_real_, NA_real_)))
  }

  k <- irr::kendall(cr$matrix, correct = config$kendall_correct)

  ci <- c(NA_real_, NA_real_)
  if (isTRUE(config$n_boot > 0) && cr$n_raters_used >= 3L) {
    set.seed(config$boot_seed)
    reps <- replicate(config$n_boot, {
      idx <- sample.int(cr$n_raters_used, cr$n_raters_used, replace = TRUE)
      # A resample drawing one panellist repeatedly is degenerate; NA those
      # replicates rather than letting them distort the interval.
      if (length(unique(idx)) < 2L) return(NA_real_)
      suppressWarnings(
        tryCatch(irr::kendall(cr$matrix[, idx, drop = FALSE],
                              correct = config$kendall_correct)$value,
                 error = function(e) NA_real_)
      )
    })
    reps <- reps[!is.na(reps)]
    if (length(reps) >= 100L) {
      ci <- unname(stats::quantile(reps, c(0.025, 0.975), names = FALSE))
    }
  }

  # irr::kendall reports df only inside stat.name ("Chisq(16)"), so it is
  # derived here rather than read off the object -- k$df1 does not exist, and
  # reading it yields NULL, which silently drops a row from the output table.
  # Same derivation as round1/R/04_agreement.R.
  list(
    W = k$value, chisq = k$statistic, df = nrow(cr$matrix) - 1L, p = k$p.value,
    n_raters = cr$n_raters_used, n_items = nrow(cr$matrix),
    dropped = cr$dropped, ci = ci
  )
}

#' Agreement between each panellist's ranking and the panel's mean ranking.
#'
#' Spearman rho per panellist against the mean rank of every other panellist --
#' leave-one-out, so a panellist is not correlated with a mean they helped
#' make. Low values flag a panellist ranking against the grain, which is a
#' finding rather than a fault.
per_rater_concordance <- function(m) {

  cr <- complete_raters(m)
  mm <- cr$matrix
  if (cr$n_raters_used < 3L) {
    return(data.frame(reviewer_code = colnames(mm), rho = NA_real_,
                      stringsAsFactors = FALSE))
  }

  rho <- vapply(seq_len(ncol(mm)), function(j) {
    others <- rowMeans(mm[, -j, drop = FALSE])
    suppressWarnings(stats::cor(mm[, j], others, method = "spearman"))
  }, numeric(1))

  out <- data.frame(reviewer_code = colnames(mm), rho = rho,
                    stringsAsFactors = FALSE)
  out <- out[order(out$rho), , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' Printable agreement table.
agreement_table <- function(kw, config = CONFIG) {
  data.frame(
    Statistic = c("Kendall's W", "chi-squared", "df", "p",
                  "Panellists", "Tasks"),
    Value = c(
      sprintf("%s%s", fmt_num(kw$W, 3),
              if (all(is.na(kw$ci))) "" else
                sprintf(" (95%% CI %s-%s)", fmt_num(kw$ci[1], 3),
                        fmt_num(kw$ci[2], 3))),
      fmt_num(kw$chisq, 2),
      as.character(kw$df),
      fmt_p(kw$p),
      as.character(kw$n_raters),
      as.character(kw$n_items)
    ),
    check.names = FALSE, stringsAsFactors = FALSE
  )
}
