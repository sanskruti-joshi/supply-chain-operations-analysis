# Metric Definitions

## Status and Grain

The source is migrated in an order-item-grain normalized model. Order-level
delivery measures are implemented in `sql/07_delivery_performance.sql`; other
analytical metric queries remain proposed or planned. Delivery findings use
`public.customer_order` without joining `order_item`, so each order is counted
once.

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

For source profiling and data-quality evidence, see [findings_report.md](./findings_report.md). Related interpretation limits are in [assumptions_and_limitations.md](./assumptions_and_limitations.md).
