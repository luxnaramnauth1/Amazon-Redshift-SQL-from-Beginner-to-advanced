-- ============================================================================
-- 11 | ADVANCED | Redshift Spectrum, materialized views, stored procedures,
--            incremental upserts, and UNLOAD to a data lake
-- ----------------------------------------------------------------------------
-- Topics:
--   * Spectrum: query Parquet/ORC files in S3 without loading them
--   * Materialized views: precomputed results that stay fast for dashboards
--   * Stored procedures: reusable, multi-step ETL logic
--   * UNLOAD: export query results back to S3
-- ============================================================================

SET search_path TO retail, public;

-- ---- 1. Redshift Spectrum: an external schema backed by the AWS Glue Data Catalog --------------
-- Replace the database name and IAM role with your own values.
CREATE EXTERNAL SCHEMA IF NOT EXISTS spectrum
FROM DATA CATALOG
DATABASE 'lake_db'
IAM_ROLE 'arn:aws:iam::123456789012:role/RedshiftSpectrumRole'
CREATE EXTERNAL DATABASE IF NOT EXISTS;

-- An external table over Parquet files in S3, partitioned by date
CREATE EXTERNAL TABLE spectrum.clickstream (
    user_id  BIGINT,
    url      VARCHAR(2048),
    ts       TIMESTAMP
)
PARTITIONED BY (event_date DATE)
STORED AS PARQUET
LOCATION 's3://my-data-lake/clickstream/';

-- Register each partition so Spectrum knows where its files are
ALTER TABLE spectrum.clickstream
ADD IF NOT EXISTS PARTITION (event_date = '2026-10-01')
LOCATION 's3://my-data-lake/clickstream/event_date=2026-10-01/';

-- Join S3 data (Spectrum) with warehouse data (local tables) in one query
SELECT c.country,
       COUNT(*) AS clicks
FROM spectrum.clickstream AS s
JOIN retail.customers     AS c ON c.customer_id = s.user_id
WHERE s.event_date = '2026-10-01'      -- partition filter limits the S3 scan
GROUP BY c.country;

-- ---- 2. Materialized view with automatic refresh -------------------------------------------------
-- Precomputes the daily revenue. Dashboards query the small result instead of the raw orders.
CREATE MATERIALIZED VIEW retail.mv_daily_revenue
AUTO REFRESH YES
AS
SELECT order_date,
       COUNT(*)          AS orders,
       SUM(total_amount) AS revenue
FROM retail.orders
WHERE status <> 'cancelled'
GROUP BY order_date;

-- Manual refresh (useful when AUTO REFRESH is off or you want control over timing)
REFRESH MATERIALIZED VIEW retail.mv_daily_revenue;

-- ---- 3. Incremental upsert pattern with a stored procedure -------------------------------------------
CREATE TABLE IF NOT EXISTS retail.customer_summary (
    customer_id      INTEGER       NOT NULL,
    lifetime_value   DECIMAL(14,2),
    last_order_date  DATE,
    PRIMARY KEY (customer_id)
)
DISTSTYLE ALL;

-- Recompute summaries only for customers who ordered since p_since.
-- Delete the old rows, insert the new ones: one transaction, so readers never see gaps.
CREATE OR REPLACE PROCEDURE retail.refresh_customer_summary(p_since DATE)
AS $$
BEGIN
    CREATE TEMP TABLE stage_summary AS
    SELECT o.customer_id,
           SUM(o.total_amount) AS lifetime_value,
           MAX(o.order_date)   AS last_order_date
    FROM retail.orders AS o
    WHERE o.customer_id IN (
        SELECT DISTINCT customer_id
        FROM retail.orders
        WHERE order_date >= p_since
    )
    GROUP BY o.customer_id;

    DELETE FROM retail.customer_summary
    USING stage_summary AS s
    WHERE retail.customer_summary.customer_id = s.customer_id;

    INSERT INTO retail.customer_summary
    SELECT customer_id, lifetime_value, last_order_date
    FROM stage_summary;

    DROP TABLE stage_summary;
END;
$$ LANGUAGE plpgsql;

-- Run it for the last 7 days of activity
CALL retail.refresh_customer_summary(CURRENT_DATE - 7);

-- ---- 4. Export query results to S3 as Parquet (for other tools or a data lake) -------------------------
-- Single quotes inside the query are doubled ('').
UNLOAD ('SELECT order_id, customer_id, order_date, total_amount
         FROM retail.orders
         WHERE order_date >= ''2026-01-01''')
TO 's3://my-bucket/exports/orders_2026_'
IAM_ROLE 'arn:aws:iam::123456789012:role/RedshiftCopyRole'
PARQUET
PARALLEL ON
ALLOWOVERWRITE;

-- ---- 5. Production habits ----------------------------------------------------------------------------
-- * Wrap multi-step loads in a procedure or a transaction, so failures roll back cleanly
-- * Schedule refreshes with Amazon EventBridge, Airflow, or dbt
-- * Keep raw, staging, and mart schemas separate (for example: raw.*, stage.*, mart.*)
-- * Monitor load times and query runtimes after each change, not just once
