# Data Dictionary

## 1. Overview

This dictionary describes the six implemented normalized tables in PostgreSQL.
Column names, types, and nullability are based on
`sql/05_schema_and_constraints.sql`. Source-column descriptions are retained
where they clarify the implemented mappings; they are descriptive metadata,
not independent proof of a business definition.

## 2. Category

| Column | PostgreSQL type | Nullability | Key / constraint | Source description |
|---|---|---|---|---|
| `category_id` | `INTEGER` | NOT NULL | Primary key | Product category code. |
| `category_name` | `VARCHAR(50)` | NOT NULL |  | Description of the product category. |

Source mapping: `Category Id` and `Category Name`.

## 3. Department

| Column | PostgreSQL type | Nullability | Key / constraint | Source description |
|---|---|---|---|---|
| `department_id` | `INTEGER` | NOT NULL | Primary key | Department code of the store. |
| `department_name` | `VARCHAR(100)` | NOT NULL |  | Department name of the store. |

Source mapping: `Department Id` and `Department Name`.

## 4. Customer

| Column | PostgreSQL type | Nullability | Key / constraint | Source description |
|---|---|---|---|---|
| `customer_id` | `INTEGER` | NOT NULL | Primary key | Customer ID. |
| `first_name` | `TEXT` | NULL allowed |  | Customer first name. |
| `last_name` | `TEXT` | NULL allowed |  | Customer last name. |
| `email` | `TEXT` | NULL allowed |  | Customer email. |
| `customer_segment` | `TEXT` | NULL allowed |  | Consumer, Corporate, or Home Office customer type. |

Source mapping: `Customer Id`, `Customer Fname`, `Customer Lname`,
`Customer Email`, and `Customer Segment`.

## 5. Product

| Column | PostgreSQL type | Nullability | Key / constraint | Source description |
|---|---|---|---|---|
| `product_id` | `INTEGER` | NOT NULL | Primary key | Product code. |
| `category_id` | `INTEGER` | NULL allowed | Foreign key to `category.category_id` | Product category code. |
| `department_id` | `INTEGER` | NULL allowed | Foreign key to `department.department_id` | Department code. |
| `product_name` | `TEXT` | NULL allowed |  | Product name. |
| `description` | `TEXT` | NULL allowed |  | Product description. |
| `image_url` | `TEXT` | NULL allowed |  | Product image link. |
| `product_price` | `NUMERIC(18,9)` | NOT NULL |  | Product price. |
| `product_status` | `SMALLINT` | NULL allowed |  | Source coding: 0 available and 1 unavailable in the source glossary. |

Source mapping: `Product Card Id`, `Product Category Id`, `Department Id`,
`Product Name`, `Product Description`, `Product Image`, `Product Price`, and
`Product Status`.

## 6. Customer Order

| Column | PostgreSQL type | Nullability | Key / constraint | Source description |
|---|---|---|---|---|
| `order_id` | `INTEGER` | NOT NULL | Primary key | Order code. |
| `customer_id` | `INTEGER` | NULL allowed | Foreign key to `customer.customer_id` | Customer reference sourced from `Order Customer Id`. |
| `transaction_type` | `TEXT` | NULL allowed |  | Type of transaction. |
| `order_date` | `TIMESTAMP WITHOUT TIME ZONE` | NULL allowed |  | Date and time the order was made. |
| `shipping_date` | `TIMESTAMP WITHOUT TIME ZONE` | NULL allowed |  | Shipment date and time. |
| `order_status` | `TEXT` | NULL allowed |  | Order lifecycle status. |
| `shipping_mode` | `TEXT` | NULL allowed |  | Standard, First, Second, or Same Day shipping mode. |
| `actual_shipping_days` | `INTEGER` | NULL allowed |  | Actual shipping duration. |
| `scheduled_shipping_days` | `INTEGER` | NULL allowed |  | Scheduled shipping duration. |
| `delivery_status` | `TEXT` | NULL allowed |  | Delivery outcome. |
| `late_delivery_risk` | `SMALLINT` | NULL allowed |  | Source 0/1 late-delivery indicator. |
| `market` | `TEXT` | NULL allowed |  | Destination market. |
| `destination_city` | `TEXT` | NULL allowed |  | Destination city. |
| `destination_state` | `TEXT` | NULL allowed |  | Destination state. |
| `destination_country` | `TEXT` | NULL allowed |  | Destination country. |
| `destination_postal_code` | `TEXT` | NULL allowed |  | Destination ZIP/postal code. |
| `destination_region` | `VARCHAR(32)` | NULL allowed |  | Destination region. |

Source mapping: `Type`, `Order Id`, `Order Customer Id`,
`order date (DateOrders)`, `shipping date (DateOrders)`, `Order Status`,
`Shipping Mode`, `Days for shipping (real)`, `Days for shipment (scheduled)`,
`Delivery Status`, `Late_delivery_risk`, `Market`, `Order City`, `Order State`,
`Order Country`, `Order Zipcode`, and `Order Region`.

## 7. Order Item

| Column | PostgreSQL type | Nullability | Key / constraint | Source description |
|---|---|---|---|---|
| `order_item_id` | `INTEGER` | NOT NULL | Primary key | Order-item code. |
| `order_id` | `INTEGER` | NULL allowed | Foreign key to `customer_order.order_id` | Parent order identifier. |
| `product_id` | `INTEGER` | NULL allowed | Foreign key to `product.product_id` | Product reference sourced from `Order Item Cardprod Id`. |
| `discount_amount` | `NUMERIC(18,9)` | NULL allowed |  | Order-item discount amount. |
| `discount_rate` | `NUMERIC(11,9)` | NULL allowed |  | Order-item discount rate. |
| `unit_product_price` | `NUMERIC(18,9)` | NULL allowed |  | Price of the product without discount. |
| `profit_ratio` | `NUMERIC(11,9)` | NULL allowed |  | Order-item profit ratio. |
| `quantity` | `INTEGER` | NULL allowed |  | Number of products on the item row. |
| `sales_amount` | `NUMERIC(18,9)` | NULL allowed |  | Item-level sales value sourced from `Sales`. |
| `order_item_total` | `NUMERIC(18,9)` | NULL allowed |  | Item total sourced from `Order Item Total`. |

Source mapping: `Order Item Id`, `Order Id`, `Order Item Cardprod Id`,
`Order Item Discount`, `Order Item Discount Rate`, `Order Item Product Price`,
`Order Item Profit Ratio`, `Order Item Quantity`, `Sales`, and
`Order Item Total`.

## 8. Intentionally Excluded Fields

The following source fields are not modeled:

- `Customer Password`
- `Customer City`, `Customer Country`, `Customer State`, `Customer Street`,
  and `Customer Zipcode`
- `Latitude` and `Longitude`
- `Sales per customer`
- `Order Profit Per Order` and `Benefit per order`

These exclusions preserve unresolved business ownership or profit meanings.
No formulas or assumptions were introduced during migration.
