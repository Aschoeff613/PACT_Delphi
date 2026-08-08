# ---------------------------------------------------------------------------
# 00_config.R -- study constants and analysis options
#
# Everything that is a *decision about the study* lives here, not buried in the
# analysis scripts. All thresholds below were prespecified before Round 1.
# ---------------------------------------------------------------------------

CONFIG <- list(

  ## ---- Prespecified thresholds -------------------------------------------

  # Consensus: >= 80% of *responding* panellists rating a task 4 or 5 on a
  # given dimension.
  consensus_threshold   = 0.80,
  consensus_rating_min  = 4L,      # ratings of 4 or 5 count toward consensus

  # Panel response rate must exceed 70%.
  response_rate_threshold = 0.70,

  # Number of panellists invited to Round 1. SET THIS to the true denominator
  # before running on the final data -- the response rate is meaningless if it
  # is left at the number of people who happened to answer.
  n_invited = NA_integer_,

  # Size of the final taxonomy selected by the leadership round.
  n_final_taxonomy = 12L,

  ## ---- Rating scale ------------------------------------------------------

  rating_min = 1L,
  rating_max = 5L,

  # The three rating dimensions, in the order they should appear in tables.
  # Names are the column names in the data; labels are for output.
  dimensions = c(
    clinical_relevance   = "Clinical relevance",
    performance_variance = "Performance variance",
    ai_relevance         = "AI relevance"
  ),

  ## ---- Agreement statistics ---------------------------------------------

  # ICC: two-way random effects, absolute agreement, average measures.
  # In irr::icc() terms: model = "twoway", type = "agreement", unit = "average".
  icc_model = "twoway",
  icc_type  = "agreement",
  icc_unit  = "average",

  # Kendall's W is computed with the tie correction.
  kendall_correct = TRUE,

  # Bootstrap replicates for the Kendall W confidence interval. Set to 0 to
  # skip the bootstrap.
  n_boot = 2000L,
  boot_seed = 20260808L,

  ## ---- Paths -------------------------------------------------------------

  # Real panel data goes in data/raw/ (gitignored). The de-identified sample
  # shipped with the repo is the fallback so the pipeline runs out of the box.
  data_raw_dir    = file.path("data", "raw"),
  data_sample_file = file.path("data", "sample", "pact_delphi_ratings_sample.csv"),
  out_tables      = file.path("output", "tables"),
  out_figures     = file.path("output", "figures"),
  out_log         = file.path("output", "session_info.txt"),

  ## ---- Misc --------------------------------------------------------------

  # Strings the Supabase export writes for missing values.
  na_strings = c("", "NA", "null", "NULL", "NaN")
)

# Convenience vectors used throughout.
DIM_COLS   <- names(CONFIG$dimensions)
DIM_LABELS <- unname(CONFIG$dimensions)
