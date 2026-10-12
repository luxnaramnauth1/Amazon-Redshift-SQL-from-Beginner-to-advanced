-- ============================================================================
-- 05 | INTERMEDIATE | Window functions
-- ----------------------------------------------------------------------------
-- A window function computes a value for each row using a set of related rows
-- (the "window"), without collapsing the rows the way GROUP BY does.
--   PARTITION BY : split rows into independent groups
--   ORDER BY     : order rows inside each group
--   frame        : which rows around the current row are included
-- ============================================================================

SET search_path TO retail, public;

-- ---- ROW_NUMBER: most recent order per customer -----------------------------------
SELECT customer_id, order_id, order_date, total_amount
FROM (
    SELECT customer_id, order_id, order_date, total_amount,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC) AS rn
    FROM orders
) AS ranked
WHERE rn = 1;

-- Same result with QUALIFY, which Redshift supports and which avoids the subquery
SELECT customer_id, order_id, order_date, total_amount
FROM orders
QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC) = 1;

-- ---- RANK vs DENSE_RANK: ties ---------------------------------------------------------
--   RANK       : 1, 2, 2, 4   (gap after a tie)
--   DENSE_RANK : 1, 2, 2, 3   (no gap)
SELECT product_name,
       unit_price,
       RANK()       OVER (ORDER BY unit_price DESC) AS price_rank,
       DENSE_RANK() OVER (ORDER BY unit_price DESC) AS price_dense_rank
FROM products;

-- ---- Running total: cumulative revenue by day ----------------------------------------
SELECT order_date,
       SUM(total_amount) AS daily_revenue,
       SUM(SUM(total_amount)) OVER (
           ORDER BY order_date
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS running_revenue
FROM orders
WHERE status <> 'cancelled'
GROUP BY order_date
ORDER BY order_date;

-- ---- Moving average: 7-day average of daily revenue -----------------------------------
SELECT order_date,
       SUM(total_amount) AS daily_revenue,
       AVG(SUM(total_amount)) OVER (
           ORDER BY order_date
           ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
       ) AS revenue_7day_avg
FROM orders
WHERE status <> 'cancelled'
GROUP BY order_date
ORDER BY order_date;

-- ---- LAG / LEAD: compare each row with its neighbors ----------------------------------
SELECT order_date,
       SUM(total_amount) AS daily_revenue,
       LAG(SUM(total_amount))  OVER (ORDER BY order_date) AS previous_day,
       LEAD(SUM(total_amount)) OVER (ORDER BY order_date) AS next_day
FROM orders
GROUP BY order_date
ORDER BY order_date;

-- ---- Share of total: each order's percentage of all revenue ----------------------------
SELECT order_id,
       total_amount,
       ROUND(100.0 * total_amount / SUM(total_amount) OVER (), 2) AS pct_of_total
FROM orders;

-- ---- NTILE: split customers into spend quartiles -----------------------------------------
WITH spend AS (
    SELECT customer_id, SUM(total_amount) AS lifetime_value
    FROM orders
    GROUP BY customer_id
)
SELECT customer_id,
       lifetime_value,
       NTILE(4) OVER (ORDER BY lifetime_value DESC) AS spend_quartile   -- 1 = top 25%
FROM spend;

-- ---- FIRST_VALUE: first product bought by each customer ----------------------------------
SELECT DISTINCT
       o.customer_id,
       FIRST_VALUE(p.product_name) OVER (
           PARTITION BY o.customer_id
           ORDER BY o.order_date, oi.line_no
           ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
       ) AS first_product
FROM orders AS o
JOIN order_items AS oi ON oi.order_id = o.order_id
JOIN products    AS p  ON p.product_id = oi.product_id;
