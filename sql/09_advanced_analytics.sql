-- 09_advanced_analytics.sql
-- Advanced customer analytics
-- A. Customer Purchasing Profile
-- A1.
WITH customer_order_profile AS (
    SELECT co.customer_id, COUNT(DISTINCT co.order_id) AS distinct_order_count,
           MIN(co.order_date) AS first_order_date, MAX(co.order_date) AS most_recent_order_date
    FROM public.customer_order co
    WHERE co.customer_id IS NOT NULL
    GROUP BY co.customer_id
),
customer_item_profile AS (
    SELECT co.customer_id,
           COUNT(oi.order_item_id) AS order_item_count,
           COALESCE(SUM(oi.quantity), 0) AS total_units_purchased
    FROM public.customer_order co
    JOIN public.order_item oi ON oi.order_id = co.order_id
    WHERE co.customer_id IS NOT NULL
    GROUP BY co.customer_id
)
SELECT c.customer_id,
       COALESCE(op.distinct_order_count, 0) AS distinct_order_count,
       COALESCE(ip.order_item_count, 0) AS order_item_count,
       COALESCE(ip.total_units_purchased, 0) AS total_units_purchased,
       op.first_order_date,
       op.most_recent_order_date,
       ROUND(
           COALESCE(ip.total_units_purchased, 0)::numeric
           / NULLIF(COALESCE(op.distinct_order_count, 0), 0),
           2
       ) AS average_units_per_order
FROM public.customer c
LEFT JOIN customer_order_profile op ON op.customer_id = c.customer_id
LEFT JOIN customer_item_profile ip ON ip.customer_id = c.customer_id
ORDER BY total_units_purchased DESC, distinct_order_count DESC, c.customer_id;
-- B. Customer Recency and Frequency
-- B1. Recency and purchasing frequency
WITH reference_data AS (
    SELECT MAX(order_date)::date AS reference_date
    FROM public.customer_order
),
customer_profile AS (
    SELECT c.customer_id, COUNT(DISTINCT co.order_id) AS distinct_order_count,
           MAX(co.order_date)::date AS most_recent_order_date
    FROM public.customer c
    LEFT JOIN public.customer_order co ON co.customer_id = c.customer_id
    GROUP BY c.customer_id
)
SELECT cp.customer_id,
       cp.distinct_order_count,
       cp.most_recent_order_date,
       rd.reference_date,
       CASE WHEN cp.most_recent_order_date IS NULL THEN NULL
            ELSE rd.reference_date - cp.most_recent_order_date
       END AS days_since_most_recent_order,
       CASE WHEN cp.distinct_order_count = 0 THEN 'No recorded orders'
            WHEN cp.distinct_order_count >= 5 THEN 'Frequent observed purchasing'
            WHEN cp.distinct_order_count BETWEEN 2 AND 4 THEN 'Recurring observed purchasing'
            ELSE 'Low observed purchasing frequency'
       END AS purchasing_frequency_classification
FROM customer_profile cp
CROSS JOIN reference_data rd
ORDER BY days_since_most_recent_order ASC NULLS LAST,
         cp.distinct_order_count DESC, cp.customer_id;
-- C. Behaviour-Based Customer Segmentation
-- C1. Segment population and purchasing totals
-- NTILE(3) applies only to active customers in approximately equal relative
-- population segments. A customer_id tie-breaker may split equal counts; these
-- are not absolute behaviour categories, adjacent segments need not differ
-- meaningfully, and no-order customers are separate.
WITH customer_profile AS (
    SELECT c.customer_id, COUNT(DISTINCT co.order_id) AS distinct_order_count,
           COALESCE(SUM(oi.quantity), 0) AS total_units_purchased
    FROM public.customer c
    LEFT JOIN public.customer_order co ON co.customer_id = c.customer_id
    LEFT JOIN public.order_item oi ON oi.order_id = co.order_id
    GROUP BY c.customer_id
),
active_segmented AS (
    SELECT customer_id,
           NTILE(3) OVER (
               ORDER BY distinct_order_count DESC, customer_id ASC
           ) AS frequency_segment
    FROM customer_profile
    WHERE distinct_order_count > 0
),
segmented AS (
    SELECT cp.*,
           CASE WHEN cp.distinct_order_count = 0 THEN 0
                ELSE active_segmented.frequency_segment
           END AS frequency_segment
    FROM customer_profile cp
    LEFT JOIN active_segmented ON active_segmented.customer_id = cp.customer_id
)
SELECT CASE frequency_segment
            WHEN 0 THEN 'No recorded orders'
            WHEN 1 THEN 'NTILE segment 1'
            WHEN 2 THEN 'NTILE segment 2'
            ELSE 'NTILE segment 3'
       END AS purchasing_segment,
       COUNT(*) AS customer_count,
       ROUND(100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0), 2)
           AS percentage_of_customers,
       SUM(distinct_order_count) AS distinct_order_count,
       SUM(total_units_purchased) AS total_units_purchased
FROM segmented
GROUP BY frequency_segment
ORDER BY frequency_segment;
-- D. Customer Ranking
-- D1.
WITH customer_profile AS (
    SELECT c.customer_id, COUNT(DISTINCT co.order_id) AS distinct_order_count,
           COALESCE(SUM(oi.quantity), 0) AS total_units_purchased
    FROM public.customer c
    LEFT JOIN public.customer_order co ON co.customer_id = c.customer_id
    LEFT JOIN public.order_item oi ON oi.order_id = co.order_id
    GROUP BY c.customer_id
),
ranked AS (
    SELECT *,
           RANK() OVER (ORDER BY distinct_order_count DESC) AS order_count_rank,
           RANK() OVER (ORDER BY total_units_purchased DESC) AS units_purchased_rank,
           ROW_NUMBER() OVER (ORDER BY distinct_order_count DESC, customer_id ASC)
               AS order_display_number,
           ROW_NUMBER() OVER (ORDER BY total_units_purchased DESC, customer_id ASC)
               AS units_display_number
    FROM customer_profile
)
SELECT customer_id, distinct_order_count, order_count_rank,
       order_display_number, total_units_purchased,
       units_purchased_rank, units_display_number
FROM ranked
ORDER BY units_purchased_rank, units_display_number
LIMIT 25;
-- E. Repeat-Purchase Analysis
-- E1.
WITH customer_profile AS (
    SELECT c.customer_id, COUNT(DISTINCT co.order_id) AS distinct_order_count,
           COALESCE(SUM(oi.quantity), 0) AS total_units_purchased
    FROM public.customer c
    LEFT JOIN public.customer_order co ON co.customer_id = c.customer_id
    LEFT JOIN public.order_item oi ON oi.order_id = co.order_id
    GROUP BY c.customer_id
),
grouped AS (
    SELECT CASE WHEN distinct_order_count > 1 THEN 'Repeat-order customer'
                WHEN distinct_order_count = 1 THEN 'One-order customer'
                ELSE 'No recorded order'
           END AS purchase_group,
           customer_id, distinct_order_count, total_units_purchased
    FROM customer_profile
),
customer_totals AS (
    SELECT purchase_group,
           COUNT(*) AS customer_count,
           SUM(distinct_order_count) AS distinct_order_count,
           SUM(total_units_purchased) AS total_units_purchased
    FROM grouped
    GROUP BY purchase_group
)
SELECT purchase_group,
       customer_count,
       ROUND(100.0 * customer_count
             / NULLIF(SUM(customer_count) OVER (), 0), 2)
           AS percentage_of_customers,
       distinct_order_count,
       total_units_purchased,
       ROUND(total_units_purchased::numeric
             / NULLIF(customer_count, 0), 2)
           AS average_units_per_customer
FROM customer_totals
ORDER BY CASE purchase_group
             WHEN 'Repeat-order customer' THEN 1
             WHEN 'One-order customer' THEN 2
             ELSE 3
         END;
-- F. Customer Demand Concentration
-- F1.
WITH active_customers AS (
    SELECT c.customer_id, SUM(oi.quantity) AS total_units_purchased
    FROM public.customer c
    JOIN public.customer_order co ON co.customer_id = c.customer_id
    JOIN public.order_item oi ON oi.order_id = co.order_id
    WHERE oi.quantity IS NOT NULL
    GROUP BY c.customer_id
),
ranked AS (
    SELECT customer_id, total_units_purchased,
           SUM(total_units_purchased) OVER (
               ORDER BY total_units_purchased DESC, customer_id ASC
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
           ) AS cumulative_units,
           ROW_NUMBER() OVER (ORDER BY total_units_purchased DESC, customer_id ASC)
               AS customer_rank
    FROM active_customers
),
concentration AS (
    SELECT *, ROUND(
        100.0 * cumulative_units
        / NULLIF(SUM(total_units_purchased) OVER (), 0),
        4
    ) AS cumulative_percentage
    FROM ranked
)
SELECT customer_rank, customer_id, total_units_purchased,
       cumulative_units, cumulative_percentage
FROM concentration
ORDER BY customer_rank
LIMIT 25;
-- F2. Demand concentration summary
WITH active_customers AS (
    SELECT c.customer_id, SUM(oi.quantity) AS total_units_purchased
    FROM public.customer c
    JOIN public.customer_order co ON co.customer_id = c.customer_id
    JOIN public.order_item oi ON oi.order_id = co.order_id
    WHERE oi.quantity IS NOT NULL
    GROUP BY c.customer_id
),
ranked AS (
    SELECT *, ROW_NUMBER() OVER (
               ORDER BY total_units_purchased DESC, customer_id ASC
           ) AS customer_rank
    FROM active_customers
),
totals AS (
    SELECT COUNT(*) AS active_customer_count,
           SUM(total_units_purchased) AS total_units
    FROM ranked
)
SELECT active_customer_count, total_units,
       SUM(total_units_purchased) FILTER (WHERE customer_rank = 1)
           AS top_1_customer_units,
       ROUND(100.0 * SUM(total_units_purchased) FILTER (WHERE customer_rank <= 10)
             / NULLIF(MAX(total_units), 0), 2)
           AS top_10_customers_percentage,
       ROUND(100.0 * SUM(total_units_purchased) FILTER (
                 WHERE customer_rank <= CEIL(active_customer_count * 0.20)
             ) / NULLIF(MAX(total_units), 0), 2)
           AS top_20_percent_customers_percentage
FROM ranked
CROSS JOIN totals
GROUP BY active_customer_count, total_units;
-- Validation and reconciliation checks
-- V1.
WITH customer_profile AS (
    SELECT c.customer_id, COUNT(DISTINCT co.order_id) AS distinct_order_count,
           COALESCE(SUM(oi.quantity), 0) AS total_units_purchased
    FROM public.customer c
    LEFT JOIN public.customer_order co ON co.customer_id = c.customer_id
    LEFT JOIN public.order_item oi ON oi.order_id = co.order_id
    GROUP BY c.customer_id
)
SELECT (SELECT COUNT(*) FROM public.customer) AS customer_population,
       COUNT(*) AS profile_customer_count,
       COUNT(*) FILTER (WHERE total_units_purchased > 0) AS customers_with_units,
       COUNT(*) FILTER (WHERE distinct_order_count = 0) AS customers_without_orders,
       COUNT(*) = (SELECT COUNT(*) FROM public.customer)
           AS customer_population_reconciles
FROM customer_profile;
-- V2.
WITH customer_profile AS (
    SELECT c.customer_id, COUNT(DISTINCT co.order_id) AS distinct_order_count
    FROM public.customer c
    LEFT JOIN public.customer_order co ON co.customer_id = c.customer_id
    GROUP BY c.customer_id
)
SELECT (SELECT COUNT(DISTINCT order_id) FROM public.customer_order)
           AS distinct_order_population,
       SUM(distinct_order_count) AS customer_summed_distinct_orders,
       MAX(distinct_order_count) AS maximum_orders_for_one_customer,
       SUM(distinct_order_count)
           = (SELECT COUNT(DISTINCT order_id) FROM public.customer_order)
           AS order_counts_reconcile,
       MAX(distinct_order_count)
           <= (SELECT COUNT(DISTINCT order_id) FROM public.customer_order)
           AS maximum_count_is_valid
FROM customer_profile;
-- V3.
WITH customer_profile AS (
    SELECT c.customer_id, COALESCE(SUM(oi.quantity), 0) AS total_units_purchased
    FROM public.customer c
    LEFT JOIN public.customer_order co ON co.customer_id = c.customer_id
    LEFT JOIN public.order_item oi ON oi.order_id = co.order_id
    GROUP BY c.customer_id
),
item_population AS (
    SELECT COUNT(*) AS order_item_count,
           COALESCE(SUM(quantity), 0) AS item_population_units
    FROM public.order_item
)
SELECT ip.order_item_count, ip.item_population_units,
       SUM(cp.total_units_purchased) AS customer_profile_units,
       ip.item_population_units = SUM(cp.total_units_purchased)
           AS units_reconcile
FROM customer_profile cp
CROSS JOIN item_population ip
GROUP BY ip.order_item_count, ip.item_population_units;
-- V4.
-- NTILE(3) uses active customers only; the tie-breaker may split equal counts.
-- Segments are relative population groups, not absolute categories, and adjacent
-- segments need not differ meaningfully. No-order customers remain separate.
WITH customer_profile AS (
    SELECT c.customer_id, COUNT(DISTINCT co.order_id) AS distinct_order_count
    FROM public.customer c
    LEFT JOIN public.customer_order co ON co.customer_id = c.customer_id
    GROUP BY c.customer_id
),
active_segmented AS (
    SELECT customer_id,
           NTILE(3) OVER (
               ORDER BY distinct_order_count DESC, customer_id ASC
           ) AS frequency_segment
    FROM customer_profile
    WHERE distinct_order_count > 0
),
segmented AS (
    SELECT cp.customer_id,
           CASE WHEN cp.distinct_order_count = 0 THEN 0
                ELSE active_segmented.frequency_segment
           END AS frequency_segment
    FROM customer_profile cp
    LEFT JOIN active_segmented ON active_segmented.customer_id = cp.customer_id
)
SELECT COUNT(*) AS segmented_customer_count,
       (SELECT COUNT(*) FROM public.customer) AS customer_population,
       COUNT(*) FILTER (WHERE frequency_segment = 0) AS no_recorded_order_count,
       COUNT(*) FILTER (WHERE frequency_segment = 1) AS ntile_segment_1_count,
       COUNT(*) FILTER (WHERE frequency_segment = 2) AS ntile_segment_2_count,
       COUNT(*) FILTER (WHERE frequency_segment = 3) AS ntile_segment_3_count,
       COUNT(*) FILTER (WHERE frequency_segment IN (0,1,2,3))
           = (SELECT COUNT(*) FROM public.customer)
           AS segments_account_for_population
FROM segmented;
-- V5.
WITH customer_profile AS (
    SELECT c.customer_id, COUNT(DISTINCT co.order_id) AS distinct_order_count
    FROM public.customer c
    LEFT JOIN public.customer_order co ON co.customer_id = c.customer_id
    GROUP BY c.customer_id
),
grouped AS (
    SELECT CASE WHEN distinct_order_count > 1 THEN 'Repeat'
                WHEN distinct_order_count = 1 THEN 'Single'
                ELSE 'No recorded order'
           END AS purchase_group
    FROM customer_profile
)
SELECT COUNT(*) AS customer_profile_count,
       (SELECT COUNT(*) FROM public.customer) AS customer_population,
       COUNT(*) FILTER (WHERE purchase_group = 'Repeat') AS repeat_customer_count,
       COUNT(*) FILTER (WHERE purchase_group = 'Single') AS single_customer_count,
       COUNT(*) FILTER (WHERE purchase_group = 'No recorded order')
           AS no_order_customer_count,
       COUNT(*) FILTER (WHERE purchase_group = 'Repeat')
           + COUNT(*) FILTER (WHERE purchase_group = 'Single')
           + COUNT(*) FILTER (WHERE purchase_group = 'No recorded order')
           = (SELECT COUNT(*) FROM public.customer)
           AS repeat_groups_reconcile
FROM grouped;
-- V6.
WITH active_customers AS (
    SELECT c.customer_id, SUM(oi.quantity) AS total_units_purchased
    FROM public.customer c
    JOIN public.customer_order co ON co.customer_id = c.customer_id
    JOIN public.order_item oi ON oi.order_id = co.order_id
    WHERE oi.quantity IS NOT NULL
    GROUP BY c.customer_id
),
ranked AS (
    SELECT customer_id, total_units_purchased,
           SUM(total_units_purchased) OVER (
               ORDER BY total_units_purchased DESC, customer_id ASC
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
           ) AS cumulative_units
    FROM active_customers
)
SELECT COUNT(*) AS active_customer_count,
       SUM(total_units_purchased) AS active_customer_units,
       (SELECT COALESCE(SUM(quantity), 0) FROM public.order_item)
           AS overall_order_item_units,
       MAX(cumulative_units) AS final_cumulative_units,
       SUM(total_units_purchased)
           = (SELECT COALESCE(SUM(quantity), 0) FROM public.order_item)
           AS demand_reconciles
FROM ranked;
