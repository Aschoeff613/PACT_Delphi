# ---------------------------------------------------------------------------
# 05_response_rate.R -- panel response rate against the prespecified threshold
#
# Response rate = respondents / invited, prespecified threshold > 70%.
#
# A panellist counts as a respondent if they submitted at least one rating.
# Partial responses are retained for the dimensions answered and excluded
# elsewhere; the number of panellists affected is reported here, because a
# response rate quoted without it is not interpretable.
# ---------------------------------------------------------------------------

response_rate <- function(completeness, config = CONFIG) {

  n_resp    <- completeness$n_respondents
  n_invited <- config$n_invited

  if (is.na(n_invited)) {
    warning("CONFIG$n_invited is NA. The response rate cannot be computed. ",
            "Set the number of panellists invited to Round 1 in R/00_config.R.",
            call. = FALSE)
    rate <- NA_real_; ci <- c(lower = NA_real_, upper = NA_real_)
  } else {
    if (n_resp > n_invited) {
      warning("More respondents (", n_resp, ") than invited (", n_invited,
              "). Check CONFIG$n_invited.", call. = FALSE)
    }
    rate <- n_resp / n_invited
    ci   <- wilson_ci(n_resp, n_invited)
  }

  list(
    n_invited      = n_invited,
    n_respondents  = n_resp,
    rate           = rate,
    pct            = 100 * rate,
    ci_lo          = 100 * ci[["lower"]],
    ci_hi          = 100 * ci[["upper"]],
    threshold      = config$response_rate_threshold,
    meets_threshold = if (is.na(rate)) NA else rate > config$response_rate_threshold,
    n_complete     = completeness$n_complete,
    n_partial      = completeness$n_partial,
    partial_ids    = completeness$partial_ids,
    label          = if (is.na(rate)) "not computed (n invited not set)"
                     else n_pct(n_resp, n_invited)
  )
}

response_rate_table <- function(rr) {
  data.frame(
    Measure = c("Panellists invited",
                "Panellists responding",
                "Response rate",
                "Prespecified threshold",
                "Threshold met",
                "Complete responses",
                "Partial responses (retained for dimensions answered)"),
    Value = c(
      ifelse(is.na(rr$n_invited), "not set", as.character(rr$n_invited)),
      as.character(rr$n_respondents),
      ifelse(is.na(rr$rate), "--",
             sprintf("%s, 95%% CI %s-%s%%", rr$label,
                     fmt_num(rr$ci_lo, 1), fmt_num(rr$ci_hi, 1))),
      sprintf(">%.0f%%", 100 * rr$threshold),
      ifelse(is.na(rr$meets_threshold), "--", ifelse(rr$meets_threshold, "Yes", "No")),
      as.character(rr$n_complete),
      ifelse(rr$n_partial == 0, "0",
             sprintf("%d (%s)", rr$n_partial,
                     paste(rr$partial_ids, collapse = ", ")))
    ),
    stringsAsFactors = FALSE
  )
}
