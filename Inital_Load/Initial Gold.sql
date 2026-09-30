-- Now I will start Create A Stored Procedure for Different Fact and dimension tables
-- I will begin with dim_customers and i will create Gold Schema inside its Stored Procedure

select * from Olist_Lakehouse.silver.customers;

CREATE PROCEDURE Gold.sp_load_dim_customers
AS
BEGIN
    -- 1. Create schema if it doesn't exist
    IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Gold')
    BEGIN
        EXEC sp_executesql N'CREATE SCHEMA Gold';
    END

    -- 2. Drop table if exists (clean start)
    DROP TABLE IF EXISTS Gold.dim_customers;

    -- 3. Create table
    CREATE TABLE Gold.dim_customers (
        Customer_Sk BIGINT IDENTITY,
        Customer_Id VARCHAR(50) NOT NULL,
        Customer_Unique_Id VARCHAR(50),
        Customer_City VARCHAR(100),
        Customer_State CHAR(2),
        Customer_Zip_Code_Prefix CHAR(5)
    );

    -- 4. Add PK (not enforced)
    ALTER TABLE Gold.dim_customers
    ADD CONSTRAINT PK_dim_customers PRIMARY KEY NONCLUSTERED (Customer_Sk) NOT ENFORCED;

    -- 5. Insert from Silver
    INSERT INTO Gold.dim_customers (
        Customer_Id,
        Customer_Unique_Id,
        Customer_City,
        Customer_State,
        Customer_Zip_Code_Prefix
    )
    SELECT
        customer_id,
        customer_unique_id,
        customer_city,
        customer_state,
        customer_zip_code_prefix
    FROM olist_Lakehouse.silver.customers;
END;

-- Now Let's go with sellers Table 

select * from olist_Lakehouse.silver.sellers;

CREATE PROCEDURE Gold.sp_load_dim_sellers
AS
BEGIN
   -- 1. Drop table if exists (clean start) 
   DROP TABLE IF EXISTS Gold.dim_sellers;

   -- 2. Create table 
   CREATE TABLE Gold.dim_sellers (
       Seller_Sk BIGINT IDENTITY NOT NULL,
       Seller_Id VARCHAR(50) NOT NULL,
       Seller_City VARCHAR(100),
       Seller_State CHAR(2),
       Seller_Zip_Code_Prefix CHAR(5),
       Seller_Lat DECIMAL(18,12),
       Seller_Lng DECIMAL(18,12)
   );

   -- 3. Add PK (not enforced) 
   ALTER TABLE Gold.dim_sellers
   ADD CONSTRAINT PK_dim_sellers PRIMARY KEY NONCLUSTERED (Seller_Sk) NOT ENFORCED;

   -- 4. Insert from Silver 
   INSERT INTO Gold.dim_sellers (
       Seller_Id,
       Seller_City,
       Seller_State,
       Seller_Zip_Code_Prefix,
       Seller_Lat,
       Seller_Lng
   )
   SELECT
       seller_id,
       seller_city,
       seller_state,
       seller_zip_code_prefix,
       geolocation_lat,
       geolocation_lng
   FROM Olist_Lakehouse.silver.sellers;
END; 

-- Now Let's go with Products Table 

select * from olist_Lakehouse.silver.products;

Create procedure Gold.sp_load_dim_products
AS
BEGIN
   -- 1. Drop table if exists (clean start) 
   DROP TABLE IF EXISTS Gold.dim_products;  

   -- 2. Create table 
   CREATE TABLE Gold.dim_products (
       Product_Sk BIGINT IDENTITY NOT NULL,
       Product_Id VARCHAR(50) NOT NULL,
       Product_Category_Name VARCHAR(100),
       Product_Category_Name_English VARCHAR(100),
       Product_Name_Length int,
       Product_Description_Length int,
       Product_Photos_Qty int,
       Product_Weight_G decimal(10,2),
       Product_Length_cm decimal(10,2),
       Product_Height_cm decimal(10,2),
       Product_Width_cm decimal(10,2)
   );

   -- 3. Add PK (not enforced) 
   ALTER TABLE Gold.dim_products
   ADD CONSTRAINT PK_dim_products PRIMARY KEY NONCLUSTERED (Product_Sk) NOT ENFORCED;

-- 4. Insert from Silver 
   INSERT INTO Gold.dim_products (
       Product_Id,
       Product_Category_Name,
       Product_Category_Name_English,
       Product_Name_Length,
       Product_Description_Length,
       Product_Photos_Qty,
       Product_Weight_G,
       Product_Length_cm,
       Product_Height_cm,
       Product_Width_cm
   )
   SELECT
       Product_id,
       product_category_name,
       product_category_name_english,
       product_name_length,
       product_description_length,
       product_photos_qty,
       product_weight_g,
       product_length_cm,
       product_height_cm,
       product_width_cm 
   FROM olist_Lakehouse.silver.products;
END; 

-- Now Let's go with Orders Table 

select * from olist_Lakehouse.silver.orders;

Create procedure Gold.sp_load_fact_orders
AS
BEGIN
   -- 1. Drop table if exists (clean start) 
   DROP TABLE IF EXISTS Gold.fact_orders;  

   -- 2. Create table 
   CREATE TABLE Gold.fact_orders (
       Order_Sk BIGINT IDENTITY NOT NULL,
       Order_Id VARCHAR(50) NOT NULL,
       Customer_Sk BIGINT,
       Order_Status VARCHAR(50),
       Order_Purchase_Timestamp date,
       Order_Approved_At date,
       Order_Delivered_Carrier_Date date,
       Order_Delivered_Customer_Date date,
       Order_Estimated_Delivery_Date date
   );

   -- 3. Add PK (not enforced) 
   ALTER TABLE Gold.fact_orders
   ADD CONSTRAINT PK_fact_orders PRIMARY KEY NONCLUSTERED (Order_Sk) NOT ENFORCED;

-- 4. Insert from Silver 
   INSERT INTO Gold.fact_orders (
       Order_Id,
       Customer_Sk,
       Order_Status,
       Order_Purchase_Timestamp,
       Order_Approved_At,
       Order_Delivered_Carrier_Date,
       Order_Delivered_Customer_Date,
       Order_Estimated_Delivery_Date
   )
   SELECT
       o.order_id,
       c.Customer_Sk,
       o.order_status,
       Cast(o.order_purchase_timestamp as date),
       Cast(o.order_approved_at as date),
       Cast(o.order_delivered_carrier_date as date),
       Cast(o.order_delivered_customer_date as date),
       Cast(o.order_estimated_delivery_date as date)  
   FROM olist_Lakehouse.silver.orders o
   inner join Gold.dim_customers c
   on o.customer_id = c.Customer_Id;
END; 

-- Now Let's go with Order_items Table 

select * from olist_Lakehouse.silver.order_items;

Create procedure Gold.sp_load_fact_order_items
AS
BEGIN
   -- 1. Drop table if exists (clean start) 
   DROP TABLE IF EXISTS Gold.fact_order_items;  

   -- 2. Create table 
   CREATE TABLE Gold.fact_order_items (
       Order_Item_Sk BIGINT IDENTITY NOT NULL,
       Order_Id VARCHAR(50) NOT NULL,
       Order_Item_Id INT NOT NULL,
       Product_Sk BIGINT,
       Seller_Sk BIGINT,
       Shipping_Limit_Date date,
       Price decimal(18,2),
       Freight_Value decimal(18,2)  
   );

   -- 3. Add PK (not enforced) 
   ALTER TABLE Gold.fact_order_items
   ADD CONSTRAINT PK_fact_order_items PRIMARY KEY NONCLUSTERED (Order_Item_Sk) NOT ENFORCED;

-- 4. Insert from Silver 
   INSERT INTO Gold.fact_order_items (
       Order_Id,
       Order_Item_Id,
       Product_Sk,
       Seller_Sk,
       Shipping_Limit_Date,
       Price,
       Freight_Value
   )
   SELECT
       o.order_id,
       o.order_item_id,
       p.Product_Sk,
       s.Seller_Sk,
       Cast(o.shipping_limit_date as date),
       o.price,
       o.freight_value
   FROM olist_Lakehouse.silver.order_items o
   inner join Gold.dim_products p
   on o.product_id = p.Product_Id
   inner join Gold.dim_sellers s 
   on o.seller_id = s.Seller_Id;
END; 

-- Now Let's go with Order_payments Table 

select * from olist_Lakehouse.silver.order_payments;

Create procedure Gold.sp_load_fact_order_payments
AS
BEGIN
   -- 1. Drop table if exists (clean start) 
   DROP TABLE IF EXISTS Gold.fact_order_payments;  

   -- 2. Create table 
   CREATE TABLE Gold.fact_order_payments (
       Order_Payment_Sk BIGINT IDENTITY NOT NULL,
       Order_Id VARCHAR(50) NOT NULL,
       Payment_Sequential INT NOT NULL,
       Payment_Type VARCHAR(50),
       Payment_Installments INT,
       Payment_Value decimal(18,2)
   );

   -- 3. Add PK (not enforced) 
   ALTER TABLE Gold.fact_order_payments
   ADD CONSTRAINT PK_fact_order_payments PRIMARY KEY NONCLUSTERED (Order_Payment_Sk) NOT ENFORCED;

-- 4. Insert from Silver 
   INSERT INTO Gold.fact_order_payments(
       Order_Id,
       Payment_Sequential,
       Payment_Type,
       Payment_Installments,
       Payment_Value
   )
   SELECT
       p.order_id,
       p.payment_sequential,
       p.payment_type,
       p.payment_installments,
       p.payment_value
   FROM olist_Lakehouse.silver.order_payments p
   inner join Gold.fact_orders o
   on p.order_id = o.Order_Id;
END; 

-- Now Let's go with Order_reviews Table 

select * from olist_Lakehouse.silver.order_reviews;

Create procedure Gold.sp_load_fact_order_reviews
AS
BEGIN
   -- 1. Drop table if exists (clean start) 
   DROP TABLE IF EXISTS Gold.fact_order_reviews;  

   -- 2. Create table 
   CREATE TABLE Gold.fact_order_reviews (
       Order_Review_Sk BIGINT IDENTITY NOT NULL,
       Review_Id VARCHAR(50) NOT NULL,
       Order_Id VARCHAR(50) NOT NULL,
       Review_Score INT,
       Review_Comment_Title VARCHAR(500),
       Review_Comment_Message VARCHAR(500),
       Review_Creation_Date Date,
       Review_Answer_Date Date 
   );

   -- 3. Add PK (not enforced) 
   ALTER TABLE Gold.fact_order_reviews
   ADD CONSTRAINT PK_fact_order_reviews PRIMARY KEY NONCLUSTERED (Order_Review_Sk) NOT ENFORCED;

-- 4. Insert from Silver 
   INSERT INTO Gold.fact_order_reviews(
       Review_Id,
       Order_Id,
       Review_Score,
       Review_Comment_Title,
       Review_Comment_Message,
       Review_Creation_Date,
       Review_Answer_Date
   )
   SELECT
       r.review_id,     
       r.order_id,
       r.review_score,
       r.review_comment_title,
       r.review_comment_message,
       cast(r.review_creation_date as date),
       cast(r.review_answer_timestamp as date)
   FROM olist_Lakehouse.silver.order_reviews r
   inner join Gold.fact_orders o
   on r.order_id = o.Order_Id;
END; 



