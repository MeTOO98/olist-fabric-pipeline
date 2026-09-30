-- First i will create Gold.ETL.Control 

Drop TABLE if EXISTS Gold.Etl_Control;

Create Table Gold.Etl_Control (
table_name VARCHAR(100) ,
max_created_at DATETIME2(6),
max_last_modified_at DATETIME2(6),
last_load_timestamp DATETIME2(6)
);

-- Then i will create stored procedure to insert data inside this table 

CREATE PROCEDURE Gold.sp_capture_initial_watermarks
AS
BEGIN
    -- Clear any old entries
    TRUNCATE TABLE Gold.Etl_Control;

    -- 1. Customers
    INSERT INTO Gold.Etl_Control (table_name, max_created_at, max_last_modified_at, last_load_timestamp)
    SELECT 
        'customers',
        MAX(created_at),
        MAX(last_modified_at),
        MAX(last_modified_at)  
    FROM olist_Lakehouse.silver.customers;

    -- 2. Orders
    INSERT INTO Gold.Etl_Control (table_name, max_created_at, max_last_modified_at, last_load_timestamp)
    SELECT 
        'orders',
        MAX(created_at),
        MAX(last_modified_at),
        MAX(last_modified_at)
    FROM olist_Lakehouse.silver.orders;

    -- 3. Order Items
    INSERT INTO Gold.Etl_Control (table_name, max_created_at, max_last_modified_at, last_load_timestamp)
    SELECT 
        'order_items',
        MAX(created_at),
        MAX(last_modified_at),
        MAX(last_modified_at)
    FROM olist_Lakehouse.silver.order_items;

    -- 4. Order Payments
    INSERT INTO Gold.Etl_Control (table_name, max_created_at, max_last_modified_at, last_load_timestamp)
    SELECT 
        'order_payments',
        MAX(created_at),
        MAX(last_modified_at),
        MAX(last_modified_at)
    FROM olist_Lakehouse.silver.order_payments;

    -- 5. Order Reviews
    INSERT INTO Gold.Etl_Control (table_name, max_created_at, max_last_modified_at, last_load_timestamp)
    SELECT 
        'order_reviews',
        MAX(created_at),
        MAX(last_modified_at),
        MAX(last_modified_at)
    FROM olist_Lakehouse.silver.order_reviews;
END;


