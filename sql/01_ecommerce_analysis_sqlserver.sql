/*
PROJECT: E-commerce Sales & Customer Analysis (2019)

WORKFLOW
1) Execute ONLY the database-creation block at the top first.
2) Download the five source files from the Kaggle dataset linked in README.md. Import the CSV/XLSX source files into database ecommerce_analysis using the appropriate SSMS import options.
   Use these destination table names exactly:
      Online_Sales_Raw, CustomersData_Raw, Discount_Coupon_Raw,
      Marketing_Spend_Raw, Tax_amount_Raw
   Keep CSV headers as column names. SSMS may infer numeric/date types; this script converts them.
3) Execute the rest of this file (or the entire file after importing).

DATA HANDLING NOTES
- Order key is CustomerID + Transaction_ID because 1,319 raw Transaction_ID values map to multiple customers.
- Coupon discounts apply only for Coupon_Status='Used' and a matching Month + Product_Category coupon.
- Delivery charges repeat across product rows, so order-level revenue counts shipping once per composite order.
- Cohort month is the first observed month in this 2019 file, not necessarily true acquisition month.
- Cost of goods sold is unavailable, so true profit/margin cannot be calculated reliably.

SAFE TO RE-RUN: This script resets the clean project tables/views but does not delete the *_Raw imported tables.
*/

/* STEP 1: Run this block first, then import the 5 source files (CSV/XLSX) into the new database. */
IF DB_ID(N'ecommerce_analysis') IS NULL
BEGIN
    CREATE DATABASE ecommerce_analysis;
END;
GO
USE ecommerce_analysis;
GO

/* STEP 2: Verify all raw import tables exist before continuing. */
IF OBJECT_ID(N'dbo.Online_Sales_Raw', N'U') IS NULL
 OR OBJECT_ID(N'dbo.CustomersData_Raw', N'U') IS NULL
 OR OBJECT_ID(N'dbo.Discount_Coupon_Raw', N'U') IS NULL
 OR OBJECT_ID(N'dbo.Marketing_Spend_Raw', N'U') IS NULL
 OR OBJECT_ID(N'dbo.Tax_amount_Raw', N'U') IS NULL
BEGIN
    THROW 50001, 'One or more raw tables are missing. Import all five source files first, using the exact table names in the script header.', 1;
END;
GO

/* Reset project views and clean tables; raw imports are retained. */
DROP VIEW IF EXISTS dbo.vw_customer_purchase_gap;
DROP VIEW IF EXISTS dbo.vw_customer_rfm_segment;
DROP VIEW IF EXISTS dbo.vw_monthly_performance;
DROP VIEW IF EXISTS dbo.vw_order_revenue;
DROP VIEW IF EXISTS dbo.vw_sales_enriched;
GO
DROP TABLE IF EXISTS dbo.online_sales;
DROP TABLE IF EXISTS dbo.customer_data;
DROP TABLE IF EXISTS dbo.discount_coupon;
DROP TABLE IF EXISTS dbo.marketing_spend;
DROP TABLE IF EXISTS dbo.tax_amount;
GO

/* Create normalized clean tables */
CREATE TABLE dbo.online_sales (
    sale_row_id BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    customer_id BIGINT NOT NULL,
    transaction_id BIGINT NOT NULL,
    transaction_date DATE NOT NULL,
    product_sku VARCHAR(40) NOT NULL,
    product_description NVARCHAR(255) NULL,
    product_category NVARCHAR(100) NOT NULL,
    quantity INT NOT NULL,
    avg_price DECIMAL(12,4) NOT NULL,
    delivery_charges DECIMAL(12,4) NOT NULL CONSTRAINT DF_online_sales_delivery DEFAULT (0),
    coupon_status VARCHAR(20) NULL
);
CREATE INDEX IX_online_sales_customer_date ON dbo.online_sales(customer_id, transaction_date);
CREATE INDEX IX_online_sales_transaction ON dbo.online_sales(transaction_id);
CREATE INDEX IX_online_sales_category ON dbo.online_sales(product_category);
CREATE INDEX IX_online_sales_date ON dbo.online_sales(transaction_date);

CREATE TABLE dbo.customer_data (
    customer_id BIGINT NOT NULL PRIMARY KEY,
    gender VARCHAR(10) NULL,
    location NVARCHAR(100) NULL,
    tenure_months INT NULL
);

CREATE TABLE dbo.discount_coupon (
    coupon_id BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    coupon_month VARCHAR(3) NOT NULL,
    product_category NVARCHAR(100) NOT NULL,
    coupon_code VARCHAR(50) NULL,
    discount_pct DECIMAL(5,2) NOT NULL,
    CONSTRAINT UQ_discount_coupon_month_category UNIQUE (coupon_month, product_category)
);

CREATE TABLE dbo.marketing_spend (
    spend_date DATE NOT NULL PRIMARY KEY,
    offline_spend DECIMAL(14,2) NOT NULL CONSTRAINT DF_marketing_offline DEFAULT (0),
    online_spend DECIMAL(14,2) NOT NULL CONSTRAINT DF_marketing_online DEFAULT (0)
);

CREATE TABLE dbo.tax_amount (
    product_category NVARCHAR(100) NOT NULL PRIMARY KEY,
    gst DECIMAL(6,4) NOT NULL
);
GO

/* Convert imported CSV tables to typed, clean tables. */
INSERT INTO dbo.online_sales
    (customer_id, transaction_id, transaction_date, product_sku, product_description,
     product_category, quantity, avg_price, delivery_charges, coupon_status)
SELECT
    TRY_CONVERT(BIGINT, CustomerID),
    TRY_CONVERT(BIGINT, Transaction_ID),
    TRY_CONVERT(DATE, Transaction_Date, 101),
    LTRIM(RTRIM(CONVERT(VARCHAR(40), Product_SKU))),
    NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(255), Product_Description))), N''),
    LTRIM(RTRIM(CONVERT(NVARCHAR(100), Product_Category))),
    TRY_CONVERT(INT, Quantity),
    TRY_CONVERT(DECIMAL(12,4), Avg_Price),
    COALESCE(TRY_CONVERT(DECIMAL(12,4), Delivery_Charges), 0),
    NULLIF(LTRIM(RTRIM(CONVERT(VARCHAR(20), Coupon_Status))), '')
FROM dbo.Online_Sales_Raw;

INSERT INTO dbo.customer_data (customer_id, gender, location, tenure_months)
SELECT
    TRY_CONVERT(BIGINT, CustomerID),
    NULLIF(LTRIM(RTRIM(CONVERT(VARCHAR(10), Gender))), ''),
    NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), Location))), N''),
    TRY_CONVERT(INT, Tenure_Months)
FROM dbo.CustomersData_Raw;

INSERT INTO dbo.discount_coupon (coupon_month, product_category, coupon_code, discount_pct)
SELECT
    LEFT(LTRIM(RTRIM(CONVERT(VARCHAR(20), [Month]))), 3),
    LTRIM(RTRIM(CONVERT(NVARCHAR(100), Product_Category))),
    NULLIF(LTRIM(RTRIM(CONVERT(VARCHAR(50), Coupon_Code))), ''),
    TRY_CONVERT(DECIMAL(5,2), Discount_pct)
FROM dbo.Discount_Coupon_Raw;

INSERT INTO dbo.marketing_spend (spend_date, offline_spend, online_spend)
SELECT
    TRY_CONVERT(DATE, [Date], 101),
    COALESCE(TRY_CONVERT(DECIMAL(14,2), Offline_Spend), 0),
    COALESCE(TRY_CONVERT(DECIMAL(14,2), Online_Spend), 0)
FROM dbo.Marketing_Spend_Raw;

INSERT INTO dbo.tax_amount (product_category, gst)
SELECT
    LTRIM(RTRIM(CONVERT(NVARCHAR(100), Product_Category))),
    TRY_CONVERT(DECIMAL(6,4), GST)
FROM dbo.Tax_amount_Raw;
GO

-- Enriched item-level sales
CREATE OR ALTER VIEW dbo.vw_sales_enriched
AS
SELECT
    x.*,
    x.quantity * x.avg_price AS gross_product_amount,
    (x.quantity * x.avg_price) * (x.applied_discount_pct / 100.0) AS discount_amount,
    (x.quantity * x.avg_price) * (1 - x.applied_discount_pct / 100.0) AS discounted_product_amount,
    ((x.quantity * x.avg_price) * (1 - x.applied_discount_pct / 100.0)) * x.gst_rate AS tax_amount_calc,
    ((x.quantity * x.avg_price) * (1 - x.applied_discount_pct / 100.0)) * (1 + x.gst_rate) AS product_invoice_excl_delivery,
    (((x.quantity * x.avg_price) * (1 - x.applied_discount_pct / 100.0)) * (1 + x.gst_rate))
        + x.delivery_charges AS line_invoice_value_as_provided
FROM (
    SELECT
        s.sale_row_id, s.customer_id, s.transaction_id,
        CONCAT(s.customer_id, '-', s.transaction_id) AS order_key,
        s.transaction_date,
        CONVERT(CHAR(7), s.transaction_date, 126) AS year_month,
        CASE MONTH(s.transaction_date)
          WHEN 1 THEN 'Jan' WHEN 2 THEN 'Feb' WHEN 3 THEN 'Mar'
          WHEN 4 THEN 'Apr' WHEN 5 THEN 'May' WHEN 6 THEN 'Jun'
          WHEN 7 THEN 'Jul' WHEN 8 THEN 'Aug' WHEN 9 THEN 'Sep'
          WHEN 10 THEN 'Oct' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Dec'
        END AS month_name,
        s.product_sku, s.product_description, s.product_category,
        s.quantity, s.avg_price, s.delivery_charges, s.coupon_status,
        c.gender, c.location, c.tenure_months,
        CASE WHEN s.coupon_status = 'Used' AND dc.coupon_code IS NOT NULL
             THEN dc.discount_pct ELSE CONVERT(DECIMAL(5,2),0) END AS applied_discount_pct,
        CASE WHEN s.coupon_status = 'Used' AND dc.coupon_code IS NULL THEN 1 ELSE 0 END AS coupon_mapping_missing,
        CASE WHEN s.coupon_status <> 'Used' THEN 'No discount applied'
             WHEN dc.coupon_code IS NULL THEN 'Missing coupon mapping'
             ELSE 'Coupon mapped' END AS coupon_mapping_status,
        COALESCE(t.gst, CONVERT(DECIMAL(6,4),0)) AS gst_rate
    FROM dbo.online_sales AS s
    LEFT JOIN dbo.customer_data AS c ON c.customer_id = s.customer_id
    LEFT JOIN dbo.discount_coupon AS dc
      ON dc.coupon_month = CASE MONTH(s.transaction_date)
          WHEN 1 THEN 'Jan' WHEN 2 THEN 'Feb' WHEN 3 THEN 'Mar'
          WHEN 4 THEN 'Apr' WHEN 5 THEN 'May' WHEN 6 THEN 'Jun'
          WHEN 7 THEN 'Jul' WHEN 8 THEN 'Aug' WHEN 9 THEN 'Sep'
          WHEN 10 THEN 'Oct' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Dec' END
     AND dc.product_category = s.product_category
    LEFT JOIN dbo.tax_amount AS t ON t.product_category = s.product_category
) AS x;
GO

-- One row per practical composite customer-order key
CREATE OR ALTER VIEW dbo.vw_order_revenue
AS
SELECT
    CONCAT(customer_id, '-', transaction_id) AS order_key,
    customer_id,
    transaction_id,
    MIN(transaction_date) AS order_date,
    CONVERT(CHAR(7), MIN(transaction_date), 126) AS year_month,
    COUNT_BIG(*) AS line_count,
    SUM(quantity) AS total_quantity,
    SUM(product_invoice_excl_delivery) AS product_invoice_excl_delivery,
    MAX(delivery_charges) AS order_delivery_charge,
    SUM(product_invoice_excl_delivery) + MAX(delivery_charges) AS order_revenue,
    SUM(line_invoice_value_as_provided) AS line_invoice_sum_as_provided
FROM dbo.vw_sales_enriched
GROUP BY customer_id, transaction_id;
GO

-- Monthly KPI, observed new/existing customers, costs
CREATE OR ALTER VIEW dbo.vw_monthly_performance
AS
WITH first_purchase AS (
    SELECT customer_id, MIN(order_date) AS first_observed_purchase_date
    FROM dbo.vw_order_revenue GROUP BY customer_id
),
monthly_orders AS (
    SELECT
        o.year_month,
        SUM(o.order_revenue) AS revenue,
        SUM(o.line_invoice_sum_as_provided) AS line_invoice_sum_as_provided,
        COUNT_BIG(*) AS order_count,
        COUNT(DISTINCT o.customer_id) AS active_customers,
        SUM(o.total_quantity) AS quantity,
        SUM(o.product_invoice_excl_delivery) AS product_invoice_excl_delivery,
        SUM(o.order_delivery_charge) AS delivery_charges_once_per_order,
        SUM(CASE WHEN CONVERT(CHAR(7), fp.first_observed_purchase_date, 126) = o.year_month
                 THEN o.order_revenue ELSE 0 END) AS new_cohort_revenue,
        SUM(CASE WHEN CONVERT(CHAR(7), fp.first_observed_purchase_date, 126) < o.year_month
                 THEN o.order_revenue ELSE 0 END) AS returning_customer_revenue
    FROM dbo.vw_order_revenue o
    JOIN first_purchase fp ON fp.customer_id = o.customer_id
    GROUP BY o.year_month
),
monthly_costs AS (
    SELECT CONVERT(CHAR(7), spend_date, 126) AS year_month,
           SUM(offline_spend) AS offline_spend,
           SUM(online_spend) AS online_spend,
           SUM(offline_spend + online_spend) AS total_marketing_spend
    FROM dbo.marketing_spend GROUP BY CONVERT(CHAR(7), spend_date, 126)
),
monthly_line_metrics AS (
    SELECT year_month, SUM(discount_amount) AS discount_amount,
           SUM(tax_amount_calc) AS tax_amount
    FROM dbo.vw_sales_enriched GROUP BY year_month
)
SELECT
    mo.year_month, mo.revenue, mo.line_invoice_sum_as_provided, mo.order_count,
    mo.active_customers, mo.quantity, mo.product_invoice_excl_delivery,
    mo.delivery_charges_once_per_order, ml.discount_amount, ml.tax_amount,
    mc.offline_spend, mc.online_spend, mc.total_marketing_spend,
    CASE WHEN mo.revenue = 0 THEN NULL ELSE mc.total_marketing_spend / mo.revenue END AS marketing_pct_of_revenue,
    CASE WHEN mo.revenue = 0 THEN NULL ELSE mo.delivery_charges_once_per_order / mo.revenue END AS delivery_pct_of_revenue,
    mo.new_cohort_revenue, mo.returning_customer_revenue
FROM monthly_orders mo
LEFT JOIN monthly_costs mc ON mc.year_month = mo.year_month
LEFT JOIN monthly_line_metrics ml ON ml.year_month = mo.year_month;
GO

-- Heuristic RFM and historical value bands (not predictive ML)
CREATE OR ALTER VIEW dbo.vw_customer_rfm_segment
AS
WITH customer_base AS (
    SELECT
        o.customer_id,
        MAX(o.order_date) AS last_purchase_date,
        DATEDIFF(DAY, MAX(o.order_date), CONVERT(DATE, '20200101', 112)) AS recency_days,
        COUNT_BIG(*) AS frequency_orders,
        SUM(o.order_revenue) AS monetary_revenue,
        c.gender, c.location, c.tenure_months
    FROM dbo.vw_order_revenue o
    LEFT JOIN dbo.customer_data c ON c.customer_id = o.customer_id
    GROUP BY o.customer_id, c.gender, c.location, c.tenure_months
),
scored AS (
    SELECT cb.*,
        6 - NTILE(5) OVER (ORDER BY recency_days ASC, customer_id ASC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency_orders ASC, customer_id ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary_revenue ASC, customer_id ASC) AS m_score,
        NTILE(3) OVER (ORDER BY monetary_revenue ASC, customer_id ASC) AS historical_value_tertile
    FROM customer_base cb
)
SELECT scored.*,
    CONCAT(r_score, f_score, m_score) AS rfm_code,
    CASE WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Premium'
         WHEN f_score >= 3 AND m_score >= 3 THEN 'Gold'
         WHEN r_score >= 3 OR f_score >= 3 THEN 'Silver'
         ELSE 'Standard' END AS rfm_segment,
    CASE WHEN historical_value_tertile = 3 THEN 'High historical value'
         WHEN historical_value_tertile = 2 THEN 'Medium historical value'
         ELSE 'Low historical value' END AS historical_customer_value_band
FROM scored;
GO

-- Observed days between purchase dates for repeat customers (proxy, not model prediction)
CREATE OR ALTER VIEW dbo.vw_customer_purchase_gap
AS
WITH customer_purchase_days AS (
    SELECT customer_id, order_date FROM dbo.vw_order_revenue GROUP BY customer_id, order_date
),
order_dates AS (
    SELECT customer_id, order_date,
           LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) AS previous_order_date
    FROM customer_purchase_days
),
intervals AS (
    SELECT customer_id, DATEDIFF(DAY, previous_order_date, order_date) AS days_between_orders
    FROM order_dates WHERE previous_order_date IS NOT NULL
),
averages AS (
    SELECT customer_id, COUNT(*) AS observed_intervals,
           AVG(CONVERT(DECIMAL(12,2), days_between_orders)) AS avg_days_between_orders
    FROM intervals GROUP BY customer_id
)
SELECT a.customer_id, a.observed_intervals,
       CONVERT(DECIMAL(12,2), a.avg_days_between_orders) AS avg_days_between_orders,
       CASE WHEN a.avg_days_between_orders <= 30 THEN '0-30 days'
            WHEN a.avg_days_between_orders <= 60 THEN '31-60 days'
            WHEN a.avg_days_between_orders <= 90 THEN '61-90 days'
            ELSE '90+ days' END AS next_purchase_timing_proxy
FROM averages a;
GO


-- ANALYSIS QUERIES: highlight and run individual query blocks as needed.

-- A. Data quality profile
SELECT COUNT(*) AS sales_rows,
       COUNT(DISTINCT transaction_id) AS distinct_raw_transaction_ids,
       COUNT(DISTINCT CONCAT(customer_id, '-', transaction_id)) AS composite_order_keys,
       COUNT(DISTINCT customer_id) AS customers,
       COUNT(DISTINCT product_sku) AS distinct_skus,
       COUNT(DISTINCT product_category) AS categories,
       MIN(transaction_date) AS first_date, MAX(transaction_date) AS last_date
FROM dbo.online_sales;

-- B. Transaction_ID mapped to more than one customer
SELECT transaction_id, COUNT(DISTINCT customer_id) AS customers_per_raw_id
FROM dbo.online_sales
GROUP BY transaction_id
HAVING COUNT(DISTINCT customer_id) > 1
ORDER BY customers_per_raw_id DESC, transaction_id;

-- C. Coupon mapping QA
SELECT coupon_status, COUNT(*) AS line_rows,
       SUM(coupon_mapping_missing) AS used_rows_missing_coupon_mapping
FROM dbo.vw_sales_enriched
GROUP BY coupon_status;

-- D. Executive KPI summary; shipping counted once per composite order
SELECT CAST(ROUND(SUM(order_revenue), 2) AS DECIMAL(18,2)) AS total_revenue_order_level,
       CAST(ROUND(SUM(line_invoice_sum_as_provided), 2) AS DECIMAL(18,2)) AS total_line_invoice_per_supplied_formula,
       COUNT_BIG(*) AS composite_orders,
       COUNT(DISTINCT customer_id) AS customers,
       CAST(ROUND(SUM(order_revenue) / NULLIF(COUNT_BIG(*),0), 2) AS DECIMAL(18,2)) AS average_order_value,
       SUM(total_quantity) AS total_quantity,
       CAST(ROUND(SUM(order_delivery_charge), 2) AS DECIMAL(18,2)) AS delivery_charges_counted_once
FROM dbo.vw_order_revenue;

-- E. Monthly performance for Power BI
SELECT * FROM dbo.vw_monthly_performance ORDER BY year_month;

-- F. Customers by first observed purchase month (not necessarily acquisition month)
SELECT CONVERT(CHAR(7), first_observed_purchase_date, 126) AS first_observed_month,
       COUNT(*) AS customers_first_observed_in_month
FROM (SELECT customer_id, MIN(order_date) AS first_observed_purchase_date
      FROM dbo.vw_order_revenue GROUP BY customer_id) x
GROUP BY CONVERT(CHAR(7), first_observed_purchase_date, 126)
ORDER BY first_observed_month;

-- G. Product/category performance; revenue excludes delivery to prevent double-counting by category
SELECT product_category,
       CAST(ROUND(SUM(product_invoice_excl_delivery),2) AS DECIMAL(18,2)) AS product_invoice_excl_delivery,
       SUM(quantity) AS quantity,
       COUNT_BIG(*) AS product_rows,
       COUNT(DISTINCT order_key) AS composite_orders,
       CAST(ROUND(SUM(discount_amount),2) AS DECIMAL(18,2)) AS discount_amount,
       CAST(ROUND(SUM(tax_amount_calc),2) AS DECIMAL(18,2)) AS tax_amount
FROM dbo.vw_sales_enriched
GROUP BY product_category
ORDER BY product_invoice_excl_delivery DESC;

-- H. Top 20 products by units sold
SELECT TOP (20) product_sku, product_description, product_category,
       SUM(quantity) AS quantity_sold,
       CAST(ROUND(SUM(product_invoice_excl_delivery),2) AS DECIMAL(18,2)) AS product_invoice_excl_delivery,
       COUNT(DISTINCT order_key) AS composite_orders
FROM dbo.vw_sales_enriched
GROUP BY product_sku, product_description, product_category
ORDER BY quantity_sold DESC;

-- I. Discount and revenue by coupon status
SELECT coupon_status, COUNT_BIG(*) AS line_rows,
       COUNT(DISTINCT order_key) AS composite_orders,
       CAST(ROUND(SUM(product_invoice_excl_delivery),2) AS DECIMAL(18,2)) AS product_invoice_excl_delivery,
       CAST(ROUND(SUM(discount_amount),2) AS DECIMAL(18,2)) AS discount_amount,
       CAST(ROUND(AVG(applied_discount_pct),2) AS DECIMAL(9,2)) AS avg_applied_discount_pct
FROM dbo.vw_sales_enriched
GROUP BY coupon_status
ORDER BY line_rows DESC;

-- J. Location performance
SELECT c.location, COUNT(DISTINCT o.customer_id) AS customers,
       COUNT_BIG(*) AS composite_orders,
       CAST(ROUND(SUM(o.order_revenue),2) AS DECIMAL(18,2)) AS revenue,
       CAST(ROUND(SUM(o.order_revenue) / NULLIF(COUNT_BIG(*),0),2) AS DECIMAL(18,2)) AS average_order_value
FROM dbo.vw_order_revenue o
LEFT JOIN dbo.customer_data c ON c.customer_id = o.customer_id
GROUP BY c.location ORDER BY revenue DESC;

-- K. RFM segment profiles and actions
SELECT rfm_segment, COUNT(*) AS customers,
       CAST(ROUND(COUNT(*) * 100.0 / NULLIF((SELECT COUNT(*) FROM dbo.vw_customer_rfm_segment),0),2) AS DECIMAL(9,2)) AS customer_pct,
       CAST(ROUND(SUM(monetary_revenue),2) AS DECIMAL(18,2)) AS historical_revenue,
       CAST(ROUND(SUM(monetary_revenue) * 100.0 / NULLIF((SELECT SUM(monetary_revenue) FROM dbo.vw_customer_rfm_segment),0),2) AS DECIMAL(9,2)) AS revenue_pct,
       CAST(ROUND(AVG(CONVERT(DECIMAL(12,2),recency_days)),1) AS DECIMAL(9,1)) AS avg_recency_days,
       CAST(ROUND(AVG(CONVERT(DECIMAL(12,2),frequency_orders)),2) AS DECIMAL(9,2)) AS avg_orders_per_customer
FROM dbo.vw_customer_rfm_segment
GROUP BY rfm_segment ORDER BY historical_revenue DESC;

-- L. Cohort retention. Month 0 is 100% by definition.
WITH customer_cohort AS (
    SELECT customer_id, DATEFROMPARTS(YEAR(MIN(order_date)), MONTH(MIN(order_date)), 1) AS cohort_month
    FROM dbo.vw_order_revenue GROUP BY customer_id
),
customer_activity AS (
    SELECT DISTINCT customer_id, DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1) AS activity_month
    FROM dbo.vw_order_revenue
)
SELECT cc.cohort_month, ca.activity_month,
       DATEDIFF(MONTH, cc.cohort_month, ca.activity_month) AS cohort_age_months,
       COUNT(DISTINCT cc.customer_id) AS cohort_size,
       COUNT(DISTINCT ca.customer_id) AS active_customers,
       CAST(ROUND(COUNT(DISTINCT ca.customer_id) * 100.0 / NULLIF(COUNT(DISTINCT cc.customer_id),0),2) AS DECIMAL(9,2)) AS retention_pct
FROM customer_cohort cc
JOIN customer_activity ca ON ca.customer_id = cc.customer_id
GROUP BY cc.cohort_month, ca.activity_month
ORDER BY cc.cohort_month, ca.activity_month;

-- M. Product pairs bought together in the same customer-order; descriptions are used to avoid reverse duplicate pairs.
WITH order_product AS (
    SELECT DISTINCT customer_id, transaction_id, product_sku, product_description
    FROM dbo.online_sales
)
SELECT TOP (50) a.product_description AS product_a, b.product_description AS product_b,
       COUNT(DISTINCT CONCAT(a.customer_id, '-', a.transaction_id)) AS orders_together
FROM order_product a
JOIN order_product b ON b.customer_id = a.customer_id AND b.transaction_id = a.transaction_id
 AND a.product_description < b.product_description
GROUP BY a.product_description, b.product_description
HAVING COUNT(DISTINCT CONCAT(a.customer_id, '-', a.transaction_id)) >= 5
ORDER BY orders_together DESC;

-- N. Observed next-purchase timing proxy (not trained prediction)
SELECT next_purchase_timing_proxy, COUNT(*) AS repeat_customers,
       CAST(ROUND(AVG(avg_days_between_orders),1) AS DECIMAL(9,1)) AS avg_customer_gap_days
FROM dbo.vw_customer_purchase_gap
GROUP BY next_purchase_timing_proxy
ORDER BY CASE next_purchase_timing_proxy WHEN '0-30 days' THEN 1 WHEN '31-60 days' THEN 2
    WHEN '61-90 days' THEN 3 ELSE 4 END;

-- O. Historical value bands (not predictive CLV)
SELECT historical_customer_value_band, COUNT(*) AS customers,
       CAST(ROUND(SUM(monetary_revenue),2) AS DECIMAL(18,2)) AS historical_revenue
FROM dbo.vw_customer_rfm_segment
GROUP BY historical_customer_value_band ORDER BY historical_revenue DESC;

-- P. Inactivity proxy as of 2020-01-01, not official churn without a business definition
SELECT CASE WHEN recency_days > 90 THEN 'No purchase in >90 days (proxy)' ELSE 'Purchased within 90 days' END AS activity_status,
       COUNT(*) AS customers
FROM dbo.vw_customer_rfm_segment
GROUP BY CASE WHEN recency_days > 90 THEN 'No purchase in >90 days (proxy)' ELSE 'Purchased within 90 days' END;




SELECT 'Online_Sales_Raw' AS table_name, COUNT_BIG(*) AS row_count FROM dbo.Online_Sales_Raw
UNION ALL SELECT 'CustomersData_Raw', COUNT_BIG(*) FROM dbo.CustomersData_Raw
UNION ALL SELECT 'Discount_Coupon_Raw', COUNT_BIG(*) FROM dbo.Discount_Coupon_Raw
UNION ALL SELECT 'Marketing_Spend_Raw', COUNT_BIG(*) FROM dbo.Marketing_Spend_Raw
UNION ALL SELECT 'Tax_amount_Raw', COUNT_BIG(*) FROM dbo.Tax_amount_Raw;
