-- ============================================================================
-- 06 | INTERMEDIATE | Date, time, string, and conditional functions
-- ============================================================================

SET search_path TO retail, public;

-- ---- Current date and time ----------------------------------------------------------
SELECT GETDATE()        AS now_utc_timestamp,    -- current timestamp (UTC cluster time)
       CURRENT_DATE    AS today;

-- ---- Date arithmetic -----------------------------------------------------------------
-- DATEDIFF(datepart, start, end): number of datepart boundaries crossed
SELECT order_id,
       order_date,
       DATEDIFF(day, order_date, CURRENT_DATE)     AS days_since_order,
       DATEADD(day, 30, order_date)                AS return_deadline
FROM orders
LIMIT 10;

-- Customer tenure in whole months
SELECT customer_id,
       DATEDIFF(month, created_at, GETDATE()) AS months_as_customer
FROM customers;

-- ---- Truncating and extracting parts of dates -----------------------------------------
SELECT DATE_TRUNC('month', order_date)  AS month_start,   -- first instant of the month
       DATE_TRUNC('week',  order_date)  AS week_start,
       EXTRACT(year  FROM order_date)   AS order_year,
       EXTRACT(month FROM order_date)   AS order_month,
       EXTRACT(dow   FROM order_date)   AS day_of_week     -- 0 = Sunday
FROM orders;

-- ---- Formatting -----------------------------------------------------------------------
SELECT TO_CHAR(order_date, 'YYYY-MM')          AS year_month,
       TO_CHAR(total_amount, '999,999.99')     AS formatted_amount
FROM orders;

-- Parse a string into a date
SELECT TO_DATE('2026-10-12', 'YYYY-MM-DD') AS parsed_date;

-- ---- Time zones ------------------------------------------------------------------------
-- Convert stored UTC timestamps to London local time
SELECT customer_id,
       created_at                                         AS created_utc,
       CONVERT_TIMEZONE('UTC', 'Europe/London', created_at) AS created_london
FROM customers;

-- ---- String functions --------------------------------------------------------------------
SELECT first_name || ' ' || last_name           AS full_name,   -- concatenation
       UPPER(country)                           AS country_code,
       LENGTH(email)                            AS email_length,
       SPLIT_PART(email, '@', 2)                AS email_domain   -- part 2 after '@'
FROM customers;

-- Count customers per email domain
SELECT SPLIT_PART(email, '@', 2) AS email_domain,
       COUNT(*)                  AS customers
FROM customers
GROUP BY 1
ORDER BY customers DESC;

-- Regular expressions: keep only letters and spaces in product names
SELECT product_id,
       REGEXP_REPLACE(product_name, '[^A-Za-z ]', '') AS cleaned_name
FROM products;

-- Aggregate strings: one comma-separated list of names per country
SELECT country,
       LISTAGG(first_name, ', ') WITHIN GROUP (ORDER BY first_name) AS customer_names
FROM customers
GROUP BY country;

-- ---- NULL handling ------------------------------------------------------------------------
SELECT customer_id,
       COALESCE(NULLIF(TRIM(email), ''), 'no-email@unknown.invalid') AS contact_email,
       NVL(last_name, '(no last name)')                              AS last_name_safe
FROM customers;

-- ---- CASE for bucketing and conditional aggregation ------------------------------------------
SELECT DATE_TRUNC('month', order_date) AS month,
       SUM(CASE WHEN status = 'delivered' THEN total_amount ELSE 0 END) AS delivered_revenue,
       SUM(CASE WHEN status = 'cancelled' THEN total_amount ELSE 0 END) AS cancelled_revenue
FROM orders
GROUP BY 1
ORDER BY 1;
