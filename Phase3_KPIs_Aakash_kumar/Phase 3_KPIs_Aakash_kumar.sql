** Phase 3 KPI Calculations  

1. CREATE DATABASE StreamFlixDB;

2. USE StreamFlixDB;
GO

SELECT 'subscribers' AS table_name, COUNT_BIG(*) AS total_rows
FROM dbo.[subscribers$]

UNION ALL

SELECT 'titles', COUNT_BIG(*)
FROM dbo.[titles$]

UNION ALL

SELECT 'watch_history', COUNT_BIG(*)
FROM dbo.[watch_history$]

UNION ALL

SELECT 'ratings', COUNT_BIG(*)
FROM dbo.[ratings$]

UNION ALL

SELECT 'reviews', COUNT_BIG(*)
FROM dbo.[reviews$]

UNION ALL

SELECT 'watchlist', COUNT_BIG(*)
FROM dbo.[watchlist$];

3. -- Table structure --

USE StreamFlixDB;
GO

-- 1. Subscribers columns
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'subscribers$'
ORDER BY ORDINAL_POSITION;

-- 2. Watch History columns
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'watch_history$'
ORDER BY ORDINAL_POSITION;

-- 3. Titles columns
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'titles$'
ORDER BY ORDINAL_POSITION;

-- 4. Watchlist columns
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'watchlist$'
ORDER BY ORDINAL_POSITION;


-- 5. Ratings Table Structure
SELECT COLUMN_NAME,DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'ratings$'
ORDER BY ORDINAL_POSITION;


-- 6 Reviews Table Structure
SELECT COLUMN_NAME,DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'reviews$'
ORDER BY ORDINAL_POSITION;

----------------------------------------------------------------------

-- KPI 1: Total Watch Hours --

SELECT
    SUM(CAST(watch_duration_min AS FLOAT)) / 60.0
        AS Total_Watch_Hours
FROM dbo.[watch_history$];


-- KPI 2: Active Rate

SELECT
    COUNT(*) AS Total_Subscribers,
    SUM(
        CASE
            WHEN LOWER(LTRIM(RTRIM(
                CAST(is_active AS VARCHAR(10))
            ))) IN ('1', 'true', 'yes')
            THEN 1
            ELSE 0
        END
    ) AS Active_Subscribers,
    CAST(
        100.0 *
        SUM(
            CASE
                WHEN LOWER(LTRIM(RTRIM(
                    CAST(is_active AS VARCHAR(10))
                ))) IN ('1', 'true', 'yes')
                THEN 1
                ELSE 0
            END
        ) / NULLIF(COUNT(*), 0)
        AS DECIMAL(10,2)
    ) AS Active_Rate_Percent
FROM dbo.[subscribers$];

-- KPI 3 — Churn Rate (%)

SELECT
    COUNT(*) AS Total_Subscribers,

    SUM(
        CASE
            WHEN LOWER(LTRIM(RTRIM(
                CAST(is_active AS VARCHAR(10))
            ))) IN ('0', 'false', 'no')
            THEN 1
            ELSE 0
        END
    ) AS Inactive_Subscribers,

    CAST(
        100.0 *
        SUM(
            CASE
                WHEN LOWER(LTRIM(RTRIM(
                    CAST(is_active AS VARCHAR(10))
                ))) IN ('0', 'false', 'no')
                THEN 1
                ELSE 0
            END
        ) / NULLIF(COUNT(*), 0)
        AS DECIMAL(10,2)
    ) AS Churn_Rate_Percent

FROM dbo.[subscribers$];

-- KPI 4 — Average Completion Rate (%)

SELECT
    COUNT(*) AS Total_Watch_Records,

    CAST(
        AVG(
            TRY_CAST(completion_pct AS DECIMAL(10,2))
        )
        AS DECIMAL(10,2)
    ) AS Avg_Completion_Rate_Percent

FROM dbo.[watch_history$];

-- KPI 5 — MRR (Monthly Recurring Revenue)

SELECT
    COUNT(*) AS Active_Subscribers,

    CAST(
        COALESCE(SUM(monthly_price_usd), 0)
        AS DECIMAL(18,2)
    ) AS MRR_USD

FROM dbo.[subscribers$]
WHERE is_active = 1;

-- KPI 6: ARPU — Average Revenue Per User


SELECT
    COUNT(*) AS Active_Subscribers,

    CAST(
        COALESCE(SUM(monthly_price_usd), 0)
        AS DECIMAL(18,2)
    ) AS Total_Monthly_Revenue_USD,

    CAST(
        COALESCE(AVG(monthly_price_usd), 0)
        AS DECIMAL(10,2)
    ) AS ARPU_USD

FROM dbo.[subscribers$]
WHERE is_active = 1;

-- KPI 7: Avg Watch Time / Subscriber

SELECT
    CAST(
        COALESCE(
            SUM(TRY_CAST(watch_duration_min AS FLOAT)),
            0
        ) / 60.0
        AS DECIMAL(18,2)
    ) AS Total_Watch_Hours,

    (
        SELECT COUNT(*)
        FROM dbo.[subscribers$]
        WHERE is_active = 1
    ) AS Active_Subscribers,

    CAST(
        (
            COALESCE(
                SUM(TRY_CAST(watch_duration_min AS FLOAT)),
                0
            ) / 60.0
        ) /
        NULLIF(
            (
                SELECT COUNT(*)
                FROM dbo.[subscribers$]
                WHERE is_active = 1
            ),
            0
        )
        AS DECIMAL(18,2)
    ) AS Avg_Watch_Hours_Per_Subscriber

FROM dbo.[watch_history$];

-- KPI 8 — Watchlist Conversion (%)

SELECT
    COUNT(*) AS Total_Watchlist_Entries,

    SUM(
        CASE
            WHEN watched = 1 THEN 1
            ELSE 0
        END
    ) AS Watched_Entries,

    CAST(
        100.0 * SUM(
            CASE
                WHEN watched = 1 THEN 1
                ELSE 0
            END
        ) / NULLIF(COUNT(*), 0)
        AS DECIMAL(10,2)
    ) AS Watchlist_Conversion_Percent

FROM dbo.[watchlist$];

-- KPI 9 Hit Concentration (%)

WITH TitlePlays AS (
    SELECT
        title_id,
        COUNT(*) AS Total_Plays
    FROM dbo.[watch_history$]
    GROUP BY title_id
),
RankedTitles AS (
    SELECT
        title_id,
        Total_Plays,
        ROW_NUMBER() OVER (
            ORDER BY Total_Plays DESC, title_id
        ) AS Title_Rank,
        COUNT(*) OVER () AS Total_Titles
    FROM TitlePlays
)
SELECT
    SUM(CASE
        WHEN Title_Rank <= CEILING(Total_Titles * 0.10)
        THEN Total_Plays
        ELSE 0
    END) AS Top_10_Percent_Title_Plays,

    SUM(Total_Plays) AS Total_Plays,

    CAST(
        100.0 * SUM(CASE
            WHEN Title_Rank <= CEILING(Total_Titles * 0.10)
            THEN Total_Plays
            ELSE 0
        END)
        / NULLIF(SUM(Total_Plays), 0)
        AS DECIMAL(10,2)
    ) AS Hit_Concentration_Percent

FROM RankedTitles;

-- KPI 10 — Originals Share of Hours (%)

SELECT
    CAST(
        100.0 *
        SUM(
            CASE
                WHEN t.is_original = 1
                THEN COALESCE(w.watch_duration_min, 0)
                ELSE 0
            END
        )
        /
        NULLIF(
            SUM(COALESCE(w.watch_duration_min, 0)),
            0
        )
        AS DECIMAL(10,2)
    ) AS Originals_Share_Of_Hours_Percent

FROM dbo.[watch_history$] AS w

INNER JOIN dbo.[titles$] AS t
    ON w.title_id = t.title_id;


--query for Cohort Retention--

WITH SubscriberCohort AS
(
    SELECT
        subscriber_id,
        signup_date,
        churn_date,
        DATEFROMPARTS(
            YEAR(signup_date),
            MONTH(signup_date),
            1
        ) AS Cohort_Month
    FROM dbo.[subscribers$]
    WHERE signup_date IS NOT NULL
),
RetentionFlags AS
(
    SELECT
        Cohort_Month,
        subscriber_id,

        CASE
            WHEN churn_date IS NULL
              OR churn_date >= DATEADD(MONTH, 3, signup_date)
            THEN 1 ELSE 0
        END AS Retained_3_Months,

        CASE
            WHEN churn_date IS NULL
              OR churn_date >= DATEADD(MONTH, 6, signup_date)
            THEN 1 ELSE 0
        END AS Retained_6_Months,

        CASE
            WHEN churn_date IS NULL
              OR churn_date >= DATEADD(MONTH, 12, signup_date)
            THEN 1 ELSE 0
        END AS Retained_12_Months

    FROM SubscriberCohort
)
SELECT
    Cohort_Month,
    COUNT(*) AS Cohort_Size,

    SUM(Retained_3_Months) AS Retained_3_Months,

    CAST(
        100.0 * SUM(Retained_3_Months)
        / NULLIF(COUNT(*), 0)
        AS DECIMAL(10,2)
    ) AS Retention_3_Months_Pct,

    SUM(Retained_6_Months) AS Retained_6_Months,

    CAST(
        100.0 * SUM(Retained_6_Months)
        / NULLIF(COUNT(*), 0)
        AS DECIMAL(10,2)
    ) AS Retention_6_Months_Pct,

    SUM(Retained_12_Months) AS Retained_12_Months,

    CAST(
        100.0 * SUM(Retained_12_Months)
        / NULLIF(COUNT(*), 0)
        AS DECIMAL(10,2)
    ) AS Retention_12_Months_Pct

FROM RetentionFlags
GROUP BY Cohort_Month
ORDER BY Cohort_Month;
