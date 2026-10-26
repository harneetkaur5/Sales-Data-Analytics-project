/* =====================================================================
   FILE    : 05_sql_concepts_demo.sql
   PURPOSE : Syllabus coverage – string, date, conversion and conditional
             functions, joins, subqueries, set operators, DML with
             transactions, schema objects, data dictionary views, access
             control (DCL) and performance on larger data.
   RUN     : One block at a time (Ctrl+Enter).
   ===================================================================== */
USE superstore_db;

/* ---------------------------------------------------------------------
   A. STRING FUNCTIONS
   --------------------------------------------------------------------- */
SELECT  customer_id,
        customer_name,
        UPPER(customer_name)                          AS name_upper,
        LOWER(customer_name)                          AS name_lower,
        LENGTH(customer_name)                         AS name_length,
        SUBSTRING_INDEX(customer_name, ' ', 1)        AS first_name,   -- text before the first space
        SUBSTRING_INDEX(customer_name, ' ', -1)       AS last_name,    -- text after the last space
        CONCAT(customer_id, ' - ', customer_name)     AS customer_label,
        LEFT(customer_id, 2)                          AS initials_code
FROM    customers
LIMIT 10;

-- Order ID = <prefix>-<year>-<number>, e.g. CA-2019-152156
SELECT  order_id,
        SUBSTRING_INDEX(order_id, '-', 1)                         AS id_prefix,
        SUBSTRING(order_id, 4, 4)                                 AS year_in_id,
        REPLACE(order_id, '-', '')                                AS id_without_dash,
        TRIM('   extra spaces   ')                                AS trimmed_example
FROM    orders
LIMIT 5;

-- Product names that contain the word "Printer"
SELECT DISTINCT product_name
FROM   products
WHERE  product_name LIKE '%Printer%'
LIMIT 10;

/* ---------------------------------------------------------------------
   B. DATE FUNCTIONS
   --------------------------------------------------------------------- */
SELECT  order_id,
        order_date,
        ship_date,
        YEAR(order_date)                       AS order_year,
        MONTH(order_date)                      AS order_month_no,
        MONTHNAME(order_date)                  AS order_month_name,
        QUARTER(order_date)                    AS order_quarter,
        DAYNAME(order_date)                    AS order_weekday,
        DATE_FORMAT(order_date, '%d-%b-%Y')    AS formatted_date,
        DATEDIFF(ship_date, order_date)        AS days_to_ship,
        DATE_ADD(order_date, INTERVAL 30 DAY)  AS payment_due_date
FROM    orders
LIMIT 10;

-- Average shipping days by ship mode (expected overall average ≈ 3.96 days per line)
SELECT  ship_mode,
        ROUND(AVG(DATEDIFF(ship_date, order_date)), 2) AS avg_days_to_ship,
        COUNT(*) AS orders
FROM     orders
GROUP BY ship_mode
ORDER BY avg_days_to_ship;

-- Sales by quarter
SELECT  YEAR(order_date) AS yr, QUARTER(order_date) AS qtr,
        ROUND(SUM(sales), 2) AS total_sales
FROM     vw_sales
GROUP BY YEAR(order_date), QUARTER(order_date)
ORDER BY yr, qtr;

/* ---------------------------------------------------------------------
   C. CONVERSION FUNCTIONS
   --------------------------------------------------------------------- */
SELECT  sales,
        CAST(sales AS SIGNED)            AS sales_as_integer,     -- rounds to whole number
        CAST(sales AS CHAR)              AS sales_as_text,
        CONVERT(quantity, CHAR)          AS qty_as_text,
        CAST('2020-12-31' AS DATE)       AS text_to_date,
        STR_TO_DATE('31/12/2020', '%d/%m/%Y') AS parsed_date,
        FORMAT(sales, 2)                 AS sales_with_commas      -- returns text e.g. '1,234.50'
FROM    order_items
LIMIT 5;

/* ---------------------------------------------------------------------
   D. CONDITIONAL FUNCTIONS: CASE, IF, IFNULL, COALESCE, NULLIF
   --------------------------------------------------------------------- */
SELECT  row_id,
        sales,
        profit,
        discount,
        IF(profit >= 0, 'Profit', 'Loss')                          AS profit_flag,
        CASE
            WHEN profit >= 500 THEN 'High profit'
            WHEN profit >= 0   THEN 'Low profit'
            WHEN profit > -500 THEN 'Small loss'
            ELSE                    'Big loss'
        END                                                        AS profit_class,
        ROUND(profit / NULLIF(sales, 0) * 100, 2)                  AS margin_pct  -- NULLIF avoids divide-by-zero
FROM    order_items
LIMIT 10;

-- IFNULL / COALESCE replace NULL – here NULL comes from the LEFT JOIN
SELECT  o.order_id,
        IFNULL(r.returned, 'No')               AS returned_ifnull,
        COALESCE(r.returned, 'No')             AS returned_coalesce
FROM        orders  o
LEFT JOIN   returns r ON r.order_id = o.order_id
LIMIT 10;

/* ---------------------------------------------------------------------
   E. JOINS
   --------------------------------------------------------------------- */
-- INNER JOIN: only orders that WERE returned (expected 296 orders)
SELECT  COUNT(*) AS returned_orders
FROM        orders  o
INNER JOIN  returns r ON r.order_id = o.order_id;

-- LEFT JOIN + IS NULL: orders that were NOT returned (expected 4713)
SELECT  COUNT(*) AS not_returned_orders
FROM        orders  o
LEFT JOIN   returns r ON r.order_id = o.order_id
WHERE       r.order_id IS NULL;

-- Return rate by region (multi-table join, conditional aggregation)
SELECT  o.region,
        COUNT(*)                                                     AS orders,
        SUM(CASE WHEN r.order_id IS NOT NULL THEN 1 ELSE 0 END)      AS returned_orders,
        ROUND(AVG(CASE WHEN r.order_id IS NOT NULL THEN 1 ELSE 0 END) * 100, 2) AS return_rate_pct
FROM        orders  o
LEFT JOIN   returns r ON r.order_id = o.order_id
GROUP BY    o.region
ORDER BY    return_rate_pct DESC;

-- SELF JOIN: pairs of customers living in the same city (first 10)
SELECT  a.customer_id AS customer_1, b.customer_id AS customer_2, a.city
FROM   (SELECT DISTINCT customer_id, city FROM orders) a
JOIN   (SELECT DISTINCT customer_id, city FROM orders) b
       ON a.city = b.city AND a.customer_id < b.customer_id
LIMIT 10;

/* ---------------------------------------------------------------------
   F. SUBQUERIES
   --------------------------------------------------------------------- */
-- Scalar subquery: order lines whose sales are above the average line
SELECT COUNT(*) AS lines_above_average
FROM   order_items
WHERE  sales > (SELECT AVG(sales) FROM order_items);

-- IN subquery: customers who have at least one returned order
SELECT COUNT(DISTINCT customer_id) AS customers_with_returns
FROM   orders
WHERE  order_id IN (SELECT order_id FROM returns);

-- EXISTS: products sold at least once with a discount of 70% or more
SELECT p.product_name
FROM   products p
WHERE  EXISTS (SELECT 1 FROM order_items oi
               WHERE oi.product_key = p.product_key AND oi.discount >= 0.70)
LIMIT 10;

-- Correlated subquery: each customer's biggest single order line
SELECT  c.customer_name,
        (SELECT MAX(oi.sales)
         FROM   order_items oi
         JOIN   orders o ON o.order_id = oi.order_id
         WHERE  o.customer_id = c.customer_id) AS biggest_line_sale
FROM    customers c
ORDER BY biggest_line_sale DESC
LIMIT 5;

-- Top 10 customers by sales (derived table)
SELECT *
FROM  (SELECT customer_name, segment,
              ROUND(SUM(sales), 2)  AS total_sales,
              ROUND(SUM(profit), 2) AS total_profit
       FROM   vw_sales
       GROUP  BY customer_id, customer_name, segment) t
ORDER BY total_sales DESC
LIMIT 10;

/* ---------------------------------------------------------------------
   G. SET OPERATORS
   UNION / UNION ALL : all MySQL versions
   INTERSECT / EXCEPT: MySQL 8.0.31 or newer (check with SELECT VERSION();)
   --------------------------------------------------------------------- */
SELECT VERSION();

-- UNION (removes duplicates): customers who bought Technology OR were in the West
SELECT customer_id FROM vw_sales WHERE category = 'Technology'
UNION
SELECT customer_id FROM vw_sales WHERE region = 'West';

-- UNION ALL keeps duplicates (much larger count)
SELECT COUNT(*) AS rows_union_all FROM (
    SELECT customer_id FROM vw_sales WHERE category = 'Technology'
    UNION ALL
    SELECT customer_id FROM vw_sales WHERE region = 'West') x;

-- INTERSECT: customers who bought BOTH Furniture AND Technology
SELECT customer_id FROM vw_sales WHERE category = 'Furniture'
INTERSECT
SELECT customer_id FROM vw_sales WHERE category = 'Technology';

-- EXCEPT: customers who bought Furniture but NEVER Technology
SELECT customer_id FROM vw_sales WHERE category = 'Furniture'
EXCEPT
SELECT customer_id FROM vw_sales WHERE category = 'Technology';

-- For MySQL older than 8.0.31 the same results can be written as:
SELECT DISTINCT customer_id FROM vw_sales
WHERE  category = 'Furniture'
  AND  customer_id IN     (SELECT customer_id FROM vw_sales WHERE category = 'Technology');   -- = INTERSECT
SELECT DISTINCT customer_id FROM vw_sales
WHERE  category = 'Furniture'
  AND  customer_id NOT IN (SELECT customer_id FROM vw_sales WHERE category = 'Technology');   -- = EXCEPT

/* ---------------------------------------------------------------------
   H. DML + TRANSACTION CONTROL (TCL)
   Changes are made inside a transaction and then ROLLED BACK,
   so the real data is not altered.
   --------------------------------------------------------------------- */
START TRANSACTION;
    INSERT INTO regions (region, manager_name) VALUES ('North', 'Test Manager');   -- INSERT
    UPDATE regions SET manager_name = 'Changed Name' WHERE region = 'North';       -- UPDATE
    SELECT * FROM regions;                                                          -- see the change
    DELETE FROM regions WHERE region = 'North';                                    -- DELETE
ROLLBACK;                                                                          -- undo everything
SELECT * FROM regions;                                                              -- back to 4 rows

-- A foreign key protects integrity: this fails because region 'Mars' does not exist
-- INSERT INTO orders VALUES ('XX-0000-1','2020-01-01','2020-01-02','Same Day','CG-12520','United States','X','Y','00000','Mars');

/* ---------------------------------------------------------------------
   I. SCHEMA OBJECTS & DATA DICTIONARY (INFORMATION_SCHEMA)
   Schema objects in this project: tables, view (vw_sales), indexes,
   constraints (PK, FK, UNIQUE, CHECK).
   --------------------------------------------------------------------- */
-- All tables and views with approximate row counts
SELECT  TABLE_NAME, TABLE_TYPE, TABLE_ROWS, ENGINE
FROM    INFORMATION_SCHEMA.TABLES
WHERE   TABLE_SCHEMA = 'superstore_db'
ORDER BY TABLE_TYPE, TABLE_NAME;

-- Column definitions of one table
SELECT  COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION, NUMERIC_SCALE, IS_NULLABLE, COLUMN_KEY
FROM    INFORMATION_SCHEMA.COLUMNS
WHERE   TABLE_SCHEMA = 'superstore_db' AND TABLE_NAME = 'order_items'
ORDER BY ORDINAL_POSITION;

-- All constraints
SELECT  TABLE_NAME, CONSTRAINT_NAME, CONSTRAINT_TYPE
FROM    INFORMATION_SCHEMA.TABLE_CONSTRAINTS
WHERE   TABLE_SCHEMA = 'superstore_db'
ORDER BY TABLE_NAME, CONSTRAINT_TYPE;

-- Foreign key relationships (child column -> parent column)
SELECT  TABLE_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
FROM    INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE   TABLE_SCHEMA = 'superstore_db' AND REFERENCED_TABLE_NAME IS NOT NULL;

-- Indexes
SELECT  TABLE_NAME, INDEX_NAME, COLUMN_NAME, NON_UNIQUE
FROM    INFORMATION_SCHEMA.STATISTICS
WHERE   TABLE_SCHEMA = 'superstore_db'
ORDER BY TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX;

-- Views
SELECT TABLE_NAME, VIEW_DEFINITION FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_SCHEMA = 'superstore_db';

-- Short-cut commands
DESCRIBE order_items;
SHOW CREATE TABLE orders;
SHOW INDEX FROM orders;

/* ---------------------------------------------------------------------
   J. ACCESS CONTROL (DCL) – run as root / admin
   Principle of least privilege: an analyst only needs to READ.
   --------------------------------------------------------------------- */
DROP USER IF EXISTS 'analyst_user'@'localhost';
CREATE USER 'analyst_user'@'localhost' IDENTIFIED BY 'Analyst@2026';
GRANT SELECT ON superstore_db.* TO 'analyst_user'@'localhost';              -- read-only on the whole database
SHOW GRANTS FOR 'analyst_user'@'localhost';

DROP USER IF EXISTS 'report_user'@'localhost';
CREATE USER 'report_user'@'localhost' IDENTIFIED BY 'Report@2026';
GRANT SELECT ON superstore_db.vw_sales TO 'report_user'@'localhost';        -- can see ONLY the view
SHOW GRANTS FOR 'report_user'@'localhost';

REVOKE SELECT ON superstore_db.* FROM 'analyst_user'@'localhost';           -- take the right away again
SHOW GRANTS FOR 'analyst_user'@'localhost';

-- Clean up the demo users
DROP USER 'analyst_user'@'localhost';
DROP USER 'report_user'@'localhost';

/* ---------------------------------------------------------------------
   K. EFFICIENT HANDLING OF LARGER DATASETS
   1. Index columns used in WHERE / JOIN / GROUP BY (see file 03).
   2. Check the query plan with EXPLAIN – look for type = ref/range
      instead of ALL (full table scan).
   3. Select only needed columns (avoid SELECT *), use LIMIT while testing.
   4. Bulk load with LOAD DATA INFILE and batch INSERTs in transactions.
   5. Use exact DECIMAL types and correct lengths to keep rows small.
   --------------------------------------------------------------------- */
EXPLAIN
SELECT  order_id, order_date
FROM    orders
WHERE   order_date BETWEEN '2020-01-01' AND '2020-03-31';    -- uses idx_orders_date

EXPLAIN ANALYZE                                              -- MySQL 8.0.18+: real execution time
SELECT  p.category, SUM(oi.sales)
FROM    order_items oi
JOIN    products p ON p.product_key = oi.product_key
GROUP BY p.category;
