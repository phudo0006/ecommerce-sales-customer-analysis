# Source data files

The SQL workflow expects the five source files from the Kaggle dataset **[Marketing Insights for E-Commerce Company](https://www.kaggle.com/datasets/rishikumarrajvansh/marketing-insights-for-e-commerce-company)**, published by `rishikumarrajvansh`.

Download the dataset from Kaggle and place the extracted files in this folder. The SQL workflow expects these file names:

- `Online_Sales.csv`
- `CustomersData.xlsx`
- `Discount_Coupon.csv`
- `Marketing_Spend.csv`
- `Tax_amount.xlsx`

The raw files are intentionally not included in this repository. Before redistributing them, check the licence and terms shown on the Kaggle dataset page. This project links to the original source rather than hosting another copy of the data.

## SQL Server import table names

Import the files into `ecommerce_analysis` using these exact destination table names and preserve the original column headers:

| Source file | Destination table |
|---|---|
| `Online_Sales.csv` | `dbo.Online_Sales_Raw` |
| `CustomersData.xlsx` | `dbo.CustomersData_Raw` |
| `Discount_Coupon.csv` | `dbo.Discount_Coupon_Raw` |
| `Marketing_Spend.csv` | `dbo.Marketing_Spend_Raw` |
| `Tax_amount.xlsx` | `dbo.Tax_amount_Raw` |

Read the execution instructions at the beginning of `sql/01_ecommerce_analysis_sqlserver.sql` before running the script.
