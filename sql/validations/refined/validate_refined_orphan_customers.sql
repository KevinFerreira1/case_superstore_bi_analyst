/*
 * Description: 
 * This query checks for referential integrity by identifying if there are any 
 * orphan customers in the fact_orders table that do not exist in dim_customer.
 * The ideal result is 0 lines.
 */
SELECT COUNT(*) AS orphan_customers
FROM superstore_db.fact_orders f
LEFT JOIN superstore_db.dim_customer d ON f.customer_key = d.customer_key
WHERE d.customer_key IS NULL;
