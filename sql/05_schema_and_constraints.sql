create table category (
    category_id int primary key,
    category_name varchar(50) not null
);

create table department (
    department_id int primary key,
    department_name varchar(100) not null
);

create table customer (
    customer_id int primary key,
    first_name text,
    last_name text,
    email text ,
    customer_segment text
);

create table product (
    product_id int primary key,
    category_id int references category(category_id),
    department_id int references department(department_id),
    product_name text,
    description text,
    image_url text,
    product_price numeric(18,9) not null,
    product_status smallint
);

create table customer_order (
    order_id int primary key,
    customer_id int references customer(customer_id),
    transaction_type text,
    order_date timestamp without time zone,
    shipping_date timestamp without time zone,
    order_status text,
    shipping_mode text,
    actual_shipping_days int,
    scheduled_shipping_days int,
    delivery_status text,
    late_delivery_risk smallint,
    market text,
    destination_city text,
    destination_state text,
    destination_country text,
    destination_postal_code text,
    destination_region varchar(32)
);

create table order_item (
    order_item_id int primary key,
    order_id int references customer_order(order_id),
    product_id int references product(product_id),
    discount_amount numeric(18,9),
    discount_rate numeric(11,9),
    unit_product_price numeric(18,9),
    profit_ratio numeric(11,9),
    quantity int,
    sales_amount numeric(18,9),
    order_item_total numeric(18,9)
);

-- DDL check

-- Verify all tables and their columns have been created correctly
SELECT
    table_name,
    column_name,
    data_type,
    character_maximum_length,
    numeric_precision,
    numeric_scale,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN (
      'customer',
      'customer_order',
      'order_item',
      'product',
      'category',
      'department'
  )
ORDER BY table_name, ordinal_position;

-- Verify primary and foreign keys
SELECT
    tc.table_name,
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name,
    ccu.table_name AS referenced_table,
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
      'customer',
      'customer_order',
      'order_item',
      'product',
      'category',
      'department'
  )
  AND tc.constraint_type IN ('PRIMARY KEY', 'FOREIGN KEY')
ORDER BY tc.table_name, tc.constraint_type;
