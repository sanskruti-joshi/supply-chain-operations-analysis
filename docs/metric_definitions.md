# Metric Definitions

## Status and Grain

The source is migrated in an order-item-grain normalized model. Order-level
delivery measures are implemented in `sql/07_delivery_performance.sql`.
Sales and profitability metric queries remain subject to unresolved
aggregation and business-meaning decisions. Delivery findings use
`public.customer_order` without joining `order_item`, so each order is counted
once. Demand, customer-purchasing, and customer demand-concentration metrics
are implemented and documented in their respective SQL stages.

| Metric | Proposed definition | Grain | Status / caveat |
|---|---|---|---|
| Total orders | Count distinct nonblank `Order Id`. | Order | The migration resulted in 65,752 customer-order rows. |
| Total order items | Count distinct nonblank `Order Item Id`, after confirming uniqueness. | Order item | The migration resulted in 180,519 order-item rows. |
| Late-delivery rate | `Late delivery` orders divided by orders with nonblank, nonnull delivery status. | Order | Implemented and reported as 54.82% overall (36,048 of 65,752 orders). |
| On-time delivery rate | `Shipping on time` orders divided by orders with nonblank, nonnull delivery status. | Order | Implemented for status reporting; 11,722 orders or 17.83%. |
| Advance-shipping rate | `Advance shipping` orders divided by orders with nonblank, nonnull delivery status. | Order | Implemented for status reporting; 15,127 orders or 23.01%. |
| Average actual shipping days | Average valid `actual_shipping_days` values. | Order | Implemented; 65,752 orders with valid values, average 3.50 days. |
| Average shipping-duration variance | Average of actual shipping days minus scheduled shipping days where both values are valid. Positive values indicate more actual days than scheduled. | Order | Implemented; average difference 0.57 days. |
| Total sales | Sum the selected item-level measure only after choosing between `Sales` and `Order Item Total` and validating its meaning. | Must be selected | Not finalized; `Sales per customer` is described as customer-level and must not be summed once per item row. |
| Total profit | No formula is established. Select and validate a profit measure and its grain before defining an aggregation. | Unresolved | `Order Profit Per Order` and `Benefit per order` are identical on all inspected source rows but vary within many orders; neither is confirmed as an order-level total or item-level profit. Do not aggregate either as profit until its business meaning is established. |
| Average discount | Report either average `Order Item Discount` (currency amount) or average `Order Item Discount Rate` (rate), with the exact field and weighting stated. | Order item | These fields are not interchangeable; decide whether the mean is row-weighted or quantity-weighted. |
| Observed units ordered | Sum `order_item.quantity` for the selected product, category, department, or month population. | Order item, then grouped | Implemented in Stage 08 as a demand proxy; not a stock-on-hand measure. |
| Order-item frequency | Count `order_item.order_item_id` rows for the selected population. | Order item | Distinct from units ordered: a row represents one order item, while `quantity` may contain multiple units. |
| Observed demand contribution | `Group units ordered / Overall units ordered`, expressed as a percentage. | Product, category, department, or month | Implemented for unit-based demand comparisons only; it is not sales or inventory-value contribution. |
| Demand-based ABC class | Classify products by cumulative observed units: A through 80%, B above 80% through 95%, C above 95%. Products are ordered by units descending and `product_id` ascending for ties. | Product | Implemented in Stage 08 as a unit-demand prioritization proxy, not conventional inventory-value ABC analysis. |
| Distinct orders per customer | Count unique orders associated with a customer. | Customer | Implemented in Stage 09; one row per customer. |
| Total units purchased | Sum recorded order-item quantities for a customer. | Customer | Implemented in Stage 09 as observed units, not stock or inventory. |
| Average units per order | Customer's total units purchased divided by that customer's distinct orders. | Customer | Implemented in Stage 09; a zero-order denominator returns no average. |
| Days since most recent order | Difference between the dataset reference date and the customer's latest recorded order date. | Customer | Implemented in Stage 09 using the maximum available order date, not the current date. |
| Purchasing-frequency classification | Classify observed distinct orders as low (1 order), recurring (2–4 orders), or frequent (5 or more orders). | Customer | Implemented in Stage 09 from observed purchase records. |
| NTILE frequency segment | Relative third of the active-customer population, ordered by distinct order count. | Customer | Implemented in Stage 09 with `customer_id` as a deterministic tie-breaker; equal counts may be split, and segments are not absolute behavioural categories. |
| Repeat-order customer | Customer with more than one distinct recorded order. | Customer | Implemented in Stage 09; repeat status does not establish loyalty or future retention. |
| Demand concentration | Share of total observed units accounted for by a ranked customer group. | Customer group | Implemented in Stage 09 as a historical descriptive share, not a predictive or causal measure. |

## Stage 11 Reusable Views

The following regular PostgreSQL views package the established metrics above:

| View | Grain | Metric rules |
|---|---|---|
| `vw_delivery_performance_by_mode` | Shipping mode | Order totals, delivery-status counts, missing/canceled status handling, and late-delivery rates based on the Stage 07 denominator rules |
| `vw_product_demand_abc` | Product | Unit demand, demand contribution, cumulative unit demand, and Stage 08 ABC thresholds of A ≤80%, B >80% through 95%, and C >95%, ordered by units descending and `product_id` ascending |
| `vw_customer_purchasing_profile` | Customer | Distinct orders, total units, average units per order, latest order date, and days since 2018-01-31 |
| `vw_customer_repeat_purchase` | Customer | Repeat if more than one distinct order, one-order if exactly one, and no recorded order if zero |
| `vw_customer_demand_concentration` | Active customer | Units purchased, deterministic rank by units descending and `customer_id` ascending, cumulative units, and cumulative demand percentage |

Stage 11 does not alter business definitions or introduce materialized views,
indexes, or automatic refresh behavior.

For source profiling and data-quality evidence, see [findings_report.md](./findings_report.md). Related interpretation limits are in [assumptions_and_limitations.md](./assumptions_and_limitations.md).
