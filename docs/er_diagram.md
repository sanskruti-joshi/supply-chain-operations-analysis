# Entity-Relationship Diagram

## Purpose and Status

This diagram represents the implemented normalized PostgreSQL schema in
`sql/05_schema_and_constraints.sql`. It contains only the six implemented
entities: category, department, customer, product, customer_order, and
order_item.

## Implemented Model

```mermaid
erDiagram
    CATEGORY ||--o{ PRODUCT : classifies
    DEPARTMENT ||--o{ PRODUCT : groups
    CUSTOMER ||--o{ CUSTOMER_ORDER : places
    CUSTOMER_ORDER ||--o{ ORDER_ITEM : contains
    PRODUCT ||--o{ ORDER_ITEM : appears_in

    CATEGORY {
        integer category_id PK
        varchar(50) category_name
    }

    DEPARTMENT {
        integer department_id PK
        varchar(100) department_name
    }

    CUSTOMER {
        integer customer_id PK
        text first_name
        text last_name
        text email
        text customer_segment
    }

    PRODUCT {
        integer product_id PK
        integer category_id FK
        integer department_id FK
        text product_name
        text description
        text image_url
        numeric(18,9) product_price
        smallint product_status
    }

    CUSTOMER_ORDER {
        integer order_id PK
        integer customer_id FK
        text transaction_type
        timestamp order_date
        timestamp shipping_date
        text order_status
        text shipping_mode
        integer actual_shipping_days
        integer scheduled_shipping_days
        text delivery_status
        smallint late_delivery_risk
        text market
        text destination_city
        text destination_state
        text destination_country
        text destination_postal_code
        varchar(32) destination_region
    }

    ORDER_ITEM {
        integer order_item_id PK
        integer order_id FK
        integer product_id FK
        numeric(18,9) discount_amount
        numeric(11,9) discount_rate
        numeric(18,9) unit_product_price
        numeric(11,9) profit_ratio
        integer quantity
        numeric(18,9) sales_amount
        numeric(18,9) order_item_total
    }
```

## Relationship Cardinalities

- One category may classify zero or more products.
- One department may group zero or more products.
- One customer may place zero or more customer orders.
- One customer order may have zero or more order items in the schema; the
  source migration supplied items for the represented orders.
- One product may appear on zero or more order items.

The foreign-key relationships are:

- `product.category_id -> category.category_id`
- `product.department_id -> department.department_id`
- `customer_order.customer_id -> customer.customer_id`
- `order_item.order_id -> customer_order.order_id`
- `order_item.product_id -> product.product_id`

The migration verified source distinct identifiers against the destination
entity counts and validated foreign-key relationships. Unresolved profit fields,
customer geography fields, `Customer Password`, and coordinates remain outside
the implemented schema.

See [findings_report.md](./findings_report.md) for migration results and
[assumptions_and_limitations.md](./assumptions_and_limitations.md) for remaining
caveats.
