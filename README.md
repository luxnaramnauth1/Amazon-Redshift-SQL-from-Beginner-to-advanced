
# Amazon Redshift SQL Lessons: Beginner to Advanced

Eleven standalone SQL files that take you from creating tables to tuning queries, securing data, and working with data lakes. Every file uses the same `retail` schema, so run them in order.

## Learning path

| # | File | Level | What you learn |
|---|------|-------|----------------|
| 01 | `01-beginner-create-tables.sql` | Beginner | Schemas, table design, `DISTSTYLE`, `DISTKEY`, `SORTKEY`, column encodings |
| 02 | `02-beginner-load-and-change-data.sql` | Beginner | `INSERT`, bulk `COPY` from S3, `UPDATE`, `DELETE`, transactions |
| 03 | `03-beginner-querying-basics.sql` | Beginner | `SELECT`, filtering, sorting, `GROUP BY`, `HAVING`, `CASE`, simple joins |
| 04 | `04-intermediate-joins-subqueries-ctes.sql` | Intermediate | Outer and anti-joins, subqueries, CTEs, recursive CTEs, `UNION ALL` |
| 05 | `05-intermediate-window-functions.sql` | Intermediate | `ROW_NUMBER`, `QUALIFY`, `RANK`, running totals, moving averages, `LAG`/`LEAD`, `NTILE` |
| 06 | `06-intermediate-date-and-string-functions.sql` | Intermediate | Date arithmetic, `DATE_TRUNC`, time zones, string functions, `LISTAGG`, NULL handling |
| 07 | `07-intermediate-semistructured-super.sql` | Intermediate | `SUPER` columns, `JSON_PARSE`, PartiQL dot notation, unnesting arrays |
| 08 | `08-advanced-distribution-and-sort-keys.sql` | Advanced | Distribution styles, compound vs interleaved sort keys, skew checks, `VACUUM`, `ANALYZE` |
| 09 | `09-advanced-query-performance.sql` | Advanced | Finding slow queries, reading `EXPLAIN` plans, result cache, WLM query groups |
| 10 | `10-advanced-security-and-governance.sql` | Advanced | Users, groups, least-privilege grants, masking views, auditing, offboarding |
| 11 | `11-advanced-spectrum-mv-procedures-unload.sql` | Advanced | Redshift Spectrum, materialized views, stored-procedure upserts, `UNLOAD` to Parquet |

Work through the files in order. Each one builds on the tables and data from the earlier files.

## Before you start

You need:

- **A Redshift cluster or Serverless workgroup** (a development environment is best for practice)
- **A query tool**, such as the Redshift Query Editor v2 in the AWS console, or `psql` with the Redshift connection details
- **An S3 bucket** with sample CSV or JSON files, for the `COPY` and `UNLOAD` examples
- **IAM roles** that the cluster can use:
  - a copy role with `s3:GetObject` (and `s3:PutObject` for `UNLOAD`) on your bucket
  - a Spectrum role with access to the AWS Glue Data Catalog and your data lake bucket (file 11)

## Placeholders to replace

These values are examples. Replace them before running the files:

| Placeholder | Where it appears | What to put there |
|-------------|------------------|-------------------|
| `my-bucket`, `my-data-lake` | Files 02, 07, 11 | Your S3 bucket names |
| `123456789012` in `arn:aws:iam::...` | Files 02, 07, 11 | Your AWS account ID |
| `RedshiftCopyRole` | Files 02, 07, 11 | Your copy/unload IAM role name |
| `RedshiftSpectrumRole` | File 11 | Your Spectrum IAM role name |
| `lake_db` | File 11 | Your AWS Glue database name |
| `REPLACE_WITH_STRONG_PASSWORD` | File 10 | A strong password, or switch to IAM-based authentication |

Do not commit real passwords or account IDs to version control. Store them in AWS Secrets Manager or use IAM authentication.

## Things to know

- **Constraints are not enforced.** `PRIMARY KEY` and `FOREIGN KEY` are informational in Redshift. Your load process must prevent duplicates.
- **The sample tables start empty.** File 02 inserts a few customers and products, but `orders` and `order_items` need data from `COPY` (or your own `INSERT` statements) before the queries in files 03 to 11 return results.
- **Files 02 and 07 include `COPY` commands** that need real S3 data. Edit the paths before running them.
- **Some statements are destructive.** File 02 updates and deletes rows, file 08 runs `VACUUM`, and file 10 revokes access. Run these on a development cluster first.
- **Commented-out lines are intentional.** Examples include `TRUNCATE`, `CANCEL`, and the `DROP USER` in file 10. Remove the `--` only when you mean to run them.
- **File 10 covers row-level security only in outline.** The exact `CREATE RLS POLICY` syntax has several steps. Check the current AWS documentation before using it in production.
- **Redshift features change.** Check the official documentation for your cluster version, especially for `QUALIFY`, `MERGE`, and Spectrum syntax.

## Suggested practice flow

1. Run files 01 and 02 to create the schema and load data.
2. Run files 03 to 07 and change the filters and aggregates to answer your own questions.
3. For each query in files 08 and 09, run `EXPLAIN` before and after changing the distribution or sort keys.
4. Work through file 10 on a separate test user, not your admin account.
5. Use file 11 once you have an S3 data lake with Parquet files.

## Verification note

These files were checked with a SQL parser that supports the Redshift dialect. That check confirms the syntax of most statements, but it cannot run them. Some Redshift-only commands, such as `ANALYZE COMPRESSION` and `VACUUM`, are not recognized by the parser. Run the files on a test cluster before depending on them.

## License

Free to use and adapt for learning.
