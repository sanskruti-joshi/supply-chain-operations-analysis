-- =========================================================
-- 08_inventory_analysis.sql
-- Purpose: Demand-based inventory planning analysis
-- =========================================================
--
-- Scope and interpretation
-- - Order-item quantity represents observed units ordered.
-- - One order_item row represents one order-item record.
-- - Missing dates and missing product attributes are reported separately.

-- =========================================================
-- A. Overall Product Demand
-- =========================================================

-- A1. Overall observed demand summary
SELECT
    COUNT(*) AS total_order_items,
    COUNT(DISTINCT product_id) AS distinct_products_with_items,
    COUNT(*) FILTER (WHERE product_id IS NULL) AS items_missing_product_id,
    COUNT(*) FILTER (WHERE quantity IS NULL) AS items_missing_quantity,
    COUNT(*) FILTER (WHERE quantity IS NOT NULL AND quantity <= 0) AS items_nonpositive_quantity,
    COALESCE(SUM(quantity), 0) AS total_units_ordered,
    ROUND(COALESCE(SUM(sales_amount), 0), 2) AS observed_sales_amount,
    ROUND(AVG(quantity), 2) AS average_units_per_item
FROM public.order_item;

-- A2. Distribution of units on order-item records
-- This distribution distinguishes item frequency from total units.
SELECT
    COALESCE(quantity::text, '[Missing quantity]') AS units_on_item,
    COUNT(*) AS order_item_count,
    COALESCE(SUM(quantity), 0) AS total_units,
    ROUND(
        100.0 * COUNT(*)
        / NULLIF((SELECT COUNT(*) FROM public.order_item), 0),
        2
    ) AS percentage_of_order_items
FROM public.order_item
GROUP BY quantity
ORDER BY
    CASE WHEN quantity IS NULL THEN 1 ELSE 0 END,
    quantity;

-- A3. Highest-demand products, by observed units
SELECT
    p.product_id,
    COALESCE(NULLIF(BTRIM(p.product_name), ''), '[Missing product name]') AS product_name,
    c.category_name,
    COUNT(oi.order_item_id) AS order_item_count,
    COALESCE(SUM(oi.quantity), 0) AS total_units_ordered,
    ROUND(COALESCE(SUM(oi.sales_amount), 0), 2) AS observed_sales_amount
FROM public.product p
LEFT JOIN public.order_item oi ON oi.product_id = p.product_id
LEFT JOIN public.category c ON c.category_id = p.category_id
GROUP BY p.product_id, p.product_name, c.category_name
ORDER BY total_units_ordered DESC, p.product_id
LIMIT 25;

-- =========================================================
-- B. Product-Level Demand Analysis
-- =========================================================

-- B1. Complete product ranking, including zero-demand products
-- RANK allows ties to share a rank; product_id provides deterministic display order.
WITH product_demand AS (
    SELECT
        p.product_id,
        COALESCE(NULLIF(BTRIM(p.product_name), ''), '[Missing product name]') AS product_name,
        COALESCE(NULLIF(BTRIM(c.category_name), ''), '[Missing category]') AS category_name,
        COALESCE(NULLIF(BTRIM(d.department_name), ''), '[Missing department]') AS department_name,
        COUNT(oi.order_item_id) AS order_item_count,
        COUNT(DISTINCT oi.order_id) AS distinct_order_count,
        COALESCE(SUM(oi.quantity), 0) AS total_units_ordered,
        ROUND(COALESCE(SUM(oi.sales_amount), 0), 2) AS observed_sales_amount
    FROM public.product p
    LEFT JOIN public.order_item oi ON oi.product_id = p.product_id
    LEFT JOIN public.category c ON c.category_id = p.category_id
    LEFT JOIN public.department d ON d.department_id = p.department_id
    GROUP BY p.product_id, p.product_name, c.category_name, d.department_name
)
SELECT
    product_id,
    product_name,
    category_name,
    department_name,
    order_item_count,
    distinct_order_count,
    total_units_ordered,
    observed_sales_amount,
    RANK() OVER (
        ORDER BY total_units_ordered DESC
    ) AS demand_rank
FROM product_demand
ORDER BY demand_rank, product_id;

-- =========================================================
-- C. Category and Department Demand
-- =========================================================

-- C1. Demand by category
WITH category_demand AS (
    SELECT
        COALESCE(NULLIF(BTRIM(c.category_name), ''), '[Missing category]') AS category_name,
        COUNT(oi.order_item_id) AS order_item_count,
        COALESCE(SUM(oi.quantity), 0) AS total_units_ordered,
        ROUND(COALESCE(SUM(oi.sales_amount), 0), 2) AS observed_sales_amount
    FROM public.order_item oi
    LEFT JOIN public.product p ON p.product_id = oi.product_id
    LEFT JOIN public.category c ON c.category_id = p.category_id
    GROUP BY COALESCE(NULLIF(BTRIM(c.category_name), ''), '[Missing category]')
)
SELECT
    category_name,
    order_item_count,
    total_units_ordered,
    observed_sales_amount,
    ROUND(
        100.0 * total_units_ordered
        / NULLIF(SUM(total_units_ordered) OVER (), 0),
        2
    ) AS percentage_of_observed_units
FROM category_demand
ORDER BY total_units_ordered DESC, category_name;

-- C2. Demand by department
WITH department_demand AS (
    SELECT
        COALESCE(NULLIF(BTRIM(d.department_name), ''), '[Missing department]') AS department_name,
        COUNT(oi.order_item_id) AS order_item_count,
        COALESCE(SUM(oi.quantity), 0) AS total_units_ordered,
        ROUND(COALESCE(SUM(oi.sales_amount), 0), 2) AS observed_sales_amount
    FROM public.order_item oi
    LEFT JOIN public.product p ON p.product_id = oi.product_id
    LEFT JOIN public.department d ON d.department_id = p.department_id
    GROUP BY COALESCE(NULLIF(BTRIM(d.department_name), ''), '[Missing department]')
)
SELECT
    department_name,
    order_item_count,
    total_units_ordered,
    observed_sales_amount,
    ROUND(
        100.0 * total_units_ordered
        / NULLIF(SUM(total_units_ordered) OVER (), 0),
        2
    ) AS percentage_of_observed_units
FROM department_demand
ORDER BY total_units_ordered DESC, department_name;

-- =========================================================
-- D. Monthly Demand Trends
-- =========================================================

-- D1. Overall monthly observed demand
-- Missing order dates are kept as a separate '[Missing order date]' bucket.
WITH monthly_demand AS (
    SELECT
        CASE
            WHEN o.order_date IS NULL THEN '[Missing order date]'
            ELSE TO_CHAR(DATE_TRUNC('month', o.order_date), 'YYYY-MM')
        END AS order_month,
        COUNT(oi.order_item_id) AS order_item_count,
        COALESCE(SUM(oi.quantity), 0) AS total_units_ordered,
        ROUND(COALESCE(SUM(oi.sales_amount), 0), 2) AS observed_sales_amount
    FROM public.order_item oi
    LEFT JOIN public.customer_order o ON o.order_id = oi.order_id
    GROUP BY
        CASE
            WHEN o.order_date IS NULL THEN '[Missing order date]'
            ELSE TO_CHAR(DATE_TRUNC('month', o.order_date), 'YYYY-MM')
        END
)
SELECT
    order_month,
    order_item_count,
    total_units_ordered,
    observed_sales_amount,
    ROUND(
        100.0 * total_units_ordered
        / NULLIF(SUM(total_units_ordered) OVER (), 0),
        2
    ) AS percentage_of_observed_units
FROM monthly_demand
ORDER BY
    CASE WHEN order_month = '[Missing order date]' THEN 1 ELSE 0 END,
    order_month;

-- D2. Category monthly demand change versus the previous observed month
-- Lag is calculated from category-month rows that exist in the data.
-- It does not interpolate missing category-month periods or prove seasonality.
WITH category_month AS (
    SELECT
        DATE_TRUNC('month', o.order_date) AS month_start,
        COALESCE(NULLIF(BTRIM(c.category_name), ''), '[Missing category]') AS category_name,
        COALESCE(SUM(oi.quantity), 0) AS total_units_ordered
    FROM public.order_item oi
    JOIN public.customer_order o ON o.order_id = oi.order_id
    LEFT JOIN public.product p ON p.product_id = oi.product_id
    LEFT JOIN public.category c ON c.category_id = p.category_id
    WHERE o.order_date IS NOT NULL
    GROUP BY
        DATE_TRUNC('month', o.order_date),
        COALESCE(NULLIF(BTRIM(c.category_name), ''), '[Missing category]')
),
category_trend AS (
    SELECT *,
        LAG(total_units_ordered) OVER (
            PARTITION BY category_name
            ORDER BY month_start
        ) AS prior_month_units
    FROM category_month
)
SELECT
    category_name,
    TO_CHAR(month_start, 'YYYY-MM') AS order_month,
    total_units_ordered,
    prior_month_units,
    CASE
        WHEN prior_month_units IS NULL THEN NULL
        ELSE total_units_ordered - prior_month_units
    END AS change_vs_previous_observed_month,
    CASE
        WHEN prior_month_units IS NULL THEN NULL
        ELSE ROUND(
            100.0 * (total_units_ordered - prior_month_units)
            / NULLIF(prior_month_units, 0),
            2
        )
    END AS percentage_change_vs_previous_observed_month
FROM category_trend
ORDER BY ABS(
        CASE
            WHEN prior_month_units IS NULL THEN NULL
            ELSE total_units_ordered - prior_month_units
        END
    ) DESC NULLS LAST,
         month_start DESC,
         category_name;

-- =========================================================
-- E. Product Demand Concentration (ABC / Pareto)
-- =========================================================
--
-- Demand-based prioritization proxy:
-- A = cumulative observed demand <= 80%
-- B = cumulative observed demand > 80% and <= 95%
-- C = cumulative observed demand > 95%
-- Products are deterministically ordered by units DESC, then product_id ASC.
-- This is not conventional inventory-value ABC and does not imply stock priority.

WITH product_demand AS (
    SELECT
        p.product_id,
        COALESCE(NULLIF(BTRIM(p.product_name), ''), '[Missing product name]') AS product_name,
        COUNT(oi.order_item_id) AS order_item_count,
        COALESCE(SUM(oi.quantity), 0) AS total_units_ordered
    FROM public.product p
    LEFT JOIN public.order_item oi ON oi.product_id = p.product_id
    GROUP BY p.product_id, p.product_name
),
ranked AS (
    SELECT *,
        SUM(total_units_ordered) OVER (
            ORDER BY total_units_ordered DESC, product_id ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_units
    FROM product_demand
),
classified AS (
    SELECT *,
        100.0 * cumulative_units
        / NULLIF(SUM(total_units_ordered) OVER (), 0) AS cumulative_percentage
    FROM ranked
)
SELECT
    product_id,
    product_name,
    order_item_count,
    total_units_ordered,
    cumulative_units,
    ROUND(cumulative_percentage, 4) AS cumulative_percentage,
    CASE
        WHEN cumulative_percentage <= 80 THEN 'A'
        WHEN cumulative_percentage <= 95 THEN 'B'
        ELSE 'C'
    END AS demand_abc_class
FROM classified
ORDER BY total_units_ordered DESC, product_id ASC;

-- =========================================================
-- Validation and reconciliation checks
-- =========================================================
-- V1. Underlying order-item population and total demand
SELECT
    COUNT(*) AS source_order_items,
    COUNT(*) FILTER (WHERE quantity IS NOT NULL) AS items_with_quantity,
    COUNT(*) FILTER (WHERE quantity IS NULL) AS items_missing_quantity,
    COALESCE(SUM(quantity), 0) AS overall_units,
    ROUND(COALESCE(SUM(sales_amount), 0), 2) AS overall_sales_amount
FROM public.order_item;

-- V2. Product aggregates reconcile to overall item totals
WITH item_totals AS (
    SELECT
        COALESCE(SUM(quantity), 0) AS overall_units,
        COUNT(*) AS overall_items
    FROM public.order_item
),
product_totals AS (
    SELECT
        COALESCE(SUM(oi.quantity), 0) AS product_units,
        COUNT(oi.order_item_id) AS product_items
    FROM public.product p
    LEFT JOIN public.order_item oi ON oi.product_id = p.product_id
)
SELECT
    item_totals.overall_items,
    product_totals.product_items,
    item_totals.overall_units,
    product_totals.product_units,
    (item_totals.overall_items = product_totals.product_items
     AND item_totals.overall_units = product_totals.product_units) AS reconciles
FROM item_totals CROSS JOIN product_totals;

-- V3. Category and department relationships reconcile to item totals
SELECT
    (SELECT COUNT(*) FROM public.order_item) AS all_items,
    COUNT(*) FILTER (WHERE p.product_id IS NULL) AS items_missing_product,
    COUNT(*) FILTER (WHERE p.category_id IS NULL) AS items_missing_category_relationship,
    COUNT(*) FILTER (WHERE p.department_id IS NULL) AS items_missing_department_relationship,
    COALESCE(SUM(oi.quantity), 0) AS all_units,
    COALESCE(SUM(oi.quantity) FILTER (WHERE p.category_id IS NOT NULL), 0) AS units_with_category,
    COALESCE(SUM(oi.quantity) FILTER (WHERE p.department_id IS NOT NULL), 0) AS units_with_department
FROM public.order_item oi
LEFT JOIN public.product p ON p.product_id = oi.product_id;

-- V4. Monthly aggregates reconcile to the overall, subject to date exclusions
WITH overall AS (
    SELECT
        COALESCE(SUM(quantity), 0) AS all_units,
        COUNT(*) AS all_items
    FROM public.order_item
),
monthly AS (
    SELECT
        COALESCE(SUM(oi.quantity) FILTER (WHERE o.order_date IS NOT NULL), 0) AS dated_units,
        COALESCE(SUM(oi.quantity) FILTER (WHERE o.order_date IS NULL), 0) AS missing_date_units,
        COUNT(*) FILTER (WHERE o.order_date IS NOT NULL) AS dated_items,
        COUNT(*) FILTER (WHERE o.order_date IS NULL) AS missing_date_items
    FROM public.order_item oi
    LEFT JOIN public.customer_order o ON o.order_id = oi.order_id
)
SELECT
    overall.all_units,
    monthly.dated_units,
    monthly.missing_date_units,
    (overall.all_units = monthly.dated_units + monthly.missing_date_units) AS units_reconcile,
    overall.all_items,
    monthly.dated_items,
    monthly.missing_date_items,
    (overall.all_items = monthly.dated_items + monthly.missing_date_items) AS items_reconcile
FROM overall CROSS JOIN monthly;

-- V5. ABC population and demand reconciliation
WITH product_demand AS (
    SELECT
        p.product_id,
        COALESCE(SUM(oi.quantity), 0) AS total_units_ordered
    FROM public.product p
    LEFT JOIN public.order_item oi ON oi.product_id = p.product_id
    GROUP BY p.product_id
),
ranked AS (
    SELECT *,
        SUM(total_units_ordered) OVER (
            ORDER BY total_units_ordered DESC, product_id ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_units
    FROM product_demand
),
classified AS (
    SELECT *,
        100.0 * cumulative_units
        / NULLIF(SUM(total_units_ordered) OVER (), 0) AS cumulative_percentage
    FROM ranked
)
SELECT
    (SELECT COUNT(*) FROM public.product) AS product_population,
    COUNT(*) AS classified_product_count,
    SUM(total_units_ordered) AS classified_units,
    (SELECT COALESCE(SUM(quantity), 0) FROM public.order_item) AS overall_units,
    MAX(cumulative_units) AS final_cumulative_units,
    (SUM(total_units_ordered)
     = (SELECT COALESCE(SUM(quantity), 0) FROM public.order_item)) AS units_reconcile,
    COUNT(*) FILTER (WHERE cumulative_percentage <= 80) AS abc_a_count,
    COUNT(*) FILTER (WHERE cumulative_percentage > 80 AND cumulative_percentage <= 95) AS abc_b_count,
    COUNT(*) FILTER (WHERE cumulative_percentage > 95) AS abc_c_count
FROM classified;
