/*
 * Description: 
 * This query validates the total sales in the fact_orders table against the 
 * trusted_orders table. A difference indicates data loss (fan-in) or duplication (fan-out)
 * during the dimensional model JOINs.
 */
SELECT 
  ROUND(SUM(t.sales), 2) AS total_sales_trusted,
  ROUND(SUM(f.sales), 2) AS total_sales_fact,
  ROUND(SUM(t.sales) - SUM(f.sales), 2) AS difference
FROM superstore_db.trusted_orders t
FULL OUTER JOIN superstore_db.fact_orders f 
  ON t.order_id = f.order_id;
