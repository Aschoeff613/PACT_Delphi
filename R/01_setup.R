# ---------------------------------------------------------------------------
# 01_setup.R -- packages and shared helpers
#
# Base R plus irr and psych. No tidyverse dependency, deliberately: this keeps
# the code reproducible from a bare R 4.4.1 install and makes the statistics
# easy to audit line by line.
# ---------------------------------------------------------------------------

REQUIRED_PKGS <- c("irr", "psych")

install_if_missing <- function(pkgs = REQUIRED_PKGS,
                               repos = "https://cloud.r-project.org") {
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) {
    message("Installing: ", paste(missing, collapse = ", "))
    install.packages(missing, repos = repos)
  }
  invisible(TRUE)
}

load_packages <- function(pkgs = REQUIRED_PKGS) {
  for (p in pkgs) {
    if (!requireNamespace(p, quietly = TRUE)) {
      stop("Package '", p, "' is not installed. Run install_if_missing().",
           call. = FALSE)
    }
  }
  suppressPackageStartupMessages({
    library(irr)
    library(psych)
  })
  invisible(TRUE)
}

## ---- Small formatting / stats helpers -------------------------------------

#' Median and interquartile range for an ordinal vector.
#'
#' Type 6 quantiles (Minitab / SPSS definition) are used because they are the
#' conventional choice for small-sample ordinal survey data and are what most
#' readers will reproduce by hand.
median_iqr <- function(x, digits = 1) {
  x <- x[!is.na(x)]
  if (!length(x)) {
    return(list(median = NA_real_, q1 = NA_real_, q3 = NA_real_,
                label = "--", n = 0L))
  }
  q <- stats::quantile(x, probs = c(0.25, 0.50, 0.75), type = 6, names = FALSE)
  list(
    median = q[2], q1 = q[1], q3 = q[3], n = length(x),
    label = sprintf("%.*f (%.*f-%.*f)", digits, q[2], digits, q[1], digits, q[3])
  )
}

#' Wilson score interval for a binomial proportion.
#'
#' Reported alongside the raw proportion because with a panel of this size a
#' point estimate on its own overstates precision. Wilson rather than Wald: it
#' behaves sensibly when the proportion is near 0 or 1, which is exactly where
#' the 80% consensus threshold sits.
wilson_ci <- function(k, n, conf = 0.95) {
  if (is.na(n) || n == 0) return(c(lower = NA_real_, upper = NA_real_))
  z  <- stats::qnorm(1 - (1 - conf) / 2)
  p  <- k / n
  d  <- 1 + z^2 / n
  ctr <- (p + z^2 / (2 * n)) / d
  hw  <- (z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2))) / d
  c(lower = max(0, ctr - hw), upper = min(1, ctr + hw))
}

#' n (%) with the count kept visible.
n_pct <- function(k, n, digits = 1) {
  if (is.na(n) || n == 0) return("--")
  sprintf("%d/%d (%.*f%%)", k, n, digits, 100 * k / n)
}

fmt_p <- function(p, digits = 3) {
  ifelse(is.na(p), "--",
         ifelse(p < 0.001, "<0.001", sprintf("%.*f", digits, p)))
}

fmt_num <- function(x, digits = 2) {
  ifelse(is.na(x), "--", sprintf("%.*f", digits, x))
}

#' Write a data frame to output/tables/ as CSV.
write_table <- function(df, name, dir = CONFIG$out_tables) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  path <- file.path(dir, paste0(name, ".csv"))
  utils::write.csv(df, path, row.names = FALSE, na = "")
  message("  wrote ", path)
  invisible(path)
}

#' The rating instrument as a table: question stem and all five anchors per
#' dimension. Belongs in the supplement so a reader can see what the panel was
#' actually asked, and makes the direction of each scale explicit.
scale_table <- function(config = CONFIG) {
  rows <- lapply(DIM_COLS, function(v) {
    a <- config$dimension_anchors[[v]]
    p <- config$dimension_poles[[v]]
    data.frame(
      Dimension = unname(config$dimensions[v]),
      Question  = unname(config$dimension_questions[v]),
      `1` = a[1], `2` = a[2], `3` = a[3], `4` = a[4], `5` = a[5],
      `Low anchor`  = unname(p[["low"]]),
      `High anchor` = unname(p[["high"]]),
      check.names = FALSE, stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' Section header for console output.
say_header <- function(txt) {
  bar <- strrep("=", 78)
  cat("\n", bar, "\n", txt, "\n", bar, "\n", sep = "")
}
