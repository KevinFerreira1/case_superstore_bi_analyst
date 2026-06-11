/*
 * Description: 
 * Geography dimension with surrogate key.
 * One row per distinct location (country+region+state+city+postal_code).
 * Includes regional_manager (1:1 with region in this dataset).
 */

CREATE OR REPLACE VIEW superstore_db.vw_dim_geography AS

WITH distinct_geo AS (
  SELECT
    country,
    region,
    state,
    city,
    postal_code,
    regional_manager
  FROM superstore_db.trusted_orders
  WHERE country IS NOT NULL
  GROUP BY country, region, state, city, postal_code, regional_manager
)

SELECT
  CAST(ROW_NUMBER() OVER (ORDER BY country, region, state, city, postal_code) AS INTEGER) AS geography_key,
  country,
  region,
  state,
  city,
  postal_code,
  regional_manager
FROM distinct_geo;
