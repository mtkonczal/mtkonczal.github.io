# LTSS costs (AARP PPI) and home care aide wages (BLS OEWS): data notes

Compiled 2026-10-07. Data pulled 2026-10-06.

## 1. AARP PPI "LTSS Affordability" (March 2026)

**Source:** AARP Public Policy Institute, "2026-03 - LTSS Affordability," Tableau Public.
<https://public.tableau.com/app/profile/public.policy.institute1477/viz/2026-03-LTSSAffordability/ByState>

Workbook metadata (from `https://public.tableau.com/profile/api/workbook/2026-03-LTSSAffordability`): three sheets (By State, By Year, By Service), last updated 2026-03-11 (epoch 1773256649929), workbook ID 18305167.

### Files in this directory

| File | Contents | Rows |
|---|---|---|
| `ltss_cost_by_state_year.csv` | All six series, 52 geographies (50 states, DC, US) by 6 years | 1,870 |
| `ltss_home_health_homemaker_by_state_year.csv` | Home Health Aide and Homemaker only | 624 |
| `scrape_tableau.py` | Extraction script (Python, `tableauscraper`) | |

Columns: `source, state, service, year, annual_cost_usd, months_affordable`.

- **Years:** 2010, 2013, 2016, 2019, 2021, 2024.
- **Services:** Home Health Aide, Homemaker, Assisted Living, Nursing Home Private Room, Nursing Home Semiprivate Room, plus Median Age 65+ Household Income (the affordability denominator; it has no affordability value).

### How it was extracted

Download and CSV export are turned off for this workbook: `/views/.../ByState.csv` returns `missing-view`, and the `.twb` download returns 404. Tableau's embed page also now loads its session config client side, so stock `tableauscraper` fails. The workaround in `scrape_tableau.py`:

1. `POST https://public.tableau.com/vizql/w/2026-03-LTSSAffordability/v/ByState/startSession/viewing` returns the session config JSON and a `Global-Session-Header`.
2. That header is attached to the session, and the config is passed to `tableauscraper`'s bootstrap and parser.
3. The script loops the dashboard's `State` filter (52 values) under both `Type` filter values (`Cost`, `Affordability`) on the `State Table` worksheet.

This depends on Tableau's current internals and may break if they change them.

### Definitions and checks

- **`annual_cost_usd`** is the annual cost of buying a standard quantity of care at market prices, in **nominal dollars**. It is a price, not observed spending.
- **Home care is priced at 30 hours/week, 52 weeks.** Checks: US 2024 Home Health Aide $53,040 / 1,560 hrs = $34.00/hr; 2010 $29,640 / 1,560 = $19.00/hr. (An earlier note in this session guessed 44 hrs/week; that was wrong.)
- **`months_affordable`** = median 65+ household income / annual cost x 12. Check: US 2024 Home Health Aide 59,648 / 53,040 x 12 = 13.50, matching the dashboard.
- **US 2024 values:** Home Health Aide $53,040; Homemaker $51,480; Assisted Living $70,800; Nursing Home Private $127,750; Semiprivate $111,325; Median 65+ income $59,648.
- **Every returned state matches the requested filter value** (0 mismatches).
- **Missing in source:** DC Assisted Living 2013 and DC Nursing Home Semiprivate 2010 (no cost value).
- **Some values are not round dollars** (e.g., US Homemaker 2016 = $31,197.27, Alabama Home Health Aide 2021 = $31,512.27), probably averaging in PPI's processing. Left unchanged.

### Underlying source (inferred)

The cost figures appear to be from the **Genworth / CareScout Cost of Care Survey**. This is inferred from matching numbers (2024 nursing home private room $127,750 and the $34/$19 hourly home care medians match Genworth's published medians); PPI's documentation was not checked. CareScout data are proprietary ("all rights" retained by CareScout Holdings, Inc.).

### Can we use it?

Not legal advice. Viewable by anyone is not the same as openly licensed: AARP disabled the data download on purpose.

- **Citing specific figures with attribution is fine.** That's standard practice, and facts are not copyrightable. Suggested citation: AARP Public Policy Institute, "LTSS Affordability," March 2026, Tableau Public.
- **Republishing the full state-by-year table or redistributing these CSVs:** email PPI first. That also gets an official file instead of relying on this extraction.

## 2. BLS OEWS: home health and personal care aides by state

**Public domain** (US government work). State files: `https://www.bls.gov/oes/special-requests/oesm{YY}st.zip` (e.g., `oesm25st.zip`). Confirmed available (HTTP 200) for 2005, 2010, 2012, 2017, 2018, 2019, 2024, 2025. The 1997 and 2001 URLs redirect (older files sit at a different path). BLS requires a user agent with contact info for scripted downloads.

### Coverage (verified in the 2017, 2018, 2019, 2025 files)

| Years | SOC code(s) | Areas |
|---|---|---|
| May 2019 to May 2025 | **31-1120** Home Health and Personal Care Aides (combined) | 54 (50 states, DC, PR, Guam, VI) |
| about 1999 to May 2018 | **31-1011** Home Health Aides; **39-9021** Personal Care Aides (separate) | 52 to 53 |

- **Variables:** `TOT_EMP`, `EMP_PRSE`, `JOBS_1000`, `LOC_Q`, `H_MEAN`, `A_MEAN`, `MEAN_PRSE`, hourly and annual 10/25/50/75/90th percentiles.
- **Geography column name:** `STATE` in 2017 and 2018 files, `AREA_TITLE` in 2025.
- **Suppression is minimal:**
  - 2025: none of the 54 areas suppressed.
  - 2018: Virgin Islands 39-9021 employment (`**`).
  - 2017: Rhode Island 31-1011 employment (`**`), Vermont 39-9021 median (`*`).
- **Examples:**
  - May 2025, 31-1120: California employment 970,150, median $16.50/hr, mean $17.51/hr. Wyoming 3,410, median $15.96/hr.
  - May 2017: California home health aides 25,180 (median $13.06), personal care aides 520,660 (median $11.41).
- **All six PPI years have a match** in OEWS (May 2010, 2013, 2016, 2019, 2021, 2024), so the two panels align. Metro-level estimates also exist.

### Caveats

1. **The 2019 code change is a series break.** Pre-2019, sum employment across 31-1011 and 39-9021 and use an employment-weighted mean wage. Medians and percentiles cannot be combined that way.
2. **Undercounts consumer-directed and privately hired aides.** OEWS is an establishment survey: it excludes the self-employed and workers employed directly by households. Medicaid self-directed workers paid through fiscal intermediaries are only partly captured. Bigger issue for personal care aides.
3. **BLS cautions against treating OEWS as a time series** (method and code changes). Endpoint comparisons are common but need a caveat.
4. **`A_MEAN` and annual percentiles = hourly x 2,080 hours**, not actual annual earnings. Many aides work part-time.
5. **No state-by-industry detail.** You cannot split home health agencies (NAICS 6216) from services for the elderly and disabled (NAICS 6241) by state.

## 3. Possible next step

Build a state-by-year panel joining PPI home care prices to OEWS aide wages:

- Price per hour = PPI `annual_cost_usd` / 1,560.
- Divide by the OEWS median hourly wage (31-1120 from 2019; constructed pre-2019 aggregate, flagged).
- The ratio shows how much of the hourly price reaches the worker, by state and over time.
- Deflate if comparing levels across years.

## Sources

- [AARP PPI LTSS Affordability dashboard](https://public.tableau.com/app/profile/public.policy.institute1477/viz/2026-03-LTSSAffordability/ByState)
- [AARP PPI Policy Plus Action newsletter](https://www.aarp.org/ppi/policy-plus-action-newsletter/)
- [CareScout Cost of Care releases (Business Wire)](https://www.businesswire.com/news/home/20260302235745/en/CareScout-Releases-2025-Cost-of-Care-Data-for-Arizona)
- [BLS OEWS tables](https://www.bls.gov/oes/tables.htm)
