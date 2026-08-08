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

  # Number of panellists invited to Round 1: the Round 1 invitation was sent to
  # the full PACT group of 50. This is the denominator for the response rate,
  # so it is the number invited, not the number who answered.
  n_invited = 50L,

  # Size of the final taxonomy selected by the leadership round.
  n_final_taxonomy = 12L,

  ## ---- Rating scale ------------------------------------------------------

  rating_min = 1L,
  rating_max = 5L,

  # The three rating dimensions, in the order they should appear in tables.
  # Names are the column names in the data; labels are the instrument wording.
  #
  # Note the third: the column is `ai_relevance`, but the instrument calls it
  # AI Augmentation Potential. Output uses the instrument wording; the column
  # name is left alone so the Supabase export loads unmodified.
  dimensions = c(
    clinical_relevance   = "Clinical relevance",
    performance_variance = "Performance variance",
    ai_relevance         = "AI augmentation potential"
  ),

  # The question stem as the panel saw it. Used in table footnotes so a reader
  # knows what was actually asked.
  dimension_questions = c(
    clinical_relevance   = "How clinically significant is this task - how much does it matter that it is done well?",
    performance_variance = "How much would competent clinicians disagree about the right path forward on this task?",
    ai_relevance         = "Could AI (including ML, LLMs, agents, etc.) meaningfully augment this task?"
  ),

  # Anchor label for each point 1-5, per dimension, exactly as displayed.
  dimension_anchors = list(
    clinical_relevance   = c("Very low", "Low", "Moderate", "High", "Very high"),
    performance_variance = c("Strong consensus", "Minor variation",
                             "Moderate variation", "Substantial disagreement",
                             "Wide disagreement"),
    ai_relevance         = c("AI unlikely to help", "Marginal AI value",
                             "Moderate AI value", "Clear AI benefit",
                             "AI core to this task")
  ),

  # The descriptive text at each end of the scale.
  dimension_poles = list(
    clinical_relevance   = c(low  = "Minor - little bearing on patient care",
                             high = "Major - materially shapes patient care"),
    performance_variance = c(low  = "Clinicians would nearly all take the same approach",
                             high = "Clinicians would vary widely on the path forward"),
    ai_relevance         = c(low  = "Requires judgment AI cannot replicate",
                             high = "AI-demonstrated capability in this area")
  ),

  ## ---- Fielding ----------------------------------------------------------

  # Round 1 open and close dates. Recorded here rather than derived from
  # completed_at, which gives the first and last response, not the window.
  field_open  = "2026-08-03",
  field_close = "2026-08-11",

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
