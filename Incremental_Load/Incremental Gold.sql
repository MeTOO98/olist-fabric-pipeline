-- Now we will go with gold layer and we will start with customers 

select * from Gold.dim_customers
select * from silver_incremental.customers

CREATE PROCEDURE Gold.sp_load_incremental_dim_customers
AS
BEGIN
    SET NOCOUNT ON;

    MERGE Gold.dim_customers AS target
    USING (
        SELECT 
            customer_id,
            customer_unique_id,
            customer_city,
            customer_state,
            customer_zip_code_prefix
        FROM silver_incremental.customers
    ) AS source
    ON target.Customer_Id = source.customer_id

    WHEN MATCHED THEN
        UPDATE SET
            target.Customer_Unique_Id = source.customer_unique_id,
            target.Customer_City = source.customer_city,
            target.Customer_State = source.customer_state,
            target.Customer_Zip_Code_Prefix = source.customer_zip_code_prefix

    WHEN NOT MATCHED THEN
        INSERT (
            Customer_Id,                        
            Customer_Unique_Id,
            Customer_City,
            Customer_State,
            Customer_Zip_Code_Prefix
        )
        VALUES (
            source.customer_id,
            source.customer_unique_id,
            source.customer_city,
            source.customer_state,
            source.customer_zip_code_prefix
        );
        
    DELETE FROM silver_incremental.customers;
    DELETE FROM staging_incremental.customers;

    UPDATE Gold.Etl_Control
    SET last_load_timestamp = GETDATE()
    WHERE table_name = 'customers';
END;

-- Now let's go with orders table 

select * from Gold.fact_orders
select * from silver_incremental.orders

CREATE PROCEDURE Gold.sp_load_incremental_fact_orders
AS
BEGIN
    SET NOCOUNT ON;

    MERGE Gold.fact_orders AS target
    USING (
        SELECT
            o.order_id,
            c.Customer_Sk,
            o.order_status,
            CAST(o.order_purchase_timestamp AS DATE) AS order_purchase_timestamp,
            CAST(o.order_approved_at AS DATE) AS order_approved_at,
            CAST(o.order_delivered_carrier_date AS DATE) AS order_delivered_carrier_date,
            CAST(o.order_delivered_customer_date AS DATE) AS order_delivered_customer_date,
            CAST(o.order_estimated_delivery_date AS DATE) AS order_estimated_delivery_date
        FROM silver_incremental.orders o
        INNER JOIN Gold.dim_customers c ON o.customer_id = c.Customer_Id
    ) AS source
    ON target.Order_Id = source.order_id

    WHEN MATCHED THEN
        UPDATE SET
            target.Order_Status = source.order_status,
            target.Order_Approved_At = source.order_approved_at,
            target.Order_Delivered_Carrier_Date = source.order_delivered_carrier_date,
            target.Order_Delivered_Customer_Date = source.order_delivered_customer_date,
            target.Order_Estimated_Delivery_Date  = source.order_estimated_delivery_date

    WHEN NOT MATCHED THEN
        INSERT (
            Order_Id,                          
            Customer_Sk,                      
            Order_Status,                      
            Order_Purchase_Timestamp,          
            Order_Approved_At,                 
            Order_Delivered_Carrier_Date,      
            Order_Delivered_Customer_Date,     
            Order_Estimated_Delivery_Date 
        )
        VALUES (
            source.order_id,
            source.Customer_Sk,
            source.order_status,
            source.order_purchase_timestamp,
            source.order_approved_at,
            source.order_delivered_carrier_date,
            source.order_delivered_customer_date,
            source.order_estimated_delivery_date
        );

    DELETE FROM silver_incremental.orders
    WHERE EXISTS (
        SELECT 1 FROM Gold.fact_orders f 
        WHERE f.Order_Id = silver_incremental.orders.order_id
    );

    DELETE FROM staging_incremental.orders;

    UPDATE Gold.Etl_Control
    SET last_load_timestamp = GETDATE()
    WHERE table_name = 'orders';
END; 

-- let's go with order_items table 

select * from Gold.fact_order_items
select * from silver_incremental.order_items

CREATE PROCEDURE Gold.sp_load_incremental_fact_order_items
AS
BEGIN
    SET NOCOUNT ON;

    MERGE Gold.fact_order_items AS target
    USING (
        SELECT
            i.order_id,
            i.order_item_id,
            p.Product_Sk,
            s.Seller_Sk,
            CAST(i.shipping_limit_date AS DATE) AS shipping_limit_date,
            i.price,
            i.freight_value
        FROM silver_incremental.order_items i
        INNER JOIN Gold.dim_products p ON i.product_id = p.Product_Id
        INNER JOIN Gold.dim_sellers s ON i.seller_id = s.Seller_Id
    ) AS source
    ON target.Order_Id = source.order_id 
       AND target.Order_Item_Id = source.order_item_id

    WHEN MATCHED THEN
        UPDATE SET
            target.Product_Sk = source.Product_Sk,
            target.Seller_Sk = source.Seller_Sk,
            target.Shipping_Limit_Date = source.shipping_limit_date,
            target.Price = source.price,
            target.Freight_Value = source.freight_value

    WHEN NOT MATCHED THEN
        INSERT (
            Order_Id, Order_Item_Id, Product_Sk, Seller_Sk,
            Shipping_Limit_Date, Price, Freight_Value
        )
        VALUES (
            source.order_id, source.order_item_id, source.Product_Sk,
            source.Seller_Sk, source.shipping_limit_date, source.price,
            source.freight_value
        );

    DELETE FROM silver_incremental.order_items
    WHERE EXISTS (
        SELECT 1 FROM Gold.fact_order_items f 
        WHERE f.Order_Id = silver_incremental.order_items.order_id
          AND f.Order_Item_Id = silver_incremental.order_items.order_item_id
    );

    DELETE FROM staging_incremental.order_items;


    UPDATE Gold.Etl_Control
    SET last_load_timestamp = GETDATE()
    WHERE table_name = 'order_items';
END;

-- Now let's go with order_payments table 

select * from Gold.fact_order_payments
select * from silver_incremental.order_payments

CREATE PROCEDURE Gold.sp_load_incremental_fact_order_payments
AS
BEGIN
    SET NOCOUNT ON;

    MERGE Gold.fact_order_payments AS target
    USING (
        SELECT
            p.order_id,
            p.payment_sequential,
            p.payment_type,
            p.payment_installments,
            p.payment_value
        FROM silver_incremental.order_payments p
        INNER JOIN Gold.fact_orders o ON p.order_id = o.Order_Id
    ) AS source
    ON target.Order_Id = source.order_id 
       AND target.Payment_Sequential = source.payment_sequential

    WHEN MATCHED THEN
        UPDATE SET
            target.Payment_Type = source.payment_type,
            target.Payment_Installments = source.payment_installments,
            target.Payment_Value = source.payment_value

    WHEN NOT MATCHED THEN
        INSERT (
            Order_Id, Payment_Sequential, Payment_Type,
            Payment_Installments, Payment_Value
        )
        VALUES (
            source.order_id, source.payment_sequential, source.payment_type,
            source.payment_installments, source.payment_value
        );

    DELETE FROM silver_incremental.order_payments
    WHERE EXISTS (
        SELECT 1 FROM Gold.fact_order_payments f 
        WHERE f.Order_Id = silver_incremental.order_payments.order_id
          AND f.Payment_Sequential = silver_incremental.order_payments.payment_sequential
    );

    DELETE FROM staging_incremental.order_payments;


    UPDATE Gold.Etl_Control
    SET last_load_timestamp = GETDATE()
    WHERE table_name = 'order_payments';
END;

-- Let's go with order_reviews table 

select * from Gold.fact_order_reviews
select * from silver_incremental.order_reviews

CREATE PROCEDURE Gold.sp_load_incremental_fact_order_reviews
AS
BEGIN
    SET NOCOUNT ON;

    MERGE Gold.fact_order_reviews AS target
    USING (
        SELECT
            r.review_id,
            r.order_id,
            r.review_score,
            r.review_comment_title,
            r.review_comment_message,
            CAST(r.review_creation_date AS DATE) AS review_creation_date,
            CAST(r.review_answer_timestamp AS DATE) AS review_answer_date
        FROM silver_incremental.order_reviews r
        INNER JOIN Gold.fact_orders o ON r.order_id = o.Order_Id
    ) AS source
    ON target.Review_Id = source.review_id

    WHEN MATCHED THEN
        UPDATE SET
            target.Review_Score = source.review_score,
            target.Review_Comment_Title = source.review_comment_title,
            target.Review_Comment_Message = source.review_comment_message,
            target.Review_Creation_Date = source.review_creation_date,
            target.Review_Answer_Date = source.review_answer_date

    WHEN NOT MATCHED THEN
        INSERT (
            Review_Id, Order_Id, Review_Score, Review_Comment_Title,
            Review_Comment_Message, Review_Creation_Date, Review_Answer_Date
        )
        VALUES (
            source.review_id, source.order_id, source.review_score,
            source.review_comment_title, source.review_comment_message,
            source.review_creation_date, source.review_answer_date
        );

    DELETE FROM silver_incremental.order_reviews
    WHERE EXISTS (
        SELECT 1 FROM Gold.fact_order_reviews f 
        WHERE f.Review_Id = silver_incremental.order_reviews.review_id
    );

    DELETE FROM staging_incremental.order_reviews;


    UPDATE Gold.Etl_Control
    SET last_load_timestamp = GETDATE()
    WHERE table_name = 'order_reviews';
END;

