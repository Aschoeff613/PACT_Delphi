# ---------------------------------------------------------------------------
# 02_load_clean.R -- read the panel export, coerce types, audit completeness
#
# Input is one row per panellist x task, with one column per rating dimension.
# This is the shape the Supabase export produces.
#
# Required columns:
#   reviewer_code, task_code, task_name,
#   clinical_relevance, performance_variance, ai_relevance
# Optional and passed through if present:
#   specialty, institution, flagged_for_discussion, comment, completed_at
# ---------------------------------------------------------------------------

#' Locate the ratings file.
#'
#' Prefers a CSV in data/raw/ (real panel data, gitignored). Falls back to the
#' de-identified sample so a fresh clone runs without any setup. The fallback
#' is announced loudly -- silently analysing sample data would be worse than
#' failing.
find_ratings_file <- function(config = CONFIG) {
  raw <- list.files(config$data_raw_dir, pattern = "\\.csv$",
                    full.names = TRUE, ignore.case = TRUE)
  if (length(raw) == 1L) {
    message("Using panel data: ", raw)
    return(raw)
  }
  if (length(raw) > 1L) {
    stop("Found ", length(raw), " CSV files in ", config$data_raw_dir,
         ". Leave exactly one, or pass a path to load_ratings().",
         call. = FALSE)
  }
  message("\n!! No CSV in ", config$data_raw_dir, ".",
          "\n!! Falling back to the DE-IDENTIFIED SAMPLE dataset.",
          "\n!! Results below are illustrative, not the panel result.\n")
  config$data_sample_file
}

#' Read and clean the ratings.
load_ratings <- function(path = NULL, config = CONFIG) {

  if (is.null(path)) path <- find_ratings_file(config)
  if (!file.exists(path)) stop("File not found: ", path, call. = FALSE)

  d <- utils::read.csv(path, stringsAsFactors = FALSE,
                       na.strings = config$na_strings,
                       check.names = TRUE)

  required <- c("reviewer_code", "task_code", DIM_COLS)
  missing_cols <- setdiff(required, names(d))
  if (length(missing_cols)) {
    stop("Ratings file is missing required column(s): ",
         paste(missing_cols, collapse = ", "), call. = FALSE)
  }

  # Ratings are ordinal 1-5. Coerce to integer and blank out anything off-scale
  # rather than letting a stray value propagate into a median.
  for (v in DIM_COLS) {
    x <- suppressWarnings(as.integer(as.character(d[[v]])))
    bad <- !is.na(x) & (x < config$rating_min | x > config$rating_max)
    if (any(bad)) {
      warning(sum(bad), " off-scale value(s) in '", v,
              "' set to NA (allowed: ", config$rating_min, "-",
              config$rating_max, ").", call. = FALSE)
      x[bad] <- NA_integer_
    }
    d[[v]] <- x
  }

  d$reviewer_code <- trimws(as.character(d$reviewer_code))
  d$task_code     <- trimws(as.character(d$task_code))

  if (!"task_name" %in% names(d)) d$task_name <- d$task_code
  d$task_name <- trimws(as.character(d$task_name))

  if ("flagged_for_discussion" %in% names(d)) {
    d$flagged_for_discussion <-
      tolower(trimws(as.character(d$flagged_for_discussion))) %in%
      c("true", "t", "yes", "y", "1")
  }

  # Drop rows with no reviewer or no task -- these are export artefacts, not
  # responses, and they would inflate the denominator.
  keep <- !is.na(d$reviewer_code) & nzchar(d$reviewer_code) &
          !is.na(d$task_code)     & nzchar(d$task_code)
  if (any(!keep)) {
    message("Dropped ", sum(!keep), " row(s) with no reviewer or task code.")
    d <- d[keep, , drop = FALSE]
  }

  # A panellist should appear once per task. Duplicates usually mean a resubmit;
  # keep the most recent by completed_at, or the last row if there is no
  # timestamp. This is flagged, never silent.
  dup_key <- paste(d$reviewer_code, d$task_code, sep = "||")
  if (anyDuplicated(dup_key)) {
    n_dup <- sum(duplicated(dup_key))
    if ("completed_at" %in% names(d)) {
      ord <- order(dup_key, as.character(d$completed_at), na.last = FALSE)
      d <- d[ord, , drop = FALSE]
      dup_key <- paste(d$reviewer_code, d$task_code, sep = "||")
    }
    d <- d[!duplicated(dup_key, fromLast = TRUE), , drop = FALSE]
    warning(n_dup, " duplicate reviewer x task row(s) found; kept the most ",
            "recent submission for each.", call. = FALSE)
  }

  # Task ordering: numeric suffix if the codes look like T1..T17, else
  # first-appearance order. Keeps tables in the order the panel saw them.
  num <- suppressWarnings(as.integer(gsub("[^0-9]", "", d$task_code)))
  d$task_order <- if (all(!is.na(num))) num else
    match(d$task_code, unique(d$task_code))

  d <- d[order(d$task_order, d$reviewer_code), , drop = FALSE]
  rownames(d) <- NULL

  attr(d, "source_file") <- path
  attr(d, "is_sample") <- identical(normalizePath(path, mustWork = FALSE),
                                    normalizePath(config$data_sample_file,
                                                  mustWork = FALSE))
  d
}

#' Per-panellist completeness.
#'
#' The protocol retains partial responses for the dimensions answered and
#' excludes them elsewhere. That is only defensible if the extent of it is
#' reported, so this counts it explicitly.
audit_completeness <- function(d, config = CONFIG) {

  n_tasks <- length(unique(d$task_code))
  cells   <- length(DIM_COLS) * n_tasks

  per_rev <- do.call(rbind, lapply(split(d, d$reviewer_code), function(r) {
    answered <- sum(!is.na(as.matrix(r[, DIM_COLS])))
    data.frame(
      reviewer_code   = r$reviewer_code[1],
      tasks_seen      = nrow(r),
      tasks_expected  = n_tasks,
      ratings_given   = answered,
      ratings_expected = cells,
      pct_complete    = 100 * answered / cells,
      complete        = answered == cells,
      partial         = answered > 0 && answered < cells,
      stringsAsFactors = FALSE
    )
  }))
  per_rev <- per_rev[order(-per_rev$pct_complete, per_rev$reviewer_code), ]
  rownames(per_rev) <- NULL

  per_dim <- data.frame(
    dimension = DIM_COLS,
    label     = DIM_LABELS,
    n_ratings = vapply(DIM_COLS, function(v) sum(!is.na(d[[v]])), integer(1)),
    n_missing = vapply(DIM_COLS, function(v) sum(is.na(d[[v]])), integer(1)),
    stringsAsFactors = FALSE
  )
  rownames(per_dim) <- NULL

  list(
    n_respondents   = nrow(per_rev),
    n_tasks         = n_tasks,
    n_complete      = sum(per_rev$complete),
    n_partial       = sum(per_rev$partial),
    partial_ids     = per_rev$reviewer_code[per_rev$partial],
    per_reviewer    = per_rev,
    per_dimension   = per_dim
  )
}

#' Reshape one dimension to a tasks x panellists matrix.
#'
#' This is the layout irr::kendall() and irr::icc() expect: rows are the objects
#' being rated, columns are the raters.
rating_matrix <- function(d, dim_col) {
  tasks <- unique(d[order(d$task_order), c("task_code", "task_name")])
  revs  <- sort(unique(d$reviewer_code))

  m <- matrix(NA_integer_, nrow = nrow(tasks), ncol = length(revs),
              dimnames = list(tasks$task_code, revs))
  m[cbind(match(d$task_code, tasks$task_code),
          match(d$reviewer_code, revs))] <- d[[dim_col]]
  m
}
