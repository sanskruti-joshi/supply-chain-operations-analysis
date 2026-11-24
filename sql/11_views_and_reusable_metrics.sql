-- =========================================================
-- 11_views_and_reusable_metrics.sql
-- Reusable delivery, product-demand, and customer-activity views.
-- Preserve the grains and definitions established in Stages 07-09.
-- =========================================================

-- =========================================================
-- View 1: Delivery performance by shipping mode
-- Grain: one row per normalized shipping-mode value.
-- Missing and canceled statuses remain separate; late rates exclude missing
-- statuses from the denominator, while canceled orders remain in total orders.
-- =========================================================
CREATE OR REPLACE VIEW public.vw_delivery_performance_by_mode AS
WITH shipping_stats AS (
    SELECT
        COALESCE(NULLIF(BTRIM(shipping_mode), ''), '[Missing or blank]') AS shipping_mode,
        COUNT(*) AS total_orders,
        COUNT(*) FILTER (WHERE BTRIM(delivery_status) ILIKE 'Late delivery') AS late_delivery_count,
        COUNT(*) FILTER (WHERE BTRIM(delivery_status) ILIKE 'Advance shipping') AS advance_shipping_count,
        COUNT(*) FILTER (WHERE BTRIM(delivery_status) ILIKE 'Shipping on time') AS on_time_delivery_count,
        COUNT(*) FILTER (WHERE BTRIM(delivery_status) ILIKE 'Shipping canceled') AS cancelled_delivery_count,
        COUNT(*) FILTER (
            WHERE delivery_status IS NULL OR BTRIM(delivery_status) = ''
        ) AS missing_status_count
    FROM public.customer_order
    GROUP BY COALESCE(NULLIF(BTRIM(shipping_mode), ''), '[Missing or blank]')
)
SELECT
    shipping_mode,
    total_orders,
    late_delivery_count,
    advance_shipping_count,
    on_time_delivery_count,
    cancelled_delivery_count,
    missing_status_count,
    ROUND(100.0 * late_delivery_count
        / NULLIF(total_orders - missing_status_count, 0), 2)
        AS late_delivery_pct_excluding_missing_status,
    ROUND(100.0 * late_delivery_count / NULLIF(total_orders, 0), 2)
        AS late_delivery_pct_of_all_orders,
    ROUND(100.0 * advance_shipping_count / NULLIF(total_orders, 0), 2)
        AS advance_shipping_pct,
    ROUND(100.0 * on_time_delivery_count / NULLIF(total_orders, 0), 2)
        AS on_time_delivery_pct,
    ROUND(100.0 * cancelled_delivery_count / NULLIF(total_orders, 0), 2)
        AS cancelled_delivery_pct,
    ROUND(100.0 * missing_status_count / NULLIF(total_orders, 0), 2)
        AS missing_status_pct
FROM shipping_stats;

-- =========================================================
-- View 2: Product demand ABC classification
-- A <= 80%, B > 80% and <= 95%, C > 95% of cumulative observed units.
-- Order products by units descending, then product_id ascending.
-- =========================================================
CREATE OR REPLACE VIEW public.vw_product_demand_abc AS
WITH product_demand AS (
    SELECT
        p.product_id,
        COALESCE(NULLIF(BTRIM(p.product_name), ''), '[Missing product name]') AS product_name,
        COUNT(oi.order_item_id) AS order_item_count,
        COALESCE(SUM(oi.quantity), 0) AS total_units_demanded
    FROM public.product p
    LEFT JOIN public.order_item oi ON oi.product_id = p.product_id
    GROUP BY p.product_id, p.product_name
),
ranked AS (
    SELECT *,
        SUM(total_units_demanded) OVER (
            ORDER BY total_units_demanded DESC, product_id ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_units
    FROM product_demand
),
classified AS (
    SELECT *,
        ROUND(
            100.0 * total_units_demanded
            / NULLIF(SUM(total_units_demanded) OVER (), 0),
            4
        ) AS demand_contribution_pct,
        100.0 * cumulative_units
            / NULLIF(SUM(total_units_demanded) OVER (), 0)
            AS cumulative_demand_pct
    FROM ranked
)
SELECT
    product_id,
    product_name,
    order_item_count,
    total_units_demanded,
    demand_contribution_pct,
    ROUND(cumulative_demand_pct, 4) AS cumulative_demand_pct,
    cumulative_units,
    CASE
        WHEN cumulative_demand_pct <= 80 THEN 'A'
        WHEN cumulative_demand_pct <= 95 THEN 'B'
        ELSE 'C'
    END AS abc_class
FROM classified;

-- =========================================================
-- View 3: Customer purchasing profile
-- Recency uses the fixed Stage 09 reference date 2018-01-31.
-- =========================================================
CREATE OR REPLACE VIEW public.vw_customer_purchasing_profile AS
WITH customer_profile AS (
    SELECT
        c.customer_id,
        COUNT(DISTINCT co.order_id) AS distinct_order_count,
        COALESCE(SUM(oi.quantity), 0) AS total_units_purchased,
        MAX(co.order_date)::date AS most_recent_order_date
    FROM public.customer c
    LEFT JOIN public.customer_order co ON co.customer_id = c.customer_id
    LEFT JOIN public.order_item oi ON oi.order_id = co.order_id
    GROUP BY c.customer_id
)
SELECT
    customer_id,
    distinct_order_count,
    total_units_purchased,
    ROUND(
        total_units_purchased::numeric / NULLIF(distinct_order_count, 0),
        2
    ) AS average_units_per_order,
    most_recent_order_date,
    CASE
        WHEN most_recent_order_date IS NULL THEN NULL
        ELSE DATE '2018-01-31' - most_recent_order_date
    END AS days_since_last_recorded_order
FROM customer_profile;

-- =========================================================
-- View 4: Customer repeat-purchase classification
-- =========================================================
CREATE OR REPLACE VIEW public.vw_customer_repeat_purchase AS
WITH customer_profile AS (
    SELECT
        c.customer_id,
        COUNT(DISTINCT co.order_id) AS distinct_order_count,
        COALESCE(SUM(oi.quantity), 0) AS total_units_purchased
    FROM public.customer c
    LEFT JOIN public.customer_order co ON co.customer_id = c.customer_id
    LEFT JOIN public.order_item oi ON oi.order_id = co.order_id
    GROUP BY c.customer_id
)
SELECT
    customer_id,
    distinct_order_count,
    total_units_purchased,
    CASE
        WHEN distinct_order_count > 1 THEN 'Repeat-order customer'
        WHEN distinct_order_count = 1 THEN 'One-order customer'
        ELSE 'No recorded order'
    END AS purchase_group
FROM customer_profile;

-- =========================================================
-- View 5: Customer demand concentration
-- Rank by units descending, then customer_id ascending.
-- =========================================================
CREATE OR REPLACE VIEW public.vw_customer_demand_concentration AS
WITH active_customers AS (
    SELECT
        c.customer_id,
        SUM(oi.quantity) AS total_units_purchased
    FROM public.customer c
    JOIN public.customer_order co ON co.customer_id = c.customer_id
    JOIN public.order_item oi ON oi.order_id = co.order_id
    WHERE oi.quantity IS NOT NULL
    GROUP BY c.customer_id
),
ranked AS (
    SELECT
        customer_id,
        total_units_purchased,
        SUM(total_units_purchased) OVER (
            ORDER BY total_units_purchased DESC, customer_id ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_units,
        ROW_NUMBER() OVER (
            ORDER BY total_units_purchased DESC, customer_id ASC
        ) AS customer_rank
    FROM active_customers
)
SELECT
    customer_id,
    total_units_purchased,
    customer_rank,
    cumulative_units,
    ROUND(
        100.0 * cumulative_units
            / NULLIF(SUM(total_units_purchased) OVER (), 0),
        4
    ) AS cumulative_demand_pct
FROM ranked;

-- =========================================================
-- Validation and reconciliation checks
-- =========================================================

-- V1. View grain counts and concentration ranking.
SELECT
    (SELECT COUNT(*) FROM public.vw_delivery_performance_by_mode) AS delivery_mode_row_count,
    (SELECT COUNT(*) FROM public.vw_product_demand_abc) AS product_view_row_count,
    (SELECT COUNT(*) FROM public.vw_customer_purchasing_profile) AS customer_profile_row_count,
    (SELECT COUNT(*) FROM public.vw_customer_repeat_purchase) AS repeat_profile_row_count,
    COUNT(*) AS active_customer_count,
    COUNT(DISTINCT customer_rank) AS distinct_customer_rank_count,
    MIN(customer_rank) AS minimum_rank,
    MAX(customer_rank) AS maximum_rank,
    COUNT(*) = COUNT(DISTINCT customer_rank) AS ranks_reconcile_with_customers,
    MIN(customer_rank) = 1 AS minimum_rank_is_one,
    MAX(customer_rank) = COUNT(*) AS maximum_rank_is_active_customer_count
FROM public.vw_customer_demand_concentration;

-- V2. Product population, ABC regression, and demand reconciliation.
SELECT
    (SELECT COUNT(*) FROM public.product) AS source_product_count,
    COUNT(*) AS abc_product_count,
    COUNT(*) = (SELECT COUNT(*) FROM public.product) AS abc_population_reconciles,
    SUM(total_units_demanded) AS abc_units,
    (SELECT COALESCE(SUM(quantity), 0) FROM public.order_item) AS overall_units,
    SUM(total_units_demanded)
        = (SELECT COALESCE(SUM(quantity), 0) FROM public.order_item) AS units_reconcile,
    COUNT(*) FILTER (WHERE abc_class = 'A') AS abc_a_count,
    COUNT(*) FILTER (WHERE abc_class = 'B') AS abc_b_count,
    COUNT(*) FILTER (WHERE abc_class = 'C') AS abc_c_count,
    COUNT(*) FILTER (WHERE abc_class = 'A') = 7 AS abc_a_count_matches_stage08,
    COUNT(*) FILTER (WHERE abc_class = 'B') = 38 AS abc_b_count_matches_stage08,
    COUNT(*) FILTER (WHERE abc_class = 'C') = 73 AS abc_c_count_matches_stage08,
    MAX(cumulative_units) AS final_cumulative_units
FROM public.vw_product_demand_abc;

-- V3. Independent customer purchasing-profile reconciliation.
SELECT
    (SELECT COUNT(*) FROM public.customer) AS customer_population,
    COUNT(*) AS purchasing_profile_count,
    COUNT(*) = (SELECT COUNT(*) FROM public.customer) AS population_reconciles,
    (SELECT COUNT(DISTINCT order_id) FROM public.customer_order) AS source_distinct_orders,
    SUM(distinct_order_count) AS profile_distinct_order_total,
    (SELECT COUNT(DISTINCT order_id) FROM public.customer_order)
        = SUM(distinct_order_count) AS order_counts_reconcile,
    (SELECT COALESCE(SUM(quantity), 0) FROM public.order_item) AS source_units,
    SUM(total_units_purchased) AS profile_purchase_units,
    (SELECT COALESCE(SUM(quantity), 0) FROM public.order_item)
        = SUM(total_units_purchased) AS units_reconcile
FROM public.vw_customer_purchasing_profile;

-- V4. Repeat-purchase groups reconcile to the customer population.
SELECT
    COUNT(*) AS customer_profile_count,
    COUNT(*) FILTER (WHERE purchase_group = 'Repeat-order customer') AS repeat_customer_count,
    COUNT(*) FILTER (WHERE purchase_group = 'One-order customer') AS one_order_customer_count,
    COUNT(*) FILTER (WHERE purchase_group = 'No recorded order') AS no_order_customer_count,
    COUNT(*) FILTER (
        WHERE purchase_group IN (
            'Repeat-order customer',
            'One-order customer',
            'No recorded order'
        )
    ) = (SELECT COUNT(*) FROM public.customer) AS groups_reconcile
FROM public.vw_customer_repeat_purchase;

-- V5. Concentration totals reconcile to overall demand.
WITH concentration_totals AS (
    SELECT
        COUNT(*) AS active_customer_count,
        SUM(total_units_purchased) AS active_customer_units,
        MAX(cumulative_units) AS final_cumulative_units,
        MAX(cumulative_demand_pct) AS final_cumulative_pct
    FROM public.vw_customer_demand_concentration
)
SELECT
    active_customer_count,
    active_customer_units,
    (SELECT COALESCE(SUM(quantity), 0) FROM public.order_item) AS overall_units,
    final_cumulative_units,
    final_cumulative_pct,
    active_customer_units
        = (SELECT COALESCE(SUM(quantity), 0) FROM public.order_item) AS units_reconcile,
    final_cumulative_units
        = (SELECT COALESCE(SUM(quantity), 0) FROM public.order_item)
        AS cumulative_units_reconcile,
    final_cumulative_pct = 100.0000 AS reaches_100_percent
FROM concentration_totals;

-- V6. Delivery totals and statuses reconcile with Stage 07.
WITH mode_totals AS (
    SELECT
        SUM(total_orders) AS mode_order_total,
        SUM(late_delivery_count) AS mode_late_count,
        SUM(cancelled_delivery_count) AS mode_cancelled_count,
        SUM(missing_status_count) AS mode_missing_status_count
    FROM public.vw_delivery_performance_by_mode
)
SELECT
    mode_order_total,
    (SELECT COUNT(*) FROM public.customer_order) AS source_order_count,
    mode_order_total = (SELECT COUNT(*) FROM public.customer_order) AS order_counts_reconcile,
    mode_late_count,
    (SELECT COUNT(*) FROM public.customer_order
     WHERE BTRIM(delivery_status) ILIKE 'Late delivery') AS source_late_count,
    mode_late_count
        = (SELECT COUNT(*) FROM public.customer_order
           WHERE BTRIM(delivery_status) ILIKE 'Late delivery') AS late_counts_reconcile,
    mode_cancelled_count,
    (SELECT COUNT(*) FROM public.customer_order
     WHERE BTRIM(delivery_status) ILIKE 'Shipping canceled') AS source_cancelled_count,
    mode_cancelled_count
        = (SELECT COUNT(*) FROM public.customer_order
           WHERE BTRIM(delivery_status) ILIKE 'Shipping canceled') AS cancelled_counts_reconcile,
    mode_missing_status_count,
    (SELECT COUNT(*) FROM public.customer_order
     WHERE delivery_status IS NULL OR BTRIM(delivery_status) = '') AS source_missing_status_count,
    mode_missing_status_count
        = (SELECT COUNT(*) FROM public.customer_order
           WHERE delivery_status IS NULL OR BTRIM(delivery_status) = '')
        AS missing_status_counts_reconcile
FROM mode_totals;
