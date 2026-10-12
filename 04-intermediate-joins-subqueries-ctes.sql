-- ============================================================================
-- 04 | INTERMEDIATE | Joins, subqueries, and Common Table Expressions (CTEs)
-- ============================================================================

SET search_path TO retail, public;

-- ---- Outer joins: keep rows that have no match --------------------------------
-- Every customer, with their order count (0 if they never ordered)
SELECT c.customer_id,
       c.first_name,
       COUNT(o.order_id) AS order_count     -- COUNT(column) ignores NULLs from the LEFT JOIN
FROM customers AS c
LEFT JOIN orders AS o
       ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name
ORDER BY order_count DESC;

-- ---- Anti-join: customers with NO orders -----------------------------------------
SELECT c.customer_id, c.email
FROM customers AS c
WHERE NOT EXISTS (
    SELECT 1
    FROM orders AS o
    WHERE o.customer_id = c.customer_id
);

-- ---- Semi-join: customers who bought at least one book ------------------------------
SELECT c.customer_id, c.first_name
FROM customers AS c
WHERE c.customer_id IN (
    SELECT o.customer_id
    FROM orders AS o
    JOIN order_items AS oi ON oi.order_id = o.order_id
    JOIN products AS p     ON p.product_id = oi.product_id
    WHERE p.category = 'books'
);

-- ---- Scalar subquery: compare each product with the average price ----------------
SELECT product_name,
       unit_price,
       unit_price - (SELECT AVG(unit_price) FROM products) AS diff_from_avg
FROM products;

-- ---- CTEs: name intermediate results to keep queries readable -----------------------
WITH paid_orders AS (
    SELECT order_id, customer_id, order_date, total_amount
    FROM orders
    WHERE status <> 'cancelled'
),
customer_spend AS (
    SELECT customer_id,
           COUNT(*)          AS orders,
           SUM(total_amount) AS lifetime_value
    FROM paid_orders
    GROUP BY customer_id
)
SELECT c.first_name,
       c.last_name,
       cs.orders,
       cs.lifetime_value
FROM customer_spend AS cs
JOIN customers AS c ON c.customer_id = cs.customer_id
ORDER BY cs.lifetime_value DESC
LIMIT 10;

-- ---- Chaining CTEs: monthly revenue ---------------------------------------------------
WITH monthly_revenue AS (
    SELECT DATE_TRUNC('month', order_date) AS month,
           SUM(total_amount)               AS revenue
    FROM orders
    WHERE status <> 'cancelled'
    GROUP BY 1                              -- GROUP BY position: allowed in Redshift
)
SELECT month, revenue
FROM monthly_revenue
ORDER BY month;

-- ---- Recursive CTE: generate a calendar of dates (useful for filling gaps) -------------
WITH RECURSIVE calendar (day) AS (
    SELECT DATE '2026-01-01'
    UNION ALL
    SELECT DATEADD(day, 1, day)
    FROM calendar
    WHERE day < DATE '2026-01-31'
)
SELECT c.day,
       COALESCE(SUM(o.total_amount), 0) AS revenue
FROM calendar AS c
LEFT JOIN orders AS o
       ON o.order_date = c.day
      AND o.status <> 'cancelled'
GROUP BY c.day
ORDER BY c.day;

-- ---- UNION ALL: combine result sets (no duplicate removal, so it is faster) -----------
SELECT 'customer' AS record_type, email AS identifier FROM customers
UNION ALL
SELECT 'product'  AS record_type, product_name        FROM products;
