-- ============================================================================
-- 07 | INTERMEDIATE | Semi-structured data: the SUPER type and PartiQL
-- ----------------------------------------------------------------------------
-- SUPER stores JSON-like nested data (objects and arrays) directly in Redshift.
-- You can query it with dot notation and array indexes (PartiQL), without
-- flattening the data into many tables first.
-- ============================================================================

SET search_path TO retail, public;

-- ---- Create a table with a SUPER column -----------------------------------------------
CREATE TABLE IF NOT EXISTS retail.events (
    event_id     BIGINT,
    received_at  TIMESTAMP,
    payload      SUPER               -- nested JSON
)
SORTKEY (received_at);

-- ---- Insert JSON with JSON_PARSE ---------------------------------------------------------
INSERT INTO retail.events (event_id, received_at, payload)
VALUES
    (1, '2026-10-01 10:00:00',
     JSON_PARSE('{"type":"click","user":{"id":7,"plan":"pro"},"tags":["web","promo"]}')),
    (2, '2026-10-01 10:05:00',
     JSON_PARSE('{"type":"purchase","user":{"id":8,"plan":"free"},"tags":["mobile"],"amount":49.9}')),
    (3, '2026-10-02 09:30:00',
     JSON_PARSE('{"type":"click","user":{"id":7,"plan":"pro"},"tags":[]}'));

-- ---- Read nested fields with dot notation ----------------------------------------------------
-- Cast with ::VARCHAR (or ::INTEGER, ::DECIMAL) to get a normal SQL type
SELECT e.event_id,
       e.payload.type::VARCHAR         AS event_type,
       e.payload.user.id::INTEGER      AS user_id,
       e.payload.user.plan::VARCHAR    AS plan
FROM retail.events AS e;

-- ---- Filter on nested values -----------------------------------------------------------------
SELECT e.event_id, e.payload.type::VARCHAR AS event_type
FROM retail.events AS e
WHERE e.payload.user.plan::VARCHAR = 'pro';

-- ---- Access array elements by index ------------------------------------------------------------
SELECT e.event_id,
       e.payload.tags[0]::VARCHAR AS first_tag
FROM retail.events AS e
WHERE e.payload.tags[0] IS NOT NULL;

-- ---- Unnest an array into rows (one row per element) ------------------------------------------
-- The second FROM item iterates over the array. Each element becomes a row.
SELECT e.event_id,
       t::VARCHAR AS tag
FROM retail.events AS e,
     e.payload.tags AS t;

-- ---- Aggregate over nested data ------------------------------------------------------------------
SELECT e.payload.type::VARCHAR AS event_type,
       COUNT(*)                AS events,
       COUNT(DISTINCT e.payload.user.id::INTEGER) AS unique_users
FROM retail.events AS e
GROUP BY 1
ORDER BY events DESC;

-- ---- Convert a SUPER value back to a JSON string --------------------------------------------------
SELECT event_id,
       JSON_SERIALIZE(payload) AS payload_json
FROM retail.events;

-- ---- Loading JSON files from S3 into a SUPER column -------------------------------------------------
-- 'auto' matches JSON keys to column names; the SUPER column receives the whole document.
-- COPY retail.events
-- FROM 's3://my-bucket/exports/events/'
-- IAM_ROLE 'arn:aws:iam::123456789012:role/RedshiftCopyRole'
-- FORMAT AS JSON 'auto'
-- GZIP;
