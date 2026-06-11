/*
 * Description: 
 * This query checks for referential integrity by identifying if there are any 
 * orphan geographies in the fact_orders table that do not exist in dim_geography.
 * The ideal result is 0 lines.
 */
SELECT COUNT(*) AS orphan_geography
FROM superstore_db.fact_orders f
LEFT JOIN superstore_db.dim_geography d ON f.geography_key = d.geography_key
WHERE d.geography_key IS NULL;
