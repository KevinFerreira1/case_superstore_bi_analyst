/*
 * Description: 
 * Product dimension with surrogate key.
 * One row per distinct product_id.
 * Uses canonical product_name only (no original variant).
 */

CREATE OR REPLACE VIEW superstore_db.vw_dim_product AS

WITH distinct_products AS (
  SELECT
    product_id,
    product_name,
    category,
    sub_category
  FROM superstore_db.trusted_orders
  WHERE product_id IS NOT NULL
  GROUP BY product_id, product_name, category, sub_category
)

SELECT
  CAST(ROW_NUMBER() OVER (ORDER BY product_id) AS INTEGER) AS product_key,
  product_id,
  product_name,
  category,
  sub_category
FROM distinct_products;
