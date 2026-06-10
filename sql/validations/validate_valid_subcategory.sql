/*
 * Description: 
 * This query lists all the valid subcategories for products that also have 
 * missing or invalid subcategories. 
 */
WITH tb_empty AS (
    -- Selects cases where the subcategory is invalid
    SELECT DISTINCT 
        "product id", 
        "category"
    FROM superstore_db.raw_orders
    WHERE "sub-category" IS NULL 
       OR TRIM("sub-category") = '' 
       OR LOWER(TRIM("sub-category")) = 'nan'
),
tb_filled AS (
    -- Selects cases where the subcategory is filled correctly
    SELECT DISTINCT 
        "product id", 
        "category",
        "sub-category" AS correct_subcategory
    FROM superstore_db.raw_orders
    WHERE "sub-category" IS NOT NULL 
      AND TRIM("sub-category") <> '' 
      AND LOWER(TRIM("sub-category")) <> 'nan'
)
SELECT 
    v."product id",
    v."category",
    -- ARRAY_AGG lists all valid subcategories found for this pair
    ARRAY_AGG(DISTINCT p.correct_subcategory) AS found_subcategories,
    COUNT(DISTINCT p.correct_subcategory) AS valid_options_count
FROM tb_empty v
INNER JOIN tb_filled p 
   ON v."product id" = p."product id" 
  AND v."category" = p."category"
GROUP BY 1, 2;
