/*
 * Description: 
 * This query ensures that the surrogate key (customer_key) in dim_customer is truly unique.
 * The ideal result is 0 lines returned.
 */
SELECT customer_key, COUNT(*) as qtd
FROM superstore_db.dim_customer
GROUP BY customer_key
HAVING COUNT(*) > 1;
