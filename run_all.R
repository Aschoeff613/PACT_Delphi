# ---------------------------------------------------------------------------
# run_all.R -- the whole analysis, top to bottom
#
#   Rscript run_all.R                    # data/raw/*.csv, else the sample
#   Rscript run_all.R path/to/panel.csv  # an explicit file
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

say_header("PACT Delphi -- consensus and agreement analysis")

## ---- Load ------------------------------------------------------------------
d   <- load_ratings(path)
cmp <- audit_completeness(d)

message(sprintf("Loaded %d rating rows: %d panellist(s) x %d task(s).",
                nrow(d), cmp$n_respondents, cmp$n_tasks))

## ---- Analyse ---------------------------------------------------------------
say_header("Consensus")
dim_summary <- summarise_all_dimensions(d)
classified  <- classify_tasks(dim_summary)
ranks       <- rank_within_dimension(dim_summary)

say_header("Agreement")
agreement <- agreement_table(d)
sp_task   <- spearman_dimensions(d, level = "task")
sp_rating <- spearman_dimensions(d, level = "rating")

say_header("Response rate")
rr <- response_rate(cmp)

res <- list(
  data            = d,
  source_file     = attr(d, "source_file"),
  completeness    = cmp,
  dim_summary     = dim_summary,
  classified      = classified,
  ranks           = ranks,
  agreement       = agreement,
  spearman_task   = sp_task,
  spearman_rating = sp_rating,
  response        = rr
)

## ---- Write -----------------------------------------------------------------
say_header("Writing output")

write_table(scale_table(),                    "table0_rating_scale")
write_table(consensus_table(classified),      "table1_consensus_by_task")
write_table(format_agreement(agreement),      "table2_agreement")
write_table(response_rate_table(rr),          "table3_response_rate")
write_table(dim_summary,                      "s1_dimension_summary_long")
write_table(classified,                       "s2_task_classification")
write_table(ranks,                            "s3_rankings_within_dimension")
write_table(sp_task,                          "s4_spearman_task_level")
write_table(sp_rating,                        "s5_spearman_rating_level")
write_table(cmp$per_reviewer,                 "s6_respondent_completeness")

plot_consensus(dim_summary, classified)
plot_rating_distribution(d)

write_report(res)

dir.create("output", showWarnings = FALSE)
writeLines(capture.output(sessionInfo()), CONFIG$out_log)
message("  wrote ", CONFIG$out_log)

saveRDS(res, file.path("output", "results.rds"))
message("  wrote output/results.rds")

## ---- Console summary -------------------------------------------------------
say_header("Summary")
cat(sprintf("Respondents:        %d%s\n", rr$n_respondents,
            ifelse(is.na(rr$rate), " (invited not set)",
                   sprintf(" of %d invited = %.1f%%", rr$n_invited, rr$pct))))
cat(sprintf("Partial responses:  %d\n", rr$n_partial))
cat(sprintf("Tasks rated:        %d\n", cmp$n_tasks))
cat(sprintf("Eligible tasks:     %d (consensus on all three dimensions)\n",
            sum(classified$eligible)))
cat(sprintf("Non-consensus:      %d\n", sum(!classified$eligible)))
cat("Kendall W:          ",
    paste(sprintf("%s = %s", agreement$label, fmt_num(agreement$W, 3)),
          collapse = ";  "), "\n", sep = "")
cat("\nFull report: output/results_report.txt\n\n")
