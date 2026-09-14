# ---------------------------------------------------------------------------
# 08_report.R -- assemble a plain-text results report
#
# The point of this file, as in Round 1: the numbers that go into the
# manuscript should be generated, not transcribed. Every figure quoted in the
# Round 2 results paragraph appears in output/results_report.txt, produced by
# the same run that made the tables.
# ---------------------------------------------------------------------------

build_report <- function(res, config = CONFIG) {

  L <- character(0)
  add <- function(...) L <<- c(L, paste0(...))
  rule <- function(ch = "-") add(strrep(ch, 78))

  inc  <- res$inclusion
  cmp  <- res$comparison
  set  <- res$consensus_set
  rr   <- res$response
  kw   <- res$kendall

  rule("=")
  add("PACT DELPHI ROUND 2 -- RANKING AND INCLUSION CONSENSUS")
  rule("=")
  add("Generated:   ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"))
  add("Data source: ", res$source_file)
  add("R version:   ", paste(R.version$major, R.version$minor, sep = "."))
  if (!is.na(config$field_open)) {
    add("Round 2 fielded: ", config$field_open, " to ", config$field_close)
  }
  add("")

  ## ---- What was asked -----------------------------------------------------
  rule("=")
  add("0. THE RANKING TASK")
  rule("=")
  add("Panellists placed all ", config$n_tasks, " tasks in a single order, 1 ",
      "(highest priority for")
  add("inclusion in the benchmark) to ", config$n_tasks, ". Every panellist ",
      "was shown the same")
  add("starting order: the ", config$n_selected, " tasks adopted at the ",
      "leadership round first, then")
  add("the ", config$n_tasks - config$n_selected, " that were not, each group ",
      "by Round 1 composite.")
  add("")
  add("Inclusion consensus: at least ", sprintf("%.0f%%", 100 * config$inclusion_threshold),
      " of panellists submitting a complete")
  add("ranking placed the task in the top ", config$n_selected, ". The ",
      "denominator is complete")
  add("rankings, not the number invited.")
  add("")
  add("Order as presented:")
  for (i in seq_along(res$presented$order)) {
    code <- res$presented$order[i]
    nm   <- inc$task_name[match(code, inc$task_code)]
    add(sprintf("   %2d  %-5s %s%s", i, code,
                if (is.na(nm)) "" else nm,
                if (i == config$n_selected) "   <- cut" else ""))
  }
  if (identical(res$presented$source, "data")) {
    add("")
    add("Recovered from initial_rank in the export",
        if (isTRUE(res$presented$agrees_with_config))
          "; matches CONFIG$presented_order." else
          "; DIFFERS from CONFIG$presented_order.")
    if (isFALSE(res$presented$per_reviewer_identical)) {
      add("WARNING: panellists were not all shown the same order.")
    }
  } else {
    add("")
    add("Taken from CONFIG$presented_order: the export carried no initial_rank.")
  }
  add("")

  ## ---- Response -----------------------------------------------------------
  rule("=")
  add("1. RESPONSE")
  rule("=")
  add("Invited:              ", rr$n_invited)
  add("Submitted:            ", rr$n_submitted)
  add("Complete rankings:    ", rr$n_complete)
  add("Incomplete, excluded: ", rr$n_incomplete)
  if (rr$n_incomplete > 0) {
    add("  ", paste(res$audit$incomplete, collapse = ", "))
  }
  add("Response rate:        ",
      if (is.na(rr$pct)) "--" else sprintf("%.1f%%", rr$pct),
      "  (prespecified threshold > ", sprintf("%.0f%%", 100 * rr$threshold), ")")
  add("Threshold met:        ",
      if (is.na(rr$meets)) "--" else if (rr$meets) "yes" else "no")
  add("")

  ## ---- Inclusion consensus ------------------------------------------------
  rule("=")
  add("2. INCLUSION CONSENSUS")
  rule("=")
  add("Share of panellists placing each task in the top ", config$n_selected,
      ", best first.")
  add("")
  add(sprintf("%-5s %-44s %-16s %-7s %s", "ID", "Task",
              sprintf("In top %d", config$n_selected), "Mean", "Consensus"))
  rule()
  for (i in seq_len(nrow(inc))) {
    add(sprintf("%-5s %-44s %-16s %-7s %s",
                inc$task_code[i],
                substr(inc$task_name[i], 1, 44),
                n_pct(inc$n_top[i], inc$n_raters[i]),
                fmt_num(inc$mean_rank[i], 2),
                if (inc$consensus[i]) "yes" else "no"))
  }
  rule()
  add("")
  add("Reached consensus: ", set$n, " of ", nrow(inc), " tasks",
      if (set$matches_size) "" else
        sprintf("  (the adopted set has %d)", set$n_expected))
  if (!set$matches_size) {
    add("")
    add("The number of tasks reaching consensus is not ", set$n_expected,
        ". This is reported as")
    add("found and not trimmed: padding the set with tasks that failed the ",
        "rule, or")
    add("dropping tasks that passed it, would substitute the analyst's ",
        "judgement for")
    add("the panel's.")
  }
  add("")

  ## ---- Against the proposed set -------------------------------------------
  rule("=")
  add("3. THE PANEL AGAINST THE PROPOSED SET")
  rule("=")
  for (v in c("confirmed", "challenged", "promoted", "excluded")) {
    rows <- cmp[cmp$verdict == v, , drop = FALSE]
    label <- switch(v,
      confirmed  = "CONFIRMED  -- proposed for the benchmark, and reached consensus",
      challenged = "CHALLENGED -- proposed for the benchmark, but did NOT reach consensus",
      promoted   = "PROMOTED   -- not proposed, but reached consensus",
      excluded   = "EXCLUDED   -- not proposed, and did not reach consensus")
    add(label)
    if (!nrow(rows)) {
      add("   (none)")
    } else {
      for (i in seq_len(nrow(rows))) {
        add(sprintf("   %-5s %-44s %s  (presented %d)",
                    rows$task_code[i], substr(rows$task_name[i], 1, 44),
                    n_pct(rows$n_top[i], rows$n_raters[i]),
                    rows$presented_rank[i]))
      }
    }
    add("")
  }
  add("Challenged and promoted tasks are the decisions this round hands back ",
      "to the")
  add("leadership group. Confirmed and excluded tasks are settled.")
  add("")

  ## ---- Agreement ----------------------------------------------------------
  rule("=")
  add("4. AGREEMENT AMONG PANELLISTS")
  rule("=")
  add("Kendall's W: ", fmt_num(kw$W, 3),
      if (all(is.na(kw$ci))) "" else
        sprintf(" (95%% CI %s-%s)", fmt_num(kw$ci[1], 3), fmt_num(kw$ci[2], 3)))
  add("chi-squared = ", fmt_num(kw$chisq, 2), " on ", kw$df, " df, p = ",
      fmt_p(kw$p))
  add("Computed over ", kw$n_items, " tasks and ", kw$n_raters, " panellist(s).")
  if (length(kw$dropped)) {
    add("Excluded for incomplete columns: ", paste(kw$dropped, collapse = ", "))
  }
  add("")
  add("W measures agreement about the whole ordering. It does not measure ",
      "agreement")
  add("about the cut: a panel can share a W while disagreeing entirely about ",
      "which")
  add("tasks make the top ", config$n_selected, ", which is why section 2 is ",
      "the headline and this is not.")
  add("")
  if (!is.null(res$per_rater) && nrow(res$per_rater)) {
    add("Per-panellist concordance with the rest of the panel (Spearman rho,")
    add("leave-one-out), lowest first:")
    for (i in seq_len(min(5L, nrow(res$per_rater)))) {
      add(sprintf("   %-12s %s", res$per_rater$reviewer_code[i],
                  fmt_num(res$per_rater$rho[i], 2)))
    }
    add("")
  }

  ## ---- Displacement -------------------------------------------------------
  rule("=")
  add("5. MOVEMENT FROM THE PRESENTED ORDER")
  rule("=")
  if (is.null(res$displacement)) {
    add("No initial_rank in the export, so displacement cannot be computed.")
    add("")
  } else {
    disp <- res$displacement
    add("Negative = moved up the list. Ordered by mean absolute movement.")
    add("")
    add(sprintf("%-5s %-40s %-6s %-14s %s", "ID", "Task", "Shown", "Moved", "Mean shift"))
    rule()
    for (i in seq_len(nrow(disp))) {
      add(sprintf("%-5s %-40s %-6d %-14s %s",
                  disp$task_code[i], substr(disp$task_name[i], 1, 40),
                  disp$presented_rank[i],
                  n_pct(disp$n_moved[i], disp$n_raters[i]),
                  fmt_signed(disp$mean_displacement[i], 2)))
    }
    rule()
    add("")
    if (!is.null(res$crossings)) {
      cr <- res$crossings[res$crossings$n_crossings > 0, , drop = FALSE]
      add("Tasks moved across the cut by at least one panellist:")
      if (!nrow(cr)) {
        add("   (none)")
      } else {
        for (i in seq_len(nrow(cr))) {
          add(sprintf("   %-5s %-40s out: %d  in: %d",
                      cr$task_code[i], substr(cr$task_name[i], 1, 40),
                      cr$n_pushed_out[i], cr$n_pulled_in[i]))
        }
      }
      add("")
    }
    if (!is.null(res$per_rater_moves)) {
      unchanged <- sum(res$per_rater_moves$unchanged)
      add("Panellists who submitted the list unchanged: ", unchanged, " of ",
          nrow(res$per_rater_moves))
      if (unchanged > 0) {
        add("A panellist who moved nothing has either agreed with all of it or ",
            "not")
        add("engaged with it; the data cannot tell those apart.")
      }
      add("")
    }
  }

  ## ---- Limitations --------------------------------------------------------
  rule("=")
  add("6. LIMITATIONS")
  rule("=")
  add("Anchoring. Panellists were shown an order rather than asked to build ",
      "one, so")
  add("the result measures adjustment from that anchor. Most people adjust an ",
      "anchor")
  add("rather than ignore it, which means agreement with the presented order ",
      "is")
  add("weaker evidence than an unanchored ranking would have given, and the ",
      "Round 2")
  add("ordering will correlate with the Round 1 composite partly because the ",
      "composite")
  add("was shown. This is a property of the design, chosen deliberately as ",
      "the")
  add("controlled feedback step of a Delphi, not an artefact of the analysis.")
  add("")
  add("Single round. Round 2 was fielded once, so stability of the rankings ",
      "across")
  add("repetitions cannot be assessed.")
  add("")
  add("Forced cut. The instrument presented a ", config$n_selected,
      "-task set, so the top-", config$n_selected, " rule")
  add("inherits that number from the leadership round rather than deriving ",
      "it from")
  add("the data.")
  add("")

  L
}

write_report <- function(res, config = CONFIG,
                         file = file.path("output", "results_report.txt")) {
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  writeLines(build_report(res, config), file)
  message("  wrote ", file)
  invisible(file)
}
