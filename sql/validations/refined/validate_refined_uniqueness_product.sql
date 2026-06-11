/*
 * Description: 
 * This query ensures that the surrogate key (product_key) in dim_product is truly unique.
 * The ideal result is 0 lines returned.
 */
SELECT product_key, COUNT(*) as qtd
FROM superstore_db.dim_product
GROUP BY product_key
HAVING COUNT(*) > 1;
