# ---------------------------------------------------------------------------
# 04_agreement.R -- Kendall's W, ICC, and between-dimension Spearman
#
# Agreement among panellists is reported as Kendall's coefficient of
# concordance (W) on the item rankings, with the intraclass correlation
# coefficient (two-way random effects, absolute agreement, average measures)
# as a secondary measure.
#
# Deliberately absent: kappa. The ratings are ordinal, and kappa scores a
# one-point disagreement and a four-point disagreement alike.
#
# Missing data. Both W and ICC need a complete tasks x panellists matrix. The
# protocol retains partial responses for the dimensions answered, so a partial
# panellist can appear for one dimension and not another. The rule here is to
# drop *panellists* with any missing rating on that dimension, keeping all
# tasks, and to report exactly who was dropped. Dropping tasks instead would
# change which items the concordance is measured over, which is worse.
# ---------------------------------------------------------------------------

#' Reduce a tasks x raters matrix to complete columns.
complete_raters <- function(m) {
  keep <- apply(m, 2, function(col) !anyNA(col))
  list(
    matrix        = m[, keep, drop = FALSE],
    n_raters_used = sum(keep),
    n_raters_all  = ncol(m),
    dropped       = colnames(m)[!keep]
  )
}

#' Kendall's W for one dimension, with a bootstrap CI over panellists.
#'
#' irr::kendall() takes objects in rows and raters in columns and ranks within
#' rater. correct = TRUE applies the tie correction, which matters here because
#' a 5-point scale over 17 tasks produces many ties.
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
      # A resample that draws the same panellist repeatedly can be degenerate;
      # NA out those replicates rather than letting them distort the interval.
      if (length(unique(idx)) < 2L) return(NA_real_)
      suppressWarnings(
        tryCatch(irr::kendall(cr$matrix[, idx, drop = FALSE],
                              correct = config$kendall_correct)$value,
                 error = function(e) NA_real_)
      )
    })
    reps <- reps[is.finite(reps)]
    if (length(reps) >= 100L) {
      ci <- unname(stats::quantile(reps, c(0.025, 0.975), na.rm = TRUE))
    }
  }

  # irr::kendall reports df only inside stat.name ("Chisq(16)"); for the
  # concordance chi-square it is simply (number of items - 1).
  list(
    W        = unname(k$value),
    chisq    = unname(k$statistic),
    df       = nrow(cr$matrix) - 1L,
    p        = unname(k$p.value),
    n_raters = cr$n_raters_used,
    n_items  = nrow(cr$matrix),
    dropped  = cr$dropped,
    ci       = ci
  )
}

#' ICC(2,k): two-way random effects, absolute agreement, average measures.
icc_agreement <- function(m, config = CONFIG) {

  cr <- complete_raters(m)
  if (cr$n_raters_used < 2L || nrow(cr$matrix) < 2L) {
    return(list(icc = NA_real_, lbound = NA_real_, ubound = NA_real_,
                p = NA_real_, n_raters = cr$n_raters_used,
                n_items = nrow(m), dropped = cr$dropped))
  }

  r <- irr::icc(cr$matrix, model = config$icc_model, type = config$icc_type,
                unit = config$icc_unit)

  list(
    icc      = unname(r$value),
    lbound   = unname(r$lbound),
    ubound   = unname(r$ubound),
    p        = unname(r$p.value),
    n_raters = cr$n_raters_used,
    n_items  = nrow(cr$matrix),
    dropped  = cr$dropped
  )
}

#' Agreement statistics for all three dimensions.
agreement_table <- function(d, config = CONFIG) {

  rows <- lapply(DIM_COLS, function(v) {
    m  <- rating_matrix(d, v)
    kw <- kendall_w(m, config)
    ic <- icc_agreement(m, config)

    data.frame(
      dimension     = v,
      label         = unname(config$dimensions[v]),
      n_items       = kw$n_items,
      n_raters_used = kw$n_raters,
      n_raters_all  = ncol(m),
      raters_dropped = if (length(kw$dropped)) paste(kw$dropped, collapse = "; ") else "",
      W             = kw$W,
      W_ci_lo       = kw$ci[1],
      W_ci_hi       = kw$ci[2],
      W_chisq       = kw$chisq,
      W_df          = kw$df,
      W_p           = kw$p,
      ICC           = ic$icc,
      ICC_ci_lo     = ic$lbound,
      ICC_ci_hi     = ic$ubound,
      ICC_p         = ic$p,
      stringsAsFactors = FALSE
    )
  })

  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' Manuscript-ready version of the agreement table.
format_agreement <- function(agr) {
  data.frame(
    Dimension = agr$label,
    `Items`   = agr$n_items,
    `Panellists` = ifelse(agr$n_raters_used == agr$n_raters_all,
                          as.character(agr$n_raters_used),
                          sprintf("%d of %d", agr$n_raters_used, agr$n_raters_all)),
    `Kendall W (95% CI)` = ifelse(
      is.na(agr$W_ci_lo),
      fmt_num(agr$W, 3),
      sprintf("%s (%s-%s)", fmt_num(agr$W, 3), fmt_num(agr$W_ci_lo, 3),
              fmt_num(agr$W_ci_hi, 3))),
    `W p value` = fmt_p(agr$W_p),
    `ICC (95% CI)` = sprintf("%s (%s-%s)", fmt_num(agr$ICC, 3),
                             fmt_num(agr$ICC_ci_lo, 3), fmt_num(agr$ICC_ci_hi, 3)),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
}

#' Spearman rank correlations between the three dimensions.
#'
#' Two levels, because they answer different questions:
#'   task  -- correlate the task-level mean rating across the 17 tasks. This is
#'            the one to report: it asks whether tasks that rank high on one
#'            dimension rank high on another.
#'   rating-- correlate individual ratings, pairwise complete. Sensitivity only;
#'            it treats each panellist x task as independent, which they are not.
spearman_dimensions <- function(d, level = c("task", "rating"), config = CONFIG) {

  level <- match.arg(level)

  if (level == "task") {
    tasks <- unique(d[order(d$task_order), "task_code"])
    mat <- vapply(DIM_COLS, function(v)
      vapply(tasks, function(tc)
        mean(d[[v]][d$task_code == tc], na.rm = TRUE), numeric(1)),
      numeric(length(tasks)))
    mat[!is.finite(mat)] <- NA_real_
    dimnames(mat) <- list(tasks, DIM_COLS)
  } else {
    mat <- as.matrix(d[, DIM_COLS])
  }

  combos <- utils::combn(DIM_COLS, 2)
  rows <- lapply(seq_len(ncol(combos)), function(i) {
    a <- combos[1, i]; b <- combos[2, i]
    ok <- stats::complete.cases(mat[, c(a, b)])
    n  <- sum(ok)
    if (n < 3L) {
      return(data.frame(level = level, dim_x = a, dim_y = b,
                        label_x = unname(config$dimensions[a]),
                        label_y = unname(config$dimensions[b]),
                        n = n, rho = NA_real_, p = NA_real_,
                        stringsAsFactors = FALSE))
    }
    # exact = FALSE: ties are expected on a 5-point scale, and the exact
    # permutation p value is not defined in their presence.
    ct <- suppressWarnings(stats::cor.test(mat[ok, a], mat[ok, b],
                                           method = "spearman", exact = FALSE))
    data.frame(
      level = level, dim_x = a, dim_y = b,
      label_x = unname(config$dimensions[a]),
      label_y = unname(config$dimensions[b]),
      n = n, rho = unname(ct$estimate), p = unname(ct$p.value),
      stringsAsFactors = FALSE
    )
  })

  out <- do.call(rbind, rows)
  out$summary <- sprintf("rho = %s (p %s%s)", fmt_num(out$rho, 2),
                         ifelse(out$p < 0.001, "", "= "), fmt_p(out$p))
  rownames(out) <- NULL
  out
}
