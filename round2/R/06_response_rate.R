# ---------------------------------------------------------------------------
# 06_response_rate.R -- response rate against the prespecified threshold
#
# Response rate = complete rankings / invited. The denominator is the number
# invited, not the number who opened the link: a panellist who did not respond
# is a non-response however far they got.
#
# Partial rankings count as non-responses here, unlike Round 1 where partial
# responses were retained for the dimensions answered. A ranking that is not a
# complete permutation cannot be placed on either side of the cut, so it
# contributes nothing to the inclusion proportions and should not inflate the
# numerator.
# ---------------------------------------------------------------------------

response_rate <- function(audit, config = CONFIG) {

  n_invited <- config$n_invited
  n_complete <- audit$n_complete

  rate <- if (is.na(n_invited) || n_invited <= 0) NA_real_ else
    n_complete / n_invited

  list(
    n_invited     = n_invited,
    n_submitted   = audit$n_submitted,
    n_complete    = n_complete,
    n_incomplete  = audit$n_incomplete,
    rate          = rate,
    pct           = if (is.na(rate)) NA_real_ else 100 * rate,
    threshold     = config$response_rate_threshold,
    meets         = if (is.na(rate)) NA else rate > config$response_rate_threshold
  )
}

response_rate_table <- function(rr) {
  data.frame(
    Statistic = c("Invited", "Submitted", "Complete rankings",
                  "Incomplete (excluded)", "Response rate",
                  "Prespecified threshold", "Threshold met"),
    Value = c(
      as.character(rr$n_invited),
      as.character(rr$n_submitted),
      as.character(rr$n_complete),
      as.character(rr$n_incomplete),
      if (is.na(rr$pct)) "--" else sprintf("%.1f%%", rr$pct),
      sprintf("> %.0f%%", 100 * rr$threshold),
      if (is.na(rr$meets)) "--" else if (rr$meets) "yes" else "no"
    ),
    check.names = FALSE, stringsAsFactors = FALSE
  )
}
