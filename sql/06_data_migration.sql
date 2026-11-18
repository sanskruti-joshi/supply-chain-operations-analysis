-- ============================================================================
-- 06_data_migration.sql
-- Purpose: first-load migration from staging.dataco_raw to public normalized tables
-- ============================================================================

BEGIN;

-- 1. FIRST-LOAD AND CATEGORY PROTECTION

DO $$
DECLARE
    populated_tables integer;
    missing_categories integer;
    blank_category_ids integer;
BEGIN
    SELECT COUNT(*) INTO populated_tables
    FROM (
        SELECT COUNT(*) AS n FROM public.department
        UNION ALL SELECT COUNT(*) FROM public.customer
        UNION ALL SELECT COUNT(*) FROM public.product
        UNION ALL SELECT COUNT(*) FROM public.customer_order
        UNION ALL SELECT COUNT(*) FROM public.order_item
    ) t
    WHERE n > 0;

    IF populated_tables > 0 THEN
        RAISE EXCEPTION 'Reload blocked: one or more destination tables already contain rows.';
    END IF;

    IF (SELECT COUNT(*) FROM public.category) = 0 THEN
        RAISE EXCEPTION 'Category guard: public.category is empty.';
    END IF;

    SELECT COUNT(*) INTO blank_category_ids
    FROM staging.dataco_raw
    WHERE NULLIF(BTRIM("Category Id"), '') IS NULL;

    IF blank_category_ids > 0 THEN
        RAISE EXCEPTION 'Category guard: % source rows have blank Category Id values.',
            blank_category_ids;
    END IF;

    SELECT COUNT(*) INTO missing_categories
    FROM (
        SELECT DISTINCT BTRIM("Category Id")::integer AS category_id
        FROM staging.dataco_raw
    ) s
    WHERE NOT EXISTS (
        SELECT 1 FROM public.category c
        WHERE c.category_id = s.category_id
    );

    IF missing_categories > 0 THEN
        RAISE EXCEPTION 'Category guard: % source Category Id values are absent from public.category.',
            missing_categories;
    END IF;
END
$$;

-- 2. REQUIRED KEYS AND MISSING DEPENDENCIES

DO $$
DECLARE
    missing_customer bigint;
    missing_order bigint;
    missing_item bigint;
    missing_item_product bigint;
    missing_product bigint;
    missing_department bigint;
    missing_department_name bigint;
    missing_product_category bigint;
    missing_product_price bigint;
    duplicate_items bigint;
BEGIN
    SELECT COUNT(*) INTO missing_customer
    FROM staging.dataco_raw
    WHERE NULLIF(BTRIM("Customer Id"), '') IS NULL;

    SELECT COUNT(*) INTO missing_order
    FROM staging.dataco_raw
    WHERE NULLIF(BTRIM("Order Id"), '') IS NULL;

    SELECT COUNT(*) INTO missing_item
    FROM staging.dataco_raw
    WHERE NULLIF(BTRIM("Order Item Id"), '') IS NULL;

    SELECT COUNT(*) INTO missing_item_product
    FROM staging.dataco_raw
    WHERE NULLIF(BTRIM("Order Item Cardprod Id"), '') IS NULL;

    SELECT COUNT(*) INTO missing_product
    FROM staging.dataco_raw
    WHERE NULLIF(BTRIM("Product Card Id"), '') IS NULL;

    SELECT COUNT(*) INTO missing_department
    FROM staging.dataco_raw
    WHERE NULLIF(BTRIM("Department Id"), '') IS NULL;

    SELECT COUNT(*) INTO missing_department_name
FROM (
    SELECT BTRIM("Department Id")
    FROM staging.dataco_raw
    WHERE NULLIF(BTRIM("Department Id"), '') IS NOT NULL
    GROUP BY BTRIM("Department Id")
    HAVING COUNT(DISTINCT NULLIF(BTRIM("Department Name"), '')) = 0
) missing_departments;

    SELECT COUNT(*) INTO missing_product_category
    FROM staging.dataco_raw
    WHERE NULLIF(BTRIM("Product Category Id"), '') IS NULL;

    SELECT COUNT(*) INTO missing_product_price
    FROM staging.dataco_raw
    WHERE NULLIF(BTRIM("Product Card Id"), '') IS NOT NULL
      AND NULLIF(BTRIM("Product Price"), '') IS NULL;

    SELECT COUNT(*) INTO duplicate_items
    FROM (
        SELECT BTRIM("Order Item Id")
        FROM staging.dataco_raw
        WHERE NULLIF(BTRIM("Order Item Id"), '') IS NOT NULL
        GROUP BY BTRIM("Order Item Id")
        HAVING COUNT(*) > 1
    ) d;

    IF missing_customer > 0 OR missing_order > 0 OR missing_item > 0
       OR missing_item_product > 0 OR missing_product > 0
       OR missing_department > 0 OR missing_department_name > 0
       OR missing_product_category > 0 OR missing_product_price > 0
       OR duplicate_items > 0 THEN
        RAISE EXCEPTION
            'Key/dependency guard: customer=%; order=%; item=%; item product=%; product=%; department=%; department name=%; product category=%; product price=%; duplicate item IDs=%.',
            missing_customer, missing_order, missing_item,
            missing_item_product, missing_product, missing_department,
            missing_department_name, missing_product_category,
            missing_product_price, duplicate_items;
    END IF;
END
$$;

-- 3. CONFLICT AND IDENTIFIER CHECKS

-- Diagnostic queries show the affected source keys before migration stops.
SELECT BTRIM("Department Id") AS department_id,
       COUNT(DISTINCT NULLIF(BTRIM("Department Name"), '')) AS name_count
FROM staging.dataco_raw
WHERE NULLIF(BTRIM("Department Id"), '') IS NOT NULL
GROUP BY BTRIM("Department Id")
HAVING COUNT(DISTINCT NULLIF(BTRIM("Department Name"), '')) > 1;

SELECT BTRIM("Customer Id") AS customer_id,
       COUNT(DISTINCT NULLIF(BTRIM("Customer Fname"), '')) AS first_name_count,
       COUNT(DISTINCT NULLIF(BTRIM("Customer Lname"), '')) AS last_name_count,
       COUNT(DISTINCT NULLIF(BTRIM("Customer Email"), '')) AS email_count,
       COUNT(DISTINCT NULLIF(BTRIM("Customer Segment"), '')) AS segment_count
FROM staging.dataco_raw
WHERE NULLIF(BTRIM("Customer Id"), '') IS NOT NULL
GROUP BY BTRIM("Customer Id")
HAVING COUNT(DISTINCT NULLIF(BTRIM("Customer Fname"), '')) > 1
    OR COUNT(DISTINCT NULLIF(BTRIM("Customer Lname"), '')) > 1
    OR COUNT(DISTINCT NULLIF(BTRIM("Customer Email"), '')) > 1
    OR COUNT(DISTINCT NULLIF(BTRIM("Customer Segment"), '')) > 1;

SELECT BTRIM("Product Card Id") AS product_id,
       COUNT(DISTINCT NULLIF(BTRIM("Product Name"), '')) AS name_count,
       COUNT(DISTINCT NULLIF(BTRIM("Product Description"), '')) AS description_count,
       COUNT(DISTINCT NULLIF(BTRIM("Product Image"), '')) AS image_count,
       COUNT(DISTINCT NULLIF(BTRIM("Product Price"), '')) AS price_count,
       COUNT(DISTINCT NULLIF(BTRIM("Product Status"), '')) AS status_count,
       COUNT(DISTINCT NULLIF(BTRIM("Product Category Id"), '')) AS category_count,
       COUNT(DISTINCT NULLIF(BTRIM("Department Id"), '')) AS department_count,
       COUNT(DISTINCT NULLIF(BTRIM("Order Item Cardprod Id"), '')) AS cardprod_count
FROM staging.dataco_raw
WHERE NULLIF(BTRIM("Product Card Id"), '') IS NOT NULL
GROUP BY BTRIM("Product Card Id")
HAVING COUNT(DISTINCT NULLIF(BTRIM("Product Name"), '')) > 1
    OR COUNT(DISTINCT NULLIF(BTRIM("Product Description"), '')) > 1
    OR COUNT(DISTINCT NULLIF(BTRIM("Product Image"), '')) > 1
    OR COUNT(DISTINCT NULLIF(BTRIM("Product Price"), '')) > 1
    OR COUNT(DISTINCT NULLIF(BTRIM("Product Status"), '')) > 1
    OR COUNT(DISTINCT NULLIF(BTRIM("Product Category Id"), '')) > 1
    OR COUNT(DISTINCT NULLIF(BTRIM("Department Id"), '')) > 1
    OR COUNT(DISTINCT NULLIF(BTRIM("Order Item Cardprod Id"), '')) > 1;

DO $$
DECLARE
    department_conflicts integer;
    customer_conflicts integer;
    product_conflicts integer;
    category_conflicts integer;
    mismatched_customers bigint;
    mismatched_products bigint;
BEGIN
    SELECT COUNT(*) INTO department_conflicts
    FROM (
        SELECT BTRIM("Department Id")
        FROM staging.dataco_raw
        WHERE NULLIF(BTRIM("Department Id"), '') IS NOT NULL
        GROUP BY BTRIM("Department Id")
        HAVING COUNT(DISTINCT NULLIF(BTRIM("Department Name"), '')) > 1
    ) s;

    SELECT COUNT(*) INTO customer_conflicts
    FROM (
        SELECT BTRIM("Customer Id")
        FROM staging.dataco_raw
        WHERE NULLIF(BTRIM("Customer Id"), '') IS NOT NULL
        GROUP BY BTRIM("Customer Id")
        HAVING COUNT(DISTINCT NULLIF(BTRIM("Customer Fname"), '')) > 1
            OR COUNT(DISTINCT NULLIF(BTRIM("Customer Lname"), '')) > 1
            OR COUNT(DISTINCT NULLIF(BTRIM("Customer Email"), '')) > 1
            OR COUNT(DISTINCT NULLIF(BTRIM("Customer Segment"), '')) > 1
    ) s;

    SELECT COUNT(*) INTO product_conflicts
    FROM (
        SELECT BTRIM("Product Card Id")
        FROM staging.dataco_raw
        WHERE NULLIF(BTRIM("Product Card Id"), '') IS NOT NULL
        GROUP BY BTRIM("Product Card Id")
        HAVING COUNT(DISTINCT NULLIF(BTRIM("Product Name"), '')) > 1
            OR COUNT(DISTINCT NULLIF(BTRIM("Product Description"), '')) > 1
            OR COUNT(DISTINCT NULLIF(BTRIM("Product Image"), '')) > 1
            OR COUNT(DISTINCT NULLIF(BTRIM("Product Price"), '')) > 1
            OR COUNT(DISTINCT NULLIF(BTRIM("Product Status"), '')) > 1
            OR COUNT(DISTINCT NULLIF(BTRIM("Product Category Id"), '')) > 1
            OR COUNT(DISTINCT NULLIF(BTRIM("Department Id"), '')) > 1
            OR COUNT(DISTINCT NULLIF(BTRIM("Order Item Cardprod Id"), '')) > 1
    ) s;

    SELECT COUNT(*) INTO category_conflicts
    FROM (
        SELECT BTRIM("Category Id")
        FROM staging.dataco_raw
        WHERE NULLIF(BTRIM("Category Id"), '') IS NOT NULL
        GROUP BY BTRIM("Category Id")
        HAVING COUNT(DISTINCT NULLIF(BTRIM("Category Name"), '')) > 1
    ) s;

    SELECT COUNT(*) INTO mismatched_customers
    FROM staging.dataco_raw
    WHERE NULLIF(BTRIM("Customer Id"), '') IS DISTINCT FROM
          NULLIF(BTRIM("Order Customer Id"), '');

    SELECT COUNT(*) INTO mismatched_products
    FROM staging.dataco_raw
    WHERE NULLIF(BTRIM("Product Card Id"), '') IS DISTINCT FROM
          NULLIF(BTRIM("Order Item Cardprod Id"), '')
       OR NULLIF(BTRIM("Category Id"), '') IS DISTINCT FROM
          NULLIF(BTRIM("Product Category Id"), '');

    IF department_conflicts > 0 OR customer_conflicts > 0
       OR product_conflicts > 0 OR category_conflicts > 0
       OR mismatched_customers > 0 OR mismatched_products > 0 THEN
        RAISE EXCEPTION
            'Conflict/mismatch guard: department=%; customer=%; product=%; category=%; customer mismatches=%; product/category mismatches=%.',
            department_conflicts, customer_conflicts, product_conflicts,
            category_conflicts, mismatched_customers, mismatched_products;
    END IF;
END
$$;

-- Order-header conflicts; these values must be stable before one order row is created.
SELECT BTRIM("Order Id") AS order_id,
       COUNT(DISTINCT NULLIF(BTRIM("Type"), '')) AS type_count,
       COUNT(DISTINCT NULLIF(BTRIM("Order Customer Id"), '')) AS customer_count,
       COUNT(DISTINCT NULLIF(BTRIM("order date (DateOrders)"), '')) AS order_date_count,
       COUNT(DISTINCT NULLIF(BTRIM("shipping date (DateOrders)"), '')) AS shipping_date_count,
       COUNT(DISTINCT NULLIF(BTRIM("Order Status"), '')) AS status_count,
       COUNT(DISTINCT NULLIF(BTRIM("Shipping Mode"), '')) AS shipping_mode_count,
       COUNT(DISTINCT NULLIF(BTRIM("Delivery Status"), '')) AS delivery_count,
       COUNT(DISTINCT NULLIF(BTRIM("Late_delivery_risk"), '')) AS risk_count,
       COUNT(DISTINCT NULLIF(BTRIM("Market"), '')) AS market_count,
       COUNT(DISTINCT NULLIF(BTRIM("Order City"), '')) AS city_count,
       COUNT(DISTINCT NULLIF(BTRIM("Order State"), '')) AS state_count,
       COUNT(DISTINCT NULLIF(BTRIM("Order Country"), '')) AS country_count,
       COUNT(DISTINCT NULLIF(BTRIM("Order Zipcode"), '')) AS postal_count,
       COUNT(DISTINCT NULLIF(BTRIM("Order Region"), '')) AS region_count,
       COUNT(DISTINCT NULLIF(BTRIM("Days for shipping (real)"), '')) AS actual_days_count,
       COUNT(DISTINCT NULLIF(BTRIM("Days for shipment (scheduled)"), '')) AS scheduled_days_count
FROM staging.dataco_raw
WHERE NULLIF(BTRIM("Order Id"), '') IS NOT NULL
GROUP BY BTRIM("Order Id")
HAVING COUNT(DISTINCT NULLIF(BTRIM("Type"), '')) > 1
    OR COUNT(DISTINCT NULLIF(BTRIM("Order Customer Id"), '')) > 1
    OR COUNT(DISTINCT NULLIF(BTRIM("order date (DateOrders)"), '')) > 1
    OR COUNT(DISTINCT NULLIF(BTRIM("shipping date (DateOrders)"), '')) > 1
    OR COUNT(DISTINCT NULLIF(BTRIM("Order Status"), '')) > 1
    OR COUNT(DISTINCT NULLIF(BTRIM("Shipping Mode"), '')) > 1
    OR COUNT(DISTINCT NULLIF(BTRIM("Delivery Status"), '')) > 1
    OR COUNT(DISTINCT NULLIF(BTRIM("Late_delivery_risk"), '')) > 1
    OR COUNT(DISTINCT NULLIF(BTRIM("Market"), '')) > 1
    OR COUNT(DISTINCT NULLIF(BTRIM("Order City"), '')) > 1
    OR COUNT(DISTINCT NULLIF(BTRIM("Order State"), '')) > 1
    OR COUNT(DISTINCT NULLIF(BTRIM("Order Country"), '')) > 1
    OR COUNT(DISTINCT NULLIF(BTRIM("Order Zipcode"), '')) > 1
    OR COUNT(DISTINCT NULLIF(BTRIM("Order Region"), '')) > 1
    OR COUNT(DISTINCT NULLIF(BTRIM("Days for shipping (real)"), '')) > 1
    OR COUNT(DISTINCT NULLIF(BTRIM("Days for shipment (scheduled)"), '')) > 1;

DO $$
DECLARE
    order_conflicts integer;
BEGIN
    SELECT COUNT(*) INTO order_conflicts
    FROM (
        SELECT BTRIM("Order Id")
        FROM staging.dataco_raw
        WHERE NULLIF(BTRIM("Order Id"), '') IS NOT NULL
        GROUP BY BTRIM("Order Id")
        HAVING COUNT(DISTINCT NULLIF(BTRIM("Type"), '')) > 1
            OR COUNT(DISTINCT NULLIF(BTRIM("Order Customer Id"), '')) > 1
            OR COUNT(DISTINCT NULLIF(BTRIM("order date (DateOrders)"), '')) > 1
            OR COUNT(DISTINCT NULLIF(BTRIM("shipping date (DateOrders)"), '')) > 1
            OR COUNT(DISTINCT NULLIF(BTRIM("Order Status"), '')) > 1
            OR COUNT(DISTINCT NULLIF(BTRIM("Shipping Mode"), '')) > 1
            OR COUNT(DISTINCT NULLIF(BTRIM("Delivery Status"), '')) > 1
            OR COUNT(DISTINCT NULLIF(BTRIM("Late_delivery_risk"), '')) > 1
            OR COUNT(DISTINCT NULLIF(BTRIM("Market"), '')) > 1
            OR COUNT(DISTINCT NULLIF(BTRIM("Order City"), '')) > 1
            OR COUNT(DISTINCT NULLIF(BTRIM("Order State"), '')) > 1
            OR COUNT(DISTINCT NULLIF(BTRIM("Order Country"), '')) > 1
            OR COUNT(DISTINCT NULLIF(BTRIM("Order Zipcode"), '')) > 1
            OR COUNT(DISTINCT NULLIF(BTRIM("Order Region"), '')) > 1
            OR COUNT(DISTINCT NULLIF(BTRIM("Days for shipping (real)"), '')) > 1
            OR COUNT(DISTINCT NULLIF(BTRIM("Days for shipment (scheduled)"), '')) > 1
    ) s;

    IF order_conflicts > 0 THEN
        RAISE EXCEPTION 'Order-header conflict: % Order Id values have conflicting attributes.',
            order_conflicts;
    END IF;
END
$$;

-- 4. NUMERIC AND DATE VALIDATION

CREATE TEMP TABLE invalid_numeric_values ON COMMIT DROP AS
SELECT field_name, raw_value
FROM staging.dataco_raw r
CROSS JOIN LATERAL (
    VALUES
        ('Category Id', r."Category Id", 'integer'),
        ('Department Id', r."Department Id", 'integer'),
        ('Customer Id', r."Customer Id", 'integer'),
        ('Order Customer Id', r."Order Customer Id", 'integer'),
        ('Order Id', r."Order Id", 'integer'),
        ('Order Item Id', r."Order Item Id", 'integer'),
        ('Product Card Id', r."Product Card Id", 'integer'),
        ('Order Item Cardprod Id', r."Order Item Cardprod Id", 'integer'),
        ('Product Category Id', r."Product Category Id", 'integer'),
        ('Days for shipping (real)', r."Days for shipping (real)", 'integer'),
        ('Days for shipment (scheduled)', r."Days for shipment (scheduled)", 'integer'),
        ('Order Item Quantity', r."Order Item Quantity", 'integer'),
        ('Late_delivery_risk', r."Late_delivery_risk", 'smallint'),
        ('Product Status', r."Product Status", 'smallint'),
        ('Product Price', r."Product Price", 'decimal18'),
        ('Order Item Discount', r."Order Item Discount", 'decimal18'),
        ('Order Item Discount Rate', r."Order Item Discount Rate", 'decimal11'),
        ('Order Item Product Price', r."Order Item Product Price", 'decimal18'),
        ('Order Item Profit Ratio', r."Order Item Profit Ratio", 'decimal11'),
        ('Sales', r."Sales", 'decimal18'),
        ('Order Item Total', r."Order Item Total", 'decimal18')
) v(field_name, raw_value, value_kind)
WHERE NULLIF(BTRIM(raw_value), '') IS NOT NULL
  AND NOT (
      CASE
          WHEN value_kind IN ('integer', 'smallint')
              THEN BTRIM(raw_value) ~ '^[+-]?[0-9]+$'
          ELSE BTRIM(raw_value) ~
              '^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?$'
      END
  );

DO $$
DECLARE
    invalid_count bigint;
    bad_integer bigint;
    bad_smallint bigint;
    bad_decimal18 bigint;
    bad_decimal11 bigint;
    bad_order_dates bigint;
    bad_shipping_dates bigint;
    bad_risk bigint;
    bad_status bigint;
BEGIN
    SELECT COUNT(*) INTO invalid_count FROM invalid_numeric_values;
    IF invalid_count > 0 THEN
        RAISE EXCEPTION 'Numeric syntax guard: % invalid nonblank numeric values.',
            invalid_count;
    END IF;

    WITH integer_values AS (
        SELECT "Category Id" AS v FROM staging.dataco_raw
        UNION ALL SELECT "Department Id" FROM staging.dataco_raw
        UNION ALL SELECT "Customer Id" FROM staging.dataco_raw
        UNION ALL SELECT "Order Customer Id" FROM staging.dataco_raw
        UNION ALL SELECT "Order Id" FROM staging.dataco_raw
        UNION ALL SELECT "Order Item Id" FROM staging.dataco_raw
        UNION ALL SELECT "Product Card Id" FROM staging.dataco_raw
        UNION ALL SELECT "Order Item Cardprod Id" FROM staging.dataco_raw
        UNION ALL SELECT "Product Category Id" FROM staging.dataco_raw
        UNION ALL SELECT "Days for shipping (real)" FROM staging.dataco_raw
        UNION ALL SELECT "Days for shipment (scheduled)" FROM staging.dataco_raw
        UNION ALL SELECT "Order Item Quantity" FROM staging.dataco_raw
    )
    SELECT COUNT(*) INTO bad_integer
    FROM integer_values
    WHERE NULLIF(BTRIM(v), '') IS NOT NULL
      AND (BTRIM(v)::numeric < -2147483648 OR BTRIM(v)::numeric > 2147483647);

    IF bad_integer > 0 THEN
        RAISE EXCEPTION 'INTEGER range guard: % values exceed target range.', bad_integer;
    END IF;

    WITH smallint_values AS (
        SELECT "Late_delivery_risk" AS v FROM staging.dataco_raw
        UNION ALL SELECT "Product Status" FROM staging.dataco_raw
    )
    SELECT COUNT(*) INTO bad_smallint
    FROM smallint_values
    WHERE NULLIF(BTRIM(v), '') IS NOT NULL
      AND (BTRIM(v)::numeric < -32768 OR BTRIM(v)::numeric > 32767);

    IF bad_smallint > 0 THEN
        RAISE EXCEPTION 'SMALLINT range guard: % values exceed target range.', bad_smallint;
    END IF;

    WITH decimal18_values AS (
        SELECT "Product Price" AS v FROM staging.dataco_raw
        UNION ALL SELECT "Order Item Discount" FROM staging.dataco_raw
        UNION ALL SELECT "Order Item Product Price" FROM staging.dataco_raw
        UNION ALL SELECT "Sales" FROM staging.dataco_raw
        UNION ALL SELECT "Order Item Total" FROM staging.dataco_raw
    )
    SELECT COUNT(*) INTO bad_decimal18
    FROM decimal18_values
    WHERE NULLIF(BTRIM(v), '') IS NOT NULL
      AND (ABS(BTRIM(v)::numeric) >= 1000000000
           OR SCALE(BTRIM(v)::numeric) > 9);

    IF bad_decimal18 > 0 THEN
        RAISE EXCEPTION 'NUMERIC(18,9) guard: % values overflow or exceed nine fractional digits.',
            bad_decimal18;
    END IF;

    WITH decimal11_values AS (
        SELECT "Order Item Discount Rate" AS v FROM staging.dataco_raw
        UNION ALL SELECT "Order Item Profit Ratio" FROM staging.dataco_raw
    )
    SELECT COUNT(*) INTO bad_decimal11
    FROM decimal11_values
    WHERE NULLIF(BTRIM(v), '') IS NOT NULL
      AND (ABS(BTRIM(v)::numeric) >= 100
           OR SCALE(BTRIM(v)::numeric) > 9);

    IF bad_decimal11 > 0 THEN
        RAISE EXCEPTION 'NUMERIC(11,9) guard: % values overflow or exceed nine fractional digits.',
            bad_decimal11;
    END IF;

    SELECT COUNT(*) INTO bad_order_dates
    FROM staging.dataco_raw
    WHERE NULLIF(BTRIM("order date (DateOrders)"), '') IS NOT NULL
      AND NOT (BTRIM("order date (DateOrders)") ~
               '^(0?[1-9]|1[0-2])/(0?[1-9]|[12][0-9]|3[01])/[0-9]{4} ([01]?[0-9]|2[0-3]):[0-5][0-9]$');

    SELECT COUNT(*) INTO bad_shipping_dates
    FROM staging.dataco_raw
    WHERE NULLIF(BTRIM("shipping date (DateOrders)"), '') IS NOT NULL
      AND NOT (BTRIM("shipping date (DateOrders)") ~
               '^(0?[1-9]|1[0-2])/(0?[1-9]|[12][0-9]|3[01])/[0-9]{4} ([01]?[0-9]|2[0-3]):[0-5][0-9]$');

    IF bad_order_dates > 0 OR bad_shipping_dates > 0 THEN
        RAISE EXCEPTION 'Date format guard: invalid order dates=%; invalid shipping dates=%.',
            bad_order_dates, bad_shipping_dates;
    END IF;

    SELECT COUNT(*) INTO bad_risk
    FROM staging.dataco_raw
    WHERE NULLIF(BTRIM("Late_delivery_risk"), '') IS NOT NULL
      AND BTRIM("Late_delivery_risk")::smallint NOT IN (0, 1);

    SELECT COUNT(*) INTO bad_status
    FROM staging.dataco_raw
    WHERE NULLIF(BTRIM("Product Status"), '') IS NOT NULL
      AND BTRIM("Product Status")::smallint NOT IN (0, 1);

    IF bad_risk > 0 OR bad_status > 0 THEN
        RAISE EXCEPTION 'Flag guard: Late_delivery_risk=%; Product Status=%.',
            bad_risk, bad_status;
    END IF;
END
$$;

-- Create exactly one timestamp record per order.
CREATE TEMP TABLE migration_order_dates ON COMMIT DROP AS
WITH parsed AS (
    SELECT
        BTRIM("Order Id") AS order_id,
        CASE
            WHEN NULLIF(BTRIM("order date (DateOrders)"), '') IS NULL THEN NULL
            ELSE make_timestamp(
                (regexp_match(BTRIM("order date (DateOrders)"), '^([0-9]+)/([0-9]+)/([0-9]+) ([0-9]+):([0-9]+)$'))[3]::integer,
                (regexp_match(BTRIM("order date (DateOrders)"), '^([0-9]+)/([0-9]+)/([0-9]+) ([0-9]+):([0-9]+)$'))[1]::integer,
                (regexp_match(BTRIM("order date (DateOrders)"), '^([0-9]+)/([0-9]+)/([0-9]+) ([0-9]+):([0-9]+)$'))[2]::integer,
                (regexp_match(BTRIM("order date (DateOrders)"), '^([0-9]+)/([0-9]+)/([0-9]+) ([0-9]+):([0-9]+)$'))[4]::integer,
                (regexp_match(BTRIM("order date (DateOrders)"), '^([0-9]+)/([0-9]+)/([0-9]+) ([0-9]+):([0-9]+)$'))[5]::integer,
                0
            )
        END AS order_date,
        CASE
            WHEN NULLIF(BTRIM("shipping date (DateOrders)"), '') IS NULL THEN NULL
            ELSE make_timestamp(
                (regexp_match(BTRIM("shipping date (DateOrders)"), '^([0-9]+)/([0-9]+)/([0-9]+) ([0-9]+):([0-9]+)$'))[3]::integer,
                (regexp_match(BTRIM("shipping date (DateOrders)"), '^([0-9]+)/([0-9]+)/([0-9]+) ([0-9]+):([0-9]+)$'))[1]::integer,
                (regexp_match(BTRIM("shipping date (DateOrders)"), '^([0-9]+)/([0-9]+)/([0-9]+) ([0-9]+):([0-9]+)$'))[2]::integer,
                (regexp_match(BTRIM("shipping date (DateOrders)"), '^([0-9]+)/([0-9]+)/([0-9]+) ([0-9]+):([0-9]+)$'))[4]::integer,
                (regexp_match(BTRIM("shipping date (DateOrders)"), '^([0-9]+)/([0-9]+)/([0-9]+) ([0-9]+):([0-9]+)$'))[5]::integer,
                0
            )
        END AS shipping_date
    FROM staging.dataco_raw
)
SELECT order_id, MAX(order_date) AS order_date, MAX(shipping_date) AS shipping_date
FROM parsed
GROUP BY order_id;

-- 5. DEPARTMENT MIGRATION

INSERT INTO public.department (department_id, department_name)
SELECT BTRIM("Department Id")::integer,
       MAX(BTRIM("Department Name"))
FROM staging.dataco_raw
WHERE NULLIF(BTRIM("Department Id"), '') IS NOT NULL
GROUP BY BTRIM("Department Id");

-- 6. CUSTOMER MIGRATION

INSERT INTO public.customer (
    customer_id, first_name, last_name, email, customer_segment
)
SELECT BTRIM("Customer Id")::integer,
       MAX(NULLIF(BTRIM("Customer Fname"), '')),
       MAX(NULLIF(BTRIM("Customer Lname"), '')),
       MAX(NULLIF(BTRIM("Customer Email"), '')),
       MAX(NULLIF(BTRIM("Customer Segment"), ''))
FROM staging.dataco_raw
WHERE NULLIF(BTRIM("Customer Id"), '') IS NOT NULL
GROUP BY BTRIM("Customer Id");

-- 7. PRODUCT MIGRATION

INSERT INTO public.product (
    product_id, category_id, department_id, product_name, description,
    image_url, product_price, product_status
)
SELECT BTRIM("Product Card Id")::integer,
       BTRIM(MAX("Product Category Id"))::integer,
       BTRIM(MAX("Department Id"))::integer,
       MAX(NULLIF(BTRIM("Product Name"), '')),
       MAX(NULLIF(BTRIM("Product Description"), '')),
       MAX(NULLIF(BTRIM("Product Image"), '')),
       BTRIM(MAX("Product Price"))::numeric(18,9),
       NULLIF(BTRIM(MAX("Product Status")), '')::smallint
FROM staging.dataco_raw
WHERE NULLIF(BTRIM("Product Card Id"), '') IS NOT NULL
  AND NULLIF(BTRIM("Product Category Id"), '') IS NOT NULL
  AND NULLIF(BTRIM("Department Id"), '') IS NOT NULL
  AND NULLIF(BTRIM("Product Price"), '') IS NOT NULL
GROUP BY BTRIM("Product Card Id");

-- 8. CUSTOMER ORDER MIGRATION

INSERT INTO public.customer_order (
    order_id, customer_id, transaction_type, order_date, shipping_date,
    order_status, shipping_mode, actual_shipping_days,
    scheduled_shipping_days, delivery_status, late_delivery_risk, market,
    destination_city, destination_state, destination_country,
    destination_postal_code, destination_region
)
SELECT BTRIM(MAX("Order Id"))::integer,
       BTRIM(MAX("Order Customer Id"))::integer,
       MAX(NULLIF(BTRIM("Type"), '')),
       d.order_date,
       d.shipping_date,
       MAX(NULLIF(BTRIM("Order Status"), '')),
       MAX(NULLIF(BTRIM("Shipping Mode"), '')),
       MAX(NULLIF(BTRIM("Days for shipping (real)"), '')::integer),
       MAX(NULLIF(BTRIM("Days for shipment (scheduled)"), '')::integer),
       MAX(NULLIF(BTRIM("Delivery Status"), '')),
       MAX(NULLIF(BTRIM("Late_delivery_risk"), '')::smallint),
       MAX(NULLIF(BTRIM("Market"), '')),
       MAX(NULLIF(BTRIM("Order City"), '')),
       MAX(NULLIF(BTRIM("Order State"), '')),
       MAX(NULLIF(BTRIM("Order Country"), '')),
       MAX(NULLIF(BTRIM("Order Zipcode"), '')),
       MAX(NULLIF(BTRIM("Order Region"), ''))
FROM staging.dataco_raw r
JOIN migration_order_dates d
  ON d.order_id = BTRIM(r."Order Id")
WHERE NULLIF(BTRIM(r."Order Id"), '') IS NOT NULL
  AND NULLIF(BTRIM(r."Order Customer Id"), '') IS NOT NULL
GROUP BY BTRIM(r."Order Id"), d.order_date, d.shipping_date;

-- 9. ORDER ITEM MIGRATION

INSERT INTO public.order_item (
    order_item_id, order_id, product_id, discount_amount, discount_rate,
    unit_product_price, profit_ratio, quantity, sales_amount, order_item_total
)
SELECT BTRIM("Order Item Id")::integer,
       BTRIM("Order Id")::integer,
       BTRIM("Order Item Cardprod Id")::integer,
       NULLIF(BTRIM("Order Item Discount"), '')::numeric(18,9),
       NULLIF(BTRIM("Order Item Discount Rate"), '')::numeric(11,9),
       NULLIF(BTRIM("Order Item Product Price"), '')::numeric(18,9),
       NULLIF(BTRIM("Order Item Profit Ratio"), '')::numeric(11,9),
       NULLIF(BTRIM("Order Item Quantity"), '')::integer,
       NULLIF(BTRIM("Sales"), '')::numeric(18,9),
       NULLIF(BTRIM("Order Item Total"), '')::numeric(18,9)
FROM staging.dataco_raw
WHERE NULLIF(BTRIM("Order Item Id"), '') IS NOT NULL
  AND NULLIF(BTRIM("Order Id"), '') IS NOT NULL
  AND NULLIF(BTRIM("Order Item Cardprod Id"), '') IS NOT NULL;

-- 10. POST-MIGRATION VALIDATION

-- Entity and reconciliation counts.
SELECT 'category' AS table_name, COUNT(*) AS row_count FROM public.category
UNION ALL SELECT 'department', COUNT(*) FROM public.department
UNION ALL SELECT 'customer', COUNT(*) FROM public.customer
UNION ALL SELECT 'product', COUNT(*) FROM public.product
UNION ALL SELECT 'customer_order', COUNT(*) FROM public.customer_order
UNION ALL SELECT 'order_item', COUNT(*) FROM public.order_item;

SELECT
    (SELECT COUNT(DISTINCT NULLIF(BTRIM("Category Id"), '')) FROM staging.dataco_raw) AS source_categories,
    (SELECT COUNT(*) FROM public.category) AS destination_categories,
    (SELECT COUNT(DISTINCT NULLIF(BTRIM("Department Id"), '')) FROM staging.dataco_raw) AS source_departments,
    (SELECT COUNT(*) FROM public.department) AS destination_departments,
    (SELECT COUNT(DISTINCT NULLIF(BTRIM("Customer Id"), '')) FROM staging.dataco_raw) AS source_customers,
    (SELECT COUNT(*) FROM public.customer) AS destination_customers,
    (SELECT COUNT(DISTINCT NULLIF(BTRIM("Product Card Id"), '')) FROM staging.dataco_raw) AS source_products,
    (SELECT COUNT(*) FROM public.product) AS destination_products,
    (SELECT COUNT(DISTINCT NULLIF(BTRIM("Order Id"), '')) FROM staging.dataco_raw) AS source_orders,
    (SELECT COUNT(*) FROM public.customer_order) AS destination_orders,
    (SELECT COUNT(DISTINCT NULLIF(BTRIM("Order Item Id"), '')) FROM staging.dataco_raw) AS source_items,
    (SELECT COUNT(*) FROM public.order_item) AS destination_items;

-- One fail-fast block covers orphaned foreign keys and exact order-item reconciliation.
DO $$
DECLARE
    source_rows bigint;
    source_items bigint;
    destination_items bigint;
    missing_items bigint;
    extra_items bigint;
    orphan_count bigint;
BEGIN
    SELECT
        (SELECT COUNT(*) FROM public.product p
         LEFT JOIN public.category c ON c.category_id = p.category_id
         WHERE p.category_id IS NOT NULL AND c.category_id IS NULL)
      + (SELECT COUNT(*) FROM public.product p
         LEFT JOIN public.department d ON d.department_id = p.department_id
         WHERE p.department_id IS NOT NULL AND d.department_id IS NULL)
      + (SELECT COUNT(*) FROM public.customer_order o
         LEFT JOIN public.customer c ON c.customer_id = o.customer_id
         WHERE o.customer_id IS NOT NULL AND c.customer_id IS NULL)
      + (SELECT COUNT(*) FROM public.order_item i
         LEFT JOIN public.customer_order o ON o.order_id = i.order_id
         WHERE i.order_id IS NOT NULL AND o.order_id IS NULL)
      + (SELECT COUNT(*) FROM public.order_item i
         LEFT JOIN public.product p ON p.product_id = i.product_id
         WHERE i.product_id IS NOT NULL AND p.product_id IS NULL)
    INTO orphan_count;

    IF orphan_count > 0 THEN
        RAISE EXCEPTION 'Foreign-key reconciliation failed: % orphan references found.',
            orphan_count;
    END IF;

    SELECT COUNT(*) INTO source_rows FROM staging.dataco_raw;
    SELECT COUNT(DISTINCT NULLIF(BTRIM("Order Item Id"), ''))
    INTO source_items
    FROM staging.dataco_raw;
    SELECT COUNT(*) INTO destination_items FROM public.order_item;

    SELECT COUNT(*) INTO missing_items
    FROM (
        SELECT BTRIM("Order Item Id") AS item_id
        FROM staging.dataco_raw
        EXCEPT
        SELECT CAST(order_item_id AS text) FROM public.order_item
    ) s;

    SELECT COUNT(*) INTO extra_items
    FROM (
        SELECT CAST(order_item_id AS text) FROM public.order_item
        EXCEPT
        SELECT BTRIM("Order Item Id") FROM staging.dataco_raw
    ) s;

    IF source_rows <> 180519 THEN
        RAISE EXCEPTION 'Source count guard: expected 180519 staging rows, found %.',
            source_rows;
    END IF;

    IF source_rows <> source_items
       OR source_items <> destination_items
       OR missing_items <> 0
       OR extra_items <> 0 THEN
        RAISE EXCEPTION
            'Order-item reconciliation failed: source rows=%; source item IDs=%; destination item IDs=%; missing=%; extra=%.',
            source_rows, source_items, destination_items, missing_items, extra_items;
    END IF;
END
$$;

COMMIT;
