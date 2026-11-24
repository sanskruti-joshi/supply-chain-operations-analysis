# Stage 10 - Query Optimization

## 1. Objective and Environment

- Database: `supply_chain_analytics`
- PostgreSQL version: 18.6
- Purpose: inspect actual execution plans for representative analytical workloads,
  evaluate candidate indexes and query changes, and establish whether any
  optimization was supported by observed evidence.
- No index or query rewrite was implemented. This establishes a performance
  baseline, not a measured optimization improvement.

## 2. B1 - Market Late-Delivery Aggregation

### Measured results

| Measurement | Warm-up | Measured run 1 | Measured run 2 |
|---|---:|---:|---:|
| Planning time | 1.806 ms | 0.075 ms | 0.098 ms |
| Execution time | 91.701 ms | 96.691 ms | 75.632 ms |

### Plan and interpretation

The plan used a sequential scan of `customer_order`, a hashed aggregate, and an
in-memory quicksort. It returned 5 market groups from 65,752 actual input rows.
The planned and actual input row counts both matched 65,752.

| Metric | Observed value |
|---|---:|
| Shared buffer hits | 1,448 |
| Shared buffer reads | 0 |
| Temporary read/written blocks | 0 / 0 |
| Hash-aggregate batches | 1 |
| Hash-aggregate memory | 32 KB |
| Hash/disk usage | No disk usage |

The observed strategy is appropriate because the query reads almost all orders
and produces only five groups. A market or delivery-status index would be
unlikely to outperform the sequential scan and hash aggregate for this workload.

## 3. B2 - Category-Month Demand

### Measured results

The available execution times were approximately 390 ms in one measured plan,
398 ms in another, and 438 ms in a third measured run. The captured planning time was approximately 0.552 ms. Planning-time measurements were not available for every execution.

Values labeled as approximate reflect run-to-run timing variability and the
plan output available for review.

### Verified plan operations

The actual plan contained:

- An inner hash join from `order_item` to `customer_order`
- A left hash join from `order_item` to `product`
- A left hash join from `product` to `category`

It did not contain a `customer_order`-to-`customer_order` join. The join
relationships were:

`order_item.order_id -> customer_order.order_id`

`order_item.product_id -> product.product_id`

`product.category_id -> category.category_id`

The plan then performed:

- A hashed aggregate producing 853 category-month rows
- Window aggregation calculating `LAG(total_units)`
- A sort producing the final month/category result

| Metric | Observed value |
|---|---:|
| `order_item` actual rows | 180,519 |
| `customer_order` actual rows | 65,752 |
| `product` actual rows | 118 |
| `category` actual rows | 51 |
| Hash-join output rows | 180,519 |
| Aggregated and final window rows | 853 |
| Shared buffer hits | Approximately 3,615 |
| Shared buffer reads | 0 |
| Temporary read/written blocks | 0 / 0 |
| Disk hash/sort spills | None observed |

The fact-table population, 180,519 rows, matched estimated and actual counts
exactly. Hash joins and in-memory aggregation were appropriate for this
full-size analytical join and aggregation workload. The window and sort work
processed only 853 aggregated category-month rows.

## 4. B3 - Customer Demand Concentration

### Measured results

| Run | Execution time | Planning time |
|---|---:|---:|
| Warm-up | 360.006 ms | 1.934 ms |
| Measured run 1 | 356.428 ms | 0.489 ms |
| Measured run 2 | 357.161 ms | 0.534 ms |

### Plan and interpretation

The plan used sequential scans of:

- `customer`: 20,652 rows
- `customer_order`: 65,752 rows
- `order_item`: 180,519 rows

It used hash joins, a hashed aggregate producing 20,652 customer rows, window
calculations for cumulative units and row ranking, and sorting before the final
limit returned 25 rows.

| Metric | Observed value |
|---|---:|
| Customer actual rows | 20,652 |
| Customer-order actual rows | 65,752 |
| Order-item actual rows | 180,519 |
| Final result rows | 25 |
| Shared buffer hits | Approximately 3,786 |
| Shared buffer reads | 0 |
| Temporary read/written blocks | 0 / 0 |
| Disk spills | None observed |

The plan must calculate demand and ranking across the active-customer
population before the top 25 can be selected. The hash joins and in-memory
aggregation were consistent with the broad joins and grouping workload.

## 5. Index Investigation

Only primary-key indexes existed. The candidate FK columns had no equivalent
indexes in the database:

| Candidate | Evidence-based conclusion |
|---|---|
| `customer_order(customer_id)` | B3 joined broad customer and order populations using hash joins; no selective point lookup was observed. No additional index was justified for the tested full-population analytical workload. |
| `order_item(order_id)` | B2 and B3 processed nearly all order items through full fact-table joins and aggregation. No selective order lookup was observed. No additional index was justified for the tested full-population analytical workload. |
| `order_item(product_id)` | B2 used full fact-table demand aggregation and hash joins. No selective product lookup was observed. No additional index was justified for the tested full-population analytical workload. |

No candidate index was created. A foreign-key or join column alone does not
justify an index because an additional index can add storage and write overhead
without replacing the observed hash or sequential access strategy.

## 6. Validation Results

| Check | Actual outcome |
|---|---|
| `market_result_matches` | `true` |
| `category_result_matches` | `true` |
| `customer_result_matches` | `true` |
| `missing_existing_indexes` | `0` |
| `missing_existing_constraints` | `0` |
| Exact candidate indexes found | 0 |
| `data_snapshot_differences` | `0` |

The bidirectional `EXCEPT ALL` checks returned matching results for B1, B2 and
B3. The B2 check included `LAG()` prior units, and the B3 check included rank,
cumulative units, cumulative percentage and the top-25 result.

The basic count/key-sum snapshot showed:

| Table | Rows | Primary-key sum |
|---|---:|---:|
| `customer` | 20,652 | 214,786,705 |
| `customer_order` | 65,752 | 2,584,836,326 |
| `order_item` | 180,519 | 16,293,644,940 |
| `product` | 118 | 81,370 |
| `category` | 51 | 2,040 |
| `department` | 11 | 77 |

This snapshot is a basic consistency check only. It does not prove complete
data integrity or validate every row and relationship.

## 7. Conclusion

No additional indexes or query rewrites were justified by the observed plans.
The existing sequential scans, hash joins and in-memory aggregate/window
strategies were retained.

The captured executions establish a baseline for the tested PostgreSQL database
and analytical workloads. They do not establish a performance improvement,
because no optimization was implemented and no before/after improvement was
measured.

These findings apply to the tested database size and query patterns; different workloads or substantially larger datasets may warrant a new performance investigation.
