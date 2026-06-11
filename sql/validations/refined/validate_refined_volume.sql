/*
 * Description: 
 * This query checks the total row count of all dimension tables and the fact table
 * in the Refined layer. It allows for a quick volume verification.
 */
SELECT 'dim_date' AS table_name, COUNT(*) AS total_rows FROM superstore_db.dim_date
UNION ALL
SELECT 'dim_customer', COUNT(*) FROM superstore_db.dim_customer
UNION ALL
SELECT 'dim_product', COUNT(*) FROM superstore_db.dim_product
UNION ALL
SELECT 'dim_geography', COUNT(*) FROM superstore_db.dim_geography
UNION ALL
SELECT 'dim_shipping', COUNT(*) FROM superstore_db.dim_shipping
UNION ALL
SELECT 'fact_orders', COUNT(*) FROM superstore_db.fact_orders;
