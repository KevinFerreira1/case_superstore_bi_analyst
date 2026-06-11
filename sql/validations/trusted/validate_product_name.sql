/*
 * Description: 
 * This query checks if there are any product IDs that are accidentally 
 * linked to multiple different product names.
 */
WITH tb AS (
    SELECT DISTINCT 
        "product id", 
        "product name"
    FROM superstore_db.raw_orders
    WHERE "product name" IS NOT NULL 
      AND LENGTH(TRIM("product name")) > 0
      AND LOWER(TRIM("product name")) <> 'nan'  -- Removes false nulls 'nan'
)
SELECT 
    "product id",
    COUNT("product name") AS diff_name_count,
    ARRAY_AGG("product name") AS associated_names
FROM tb
GROUP BY 1
HAVING COUNT("product name") > 1;
