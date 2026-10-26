/* =====================================================================
   PROJECT : Retail Sales Performance and Profitability Analysis
   FILE    : 01_create_database_and_tables.sql
   PURPOSE : DDL – create the database, a staging table for the cleaned
             CSV, and normalised tables with PRIMARY and FOREIGN keys.
   DBMS    : MySQL 8.0 (tested syntax for 8.0.x; INTERSECT/EXCEPT used
             in file 05 need 8.0.31 or newer)
   RUN     : MySQL Workbench > File > Open SQL Script > this file >
             click the lightning icon (Execute all).
   ===================================================================== */

-- ---------------------------------------------------------------------
-- 1. Create the database (schema) and select it
-- ---------------------------------------------------------------------
DROP DATABASE IF EXISTS superstore_db;          -- start fresh every time the script runs
CREATE DATABASE superstore_db
    CHARACTER SET utf8mb4                       -- utf8mb4 stores every character (é, ’ …)
    COLLATE utf8mb4_0900_ai_ci;
USE superstore_db;

-- ---------------------------------------------------------------------
-- 2. STAGING TABLES – one-to-one copy of the cleaned CSV files.
--    We load raw data here first, then split it into proper tables.
-- ---------------------------------------------------------------------
CREATE TABLE stg_orders (
    row_id         INT            NOT NULL,
    order_id       VARCHAR(20)    NOT NULL,
    order_date     DATE           NOT NULL,
    ship_date      DATE           NOT NULL,
    ship_mode      VARCHAR(20)    NOT NULL,
    customer_id    VARCHAR(10)    NOT NULL,
    customer_name  VARCHAR(60)    NOT NULL,
    segment        VARCHAR(20)    NOT NULL,
    country        VARCHAR(30)    NOT NULL,
    city           VARCHAR(40)    NOT NULL,
    state          VARCHAR(30)    NOT NULL,
    postal_code    CHAR(5)        NOT NULL,     -- text, so leading zeros (e.g. 01852) are kept
    region         VARCHAR(10)    NOT NULL,
    product_id     VARCHAR(20)    NOT NULL,
    category       VARCHAR(20)    NOT NULL,
    sub_category   VARCHAR(20)    NOT NULL,
    product_name   VARCHAR(255)   NOT NULL,
    sales          DECIMAL(12,4)  NOT NULL,     -- DECIMAL = exact money arithmetic (FLOAT is approximate)
    quantity       INT            NOT NULL,
    discount       DECIMAL(4,2)   NOT NULL,
    profit         DECIMAL(12,4)  NOT NULL,
    PRIMARY KEY (row_id)
);

CREATE TABLE stg_returns (
    order_id   VARCHAR(20) NOT NULL,
    returned   VARCHAR(3)  NOT NULL
);

CREATE TABLE stg_people (
    person   VARCHAR(60) NOT NULL,
    region   VARCHAR(10) NOT NULL
);

-- ---------------------------------------------------------------------
-- 3. NORMALISED TABLES (3NF-style star around order_items)
--
--    regions 1 ──< orders >── 1 customers
--                    1
--                    │
--                    ^
--               order_items >── 1 products
--    orders 1 ──── 0..1 returns
-- ---------------------------------------------------------------------
CREATE TABLE regions (
    region        VARCHAR(10)  NOT NULL,
    manager_name  VARCHAR(60)  NOT NULL,
    CONSTRAINT pk_regions PRIMARY KEY (region)
);

CREATE TABLE customers (
    customer_id    VARCHAR(10)  NOT NULL,
    customer_name  VARCHAR(60)  NOT NULL,
    segment        VARCHAR(20)  NOT NULL,
    CONSTRAINT pk_customers PRIMARY KEY (customer_id),
    CONSTRAINT chk_segment CHECK (segment IN ('Consumer','Corporate','Home Office'))
);

/* In the source data 32 Product IDs are linked to more than one Product Name.
   We do NOT guess which name is correct. Instead each distinct
   (product_id, product_name) pair gets its own surrogate key. */
CREATE TABLE products (
    product_key    INT           NOT NULL AUTO_INCREMENT,
    product_id     VARCHAR(20)   NOT NULL,
    product_name   VARCHAR(255)  NOT NULL,
    category       VARCHAR(20)   NOT NULL,
    sub_category   VARCHAR(20)   NOT NULL,
    CONSTRAINT pk_products PRIMARY KEY (product_key),
    CONSTRAINT uq_product UNIQUE (product_id, product_name)
);

CREATE TABLE orders (
    order_id      VARCHAR(20)  NOT NULL,
    order_date    DATE         NOT NULL,
    ship_date     DATE         NOT NULL,
    ship_mode     VARCHAR(20)  NOT NULL,
    customer_id   VARCHAR(10)  NOT NULL,
    country       VARCHAR(30)  NOT NULL,
    city          VARCHAR(40)  NOT NULL,
    state         VARCHAR(30)  NOT NULL,
    postal_code   CHAR(5)      NOT NULL,
    region        VARCHAR(10)  NOT NULL,
    CONSTRAINT pk_orders PRIMARY KEY (order_id),
    CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES customers (customer_id),
    CONSTRAINT fk_orders_region   FOREIGN KEY (region)      REFERENCES regions (region),
    CONSTRAINT chk_ship_after_order CHECK (ship_date >= order_date)
);

CREATE TABLE order_items (
    row_id       INT            NOT NULL,
    order_id     VARCHAR(20)    NOT NULL,
    product_key  INT            NOT NULL,
    sales        DECIMAL(12,4)  NOT NULL,
    quantity     INT            NOT NULL,
    discount     DECIMAL(4,2)   NOT NULL,
    profit       DECIMAL(12,4)  NOT NULL,
    CONSTRAINT pk_order_items PRIMARY KEY (row_id),
    CONSTRAINT fk_items_order   FOREIGN KEY (order_id)    REFERENCES orders (order_id),
    CONSTRAINT fk_items_product FOREIGN KEY (product_key) REFERENCES products (product_key),
    CONSTRAINT chk_quantity CHECK (quantity > 0),
    CONSTRAINT chk_discount CHECK (discount BETWEEN 0 AND 1)
);

CREATE TABLE returns (
    order_id   VARCHAR(20) NOT NULL,
    returned   VARCHAR(3)  NOT NULL DEFAULT 'Yes',
    CONSTRAINT pk_returns PRIMARY KEY (order_id),
    CONSTRAINT fk_returns_order FOREIGN KEY (order_id) REFERENCES orders (order_id)
);

-- Verify: should list 9 tables
SHOW TABLES;
