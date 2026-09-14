# ---------------------------------------------------------------------------
# 00_config.R -- study constants and analysis options for Round 2
#
# Everything that is a *decision about the study* lives here, not buried in the
# analysis scripts, matching round1/R/00_config.R.
# ---------------------------------------------------------------------------

CONFIG <- list(

  ## ---- Prespecified thresholds -------------------------------------------

  # Inclusion consensus: a task is judged to have panel consensus for the
  # benchmark when at least this share of *responding* panellists placed it in
  # the top n_selected positions of their own ranking.
  #
  # 0.80 matches the Round 1 rule after the reviewer request to use 80%
  # throughout. The denominator is panellists who submitted a complete
  # ranking, not the number invited.
  inclusion_threshold = 0.80,

  # Panel response rate must exceed this. Unchanged from Round 1: this is a
  # response-rate threshold, not a consensus threshold, and the reviewer
  # request was about consensus.
  response_rate_threshold = 0.70,

  # Panellists invited to Round 2. Denominator for the response rate.
  n_invited = 50L,

  ## ---- The ranking task --------------------------------------------------

  # Panellists placed all 17 tasks in order, 1 (highest priority for
  # inclusion) to 17.
  n_tasks   = 17L,
  rank_min  = 1L,
  rank_max  = 17L,

  # Size of the set the leadership round adopted, and so the cut the
  # instrument drew: positions 1..12 were presented as the proposed benchmark.
  n_selected = 12L,

  # The order every panellist was shown, top to bottom.
  #
  # Round 2 presented a fixed order rather than a randomised one: the adopted
  # 12 first, then the 5 that were not selected, each group by Round 1
  # composite. It is declared here so the analysis can state what was shown
  # without trusting the export, and 02_load_clean.R checks the data's
  # initial_rank against it.
  #
  # Not composite order. Selection was a leadership decision, not a cutoff:
  # T1 (composite 3.16) was selected and sits at 12, while T5 (3.62) was not
  # and sits at 13.
  presented_order = c("T4", "T15", "T3", "T6", "T9", "T2", "T8", "T11",
                      "T12", "T16", "T10", "T1",
                      "T5", "T14", "T7", "T17", "T13"),

  ## ---- Fielding ----------------------------------------------------------

  # Round 2 open and close dates. Set these before reporting; they are recorded
  # here rather than derived from submitted_at, which gives the first and last
  # response, not the window.
  field_open  = NA_character_,
  field_close = NA_character_,

  ## ---- Agreement statistics ---------------------------------------------

  # Kendall's W over the tasks x panellists rank matrix.
  #
  # correct = FALSE, unlike Round 1. A complete 1..17 ranking has no ties by
  # construction, so the tie correction has nothing to correct; Round 1 needed
  # it because a 5-point scale over 17 tasks produces many.
  kendall_correct = FALSE,

  # Bootstrap replicates for the Kendall W confidence interval. 0 to skip.
  n_boot    = 2000L,
  boot_seed = 20260914L,

  ## ---- Paths -------------------------------------------------------------

  data_raw_dir = file.path("data", "raw"),
  out_tables   = file.path("output", "tables"),
  out_figures  = file.path("output", "figures"),
  out_log      = file.path("output", "session_info.txt"),

  ## ---- Misc --------------------------------------------------------------

  # Strings the Supabase export writes for missing values.
  na_strings = c("", "NA", "null", "NULL", "NaN")
)
