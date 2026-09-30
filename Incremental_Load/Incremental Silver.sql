-- First I will create silver layer 

CREATE SCHEMA silver_incremental; 

-- Then i will create different tables 

select * from staging_incremental.customers

CREATE TABLE silver_incremental.customers (
    customer_id VARCHAR(50),
    customer_unique_id VARCHAR(50),
    customer_city VARCHAR(100),
    customer_state VARCHAR(5),
    customer_zip_code_prefix VARCHAR(10),
    silver_loaded_date DATETIME2(6),
    silver_source_table VARCHAR(100)
);

select * from staging_incremental.orders

CREATE TABLE silver_incremental.orders (
    order_id VARCHAR(50),
    customer_id VARCHAR(50),
    order_status VARCHAR(50),
    order_purchase_timestamp DATETIME2(6),
    order_approved_at DATETIME2(6),
    order_delivered_carrier_date DATETIME2(6),
    order_delivered_customer_date DATETIME2(6),
    order_estimated_delivery_date DATETIME2(6),
    silver_loaded_date DATETIME2(6),
    silver_source_table VARCHAR(100)
);

select * from staging_incremental.order_items

CREATE TABLE silver_incremental.order_items (
    order_id VARCHAR(50),
    order_item_id INT,
    product_id VARCHAR(50),
    seller_id VARCHAR(50),
    shipping_limit_date DATETIME2(6),
    price DECIMAL(18,2),
    freight_value DECIMAL(18,2),
    silver_loaded_date DATETIME2(6),
    silver_source_table VARCHAR(100)
);

select * from staging_incremental.order_payments

CREATE TABLE silver_incremental.order_payments (
    order_id VARCHAR(50),
    payment_sequential INT,
    payment_type VARCHAR(50),
    payment_installments INT,
    payment_value DECIMAL(18,2),
    silver_loaded_date DATETIME2(6),
    silver_source_table VARCHAR(100)
);

select * from staging_incremental.order_reviews

CREATE TABLE silver_incremental.order_reviews (
    review_id VARCHAR(50),
    order_id VARCHAR(50),
    review_score INT,
    review_comment_title VARCHAR(500),
    review_comment_message VARCHAR(5000),
    review_creation_date DATETIME2(6),
    review_answer_timestamp DATETIME2(6),
    silver_loaded_date DATETIME2(6),
    silver_source_table VARCHAR(100)
);

-- Now i will make stored procedures to make transformations that each table needs and i will begin with customers

select * from staging_incremental.customers;


CREATE PROCEDURE silver_incremental.sp_clean_customers
AS
BEGIN
    SET NOCOUNT ON;

    WITH source_data AS (
        SELECT
            LOWER(TRIM(customer_id)) AS customer_id,
            LOWER(TRIM(customer_unique_id)) AS customer_unique_id,
            COALESCE(
                NULLIF(REPLACE(LOWER(TRIM(customer_city)), '  ', ' '), ''),
                'unknown'
            ) AS customer_city,
            CASE
                WHEN LEN(TRIM(customer_state)) = 2 THEN UPPER(TRIM(customer_state))
                ELSE 'UN'
            END AS customer_state,
            RIGHT('00000' + COALESCE(CAST(customer_zip_code_prefix AS VARCHAR(10)), '0'), 5) AS customer_zip_code_prefix,
            ROW_NUMBER() OVER (
                PARTITION BY LOWER(TRIM(customer_id))    
                ORDER BY (SELECT NULL)
            ) AS rn
        FROM staging_incremental.customers
        WHERE NULLIF(TRIM(customer_id), '') IS NOT NULL
          AND NULLIF(TRIM(customer_unique_id), '') IS NOT NULL
          AND LEN(NULLIF(TRIM(customer_id), '')) = 32
    )
    INSERT INTO silver_incremental.customers (
        customer_id, customer_unique_id, customer_city, customer_state,
        customer_zip_code_prefix, silver_loaded_date, silver_source_table
    )
    SELECT
        customer_id,
        customer_unique_id,
        customer_city,
        customer_state,
        customer_zip_code_prefix,
        GETDATE(),
        'staging_incremental.customers'
    FROM source_data
    WHERE rn = 1;                                    

    
END;
         

-- Let's go with orders table 

select * from staging_incremental.orders;

CREATE PROCEDURE silver_incremental.sp_clean_orders
AS
BEGIN
    SET NOCOUNT ON;

    WITH source_data AS (
        SELECT
            LOWER(TRIM(order_id)) AS order_id,
            LOWER(TRIM(customer_id)) AS customer_id,
            COALESCE(NULLIF(LOWER(TRIM(order_status)), ''), 'unknown') AS order_status,
            CAST(order_purchase_timestamp AS DATETIME2) AS order_purchase_timestamp,
            CAST(order_approved_at AS DATETIME2) AS order_approved_at,
            CAST(order_delivered_carrier_date AS DATETIME2) AS order_delivered_carrier_date,
            CAST(order_delivered_customer_date AS DATETIME2) AS order_delivered_customer_date,
            CAST(order_estimated_delivery_date AS DATETIME2) AS order_estimated_delivery_date,
            CASE
                WHEN order_delivered_customer_date < order_purchase_timestamp THEN 1
                WHEN order_delivered_carrier_date < order_purchase_timestamp THEN 1
                WHEN order_approved_at < order_purchase_timestamp THEN 1
                ELSE 0
            END AS date_logic_error,
            ROW_NUMBER() OVER (
                PARTITION BY LOWER(TRIM(order_id))    
                ORDER BY order_purchase_timestamp DESC
            ) AS rn
        FROM staging_incremental.orders
        WHERE NULLIF(TRIM(order_id), '') IS NOT NULL
          AND NULLIF(TRIM(customer_id), '') IS NOT NULL
          AND order_purchase_timestamp >= '2016-01-01'
          AND order_purchase_timestamp <= GETDATE()
    )
    INSERT INTO silver_incremental.orders (
        order_id, customer_id, order_status,
        order_purchase_timestamp, order_approved_at,
        order_delivered_carrier_date, order_delivered_customer_date,
        order_estimated_delivery_date, silver_loaded_date, silver_source_table
    )
    SELECT
        order_id,
        customer_id,
        order_status,
        order_purchase_timestamp,
        order_approved_at,
        order_delivered_carrier_date,
        order_delivered_customer_date,
        order_estimated_delivery_date,
        GETDATE(),
        'staging_incremental.orders'
    FROM source_data
    WHERE rn = 1                                    
      AND date_logic_error = 0;                    

    
END;

-- let's go with order_items table 

select * from staging_incremental.order_items

CREATE PROCEDURE silver_incremental.sp_clean_order_items
AS
BEGIN
    SET NOCOUNT ON;

    WITH deduped AS (
        SELECT
            LOWER(TRIM(order_id)) AS order_id,
            order_item_id,
            LOWER(TRIM(product_id)) AS product_id,
            LOWER(TRIM(seller_id)) AS seller_id,
            CAST(shipping_limit_date AS DATETIME2) AS shipping_limit_date,
            CASE
                WHEN price <= 0 THEN NULL
                ELSE price
            END AS price,
            CASE WHEN freight_value < 0 THEN 0 ELSE ISNULL(freight_value, 0) END AS freight_value,
            ROW_NUMBER() OVER (
                PARTITION BY LOWER(TRIM(order_id)), order_item_id
                ORDER BY (SELECT NULL)
            ) AS rn
        FROM staging_incremental.order_items
        WHERE NULLIF(TRIM(order_id), '') IS NOT NULL
          AND order_item_id IS NOT NULL
          AND NULLIF(TRIM(product_id), '') IS NOT NULL
          AND NULLIF(TRIM(seller_id), '') IS NOT NULL
    ),
    medians AS (
        SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price) OVER () AS median_price
        FROM deduped
    )
    INSERT INTO silver_incremental.order_items (
        order_id, order_item_id, product_id, seller_id,
        shipping_limit_date, price, freight_value,
        silver_loaded_date, silver_source_table
    )
    SELECT
        order_id,
        order_item_id,
        product_id,
        seller_id,
        shipping_limit_date,
        ISNULL(price, (SELECT TOP 1 median_price FROM medians)) AS price,
        freight_value,
        GETDATE(),
        'staging_incremental.order_items'
    FROM deduped
    WHERE rn = 1
      AND (shipping_limit_date IS NULL OR shipping_limit_date >= '2016-01-01')
      AND (shipping_limit_date IS NULL OR shipping_limit_date <= GETDATE());

END;

-- let's go with order_payments table 

select * from staging_incremental.order_payments

CREATE PROCEDURE silver_incremental.sp_clean_order_payments
AS
BEGIN
    SET NOCOUNT ON;

    WITH deduped AS (
        SELECT
            LOWER(TRIM(order_id)) AS order_id,
            payment_sequential,
            COALESCE(NULLIF(TRIM(LOWER(payment_type)), ''), 'Not Defined') AS payment_type,
            CASE WHEN payment_installments <= 0 OR payment_installments IS NULL THEN 1 ELSE payment_installments END AS payment_installments,
            payment_value,
            ROW_NUMBER() OVER (
                PARTITION BY LOWER(TRIM(order_id)), payment_sequential
                ORDER BY (SELECT NULL)
            ) AS rn
        FROM staging_incremental.order_payments
        WHERE NULLIF(TRIM(order_id), '') IS NOT NULL
          AND payment_sequential IS NOT NULL
          AND payment_value >= 0
    ),
    medians AS (
        SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY payment_value) OVER () AS median_value
        FROM deduped
    )
    INSERT INTO silver_incremental.order_payments (
        order_id, payment_sequential, payment_type, payment_installments,
        payment_value, silver_loaded_date, silver_source_table
    )
    SELECT
        order_id,
        payment_sequential,
        payment_type,
        payment_installments,
        ISNULL(payment_value, (SELECT TOP 1 median_value FROM medians)) AS payment_value,
        GETDATE(),
        'staging_incremental.order_payments'
    FROM deduped
    WHERE rn = 1;

END;

-- let's go with order_reviews table 

select * from staging_incremental.order_reviews

CREATE PROCEDURE silver_incremental.sp_clean_order_reviews
AS
BEGIN
    SET NOCOUNT ON;

    WITH source_data AS (
        SELECT
            LOWER(TRIM(review_id)) AS review_id,
            LOWER(TRIM(order_id)) AS order_id,
            review_score,
            NULLIF(TRIM(review_comment_title), '') AS review_comment_title,
            NULLIF(TRIM(review_comment_message), '') AS review_comment_message,
            CAST(review_creation_date AS DATETIME2) AS review_creation_date,
            CAST(review_answer_timestamp AS DATETIME2) AS review_answer_timestamp,
            CASE
                WHEN review_answer_timestamp < review_creation_date THEN 1
                ELSE 0
            END AS review_date_error,
            ROW_NUMBER() OVER (
                PARTITION BY LOWER(TRIM(review_id))    
                ORDER BY review_creation_date DESC
            ) AS rn
        FROM staging_incremental.order_reviews
        WHERE NULLIF(TRIM(review_id), '') IS NOT NULL
          AND NULLIF(TRIM(order_id), '') IS NOT NULL
          AND review_creation_date >= '2016-01-01'
          AND (review_score >= 1 AND review_score <= 5 OR review_score IS NULL)
    )
    INSERT INTO silver_incremental.order_reviews (
        review_id, order_id, review_score, review_comment_title,
        review_comment_message, review_creation_date, review_answer_timestamp,
        silver_loaded_date, silver_source_table
    )
    SELECT
        review_id,
        order_id,
        review_score,
        review_comment_title,
        review_comment_message,
        review_creation_date,
        review_answer_timestamp,
        GETDATE(),
        'staging_incremental.order_reviews'
    FROM source_data
    WHERE rn = 1                                   
      AND review_date_error = 0;
END;

