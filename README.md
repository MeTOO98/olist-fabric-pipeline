# Olist End-to-End Data Pipeline with Microsoft Fabric

An end-to-end data pipeline that ingests the Olist Brazilian E-Commerce dataset from SQL Server into Microsoft Fabric, follows the Medallion Architecture (Bronze → Silver → Gold), supports both initial and incremental loads, and exposes a Galaxy Schema to Power BI for reporting.

---

## Table of Contents

- Overview
- Architecture
- Design Evolution
- Design Trade-off
- Folder Structure
- Tech Stack
- Source Data
- Pipeline Overview
- Data Model (Galaxy Schema)
- Silver Transformations
- Gold Layer
- Incremental Load Strategy
- Dashboard (Result)


---

## Overview

The Olist dataset is a public e-commerce dataset containing ~100k orders placed between 2016 and 2018 across multiple Brazilian marketplaces. This project:

- Loads the raw CSV data into SQL Server as the source system.
- Uses Microsoft Fabric Data Pipeline to move the data into a Lakehouse (Bronze layer).
- Applies data-quality and cleansing transformations using PySpark notebook (Silver layer, initial load).
- Loads cleansed data into a Fabric Warehouse using stored procedures (Gold layer).
- Runs the incremental load entirely through T-SQL stored procedures inside the Warehouse — the Lakehouse is only used by the initial load.
- Publishes an interactive Power BI dashboard on top of the Gold Galaxy Schema (multi-fact star).
- Supports incremental loading using timestamp-based watermarks and SQL Server triggers.

> Note: The project originally envisioned an all-notebooks pipeline, but pivoted to a hybrid (Notebooks + T-SQL) design due to Fabric's Spark capacity limits. See the Design Evolution section for the full story.

---

## Architecture

The project follows the Medallion Architecture:

| Layer | Storage | Purpose |
|---|---|---|
| Raw | SQL Server | Source system holding the original Olist data |
| Bronze | Fabric Lakehouse (Delta) | Raw copy of source tables with ingestion metadata |
| Silver (initial load) | Fabric Lakehouse (Delta) | Cleansed, deduplicated, and standardized data — Delta tables in the Lakehouse only |
| Silver (incremental load) | Fabric Warehouse | Cleansed incremental batches loaded into silver_incremental.* and staging_incremental.* schemas |
| Gold | Fabric Warehouse | Galaxy Schema — 4 fact tables + 4 conformed dimensions, with surrogate keys |
| Reporting | Power BI | Interactive dashboards built on top of the Gold layer |

Because the two load paths use different engines, they materialize Silver in two different systems:

Initial Load Path:
SQL Server → Bronze (Lakehouse) → Silver (Lakehouse) → Gold (Warehouse)

Incremental Load Path:
SQL Server → staging_incremental (Warehouse) → silver_incremental (Warehouse) → Gold (Warehouse)

Both paths end at → Power BI

---

## Design Evolution (Original Vision vs Delivered Design)

### Original vision

The first plan for this project was to run the entire pipeline through PySpark notebooks — from ingestion all the way to the Gold layer:

SQL Server → [Bronze Notebook] → [Silver Notebook] → [Gold Notebook] → Power BI

The appeal was simplicity: one engine (PySpark), one language (Python), one artifact type (notebooks), fewer things to maintain.

### What changed

During the trial, the primary blocker was Spark capacity limits — the Fabric Spark cluster hit capacity errors (HTTP 430) when running the full Bronze → Silver → Gold transformations as notebooks. This made a pure-notebook pipeline unreliable at the scale required by the initial load.

To keep the project moving, the design pivoted to a hybrid approach:

- Initial load — the Bronze → Silver stage stays in PySpark notebooks (processing the dataset in one distributed pass), while the Silver → Gold transformation was moved from a PySpark notebook to T-SQL stored procedures. The Gold tables themselves live in the Warehouse in both cases — only the transformation engine changed.
- Incremental load — moved entirely to T-SQL stored procedures inside the Warehouse, avoiding Spark altogether for the small incremental batches.

To let the Warehouse read the Silver tables that live in the Lakehouse, the initial load pipeline includes a Refresh SQL analytics endpoint activity that exposes the Lakehouse Delta tables as queryable T-SQL sources before the Gold stored procedures run.

### Why this matters for reviewers

The hybrid design is a deliberate engineering response to real Fabric constraints — not an oversight. It also happens to satisfy a secondary goal of the project: exploring as many Fabric components as possible (Lakehouse, Warehouse, Pipelines, Notebooks, Stored Procedures) in a single end-to-end solution.

See the Design Trade-off section below for the full comparison and the recommended optimization path.

---

## Design Trade-off (Deliberate vs Optimal)

| Path | Transformation Engine | Silver Storage | Gold Storage | Reason |
|---|---|---|---|---|
| Initial Load | PySpark Notebooks | Fabric Lakehouse (Delta) | Fabric Warehouse | Spark processes the full dataset in one distributed pass |
| Incremental Load | T-SQL Stored Procedures | Fabric Warehouse (silver_incremental.*) | Fabric Warehouse | Small batches, fast inside the Warehouse, no Spark needed |

### Why two engines?

- Exploring Fabric components — intentionally exercises as many Fabric components as possible during a trial period.
- Initial load benefits from PySpark because it processes the entire dataset in parallel across a Spark cluster.
- Incremental load uses T-SQL because each batch is small and stored procedures execute fast inside the Warehouse.
- Spark capacity constraints — the initial pipeline hit HTTP 430 errors from the Fabric Spark cluster.
- Refresh SQL analytics endpoint — the initial pipeline includes this activity so the Warehouse stored procedures can read the Lakehouse Silver Delta tables.
- Simulating incremental behavior — the incremental load was simulated by splitting the source CSVs by year and quarter using Pandas.

### Optimization Opportunity

Running two separate transformation paths introduces:

- Duplicated logic — Silver rules are maintained twice.
- Two storage layers for the same data — no shared Silver store between the two paths.
- Higher operational complexity — the initial and incremental loads must be maintained separately.

### Recommended Optimization

1. All-in-Warehouse — run the initial load's PySpark transformations as T-SQL stored procedures too. Downside: initial load becomes slower.
2. All-in-Lakehouse — run the incremental load through the same PySpark notebook, and let the Warehouse read from the Lakehouse Silver tables via shortcuts or views. Downside: Warehouse cannot natively query Lakehouse tables for stored procedures in some configurations.

---

## Folder Structure

```
olist-fabric-pipeline/
├── Dashboard/                      # Power BI page screenshots
│   ├── orders_page.png
│   ├── overview_page.png
│   ├── payments_page.png
│   └── reviews_page.png
├── Pipelines and Model/            # Fabric pipelines + Galaxy schema
│   ├── initial_pipeline.png
│   ├── sup_incremental_pipeline.png
│   ├── main_incremental_pipeline.png
│   └── data_model.png
├── Raw_Data/                       # Original Olist CSV files + pandas code
│   ├── olist_customers_dataset.csv
│   ├── olist_geolocation_dataset.csv
│   └── ...
├── Initial_Load/                   # Notebooks + SQL (initial load)
│   ├── From Raw to Bronze.ipynb
│   ├── Silver_Notebook.ipynb
│   ├── Gold_Etl_Control.sql
│   └── Initial Gold.sql
├── Incremental_Load/               # SQL scripts (incremental load)
│   ├── Incremental Staging.sql
│   ├── Incremental Silver.sql
│   ├── Incremental Gold.sql
│   └── Views.sql
└── README.md
```

## Tech Stack

| Component | Technology |
|---|---|
| Source Database | Microsoft SQL Server |
| Data Platform | Microsoft Fabric (Lakehouse + Warehouse) |
| Data Pipelines | Fabric Data Pipelines |
| Transformations (Bronze → Silver, initial load) | PySpark Notebooks (Synapse Spark) |
| Transformations (Silver → Gold) | T-SQL Stored Procedures |
| Transformations (incremental) | T-SQL Stored Procedures |
| Simulation of Incremental Batches | Python (Pandas) — splits CSVs by year / quarter |
| Storage Format | Delta Lake |
| Reporting | Power BI |
| Language(s) | Python (PySpark + Pandas), T-SQL |

---

## Source Data

| File | Description |
|---|---|
| olist_customers_dataset.csv | Customer information |
| olist_geolocation_dataset.csv | Zip-code → lat/lng mapping |
| olist_order_items_dataset.csv | Items inside each order |
| olist_order_payments_dataset.csv | Payment details per order |
| olist_order_reviews_dataset.csv | Customer reviews |
| olist_orders_dataset.csv | Order-level information |
| olist_products_dataset.csv | Product catalog |
| olist_sellers_dataset.csv | Seller information |
| product_category_name_translation.csv | Category name translations (PT → EN) |

For the incremental load, five of these tables were extended with created_at and last_modified_at columns plus AFTER UPDATE triggers on SQL Server:

- customers
- orders
- order_items
- order_payments
- order_reviews

Full-refresh tables (no timestamps): sellers, products, geolocation, product_category_name_translation.

> Note: The Olist dataset is a static snapshot, so the incremental load was simulated by splitting the CSVs into yearly / quarterly batches using Pandas.

---

## Pipeline Overview

### Initial Load Pipeline

[Lookup tables] → [ForEach → Copy Tables → Bronze] → [Notebook: Add_Metadata] → [Notebook: Silver_Notebook] → [Refresh SQL analytics endpoint] → [ForEach → Execute Stored Procedures → Gold]

Screenshot:<img src="Pipelines%20and%20Model/final_initial_pipeline.png" alt="Initial Load Pipeline" width="800">

### Incremental Load Pipeline

[Invoke Copy_Pipeline] → [ForEach → Silver_SP] → [ForEach → Gold_SP]

Screenshot: Pipelines and Model/incremental_pipeline.png

### Incremental Copy Pipeline

Lookup watermark → Copy customers
Lookup watermark → Copy orders
Lookup watermark → Copy order_items
Lookup watermark → Copy order_payments
Lookup watermark → Copy order_reviews

Screenshot: Pipelines and Model/incremental_copy_pipeline.png

---

## Data Model (Galaxy Schema)

The Gold layer implements a Galaxy Schema (also known as a Fact Constellation Schema) — multiple fact tables that share a set of conformed dimensions.

### Dimensions (Conformed)

| Table | Grain | Surrogate Key |
|---|---|---|
| dim_customers | One row per customer | customer_sk |
| dim_sellers | One row per seller | seller_sk |
| dim_products | One row per product | product_sk |
| dim_date | One row per calendar day (2016-01-01 → 2018-12-31) | date |

### Facts

| Table | Grain | Surrogate Key | Related Dimensions |
|---|---|---|---|
| fact_orders | One row per order | order_sk | dim_customers, dim_date |
| fact_order_items | One row per order line item | order_item_sk | dim_products, dim_sellers |
| fact_order_payments | One row per payment | order_payment_sk | dim_date (via fact_orders) |
| fact_order_reviews | One row per review | order_review_sk | dim_customers, dim_date |

### Why Galaxy (and not Star)?

- A Star Schema contains one fact table. It is ideal for a single business process.
- A Galaxy Schema contains two or more fact tables that share conformed dimensions.

Screenshot: Pipelines and Model/data_model.png

---

## Silver Transformations

Silver transformations are applied twice in this project:

1. Initial load — via Silver_Notebook.ipynb (Bronze → Silver Lakehouse tables).
2. Incremental load — via Incremental Silver.sql stored procedures (staging → silver_incremental Warehouse tables).


| Table | Rules |
|---|---|
| Customers | Trim + lowercase IDs, enforce 32-char length, clean city, uppercase state, pad zip |
| Orders | Validate status, restrict date range, flag date-logic errors |
| Order Items | Composite key, replace price ≤ 0 with median, freight ≥ 0 |
| Order Payments | Composite key, default payment_type to 'Not Defined', installments ≥ 1 |
| Order Reviews | Drop rows with review_answer_timestamp < review_creation_date, score 1–5 |

Every Silver row gets silver_loaded_date and silver_source_table.

---

## Gold Layer

The Gold layer is built via stored procedures and produces a Galaxy Schema. The Gold tables live in the Warehouse for both load paths.

### Initial Load Procedures

- Gold.sp_load_dim_customers
- Gold.sp_load_dim_sellers
- Gold.sp_load_dim_products
- Gold.sp_load_fact_orders
- Gold.sp_load_fact_order_items
- Gold.sp_load_fact_order_payments
- Gold.sp_load_fact_order_reviews

### Incremental Load Procedures

- Gold.sp_load_incremental_dim_customers
- Gold.sp_load_incremental_fact_orders
- Gold.sp_load_incremental_fact_order_items
- Gold.sp_load_incremental_fact_order_payments
- Gold.sp_load_incremental_fact_order_reviews

### Date Dimension

dim_date populated for 2016-01-01 through 2018-12-31.

### Views for Reporting

The views schema exposes snake_case wrappers over the Gold tables.

---

## Incremental Load Strategy

Incremental loading is watermark-based:

1. Gold.Etl_Control stores a last_load_timestamp per table.
2. The pipeline reads this watermark.
3. The Copy activity pulls only rows where last_modified_at > watermark.
4. Silver procedures cleanse the new batch.
5. Gold procedures MERGE the new batch into the Gold tables.
6. The watermark is advanced to GETDATE().

### How the Incremental Behavior Was Simulated

Because the Olist dataset is a static historical snapshot, the incremental load was simulated by splitting the data into yearly / quarterly batches using Pandas:

- The original CSV files were loaded with Pandas.
- Each file was partitioned by year and quarter.
- The partitions were inserted into SQL Server progressively.
- created_at / last_modified_at were refreshed between batches.

---

## Dashboard (Result)

The end product of the pipeline is a Power BI dashboard built on top of the Gold Galaxy Schema. It has 4 pages:

### 1. Overview
Total Revenue, Total Orders, Total Customers, Average Order Value, Revenue trend, Orders by status, Revenue by category.

### 2. Orders
Total Orders, Delivered Orders, Late Deliveries, Average Delivery Days, Late vs on-time, Orders by state, Delivery performance.

### 3. Payments
Total Payment Value, Average Payment Value, Total Payment Transactions, Payment Types, Payment trend, Payment type distribution, Installments analysis, Avg payment by type.

### 4. Reviews
Total Reviews, Average Review Score, 5-Star Reviews, Response Rate, Avg score over time, Delivery vs Review scatter, 5-star % by state, Avg score by category.

Screenshots: Dashboard/*.png

---
