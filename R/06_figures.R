# ---------------------------------------------------------------------------
# 06_figures.R -- figures, base graphics only
#
# No ggplot2 on purpose: base graphics keeps the dependency list to irr and
# psych, which is what the Methods states.
# ---------------------------------------------------------------------------

DIM_PCH <- c(21, 22, 24)
DIM_COL <- c("#1f4e79", "#b7472a", "#3c7a3c")

open_device <- function(file, width, height, res = 300) {
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  if (capabilities("png")) {
    grDevices::png(file, width = width, height = height, units = "in", res = res)
    return(file)
  }
  file <- sub("\\.png$", ".pdf", file)
  grDevices::pdf(file, width = width, height = height)
  file
}

#' Proportion rating 4-5 by task and dimension, with the 70% threshold marked.
plot_consensus <- function(dim_summary, classified, config = CONFIG,
                           file = file.path(config$out_figures,
                                            "fig1_consensus_by_task.png")) {

  # Ascending sort: y increases upward, so the strongest task lands at the top.
  ord   <- classified[order(classified$mean_pct_agree, -classified$task_order), ]
  tasks <- ord$task_code
  y     <- seq_along(tasks)

  f <- open_device(file, width = 9.5, height = max(5, 0.34 * length(tasks) + 2.6))
  on.exit(grDevices::dev.off(), add = TRUE)

  op <- graphics::par(mar = c(5.8, 14.5, 3.2, 1.4), xpd = FALSE)
  on.exit(graphics::par(op), add = TRUE)

  plot(NA, xlim = c(0, 100), ylim = c(0.5, length(tasks) + 0.5),
       xlab = "Panellists rating 4 or 5 (%)", ylab = "", yaxt = "n",
       bty = "n", cex.lab = 0.95)

  graphics::abline(h = y, col = "grey92", lwd = 0.7)
  graphics::abline(v = 100 * config$consensus_threshold, lty = 2,
                   col = "grey30", lwd = 1.3)
  graphics::mtext(sprintf("%.0f%% consensus threshold",
                          100 * config$consensus_threshold),
                  side = 3, at = 100 * config$consensus_threshold,
                  line = 0.2, cex = 0.78, col = "grey30")

  # Labels are drawn one at a time so eligible tasks can be shown in black and
  # non-consensus tasks in grey; axis() only accepts a single colour.
  labs <- sprintf("%s  %s", tasks, substr(ord$task_name, 1, 46))
  graphics::par(xpd = TRUE)
  graphics::text(x = graphics::grconvertX(0.02, "ndc", "user"), y = y,
                 labels = labs, adj = c(0, 0.5), cex = 0.72,
                 col = ifelse(ord$eligible, "black", "grey45"))
  graphics::par(xpd = FALSE)

  for (j in seq_along(DIM_COLS)) {
    s <- dim_summary[dim_summary$dimension == DIM_COLS[j], ]
    s <- s[match(tasks, s$task_code), ]
    graphics::points(s$pct_agree, y, pch = DIM_PCH[j], bg = DIM_COL[j],
                     col = DIM_COL[j], cex = 1.15)
  }

  # Legend below the axis so it never sits on top of a data point.
  graphics::par(xpd = TRUE)
  graphics::legend(x = 0, y = graphics::grconvertY(0.015, "ndc", "user"),
                   legend = DIM_LABELS, pch = DIM_PCH, pt.bg = DIM_COL,
                   col = DIM_COL, bty = "n", cex = 0.82, horiz = TRUE,
                   xjust = 0, yjust = 0)
  graphics::par(xpd = FALSE)

  graphics::title(main = "Consensus by task and dimension", adj = 0,
                  cex.main = 1.05)
  graphics::mtext("Tasks in grey did not reach consensus on all three dimensions",
                  side = 3, adj = 0, line = 0.1, cex = 0.75, col = "grey40")

  message("  wrote ", f)
  invisible(f)
}

#' Distribution of ratings 1-5 within each dimension.
plot_rating_distribution <- function(d, config = CONFIG,
                                     file = file.path(config$out_figures,
                                                      "fig2_rating_distribution.png")) {

  levels_1_5 <- config$rating_min:config$rating_max
  counts <- vapply(DIM_COLS, function(v) {
    x <- factor(d[[v]][!is.na(d[[v]])], levels = levels_1_5)
    as.numeric(table(x))
  }, numeric(length(levels_1_5)))
  pct <- sweep(counts, 2, colSums(counts), "/") * 100

  f <- open_device(file, width = 8.2, height = 5.0)
  on.exit(grDevices::dev.off(), add = TRUE)

  op <- graphics::par(mar = c(5.6, 4.4, 3.4, 8.2), xpd = TRUE)
  on.exit(graphics::par(op), add = TRUE)

  shades <- grDevices::grey.colors(length(levels_1_5), start = 0.88, end = 0.28)
  bp <- graphics::barplot(pct, beside = FALSE, col = shades, border = "white",
                          names.arg = DIM_LABELS, ylim = c(0, 100),
                          ylab = "Ratings (%)", cex.names = 0.82,
                          cex.axis = 0.85, cex.lab = 0.92)

  # Label the share of ratings in the top two points. A threshold line would be
  # misleading here: the 70% rule applies per task, not to the pooled
  # distribution shown in these bars.
  top <- colSums(pct[levels_1_5 >= config$consensus_rating_min, , drop = FALSE])
  graphics::segments(bp - 0.5, 100 - top, bp + 0.5, 100 - top,
                     lty = 2, col = "#b7472a", lwd = 1.4)
  graphics::text(bp, 100 - top, labels = sprintf("%.0f%% rated 4-5", top),
                 pos = 3, offset = 0.35, cex = 0.76, col = "#b7472a")

  # Anchors for the top two points differ by dimension, so name them. Stacked
  # on two lines -- side by side they collide at this width.
  a4 <- vapply(DIM_COLS, function(v) config$dimension_anchors[[v]][config$consensus_rating_min],
               character(1))
  a5 <- vapply(DIM_COLS, function(v) config$dimension_anchors[[v]][config$rating_max],
               character(1))
  graphics::mtext(paste("4 =", a4), side = 1, at = bp, line = 1.9, cex = 0.6,
                  col = "grey40")
  graphics::mtext(paste("5 =", a5), side = 1, at = bp, line = 2.7, cex = 0.6,
                  col = "grey40")

  graphics::legend(x = max(bp) + 0.75, y = 100,
                   legend = rev(paste("Rating", levels_1_5)),
                   fill = rev(shades), border = "white", bty = "n", cex = 0.78)
  graphics::title(main = "Distribution of ratings by dimension", adj = 0,
                  cex.main = 1.05)
  graphics::mtext("Pooled across all tasks; the 70% consensus rule is applied per task, not here",
                  side = 3, adj = 0, line = 0.1, cex = 0.72, col = "grey40")

  message("  wrote ", f)
  invisible(f)
}
