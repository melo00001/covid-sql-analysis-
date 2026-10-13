# COVID-19 Global Trends: A SQL Analysis

## Project Overview

This project analyses global COVID-19 case, death, and vaccination data using T-SQL in SQL Server Management Studio. The goal wasn't just to run queries, but to practise the full workflow a real analyst goes through: loading messy real-world data, making deliberate decisions about how to handle its imperfections, and only then answering specific business/public-health questions with increasingly advanced SQL.

**Data source:** [Our World in Data](https://ourworldindata.org/covid-deaths) COVID-19 dataset, split into two files: `Covid_death.csv` (cases, deaths, hospitalisation) and `Covid_vaccinations.csv` (testing, vaccination, demographic indicators). Raw CSVs aren't included in this repo due to file size - download them from the link above to run the scripts yourself.

**Date range covered:** 1 January 2020 – 30 April 2021 (so this dataset captures the first year of the pandemic and the very start of the global vaccine rollout, but not later waves like Delta or Omicron).

**Tools used:** SQL Server Management Studio (T-SQL), BULK INSERT, window functions, CTEs, views, stored procedures.

---

## Process

### 1. Loading the data
Rather than rely on SSMS's Import Flat File wizard (which repeatedly mis-sized numeric columns and rejected legitimate blank values as errors), both CSVs were loaded using a hand-written schema (`01_create_and_load_covid_tables.sql`) and `BULK INSERT`. Writing the schema manually meant full control over data types and nullability from the start - e.g. `population` needed `bigint` rather than `int`, since the "World" aggregate row alone is close to 8 billion.

### 2. Cleaning (`02_data_cleaning.sql`)
- **Duplicates:** Checked for duplicate `(location, date)` pairs using `ROW_NUMBER()`. None were found - confirmed, not assumed.
- **Aggregate rows:** The dataset includes rows for continents, the EU, and "World" alongside individual countries, identifiable by an `iso_code` starting with `OWID_`. These aren't errors - they're a different level of granularity - so they were kept but explicitly excluded from country-level comparisons throughout.
- **Nulls - a deliberate decision, not a default:** Roughly 90% of `icu_patients` and `hosp_patients` values are null, because most countries never reported those metrics at all - not because the true value was zero. These were **left as null rather than zero-filled**, because filling with 0 would have fabricated "no ICU load" for countries that simply didn't publish the figure. The same reasoning applied to `new_cases`/`new_deaths`: `SUM()` and `AVG()` already skip nulls correctly, so leaving reporting gaps as null kept global totals and rolling averages accurate.
- **The two `population` nulls** ("International" - cases not tied to a specific country, e.g. cruise ships - and "Northern Cyprus" - a real place with no official population figure available) were also left alone, since any calculation dividing by population correctly returns null for these two rows rather than a fabricated number.

One bug worth showing rather than just mentioning: an early version of a percentage calculation divided before multiplying by a decimal, which in SQL Server triggers integer division and silently truncates the result to zero. Same query, same data, before and after the fix:

![Integer division bug fix](screenshots/bug-fix-integer-division.png)

### 3. Analysis (`03_analysis_queries.sql`)
Eleven queries, building in complexity: global aggregation → per-country grouping → window functions (rolling 7-day averages, running vaccination totals) → CTEs → ranking within continents and by rollout speed → a reusable view → a parameterised stored procedure. Full queries and comments are in the script itself.

---

## Key Insights

**Global scale:** Across the ~16 months covered, there were **150,574,977 recorded cases** and **3,180,206 recorded deaths** worldwide - a global case fatality rate of **2.11%**.

**Case fatality rate varies enormously - and testing capacity is likely the real driver.** Among countries with a statistically meaningful case count (100,000+), **Mexico had the highest case fatality rate at 9.25%**, more than double the next-highest countries (Egypt 5.86%, Ecuador 4.88%, China 4.73%, Bosnia and Herzegovina 4.31%). This almost certainly doesn't mean the virus was more lethal in Mexico - it more likely reflects lower testing capacity, meaning many mild/asymptomatic cases there went uncounted while deaths (harder to miss) were still recorded, inflating the ratio. Case fatality rate is a measure of *reported* severity, not a clean, universally comparable metric - it needs testing coverage as context, not just the raw number.

**Infection rate told a different story, dominated by small European countries.** The highest shares of population infected were **Andorra (17.1%), Montenegro (15.5%), Czechia (15.2%), San Marino (14.9%), and Slovenia (11.6%)**. These are all small nations with (relative to their population) extensive testing - a reminder that "more infections recorded" often means "more testing done," not necessarily "more actual spread."

**Europe bore the highest absolute death toll.** By continent: **Europe (1,016,750 deaths)**, North America (847,942), South America (672,415), Asia (520,269), Africa (121,784), and Oceania (1,046) - a gap of three orders of magnitude between the hardest-hit and least-hit continents.

**Vaccine rollout speed had almost nothing to do with population size, and everything to do with how small and centralised a place was.** As of the dataset's final date (30 April 2021), the most fully-vaccinated places were **Gibraltar (97.5%), Seychelles (60.2%), Israel (58.8%), the Falkland Islands (51.0%), and the Cayman Islands (45.5%)** - almost all small territories or city-states that could run a national rollout quickly. Meanwhile, countries like Ukraine, Guatemala, Albania, Grenada, and Honduras were all still under 0.03% fully vaccinated at the same date - essentially not yet started. This is one of the starkest findings in the dataset: a ~3,000x gap in rollout speed between the fastest and slowest countries, at the exact same point in time.

![Vaccination rollout ranking](screenshots/vaccination-ranking.png)

---

## Recommendations

1. **Don't compare case fatality rates across countries without adjusting for testing capacity.** A country-by-country CFR ranking on its own (as in Q2) is a reasonable analytical exercise, but presenting it without this caveat to a non-technical audience risks a misleading headline ("Mexico's COVID death rate is double Egypt's") that a closer look doesn't fully support.
2. **Use "percent of population infected/vaccinated" (Q3/Q11) over raw counts when comparing countries of different sizes** - raw totals overwhelmingly favour large-population countries like the US, China, and India regardless of actual severity or progress.
3. **The vaccine-rollout gap is the most actionable finding here.** For an organisation working in global health or logistics, the ~3,000x gap between the fastest and slowest vaccinating countries is a clear signal that distribution and logistics (not vaccine availability alone) were the binding constraint in early 2021 - small, centralised places could vaccinate almost everyone in months, while larger or less-centralised countries needed far longer even with intent and resources.
4. **Keep the null-handling approach from this project as a standard, not a one-off.** Treating "not reported" as genuinely different from "reported as zero" avoided fabricating trends in this analysis - the same discipline is worth applying to any dataset with real-world reporting gaps.

---

## Limitations

- The dataset ends 30 April 2021, so none of this reflects the Delta or Omicron waves, booster rollouts, or the long tail of the pandemic.
- Case and death counts depend entirely on each country's testing and reporting infrastructure - cross-country comparisons reflect reporting capacity as much as actual spread or severity.
- A few very small countries (e.g. Vanuatu, 4 total cases) produce statistically meaningless percentages when included in rankings without a minimum sample size filter - addressed in this project by reporting both the raw and filtered (100,000+ cases) version of the case-fatality ranking side by side.

## Possible next steps
- Extend the stored procedure (`GetCountrySummary`) to accept a date range parameter, not just a country.
- Build a small Power BI dashboard on top of the `PercentPopulationVaccinated` view (see note in the main project thread about whether this belongs in this project or a separate one).
