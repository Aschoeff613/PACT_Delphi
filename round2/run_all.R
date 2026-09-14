# ---------------------------------------------------------------------------
# run_all.R -- the whole Round 2 analysis, top to bottom
#
#   Rscript run_all.R                     # data/raw/*.csv
#   Rscript run_all.R path/to/export.csv  # an explicit file
#
# Writes tables to output/tables/, figures to output/figures/, and a full
# results report to output/results_report.txt.
# ---------------------------------------------------------------------------

suppressWarnings(rm(list = ls()))

for (f in list.files("R", pattern = "\\.R$", full.names = TRUE)) source(f)

install_if_missing()
load_packages()

args <- commandArgs(trailingOnly = TRUE)
path <- if (length(args) >= 1L) args[[1]] else NULL

say_header("PACT Delphi Round 2 -- ranking and inclusion consensus")

## ---- Load ------------------------------------------------------------------
raw       <- load_rankings(path)
audit     <- audit_rankings(raw)
d         <- complete_rankings_only(raw, audit)
presented <- presented_order_from_data(d)

message(sprintf("Loaded %d ranking rows: %d complete ranking(s) x %d task(s).",
                nrow(d), audit$n_complete, audit$n_tasks_seen))

if (!audit$n_complete) {
  stop("No complete rankings in the file, so there is nothing to analyse.",
       call. = FALSE)
}

## ---- Analyse ---------------------------------------------------------------
say_header("Inclusion consensus")
inclusion  <- inclusion_summary(d)
comparison <- compare_with_presented(inclusion, presented)
cset       <- consensus_set(inclusion)

say_header("Agreement")
m         <- rank_matrix(d)
kw        <- kendall_w(m)
per_rater <- per_rater_concordance(m)

say_header("Movement from the presented order")
disp       <- displacement_summary(d)
moves      <- per_rater_displacement(d)
crossings  <- cut_crossings(d)

say_header("Response rate")
rr <- response_rate(audit)

res <- list(
  data            = d,
  source_file     = attr(raw, "source_file"),
  audit           = audit,
  presented       = presented,
  inclusion       = inclusion,
  comparison      = comparison,
  consensus_set   = cset,
  kendall         = kw,
  per_rater       = per_rater,
  displacement    = disp,
  per_rater_moves = moves,
  crossings       = crossings,
  response        = rr
)

## ---- Write -----------------------------------------------------------------
say_header("Writing output")

write_table(inclusion_table(inclusion),      "table1_inclusion_consensus")
write_table(comparison,                      "table2_panel_vs_proposed")
write_table(agreement_table(kw),             "table3_agreement")
write_table(response_rate_table(rr),         "table4_response_rate")
if (!is.null(disp)) {
  write_table(displacement_table(disp),      "table5_displacement")
  write_table(crossings,                     "s3_cut_crossings")
  write_table(moves,                         "s4_per_panellist_movement")
}
write_table(inclusion,                       "s1_inclusion_long")
write_table(audit$per_reviewer,              "s2_submission_completeness")
write_table(per_rater,                       "s5_per_panellist_concordance")

plot_inclusion(inclusion)
plot_rank_distribution(d, inclusion)
plot_displacement(disp)

write_report(res)

dir.create("output", showWarnings = FALSE)
writeLines(capture.output(sessionInfo()), CONFIG$out_log)
message("  wrote ", CONFIG$out_log)

saveRDS(res, file.path("output", "results.rds"))
message("  wrote output/results.rds")

## ---- Console summary -------------------------------------------------------
say_header("Summary")
cat(sprintf("Complete rankings:  %d%s\n", rr$n_complete,
            ifelse(is.na(rr$rate), " (invited not set)",
                   sprintf(" of %d invited = %.1f%%", rr$n_invited, rr$pct))))
cat(sprintf("Excluded partial:   %d\n", rr$n_incomplete))
cat(sprintf("Tasks ranked:       %d\n", audit$n_tasks_seen))
cat(sprintf("Reached consensus:  %d of %d (>= %.0f%% placing in the top %d)\n",
            cset$n, nrow(inclusion), 100 * CONFIG$inclusion_threshold,
            CONFIG$n_selected))
cat(sprintf("Challenged:         %d (proposed, but below the threshold)\n",
            sum(comparison$verdict == "challenged")))
cat(sprintf("Promoted:           %d (not proposed, but above it)\n",
            sum(comparison$verdict == "promoted")))
cat(sprintf("Kendall W:          %s\n", fmt_num(kw$W, 3)))
cat("\nFull report: output/results_report.txt\n\n")
