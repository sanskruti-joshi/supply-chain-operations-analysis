# Delivery Performance Summary

## 1. Analysis Overview

- **Objective:** Assess delivery outcomes, shipping-mode performance, geographic variation, shipping-duration performance, late-delivery risk alignment, and monthly trends.
- **Scope:** Order-level descriptive analysis of delivery and shipping fields.
- **Data source:** `public.customer_order` in the `supply_chain_analytics` PostgreSQL database.
- **Analysis grain:** One row per order. The `order_item` table was not joined into this analysis, preventing duplicated order counts.
- **SQL script:** `sql/07_delivery_performance.sql`

## 2. Overall Delivery Performance

The total order count is **65,752**.

| Delivery status | Orders | Percentage of all orders |
|---|---:|---:|
| Late delivery | 36,048 | 54.82% |
| Advance shipping | 15,127 | 23.01% |
| Shipping on time | 11,722 | 17.83% |
| Shipping canceled | 2,855 | 4.34% |

- **Overall late-delivery rate:** 54.82%, or 36,048 of 65,752 orders.
- The late-rate denominator uses all orders with a nonmissing delivery status.
- No missing or blank delivery-status values were returned in the available outputs.

## 3. Shipping-Mode Performance

Late-delivery rates below exclude missing delivery statuses from their denominators. Canceled orders remain in the observed status distributions and are not interpreted as caused by a shipping mode.

| Shipping mode | Orders | Late orders | Late-delivery rate |
|---|---:|---:|---:|
| First Class | 10,079 | 9,602 | 95.27% |
| Second Class | 12,778 | 9,803 | 76.72% |
| Same Day | 3,571 | 1,648 | 46.15% |
| Standard Class | 39,324 | 14,995 | 38.13% |

- First Class has the highest observed late-delivery rate at **95.27%** across 10,079 orders.
- Standard Class has the lowest reported late-delivery rate at **38.13%**, although it is the largest shipping-mode volume at 39,324 orders.
- Same Day sits at **46.15%**, compared with **76.72%** for Second Class.
- These differences describe observed association only; they do not establish that a shipping mode caused a delivery outcome.

## 4. Geographical Delivery Performance

### Market performance

| Market | Orders | Late orders | Late-delivery rate |
|---|---:|---:|---:|
| Pacific Asia | 17,577 | 9,720 | 55.30% |
| Europe | 18,561 | 10,199 | 54.95% |
| USCA | 8,579 | 4,704 | 54.83% |
| LATAM | 17,181 | 9,339 | 54.36% |
| Africa | 3,854 | 2,086 | 54.13% |

- Pacific Asia has the highest market late-delivery rate at **55.30%**.
- Africa has the lowest at **54.13%**.
- The market rates form a narrow range of **1.17 percentage points**.
- Missing market values were not returned in the available outputs and therefore require no separate missing-market count.

### Region performance

| Region | Orders | Late orders | Late-delivery rate |
|---|---:|---:|---:|
| Central Africa | 556 | 320 | 57.55% |
| East Africa | 613 | 348 | 56.77% |
| South of USA | 1,345 | 753 | 55.99% |
| West Asia | 2,022 | 1,132 | 55.98% |
| Eastern Europe | 1,292 | 723 | 55.96% |
| South Asia | 3,335 | 1,865 | 55.92% |
| Western Europe | 10,010 | 5,585 | 55.79% |
| Southeast Asia | 4,356 | 2,421 | 55.58% |
| Central Asia | 184 | 102 | 55.43% |
| US Center | 1,935 | 1,071 | 55.35% |
| East of USA | 2,323 | 1,276 | 54.93% |
| Central America | 9,396 | 5,156 | 54.87% |
| Eastern Asia | 3,318 | 1,818 | 54.79% |
| Oceania | 4,362 | 2,382 | 54.61% |
| West of USA | 2,667 | 1,451 | 54.41% |
| North Africa | 1,064 | 578 | 54.32% |
| South America | 4,979 | 2,696 | 54.15% |
| Southern Africa | 398 | 214 | 53.77% |
| Northern Europe | 3,716 | 1,996 | 53.71% |
| Southern Europe | 3,543 | 1,895 | 53.49% |
| Caribbean | 2,806 | 1,487 | 52.99% |
| West Africa | 1,223 | 626 | 51.19% |
| Canada | 309 | 153 | 49.51% |

- Across the complete available region output, Central Africa has the highest reported region rate at **57.55%**.
- Across the complete available region output, Canada has the lowest at **49.51%**, but it represents only 309 orders.
- West Africa is at **51.19%** across 1,223 orders.
- Missing region values were not returned in the available outputs.

Regional percentages are more sensitive to small volumes than market percentages. Small regions such as Canada and Central Africa should be interpreted cautiously.

## 5. Actual vs Scheduled Shipping Time

- **Orders with valid actual and scheduled shipping days:** 65,752
- **Average actual shipping days:** 3.50
- **Average scheduled shipping days:** 2.93
- **Average difference:** 0.57 actual days minus scheduled days
- **Interpretation:** Positive difference means actual shipping took longer than scheduled.

| Comparison | Orders | Percentage of all orders |
|---|---:|---:|
| Actual exceeded schedule | 37,698 | 57.33% |
| Actual matched schedule | 12,267 | 18.66% |
| Actual beat schedule | 15,787 | 24.01% |
| Missing timing comparison | 0 | 0.00% |

- On average, actual shipping took **0.57 days longer** than scheduled.
- Most orders, **37,698 or 57.33%**, took longer than scheduled.
- **12,267 orders or 18.66%** matched the scheduled duration.
- **15,787 orders or 24.01%** shipped in fewer than the scheduled days.

## 6. Late-Delivery Risk Assessment

`late_delivery_risk` is compared with observed `delivery_status` to assess indicator alignment, not to measure predictive accuracy or model performance.

| Risk indicator | Observed status | Orders | Percentage of all orders |
|---|---|---:|---:|
| Risk 0, not flagged | Not late delivery | 26,849 | 40.83% |
| Risk 0, not flagged | Shipping canceled | 2,855 | 4.34% |
| Risk 1, flagged | Late delivery | 36,048 | 54.82% |

- No other risk/status combinations were returned.
- No missing or blank delivery statuses were present in the available outputs.
- No missing or unexpected `late_delivery_risk` values appeared in the available cross-tab.

The disagreement analysis, which excludes shipping-canceled and missing-status orders, returned **no disagreement categories**

Canceled orders are retained as a separate status rather than classified as a risk/status disagreement.

## 7. Monthly Delivery Trend

Months are based on `order_date`, not shipping or delivery date.

The complete monthly output available in the workspace is summarized below.

| Order month | Orders | Late orders | Late-delivery rate |
|---|---:|---:|---:|
| 2015-01 | 1,787 | 963 | 53.89% |
| 2015-02 | 1,585 | 871 | 54.95% |
| 2015-03 | 1,781 | 978 | 54.91% |
| 2015-04 | 1,710 | 927 | 54.21% |
| 2015-05 | 1,776 | 969 | 54.56% |
| 2015-06 | 1,725 | 941 | 54.55% |
| 2015-07 | 1,763 | 963 | 54.62% |
| 2015-08 | 1,762 | 966 | 54.82% |
| 2015-09 | 1,706 | 951 | 55.74% |
| 2015-10 | 1,775 | 973 | 54.82% |
| 2015-11 | 1,729 | 941 | 54.42% |
| 2015-12 | 1,805 | 988 | 54.74% |
| 2016-01 | 1,772 | 998 | 56.32% |
| 2016-02 | 1,650 | 893 | 54.12% |
| 2016-03 | 1,764 | 987 | 55.95% |
| 2016-04 | 1,706 | 925 | 54.22% |
| 2016-05 | 1,763 | 971 | 55.08% |
| 2016-06 | 1,690 | 968 | 57.28% |
| 2016-07 | 1,758 | 922 | 52.45% |
| 2016-08 | 1,766 | 983 | 55.66% |
| 2016-09 | 1,730 | 949 | 54.86% |
| 2016-10 | 1,776 | 976 | 54.95% |
| 2016-11 | 1,721 | 935 | 54.33% |
| 2016-12 | 1,763 | 990 | 56.15% |
| 2017-01 | 1,745 | 940 | 53.87% |
| 2017-02 | 1,614 | 879 | 54.46% |
| 2017-03 | 1,782 | 984 | 55.22% |
| 2017-04 | 1,739 | 917 | 52.73% |
| 2017-05 | 1,763 | 965 | 54.74% |
| 2017-06 | 1,676 | 911 | 54.36% |
| 2017-07 | 1,776 | 966 | 54.39% |
| 2017-08 | 1,768 | 981 | 55.49% |
| 2017-09 | 1,723 | 941 | 54.61% |
| 2017-10 | 2,101 | 1,137 | 54.12% |
| 2017-11 | 2,055 | 1,132 | 55.09% |
| 2017-12 | 2,124 | 1,172 | 55.18% |
| 2018-01 | 2,123 | 1,195 | 56.29% |

- Observed monthly late-delivery rates ranged from **52.45%** in 2016-07 to **57.28%** in 2016-06.
- No monthly missing-date group was returned.

These month-to-month differences are descriptive. They do not establish seasonality or a causal effect of calendar month on delivery outcomes.

## 8. Key Business Findings

1. **Late delivery is the largest observed status:** 36,048 orders, or 54.82%, were late.
2. **First Class has the highest observed late-delivery rate:** 95.27% across 10,079 orders, compared with 38.13% for Standard Class across 39,324 orders.
3. **Geographic rates vary only moderately at market level:** Pacific Asia is highest at 55.30%, while Africa is lowest at 54.13%.
4. **Actual shipping time is longer on average:** actual shipping averages 3.50 days versus 2.93 scheduled, and 57.33% of orders exceed the scheduled duration.
5. **The available risk/status observations show alignment, not proven predictive performance:** every reported risk-1 record was observed as late, and every reported risk-0 record was observed as not late or canceled. Canceled and missing statuses are handled separately.

## 9. Limitations

- This is descriptive analysis; it does not establish causation or the reasons for delivery variation.
- `late_delivery_risk` is an indicator and has been used to compare observed outcomes, not to assert predictive-model performance.
- Missing delivery statuses are excluded from the late-delivery-rate denominators.
- Canceled orders are separated from risk/status disagreement classifications and are not counted as late deliveries.
- Market and region outputs describe association across existing groups and do not control for shipping mode, order volume, or other factors.
- Monthly rates are grouped by `order_date`; they may differ from trends based on shipping date or delivery date.
- Relative comparisons should account for order volume, especially for low-volume regions.
- The source documentation states that coverage, representativeness, and exact delivery-denominator rules require further validation.
