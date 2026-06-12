# Data Model - Superstore

This document details the data model for the **Raw (Bronze)**, **Trusted (Silver)**, and **Refined (Gold)** layers. The modeling follows the concepts of the Medallion Architecture.

---

## Raw Layer (Bronze)

This layer contains the data in its raw state, extracted from the original source (XLSX files) and stored in Parquet format.

### `raw_orders`
Contains the historical order data from Superstore.
* **Columns:** `Row ID`, `Order ID`, `Order Date`, `Ship Date`, `Ship Mode`, `Customer ID`, `Customer Name`, `Segment`, `Country/Region`, `City`, `State/Province`, `Postal Code`, `Region`, `Product ID`, `Category`, `Sub-Category`, `Product Name`, `Sales`, `Quantity`, `Discount`, `Profit`

### `raw_returns`
Contains the records of orders that were returned.
* **Columns:** `Returned`, `Order ID`

### `raw_people`
Contains the mapping of regional managers.
* **Columns:** `Regional Manager`, `Region`

---

## Trusted Layer (Silver)

This layer contains clean, deduplicated, and enriched data, but still in a non-dimensional transactional format (flat table).

### `trusted_orders`
Central table with all enriched order information.

| Column | Description / Transformation |
| :--- | :--- |
| `order_id` | Order ID |
| `customer_id` | Customer ID |
| `customer_name` | Customer Name (Enriched to cover nulls) |
| `product_id` | Product ID |
| `order_date` | Order placement date |
| `ship_date` | Order shipping date |
| `ship_mode` | Shipping Mode (Enriched to cover nulls) |
| `segment` | Market segment (e.g., Consumer, Corporate) |
| `country` | Country |
| `city` | City |
| `state` | State/Province |
| `postal_code` | Postal Code (Enriched via locality mode) |
| `region` | Standardized and unified region (e.g., US-Central, CA-West) |
| `category` | Product Category (Enriched) |
| `sub_category` | Product Sub-category (Enriched) |
| `product_name` | Canonical Product Name |
| `product_name_original`| Original Product Name kept for auditing |
| `sales` | Total sales value |
| `quantity` | Quantity of items purchased |
| `discount` | Applied discount (Converted to always positive values) |
| `profit` | Operation Profit/Loss |
| `is_returned` | Boolean flag indicating if the order had a return (1 = Yes, 0 = No) |
| `regional_manager` | Name of the manager responsible for the region |

---

## Refined Layer (Gold) - Star Schema

In the Gold layer, the *flat* table from the Silver layer was transformed into a multidimensional model (Star Schema) ideal for Power BI reporting.

### Fact Table

#### `fact_orders`
* **Description:** Fact table measuring quantitative metrics and indicators of sales and logistics.

| Column | Type | Description |
| :--- | :--- | :--- |
| `order_id` | Natural Key | Original order identifier |
| `order_date_key` | Surrogate Key | FK to `dim_date` (Order Date) |
| `ship_date_key` | Surrogate Key | FK to `dim_date` (Ship Date) |
| `customer_key` | Surrogate Key | FK to `dim_customer` |
| `product_key` | Surrogate Key | FK to `dim_product` |
| `geography_key` | Surrogate Key | FK to `dim_geography` |
| `shipping_key` | Surrogate Key | FK to `dim_shipping` |
| `sales` | Measure | Sales value |
| `quantity` | Measure | Item quantity |
| `discount` | Measure | Discount percentage |
| `profit` | Measure | Profit value (can be negative) |
| `is_returned` | Measure/Flag | Return indicator (1 or 0) |
| `delivery_days` | Measure Calc | Delivery days (difference between order_date and ship_date) |
| `discount_amount` | Measure Calc | Nominal discount value (`sales * discount`) |

---

### Dimension Tables

#### `dim_customer`
* **Description:** Customer dimension containing identification and segmentation.

| Column | Type | Description |
| :--- | :--- | :--- |
| `customer_key` | Surrogate Key (INT) | Artificially generated primary key |
| `customer_id` | Natural Key | Original customer ID |
| `customer_name` | Attribute | Full customer name |
| `segment` | Attribute | Consumer segment |

#### `dim_product`
* **Description:** Product portfolio dimension.

| Column | Type | Description |
| :--- | :--- | :--- |
| `product_key` | Surrogate Key (INT) | Artificially generated primary key |
| `product_id` | Natural Key | Original product ID |
| `product_name` | Attribute | Consolidated canonical product name |
| `category` | Attribute | Main category |
| `sub_category` | Attribute | Product sub-category |

#### `dim_geography`
* **Description:** Geographical dimension reflecting sales location and regional leadership.

| Column | Type | Description |
| :--- | :--- | :--- |
| `geography_key` | Surrogate Key (INT) | Artificially generated primary key |
| `country` | Attribute | Country |
| `region` | Attribute | Commercial region |
| `state` | Attribute | State / Province |
| `city` | Attribute | City |
| `postal_code` | Attribute | Postal code (ZIP) |
| `regional_manager` | Attribute | Responsible regional manager name |

#### `dim_shipping`
* **Description:** Dimension containing logistics / shipping methods.

| Column | Type | Description |
| :--- | :--- | :--- |
| `shipping_key` | Surrogate Key (INT) | Artificially generated primary key |
| `ship_mode` | Attribute | Shipping modality (e.g., First Class, Standard Class) |

#### `dim_date`
* **Description:** Contiguous calendar dimension generated from the minimum to the maximum date found in the database.

| Column | Type | Description |
| :--- | :--- | :--- |
| `date_key` | Surrogate Key (INT)| Numeric `YYYYMMDD` format |
| `full_date` | Attribute (DATE) | Full date |
| `day_of_month` | Attribute | Day of the month (1 to 31) |
| `day_of_week` | Attribute | Day of the week (numeric) |
| `day_name` | Attribute | Name of the day (e.g., Monday) |
| `week_of_year` | Attribute | Week number of the year |
| `month_number` | Attribute | Numeric month (1 to 12) |
| `month_name` | Attribute | Name of the month |
| `quarter` | Attribute | Quarter (1 to 4) |
| `quarter_label` | Attribute | Quarter label (e.g., Q1 2020) |
| `year` | Attribute | 4-digit year |
| `year_month` | Attribute | Year-Month format (e.g., 2020-01) |
| `is_weekend` | Attribute (BOOL)| Indicator if it's the weekend |
