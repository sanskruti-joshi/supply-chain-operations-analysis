-- =========================================================
-- 07_delivery_performance.sql
-- Purpose: Answer order-level, shipping, geography, timing, and risk questions.
-- Classification used throughout:
-- Late delivery is identified case-insensitively.
-- Cancelled and missing statuses are handled separately where relevant.
-- Customer_order is the order grain; order_item is not joined, preventing
-- duplicated order counts.
-- =========================================================

-- =========================================================
-- A1. Overall delivery-status count
-- =========================================================
SELECT
    COALESCE(NULLIF(BTRIM(delivery_status), ''), '[Missing or blank]') AS delivery_status,
    COUNT(*) AS order_count
FROM public.customer_order
GROUP BY COALESCE(NULLIF(BTRIM(delivery_status), ''), '[Missing or blank]')
ORDER BY order_count DESC, delivery_status;

-- =========================================================
-- A2. Percentage distribution of delivery statuses
-- =========================================================
WITH status_counts AS (
    SELECT
        COALESCE(NULLIF(BTRIM(delivery_status), ''), '[Missing or blank]') AS delivery_status,
        COUNT(*) AS order_count
    FROM public.customer_order
    GROUP BY COALESCE(NULLIF(BTRIM(delivery_status), ''), '[Missing or blank]')
)
SELECT
    delivery_status,
    order_count,
    ROUND(
        100.0 * order_count
        / NULLIF(SUM(order_count) OVER (), 0),
        2
    ) AS percentage_of_orders
FROM status_counts
ORDER BY order_count DESC, delivery_status;

-- =========================================================
-- B1. Order count by shipping mode
-- =========================================================
SELECT
    COALESCE(NULLIF(BTRIM(shipping_mode), ''), '[Missing or blank]') AS shipping_mode,
    COUNT(*) AS order_count
FROM public.customer_order
GROUP BY COALESCE(NULLIF(BTRIM(shipping_mode), ''), '[Missing or blank]')
ORDER BY order_count DESC, shipping_mode;

-- =========================================================
-- B2. Delivery-status distribution within each shipping mode
-- =========================================================
WITH shipping_status_counts AS (
    SELECT
        COALESCE(NULLIF(BTRIM(shipping_mode), ''), '[Missing or blank]') AS shipping_mode,
        COALESCE(NULLIF(BTRIM(delivery_status), ''), '[Missing or blank]') AS delivery_status,
        COUNT(*) AS order_count
    FROM public.customer_order
    GROUP BY
        COALESCE(NULLIF(BTRIM(shipping_mode), ''), '[Missing or blank]'),
        COALESCE(NULLIF(BTRIM(delivery_status), ''), '[Missing or blank]')
)
SELECT
    shipping_mode,
    delivery_status,
    order_count,
    ROUND(
        100.0 * order_count
        / NULLIF(SUM(order_count) OVER (PARTITION BY shipping_mode), 0),
        2
    ) AS percentage_within_shipping_mode
FROM shipping_status_counts
ORDER BY shipping_mode, order_count DESC, delivery_status;

-- =========================================================
-- B3. Late-delivery percentage by shipping mode
-- =========================================================
WITH shipping_stats AS (
    SELECT
        COALESCE(NULLIF(BTRIM(shipping_mode), ''), '[Missing or blank]') AS shipping_mode,
        COUNT(*) AS order_count,
        COUNT(*) FILTER (
            WHERE BTRIM(delivery_status) ILIKE 'Late delivery'
        ) AS late_order_count,
        COUNT(*) FILTER (
            WHERE delivery_status IS NULL OR BTRIM(delivery_status) = ''
        ) AS missing_status_count
    FROM public.customer_order
    GROUP BY COALESCE(NULLIF(BTRIM(shipping_mode), ''), '[Missing or blank]')
)
SELECT
    shipping_mode,
    order_count,
    late_order_count,
    missing_status_count,
    ROUND(
        100.0 * late_order_count / NULLIF(order_count - missing_status_count, 0),
        2
    ) AS late_delivery_pct_excluding_missing_status
FROM shipping_stats
ORDER BY late_delivery_pct_excluding_missing_status DESC NULLS LAST,
         shipping_mode;

-- =========================================================
-- C1. Delivery-status distribution by market
-- =========================================================
WITH market_status_counts AS (
    SELECT
        COALESCE(NULLIF(BTRIM(market), ''), '[Missing or blank]') AS market,
        COALESCE(NULLIF(BTRIM(delivery_status), ''), '[Missing or blank]') AS delivery_status,
        COUNT(*) AS order_count
    FROM public.customer_order
    GROUP BY
        COALESCE(NULLIF(BTRIM(market), ''), '[Missing or blank]'),
        COALESCE(NULLIF(BTRIM(delivery_status), ''), '[Missing or blank]')
)
SELECT
    market,
    delivery_status,
    order_count,
    ROUND(
        100.0 * order_count
        / NULLIF(SUM(order_count) OVER (PARTITION BY market), 0),
        2
    ) AS percentage_within_market
FROM market_status_counts
ORDER BY market, order_count DESC, delivery_status;

-- =========================================================
-- C2. Market late-delivery rates and relative-risk ranking
-- =========================================================
WITH market_stats AS (
    SELECT
        COALESCE(NULLIF(BTRIM(market), ''), '[Missing or blank]') AS market,
        COUNT(*) AS order_count,
        COUNT(*) FILTER (
            WHERE BTRIM(delivery_status) ILIKE 'Late delivery'
        ) AS late_order_count,
        COUNT(*) FILTER (
            WHERE delivery_status IS NULL OR BTRIM(delivery_status) = ''
        ) AS missing_status_count
    FROM public.customer_order
    GROUP BY COALESCE(NULLIF(BTRIM(market), ''), '[Missing or blank]')
),
rates AS (
    SELECT
        market,
        order_count,
        late_order_count,
        missing_status_count,
        ROUND(
            100.0 * late_order_count
            / NULLIF(order_count - missing_status_count, 0),
            2
        ) AS late_delivery_pct,
        market = '[Missing or blank]' AS has_missing_market
    FROM market_stats
),
overall AS (
    SELECT
        ROUND(
            100.0 * COUNT(*) FILTER (
                WHERE BTRIM(delivery_status) ILIKE 'Late delivery'
            )
            / NULLIF(
                COUNT(*) FILTER (
                    WHERE delivery_status IS NOT NULL
                      AND BTRIM(delivery_status) <> ''
                ),
                0
            ),
            2
        ) AS overall_late_pct
    FROM public.customer_order
)
SELECT
    rates.market,
    rates.order_count,
    rates.late_order_count,
    rates.missing_status_count,
    rates.late_delivery_pct,
    overall.overall_late_pct,
    (rates.late_delivery_pct > overall.overall_late_pct) AS above_overall_late_rate,
    CASE
        WHEN rates.has_missing_market THEN NULL
        ELSE RANK() OVER (
            ORDER BY
                CASE WHEN rates.has_missing_market THEN NULL ELSE rates.late_delivery_pct END
                DESC NULLS LAST
        )
    END AS late_rate_rank,
    rates.has_missing_market
FROM rates
CROSS JOIN overall
ORDER BY rates.late_delivery_pct DESC NULLS LAST, rates.market;

-- =========================================================
-- C3. Delivery-status distribution by region
-- =========================================================
WITH region_status_counts AS (
    SELECT
        COALESCE(NULLIF(BTRIM(destination_region), ''), '[Missing or blank]') AS region,
        COALESCE(NULLIF(BTRIM(delivery_status), ''), '[Missing or blank]') AS delivery_status,
        COUNT(*) AS order_count
    FROM public.customer_order
    GROUP BY
        COALESCE(NULLIF(BTRIM(destination_region), ''), '[Missing or blank]'),
        COALESCE(NULLIF(BTRIM(delivery_status), ''), '[Missing or blank]')
)
SELECT
    region,
    delivery_status,
    order_count,
    ROUND(
        100.0 * order_count
        / NULLIF(SUM(order_count) OVER (PARTITION BY region), 0),
        2
    ) AS percentage_within_region
FROM region_status_counts
ORDER BY region, order_count DESC, delivery_status;

-- =========================================================
-- C4. Region late-delivery rates and relative-risk ranking
-- =========================================================
WITH region_stats AS (
    SELECT
        COALESCE(NULLIF(BTRIM(destination_region), ''), '[Missing or blank]') AS region,
        COUNT(*) AS order_count,
        COUNT(*) FILTER (
            WHERE BTRIM(delivery_status) ILIKE 'Late delivery'
        ) AS late_order_count,
        COUNT(*) FILTER (
            WHERE delivery_status IS NULL OR BTRIM(delivery_status) = ''
        ) AS missing_status_count
    FROM public.customer_order
    GROUP BY COALESCE(NULLIF(BTRIM(destination_region), ''), '[Missing or blank]')
),
rates AS (
    SELECT
        region,
        order_count,
        late_order_count,
        missing_status_count,
        ROUND(
            100.0 * late_order_count
            / NULLIF(order_count - missing_status_count, 0),
            2
        ) AS late_delivery_pct,
        region = '[Missing or blank]' AS has_missing_region
    FROM region_stats
),
overall AS (
    SELECT
        ROUND(
            100.0 * COUNT(*) FILTER (
                WHERE BTRIM(delivery_status) ILIKE 'Late delivery'
            )
            / NULLIF(
                COUNT(*) FILTER (
                    WHERE delivery_status IS NOT NULL
                      AND BTRIM(delivery_status) <> ''
                ),
                0
            ),
            2
        ) AS overall_late_pct
    FROM public.customer_order
)
SELECT
    rates.region,
    rates.order_count,
    rates.late_order_count,
    rates.missing_status_count,
    rates.late_delivery_pct,
    overall.overall_late_pct,
    (rates.late_delivery_pct > overall.overall_late_pct) AS above_overall_late_rate,
    CASE
        WHEN rates.has_missing_region THEN NULL
        ELSE RANK() OVER (
            ORDER BY
                CASE WHEN rates.has_missing_region THEN NULL ELSE rates.late_delivery_pct END
                DESC NULLS LAST
        )
    END AS late_rate_rank,
    rates.has_missing_region
FROM rates
CROSS JOIN overall
ORDER BY rates.late_delivery_pct DESC NULLS LAST, rates.region;

-- =========================================================
-- D1. Actual versus scheduled shipping-time averages
-- Positive difference = actual slower than scheduled.
-- =========================================================
WITH timing AS (
    SELECT
        actual_shipping_days,
        scheduled_shipping_days,
        CASE
            WHEN actual_shipping_days IS NULL
              OR scheduled_shipping_days IS NULL THEN NULL
            ELSE actual_shipping_days - scheduled_shipping_days
        END AS shipping_day_difference
    FROM public.customer_order
)
SELECT
    COUNT(actual_shipping_days) AS orders_with_actual_days,
    COUNT(scheduled_shipping_days) AS orders_with_scheduled_days,
    COUNT(shipping_day_difference) AS orders_with_both_values,
    COUNT(*) FILTER (
        WHERE actual_shipping_days IS NULL OR scheduled_shipping_days IS NULL
    ) AS orders_missing_timing_value,
    ROUND(AVG(actual_shipping_days), 2) AS average_actual_shipping_days,
    ROUND(AVG(scheduled_shipping_days), 2) AS average_scheduled_shipping_days,
    ROUND(AVG(shipping_day_difference), 2) AS average_actual_minus_scheduled,
    ROUND(
        AVG(shipping_day_difference) FILTER (WHERE shipping_day_difference > 0),
        2
    ) AS average_delay_when_late,
    ROUND(
        AVG(-shipping_day_difference) FILTER (WHERE shipping_day_difference < 0),
        2
    ) AS average_time_saved
FROM timing;

-- =========================================================
-- D2. Comparison outcome: exceeded, matched, or below schedule
-- =========================================================
WITH timing AS (
    SELECT
        CASE
            WHEN actual_shipping_days IS NULL
              OR scheduled_shipping_days IS NULL THEN '[Missing timing value]'
            WHEN actual_shipping_days > scheduled_shipping_days THEN 'Actual exceeded schedule'
            WHEN actual_shipping_days = scheduled_shipping_days THEN 'Actual matched schedule'
            ELSE 'Actual below schedule'
        END AS comparison_result
    FROM public.customer_order
),
counts AS (
    SELECT comparison_result, COUNT(*) AS order_count
    FROM timing
    GROUP BY comparison_result
)
SELECT
    comparison_result,
    order_count,
    ROUND(
        100.0 * order_count
        / NULLIF(SUM(order_count) OVER (), 0),
        2
    ) AS percentage_of_orders
FROM counts
ORDER BY
    CASE comparison_result
        WHEN 'Actual exceeded schedule' THEN 1
        WHEN 'Actual matched schedule' THEN 2
        WHEN 'Actual below schedule' THEN 3
        ELSE 4
    END;

-- =========================================================
-- E1. late_delivery_risk compared with observed delivery status
-- Risk 1 means the indicator is flagged; 0 means not flagged.
-- The cross-tab does not treat the indicator as proof of the outcome.
-- =========================================================
WITH risk_status AS (
    SELECT
        CASE
            WHEN late_delivery_risk = 1 THEN '1 - Risk flagged'
            WHEN late_delivery_risk = 0 THEN '0 - Risk not flagged'
            ELSE '[Missing or other]'
        END AS risk_indicator,
        CASE
            WHEN delivery_status IS NULL OR BTRIM(delivery_status) = '' THEN '[Missing or blank]'
            WHEN BTRIM(delivery_status) ILIKE 'Shipping canceled' THEN 'Shipping canceled'
            WHEN BTRIM(delivery_status) ILIKE 'Late delivery' THEN 'Late delivery'
            ELSE 'Not late delivery'
        END AS observed_status
    FROM public.customer_order
),
combination_counts AS (
    SELECT
        risk_indicator,
        observed_status,
        COUNT(*) AS order_count
    FROM risk_status
    GROUP BY risk_indicator, observed_status
)
SELECT
    risk_indicator,
    observed_status,
    order_count,
    ROUND(
        100.0 * order_count
        / NULLIF(SUM(order_count) OVER (), 0),
        2
    ) AS percentage_of_orders
FROM combination_counts
ORDER BY
    CASE risk_indicator
        WHEN '1 - Risk flagged' THEN 1
        WHEN '0 - Risk not flagged' THEN 2
        ELSE 3
    END,
    observed_status;

-- =========================================================
-- E2. Cases where risk indicator and observed status disagree
-- =========================================================
WITH assessed AS (
    SELECT
        CASE
            WHEN late_delivery_risk = 1
             AND delivery_status IS NOT NULL
             AND BTRIM(delivery_status) <> ''
             AND NOT (BTRIM(delivery_status) ILIKE 'Late delivery')
             AND NOT (BTRIM(delivery_status) ILIKE 'Shipping canceled')
            THEN 'Risk=1, observed=not late'
            WHEN late_delivery_risk = 0
             AND BTRIM(delivery_status) ILIKE 'Late delivery'
            THEN 'Risk=0, observed=late'
            ELSE NULL
        END AS disagreement_type
    FROM public.customer_order
)
SELECT
    disagreement_type,
    COUNT(*) AS disagreement_count,
    ROUND(
        100.0 * COUNT(*)
        / NULLIF(
            (SELECT COUNT(*) FROM assessed WHERE disagreement_type IS NOT NULL),
            0
        ),
        2
    ) AS percentage_of_disagreement_cases
FROM assessed
WHERE disagreement_type IS NOT NULL
GROUP BY disagreement_type
ORDER BY disagreement_count DESC, disagreement_type;

-- =========================================================
-- F1. Monthly late-delivery trend
-- Orders are grouped by order month; missing dates and delivery statuses
-- are reported rather than hidden.
-- =========================================================
WITH monthly_stats AS (
    SELECT
        COALESCE(
            TO_CHAR(order_date, 'YYYY-MM'),
            '[Missing or blank]'
        ) AS order_month,
        COUNT(*) AS order_count,
        COUNT(*) FILTER (
            WHERE BTRIM(delivery_status) ILIKE 'Late delivery'
        ) AS late_order_count,
        COUNT(*) FILTER (
            WHERE delivery_status IS NULL OR BTRIM(delivery_status) = ''
        ) AS missing_status_count
    FROM public.customer_order
    GROUP BY COALESCE(TO_CHAR(order_date, 'YYYY-MM'), '[Missing or blank]')
)
SELECT
    order_month,
    order_count,
    late_order_count,
    missing_status_count,
    ROUND(
        100.0 * late_order_count
        / NULLIF(order_count - missing_status_count, 0),
        2
    ) AS late_delivery_pct_excluding_missing_status
FROM monthly_stats
ORDER BY
    CASE WHEN order_month = '[Missing or blank]' THEN 1 ELSE 0 END,
    order_month;