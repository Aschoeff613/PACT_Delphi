# ---------------------------------------------------------------------------
# 07_figures.R -- base-graphics figures, written to output/figures/
#
# Base graphics rather than ggplot2, matching Round 1: one fewer dependency,
# and the figures reproduce from a bare R install.
# ---------------------------------------------------------------------------

open_device <- function(file, width, height, res = 300) {
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  grDevices::png(file, width = width, height = height, units = "in", res = res)
  file
}

#' Share of panellists placing each task in the top 12, threshold marked.
plot_inclusion <- function(inclusion, config = CONFIG,
                           file = file.path(config$out_figures,
                                            "fig1_inclusion_by_task.png")) {

  open_device(file, width = 9, height = 7)
  on.exit(grDevices::dev.off(), add = TRUE)

  # barplot() draws the first element at the bottom, so reverse the rows to put
  # the strongest task at the top. Row order, not rev(), which on a data frame
  # reverses the columns.
  x <- inclusion[rev(seq_len(nrow(inclusion))), , drop = FALSE]
  pct <- 100 * x$p_top

  graphics::par(mar = c(4.6, 17.5, 3.2, 1.4), mgp = c(2.6, 0.7, 0))
  bp <- graphics::barplot(pct, horiz = TRUE, names.arg = x$task_name,
                          las = 1, xlim = c(0, 100),
                          col = ifelse(x$consensus, "#8c1515", "#c9ced6"),
                          border = NA,
                          xlab = sprintf("Panellists placing the task in the top %d (%%)",
                                         config$n_selected),
                          cex.names = 0.78, cex.axis = 0.85, cex.lab = 0.9)

  # Wilson intervals: a point estimate on a panel this size overstates
  # precision, so the interval is drawn on every bar. Light on the filled bars
  # and dark on the empty ones -- a single colour is unreadable against one or
  # the other.
  graphics::segments(100 * x$ci_lower, bp, 100 * x$ci_upper, bp,
                     col = ifelse(x$consensus, "#f2d5d5", "#444c57"), lwd = 1.4)

  graphics::abline(v = 100 * config$inclusion_threshold, lty = 2, col = "#8c1515")
  graphics::mtext(sprintf("%.0f%% consensus threshold", 100 * config$inclusion_threshold),
                  side = 3, at = 100 * config$inclusion_threshold,
                  cex = 0.72, col = "#8c1515", line = 0.3)

  graphics::title(main = "Round 2: inclusion consensus by task", adj = 0,
                  cex.main = 1.05, font.main = 2)
  invisible(file)
}

#' Rank distribution per task: median, IQR box, and full range.
plot_rank_distribution <- function(d, inclusion, config = CONFIG,
                                   file = file.path(config$out_figures,
                                                    "fig2_rank_distribution.png")) {

  open_device(file, width = 9, height = 7)
  on.exit(grDevices::dev.off(), add = TRUE)

  ord <- rev(inclusion$task_code)
  ranks <- lapply(ord, function(code) d$rank[d$task_code == code & !is.na(d$rank)])
  names(ranks) <- rev(inclusion$task_name)

  graphics::par(mar = c(4.6, 17.5, 3.2, 1.4), mgp = c(2.6, 0.7, 0))
  graphics::boxplot(ranks, horizontal = TRUE, las = 1, outline = TRUE,
                    col = "#eef1f4", border = "#444c57", medlwd = 2,
                    xlab = "Position assigned (1 = highest priority)",
                    cex.axis = 0.78, cex.lab = 0.9)

  # The cut the instrument drew, so a reader can see which distributions
  # straddle it.
  graphics::abline(v = config$n_selected + 0.5, lty = 2, col = "#8c1515")
  graphics::mtext(sprintf("top %d", config$n_selected), side = 3,
                  at = config$n_selected + 0.5, cex = 0.72,
                  col = "#8c1515", line = 0.3)

  graphics::title(main = "Round 2: rank distribution by task", adj = 0,
                  cex.main = 1.05, font.main = 2)
  invisible(file)
}

#' Presented position against the panel's mean position.
#'
#' Points on the diagonal are tasks the panel left where they were; distance
#' from it is the panel disagreeing with the proposed order.
plot_displacement <- function(disp, config = CONFIG,
                              file = file.path(config$out_figures,
                                               "fig3_displacement.png")) {
  if (is.null(disp)) return(invisible(NULL))

  open_device(file, width = 7.2, height = 7)
  on.exit(grDevices::dev.off(), add = TRUE)

  mean_rank <- disp$presented_rank + disp$mean_displacement

  graphics::par(mar = c(4.4, 4.4, 3.2, 1.4), mgp = c(2.6, 0.7, 0))
  graphics::plot(disp$presented_rank, mean_rank, type = "n",
                 xlim = c(0.5, config$n_tasks + 0.5),
                 ylim = c(config$n_tasks + 0.5, 0.5),
                 xlab = "Position as presented",
                 ylab = "Mean position assigned by the panel",
                 cex.axis = 0.85, cex.lab = 0.9)

  graphics::abline(a = 0, b = 1, col = "#c9ced6")
  graphics::abline(v = config$n_selected + 0.5, lty = 2, col = "#8c1515")
  graphics::abline(h = config$n_selected + 0.5, lty = 2, col = "#8c1515")

  graphics::segments(disp$presented_rank, disp$presented_rank,
                     disp$presented_rank, mean_rank, col = "#8c1515", lwd = 1.1)
  graphics::points(disp$presented_rank, mean_rank, pch = 21, bg = "#8c1515",
                   col = "white", cex = 1.25)
  graphics::text(disp$presented_rank, mean_rank, labels = disp$task_code,
                 pos = 4, offset = 0.45, cex = 0.66, col = "#333b45")

  graphics::title(main = "Round 2: movement from the presented order", adj = 0,
                  cex.main = 1.05, font.main = 2)
  invisible(file)
}
