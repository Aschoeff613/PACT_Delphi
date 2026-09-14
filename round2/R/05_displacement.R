# ---------------------------------------------------------------------------
# 05_displacement.R -- movement away from the order the panel was shown
#
# Round 2 did not ask panellists to build a ranking from nothing. It showed
# them one -- the leadership round's 12 first, then the 5 unselected, each
# group by Round 1 composite -- and asked them to move whatever needed
# adjusting. So the informative quantity is not the rank itself but how far
# each task moved:
#
#     displacement = rank - initial_rank     (negative = moved up)
#
# A task nobody moved is a task the panel accepted where it stood. A task that
# moved a long way, or moved consistently in one direction, is where the
# proposed order was wrong.
#
# This is only interpretable because every panellist saw the same list;
# 02_load_clean.R checks that rather than assuming it. It is also the reason
# these figures must be read with the anchoring in mind: panellists were shown
# an order, and most people adjust an anchor rather than ignore it, so "no
# movement" is weaker evidence of agreement than an unanchored ranking would
# have given. That is a property of the design, not of the analysis.
# ---------------------------------------------------------------------------

#' Per-task displacement from the presented position.
displacement_summary <- function(d, config = CONFIG) {

  usable <- d[!is.na(d$rank) & !is.na(d$initial_rank), , drop = FALSE]
  if (!nrow(usable)) return(NULL)

  usable$displacement <- usable$rank - usable$initial_rank
  by_task <- split(usable, usable$task_code)

  rows <- lapply(names(by_task), function(code) {
    r  <- by_task[[code]]
    dp <- r$displacement
    mi <- median_iqr(dp, digits = 1)

    data.frame(
      task_code       = code,
      task_name       = r$task_name[1],
      presented_rank  = r$initial_rank[1],
      n_raters        = length(dp),
      n_moved         = sum(dp != 0),
      p_moved         = mean(dp != 0),
      n_moved_up      = sum(dp < 0),
      n_moved_down    = sum(dp > 0),
      mean_displacement   = mean(dp),
      median_displacement = mi$median,
      # Mean absolute displacement separates "everyone nudged it the same way"
      # from "the panel split and the average cancelled out".
      mean_abs_displacement = mean(abs(dp)),
      max_up   = if (any(dp < 0)) -min(dp) else 0L,
      max_down = if (any(dp > 0))  max(dp) else 0L,
      stringsAsFactors = FALSE
    )
  })

  out <- do.call(rbind, rows)
  out <- out[order(-out$mean_abs_displacement, out$presented_rank), ,
             drop = FALSE]
  rownames(out) <- NULL
  out
}

#' How much each panellist changed the list they were given.
#'
#' A panellist who moved nothing has either agreed with all of it or not
#' engaged with it, and the two are indistinguishable in the data. Reporting
#' the count makes that visible instead of letting it hide inside the means.
per_rater_displacement <- function(d) {

  usable <- d[!is.na(d$rank) & !is.na(d$initial_rank), , drop = FALSE]
  if (!nrow(usable)) return(NULL)

  usable$displacement <- usable$rank - usable$initial_rank
  by_rev <- split(usable, usable$reviewer_code)

  rows <- lapply(names(by_rev), function(code) {
    dp <- by_rev[[code]]$displacement
    data.frame(
      reviewer_code    = code,
      n_tasks_moved    = sum(dp != 0),
      total_movement   = sum(abs(dp)),
      largest_movement = if (length(dp)) max(abs(dp)) else NA_integer_,
      unchanged        = all(dp == 0),
      stringsAsFactors = FALSE
    )
  })

  out <- do.call(rbind, rows)
  out <- out[order(-out$total_movement), , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' Crossings of the cut line, in both directions.
#'
#' The single most decision-relevant movement: a task presented inside the
#' proposed 12 that a panellist pushed out, or one presented below the line
#' that they pulled in.
cut_crossings <- function(d, config = CONFIG) {

  usable <- d[!is.na(d$rank) & !is.na(d$initial_rank), , drop = FALSE]
  if (!nrow(usable)) return(NULL)

  cut <- config$n_selected
  usable$was_in  <- usable$initial_rank <= cut
  usable$now_in  <- usable$rank        <= cut
  by_task <- split(usable, usable$task_code)

  rows <- lapply(names(by_task), function(code) {
    r <- by_task[[code]]
    data.frame(
      task_code      = code,
      task_name      = r$task_name[1],
      presented_rank = r$initial_rank[1],
      presented_in   = r$was_in[1],
      n_raters       = nrow(r),
      n_pushed_out   = sum(r$was_in & !r$now_in),
      n_pulled_in    = sum(!r$was_in & r$now_in),
      stringsAsFactors = FALSE
    )
  })

  out <- do.call(rbind, rows)
  out$n_crossings <- out$n_pushed_out + out$n_pulled_in
  out <- out[order(-out$n_crossings, out$presented_rank), , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' Printable displacement table.
displacement_table <- function(disp) {
  if (is.null(disp)) return(NULL)
  data.frame(
    `Task ID`   = disp$task_code,
    Task        = disp$task_name,
    `Presented` = disp$presented_rank,
    n           = disp$n_raters,
    Moved       = mapply(n_pct, disp$n_moved, disp$n_raters),
    Up          = disp$n_moved_up,
    Down        = disp$n_moved_down,
    `Mean shift`     = fmt_signed(disp$mean_displacement, 2),
    `Mean abs shift` = fmt_num(disp$mean_abs_displacement, 2),
    `Furthest up`    = disp$max_up,
    `Furthest down`  = disp$max_down,
    check.names = FALSE, stringsAsFactors = FALSE
  )
}
