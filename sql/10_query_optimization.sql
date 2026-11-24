-- 10_query_optimization.sql
-- PostgreSQL optimization baseline
-- Database: supply_chain_analytics

DROP TABLE IF EXISTS pg_temp.opt_indexes;
DROP TABLE IF EXISTS pg_temp.opt_constraints;
DROP TABLE IF EXISTS pg_temp.opt_snapshot;
DROP TABLE IF EXISTS pg_temp.opt_post_snapshot;

-- =========================================================
-- A. Existing Index and Table Overview
-- =========================================================

SELECT schemaname, tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN (
      'customer', 'customer_order', 'order_item',
      'product', 'category', 'department'
  )
ORDER BY tablename, indexname;

SELECT n.nspname AS table_schema,
       c.relname AS table_name,
       pg_size_pretty(pg_total_relation_size(c.oid)) AS total_size,
       pg_total_relation_size(c.oid) AS total_bytes,
       c.reltuples::bigint AS estimated_rows,
       pg_stat_get_live_tuples(c.oid) AS live_rows
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind = 'r'
  AND c.relname IN (
      'customer', 'customer_order', 'order_item',
      'product', 'category', 'department'
  )
ORDER BY c.relname;

SELECT tc.table_name, tc.constraint_name, tc.constraint_type,
       kcu.column_name, ccu.table_name AS referenced_table,
       ccu.column_name AS referenced_column
FROM information_schema.table_constraints tc
LEFT JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
 AND tc.table_schema = kcu.table_schema
LEFT JOIN information_schema.constraint_column_usage ccu
  ON tc.constraint_name = ccu.constraint_name
 AND tc.table_schema = ccu.table_schema
WHERE tc.table_schema = 'public'
  AND tc.table_name IN (
      'customer', 'customer_order', 'order_item',
      'product', 'category', 'department'
  )
  AND tc.constraint_type IN ('PRIMARY KEY', 'FOREIGN KEY')
ORDER BY tc.table_name, tc.constraint_type, tc.constraint_name;

ANALYZE public.customer;
ANALYZE public.customer_order;
ANALYZE public.order_item;
ANALYZE public.product;
ANALYZE public.category;
ANALYZE public.department;

CREATE TEMP TABLE opt_indexes AS
SELECT schemaname, tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public';

CREATE TEMP TABLE opt_constraints AS
SELECT table_schema, table_name, constraint_name, constraint_type
FROM information_schema.table_constraints
WHERE table_schema = 'public';

CREATE TEMP TABLE opt_snapshot AS
SELECT 'customer' AS table_name, COUNT(*) AS row_count,
       SUM(customer_id)::numeric AS key_sum FROM public.customer
UNION ALL
SELECT 'customer_order', COUNT(*), SUM(order_id)::numeric
FROM public.customer_order
UNION ALL
SELECT 'order_item', COUNT(*), SUM(order_item_id)::numeric
FROM public.order_item
UNION ALL
SELECT 'product', COUNT(*), SUM(product_id)::numeric
FROM public.product
UNION ALL
SELECT 'category', COUNT(*), SUM(category_id)::numeric
FROM public.category
UNION ALL
SELECT 'department', COUNT(*), SUM(department_id)::numeric
FROM public.department;

-- =========================================================
-- B. Baseline Execution Plans
-- =========================================================
-- Repeat each plan during review: warm-up plus two measured runs.
-- Record actual time/rows, shared hits/reads, temp I/O and plan operations.

-- B1. Stage 07 market-level late-delivery aggregation.
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT COALESCE(NULLIF(BTRIM(market), ''), '[Missing or blank]') AS market,
       COUNT(*) AS order_count,
       COUNT(*) FILTER (
           WHERE BTRIM(delivery_status) ILIKE 'Late delivery'
       ) AS late_count
FROM public.customer_order
GROUP BY COALESCE(NULLIF(BTRIM(market), ''), '[Missing or blank]')
ORDER BY late_count DESC, market;

-- B2. Stage 08 category-month demand and prior-month LAG().
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
WITH category_month AS (
    SELECT DATE_TRUNC('month', o.order_date) AS month_start,
           COALESCE(NULLIF(BTRIM(c.category_name), ''), '[Missing category]')
               AS category_name,
           COALESCE(SUM(oi.quantity), 0) AS total_units
    FROM public.order_item oi
    JOIN public.customer_order o ON o.order_id = oi.order_id
    LEFT JOIN public.product p ON p.product_id = oi.product_id
    LEFT JOIN public.category c ON c.category_id = p.category_id
    WHERE o.order_date IS NOT NULL
    GROUP BY DATE_TRUNC('month', o.order_date),
             COALESCE(NULLIF(BTRIM(c.category_name), ''), '[Missing category]')
),
trend AS (
    SELECT *,
           LAG(total_units) OVER (
               PARTITION BY category_name
               ORDER BY month_start
           ) AS prior_units
    FROM category_month
)
SELECT category_name,
       TO_CHAR(month_start, 'YYYY-MM') AS order_month,
       total_units,
       prior_units
FROM trend
ORDER BY month_start DESC, category_name;

-- B3. Stage 09 active-customer cumulative/top-25 ranking.
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
WITH active AS (
    SELECT c.customer_id, SUM(oi.quantity) AS total_units
    FROM public.customer c
    JOIN public.customer_order co ON co.customer_id = c.customer_id
    JOIN public.order_item oi ON oi.order_id = co.order_id
    WHERE oi.quantity IS NOT NULL
    GROUP BY c.customer_id
),
ranked AS (
    SELECT *,
           SUM(total_units) OVER (
               ORDER BY total_units DESC, customer_id ASC
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
           ) AS cumulative_units,
           ROW_NUMBER() OVER (
               ORDER BY total_units DESC, customer_id ASC
           ) AS customer_rank
    FROM active
),
concentration AS (
    SELECT *,
           ROUND(
               100.0 * cumulative_units
               / NULLIF(SUM(total_units) OVER (), 0),
               4
           ) AS cumulative_percentage
    FROM ranked
)
SELECT customer_rank, customer_id, total_units,
       cumulative_units, cumulative_percentage
FROM concentration
ORDER BY customer_rank
LIMIT 25;

-- =========================================================
-- C. Optimization Investigation
-- =========================================================

-- Check candidate columns against existing and equivalent index definitions.
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND (
      (tablename = 'customer_order' AND indexdef LIKE '%(customer_id)%')
   OR (tablename = 'order_item' AND indexdef LIKE '%(order_id)%')
   OR (tablename = 'order_item' AND indexdef LIKE '%(product_id)%')
  )
ORDER BY tablename, indexname;

-- Candidate FK indexes were not justified:
-- customer_order(customer_id): B3 used full customer/order hash joins.
-- order_item(order_id): B2/B3 used full fact-table hash joins.
-- order_item(product_id): B2 used full fact-table aggregation.
-- A FOREIGN KEY or JOIN column alone is not sufficient evidence for an index.
-- The observed plans used sequential scans and in-memory hash operations.

-- =========================================================
-- D. Optimization Summary
-- =========================================================

-- Observation: B1 reads 65,752 orders and uses a sequential scan plus a
-- one-batch hashed aggregate. B2 reads 180,519 items and uses hash joins,
-- hashed aggregation, window processing and sorts. B3 reads 20,652 customers,
-- 65,752 orders and 180,519 items, then performs hash joins, grouping,
-- windows and sorting.
--
-- Interpretation: no measured benefit supports an additional index or rewrite.
-- The existing sequential scans, hash joins and in-memory operations are retained.
-- Measured baseline examples: B1 75.632-96.691 ms; B2 approximately
-- 390-438 ms; B3 approximately 356-360 ms. Repeated runs varied with cache
-- and system load. These times establish baseline behavior, not optimization.

-- =========================================================
-- E. Validation and Safety Checks
-- =========================================================

-- B1 result equivalence.
WITH baseline AS (
    SELECT COALESCE(NULLIF(BTRIM(market), ''), '[Missing or blank]') AS market,
           COUNT(*) AS order_count,
           COUNT(*) FILTER (
               WHERE BTRIM(delivery_status) ILIKE 'Late delivery'
           ) AS late_count
    FROM public.customer_order
    GROUP BY COALESCE(NULLIF(BTRIM(market), ''), '[Missing or blank]')
),
optimized AS (
    SELECT COALESCE(NULLIF(BTRIM(market), ''), '[Missing or blank]') AS market,
           COUNT(*) AS order_count,
           COUNT(*) FILTER (
               WHERE BTRIM(delivery_status) ILIKE 'Late delivery'
           ) AS late_count
    FROM public.customer_order
    GROUP BY COALESCE(NULLIF(BTRIM(market), ''), '[Missing or blank]')
)
SELECT NOT EXISTS (
    (SELECT * FROM baseline EXCEPT ALL SELECT * FROM optimized)
    UNION ALL
    (SELECT * FROM optimized EXCEPT ALL SELECT * FROM baseline)
) AS market_result_matches;

-- B2 result equivalence, including prior_units and NULL handling.
WITH category_month AS (
    SELECT DATE_TRUNC('month', o.order_date) AS month_start,
           COALESCE(NULLIF(BTRIM(c.category_name), ''), '[Missing category]')
               AS category_name,
           COALESCE(SUM(oi.quantity), 0) AS total_units
    FROM public.order_item oi
    JOIN public.customer_order o ON o.order_id = oi.order_id
    LEFT JOIN public.product p ON p.product_id = oi.product_id
    LEFT JOIN public.category c ON c.category_id = p.category_id
    WHERE o.order_date IS NOT NULL
    GROUP BY DATE_TRUNC('month', o.order_date),
             COALESCE(NULLIF(BTRIM(c.category_name), ''), '[Missing category]')
),
trend AS (
    SELECT *,
           LAG(total_units) OVER (
               PARTITION BY category_name
               ORDER BY month_start
           ) AS prior_units
    FROM category_month
),
baseline AS (
    SELECT category_name,
           TO_CHAR(month_start, 'YYYY-MM') AS order_month,
           total_units, prior_units
    FROM trend
),
optimized_category_month AS (
    SELECT DATE_TRUNC('month', o.order_date) AS month_start,
           COALESCE(NULLIF(BTRIM(c.category_name), ''), '[Missing category]')
               AS category_name,
           COALESCE(SUM(oi.quantity), 0) AS total_units
    FROM public.order_item oi
    JOIN public.customer_order o ON o.order_id = oi.order_id
    LEFT JOIN public.product p ON p.product_id = oi.product_id
    LEFT JOIN public.category c ON c.category_id = p.category_id
    WHERE o.order_date IS NOT NULL
    GROUP BY DATE_TRUNC('month', o.order_date),
             COALESCE(NULLIF(BTRIM(c.category_name), ''), '[Missing category]')
),
optimized_trend AS (
    SELECT *,
           LAG(total_units) OVER (
               PARTITION BY category_name
               ORDER BY month_start
           ) AS prior_units
    FROM optimized_category_month
),
optimized AS (
    SELECT category_name,
           TO_CHAR(month_start, 'YYYY-MM') AS order_month,
           total_units, prior_units
    FROM optimized_trend
)
SELECT NOT EXISTS (
    (SELECT * FROM baseline EXCEPT ALL SELECT * FROM optimized)
    UNION ALL
    (SELECT * FROM optimized EXCEPT ALL SELECT * FROM baseline)
) AS category_result_matches;

-- B3 result equivalence, including rank, cumulative units and top 25.
WITH active AS (
    SELECT c.customer_id, SUM(oi.quantity) AS total_units
    FROM public.customer c
    JOIN public.customer_order co ON co.customer_id = c.customer_id
    JOIN public.order_item oi ON oi.order_id = co.order_id
    WHERE oi.quantity IS NOT NULL
    GROUP BY c.customer_id
),
ranked AS (
    SELECT *,
           SUM(total_units) OVER (
               ORDER BY total_units DESC, customer_id ASC
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
           ) AS cumulative_units,
           ROW_NUMBER() OVER (
               ORDER BY total_units DESC, customer_id ASC
           ) AS customer_rank
    FROM active
),
concentration AS (
    SELECT *,
           ROUND(
               100.0 * cumulative_units
               / NULLIF(SUM(total_units) OVER (), 0),
               4
           ) AS cumulative_percentage
    FROM ranked
),
baseline AS (
    SELECT customer_rank, customer_id, total_units,
           cumulative_units, cumulative_percentage
    FROM concentration
    ORDER BY customer_rank
    LIMIT 25
),
optimized_active AS (
    SELECT c.customer_id, SUM(oi.quantity) AS total_units
    FROM public.customer c
    JOIN public.customer_order co ON co.customer_id = c.customer_id
    JOIN public.order_item oi ON oi.order_id = co.order_id
    WHERE oi.quantity IS NOT NULL
    GROUP BY c.customer_id
),
optimized_ranked AS (
    SELECT *,
           SUM(total_units) OVER (
               ORDER BY total_units DESC, customer_id ASC
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
           ) AS cumulative_units,
           ROW_NUMBER() OVER (
               ORDER BY total_units DESC, customer_id ASC
           ) AS customer_rank
    FROM optimized_active
),
optimized_concentration AS (
    SELECT *,
           ROUND(
               100.0 * cumulative_units
               / NULLIF(SUM(total_units) OVER (), 0),
               4
           ) AS cumulative_percentage
    FROM optimized_ranked
),
optimized AS (
    SELECT customer_rank, customer_id, total_units,
           cumulative_units, cumulative_percentage
    FROM optimized_concentration
    ORDER BY customer_rank
    LIMIT 25
)
SELECT NOT EXISTS (
    (SELECT * FROM baseline EXCEPT ALL SELECT * FROM optimized)
    UNION ALL
    (SELECT * FROM optimized EXCEPT ALL SELECT * FROM baseline)
) AS customer_result_matches;

-- Existing index preservation.
SELECT COUNT(*) AS missing_existing_indexes
FROM opt_indexes old
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_indexes now
    WHERE now.schemaname = old.schemaname
      AND now.tablename = old.tablename
      AND now.indexname = old.indexname
      AND now.indexdef = old.indexdef
);

-- Existing constraint preservation.
SELECT COUNT(*) AS missing_existing_constraints
FROM opt_constraints old
WHERE NOT EXISTS (
    SELECT 1
    FROM information_schema.table_constraints now
    WHERE now.table_schema = old.table_schema
      AND now.table_name = old.table_name
      AND now.constraint_name = old.constraint_name
      AND now.constraint_type = old.constraint_type
);

-- Validate exact candidate names if an index was later evaluated.
SELECT px.indexname, px.indexdef,
       pi.indisvalid, pi.indisready, pi.indislive
FROM pg_indexes px
JOIN pg_index pi
  ON pi.indexrelid = (
      SELECT ix.oid
      FROM pg_class ix
      JOIN pg_namespace nx ON nx.oid = ix.relnamespace
      WHERE ix.relname = px.indexname
        AND nx.nspname = px.schemaname
  )
WHERE px.schemaname = 'public'
  AND px.indexname IN (
      'idx_opt_customer_order_customer_id',
      'idx_opt_order_item_order_id',
      'idx_opt_order_item_product_id'
  );

-- Basic count/key-sum snapshot; not complete data-integrity proof.
CREATE TEMP TABLE opt_post_snapshot AS
SELECT 'customer' AS table_name, COUNT(*) AS row_count,
       SUM(customer_id)::numeric AS key_sum FROM public.customer
UNION ALL
SELECT 'customer_order', COUNT(*), SUM(order_id)::numeric
FROM public.customer_order
UNION ALL
SELECT 'order_item', COUNT(*), SUM(order_item_id)::numeric
FROM public.order_item
UNION ALL
SELECT 'product', COUNT(*), SUM(product_id)::numeric
FROM public.product
UNION ALL
SELECT 'category', COUNT(*), SUM(category_id)::numeric
FROM public.category
UNION ALL
SELECT 'department', COUNT(*), SUM(department_id)::numeric
FROM public.department;

SELECT
    (SELECT COUNT(*) FROM (
        SELECT * FROM opt_snapshot
        EXCEPT
        SELECT * FROM opt_post_snapshot
    ) AS differences_one_way)
  + (SELECT COUNT(*) FROM (
        SELECT * FROM opt_post_snapshot
        EXCEPT
        SELECT * FROM opt_snapshot
    ) AS differences_other_way)
AS data_snapshot_differences;
