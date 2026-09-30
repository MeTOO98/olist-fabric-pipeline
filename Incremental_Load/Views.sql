-- First I will create a Schema to these views 

CREATE SCHEMA views

-- Now i will create a view to each table and i will start will customers

select * from Gold.dim_customers

CREATE VIEW views.v_dim_customers AS
SELECT 
    Customer_Sk AS customer_sk,                 
    Customer_Id AS customer_id,
    Customer_Unique_Id AS customer_unique_id,
    Customer_City AS customer_city,
    Customer_State AS customer_state,
    Customer_Zip_Code_Prefix AS customer_zip_code_prefix
FROM Gold.dim_customers;

-- Now let's go with sellers 

select * from Gold.dim_sellers

CREATE VIEW views.v_dim_sellers AS
SELECT 
    Seller_Sk AS seller_sk,                    
    Seller_Id AS seller_id,
    Seller_City AS seller_city,
    Seller_State AS seller_state,
    Seller_Zip_Code_Prefix AS seller_zip_code_prefix,
    Seller_Lat AS seller_lat,
    Seller_Lng AS seller_lng
FROM Gold.dim_sellers;

-- Now let's go with products

select * from Gold.dim_products

CREATE VIEW views.v_dim_products AS
SELECT 
    Product_Sk AS product_sk,                  
    Product_Id AS product_id,
    Product_Category_Name AS product_category_name,
    Product_Category_Name_English AS product_category_name_english,
    Product_Name_Length AS product_name_length,
    Product_Description_Length AS product_description_length,
    Product_Photos_Qty AS product_photos_qty,
    Product_Weight_G AS product_weight_g,
    Product_Length_cm AS product_length_cm,
    Product_Height_cm AS product_height_cm,
    Product_Width_cm AS product_width_cm
FROM Gold.dim_products;

-- Now let's go with orders

select * from Gold.fact_orders

CREATE VIEW views.v_fact_orders AS
SELECT 
    Order_Sk AS order_sk,                      
    Order_Id AS order_id,
    Customer_Sk AS customer_sk,                
    Order_Status AS order_status,
    Order_Purchase_Timestamp AS order_purchase_date,
    Order_Approved_At AS order_approved_date,
    Order_Delivered_Carrier_Date AS delivered_carrier_date,
    Order_Delivered_Customer_Date AS delivered_customer_date,
    Order_Estimated_Delivery_Date AS estimated_delivery_date
FROM Gold.fact_orders;

-- Now let's go with order_items

select * from Gold.fact_order_items

CREATE VIEW views.v_fact_order_items AS
SELECT 
    Order_Item_Sk AS order_item_sk,             
    Order_Id AS order_id,
    Order_Item_Id AS order_item_id,
    Product_Sk AS product_sk,                   
    Seller_Sk AS seller_sk,                     
    Shipping_Limit_Date AS shipping_limit_date,
    Price AS price,
    Freight_Value AS freight_value
FROM Gold.fact_order_items;

-- Now let's go with order_payments

select * from Gold.fact_order_payments

CREATE VIEW views.v_fact_order_payments AS
SELECT 
    Order_Payment_Sk AS order_payment_sk,
    Order_Id AS order_id,
    Payment_Sequential AS payment_sequential,
    Payment_Type AS payment_type,
    Payment_Installments AS payment_installments,
    Payment_Value AS payment_value
FROM Gold.fact_order_payments;

-- Now let's go with order_reviews

select * from Gold.fact_order_reviews

CREATE VIEW views.v_fact_order_reviews AS
SELECT 
    Order_Review_Sk AS order_review_sk,
    Review_Id AS review_id,
    Order_Id AS order_id,
    Review_Score AS review_score,
    Review_Comment_Title AS review_comment_title,
    Review_Comment_Message AS review_comment_message,
    Review_Creation_Date AS review_creation_date,
    Review_Answer_Date AS review_answer_date
FROM Gold.fact_order_reviews;

-- Here i will create date dimension 

CREATE TABLE views.dim_date (
    date DATE NOT NULL,
    year INT,
    quarter INT,
    quarter_name VARCHAR(10),
    month INT,
    month_name VARCHAR(20),
    month_short VARCHAR(10),
    month_year VARCHAR(20),
    day INT,
    day_name VARCHAR(20),
    day_short VARCHAR(10),
    is_weekend BIT,
    week_of_year INT
);

-- Now I will populate it 

DECLARE @start_date DATE = '2016-01-01';
DECLARE @end_date DATE = '2018-12-31';
DECLARE @current_date DATE = @start_date;

WHILE @current_date <= @end_date
BEGIN
    INSERT INTO views.dim_date (
        date, year, quarter, quarter_name,
        month, month_name, month_short, month_year,
        day, day_name, day_short,
        is_weekend, week_of_year
    )
    VALUES (
        @current_date,
        YEAR(@current_date),
        DATEPART(QUARTER, @current_date),
        'Q' + CAST(DATEPART(QUARTER, @current_date) AS VARCHAR(2)),
        MONTH(@current_date),
        DATENAME(MONTH, @current_date),
        LEFT(DATENAME(MONTH, @current_date), 3),
        LEFT(DATENAME(MONTH, @current_date), 3) + ' ' + CAST(YEAR(@current_date) AS VARCHAR(4)),
        DAY(@current_date),
        DATENAME(WEEKDAY, @current_date),
        LEFT(DATENAME(WEEKDAY, @current_date), 3),
        CASE WHEN DATEPART(WEEKDAY, @current_date) IN (1, 7) THEN 1 ELSE 0 END,
        DATEPART(WEEK, @current_date)
    );

    SET @current_date = DATEADD(DAY, 1, @current_date);
END;

