# ---------------------------------------------------------------------------
# 07_report.R -- assemble a plain-text results report
#
# The point of this file: the numbers that go into the manuscript should be
# generated, not transcribed. Every figure quoted in the Results paragraph
# appears in output/results_report.txt, produced by the same run that made the
# tables.
# ---------------------------------------------------------------------------

build_report <- function(res, config = CONFIG) {

  L <- character(0)
  add <- function(...) L <<- c(L, paste0(...))
  rule <- function(ch = "-") add(strrep(ch, 78))

  rule("=")
  add("PACT DELPHI -- CONSENSUS AND AGREEMENT ANALYSIS")
  rule("=")
  add("Generated:   ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"))
  add("Data source: ", res$source_file)
  add("R version:   ", paste(R.version$major, R.version$minor, sep = "."))
  add("Round 1 fielded: ", config$field_open, " to ", config$field_close)
  add("")

  ## ---- The instrument -----------------------------------------------------
  rule("=")
  add("0. RATING INSTRUMENT")
  rule("=")
  add("Each task was rated on three dimensions, 1-5. Consensus counts ratings ",
      "of ", config$consensus_rating_min, " or ", config$rating_max,
      " -- the top two")
  add("points -- on every dimension, so all three scales run in the same ",
      "direction:")
  add("a higher rating always means the task is a stronger candidate for the ",
      "benchmark.")
  add("")
  for (v in DIM_COLS) {
    a <- config$dimension_anchors[[v]]
    p <- config$dimension_poles[[v]]
    add(unname(config$dimensions[v]))
    add("  ", unname(config$dimension_questions[v]))
    for (i in seq_along(a)) {
      add(sprintf("    %d  %-26s%s", i, a[i],
                  ifelse(i >= config$consensus_rating_min,
                         "  <- counts toward consensus", "")))
    }
    add("    Low:  ", p[["low"]])
    add("    High: ", p[["high"]])
    add("")
  }

  ## ---- Response rate ------------------------------------------------------
  rule("=")
  add("1. PANEL RESPONSE RATE")
  rule("=")
  rr <- res$response
  add("Round 1 open: ", config$field_open, " to ", config$field_close)
  add("Invited:     ", ifelse(is.na(rr$n_invited), "NOT SET (see R/00_config.R)",
                              rr$n_invited),
      " (Round 1 invitation sent to the full PACT group)")
  add("Responding:  ", rr$n_respondents)
  if (!is.na(rr$rate)) {
    add("Rate:        ", rr$label, "  (95% CI ", fmt_num(rr$ci_lo, 1), "-",
        fmt_num(rr$ci_hi, 1), "%)")
    add("Threshold:   >", 100 * rr$threshold, "%  --  ",
        ifelse(rr$meets_threshold, "MET", "NOT MET"))
  }
  add("Complete responses: ", rr$n_complete)
  add("Partial responses:  ", rr$n_partial,
      if (rr$n_partial > 0) paste0(" (", paste(rr$partial_ids, collapse = ", "),
                                   ") -- retained for the dimensions answered, ",
                                   "excluded elsewhere") else "")
  add("")
  add("Ratings available per dimension:")
  for (i in seq_len(nrow(res$completeness$per_dimension))) {
    p <- res$completeness$per_dimension[i, ]
    add(sprintf("  %-24s %3d ratings, %d missing", p$label, p$n_ratings,
                p$n_missing))
  }
  add("")

  ## ---- Consensus ----------------------------------------------------------
  rule("=")
  add("2. CONSENSUS BY DIMENSION")
  rule("=")
  add("Consensus = >=", 100 * config$consensus_threshold,
      "% of responding panellists rating ", config$consensus_rating_min,
      " or ", config$rating_max, ".")
  add("")

  for (v in DIM_COLS) {
    s <- res$dim_summary[res$dim_summary$dimension == v, ]
    s <- s[order(-s$prop_agree, s$task_order), ]
    add(unname(config$dimensions[v]))
    rule()
    add(sprintf("%-6s %-44s %3s  %-12s %-18s %s",
                "Task", "Description", "n", "Median (IQR)", "Rating 4-5", "Cons."))
    for (i in seq_len(nrow(s))) {
      add(sprintf("%-6s %-44s %3d  %-12s %-18s %s",
                  s$task_code[i], substr(s$task_name[i], 1, 44), s$n[i],
                  s$median_iqr[i], s$agree_label[i],
                  ifelse(isTRUE(s$consensus[i]), "yes", "no")))
    }
    add(sprintf("  Tasks meeting threshold on this dimension: %d of %d",
                sum(s$consensus, na.rm = TRUE), nrow(s)))
    add("")
  }

  ## ---- Eligibility --------------------------------------------------------
  rule("=")
  add("3. ELIGIBILITY FOR THE FINAL TAXONOMY")
  rule("=")
  cl <- res$classified
  add("A task is eligible only if it meets the threshold on all three ",
      "dimensions.")
  add("")
  tab <- table(factor(cl$n_dimensions_met, levels = 0:3))
  for (k in 3:0) {
    add(sprintf("  %d of 3 dimensions: %2d task(s)%s", k, tab[[as.character(k)]],
                ifelse(k == 3, "   <- ELIGIBLE", "")))
  }
  add("")
  el <- cl[cl$eligible, ]
  el <- el[order(el$selection_rank), ]
  if (nrow(el)) {
    add("Eligible set, ranked for the leadership round ",
        "(mean of the three agreement proportions, ties broken by the lowest):")
    add(sprintf("%-5s %-6s %-46s %-8s %s", "Rank", "Task", "Description",
                "Mean %", "Min %"))
    for (i in seq_len(nrow(el))) {
      add(sprintf("%-5d %-6s %-46s %-8s %s", el$selection_rank[i],
                  el$task_code[i], substr(el$task_name[i], 1, 46),
                  fmt_num(el$mean_pct_agree[i], 1),
                  fmt_num(el$min_pct_agree[i], 1)))
    }
    add("")
    add("Leadership round selects ", config$n_final_taxonomy, " of these ",
        nrow(el), ".")
    if (nrow(el) < config$n_final_taxonomy) {
      add("!! Fewer eligible tasks (", nrow(el), ") than the target of ",
          config$n_final_taxonomy, ".")
    }
  } else {
    add("No task met the threshold on all three dimensions.")
  }
  add("")

  add("Non-consensus tasks (retained in the record, not deleted):")
  nc <- cl[!cl$eligible, ]
  nc <- nc[order(-nc$n_dimensions_met, nc$task_order), ]
  if (nrow(nc)) {
    for (i in seq_len(nrow(nc))) {
      add(sprintf("  %-6s %-44s  %d/3 met; not met: %s",
                  nc$task_code[i], substr(nc$task_name[i], 1, 44),
                  nc$n_dimensions_met[i], nc$dimensions_not_met[i]))
    }
  } else {
    add("  none")
  }
  add("")

  ## ---- Agreement ----------------------------------------------------------
  rule("=")
  add("4. AGREEMENT AMONG PANELLISTS")
  rule("=")
  add("Primary:   Kendall's W on the item rankings (tie-corrected).")
  add("Secondary: ICC, two-way random effects, absolute agreement, average ",
      "measures.")
  add("Kappa is not reported: the ratings are ordinal and kappa scores a ",
      "one-point")
  add("and a four-point disagreement alike.")
  add("")
  add("The bootstrap interval on W resamples panellists with replacement. With ",
      "a panel")
  add("this small, resampling duplicates panellists and so tends to pull W ",
      "upward; read")
  add("the interval as indicative of spread, not as a calibrated 95% interval. ",
      "The")
  add("chi-square p value does not depend on the bootstrap.")
  add("")
  a <- res$agreement
  for (i in seq_len(nrow(a))) {
    add(a$label[i])
    add(sprintf("  Kendall W = %s%s, chi-square = %s, df = %s, p %s%s",
                fmt_num(a$W[i], 3),
                ifelse(is.na(a$W_ci_lo[i]), "",
                       sprintf(" (95%% CI %s-%s)", fmt_num(a$W_ci_lo[i], 3),
                               fmt_num(a$W_ci_hi[i], 3))),
                fmt_num(a$W_chisq[i], 2), fmt_num(a$W_df[i], 0),
                ifelse(a$W_p[i] < 0.001, "", "= "), fmt_p(a$W_p[i])))
    add(sprintf("  ICC       = %s (95%% CI %s-%s)", fmt_num(a$ICC[i], 3),
                fmt_num(a$ICC_ci_lo[i], 3), fmt_num(a$ICC_ci_hi[i], 3)))
    add(sprintf("  Based on %d item(s) and %d panellist(s)%s",
                a$n_items[i], a$n_raters_used[i],
                ifelse(nzchar(a$raters_dropped[i]),
                       paste0("; excluded for incomplete ratings on this ",
                              "dimension: ", a$raters_dropped[i]), "")))
    add("")
  }

  ## ---- Spearman -----------------------------------------------------------
  rule("=")
  add("5. SPEARMAN RANK CORRELATIONS BETWEEN DIMENSIONS")
  rule("=")
  add("Task level (task-mean rating across ", res$completeness$n_tasks,
      " tasks) -- report this one:")
  for (i in seq_len(nrow(res$spearman_task))) {
    s <- res$spearman_task[i, ]
    add(sprintf("  %-22s vs %-22s  rho = %6s  p %s%-7s  (n = %d)",
                s$label_x, s$label_y, fmt_num(s$rho, 2),
                ifelse(s$p < 0.001, "", "= "), fmt_p(s$p), s$n))
  }
  add("")
  add("Rating level (individual ratings, pairwise complete) -- sensitivity ",
      "only; treats each panellist x task as independent, which it is not:")
  for (i in seq_len(nrow(res$spearman_rating))) {
    s <- res$spearman_rating[i, ]
    add(sprintf("  %-22s vs %-22s  rho = %6s  p %s%-7s  (n = %d)",
                s$label_x, s$label_y, fmt_num(s$rho, 2),
                ifelse(s$p < 0.001, "", "= "), fmt_p(s$p), s$n))
  }
  add("")

  ## ---- Prespecified limitations ------------------------------------------
  rule("=")
  add("6. NOTES CARRIED FROM THE PROTOCOL")
  rule("=")
  add("- A single rating round means stability of ratings across rounds ",
      "could not be assessed.")
  add("- Partial responses were retained for the dimensions answered and ",
      "excluded elsewhere; the number affected is in section 1.")
  add("- Kappa statistics are not reported (see section 4).")
  add("")
  rule("=")
  add("END")
  rule("=")

  paste(L, collapse = "\n")
}

write_report <- function(res, config = CONFIG,
                         file = file.path("output", "results_report.txt")) {
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  writeLines(build_report(res, config), file)
  message("  wrote ", file)
  invisible(file)
}
