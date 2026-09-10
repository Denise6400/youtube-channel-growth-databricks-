-- YouTube Channel Growth Analysis
-- Databricks SQL
-- Source table required: youtube_daily_views
-- Required columns: Date, Channel, Daily_Views

-- If Databricks created the table in a specific catalog/schema, replace
-- youtube_daily_views below with catalog_name.schema_name.youtube_daily_views.

-- ============================================================
-- QUERY 1: 30-day channel growth ranking and dashboard summary
-- ============================================================

WITH daily_data AS (
    SELECT
        Channel,
        TO_DATE(Date) AS View_Date,
        CAST(Daily_Views AS BIGINT) AS Daily_Views
    FROM youtube_daily_views
),
latest_date AS (
    SELECT MAX(View_Date) AS Max_Date
    FROM daily_data
),
channel_growth AS (
    SELECT
        d.Channel,
        SUM(
            CASE
                WHEN d.View_Date > DATE_SUB(l.Max_Date, 30)
                 AND d.View_Date <= l.Max_Date
                THEN d.Daily_Views ELSE 0
            END
        ) AS Current_30_Day_Views,
        SUM(
            CASE
                WHEN d.View_Date > DATE_SUB(l.Max_Date, 60)
                 AND d.View_Date <= DATE_SUB(l.Max_Date, 30)
                THEN d.Daily_Views ELSE 0
            END
        ) AS Previous_30_Day_Views
    FROM daily_data d
    CROSS JOIN latest_date l
    GROUP BY d.Channel
),
growth_results AS (
    SELECT
        Channel,
        Current_30_Day_Views,
        Previous_30_Day_Views,
        Current_30_Day_Views - Previous_30_Day_Views AS View_Increase,
        ROUND(
            100.0 * (Current_30_Day_Views - Previous_30_Day_Views)
            / NULLIF(Previous_30_Day_Views, 0),
            1
        ) AS Growth_Percent
    FROM channel_growth
),
ranked_results AS (
    SELECT
        *,
        DENSE_RANK() OVER (ORDER BY Growth_Percent DESC) AS Growth_Rank
    FROM growth_results
)
SELECT
    Channel,
    Current_30_Day_Views,
    Previous_30_Day_Views,
    View_Increase,
    Growth_Percent,
    Growth_Rank,
    CASE
        WHEN Growth_Rank = 1 THEN 'Fastest Growing Channel'
        ELSE ''
    END AS Growth_Status
FROM ranked_results
ORDER BY Growth_Rank;


-- ============================================================
-- QUERY 2: 30-day rolling average views by channel
-- Use View_Date as the X-axis, Rolling_30_Day_Avg_Views as the
-- Y-axis, and Channel as the series/group in the dashboard.
-- ============================================================

WITH daily_data AS (
    SELECT
        TO_DATE(Date) AS View_Date,
        Channel,
        CAST(Daily_Views AS BIGINT) AS Daily_Views
    FROM youtube_daily_views
)
SELECT
    View_Date,
    Channel,
    Daily_Views,
    ROUND(
        AVG(Daily_Views) OVER (
            PARTITION BY Channel
            ORDER BY View_Date
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
        ),
        1
    ) AS Rolling_30_Day_Avg_Views
FROM daily_data
ORDER BY View_Date, Channel;


-- ============================================================
-- QUERY 3: Dashboard KPI totals
-- Returns current views, prior views, net increase, and the share
-- of the total increase contributed by the leading channel.
-- ============================================================

WITH daily_data AS (
    SELECT
        Channel,
        TO_DATE(Date) AS View_Date,
        CAST(Daily_Views AS BIGINT) AS Daily_Views
    FROM youtube_daily_views
),
latest_date AS (
    SELECT MAX(View_Date) AS Max_Date
    FROM daily_data
),
channel_periods AS (
    SELECT
        d.Channel,
        SUM(CASE
            WHEN d.View_Date > DATE_SUB(l.Max_Date, 30)
             AND d.View_Date <= l.Max_Date
            THEN d.Daily_Views ELSE 0
        END) AS Current_Views,
        SUM(CASE
            WHEN d.View_Date > DATE_SUB(l.Max_Date, 60)
             AND d.View_Date <= DATE_SUB(l.Max_Date, 30)
            THEN d.Daily_Views ELSE 0
        END) AS Previous_Views
    FROM daily_data d
    CROSS JOIN latest_date l
    GROUP BY d.Channel
),
increases AS (
    SELECT
        Channel,
        Current_Views,
        Previous_Views,
        Current_Views - Previous_Views AS View_Increase
    FROM channel_periods
),
ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (ORDER BY View_Increase DESC) AS Increase_Rank,
        SUM(View_Increase) OVER () AS Total_View_Increase
    FROM increases
)
SELECT
    SUM(Current_Views) AS Current_30_Day_Total_Views,
    SUM(Previous_Views) AS Previous_30_Day_Total_Views,
    MAX(Total_View_Increase) AS Net_View_Increase,
    MAX(CASE WHEN Increase_Rank = 1 THEN Channel END) AS Leading_Channel,
    ROUND(
        100.0 * MAX(CASE WHEN Increase_Rank = 1 THEN View_Increase END)
        / NULLIF(MAX(Total_View_Increase), 0),
        1
    ) AS Leading_Channel_Share_Percent
FROM ranked;


-- ============================================================
-- QUERY 4: Exact comparison dates for a dashboard subtitle
-- ============================================================

WITH date_range AS (
    SELECT MAX(TO_DATE(Date)) AS Max_Date
    FROM youtube_daily_views
)
SELECT
    DATE_SUB(Max_Date, 29) AS Current_Period_Start,
    Max_Date AS Current_Period_End,
    DATE_SUB(Max_Date, 59) AS Previous_Period_Start,
    DATE_SUB(Max_Date, 30) AS Previous_Period_End
FROM date_range;
