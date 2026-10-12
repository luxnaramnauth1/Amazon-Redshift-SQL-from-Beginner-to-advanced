-- ============================================================================
-- 03 | BEGINNER | Querying data: SELECT, filters, sorting, grouping
-- ----------------------------------------------------------------------------
-- Redshift uses standard PostgreSQL-style SQL for everyday queries.
-- Tips for speed:
--   * Select only the columns you need (avoid SELECT * on wide tables)
--   * Filter on the SORTKEY columns (here: order_date) when you can
-- ============================================================================

SET search_path TO retail, public;

-- Basic select with ordering and a row limit
SELECT customer_id, first_name, last_name, country
FROM customers
ORDER BY last_name
LIMIT 10;

-- Distinct values
SELECT DISTINCT country
FROM customers
ORDER BY country;

-- Filtering with WHERE: comparison, BETWEEN, IN, LIKE, NULL checks
SELECT order_id, order_date, total_amount, status
FROM orders
WHERE order_date BETWEEN '2026-01-01' AND '2026-03-31'
  AND status IN ('shipped', 'delivered')
  AND total_amount IS NOT NULL
ORDER BY order_date;

SELECT first_name, email
FROM customers
WHERE email LIKE '%@example.com';

-- Aggregates with GROUP BY and HAVING (HAVING filters the groups)
SELECT category,
       COUNT(*)        AS product_count,
       AVG(unit_price) AS avg_price,
       MIN(unit_price) AS cheapest,
       MAX(unit_price) AS most_expensive
FROM products
GROUP BY category
HAVING COUNT(*) >= 1
ORDER BY avg_price DESC;

-- Revenue by status for Q1 2026
SELECT status,
       COUNT(*)          AS order_count,
       SUM(total_amount) AS revenue
FROM orders
WHERE order_date >= '2026-01-01' AND order_date < '2026-04-01'
GROUP BY status
ORDER BY revenue DESC;

-- CASE: label each order by size
SELECT order_id,
       total_amount,
       CASE
           WHEN total_amount >= 500 THEN 'large'
           WHEN total_amount >= 100 THEN 'medium'
           ELSE 'small'
       END AS size_band
FROM orders;

-- Simple inner join: orders with the customer's name
SELECT o.order_id,
       c.first_name,
       c.last_name,
       o.total_amount
FROM orders AS o
JOIN customers AS c
  ON c.customer_id = o.customer_id
WHERE o.status = 'shipped';
