# Stage 11 - Views and Reusable Metrics

## 1. Objective

Stage 11 defines five regular PostgreSQL views over the established normalized
tables and analytical definitions. The views package delivery, demand-based
ABC, customer purchasing, repeat-purchase, and customer concentration metrics
for reusable reporting. They are views, not materialized views, and no indexes
or automatic refresh behavior were created.

The SQL script is `sql/11_views_and_reusable_metrics.sql`.

## 2. Reusable Views

| View | Grain | Reusable metrics |
|---|---|---|
| `public.vw_delivery_performance_by_mode` | One row per normalized shipping mode | Total orders; late, advance, on-time, canceled, and missing-status counts and percentages; late-delivery rate excluding missing statuses |
| `public.vw_product_demand_abc` | One row per product | Product ID and name, order-item count, units demanded, individual demand contribution, cumulative units and demand contribution, and ABC class |
| `public.vw_customer_purchasing_profile` | One row per customer | Distinct order count, total units purchased, average units per order, most recent order date, and days since the fixed 2018-01-31 reference date |
| `public.vw_customer_repeat_purchase` | One row per customer | Distinct order count, total units purchased, and repeat-purchase classification |
| `public.vw_customer_demand_concentration` | One row per active customer | Units purchased, deterministic customer rank, cumulative units, and cumulative demand percentage |

## 3. Metric Rules

### Delivery performance

The view preserves the Stage 07 order grain and does not join `order_item`.
Missing or blank shipping modes and delivery statuses are represented with
`[Missing or blank]` buckets. Missing delivery statuses are separate and are
excluded from the late-delivery-rate denominator. Canceled orders remain in the
observed status distribution and are not counted as late deliveries.

### Demand-based ABC

The Stage 08 unit-demand rules are preserved:

- A: cumulative demand through 80%
- B: cumulative demand above 80% through 95%
- C: cumulative demand above 95%

Products are ordered by total units descending, then `product_id` ascending.
This is a demand-volume proxy, not conventional inventory-value ABC analysis
and not an actual inventory or stock-priority measure.

### Customer profiles and concentration

Distinct orders are counted from `customer_order`; units are summed from
`order_item.quantity`. Average units per order is customer-level units divided
by that customer's distinct-order count. Recency uses 2018-01-31 as a fixed
historical reference date, not the current date.

Repeat-purchase classifications preserve Stage 09:

- Repeat-order customer: more than one distinct order
- One-order customer: exactly one distinct order
- No recorded order: zero distinct orders

Customer concentration is limited to active customers with quantity-bearing
order items. Customers are ranked by units purchased descending and
`customer_id` ascending to provide deterministic tie-breaking.

## 4. Verified Results

| View or reconciliation | Verified result |
|---|---|
| Shipping-mode view | 4 shipping-mode rows |
| Product ABC view | 118 products; 384,079 units; A = 7, B = 38, C = 73 |
| Customer purchasing profile | 20,652 customers; 65,752 distinct orders; 384,079 units |
| Repeat-purchase view | 11,768 repeat; 8,884 one-order; 0 no-order |
| Customer demand concentration | 20,652 active customers; 384,079 units; final cumulative percentage = 100.0000% |
| Delivery reconciliation | 65,752 orders; 36,048 late; 2,855 canceled; 0 missing statuses |

All six validation sections passed. Every reported reconciliation and ranking
check returned `True`.

The validation coverage confirms view execution, source population counts,
rank and ABC regression counts, customer metric reconciliation, concentration
totals, and delivery-status reconciliation. These checks verify that the views
preserve established Stage 07-09 calculations.

## 5. Limitations

These views expose descriptive historical metrics; they do not establish
causation, predictive accuracy, customer loyalty, future demand, stock-on-hand,
stockouts, replenishment requirements, or inventory value. The fixed recency
date and all ranking, tie-breaking, and classification rules are inherited
from the earlier analytical stages.
