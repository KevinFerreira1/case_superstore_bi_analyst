/*
 * Description: 
 * This query checks if there's any customer ID associated with more than 
 * one customer name. This ensures that the customer data is consistent.
 */
SELECT 
    "customer id",
    COUNT(DISTINCT "customer name") AS diff_name_count,
    ARRAY_AGG(DISTINCT "customer name") AS associated_names
FROM superstore_db.raw_orders
WHERE "customer name" IS NOT NULL 
  AND LENGTH(TRIM("customer name")) > 0
  AND LOWER(TRIM("customer name")) <> 'nan' 
GROUP BY "customer id"
HAVING COUNT(DISTINCT "customer name") > 1;
