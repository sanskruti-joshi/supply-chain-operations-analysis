# Findings Report

## Status

This report records implemented project work on the DataCo Smart Supply Chain
dataset. The project has implemented database and staging setup, profiling,
data-quality checks, the six-table normalized schema and first-load migration,
the Stage 07 delivery-performance analysis, and the Stage 08 demand-based
inventory analysis. Stage 09 advanced customer analytics is also implemented.
Stage 10 query optimization is implemented as a baseline investigation.
The sections below distinguish migration verification, profiling, delivery,
historical product-demand, and customer purchasing findings.

## Migration Results

The first migration of `staging.dataco_raw` into the public normalized tables
completed successfully. The verified destination counts were:

| Table | Destination rows |
|---|---:|
| `category` | 51 |
| `department` | 11 |
| `customer` | 20,652 |
| `product` | 118 |
| `customer_order` | 65,752 |
| `order_item` | 180,519 |

The source contained 180,519 staging rows. Source distinct identifier counts
matched the destination row counts for all six entities:

- Category: 51 source category IDs to 51 category rows
- Department: 11 source department IDs to 11 department rows
- Customer: 20,652 source customer IDs to 20,652 customer rows
- Product: 118 source product IDs to 118 product rows
- Customer order: 65,752 source order IDs to 65,752 customer-order rows
- Order item: 180,519 source item IDs to 180,519 order-item rows

Normalization separates repeated customer, product, category, department,
order, and order-item entities while preserving the source grain through
foreign-key relationships. These counts confirm migration cardinality; they
do not, by themselves, establish a business-analysis finding or operational
recommendation.

## Profiling Results

| Check | Result recorded |
|---|---:|
| Source rows | 180,519 |
| Source columns | 53 |
| Distinct order IDs | 65,752 |
| Distinct order-item IDs | 180,519 |
| Distinct customer IDs | 20,652 |
| Distinct product IDs | 118 |
| Duplicate non-empty order-item IDs | 0 |

The inspected important fields had no SQL `NULL` or empty/whitespace values. Inspected numeric values matched the expected numeric syntax, and the inspected date values matched the expected text format. These were focused checks, not a complete semantic validation of every column or calendar date.

## Consistency and Cardinality

- `Customer Id` and `Order Customer Id` matched in all rows checked. No order was associated with multiple distinct customers, and no conflicts were found across the nine inspected order-level attributes.
- No missing or mismatched product identifiers were found between `Order Item Cardprod Id` and `Product Card Id` in the checks recorded. No product/category/department mapping conflicts or missing product categories were found in the inspected mappings.
- The order-cardinality check found 65,752 represented orders, between 1 and 5 item rows per order, and no orders with repeated or missing item IDs.
- Delivery-status counts matched the corresponding `Late_delivery_risk` counts in the checked comparison. This agreement does not independently validate the source's business definition.

These are source-row consistency observations. The implemented schema's
primary and foreign-key constraints and the migration reconciliation provide
the normalized-schema validation in addition to these earlier profiling checks.

## Dates and Numeric Measures

- Initial date profiling reported 65,752 distinct non-empty order-date values and 63,701 distinct non-empty shipping-date values.
- A chronology query initially encountered a parsing issue under the PostgreSQL session's default date style. After explicitly parsing the source format, no nonblank parsed rows showed shipping earlier than ordering. This does not establish that every date is valid or present.
- The inspected quantities were neither negative nor zero; inspected sales and order-item product prices were not negative.
- `Order Item Profit Ratio` ranged from `-2.75` to `0.50`, averaged approximately `0.1206`, and had 33,784 negative, 1,177 zero, and 145,558 positive rows (180,519 total).
- A read-only audit of the local source CSV found that `Order Profit Per Order` and `Benefit per order` contain identical text on all 180,519 rows. Each field has multiple distinct values within 45,902 orders and one distinct value within 19,850 orders. Thus, in this extract they are identical row-level source values, but they are not constant across every order's item rows. This observed pattern does not establish either field's business meaning or economic grain; neither should be treated as an order-level total or summed until those are defined.
- `Order Item Profit Ratio` is a row-level source field, and the profiling SQL explores its distribution alongside profit values. The recorded findings do not establish a validated profit formula or an aggregation rule for the ratio or either profit field.
- Some orders contain multiple item-level profit ratios; order `10004` was an inspected example. Negative ratios have not been classified as errors and no source values were changed or removed.

The order-level variation checks for `Order Profit Per Order` and `Benefit per order` are present in `sql/04_data_quality_checks.sql`, but their execution output is not committed. The section comment calls them “order-level financial measures”; that is a check label, not evidence that either field has order-level business grain. The SQL checks each field's within-order variation separately and do not compare the two columns for equality. `sql/03_data_profiling.sql` checks their numeric syntax and explores profit-ratio values, but does not establish their relationship or aggregation. The counts and row-wise equality above are independently confirmed by a read-only audit of the local CSV; the scripts do not document or persist these result counts.

## Delivery-Performance Findings

The available read-only aggregate outputs from
`public.customer_order` are summarized in
[delivery_performance_summary.md](../results/delivery_performance_summary.md).
The complete `sql/07_delivery_performance.sql` file was executed from beginning
to end successfully.

- The normalized order table contains 65,752 orders.
- Delivery-status counts: 36,048 late (54.82%), 15,127 advance shipping
  (23.01%), 11,722 on time (17.83%), and 2,855 canceled (4.34%).
- Late-delivery rates by shipping mode: First Class 95.27%, Second Class
  76.72%, Same Day 46.15%, and Standard Class 38.13%.
- Markets ranged from 54.13% late in Africa to 55.30% in Pacific Asia.
- The complete available region output showed 57.55% in Central Africa and
  49.51% in Canada, with regional rates sorted and reported in the summary.
- Average actual shipping was 3.50 days versus 2.93 scheduled. The average
  difference was 0.57 actual minus scheduled days.
- Among all 65,752 orders, 37,698 exceeded the schedule, 12,267 matched it,
  and 15,787 beat it.
- The available risk/status cross-tab contained 36,048 risk-1/late orders and
  26,849 risk-0/not-late orders, plus 2,855 risk-0/canceled orders. It showed
  no disagreement categories after canceled and missing statuses were excluded.

These are descriptive associations, not evidence of causation or predictive
accuracy. Missing delivery statuses are excluded from late-rate denominators,
canceled orders are kept separate, and the monthly trend is grouped by
`order_date`.

## Demand-Based Inventory Findings

The Stage 08 demand-based inventory analysis is summarized in
[inventory_analysis_summary.md](../results/inventory_analysis_summary.md).

- The available order-item population contains 180,519 records representing
  384,079 units across 118 products.
- Perfect Fitness Perfect Rip Deck had the highest observed demand at 73,698
  units, or 19.19% of observed units.
- Seven A-class products, representing 5.93% of products, accounted for 78.74%
  of observed units. This classification is based on cumulative unit demand.
- Fan Shop, Golf, and Apparel together accounted for 79.05% of observed units.
- October 2017 showed a substantial decline in recorded demand. Later-period
  data completeness has not been independently established, so this result
  should be interpreted cautiously.

These findings use historical order-item quantities as a proxy for observed
demand. This is not actual inventory analysis and does not establish
stock-on-hand, stockout rates, inventory turnover, days on hand, reorder points,
safety stock, supplier replenishment, or actual inventory optimization. The
ABC classification is unit-demand-based, not a measure of inventory value,
profitability, or stockout risk.

## Query Optimization Findings

The Stage 10 investigation used `EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)` for
the Stage 07 market late-delivery aggregation, Stage 08 category-month demand
analysis, and Stage 09 customer demand-concentration workload.

- B1 used a sequential scan of 65,752 customer orders, a hashed aggregate, and
  an in-memory sort. Captured execution times ranged from 75.632 to 96.691 ms
  across measured runs.
- B2 used an inner hash join from order items to customer orders, left hash
  joins to products and categories, hashed aggregation, a 853-row window
  calculation, and sorting. It did not contain a customer-order-to-customer-
  order join.
- B3 used sequential scans and hash joins across 20,652 customers, 65,752
  customer orders, and 180,519 order items, followed by grouping, window
  calculations and sorting. Captured execution times were approximately
  356–360 ms.

No additional index or query rewrite was implemented. The observed plans used
full fact-table or hash-join strategies with no temporary I/O, and no candidate
index showed sufficient evidence of benefit. All three result-equivalence
checks passed, existing indexes and constraints remained present, and the
basic count/key-sum snapshot had zero differences. The full details are in
[query_optimization_summary.md](../results/query_optimization_summary.md).

## Advanced Customer Analytics

The Stage 09 customer analysis is summarized in
[advanced_analytics_summary.md](../results/advanced_analytics_summary.md).

- The customer population contains 20,652 customers, and all have at least
  one recorded order.
- Repeat-order customers number 11,768, or 56.98% of the population.
- One-order customers number 8,884, or 43.02% of the population.
- The frequent observed purchasing group contains 6,093 customers, or 29.50%
  of the population.
- NTILE segment 1 accounts for 275,026 units, or 71.60% of observed units.
- The top 20% of active customers account for 202,265 units, or 52.6623% of
  observed units.
- All six V1–V6 validation checks passed.

These findings describe recorded customer purchasing activity. NTILE segments
are relative population groups, and repeat purchasing does not establish
loyalty or future retention.

## Interpretation

The checks support treating the source as order-item-grain data and support
the implemented entity relationships as a normalized representation. They do
not establish financial aggregation rules, causal explanations for delivery
outcomes, or supplier and inventory performance.

Profiling and data-quality checks, migration validation, delivery-performance
analysis, and demand-based inventory analysis support descriptive reporting of
orders, delivery outcomes, and historical product demand. Delivery outcomes
vary across shipping modes and geographic regions. Historical product demand is
concentrated among a relatively small number of products and departments.
Financial aggregation rules remain unresolved. The available data cannot assess
actual inventory levels or supplier/replenishment performance. These findings
remain descriptive associations and do not establish causation or predictive
performance.

Metric definitions and their current status are in [metric_definitions.md](./metric_definitions.md). Remaining assumptions and validation work are in [assumptions_and_limitations.md](./assumptions_and_limitations.md).

## Next Work

1. Validate migration evidence against future database snapshots.
2. Resolve financial measure meanings and aggregation rules before reporting financial KPIs.
3. Resolve customer geography and excluded source fields only if a supported business entity or requirement is established.
4. Continue remaining supported sales, reusable-view, and optimization analysis stages.
5. Investigate supplier-related analysis only if additional supplier data or relevant identifiers become available.
6. Add results and recommendations only after relevant queries have been executed and checked.
