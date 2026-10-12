-- ============================================================================
-- 09 | ADVANCED | Diagnosing and tuning query performance
-- ----------------------------------------------------------------------------
-- Workflow:
--   1. Find slow queries (system tables)
--   2. Read the query plan with EXPLAIN
--   3. Fix the cause: data layout, filters, joins, or workload management (WLM)
-- ============================================================================

SET search_path TO retail, public;

-- ---- 1. Find the slowest queries from the last hour ------------------------------------------
--    svl_qlog: one row per query. elapsed is in microseconds.
SELECT query,
       userid,
       ROUND(elapsed / 1000000.0, 2) AS seconds,
       starttime,
       LEFT(querytxt, 120)           AS sql_text
FROM svl_qlog
WHERE starttime > DATEADD(hour, -1, GETDATE())
  AND aborted = 0
ORDER BY elapsed DESC
LIMIT 20;

-- ---- 2. See warnings the optimizer raised (missing stats, nested loops, disk spills) -------------
SELECT query, event, solution, event_time
FROM stl_alert_event_log
ORDER BY event_time DESC
LIMIT 20;

-- ---- 3. Read a query plan --------------------------------------------------------------------------
--    Look for:
--      DS_DIST_NONE   : no data movement (best)
--      DS_BCAST_INNER : a small table was broadcast to all nodes (usually fine)
--      DS_DIST_BOTH   : both sides were redistributed (costly; revisit DISTKEYs)
--      Nested Loop    : often a missing join condition (may produce huge row counts)
EXPLAIN
SELECT c.country,
       SUM(o.total_amount) AS revenue
FROM orders AS o
JOIN customers AS c ON c.customer_id = o.customer_id
WHERE o.order_date >= '2026-01-01'
GROUP BY c.country;

-- ---- 4. Write queries that prune data early ----------------------------------------------------
-- Good: filters on the SORTKEY column (order_date) let Redshift skip blocks
SELECT COUNT(*)
FROM orders
WHERE order_date BETWEEN '2026-07-01' AND '2026-07-31';

-- Bad: wrapping the sort key in a function prevents block skipping
-- SELECT COUNT(*) FROM orders WHERE TO_CHAR(order_date, 'YYYY-MM') = '2026-07';

-- ---- 5. Avoid redundant work: result cache -------------------------------------------------------------
-- Redshift caches identical read-only query results. Turn it off when benchmarking.
SET enable_result_cache_for_session TO off;
-- ... run the benchmark query here ...
SET enable_result_cache_for_session TO on;

-- ---- 6. Assign queries to a WLM queue or query group ----------------------------------------------------
-- Put heavy reports in their own queue so they do not starve dashboards
SET query_group TO 'reporting';
SELECT category, SUM(unit_price) AS total_value
FROM products
GROUP BY category;
RESET query_group;

-- ---- 7. Watch what is running right now ----------------------------------------------------------------
SELECT query, state, queue_time, exec_time, service_class
FROM stv_wlm_query_state
ORDER BY exec_time DESC;

-- ---- 8. Cancel a runaway query (use the query id from svl_qlog) -------------------------------------------
-- CANCEL 12345;
