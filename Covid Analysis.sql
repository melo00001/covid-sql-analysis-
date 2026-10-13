USE CovidAnalysis;
 
-- Clean slate in case a previous wizard attempt left a partial table
DROP TABLE IF EXISTS dbo.CovidDeaths;
DROP TABLE IF EXISTS dbo.CovidVaccinations;

CREATE TABLE dbo.CovidDeaths (
    iso_code                         VARCHAR(10)   NOT NULL,
    continent                        VARCHAR(20)   NULL,
    location                         VARCHAR(100)  NOT NULL,
    [date]                           VARCHAR(20)   NOT NULL,   -- converted to DATE below
    population                       BIGINT        NULL,
    total_cases                      BIGINT        NULL,
    new_cases                        INT           NULL,
    new_cases_smoothed                FLOAT         NULL,
    total_deaths                     BIGINT        NULL,
    new_deaths                       INT           NULL,
    new_deaths_smoothed              FLOAT         NULL,
    total_cases_per_million          FLOAT         NULL,
    new_cases_per_million            FLOAT         NULL,
    new_cases_smoothed_per_million   FLOAT         NULL,
    total_deaths_per_million         FLOAT         NULL,
    new_deaths_per_million           FLOAT         NULL,
    new_deaths_smoothed_per_million  FLOAT         NULL,
    reproduction_rate                FLOAT         NULL,
    icu_patients                     FLOAT         NULL,
    icu_patients_per_million         FLOAT         NULL,
    hosp_patients                    FLOAT         NULL,
    hosp_patients_per_million        FLOAT         NULL,
    weekly_icu_admissions            FLOAT         NULL,
    weekly_icu_admissions_per_million FLOAT        NULL,
    weekly_hosp_admissions           FLOAT         NULL,
    weekly_hosp_admissions_per_million FLOAT       NULL
);
 



CREATE TABLE dbo.CovidVaccinations (
    iso_code                              VARCHAR(10)   NOT NULL,
    continent                             VARCHAR(20)   NULL,
    location                              VARCHAR(100)  NOT NULL,
    [date]                                VARCHAR(20)   NOT NULL, 
    new_tests                             INT           NULL,
    total_tests                           BIGINT        NULL,
    total_tests_per_thousand              FLOAT         NULL,
    new_tests_per_thousand                FLOAT         NULL,
    new_tests_smoothed                    INT           NULL,
    new_tests_smoothed_per_thousand       FLOAT         NULL,
    positive_rate                         FLOAT         NULL,
    tests_per_case                        FLOAT         NULL,
    tests_units                           VARCHAR(30)   NULL,
    total_vaccinations                    BIGINT        NULL,
    people_vaccinated                     BIGINT        NULL,
    people_fully_vaccinated               BIGINT        NULL,
    new_vaccinations                      INT           NULL,
    new_vaccinations_smoothed             INT           NULL,
    total_vaccinations_per_hundred        FLOAT         NULL,
    people_vaccinated_per_hundred         FLOAT         NULL,
    people_fully_vaccinated_per_hundred   FLOAT         NULL,
    new_vaccinations_smoothed_per_million FLOAT         NULL,
    stringency_index                      FLOAT         NULL,
    population_density                    FLOAT         NULL,
    median_age                            FLOAT         NULL,
    aged_65_older                         FLOAT         NULL,
    aged_70_older                         FLOAT         NULL,
    gdp_per_capita                        FLOAT         NULL,
    extreme_poverty                       FLOAT         NULL,
    cardiovasc_death_rate                 FLOAT         NULL,
    diabetes_prevalence                   FLOAT         NULL,
    female_smokers                        FLOAT         NULL,
    male_smokers                          FLOAT         NULL,
    handwashing_facilities                FLOAT         NULL,
    hospital_beds_per_thousand             FLOAT         NULL,
    life_expectancy                       FLOAT         NULL,
    human_development_index               FLOAT         NULL
);

BULK INSERT dbo.CovidDeaths
FROM 'C:\Users\CC\Desktop\Datasets\Covid_death.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);

BULK INSERT dbo.CovidVaccinations
FROM 'C:\Users\CC\Desktop\Datasets\Covid_vaccinations.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a', 
    TABLOCK
);

ALTER TABLE dbo.CovidDeaths ADD date_converted DATE;

UPDATE dbo.CovidDeaths SET date_converted = CONVERT(DATE, [date], 101);
ALTER TABLE dbo.CovidDeaths DROP COLUMN [date];
EXEC sp_rename 'dbo.CovidDeaths.date_converted', 'date', 'COLUMN';

ALTER TABLE dbo.CovidVaccinations ADD date_converted DATE;

UPDATE dbo.CovidVaccinations SET date_converted = CONVERT(DATE, [date], 101);
ALTER TABLE dbo.CovidVaccinations DROP COLUMN [date];
EXEC sp_rename 'dbo.CovidVaccinations.date_converted', 'date', 'COLUMN';

CREATE INDEX IX_CovidDeaths_LocDate ON dbo.CovidDeaths(location, [date]);
CREATE INDEX IX_CovidVaccinations_LocDate ON dbo.CovidVaccinations(location, [date]);

SELECT COUNT(*) AS DeathsRowCount FROM dbo.CovidDeaths;
SELECT COUNT(*) AS VaccinationsRowCount FROM dbo.CovidVaccinations;
SELECT MIN([date]) AS EarliestDate, MAX([date]) AS LatestDate FROM dbo.CovidDeaths;
SELECT TOP 5 * FROM dbo.CovidVaccinations;

/* Data Cleaning process (Duplicates Check) */
/* (Covid Deaths) */

WITH DupeCheck AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY location, [date]
            ORDER BY (SELECT NULL)
        ) AS rn
    FROM dbo.CovidDeaths
)
SELECT COUNT(*) AS duplicate_rows_found
FROM DupeCheck
WHERE rn > 1;

/* (Covid Vaccination) */

WITH DupeCheck AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY location, [date]
            ORDER BY (SELECT NULL)
        ) AS rn
    FROM dbo.CovidVaccinations
)
SELECT COUNT(*) AS duplicate_rows_found
FROM DupeCheck
WHERE rn > 1;

/* Trim spaces */

UPDATE dbo.CovidDeaths
SET location  = LTRIM(RTRIM(location)),
    continent = LTRIM(RTRIM(continent)),
    iso_code  = LTRIM(RTRIM(iso_code));

UPDATE dbo.CovidVaccinations
SET location  = LTRIM(RTRIM(location)),
    continent = LTRIM(RTRIM(continent)),
    iso_code  = LTRIM(RTRIM(iso_code));


/* Check for aggregate rows */

SELECT DISTINCT iso_code, location
FROM dbo.CovidDeaths
WHERE iso_code LIKE 'OWID_%'
ORDER BY location;

/* Check for NUlls */
SELECT
    'population'    AS column_name, COUNT(*) - COUNT(population)    AS null_count FROM dbo.CovidDeaths
UNION ALL
SELECT 'new_cases',    COUNT(*) - COUNT(new_cases)    FROM dbo.CovidDeaths
UNION ALL
SELECT 'new_deaths',   COUNT(*) - COUNT(new_deaths)   FROM dbo.CovidDeaths
UNION ALL
SELECT 'total_cases',  COUNT(*) - COUNT(total_cases)  FROM dbo.CovidDeaths
UNION ALL
SELECT 'total_deaths', COUNT(*) - COUNT(total_deaths) FROM dbo.CovidDeaths
UNION ALL
SELECT 'icu_patients', COUNT(*) - COUNT(icu_patients) FROM dbo.CovidDeaths
UNION ALL
SELECT 'hosp_patients',COUNT(*) - COUNT(hosp_patients) FROM dbo.CovidDeaths;





/* Total Cases, Total Deaths,  Death Percentage */
SELECT
    SUM(new_cases)                         AS total_cases,
    SUM(new_deaths)                        AS total_deaths,
    CAST(SUM(new_deaths) * 100.0 / SUM(new_cases) AS DECIMAL(10,2)) AS death_percentage
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL;  


/* Countires with Highest Death Rate relative to confirmed cases */
SELECT
    location,
    population,
    MAX(total_cases)  AS highest_infection_count,
    MAX(total_deaths) AS highest_death_count,
    CAST(MAX(total_deaths) * 100.0 / MAX(total_cases) AS DECIMAL(10,2)) AS death_percentage
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location, population
HAVING MAX(total_cases) > 0
ORDER BY death_percentage DESC;


/* Countries with the highest infection rate relative to population */
SELECT
    location,
    population,
    MAX(total_cases) AS highest_infection_count,
    CAST(MAX(total_cases) * 100.0 / population AS DECIMAL(10,2)) AS percent_population_infected
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY percent_population_infected DESC;



/* Countries with the highest infection rate relative to population where 
total cases is not null*/
SELECT
    location,
    population,
    MAX(total_cases) AS highest_infection_count,
    CAST(MAX(total_cases) * 100.0 / population AS DECIMAL(10,2)) AS percent_population_infected
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location, population
HAVING MAX(total_cases) IS NOT NULL
ORDER BY percent_population_infected DESC;


/* Continent-level death counts */
SELECT
    continent,
    SUM(new_deaths) AS total_death_count
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL
GROUP BY continent
ORDER BY total_death_count DESC;


/* Rolling 7-day average of new cases per country */
SELECT
    location,
    [date],
    new_cases,
    CAST(AVG(CAST(new_cases AS DECIMAL(10,2))) OVER (
        PARTITION BY location
        ORDER BY [date]
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS DECIMAL(10,2)) AS rolling_7day_avg_cases
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL
ORDER BY location, [date];

/* running total of vaccinations against population, by
       country and date */
SELECT
    d.location,
    d.[date],
    d.population,
    v.new_vaccinations,
    SUM(v.new_vaccinations) OVER (
        PARTITION BY d.location
        ORDER BY d.[date]
    ) AS rolling_people_vaccinated
FROM dbo.CovidDeaths d
JOIN dbo.CovidVaccinations v
    ON d.location = v.location
    AND d.[date] = v.[date]
WHERE d.continent IS NOT NULL
ORDER BY d.location, d.[date];

/* CTE version of Q6, extended to calculate % of population
       vaccinated (running total / population)  */

WITH PopvsVac AS (
    SELECT
        d.location,
        d.[date],
        d.population,
        v.new_vaccinations,
        SUM(v.new_vaccinations) OVER (
            PARTITION BY d.location
            ORDER BY d.[date]
        ) AS rolling_people_vaccinated
    FROM dbo.CovidDeaths d
    JOIN dbo.CovidVaccinations v
        ON d.location = v.location
        AND d.[date] = v.[date]
    WHERE d.continent IS NOT NULL
)
SELECT
    *,
    CAST((rolling_people_vaccinated * 100.0) / population AS DECIMAL(10,2)) AS percent_population_vaccinated
FROM PopvsVac
ORDER BY location, [date];


/* Rank countries by death rate per million within each continent */
SELECT
    continent,
    location,
    MAX(total_deaths_per_million) AS death_rate_per_million,
    RANK() OVER (
        PARTITION BY continent
        ORDER BY MAX(total_deaths_per_million) DESC
    ) AS continent_rank
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL
GROUP BY continent, location
ORDER BY continent, continent_rank;

/* percent of population vaccinated, saved as a reusable
       object - this is what you'd point a Power BI/Tableau dashboard
       at later, instead of re-running the CTE every time. */
CREATE OR ALTER VIEW dbo.PercentPopulationVaccinated AS
SELECT
    d.location,
    d.[date],
    d.population,
    v.new_vaccinations,
    SUM(v.new_vaccinations) OVER (
        PARTITION BY d.location
        ORDER BY d.[date]
    ) AS rolling_people_vaccinated
FROM dbo.CovidDeaths d
JOIN dbo.CovidVaccinations v
    ON d.location = v.location
    AND d.[date] = v.[date]
WHERE d.continent IS NOT NULL;

SELECT * FROM dbo.PercentPopulationVaccinated ORDER BY location, [date];


/* STORED PROCEDURE: return key metrics for any one country,
        parameterised so it's reusable rather than hand-editing a
        WHERE clause each time. */
CREATE OR ALTER PROCEDURE dbo.GetCountrySummary
    @CountryName VARCHAR(100)
AS
BEGIN
    SELECT
        d.location,
        MAX(d.total_cases)  AS total_cases,
        MAX(d.total_deaths) AS total_deaths,
        CAST(MAX(d.total_deaths) * 100.0 / MAX(d.total_cases) AS DECIMAL(10,2)) AS death_percentage,
        MAX(v.people_fully_vaccinated) AS people_fully_vaccinated,
        CAST(MAX(v.people_fully_vaccinated) * 100.0 / MAX(d.population) AS DECIMAL(10,2)) AS percent_fully_vaccinated
    FROM dbo.CovidDeaths d
    JOIN dbo.CovidVaccinations v
        ON d.location = v.location
        AND d.[date] = v.[date]
    WHERE d.location = @CountryName
    GROUP BY d.location;
END;

EXEC dbo.GetCountrySummary @CountryName = 'United Kingdom';


/* Vaccination rollout speed: rank every country by % of
        population fully vaccinated, as of the most recent date each
        country reported it. */
WITH LatestVaccination AS (
    SELECT
        d.location,
        d.population,
        d.[date],
        v.people_fully_vaccinated,
        ROW_NUMBER() OVER (
            PARTITION BY d.location
            ORDER BY d.[date] DESC
        ) AS rn
    FROM dbo.CovidDeaths d
    JOIN dbo.CovidVaccinations v
        ON d.location = v.location
        AND d.[date] = v.[date]
    WHERE d.continent IS NOT NULL
      AND v.people_fully_vaccinated IS NOT NULL
)
SELECT
    location,
    [date] AS latest_reported_date,
    population,
    people_fully_vaccinated,
    CAST(people_fully_vaccinated * 100.0 / population AS DECIMAL(10,2)) AS percent_fully_vaccinated
FROM LatestVaccination
WHERE rn = 1
ORDER BY percent_fully_vaccinated DESC;








































































