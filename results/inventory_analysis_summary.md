# Inventory Analysis Summary

## 1. Analysis Overview

- **Objective:** Analyze observed product demand to support demand-based inventory planning, without asserting actual inventory availability or risk.
- **Scope:** Order-item quantity, order frequency, product attributes, category and department demand, monthly demand patterns, and demand concentration.
- **Data source:** `public.order_item`, `public.customer_order`, `public.product`, `public.category`, and `public.department` in the `supply_chain_analytics` PostgreSQL database.
- **Analysis grain:** One row per order item for units and order-item frequency. Product, category, department, and month aggregations are derived from those item rows.
- **SQL script:** `sql/08_inventory_analysis.sql`
- **Execution context:** Verified from read-only queries against the successfully executed Stage 08 database outputs.
- **Sales interpretation:** `sales_amount` is retained as an item-level observed sales measure only. It is not profit.

This analysis is based on historical order activity as a demand proxy. It does not establish stock-on-hand, stockouts, replenishment, inventory turnover, reorder points, safety stock, or inventory valuation.

## 2. Overall Product Demand

The complete order-item population contains **180,519 order items**, covering **118 distinct products**.

| Metric | Verified result |
|---|---:|
| Total order-item records | 180,519 |
| Distinct products with observed demand | 118 |
| Total units ordered | 384,079 |
| Missing quantities | 0 |
| Nonpositive quantities | 0 |
| Observed sales amount | 36,784,735.01 |
| Average units per order item | 2.13 |

The quantity distribution is:

| Units on one order item | Order-item records | Percentage of records | Total units |
|---:|---:|---:|---:|
| 1 | 99,134 | 54.92% | 99,134 |
| 2 | 20,315 | 11.25% | 40,630 |
| 3 | 20,350 | 11.27% | 61,050 |
| 4 | 20,335 | 11.26% | 81,340 |
| 5 | 20,385 | 11.29% | 101,925 |

Single-unit rows account for most order-item records, while five-unit rows account for the largest quantity subtotal among the displayed quantities.

## 3. Product-Level Demand Findings

The 118-product population has no zero-demand products; every product has at least one order item. The lowest observed product demand is **10 units**.

| Rank | Product | Category | Order-item records | Distinct orders | Units ordered | Observed sales |
|---:|---|---|---:|---:|---:|---:|
| 1 | Perfect Fitness Perfect Rip Deck | Cleats | 24,515 | 20,359 | 73,698 | 4,421,143.14 |
| 2 | Nike Men's Dri-FIT Victory Golf Polo | Women's Apparel | 21,035 | 17,869 | 62,956 | 3,147,800.00 |
| 3 | O'Brien Men's Neoprene Life Vest | Indoor/Outdoor Games | 19,298 | 16,623 | 57,803 | 2,888,993.91 |
| 4 | Nike Men's Free 5.0+ Running Shoe | Cardio Equipment | 12,169 | 11,092 | 36,680 | 3,667,633.20 |
| 5 | Under Armour Girls' Toddler Spine Surge Runni... | Shop By Sport | 10,617 | 9,825 | 31,735 | 1,269,082.67 |

Perfect Fitness Perfect Rip Deck is the clear highest-demand product: **73,698 units** across **24,515 order-item records** and **20,359 distinct orders**. Its units represent **19.19%** of total observed units.

Order-item frequency and units ordered are distinct measures. An order-item record represents one line, while its quantity may contain multiple units. Consequently, a product's order-item count should not be interpreted as its total unit demand.

Product names and ranks are reported as observed in the normalized dataset.

## 4. Category and Department Demand

### Category demand

| Category | Order-item records | Units ordered | Share of units | Observed sales |
|---|---:|---:|---:|---:|
| Cleats | 24,551 | 73,734 | 19.20% | 4,431,942.78 |
| Women's Apparel | 21,035 | 62,956 | 16.39% | 3,147,800.00 |
| Indoor/Outdoor Games | 19,298 | 57,803 | 15.05% | 2,888,993.91 |
| Cardio Equipment | 12,487 | 37,587 | 9.79% | 3,694,843.20 |
| Shop By Sport | 10,984 | 32,726 | 8.52% | 1,309,522.04 |

The lowest-demand category shown is **Golf Bags & Carts**, with **61 units** across 61 order-item records and observed sales of **10,369.39**. The five largest categories above account for **68.95%** of observed units.

Fishing is notable for sales concentration despite lower unit volume: it generated **6,929,653.69** in observed sales across 17,325 units.

### Department demand

| Department | Order-item records | Units ordered | Share of units | Observed sales |
|---|---:|---:|---:|---:|
| Fan Shop | 66,861 | 106,165 | 27.64% | 17,113,870.94 |
| Golf | 33,220 | 99,297 | 25.85% | 4,609,028.24 |
| Apparel | 48,998 | 98,181 | 25.56% | 7,976,255.34 |
| Footwear | 14,525 | 43,400 | 11.30% | 4,006,498.77 |
| Outdoors | 9,686 | 26,059 | 6.78% | 1,253,351.45 |

Fan Shop is the largest observed department by units, at **27.64%** of total demand. Golf and Apparel follow closely at 25.85% and 25.56%, respectively. Health and Beauty is the smallest department at **362 units**, or **0.09%** of observed demand.

## 5. Monthly Demand Trends

Monthly demand is grouped by `customer_order.order_date`. Missing dates are retained as a separate result in the reconciliation, but no missing-date order items were returned.

The largest monthly unit total is **12,062** in **2015-03**. The smallest listed month is **2,055** in **2017-11**.

The largest observed month-to-month unit change in the overall trend is:

| Month | Units | Previous observed month | Unit change | Percentage change |
|---|---:|---:|---:|---:|
| 2017-10 | 2,490 | 10,502 | -8,012 | -76.29% |

This result should be interpreted cautiously. The surrounding 2017 monthly totals also fall sharply from the earlier part of the dataset, and coverage in the available extract may not represent a complete calendar period.

Category-month changes vary materially. The largest absolute changes versus the prior observed month include:

| Category | Month | Units | Previous month | Change | Percentage change |
|---|---|---:|---:|---:|---:|
| Cleats | 2017-10 | 120 | 2,108 | -1,988 | -94.31% |
| Women's Apparel | 2017-10 | 78 | 1,969 | -1,891 | -96.04% |
| Indoor/Outdoor Games | 2017-10 | 68 | 1,609 | -1,541 | -95.77% |
| Cardio Equipment | 2017-10 | 64 | 1,097 | -1,033 | -94.17% |
| Shop By Sport | 2017-10 | 25 | 994 | -969 | -97.48% |

The comparison uses consecutive available category-month observations, not an asserted complete sequence of calendar months. It does not interpolate missing periods and does not establish seasonality.

## 6. Demand-Based ABC Classification

The ABC output uses a demand-based unit-volume proxy:

- **A:** cumulative observed units through 80%.
- **B:** cumulative observed units above 80% through 95%.
- **C:** cumulative observed units above 95%.
- Products are ordered by total units descending, then product ID ascending to handle deterministic ties.

| ABC class | Products | Share of products | Units contributed | Share of units |
|---|---:|---:|---:|---:|
| A | 7 | 5.93% | 302,443 | 78.74% |
| B | 38 | 32.20% | 61,692 | 16.06% |
| C | 73 | 61.86% | 19,944 | 5.19% |

The highest cumulative-demand products are:

| Product | Units | Cumulative units | Cumulative share | Class |
|---|---:|---:|---:|---|
| Perfect Fitness Perfect Rip Deck | 73,698 | 73,698 | 19.1882% | A |
| Nike Men's Dri-FIT Victory Golf Polo | 62,956 | 136,654 | 35.5797% | A |
| O'Brien Men's Neoprene Life Vest | 57,803 | 194,457 | 50.6294% | A |
| Nike Men's Free 5.0+ Running Shoe | 36,680 | 231,137 | 60.1795% | A |
| Under Armour Girls' Toddler Spine Surge Runni... | 31,735 | 262,872 | 68.4422% | A |
| Nike Men's CJ Elite 2 TD Football Cleat | 22,246 | 285,118 | 74.2342% | A |
| Field & Stream Sportsman 16 Gun Fire Safe | 17,325 | 302,443 | 78.7450% | A |

The first B-class product, Pelican Sunstream 100 Kayak, raises cumulative demand to **82.7806%**.

This is not conventional inventory-value ABC analysis. It prioritizes observed unit demand and should not be interpreted as stock priority or actual inventory criticality.

## 7. Data Validation and Reconciliation

| Check | Result |
|---|---|
| V1 order-item population | 180,519 records; 180,519 quantities present; 384,079 units |
| V2 product reconciliation | 180,519 item records and 384,079 units reconcile between item-level and product-level aggregation |
| V3 product relationships | 0 missing products, 0 missing categories, and 0 missing departments |
| V3 relationship units | 384,079 units have category and department relationships |
| V4 monthly units | 384,079 dated units; 0 missing-date units; reconciliation true |
| V4 monthly records | 180,519 dated records; 0 missing-date records; reconciliation true |
| V5 ABC population | 118 of 118 products classified |
| V5 ABC units | 384,079 classified units reconcile to 384,079 overall units |
| V5 cumulative final unit total | 384,079 |

No failed reconciliation or missing relationship was observed. Missing quantities and nonpositive quantities were both zero.

## 8. Key Business Findings

1. **Demand is concentrated in a small number of products:** 7 A-class products, or 5.93% of products, represent 78.74% of observed units.
2. **Perfect Fitness Perfect Rip Deck is the leading product:** 73,698 units across 24,515 order-item records and 20,359 distinct orders.
3. **Category demand is concentrated:** Cleats, Women's Apparel, and Indoor/Outdoor Games contribute 50.64% of observed units collectively.
4. **Three departments dominate unit demand:** Fan Shop, Golf, and Apparel contribute 79.05% of observed units combined.
5. **The 2017-10 overall decline is abrupt:** observed units fall by 8,012, or 76.29%, from the previous month, and should not be interpreted as normal seasonality.
6. **The complete observed population is relationship-complete:** no missing product, category, department, quantity, or order-date values were found in the reconciliation checks.

## 9. Assumptions and Limitations

- The dataset provides historical order activity, not verified stock-on-hand or inventory transaction data.
- `quantity` is treated as the units-demand measure. `sales_amount` is not treated as profit or inventory value.
- The ABC output is a demand-volume Pareto classification, not a conventional inventory-value or risk-based ABC analysis.
- A product can appear across multiple order items and orders; order-item counts and distinct-order counts are not interchangeable with units.
- Month-over-month category comparisons use consecutive available observations and do not fill missing category-month periods.
- Descriptive monthly changes do not establish seasonality or causation.
- Low-demand products are reported descriptively and are not classified as obsolete or unnecessary.
- Coverage completeness for later periods was not independently established.
- No inventory-level recommendation can be made without stock, supplier, replenishment, or stockout data.
