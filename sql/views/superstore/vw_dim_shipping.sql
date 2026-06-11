/*
 * Description: 
 * Shipping mode dimension with surrogate key.
 * One row per distinct ship_mode.
 */

CREATE OR REPLACE VIEW superstore_db.vw_dim_shipping AS

WITH distinct_shipping AS (
  SELECT
    COALESCE(ship_mode, 'N/A') AS ship_mode
  FROM superstore_db.trusted_orders
  GROUP BY COALESCE(ship_mode, 'N/A')
)

SELECT
  CAST(ROW_NUMBER() OVER (ORDER BY ship_mode) AS INTEGER) AS shipping_key,
  ship_mode
FROM distinct_shipping;
