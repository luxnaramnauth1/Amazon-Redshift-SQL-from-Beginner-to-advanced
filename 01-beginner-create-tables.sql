-- ============================================================================
-- 01 | BEGINNER | Creating schemas and tables in Amazon Redshift
-- ----------------------------------------------------------------------------
-- Redshift is a columnar, massively parallel (MPP) data warehouse built on
-- PostgreSQL. Most standard SQL works, but two table options matter a lot:
--   DISTSTYLE / DISTKEY : how rows are spread across compute nodes
--   SORTKEY             : how rows are ordered on disk (speeds up range filters)
-- Redshift does NOT enforce PRIMARY KEY or FOREIGN KEY constraints. They are
-- informational only, so your loading process must guarantee uniqueness.
-- ============================================================================

-- A schema is a namespace for tables (like a folder)
CREATE SCHEMA IF NOT EXISTS retail;

SET search_path TO retail, public;

-- Customers: a small dimension table.
-- DISTSTYLE ALL copies the whole table to every node, so joins never move data.
CREATE TABLE IF NOT EXISTS retail.customers (
    customer_id  INTEGER      NOT NULL,
    first_name   VARCHAR(100),
    last_name    VARCHAR(100),
    email        VARCHAR(255),
    country      CHAR(2),
    created_at   TIMESTAMP,
    PRIMARY KEY (customer_id)          -- informational only
)
DISTSTYLE ALL
SORTKEY (customer_id);

-- Products: another small dimension table
CREATE TABLE IF NOT EXISTS retail.products (
    product_id    INTEGER       NOT NULL,
    product_name  VARCHAR(200),
    category      VARCHAR(50),
    unit_price    DECIMAL(10,2),
    PRIMARY KEY (product_id)
)
DISTSTYLE ALL;

-- Orders: a large fact table.
-- DISTKEY(order_id) places each order's rows and its line items on the same node,
-- so joining orders to order_items does not need to shuffle data.
CREATE TABLE IF NOT EXISTS retail.orders (
    order_id      BIGINT        NOT NULL,
    customer_id   INTEGER       NOT NULL,
    order_date    DATE          NOT NULL,
    status        VARCHAR(20)   ENCODE ZSTD,     -- compression encoding
    total_amount  DECIMAL(12,2) ENCODE AZ64,
    PRIMARY KEY (order_id)
)
DISTKEY (order_id)
SORTKEY (order_date);                            -- date-range filters skip blocks

-- Order line items: co-located with orders via the same DISTKEY
CREATE TABLE IF NOT EXISTS retail.order_items (
    order_id     BIGINT        NOT NULL,
    line_no      SMALLINT      NOT NULL,
    product_id   INTEGER       NOT NULL,
    quantity     INTEGER       NOT NULL,
    line_amount  DECIMAL(12,2),
    PRIMARY KEY (order_id, line_no)
)
DISTKEY (order_id)
SORTKEY (order_id);

-- Inspect the column definitions and encodings you just created
SELECT "column", type, encoding, distkey, sortkey
FROM pg_table_def
WHERE schemaname = 'retail' AND tablename = 'orders';
