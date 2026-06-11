/*
 * Description: 
 * Central fact table joining trusted_orders to all dimension
 * tables to resolve surrogate keys. Includes calculated
 * measures: delivery_days, discount_amount.
 */

CREATE OR REPLACE VIEW superstore_db.vw_fact_orders AS

SELECT
  t.order_id,

  -- Keys
  CAST(DATE_FORMAT(t.order_date, '%Y%m%d') AS INTEGER)  AS order_date_key,
  CAST(DATE_FORMAT(t.ship_date,  '%Y%m%d') AS INTEGER)  AS ship_date_key,
  dc.customer_key,
  dp.product_key,
  dg.geography_key,
  ds.shipping_key,

  -- Measures
  t.sales,
  t.quantity,
  t.discount,
  t.profit,
  t.is_returned,

  -- Calculated measures
  DATE_DIFF('day', t.order_date, t.ship_date) AS delivery_days,
  ROUND(t.sales * t.discount, 2)              AS discount_amount

FROM superstore_db.trusted_orders t

-- Customer dimension
INNER JOIN superstore_db.dim_customer dc
  ON  t.customer_id   = dc.customer_id
  AND t.customer_name  = dc.customer_name
  AND t.segment        = dc.segment

-- Product dimension
INNER JOIN superstore_db.dim_product dp
  ON  t.product_id    = dp.product_id
  AND t.product_name  = dp.product_name
  AND t.category      = dp.category
  AND t.sub_category  = dp.sub_category

-- Geography dimension
INNER JOIN superstore_db.dim_geography dg
  ON  t.country       = dg.country
  AND t.region        = dg.region
  AND t.state         = dg.state
  AND t.city          = dg.city
  AND COALESCE(t.postal_code, '') = COALESCE(dg.postal_code, '')

-- Shipping dimension
INNER JOIN superstore_db.dim_shipping ds
  ON COALESCE(t.ship_mode, 'N/A')      = ds.ship_mode;
