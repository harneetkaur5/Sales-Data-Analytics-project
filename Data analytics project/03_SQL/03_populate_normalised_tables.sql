/* =====================================================================
   FILE    : 03_populate_normalised_tables.sql
   PURPOSE : DML – move data from the staging tables into the normalised
             tables (INSERT … SELECT), then create a reporting VIEW and
             indexes.
   ORDER   : parent tables first (regions, customers, products, orders),
             child tables last (order_items, returns) – otherwise the
             FOREIGN KEY constraints would reject the rows.
   ===================================================================== */
USE superstore_db;

-- 1. regions (parent of orders)
INSERT INTO regions (region, manager_name)
SELECT region, person
FROM   stg_people;

-- 2. customers – one row per customer (each customer has one name & segment)
INSERT INTO customers (customer_id, customer_name, segment)
SELECT DISTINCT customer_id, customer_name, segment
FROM   stg_orders;

-- 3. products – one row per distinct (product_id, product_name) pair
INSERT INTO products (product_id, product_name, category, sub_category)
SELECT DISTINCT product_id, product_name, category, sub_category
FROM   stg_orders
ORDER  BY product_id, product_name;

-- 4. orders – order-level columns (each order has one date, customer, address)
INSERT INTO orders (order_id, order_date, ship_date, ship_mode, customer_id,
                    country, city, state, postal_code, region)
SELECT DISTINCT order_id, order_date, ship_date, ship_mode, customer_id,
                country, city, state, postal_code, region
FROM   stg_orders;

-- 5. order_items – one row per order line; look up the surrogate product_key
INSERT INTO order_items (row_id, order_id, product_key, sales, quantity, discount, profit)
SELECT s.row_id, s.order_id, p.product_key, s.sales, s.quantity, s.discount, s.profit
FROM   stg_orders AS s
JOIN   products   AS p
       ON  p.product_id   = s.product_id
       AND p.product_name = s.product_name;

-- 6. returns – only orders that exist in the orders table
INSERT INTO returns (order_id, returned)
SELECT DISTINCT r.order_id, r.returned
FROM   stg_returns AS r
WHERE  r.order_id IN (SELECT order_id FROM orders);

-- ---------------------------------------------------------------------
-- 7. VERIFY – expected: regions 4, customers 793, products 1894,
--    orders 5009, order_items 9993, returns 296
-- ---------------------------------------------------------------------
SELECT 'regions'     AS table_name, COUNT(*) AS row_count FROM regions
UNION ALL SELECT 'customers',   COUNT(*) FROM customers
UNION ALL SELECT 'products',    COUNT(*) FROM products
UNION ALL SELECT 'orders',      COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'returns',     COUNT(*) FROM returns;

-- Totals must be identical to the staging table (no rows lost in the joins)
SELECT SUM(sales) AS total_sales, SUM(profit) AS total_profit FROM order_items;

-- ---------------------------------------------------------------------
-- 8. REPORTING VIEW – joins everything back into one wide, easy table.
--    A view stores the query, not the data, so it is always up to date.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_sales AS
SELECT  oi.row_id,
        o.order_id,
        o.order_date,
        o.ship_date,
        o.ship_mode,
        c.customer_id,
        c.customer_name,
        c.segment,
        o.city,
        o.state,
        o.postal_code,
        o.region,
        r.manager_name,
        p.product_id,
        p.product_name,
        p.category,
        p.sub_category,
        oi.sales,
        oi.quantity,
        oi.discount,
        oi.profit,
        CASE WHEN rt.order_id IS NULL THEN 'No' ELSE 'Yes' END AS returned
FROM        order_items oi
INNER JOIN  orders      o  ON o.order_id     = oi.order_id
INNER JOIN  customers   c  ON c.customer_id  = o.customer_id
INNER JOIN  products    p  ON p.product_key  = oi.product_key
INNER JOIN  regions     r  ON r.region       = o.region
LEFT  JOIN  returns     rt ON rt.order_id    = o.order_id;   -- LEFT JOIN keeps orders that were NOT returned

SELECT COUNT(*) AS rows_in_view FROM vw_sales;   -- expected 9993

-- ---------------------------------------------------------------------
-- 9. INDEXES – speed up the columns we filter / group / join on most.
--    (Primary keys and foreign keys are indexed automatically in InnoDB.)
-- ---------------------------------------------------------------------
CREATE INDEX idx_orders_date      ON orders (order_date);
CREATE INDEX idx_products_cat_sub ON products (category, sub_category);
CREATE INDEX idx_customers_seg    ON customers (segment);
