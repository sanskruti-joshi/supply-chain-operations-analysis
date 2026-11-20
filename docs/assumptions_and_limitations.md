# Assumptions and Limitations

## Working Assumptions

- `staging.dataco_raw` represents the source CSV at order-item grain: multiple rows may belong to one order.
- The raw staging table retains source values as text to preserve their original representation during profiling.
- Repeated customer, product, category, and department identifiers in staging are expected; uniqueness is assessed within each implemented entity rather than across the denormalized rows.
- The implemented normalized schema preserves the source mapping documented in
  `docs/source_to_entity_mapping.md`. Primary and foreign keys follow
  `sql/05_schema_and_constraints.sql`.
- The migration is a first-load process. Existing destination rows block
  rerunning `sql/06_data_migration.sql`; no truncate, delete, or overwrite
  reload mechanism is implemented.
- A query returning no matching rows only supports the condition tested. It does not establish complete integrity or correctness.
- The source glossary is descriptive metadata, not independent proof of a field's business meaning.

## Limitations

- The dataset's coverage period, completeness, and representativeness have not been independently established.
- Available fields may show an association with delivery outcomes but do not explain the causes of delays.
- Supplier identifiers and inventory/replenishment history are not established in the current dataset; supplier-performance and inventory-risk conclusions are therefore out of scope without additional data.
- Stage 08 inventory analysis uses historical order-item quantity and order activity as a demand proxy. The dataset does not provide verified stock-on-hand snapshots, warehouse stock levels, stockout history, supplier replenishment records, or inventory transaction history.
- Customer-related fields exist in the source. Keep raw data and query results private; do not publish customer values or commit derived exports without an appropriate review.
- In the inspected source CSV, `Order Profit Per Order` and `Benefit per order` are identical on every row, and both vary within many orders. They are not confirmed order-level measures, nor is either confirmed to be item-level profit. Their business meaning and valid aggregation remain unresolved; do not model or aggregate either as profit until defined.
- The exact business definitions and aggregation rules for sales, discounts, profit, and delivery denominators remain subject to validation.
- Delivery status rates in `sql/07_delivery_performance.sql` classify
  `Late delivery` case-insensitively, report canceled and missing statuses
  separately, and exclude missing delivery statuses from late-rate denominators.
- Shipping-duration differences are calculated as actual shipping days minus
  scheduled shipping days; positive values mean actual shipping took longer.
- Recency in Stage 09 uses 2018-01-31, the maximum available
  `customer_order.order_date`, as the dataset reference date. It is not based
  on the current date.
- Stage 09 purchasing-frequency classifications use fixed thresholds based on
  observed distinct orders: low means 1 order, recurring means 2–4 orders,
  and frequent means 5 or more orders.
- NTILE frequency segmentation divides active customers into relative
  population thirds. It does not create absolute behavioural categories,
  and customers with equal order counts may be split across segments.
- Repeat purchasing does not establish customer loyalty or predict future
  retention.
- No recorded orders would not independently establish customer churn or
  inactivity. In the available Stage 09 dataset, all 20,652 customers have
  at least one recorded order.
- Stage 09 demand concentration describes historical recorded units. It does
  not predict future demand.

## Validation Still Required

- Confirm future migration batches with primary-key uniqueness and non-nullness for each implemented entity.
- Validate foreign-key relationships for every future migration batch.
- Revalidate the order-item product identifier mapping when future source batches are loaded.
- Choose defensible aggregation rules for financial and delivery measures.
- Resolve whether either duplicate profit field has a defined business meaning or valid grain before including it in the normalized model or reporting profit. The source-row values alone do not establish that decision.
- Preserve the implemented PostgreSQL types until a separately reviewed schema
  change establishes a need for different precision or constraints.
- Design and approve a reload/merge process before rerunning migration for a
  new or changed source batch.

Reported profiling and consistency-check results are collected in [findings_report.md](./findings_report.md), rather than repeated here or in the ER diagram.
