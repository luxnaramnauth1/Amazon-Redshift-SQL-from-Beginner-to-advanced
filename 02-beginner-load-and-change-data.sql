-- ============================================================================
-- 02 | BEGINNER | Loading and changing data
-- ----------------------------------------------------------------------------
-- Redshift is built for BULK loading with COPY from Amazon S3.
-- Row-by-row INSERTs are fine for small reference data, but slow for big loads.
-- ============================================================================

SET search_path TO retail, public;

-- 1. Small inserts (multi-row VALUES) for reference data
INSERT INTO retail.customers (customer_id, first_name, last_name, email, country, created_at)
VALUES
    (1, 'Ada',   'Lovelace', 'ada@example.com',   'GB', '2026-01-05 09:00:00'),
    (2, 'Grace', 'Hopper',   'grace@example.com', 'US', '2026-01-07 14:30:00'),
    (3, 'Linus', 'Torvalds', 'linus@example.com', 'FI', '2026-02-01 08:15:00');

INSERT INTO retail.products (product_id, product_name, category, unit_price)
VALUES
    (101, 'Analytical Engine Notebook', 'books',       24.99),
    (102, 'Mechanical Keyboard',        'electronics', 89.50),
    (103, 'Coffee Mug',                 'kitchen',      9.75);

-- 2. Bulk load from S3 (the recommended way).
--    Replace the bucket, prefix and IAM role with your own values.
--    The IAM role must be attached to the cluster and allow s3:GetObject.
COPY retail.orders
FROM 's3://my-bucket/exports/orders/'
IAM_ROLE 'arn:aws:iam::123456789012:role/RedshiftCopyRole'
FORMAT AS CSV
IGNOREHEADER 1
GZIP
REGION 'us-east-1'
DATEFORMAT 'auto'
TIMEFORMAT 'auto'
MAXERROR 10;                        -- stop after 10 bad rows instead of the first

-- 3. Update rows
UPDATE retail.orders
SET status = 'shipped'
WHERE order_id = 1001;

-- 4. Delete rows
DELETE FROM retail.orders
WHERE status = 'cancelled'
  AND order_date < '2025-01-01';

-- 5. Wrap related changes in a transaction so they succeed or fail together
BEGIN;
UPDATE retail.products
SET unit_price = unit_price * 1.10
WHERE category = 'books';

INSERT INTO retail.products (product_id, product_name, category, unit_price)
VALUES (104, 'Pocket Notebook', 'books', 6.00);
COMMIT;

-- 6. Remove all rows quickly (cannot be rolled back inside some contexts;
--    use DELETE when you need a WHERE clause)
-- TRUNCATE retail.order_items;

-- 7. Check how much data a table holds and whether it needs maintenance
SELECT "table", tbl_rows, unsorted, stats_off
FROM svv_table_info
WHERE "schema" = 'retail';
