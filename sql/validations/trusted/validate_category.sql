/*
 * Description: 
 * This query checks if the same product ID has been assigned to multiple 
 * different categories.
 */
WITH tb AS (
    SELECT DISTINCT 
        "product id", 
        TRIM(UPPER(category)) AS category
    FROM superstore_db.raw_orders
    WHERE category IS NOT NULL 
      AND LENGTH(TRIM(category)) > 0
      AND LOWER(TRIM(category)) <> 'nan' 
)
SELECT 
     "product id",
    COUNT(category) AS diff_name_count,
    ARRAY_AGG(category) AS associated_names
FROM tb
GROUP BY 1
HAVING COUNT(category) > 1;
