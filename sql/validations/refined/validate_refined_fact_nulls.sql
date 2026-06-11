/*
 * Description: 
 * This query checks for data quality in the fact_orders table by counting 
 * nulls in critical dates and calculated measures like discount_amount and delivery_days.
 * Ideally, these should be 0.
 */
SELECT 
  COUNT(*) AS total_rows,
  SUM(CASE WHEN order_date_key IS NULL THEN 1 ELSE 0 END) AS null_order_dates,
  SUM(CASE WHEN ship_date_key IS NULL THEN 1 ELSE 0 END) AS null_ship_dates,
  SUM(CASE WHEN delivery_days < 0 THEN 1 ELSE 0 END) AS negative_delivery_days,
  SUM(CASE WHEN discount_amount IS NULL THEN 1 ELSE 0 END) AS null_discounts
FROM superstore_db.fact_orders;
