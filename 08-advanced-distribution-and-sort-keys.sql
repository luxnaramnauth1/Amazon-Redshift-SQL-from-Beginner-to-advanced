-- ============================================================================
-- 08 | ADVANCED | Distribution styles, sort keys, and table maintenance
-- ----------------------------------------------------------------------------
-- Most Redshift performance problems come from data layout:
--   * DISTSTYLE / DISTKEY decide which node stores each row. Joins are fastest
--     when matching rows live on the same node.
--   * SORTKEY decides on-disk order. Range filters skip blocks that cannot match.
--   * Compression (ENCODE) and maintenance (VACUUM, ANALYZE) keep tables compact.
-- ============================================================================

SET search_path TO retail, public;

-- ---- Distribution styles -------------------------------------------------------------
--   AUTO : Redshift chooses (default). Good starting point.
--   EVEN : rows spread round-robin. Good for tables without a common join key.
--   KEY  : rows placed by a column's hash. Good when a column is joined often.
--   ALL  : full copy on every node. Good for small, frequently joined dimensions.

-- Example: a large fact table distributed on the most common join key
CREATE TABLE IF NOT EXISTS retail.order_facts (
    order_id     BIGINT,
    customer_id  INTEGER,
    product_id   INTEGER,
    order_date   DATE,
    amount       DECIMAL(12,2)
)
DISTSTYLE KEY
DISTKEY (customer_id)
COMPOUND SORTKEY (order_date, customer_id);

-- ---- Sort keys ---------------------------------------------------------------------------
--   COMPOUND   : best when queries filter on the first column (or a prefix of columns)
--   INTERLEAVED: equal weight to several columns, for varied filter patterns.
--                Costlier to maintain; use only when the query pattern truly needs it.
CREATE TABLE IF NOT EXISTS retail.page_views (
    customer_id  INTEGER,
    page_id      INTEGER,
    viewed_at    TIMESTAMP
)
DISTSTYLE KEY
DISTKEY (customer_id)
INTERLEAVED SORTKEY (customer_id, page_id);

-- ---- Create a rebuilt table with a better layout (CREATE TABLE AS) -------------------------------
CREATE TABLE retail.orders_2026
DISTKEY (customer_id)
SORTKEY (order_date)
AS
SELECT *
FROM retail.orders
WHERE order_date >= '2026-01-01';

-- ---- Diagnose skew: uneven row counts across nodes slow queries down --------------------------------
SELECT "table",
       diststyle,
       tbl_rows,
       skew_rows,            -- ratio of rows on the fullest node to the emptiest; near 1.0 is ideal
       skew_sortkey1,
       size                  -- size in 1 MB blocks
FROM svv_table_info
WHERE "schema" = 'retail'
ORDER BY skew_rows DESC;

-- ---- Check how much unsorted data is waiting to be sorted ---------------------------------------
SELECT "table", unsorted, stats_off
FROM svv_table_info
WHERE "schema" = 'retail'
ORDER BY unsorted DESC;

-- ---- Compression: let Redshift recommend encodings for an existing table ------------------------
ANALYZE COMPRESSION retail.orders;

-- ---- Maintenance -----------------------------------------------------------------------------------
-- Update planner statistics after large loads
ANALYZE retail.orders;

-- Re-sort rows and reclaim space left by deletes and updates
VACUUM retail.orders;

-- Only re-sort (faster when you have just loaded new rows)
VACUUM SORT ONLY retail.orders;

-- Only reclaim space from deleted rows
VACUUM DELETE ONLY retail.orders;

-- Note: Redshift runs automatic VACUUM and ANALYZE in the background.
-- Manual runs are useful right after very large loads or deletes.
