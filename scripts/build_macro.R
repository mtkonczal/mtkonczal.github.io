# build_macro.R — assemble the four "Data I'm watching" indicators for the
# homepage macro strip (index.qmd, chunk `macro_strip`) and the cache seeder
# (scripts/update_macro_data.R). Sourcing this file defines build_macro().
#
# Output: a long tibble (date, series_id, value, vintage) where `value` is the
# already-transformed metric each cell displays, so the strip does no economics
# of its own. Nine series:
#   UNRATE_FULL    Unemployment rate to an extra digit: unemployed / labor force
#                  (UNEMPLOY / CLF16OV), in percent — finer than the 1-decimal
#                  published UNRATE.
#   SUPERCORE_YOY  PCE services ex-energy & housing (FRED IA001260M), the
#                  "supercore" inflation gauge, year-over-year percent.
#   VU             Vacancies per unemployed worker: job openings (JTSJOL) over
#                  unemployment level (UNEMPLOY). A pure ratio.
#   DIFFUSION      BLS 1-month payroll diffusion index, total private
#                  (CES0500000021), 0-100 (50 = as many industries adding jobs
#                  as cutting). Pulled from the BLS API, so it needs BLS_KEY.
#   WOMEN_SHARE    Share of the past year's net nonfarm job gains that went to
#                  women: 12-month change in CES0000000010 (women employees)
#                  over 12-month change in PAYEMS (total nonfarm), percent.
#   HEALTH_SHARE   Same, for health care (CES6562000101) over total nonfarm
#                  (PAYEMS), percent.
#   WOMEN_CHG      12-month change in women employees (CES0000000010), the raw
#                  level in thousands of jobs (numerator of WOMEN_SHARE).
#   HEALTH_CHG     12-month change in health care employees (CES6562000101),
#                  thousands of jobs (numerator of HEALTH_SHARE).
#   TOTAL_CHG      12-month change in total nonfarm (PAYEMS), thousands of jobs
#                  (the shared denominator). Plotted against WOMEN_CHG/HEALTH_CHG
#                  as the "total" line in those two cells.
#   LABOR_SHARE    Nonfarm business sector labor share (PRS85006173), rescaled
#                  from the 2017=100 index to an actual percent of output using
#                  the hard-coded 2017 level of 56.5%; quarterly.
#   TAYLOR         Taylor-rule policy rate estimate, percent (SEP anchors).
#   FEDFUNDS       Effective federal funds rate (FEDFUNDS), percent. Paired with
#                  TAYLOR in a single two-line chart.
#
# API keys: getFRED() uses FRED's public flat files (no key). The diffusion
# index uses the registered BLS API via blsR, which reads BLS_KEY from the
# environment (.Renviron locally; a repo secret on GitHub Actions).

suppressPackageStartupMessages({
  library(tidyverse)
  library(lubridate)
  library(tidyusmacro)  # getFRED(), getUnrateFRED(): robust FRED flat-file pulls
  library(blsR)         # BLS API client for the diffusion index
})

build_macro <- function() {

  # 1. Unemployment, extra digit -------------------------------------------
  u <- getUnrateFRED() %>%
    arrange(date) %>%
    transmute(date, series_id = "UNRATE_FULL", value = 100 * full_unrate) %>%
    filter(!is.na(value))

  # 2. Supercore PCE (IA001260M), year-over-year ----------------------------
  sc <- getFRED("IA001260M") %>%
    arrange(date) %>%
    transmute(date, level = ia001260m) %>%
    mutate(series_id = "SUPERCORE_YOY",
           value = 100 * (level / lag(level, 12) - 1)) %>%
    filter(!is.na(value)) %>%
    select(date, series_id, value)

  # 3. Vacancies per unemployed worker (v/u) --------------------------------
  vu <- getFRED(c("JTSJOL", "UNEMPLOY")) %>%
    arrange(date) %>%
    filter(!is.na(jtsjol), !is.na(unemploy)) %>%
    transmute(date, series_id = "VU", value = jtsjol / unemploy)

  # 4. Diffusion index (BLS API) --------------------------------------------
  key <- Sys.getenv("BLS_KEY")
  if (!nzchar(key)) {
    stop("BLS_KEY is not set — cannot pull the diffusion index (CES0500000021).")
  }
  bls_set_key(key)
  di_raw <- get_series_table("CES0500000021",
                             start_year = year(Sys.Date()) - 6,
                             end_year   = year(Sys.Date()))
  di <- di_raw %>%
    mutate(month = as.integer(str_sub(period, 2, 3)),
           date  = make_date(year, month, 1)) %>%
    filter(!is.na(date)) %>%
    transmute(date, series_id = "DIFFUSION", value = as.numeric(value)) %>%
    arrange(date)

  # 5. Women's share of net job growth, trailing 12 months ------------------
  #    (change in women payroll employment) / (change in total nonfarm), in
  #    percent. Both series are SA levels in thousands, so the ratio is the share
  #    of net new jobs over the past year that went to women.
  #    (Total nonfarm is PAYEMS on FRED, not the raw BLS id CES0000000001.)
  #    CES6562000101 is All Employees, Health Care (a subsector of health care &
  #    social assistance) — health care alone, not the broader eds-and-meds.
  #    From one pull we derive both the SHARE (headline) and the raw 12-month
  #    CHANGE levels (thousands of jobs) that the two cells now plot as lines.
  jobs <- getFRED(c("CES0000000010", "PAYEMS", "CES6562000101")) %>%
    arrange(date) %>%
    mutate(
      women_chg  = ces0000000010 - lag(ces0000000010, 12),
      health_chg = ces6562000101 - lag(ces6562000101, 12),
      total_chg  = payems        - lag(payems, 12)
    )

  women <- jobs %>%
    transmute(date, series_id = "WOMEN_SHARE",  value = 100 * women_chg  / total_chg) %>%
    filter(!is.na(value))

  # 6. Health care share of net job growth, trailing 12 months --------------
  health <- jobs %>%
    transmute(date, series_id = "HEALTH_SHARE", value = 100 * health_chg / total_chg) %>%
    filter(!is.na(value))

  # 5b/6b. Raw 12-month change levels (thousands of jobs), plotted as the two
  #        lines in the women's and health care cells against a zero reference.
  women_chg  <- jobs %>% transmute(date, series_id = "WOMEN_CHG",  value = women_chg)  %>% filter(!is.na(value))
  health_chg <- jobs %>% transmute(date, series_id = "HEALTH_CHG", value = health_chg) %>% filter(!is.na(value))
  total_chg  <- jobs %>% transmute(date, series_id = "TOTAL_CHG",  value = total_chg)  %>% filter(!is.na(value))

  # 7. Labor share, nonfarm business sector (PRS85006173, index 2017=100) ----
  #    Quarterly. Rescaled from the index to an actual percent share by anchoring
  #    the 2017 base (index = 100) to its known level of 56.5% of output:
  #    share% = index/100 * 56.5 = index * 0.565. The 56.5% anchor is hard-coded;
  #    if BLS rebases off 2017, revisit this constant.
  labor_share_2017 <- 56.5
  lshare <- getFRED("PRS85006173") %>%
    arrange(date) %>%
    transmute(date, series_id = "LABOR_SHARE",
              value = prs85006173 * labor_share_2017 / 100) %>%
    filter(!is.na(value))

  # 8. Taylor rule vs. effective fed funds rate (both percent) ---------------
  #    Taylor rule with SEP-based anchors: neutral real rate 1%, u* 4.2%,
  #    inflation target 2%; inflation is core PCE (PCEPILFE) year-over-year.
  #    taylor = r* + pi + 0.5*(pi - pi*) + (u* - u). Two series for one chart.
  tr <- getFRED(c("PCEPILFE", "FEDFUNDS", "UNRATE")) %>%
    arrange(date) %>%
    filter(!is.na(pcepilfe), !is.na(fedfunds), !is.na(unrate)) %>%
    mutate(core_pce  = pcepilfe / lag(pcepilfe, 12) - 1,
           u         = unrate / 100,
           fed_funds = fedfunds / 100,
           taylor    = 0.01 + core_pce + 0.5 * (core_pce - 0.02) + (0.042 - u)) %>%
    filter(!is.na(taylor), year(date) >= 2023)
  taylor   <- tr %>% transmute(date, series_id = "TAYLOR",   value = 100 * taylor)
  fedfunds <- tr %>% transmute(date, series_id = "FEDFUNDS", value = 100 * fed_funds)

  bind_rows(u, sc, vu, di, women, health, women_chg, health_chg, total_chg,
            lshare, taylor, fedfunds) %>%
    filter(date >= Sys.Date() - years(5)) %>%
    arrange(series_id, date) %>%
    mutate(vintage = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"))
}
