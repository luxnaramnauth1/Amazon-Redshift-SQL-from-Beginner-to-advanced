-- ============================================================================
-- 10 | ADVANCED | Security: users, groups, least-privilege access, and masking
-- ----------------------------------------------------------------------------
-- Principles:
--   * Grant privileges to GROUPS, then add users to groups
--   * Give read-only access by default
--   * Expose sensitive columns through views, not the base tables
--   * Never hard-code real passwords in scripts; use AWS Secrets Manager or IAM auth
-- ============================================================================

-- ---- Users and groups ---------------------------------------------------------------
-- Placeholder password: replace it, or use IAM-based authentication instead
CREATE USER analyst_ana PASSWORD 'REPLACE_WITH_STRONG_PASSWORD';

CREATE GROUP analysts;
ALTER GROUP analysts ADD USER analyst_ana;

-- ---- Schema and table privileges --------------------------------------------------------
GRANT USAGE ON SCHEMA retail TO GROUP analysts;
GRANT SELECT ON ALL TABLES IN SCHEMA retail TO GROUP analysts;

-- Tables created later in the schema are readable automatically
ALTER DEFAULT PRIVILEGES IN SCHEMA retail
    GRANT SELECT ON TABLES TO GROUP analysts;

-- ---- Mask personal data with a view ------------------------------------------------------
-- Analysts query the view; the base table with full emails and names stays private
CREATE OR REPLACE VIEW retail.customers_masked AS
SELECT customer_id,
       first_name,
       LEFT(last_name, 1) || '.'     AS last_initial,
       country,
       SPLIT_PART(email, '@', 2)     AS email_domain,   -- keeps the domain, hides the user
       created_at
FROM retail.customers;

GRANT SELECT ON retail.customers_masked TO GROUP analysts;

-- Stop direct access to the sensitive base table (revoking is explicit and auditable)
REVOKE ALL ON retail.customers FROM GROUP analysts;

-- ---- Writers: a separate group that can load and change data ----------------------------------
CREATE GROUP etl_writers;
GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA retail TO GROUP etl_writers;

-- ---- Workload-level control: limit concurrent queries for a group via WLM -----------------------
-- Configure in the console or with the WLM parameter group; enforce concurrency
-- and memory limits per queue so one team cannot starve the others.

-- ---- Row-level security (RLS) ----------------------------------------------------------------------
-- Redshift supports row-level security policies that filter rows per user or role.
-- Syntax has several parts (CREATE RLS POLICY, ATTACH RLS POLICY, and enabling RLS
-- on the table), so check the current AWS documentation before applying it in production.

-- ---- Auditing: who is connected and what they are running ------------------------------------------
SELECT usename, usesysid, valuntil
FROM pg_user
ORDER BY usename;

SELECT query, userid, starttime, LEFT(querytxt, 100) AS sql_text
FROM stl_query
WHERE starttime > DATEADD(day, -1, GETDATE())
ORDER BY starttime DESC
LIMIT 50;

-- ---- Remove access when someone leaves ---------------------------------------------------------------
ALTER GROUP analysts DROP USER analyst_ana;
-- DROP USER analyst_ana;    -- uncomment to delete the account entirely
