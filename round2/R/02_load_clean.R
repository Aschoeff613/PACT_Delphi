# ---------------------------------------------------------------------------
# 02_load_clean.R -- read the ranking export, validate, audit completeness
#
# Input is one row per panellist x task, the shape the Round 2 instrument's
# export produces:
#
#   reviewer_code, task_code, task_name, rank, initial_rank, submitted_at
#
# Optional and passed through if present: display_name, institution, title,
# updated_at.
#
# A ranking is only meaningful as a complete permutation of 1..17, so the
# validation here is stricter than Round 1's. Round 1 retained partial
# responses for the dimensions answered, because rating task A says nothing
# about task B. A partial *ranking* is different: positions are defined
# relative to one another, so a panellist who placed only nine tasks has not
# told us where the other eight sit, and "top 12" is undefined for them. Those
# panellists are dropped whole, and reported.
# ---------------------------------------------------------------------------

#' Locate the rankings file.
find_rankings_file <- function(config = CONFIG) {
  raw <- list.files(config$data_raw_dir, pattern = "\\.csv$",
                    full.names = TRUE, ignore.case = TRUE)
  if (length(raw) == 1L) {
    message("Using panel data: ", raw)
    return(raw)
  }
  if (length(raw) > 1L) {
    stop("Found ", length(raw), " CSV files in ", config$data_raw_dir,
         ". Leave exactly one, or pass a path to load_rankings().",
         call. = FALSE)
  }
  stop("No CSV in ", config$data_raw_dir, ". Copy the Round 2 export there, ",
       "or pass a path: Rscript run_all.R /path/to/export.csv",
       call. = FALSE)
}

#' Read and clean the rankings.
load_rankings <- function(path = NULL, config = CONFIG) {

  if (is.null(path)) path <- find_rankings_file(config)
  if (!file.exists(path)) stop("File not found: ", path, call. = FALSE)

  d <- utils::read.csv(path, stringsAsFactors = FALSE,
                       na.strings = config$na_strings, check.names = TRUE)

  required <- c("reviewer_code", "task_code", "rank")
  missing_cols <- setdiff(required, names(d))
  if (length(missing_cols)) {
    stop("Rankings file is missing required column(s): ",
         paste(missing_cols, collapse = ", "), call. = FALSE)
  }

  d$reviewer_code <- trimws(as.character(d$reviewer_code))
  d$task_code     <- trimws(as.character(d$task_code))

  if (!"task_name" %in% names(d)) d$task_name <- d$task_code
  d$task_name <- trimws(as.character(d$task_name))

  # Ranks are positions, so coerce to integer and blank anything off-scale
  # rather than letting a stray value propagate into a mean rank.
  for (v in intersect(c("rank", "initial_rank"), names(d))) {
    x <- suppressWarnings(as.integer(as.character(d[[v]])))
    bad <- !is.na(x) & (x < config$rank_min | x > config$rank_max)
    if (any(bad)) {
      warning(sum(bad), " off-scale value(s) in '", v, "' set to NA (allowed: ",
              config$rank_min, "-", config$rank_max, ").", call. = FALSE)
      x[bad] <- NA_integer_
    }
    d[[v]] <- x
  }
  if (!"initial_rank" %in% names(d)) d$initial_rank <- NA_integer_

  # Drop export artefacts: rows with no panellist, no task, or no rank.
  keep <- !is.na(d$reviewer_code) & nzchar(d$reviewer_code) &
          !is.na(d$task_code)     & nzchar(d$task_code) &
          !is.na(d$rank)
  if (any(!keep)) {
    message("Dropped ", sum(!keep), " row(s) with no panellist, task or rank.")
    d <- d[keep, , drop = FALSE]
  }

  # A panellist should appear once per task. Duplicates mean a resubmit that
  # the database's unique constraint should have prevented; keep the most
  # recent and say so rather than averaging two rankings together.
  dup_key <- paste(d$reviewer_code, d$task_code, sep = "||")
  if (anyDuplicated(dup_key)) {
    n_dup <- sum(duplicated(dup_key))
    stamp <- if ("submitted_at" %in% names(d)) "submitted_at" else NULL
    if (!is.null(stamp)) {
      d <- d[order(dup_key, as.character(d[[stamp]]), na.last = FALSE), ,
             drop = FALSE]
      dup_key <- paste(d$reviewer_code, d$task_code, sep = "||")
    }
    d <- d[!duplicated(dup_key, fromLast = TRUE), , drop = FALSE]
    warning(n_dup, " duplicate panellist x task row(s) found; kept the most ",
            "recent submission for each.", call. = FALSE)
  }

  # Task ordering for tables: numeric suffix if the codes look like T1..T17,
  # else first-appearance order. Same rule as Round 1.
  num <- suppressWarnings(as.integer(gsub("[^0-9]", "", d$task_code)))
  d$task_order <- if (all(!is.na(num))) num else
    match(d$task_code, unique(d$task_code))

  d <- d[order(d$reviewer_code, d$rank), , drop = FALSE]
  rownames(d) <- NULL

  attr(d, "source_file") <- path
  d
}

#' Per-panellist validity: is each submission a complete permutation of 1..17?
#'
#' Three ways a ranking can be unusable, all checked and all reported: too few
#' tasks, a repeated position, or a position outside 1..n. The database behind
#' the instrument makes all three impossible -- unique (reviewer, task), unique
#' (reviewer, rank) and a range check -- so anything caught here means the file
#' did not come from the instrument, and that is worth knowing loudly.
audit_rankings <- function(d, config = CONFIG) {

  by_rev <- split(d, d$reviewer_code)

  per_reviewer <- do.call(rbind, lapply(names(by_rev), function(code) {
    r <- by_rev[[code]]$rank
    data.frame(
      reviewer_code = code,
      n_tasks_ranked = length(r),
      complete = length(r) == config$n_tasks &&
                 !anyDuplicated(r) &&
                 setequal(r, seq_len(config$n_tasks)),
      duplicate_positions = anyDuplicated(r) > 0,
      stringsAsFactors = FALSE
    )
  }))
  rownames(per_reviewer) <- NULL
  per_reviewer <- per_reviewer[order(per_reviewer$reviewer_code), , drop = FALSE]

  list(
    per_reviewer  = per_reviewer,
    n_submitted   = nrow(per_reviewer),
    n_complete    = sum(per_reviewer$complete),
    n_incomplete  = sum(!per_reviewer$complete),
    incomplete    = per_reviewer$reviewer_code[!per_reviewer$complete],
    n_tasks_seen  = length(unique(d$task_code))
  )
}

#' Keep only complete rankings, and say who was dropped.
complete_rankings_only <- function(d, audit) {
  if (!audit$n_incomplete) return(d)
  message("Excluding ", audit$n_incomplete,
          " incomplete ranking(s) from the analysis: ",
          paste(audit$incomplete, collapse = ", "))
  d[!d$reviewer_code %in% audit$incomplete, , drop = FALSE]
}

#' The order panellists were shown, recovered from the data.
#'
#' initial_rank is the position each task held in the list as presented. Round
#' 2 showed every panellist the same order, so this should be one order shared
#' by all of them -- and that is checked, not assumed, because a mismatch would
#' silently invalidate every displacement figure downstream.
presented_order_from_data <- function(d, config = CONFIG) {

  if (all(is.na(d$initial_rank))) {
    return(list(order = config$presented_order, source = "config",
                agrees_with_config = NA, per_reviewer_identical = NA))
  }

  by_rev <- split(d[!is.na(d$initial_rank), ], d$reviewer_code[!is.na(d$initial_rank)])
  orders <- lapply(by_rev, function(r) r$task_code[order(r$initial_rank)])
  orders <- orders[vapply(orders, length, integer(1)) == config$n_tasks]

  if (!length(orders)) {
    return(list(order = config$presented_order, source = "config",
                agrees_with_config = NA, per_reviewer_identical = NA))
  }

  identical_across <- all(vapply(orders, function(o) identical(o, orders[[1]]),
                                 logical(1)))
  from_data <- orders[[1]]

  agrees <- identical(as.character(from_data), as.character(config$presented_order))
  if (!identical_across) {
    warning("Panellists were not all shown the same order: initial_rank ",
            "differs between submissions. Displacement figures pool ",
            "panellists who saw different lists.", call. = FALSE)
  }
  if (!agrees) {
    warning("The presented order in the data does not match ",
            "CONFIG$presented_order. Reporting the order from the data.",
            call. = FALSE)
  }

  list(order = from_data, source = "data",
       agrees_with_config = agrees, per_reviewer_identical = identical_across)
}

#' Tasks x panellists matrix of ranks, for the concordance statistics.
rank_matrix <- function(d, config = CONFIG) {
  m <- tapply(d$rank, list(d$task_code, d$reviewer_code), function(x) x[1])
  # Order rows by task number so the matrix reads like the tables.
  num <- suppressWarnings(as.integer(gsub("[^0-9]", "", rownames(m))))
  if (all(!is.na(num))) m <- m[order(num), , drop = FALSE]
  m
}
