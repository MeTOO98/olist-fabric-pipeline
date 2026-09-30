-- First I will Create The Schema

create schema staging_incremental;

-- Now I will create Customers Table 

create table staging_incremental.customers (
customer_id VARCHAR(50),
customer_unique_id VARCHAR(50),
customer_zip_code_prefix int,
customer_city varchar(100),
customer_state varchar(5),
created_at DATETIME2(6),
last_modified_at DATETIME2(6));

-- let's go with orders table 

create table staging_incremental.orders (
order_id varchar(50) ,
customer_id varchar(50) ,
order_status varchar(20),
order_purchase_timestamp DATETIME2(6),
order_approved_at DATETIME2(6),
order_delivered_carrier_date DATETIME2(6),
order_delivered_customer_date DATETIME2(6),
order_estimated_delivery_date DATETIME2(6),
year int,
quarter int,
created_at DATETIME2(6),
last_modified_at DATETIME2(6));

-- let's go with order_items table 

create table staging_incremental.order_items (
order_id varchar(50) ,
order_item_id int,
product_id varchar(50) ,
seller_id varchar(50),
shipping_limit_date DATETIME2(6),
price FLOAT,
freight_value FLOAT,
created_at DATETIME2(6),
last_modified_at DATETIME2(6));

-- let's go with order_payments table 

create table staging_incremental.order_payments (
order_id varchar(50)  ,
payment_sequential int,
payment_type varchar(20) ,
payment_installments int,
payment_value FLOAT,
created_at DATETIME2(6),
last_modified_at DATETIME2(6));

-- let's go with order_reviews table 

create table staging_incremental.order_reviews (
review_id varchar(50) ,
order_id varchar(50) ,
review_score int,
review_comment_title varchar(200) ,
review_comment_message varchar(max),
review_creation_date DATETIME2(6),
review_answer_timestamp DATETIME2(6),
created_at DATETIME2(6),
last_modified_at DATETIME2(6));
