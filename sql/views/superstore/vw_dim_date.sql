/*
 * Description: 
 * Contiguous calendar dimension built from min to max dates
 * found in the dataset. Key format YYYYMMDD (INT).
 */

CREATE OR REPLACE VIEW superstore_db.vw_dim_date AS

WITH date_bounds AS (
  SELECT 
    MIN(dt) AS min_dt,
    MAX(dt) AS max_dt
  FROM (
    SELECT order_date AS dt FROM superstore_db.trusted_orders WHERE order_date IS NOT NULL
    UNION ALL
    SELECT ship_date AS dt FROM superstore_db.trusted_orders WHERE ship_date IS NOT NULL
  )
),
all_dates AS (
  SELECT CAST(dt AS DATE) AS dt
  FROM date_bounds
  CROSS JOIN UNNEST(SEQUENCE(min_dt, max_dt, INTERVAL '1' DAY)) AS t(dt)
)

SELECT
  CAST(DATE_FORMAT(dt, '%Y%m%d') AS INTEGER)   AS date_key,

  dt                                            AS full_date,
  DAY(dt)                                       AS day_of_month,
  DAY_OF_WEEK(dt)                               AS day_of_week,
  DATE_FORMAT(dt, '%W')                         AS day_name,
  WEEK(dt)                                      AS week_of_year,
  MONTH(dt)                                     AS month_number,
  DATE_FORMAT(dt, '%M')                         AS month_name,
  QUARTER(dt)                                   AS quarter,
  CONCAT('Q', CAST(QUARTER(dt) AS VARCHAR), ' ', CAST(YEAR(dt) AS VARCHAR)) AS quarter_label,
  YEAR(dt)                                      AS year,
  DATE_FORMAT(dt, '%Y-%m')                      AS year_month,
  CASE WHEN DAY_OF_WEEK(dt) IN (6, 7) THEN TRUE ELSE FALSE END AS is_weekend

FROM all_dates
ORDER BY dt;
