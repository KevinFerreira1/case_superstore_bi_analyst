/*
 * Description: 
 * Customer dimension with surrogate key.
 * One row per distinct customer_id.
 */

CREATE OR REPLACE VIEW superstore_db.vw_dim_customer AS

WITH distinct_customers AS (
  SELECT
    customer_id,
    customer_name,
    segment
  FROM superstore_db.trusted_orders
  WHERE customer_id IS NOT NULL
  GROUP BY customer_id, customer_name, segment
)

SELECT
  CAST(ROW_NUMBER() OVER (ORDER BY customer_id) AS INTEGER) AS customer_key,
  customer_id,
  customer_name,
  segment
FROM distinct_customers;
