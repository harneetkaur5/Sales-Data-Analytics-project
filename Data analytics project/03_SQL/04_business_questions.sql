/* =====================================================================
   FILE    : 04_business_questions.sql
   PURPOSE : The 12 analytical queries that answer the project's business
             questions. Run them one at a time (place the cursor inside a
             query and press Ctrl+Enter in MySQL Workbench).
   NOTE    : "Expected result" comments were calculated from the same
             cleaned data, so you can check your output matches.
   ===================================================================== */
USE superstore_db;

-- @Q1 ------------------------------------------------------------------
-- Q1. What are the total sales and total profit?
-- Expected: 2296919.49 | 286409.08 | 9993 lines
SELECT  ROUND(SUM(sales), 2)  AS total_sales,      -- add every line's sales
        ROUND(SUM(profit), 2) AS total_profit,     -- add every line's profit
        COUNT(*)              AS order_lines       -- number of rows
FROM    order_items;

-- @Q2 ------------------------------------------------------------------
-- Q2. What is the total sales value for each product category?
-- Expected: Technology 836154.03 | Furniture 741718.42 | Office Supplies 719047.03
SELECT  p.category,
        ROUND(SUM(oi.sales), 2)                                          AS total_sales,
        ROUND(SUM(oi.sales) * 100 / (SELECT SUM(sales) FROM order_items), 2) AS pct_of_total_sales
FROM        order_items oi
INNER JOIN  products    p  ON p.product_key = oi.product_key   -- join line items to their product
GROUP BY    p.category                                         -- one result row per category
ORDER BY    total_sales DESC;                                  -- biggest first

-- @Q3 ------------------------------------------------------------------
-- Q3. Which regions generate the highest sales and profit?
-- Expected: West 725457.82 / 108418.45 at the top, South lowest sales
SELECT  o.region,
        r.manager_name,
        ROUND(SUM(oi.sales), 2)                    AS total_sales,
        ROUND(SUM(oi.profit), 2)                   AS total_profit,
        ROUND(SUM(oi.profit) / SUM(oi.sales) * 100, 2) AS profit_margin_pct,
        COUNT(DISTINCT o.order_id)                 AS orders
FROM        order_items oi
INNER JOIN  orders      o ON o.order_id = oi.order_id
INNER JOIN  regions     r ON r.region   = o.region
GROUP BY    o.region, r.manager_name
ORDER BY    total_sales DESC;

-- @Q4 ------------------------------------------------------------------
-- Q4. Which products generate the highest profit? (top 5 with their category)
-- Expected #1: Canon imageCLASS 2200 Advanced Copier, profit 25199.93
SELECT  p.product_name,
        p.category,
        p.sub_category,
        ROUND(SUM(oi.sales), 2)  AS total_sales,
        ROUND(SUM(oi.profit), 2) AS total_profit,
        SUM(oi.quantity)         AS units_sold
FROM        order_items oi
INNER JOIN  products    p ON p.product_key = oi.product_key
GROUP BY    p.product_name, p.category, p.sub_category
ORDER BY    total_profit DESC
LIMIT 5;

-- @Q5a -----------------------------------------------------------------
-- Q5a. Which sub-categories have negative profit overall?
-- Expected: Tables -17725.48 | Bookcases -3472.56 | Supplies -1189.10
SELECT  category,
        sub_category,
        ROUND(SUM(sales), 2)  AS total_sales,
        ROUND(SUM(profit), 2) AS total_profit
FROM     vw_sales
GROUP BY category, sub_category
HAVING   SUM(profit) < 0          -- HAVING filters GROUPS (WHERE filters rows)
ORDER BY total_profit;

-- @Q5b -----------------------------------------------------------------
-- Q5b. The 10 products with the largest losses
-- Expected #1: Cubify CubeX 3D Printer Double Head Print, -8879.97
SELECT  product_name,
        sub_category,
        ROUND(SUM(sales), 2)  AS total_sales,
        ROUND(SUM(profit), 2) AS total_profit,
        ROUND(AVG(discount) * 100, 1) AS avg_discount_pct
FROM     vw_sales
GROUP BY product_name, sub_category
HAVING   SUM(profit) < 0
ORDER BY total_profit
LIMIT 10;

-- @Q5c -----------------------------------------------------------------
-- Q5c. How many products are loss-making overall? Expected: 299 (6 more break exactly even at 0.00)
SELECT COUNT(*) AS loss_making_products
FROM  (SELECT product_name
       FROM   vw_sales
       GROUP  BY product_name
       HAVING SUM(profit) < 0) AS loss_products;     -- derived table (subquery in FROM)

-- @Q6 ------------------------------------------------------------------
-- Q6. How do sales change month by month? (with month-on-month growth %)
-- Uses a CTE (WITH) and the window function LAG() – MySQL 8.0+
-- Expected: 48 months, 2017-01 = 14236.90 … 2020-11 = 118447.82 (highest)
WITH monthly AS (
    SELECT  DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,
            SUM(oi.sales)  AS sales,
            SUM(oi.profit) AS profit
    FROM        order_items oi
    INNER JOIN  orders      o ON o.order_id = oi.order_id
    GROUP BY    DATE_FORMAT(o.order_date, '%Y-%m')
)
SELECT  order_month,
        ROUND(sales, 2)                                       AS monthly_sales,
        ROUND(profit, 2)                                      AS monthly_profit,
        ROUND(LAG(sales) OVER (ORDER BY order_month), 2)      AS previous_month_sales,
        ROUND( (sales - LAG(sales) OVER (ORDER BY order_month))
               / LAG(sales) OVER (ORDER BY order_month) * 100, 2) AS mom_growth_pct
FROM    monthly
ORDER BY order_month;

-- @Q6b -----------------------------------------------------------------
-- Q6b. Yearly view (easier to read than 48 months)
-- Expected: 2017 483966.13 | 2018 470532.51 | 2019 609205.60 | 2020 733215.26
SELECT  YEAR(order_date)               AS order_year,
        ROUND(SUM(sales), 2)           AS total_sales,
        ROUND(SUM(profit), 2)          AS total_profit,
        COUNT(DISTINCT order_id)       AS orders
FROM     vw_sales
GROUP BY YEAR(order_date)
ORDER BY order_year;

-- @Q7 ------------------------------------------------------------------
-- Q7. Which customer segments generate the most sales?
-- Expected: Consumer 1161401.35 (50.56%) | Corporate 706146.37 | Home Office 429371.78
SELECT  c.segment,
        COUNT(DISTINCT c.customer_id)  AS customers,
        COUNT(DISTINCT o.order_id)     AS orders,
        ROUND(SUM(oi.sales), 2)        AS total_sales,
        ROUND(SUM(oi.profit), 2)       AS total_profit,
        ROUND(SUM(oi.profit) / SUM(oi.sales) * 100, 2)              AS profit_margin_pct,
        ROUND(SUM(oi.sales) / COUNT(DISTINCT o.order_id), 2)        AS avg_order_value
FROM        order_items oi
INNER JOIN  orders      o ON o.order_id    = oi.order_id
INNER JOIN  customers   c ON c.customer_id = o.customer_id
GROUP BY    c.segment
ORDER BY    total_sales DESC;

-- @Q8 ------------------------------------------------------------------
-- Q8. How are discounts associated with profitability?
-- CASE puts every line into a discount band.
-- Expected margins: No discount 29.51% | Low 11.91% | Medium -15.31% | High -77.40%
SELECT  CASE
            WHEN discount = 0     THEN '1. No Discount (0%)'
            WHEN discount <= 0.20 THEN '2. Low (1-20%)'
            WHEN discount <= 0.40 THEN '3. Medium (21-40%)'
            ELSE                       '4. High (>40%)'
        END                                         AS discount_band,
        COUNT(*)                                    AS order_lines,
        ROUND(SUM(sales), 2)                        AS total_sales,
        ROUND(SUM(profit), 2)                       AS total_profit,
        ROUND(SUM(profit) / SUM(sales) * 100, 2)    AS profit_margin_pct,
        SUM(CASE WHEN profit < 0 THEN 1 ELSE 0 END) AS loss_lines,
        ROUND(AVG(CASE WHEN profit < 0 THEN 1 ELSE 0 END) * 100, 1) AS pct_lines_loss
FROM     order_items
GROUP BY discount_band
ORDER BY discount_band;

-- @Q8b -----------------------------------------------------------------
-- Q8b. Same idea at every exact discount level
SELECT  discount,
        COUNT(*)                                 AS order_lines,
        ROUND(SUM(sales), 2)                     AS total_sales,
        ROUND(SUM(profit), 2)                    AS total_profit,
        ROUND(SUM(profit) / SUM(sales) * 100, 2) AS profit_margin_pct
FROM     order_items
GROUP BY discount
ORDER BY discount;

-- @Q9 ------------------------------------------------------------------
-- Q9. Top 10 products by profit, with an explicit rank (window function RANK)
WITH product_profit AS (
    SELECT  p.product_name,
            p.sub_category,
            SUM(oi.profit) AS total_profit,
            SUM(oi.sales)  AS total_sales
    FROM        order_items oi
    INNER JOIN  products    p ON p.product_key = oi.product_key
    GROUP BY    p.product_name, p.sub_category
)
SELECT  RANK() OVER (ORDER BY total_profit DESC) AS profit_rank,
        product_name,
        sub_category,
        ROUND(total_sales, 2)  AS total_sales,
        ROUND(total_profit, 2) AS total_profit
FROM    product_profit
ORDER BY profit_rank
LIMIT 10;

-- @Q10a ----------------------------------------------------------------
-- Q10a. Categories: share of sales vs share of profit
-- Expected: Furniture = 32.29% of sales but only 6.45% of profit (margin 2.49%)
SELECT  category,
        ROUND(SUM(sales), 2) AS total_sales,
        ROUND(SUM(profit), 2) AS total_profit,
        ROUND(SUM(sales)  * 100 / (SELECT SUM(sales)  FROM order_items), 2) AS pct_of_sales,
        ROUND(SUM(profit) * 100 / (SELECT SUM(profit) FROM order_items), 2) AS pct_of_profit,
        ROUND(SUM(profit) / SUM(sales) * 100, 2) AS profit_margin_pct
FROM     vw_sales
GROUP BY category
ORDER BY profit_margin_pct;

-- @Q10b ----------------------------------------------------------------
-- Q10b. Sub-categories with ABOVE-average sales but BELOW-overall profit margin
-- Expected: Chairs, Storage, Tables, Machines
WITH sub_cat AS (
    SELECT  category, sub_category,
            SUM(sales) AS total_sales, SUM(profit) AS total_profit
    FROM     vw_sales
    GROUP BY category, sub_category
)
SELECT  category,
        sub_category,
        ROUND(total_sales, 2)                       AS total_sales,
        ROUND(total_profit, 2)                      AS total_profit,
        ROUND(total_profit / total_sales * 100, 2)  AS profit_margin_pct
FROM    sub_cat
WHERE   total_sales > (SELECT AVG(total_sales) FROM sub_cat)                       -- high sales
  AND   total_profit / total_sales < (SELECT SUM(profit) / SUM(sales) FROM order_items) -- low margin
ORDER BY total_sales DESC;

-- @Q11 -----------------------------------------------------------------
-- Q11. Average order value and overall profit margin
-- Expected: 5009 orders | AOV 458.56 | margin 12.47%
-- Correct margin = SUM(profit)/SUM(sales); NOT AVG(profit/sales) (that gives 12.03%)
SELECT  COUNT(DISTINCT order_id)                           AS total_orders,
        ROUND(SUM(sales) / COUNT(DISTINCT order_id), 2)    AS avg_order_value,
        ROUND(SUM(profit) / SUM(sales) * 100, 2)           AS overall_profit_margin_pct,
        ROUND(AVG(profit / sales) * 100, 2)                AS misleading_avg_of_row_margins_pct
FROM    order_items;

-- @Q12a ----------------------------------------------------------------
-- Q12a. Regions whose sales are below the average region (HAVING + subquery)
-- Average region sales = 574229.87. Expected: Central, South
SELECT  region,
        ROUND(SUM(sales), 2) AS total_sales
FROM     vw_sales
GROUP BY region
HAVING   SUM(sales) < (SELECT SUM(sales) / COUNT(DISTINCT region) FROM vw_sales)
ORDER BY total_sales;

-- @Q12b ----------------------------------------------------------------
-- Q12b. Every region and category compared with the OVERALL profit margin (12.47%)
SELECT  'Region' AS dimension, region AS member,
        ROUND(SUM(profit) / SUM(sales) * 100, 2) AS profit_margin_pct,
        CASE WHEN SUM(profit) / SUM(sales) < (SELECT SUM(profit) / SUM(sales) FROM order_items)
             THEN 'Below overall' ELSE 'Above overall' END AS vs_overall
FROM vw_sales GROUP BY region
UNION ALL
SELECT  'Category', category,
        ROUND(SUM(profit) / SUM(sales) * 100, 2),
        CASE WHEN SUM(profit) / SUM(sales) < (SELECT SUM(profit) / SUM(sales) FROM order_items)
             THEN 'Below overall' ELSE 'Above overall' END
FROM vw_sales GROUP BY category
ORDER BY dimension, profit_margin_pct;
