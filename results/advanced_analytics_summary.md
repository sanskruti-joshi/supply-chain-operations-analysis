# Advanced Customer Analytics Summary

## 1. Analysis Overview

- **Objective:** Assess observed customer purchasing activity, recency, frequency, segmentation, ranking, repeat purchasing, and demand concentration.
- **Scope:** Customer-level descriptive analysis derived from `public.customer`, `public.customer_order`, and `public.order_item`.
- **Data source:** `public.customer`, `public.customer_order`, and `public.order_item` in the `supply_chain_analytics` PostgreSQL database.
- **Analysis grain:** Customer is the customer population; `customer_order` supplies distinct-order counts and dates; `order_item` supplies observed units-purchased totals.
- **SQL script:** `sql/09_advanced_analytics.sql`
- **Execution context:** Findings below are from the executed query outputs for this script.

This analysis describes purchasing activity recorded in the available dataset. It does not establish customer churn, inactivity, loyalty, future retention, or future demand.

## 2. A. Customer Purchasing Profile

The customer purchasing population contains **20,652 customers**.

| Customer measure | Verified result |
|---|---:|
| Customer population | 20,652 |
| Customers with no recorded orders | 0 |
| Customers with observed units | 20,652 |
| Minimum distinct orders per customer | 1 |
| Maximum distinct orders per customer | 15 |
| Average distinct orders per customer | 3.18 |
| Minimum units purchased per customer | 1 |
| Maximum units purchased per customer | 114 |
| Average units purchased per customer | 18.60 |
| Earliest customer order date | 2015-01-01 00:00:00 |
| Latest customer order date | 2018-01-31 23:38:00 |

The order-count distribution is:

| Distinct orders per customer | Customers | Percentage |
|---:|---:|---:|
| 1 | 8,884 | 43.02% |
| 2 | 1,363 | 6.60% |
| 3 | 1,988 | 9.63% |
| 4 | 2,324 | 11.25% |
| 5 | 2,172 | 10.52% |
| 6 | 1,668 | 8.08% |
| 7 | 1,042 | 5.05% |
| 8 | 627 | 3.04% |
| 9 | 325 | 1.57% |
| 10 | 143 | 0.69% |
| 11 | 69 | 0.33% |
| 12 | 28 | 0.14% |
| 13 | 13 | 0.06% |
| 14 | 5 | 0.02% |
| 15 | 1 | 0.00% |

The distribution of units purchased per customer is:

| Statistic | Units |
|---|---:|
| Minimum | 1 |
| First quartile | 1 |
| Median | 14 |
| Third quartile | 32 |
| Maximum | 114 |
| Average | 18.60 |

Customers with one recorded order represent **43.02%** of the population. The median customer purchased 14 units, while the maximum was 114 units.

The A1 `average_units_per_order` metric is defined separately for each customer as observed units divided by that customer's distinct-order count. It is therefore not represented by a population-wide recalculation in this summary.

## 3. B. Customer Recency and Frequency

The recency reference date is **2018-01-31**. Recency is measured relative to this maximum available `customer_order.order_date`, not the current date.

| Purchasing-frequency classification | Customers | Percentage |
|---|---:|---:|
| Low observed purchasing frequency | 8,884 | 43.02% |
| Frequent observed purchasing | 6,093 | 29.50% |
| Recurring observed purchasing | 5,675 | 27.48% |

The recency distribution is:

| Statistic | Days from reference date |
|---|---:|
| Minimum | 0 |
| First quartile | 75 |
| Median | 159 |
| Third quartile | 307 |
| Maximum | 1,125 |

Average days since the most recent recorded order differ by classification:

| Purchasing-frequency classification | Average days since last order | Minimum | Maximum |
|---|---:|---:|---:|
| Low observed purchasing frequency | 96.32 | 0 | 1,125 |
| Frequent observed purchasing | 260.70 | 121 | 864 |
| Recurring observed purchasing | 370.30 | 121 | 1,108 |

The low-frequency group has the lowest average recency value at 96.32 days, but the recency and frequency groups overlap in their underlying ordering patterns. The recurring group is largest by average time from its last observed order at 370.30 days.

No customer with no recorded orders was present in the available output. A no-recorded-order result would require caution and would not itself establish customer churn or inactivity.

## 4. C. Behaviour-Based Customer Segmentation

C1 assigns customers with at least one recorded order across **NTILE(3)** population segments. NTILE segments are relative population groups, not absolute behavioural categories. The `customer_id` tie-breaker may split customers with identical order counts across segments, and adjacent segments may not represent meaningfully different purchasing behaviour.

| Segment | Customers | Percentage | Distinct orders | Units purchased |
|---|---:|---:|---:|---:|
| NTILE segment 1 | 6,884 | 33.33% | 42,046 | 275,026 |
| NTILE segment 2 | 6,884 | 33.33% | 16,822 | 102,169 |
| NTILE segment 3 | 6,884 | 33.33% | 6,884 | 6,884 |
| No recorded orders | 0 | 0.00% | 0 | 0 |

Segment 1 accounts for 275,026 units, or 71.60% of the 384,079 total observed units. Segment 2 accounts for 102,169 units, or 26.60%, and Segment 3 accounts for 6,884 units, or 1.79%. These shares are derived from the segment totals and the reconciled 384,079-unit population.

The segment totals sum to **65,752 distinct orders** and **384,079 units**. Equal order counts can be divided by the deterministic customer tie-breaker, so these labels describe relative position in the customer population rather than fixed frequency classes.

## 5. D. Customer Ranking

The top 25 units-purchased ranking contains the following ordering observations:

| Ranking observation | Verified result |
|---|---:|
| Highest observed units purchased | 114 |
| Second-highest observed units purchased | 111 |
| Third-highest observed units purchased | 110 |
| Fourth-highest observed units purchased | 103 |
| Fifth-highest observed units purchased | 101 |
| Units purchased by customers ranked 1–25 | 2,406 |
| Cumulative share for customers ranked 1–25 | 0.6264% |

The highest-ranked customer purchased **114 units across 13 distinct orders**. The second-ranked customer purchased 111 units across 11 orders, and the third-ranked customer purchased 110 units across 14 orders.

The fifth-ranked position is tied in units at 101, with two customers shown at that units level. Multiple customers also share ranks for order counts and units; `RANK()` allows tied ranks while `ROW_NUMBER()` provides deterministic display order.

The top 25 ranking is not a concentration measure on its own; its 2,406-unit cumulative total equals only 0.6264% of the reconciled unit population.

## 6. E. Repeat-Purchase Analysis

| Purchase group | Customers | Percentage | Distinct orders | Units purchased | Average units per customer |
|---|---:|---:|---:|---:|---:|
| Repeat-order customer | 11,768 | 56.98% | 56,868 | 372,261 | 31.63 |
| One-order customer | 8,884 | 43.02% | 8,884 | 11,818 | 1.33 |
| No recorded order | 0 | 0.00% | 0 | 0 | 0.00 |

The repeat-order group has **56,868 distinct orders** and **372,261 units**, averaging 31.63 units per customer. The one-order group has 8,884 distinct orders and 11,818 units, averaging 1.33 units per customer.

Repeat-order status means only that a customer had more than one distinct recorded order in the available dataset. It does not establish loyalty or future customer retention.

## 7. F. Customer Demand Concentration

The active-customer population contains **20,652 customers** with **384,079 observed units**.

| Concentration measure | Verified result |
|---|---:|
| Top one customer units | 114 |
| Top one customer share | 0.0297% |
| Top 10 customers' share | 0.2690% |
| Top 20% of active customers' share | 52.6623% |
| Active-customer count used for the 20% threshold | 20,652 |
| CEIL(20% of active customers) | 4,131 |

The F1 cumulative-demand milestones are:

| Customer rank milestone | Cumulative units | Cumulative share |
|---:|---:|---:|
| 1 | 114 | 0.0297% |
| 10 | 1,033 | 0.2690% |
| 25 | 2,406 | 0.6264% |
| 100 | 8,628 | 2.2464% |
| 1,000 | 65,287 | 16.9983% |
| 4,131 | 202,265 | 52.6623% |
| 6,884 | 286,886 | 74.6945% |
| 20,652 | 384,079 | 100.0000% |

Observed unit demand is concentrated heavily among a subset of customers. The 4,131 customers representing the top 20% of active customers account for 202,265 units, or 52.6623% of all observed units. The single highest-demand customer accounts for only 0.0297%.

These figures are descriptive of recorded activity. They do not imply causation or predict future demand.

## 8. Data Validation and Reconciliation

| Check | Actual result | Status |
|---|---|---|
| V1 customer population | 20,652 population; 20,652 profiles; 20,652 customers with units; 0 customers without orders; population reconciles = true | **Passed** |
| V2 distinct orders | 65,752 distinct order population; 65,752 summed customer-order counts; maximum 15 orders for one customer; both checks true | **Passed** |
| V3 customer units | 180,519 order items; 384,079 item-population units; 384,079 customer-profile units; units reconcile = true | **Passed** |
| V4 NTILE population | 20,652 segmented; 20,652 customer population; 0 no-order; 6,884 in each NTILE segment; full population reconciles = true | **Passed** |
| V5 repeat groups | 20,652 customer profiles; 11,768 repeat; 8,884 single; 0 no-order; repeat groups reconcile = true | **Passed** |
| V6 active demand | 20,652 active customers; 384,079 active units; 384,079 overall order-item units; final cumulative 384,079; demand reconciles = true | **Passed** |

All six validation checks passed.

## 9. Key Observations

1. **The full customer population has recorded orders:** all 20,652 customers have at least one distinct recorded order.
2. **Purchasing frequency is broadly split:** 43.02% have one order, 56.98% are repeat-order customers, and 29.50% meet the frequent-purchasing threshold.
3. **Units are concentrated in high-frequency segments:** NTILE segment 1 contains 275,026 units, 71.60% of total observed units.
4. **Top-customer demand is not driven by a single outlier:** the top customer contributes 0.0297%, while the top 20% of active customers contribute 52.6623%.
5. **Repeat-purchase customers account for most observed units:** 372,261 of 384,079 units, or 96.92%, come from repeat-order customers.
6. **All major reconciliations match:** customer, order, order-item, NTILE, repeat-group, and cumulative-demand totals reconcile.

## 10. Limitations

- Findings describe recorded purchasing activity only; they do not measure actual customer inactivity or churn.
- Recency uses 2018-01-31, the maximum available order date, rather than the current date.
- Frequency classifications are based on observed distinct-order counts in the available data.
- NTILE segments divide the active-customer population into relative thirds and can separate equal order counts.
- Repeat purchasing does not establish customer loyalty or future retention.
- Demand concentration is descriptive and does not imply causation or predict future demand.
- `average_units_per_order` in A1 is customer-specific; the summary does not replace or silently recompute that output.
