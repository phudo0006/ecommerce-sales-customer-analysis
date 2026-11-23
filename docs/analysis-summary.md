# Analysis Summary

## Project scope

This project analyses e-commerce transactions from 2019 using SQL Server and Power BI. The submitted report covers sales performance over time, product/category performance, customer segmentation, cohort retention, marketing spend, coupons, and product co-purchases.

**Note on units:** The submitted presentation does not specify a currency. All monetary figures below are therefore expressed in unspecified dataset units.

## Source tables

The project uses the **Marketing Insights for E-Commerce Company** dataset published on Kaggle by `rishikumarrajvansh`: [Kaggle dataset page](https://www.kaggle.com/datasets/rishikumarrajvansh/marketing-insights-for-e-commerce-company). The analysis covers 1 January 2019 to 31 December 2019, as stated in the submitted report.

The five source files are:

1. `Online_Sales.csv` — 52,924 product-level rows.
2. `CustomersData.xlsx` — 1,468 customer records.
3. `Discount_Coupon.csv` — 204 month/category coupon mappings.
4. `Marketing_Spend.csv` — 365 daily marketing-spend records.
5. `Tax_amount.xlsx` — GST rates for 20 product categories.

The raw files are not bundled in this repository. Download them from the Kaggle source page and place them under `data/raw/` before importing. SQL import destinations are specified in the main SQL script and in `data/raw/README.md`. Check the dataset page and current licence/terms before redistributing the raw files or a PBIX that embeds their data.

## Methodology

### 1. Data preparation in SQL Server

The SQL script creates typed clean tables from imported raw tables, converts dates and numeric fields, trims text fields, and builds reusable views. It retains the raw import tables when the clean tables/views are recreated.

### 2. Order-level revenue

The report notes that 1,319 raw `Transaction_ID` values are associated with more than one customer. The project therefore defines a practical composite order key using `CustomerID + Transaction_ID`.

Delivery charges are repeated across product-level rows. To avoid adding the same shipping charge multiple times to an order, the order-level view sums product invoice value and adds the delivery charge once per composite order. This produces the reported order-level revenue of 5.080M dataset units. The equivalent sum using the provided line-level formula is 5.397M because shipping appears on multiple product rows.

### 3. Coupon and tax handling

A coupon discount is applied only where the sales row has `Coupon_Status = 'Used'` and a matching month/product-category coupon mapping exists. The report identifies 126 `Used` rows without a matching mapping. These rows receive a 0% applied discount in the calculation and are flagged for data-quality follow-up. GST is joined by product category.

### 4. Customer analysis

The SQL script creates an RFM segment view using recency, frequency, and monetary values. The report explicitly describes the resulting customer segments as heuristic, not K-Means clusters or a predictive model. The snapshot date used in the RFM calculation is 1 January 2020. Monetary value is historical revenue observed in the supplied dataset, not predicted CLV.

Cohort month is based on each customer's first observed purchase month in the 2019 file. It should not be interpreted as the customer's actual acquisition month.

## Selected findings from the final report

| Finding | Reported value |
|---|---:|
| Order-level revenue (shipping counted once) | 5.080M |
| Line-level invoice sum using supplied formula | 5.397M |
| Composite orders | 26,631 |
| Unique customers | 1,468 |
| Average order value | 190.74 |
| Repeat-customer rate | 91.5% (1,343 of 1,468) |
| Marketing spend | 1.73M |
| Marketing spend / revenue | 34.1% |
| Revenue peak | December, 540K; 2,781 orders |
| Lowest-revenue month | June, 341K; 2,091 orders |
| Nest-USA product invoice value | 2.62M; approximately 54% of product invoice value |
| Premium segment | 297 customers; 48.8% of historical revenue |
| Premium + Gold | 808 customers; 90.6% of historical revenue |
| Nest Cam Indoor + Nest Cam Outdoor | Co-occurred in 651 composite orders |

The presentation also reports 88,383 units sold in the Office category and 16,234 units sold for Maze Pen, the leading individual product by quantity.

## Power BI report pages

- **Overview:** headline performance measures, monthly revenue, category value, gender mix, and monthly KPI table.
- **Customer Segmentation:** RFM segment mix, historical revenue by segment, frequency profile, and customer detail.
- **Product Performance & Discount Analysis:** product quantity/revenue, discount measures, and marketing-related metrics.

## Business implications in the report

- Prioritise retention and loyalty activities for Premium and Gold customers because these segments contribute a large share of observed historical revenue.
- Prepare stock, delivery operations, and campaign planning before the November–December peak period.
- Use the Nest Cam Indoor / Outdoor co-purchase pattern as a hypothesis for a bundle test, then measure AOV and conversion before and after the test.
- Improve data quality by reviewing reused transaction IDs, missing coupon mappings, and the repeated storage of delivery charges.

## Limitations

1. Currency is not specified in the supplied report; values are not labelled USD.
2. Marketing spend/revenue is a descriptive ratio, not marketing ROI.
3. There is no Cost of Goods Sold field, so the project cannot calculate true profit or profit margin.
4. RFM segments are heuristic; there is no K-Means clustering or predictive CLV model.
5. The cohort is based on first observed purchase in the 2019 dataset, not actual customer acquisition.
6. Product co-occurrence does not establish causal bundle uplift.
7. The 126 unmapped `Used` coupon rows require reconciliation; the current calculation applies 0% discount to those rows.

## AI assistance and learning context

ChatGPT was used as a learning and troubleshooting assistant during parts of the work. It supported understanding SQL/Power BI concepts, resolving selected query or coding questions, and improving explanations. This project is presented transparently as a student project completed with AI assistance, rather than as unaided work.
