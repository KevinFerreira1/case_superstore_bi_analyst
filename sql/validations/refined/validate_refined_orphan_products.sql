/*
 * Description: 
 * This query checks for referential integrity by identifying if there are any 
 * orphan products in the fact_orders table that do not exist in dim_product.
 * The ideal result is 0 lines.
 */
SELECT COUNT(*) AS orphan_products
FROM superstore_db.fact_orders f
LEFT JOIN superstore_db.dim_product d ON f.product_key = d.product_key
WHERE d.product_key IS NULL;
