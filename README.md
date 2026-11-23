# E-commerce Sales & Customer Analysis (2019)

A SQL Server and Power BI data analytics project exploring 2019 e-commerce transactions, customer segments, product performance, discounts, marketing spend, and repeat-purchase patterns.

> **Project context:** This was a hands-on learning project. I used ChatGPT as an AI learning and troubleshooting assistant during parts of the work, including help understanding SQL/Power BI concepts, working through some queries, and improving explanations. I used that assistance as part of my learning process; this repository is not presented as work completed without AI support.

## Project at a glance

- **Period analysed:** 2019
- **Tools:** Microsoft SQL Server, Power BI Desktop
- **Core work:** importing and cleaning multiple source tables, creating SQL views, defining order-level revenue, analysing customer and product performance, and building an interactive Power BI report.
- **Report pages:** Overview; Customer Segmentation; Product Performance & Discount Analysis.
- **Currency:** The source presentation does not specify a currency. Monetary values in this project are therefore described as **dataset units**, not USD or another named currency.

## Repository structure

```text
 ecommerce-sales-customer-analysis/
 ├── data/
 │   └── raw/README.md
 ├── sql/
 │   └── 01_ecommerce_analysis_sqlserver.sql
 ├── powerbi/
 │   └── Final_Project_DOMINHPHU.pbix
 ├── presentation/
 │   └── 03_final_report.pptx
 ├── docs/
 │   └── analysis-summary.md
 ├── .gitignore
 └── README.md
```

## Data sources

The analysis uses the **Marketing Insights for E-Commerce Company** dataset published on Kaggle by `rishikumarrajvansh`:

- **Dataset:** [Marketing Insights for E-Commerce Company — Kaggle](https://www.kaggle.com/datasets/rishikumarrajvansh/marketing-insights-for-e-commerce-company)
- **Platform / publisher:** Kaggle dataset page by `rishikumarrajvansh`
- **Period analysed:** 1 January 2019 – 31 December 2019, as described in the project report.

The project uses the five source files listed below:

| Source file | Description | Reported size |
|---|---|---:|
| `Online_Sales.csv` | Product-level sales transactions, customer/transaction IDs, SKU, price, quantity, coupon status | 52,924 rows |
| `CustomersData.xlsx` | Customer attributes such as gender, location, and tenure | 1,468 customers |
| `Discount_Coupon.csv` | Month and product-category coupon mapping | 204 mappings |
| `Marketing_Spend.csv` | Daily online and offline marketing spend | 365 days |
| `Tax_amount.xlsx` | GST rates by product category | 20 categories |

The five raw source files are **not included** in this repository. Download them from the original [Kaggle dataset page](https://www.kaggle.com/datasets/rishikumarrajvansh/marketing-insights-for-e-commerce-company) and place them locally under `data/raw/` before running the SQL workflow. See [`data/raw/README.md`](data/raw/README.md) for the expected file names and SQL import table names. Check the dataset page and its current licence/terms before redistributing the raw files; this repository links to the source rather than republishing the dataset. **Important:** the `.pbix` file contains an embedded Power BI data model, so it may contain imported rows from those source files. Confirm that the dataset licence/terms permit redistribution before committing the raw files or making a PBIX containing embedded source data public; otherwise keep the repository private or create a PBIX copy with data removed, if appropriate.

## Data preparation and SQL workflow

The SQL script is designed for Microsoft SQL Server and follows this workflow:

1. Create or use the `ecommerce_analysis` database.
2. Import the five source files into the raw tables listed below, keeping the source column headers.
3. Execute the SQL script to build typed/clean tables and analytical views.
4. Run the analysis query blocks (A–P) to inspect data quality and generate metrics used in the report and Power BI model.

Expected raw table names:

- `dbo.Online_Sales_Raw`
- `dbo.CustomersData_Raw`
- `dbo.Discount_Coupon_Raw`
- `dbo.Marketing_Spend_Raw`
- `dbo.Tax_amount_Raw`

**Important execution note:** The script header explains that the database-creation block should be run first, then the five raw tables should be imported, and then the remaining script should be executed. The script drops and recreates the project's clean tables and views when rerun; it intentionally retains the imported `*_Raw` tables. Read the comments at the top of the SQL file before running it.

### Main SQL objects

- `dbo.vw_sales_enriched` — item-level sales enriched with customer, discount-coupon, and tax information.
- `dbo.vw_order_revenue` — order-level aggregation using the composite key `CustomerID + Transaction_ID`.
- `dbo.vw_monthly_performance` — monthly revenue, order/customer counts, discount/tax metrics, delivery charges, and marketing spend.
- `dbo.vw_customer_rfm_segment` — heuristic RFM scores and customer segments.
- `dbo.vw_customer_purchase_gap` — observed gaps between purchase dates, used as a descriptive timing proxy.

## Important business rules

- **Composite order key:** 1,319 raw `Transaction_ID` values were associated with multiple customers in the dataset. The project therefore uses `CustomerID + Transaction_ID` as the practical order key.
- **Shipping counted once:** Delivery charges repeat across product rows. Order-level revenue sums product invoice values and adds the delivery charge once per composite order. The report preserves a separate line-level total for comparison.
- **Coupon mapping:** A discount is applied only when `Coupon_Status = 'Used'` and a matching month/category mapping exists. The report identifies 126 `Used` rows without a mapping; those rows receive 0% applied discount and are flagged for review.
- **Cohort definition:** The first purchase month observed in this 2019 dataset is not necessarily the customer's true acquisition month.
- **Customer segmentation:** RFM is a rule-based/heuristic segmentation built from recency, frequency, and monetary values. It is not K-Means clustering, predictive churn modelling, or predicted customer lifetime value.
- **Profitability:** Cost of Goods Sold is not available, so the project does not claim to calculate true profit or profit margin.

## Key findings reported in the presentation

The figures below are transcribed from the submitted final report. Monetary values are in unspecified dataset units.

| Metric / finding | Reported result |
|---|---:|
| Order-level revenue, with delivery counted once | 5.080M |
| Line-level invoice sum using the supplied row formula | 5.397M |
| Composite orders | 26,631 |
| Unique customers | 1,468 |
| Average order value | 190.74 |
| Repeat-customer rate | 91.5% (1,343 / 1,468 customers) |
| Marketing spend | 1.73M |
| Marketing spend / order-level revenue | 34.1% (descriptive ratio, **not ROI**) |
| Highest-revenue month | December: 540K; 2,781 composite orders |
| Lowest-revenue month | June: 341K; 2,091 composite orders |
| Nest-USA product invoice value | 2.62M, about 54% of product invoice value |
| Premium segment | 297 customers; 48.8% of historical revenue |
| Premium + Gold segments | 808 customers; 90.6% of historical revenue |
| Cross-sell pair | Nest Cam Indoor + Nest Cam Outdoor appeared together in 651 composite orders |

Additional product findings in the presentation: Office recorded 88,383 units sold, while Maze Pen was the top individual product by units sold at 16,234 units.

## Power BI report

The supplied `.pbix` contains three report pages:

1. **Overview** — headline KPIs, monthly revenue, product-category value, customer gender mix, and a monthly performance table.
2. **Customer Segmentation** — RFM segment distribution, historical revenue by segment, frequency mix, and customer-level detail.
3. **Product Performance & Discount Analysis** — quantity/product performance, discount-related analysis, product revenue, and marketing-related measures.

The final presentation (`presentation/03_final_report.pptx`) documents the analysis narrative, selected charts, findings, business implications, and limitations.

## Limitations and interpretation notes

- The source report does not identify the currency, so values are kept in dataset units.
- The 5.080M order-level revenue and 5.397M line-level sum differ because delivery charges repeat across product rows; the order-level KPI counts delivery once.
- Marketing spend divided by revenue is a descriptive spend-to-revenue ratio, not marketing ROI or causal attribution.
- Coupon analysis depends on the available month/category mapping; unmapped `Used` rows are flagged and assigned 0% in the calculation.
- Cohort months refer to first observed purchases in the 2019 file, not confirmed acquisition dates.
- RFM/value bands are heuristic descriptions of observed historical behaviour, not a trained ML model or CLV prediction.
- No Cost of Goods Sold is available, so true profit margin cannot be calculated.
- Co-purchase frequency indicates products appearing in the same composite order; it does not prove that a bundle or promotion will cause incremental sales.

## How AI was used

ChatGPT was used as a support tool during the learning and development process. It helped me work through unfamiliar SQL and Power BI concepts, troubleshoot selected coding/query questions, and refine parts of the analysis and its explanations. I used the assistance to support my own learning and project work. The final SQL workflow, Power BI report, presentation, and interpretation should be read in that context: this is a student learning project developed with AI assistance, not a claim of completely unaided work.

## Files

- [`sql/01_ecommerce_analysis_sqlserver.sql`](sql/01_ecommerce_analysis_sqlserver.sql) — SQL Server database preparation, clean tables, views, and analysis queries.
- [`powerbi/Final_Project_DOMINHPHU.pbix`](powerbi/Final_Project_DOMINHPHU.pbix) — Power BI report and data model.
- [`presentation/03_final_report.pptx`](presentation/03_final_report.pptx) — final project presentation.
- [`docs/analysis-summary.md`](docs/analysis-summary.md) — concise methodology, key findings, and limitations.

---

*Created as a hands-on student project to practise SQL-based data preparation and Power BI business analysis.*
