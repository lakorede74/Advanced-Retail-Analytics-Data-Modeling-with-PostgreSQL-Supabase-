
-- having a glance of our dataset
select * from dunnhumby.transaction_data
limit 1000;

-- creating indexes
CREATE index idx_house_key
ON dunnhumby.transaction_data(household_key)

CREATE index idx_sales_value
ON dunnhumby.transaction_data("SALES_VALUE")

create index idx_trans_DAY
ON dunnhumby.transaction_data("DAY")

create index idx_housekey_day
ON dunnhumby.transaction_data(household_key, "DAY")
---------------------------------
CREATE OR REPLACE VIEW dunnhumby.transaction_view AS
SELECT 
household_key,
"BASKET_ID",
"PRODUCT_ID",
"DAY",
  (DATE '2023-01-01' + ("DAY"-1) * interval '1 day') AS transaction_date,
  TO_CHAR(DATE '2023-01-01' + ("DAY" - 1) * interval '1 day', 'month') AS transaction_month,
"SALES_VALUE",
"RETAIL_DISC",
"COUPON_DISC",
"COUPON_MATCH_DISC",
"QUANTITY"
FROM dunnhumby.transaction_data
;  

-- daily Sales
CREATE OR REPLACE VIEW dunnhumby.daily_trans_view AS 
SELECT 
household_key,
DATE_TRUNC('day', transaction_date) AS start_day,
Sum("SALES_VALUE") AS total_d_sales
FROM dunnhumby.transaction_view
GROUP BY household_key, start_day;

-- weekly sales
CREATE OR REPLACE VIEW dunnhumby.weekly_trans_view AS
SELECT 
household_key,
DATE_TRUNC('week', transaction_date) AS start_week,
SUM("SALES_VALUE") AS total_w_sales
FROM dunnhumby.transaction_view
GROUP BY household_key, start_week


-- monthly sales
CREATE OR REPLACE VIEW dunnhumby.monthly_trans_view AS
SELECT 
household_key,
DATE_TRUNC('month', transaction_date) AS start_month,
SUM("SALES_VALUE") AS total_m_sales
FROM dunnhumby.transaction_view
GROUP BY household_key, start_month

-- COHORT ANALYSIS ----
-- finding the the cohort month
CREATE OR REPLACE VIEW dunnhumby.first_purchase_date_view AS 
SELECT 
household_key,
MIN(transaction_date) AS first_purchase_date
FROM dunnhumby.transaction_view
GROUP BY 
household_key;

-- COHORT
CREATE OR REPLACE VIEW dunnhumby.cohort_view AS
WITH cohort_count AS 
(SELECT
DATE_TRUNC('month', f.first_purchase_date) AS cohort_month,
TO_CHAR(DATE_TRUNC('month', f.first_purchase_date), 'month-YYYY') AS c_MY,
DATE_TRUNC('month', t.transaction_date) AS activity_month,
TO_CHAR(DATE_TRUNC('month', t.transaction_date), 'month-YYYY') AS a_MY,
COUNT(DISTINCT t.household_key) AS active_members,
SUM("SALES_VALUE") AS total_sales
FROM dunnhumby.transaction_view t
LEFT JOIN dunnhumby.first_purchase_date_view f
ON t.household_key = f.household_key
GROUP BY 
cohort_month,
c_MY,
activity_month,
a_MY),

cohort_size AS 
    (
      SELECT 
      cohort_month,
      c_MY,
      activity_month,
      a_MY,
      active_members,
      FIRST_VALUE(active_members) OVER(PARTITION BY cohort_month ORDER BY activity_month) AS cohort_size,
      total_sales
      FROM cohort_count
    )

  SELECT 
  cohort_month,
  c_MY,
  activity_month,
  a_MY,
  active_members,
  cohort_size,
  ROUND(active_members * 100.0/cohort_size, 2) || '%' AS retention_rate,
  ('M' || (EXTRACT(YEAR FROM activity_month) - EXTRACT(YEAR FROM cohort_month)) * 12 + EXTRACT(MONTH FROM activity_month) - EXTRACT(MONTH FROM cohort_month))::text AS month_number,
  total_sales

  FROM cohort_size;

SELECT * FROM dunnhumby.product;

-- Product level margin
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

-- product mix segmentation
CREATE OR REPLACE VIEW dunnhumby.product_seg_view AS 
WITH seg_percentile AS
(
  SELECT 
    PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY raw_margin_pct) AS p_rm_50,
    PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY total_revenue) AS p_tr_50
    
  FROM dunnhumby.product_margin_view
)

SELECT 
*,
CASE 
WHEN raw_margin_pct >= p_rm_50 AND total_revenue >= p_tr_50
THEN 'Stars'

WHEN raw_margin_pct < p_rm_50 AND total_revenue >= p_tr_50
THEN 'Cash cows'

WHEN raw_margin_pct >= p_rm_50 AND total_revenue < p_tr_50
THEN 'Ivestigate'

ELSE 'dogs'

-- WHEN raw_margin_pct < p_rm_50 AND total_revenue < p_tr_50
-- THEN 'Dogs'

END AS product_segment

FROM dunnhumby.product_margin_view, seg_percentile;


-- product seg_margin
CREATE OR REPLACE VIEW dunnhumby.product_seg_contribution_view AS 
SELECT 
product_segment,
COUNT(DISTINCT "PRODUCT_ID") AS total_product,
SUM(gross_margin) AS segment_margin,
ROUND(
  SUM(gross_margin::numeric)/NULLIF(SUM(total_revenue::numeric),0),2
  ) AS seg_margin_pct,
SUM(total_revenue) AS segment_sales
FROM dunnhumby.product_seg_view
GROUP BY product_segment;

-- cost to serve
CREATE OR REPLACE VIEW dunnhumby.cost_to_serve_view AS 
SELECT 
household_key,
COUNT(DISTINCT "BASKET_ID") * 0.1 AS transaction_cost,
SUM("QUANTITY") * 0.07 AS fulfiLlment_cost
FROM dunnhumby.transaction_view 
GROUP BY household_key;

-- Net margin
CREATE OR REPLACE VIEW dunnhumby.net_margin_view AS  
SELECT 
t.household_key,
SUM(t."SALES_VALUE") AS total_sales,
SUM(t."SALES_VALUE") - ABS(SUM(t."RETAIL_DISC" + t."COUPON_DISC" + t."COUPON_MATCH_DISC" )) - (COALESCE(c.transaction_cost,0) + COALESCE(c.fulfillment_cost,0)) AS net_margin,
COUNT(DISTINCT "BASKET_ID") AS total_order,
COALESCE(c.transaction_cost,0) + COALESCE(c.fulfillment_cost,0) AS cost_to_serve,
ABS(SUM(t."RETAIL_DISC" + t."COUPON_DISC" + t."COUPON_MATCH_DISC" )) AS total_discount
FROM dunnhumby.transaction_view t
LEFT JOIN dunnhumby.cost_to_serve_view c 
ON t.household_key = c.household_key
GROUP BY 
t.household_key,
c.transaction_cost,
c.fulfillment_cost
;
