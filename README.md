# Advanced-Retail-Analytics-Data-Modeling-with-PostgreSQL-Supabase

## Overview
This project focuses on building production-ready data layer for advanced retail profitability, product mix, cohort analysis and product segmentation using PostgreSQL hosted on Supabase.

Supabase is used as the managed PostgreSQL cloud backend, enabling secure remote access, scalable storage, and seamless integration with external analytics platforms such as Looker Studio and Power BI.
>The goal of this project is to create an optimized analytical SQL layer that can easily be consumed by downstream BI tools

## Dataset
Source: https://www.dunnhumby.com/source-files

Description: This data consist of 8 tables and in this project will be exploring 3 of the tables (Transaction_data, hh_demographic, and product)
The transaction__data table consists of 13 columns and 2.6 milloin rows, product table consists of 7 columns and 92.4k rows, hh_demographic tbale  consists of  8 fields and 801 rows  

File: dunnhumby_the_complete_journey.csv

## Design Philosophy
- **Logic lives in SQL (postgreSQL), not BI tools**

All business logic (joins, calculations, cohort definitions) is handled at the database layer.

- **Views over BI modeling**

Each view represents a trusted metric layer, allowing BI tools to remain lightweight and visualization-focused.

- **Scalable & reproducible**

The database structure is designed to handle larger datasets and evolving analytical requirements.

## Entity Relationship Diagram

![ERD](image/DunnhumbyERD2.svg)

The ERD represents the logical structure of the Dunnhumby dataset at the base-table level. Analytical complexity is handled through PostgreSQL views rather than physical star-schema modeling, ensuring metric consistency and avoiding double aggregation in BI tools.

## Analytical Viewsand KPIs Layers

### Product Level Margin 
- This shows the profitability of the products

  
  ```
          CREATE OR REPLACE VIEW dunnhumby.product_margin_view AS
          SELECT 
          P."PRODUCT_ID",
          P."DEPARTMENT",
          P."COMMODITY_DESC",
          ABS(SUM("RETAIL_DISC" + "COUPON_DISC" + "COUPON_MATCH_DISC")) AS total_discount,
          SUM(t."SALES_VALUE") - ABS(SUM("RETAIL_DISC" + "COUPON_DISC" + "COUPON_MATCH_DISC")) AS gross_margin,
          ROUND(
            ((SUM(t."SALES_VALUE") - ABS(SUM("RETAIL_DISC" + "COUPON_DISC" + "COUPON_MATCH_DISC"))) * 100.0/NULLIF(SUM("SALES_VALUE"), 0))::numeric, 2) || '%' AS gross_margin_pct,
          
          ROUND(
            ((SUM(t."SALES_VALUE") - ABS(SUM("RETAIL_DISC" + "COUPON_DISC" + "COUPON_MATCH_DISC"))) * 100.0/NULLIF(SUM("SALES_VALUE"), 0))::numeric, 2) AS raw_margin_pct,
          SUM("SALES_VALUE") AS total_revenue
          FROM dunnhumby.product p
          LEFT JOIN dunnhumby.transaction_view t
          USING("PRODUCT_ID")
          GROUP BY "PRODUCT_ID", "DEPARTMENT", "COMMODITY_DESC"
          ;
  
  ```
  [see full query](advanced_retail_analytics_modeling.SQL)

  ![Output:](image/product_level_margin.png)

  


