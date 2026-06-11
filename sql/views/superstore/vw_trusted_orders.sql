/*
 * Description: 
 * View with cleaned, enriched and deduplicated data
 */

CREATE OR REPLACE VIEW superstore_db.vw_trusted_orders AS

-- ─────────────────────────────────────────────────────────────────────────────
-- CTE 1: Base parsing — type casting, TRIM and date conversion
-- ─────────────────────────────────────────────────────────────────────────────
WITH base AS (
  SELECT
    NULLIF(NULLIF(TRIM("order id"), ''), 'nan')     AS order_id,
    NULLIF(NULLIF(TRIM("customer id"), ''), 'nan')  AS customer_id,
    NULLIF(NULLIF(TRIM("product id"), ''), 'nan')   AS product_id,

    -- ── Order Date ──
    CAST(COALESCE(
      TRY(DATE_PARSE(TRIM("order date"), '%Y-%m-%d %H:%i:%s')),
      TRY(DATE_PARSE(TRIM("order date"), '%Y-%m-%d')),
      TRY(DATE_PARSE(TRIM("order date"), '%m-%d-%Y')),
      TRY(DATE_PARSE(TRIM("order date"), '%d/%m/%Y')),
      TRY(DATE_PARSE(TRIM("order date"), '%d-%b-%Y')),
      TRY(DATE_PARSE(TRIM("order date"), '%b %d %Y'))
    ) AS DATE) AS order_date,

    -- ── Ship Date ──
    CAST(COALESCE(
      TRY(DATE_PARSE(TRIM("ship date"), '%Y-%m-%d %H:%i:%s')),
      TRY(DATE_PARSE(TRIM("ship date"), '%Y-%m-%d')),
      TRY(DATE_PARSE(TRIM("ship date"), '%m-%d-%Y')),
      TRY(DATE_PARSE(TRIM("ship date"), '%d/%m/%Y')),
      TRY(DATE_PARSE(TRIM("ship date"), '%d-%b-%Y')),
      TRY(DATE_PARSE(TRIM("ship date"), '%b %d %Y'))
    ) AS DATE) AS ship_date,

    NULLIF(NULLIF(UPPER(TRIM("ship mode")), ''), 'NAN') AS ship_mode,
    NULLIF(NULLIF(TRIM("segment"), ''), 'nan')          AS segment,
    NULLIF(NULLIF(TRIM("country/region"), ''), 'nan')   AS country,
    NULLIF(NULLIF(TRIM("city"), ''), 'nan')             AS city,
    NULLIF(NULLIF(TRIM("state/province"), ''), 'nan')   AS state,
    NULLIF(NULLIF(TRIM("postal code"), ''), 'nan')      AS postal_code,
    NULLIF(NULLIF(TRIM("region"), ''), 'nan')           AS region,
    NULLIF(NULLIF(TRIM(UPPER("category")), ''), 'NAN')   AS category,
    NULLIF(NULLIF(TRIM(UPPER("sub-category")), ''), 'NAN') AS sub_category,
    NULLIF(NULLIF(TRIM("product name"), ''), 'nan')     AS product_name,
    NULLIF(NULLIF(TRIM("customer name"), ''), 'nan')    AS customer_name,

    -- ── Monetary Values ──
    -- The raw data contains inconsistencies like '$' prefix and ',' as thousands separator (e.g. '$1,906.48' or '-1,359.99')
    -- We safely strip these characters before casting to DOUBLE
    -- We also handle 'nan' strings coming from pandas astype(str)
    TRY(CAST(REPLACE(REPLACE(NULLIF(TRIM("sales"), 'nan'),  '$', ''), ',', '') AS DOUBLE)) AS sales,
    TRY(CAST(NULLIF(TRIM("quantity"), 'nan') AS DOUBLE))                                   AS quantity,
    TRY(CAST(NULLIF(TRIM("discount"), 'nan') AS DOUBLE))                                   AS discount,
    TRY(CAST(REPLACE(REPLACE(NULLIF(TRIM("profit"), 'nan'), '$', ''), ',', '') AS DOUBLE)) AS profit

  FROM superstore_db.raw_orders
  WHERE NULLIF(NULLIF(TRIM("order id"), ''), 'nan') IS NOT NULL
),

-- ─────────────────────────────────────────────────────────────────────────────
-- CTE 1.1: Returns deduplication (prevent fan-out)
-- ─────────────────────────────────────────────────────────────────────────────
prep_returns AS (
  SELECT
    NULLIF(NULLIF(TRIM("order id"), ''), 'nan') AS order_id
  FROM superstore_db.raw_returns
  WHERE NULLIF(NULLIF(TRIM("order id"), ''), 'nan') IS NOT NULL
    AND UPPER(TRIM("returned")) = 'YES'
  GROUP BY 1
),

-- ─────────────────────────────────────────────────────────────────────────────
-- CTE 1.2: People normalization (region formatting)
-- ─────────────────────────────────────────────────────────────────────────────
prep_people AS (
  SELECT
    NULLIF(NULLIF(TRIM("regional manager"), ''), 'nan') AS regional_manager,
    CASE UPPER(TRIM("region"))
      WHEN 'CENTRAL REGION' THEN 'Central'
      WHEN 'CTR'            THEN 'Central'
      WHEN 'CENTRAL'        THEN 'Central'
      WHEN 'EAST REGION'    THEN 'East'
      WHEN 'EAST'           THEN 'East'
      WHEN 'STH'            THEN 'South'
      WHEN 'SOUTH REGION'   THEN 'South'
      WHEN 'SOUTH'          THEN 'South'
      WHEN 'WST'            THEN 'West'
      WHEN 'WEST REGION'    THEN 'West'
      WHEN 'WEST'           THEN 'West'
      ELSE TRIM("region")
    END AS region_normalized
  FROM superstore_db.raw_people
  WHERE NULLIF(NULLIF(TRIM("region"), ''), 'nan') IS NOT NULL
  AND NULLIF(NULLIF(TRIM("regional manager"), ''), 'nan') <> 'Temporary Manager'
),

-- ─────────────────────────────────────────────────────────────────────────────
-- CTE 2: Enrich ship_mode — fills empty values using another row
--        with the same order_id that has ship_mode filled in
-- ─────────────────────────────────────────────────────────────────────────────
enriched_ship_mode AS (
  SELECT
    b.*,
    COALESCE(
      NULLIF(b.ship_mode, ''),
      -- looks up ship_mode from another row with same order_id
      (SELECT MAX(b2.ship_mode)
       FROM base b2
       WHERE b2.order_id = b.order_id
         AND NULLIF(b2.ship_mode, '') IS NOT NULL)
    ) AS ship_mode_enriched
  FROM base b
),

-- ─────────────────────────────────────────────────────────────────────────────
-- CTE 3: Enrich customer_name — fills using customer_id as lookup key
--        (fetches the name from another row with the same customer_id)
-- ─────────────────────────────────────────────────────────────────────────────
enriched_customer AS (
  SELECT
    e.*,
    COALESCE(
      NULLIF(e.customer_name, ''),
      (SELECT MAX(b2.customer_name)
       FROM base b2
       WHERE b2.customer_id = e.customer_id
         AND NULLIF(b2.customer_name, '') IS NOT NULL)
    ) AS customer_name_enriched
  FROM enriched_ship_mode e
),

-- ─────────────────────────────────────────────────────────────────────────────
-- CTE 4: Enrich postal_code — fills using the composite key
--        (country, state, city). Rows from the same geographic location
--        share the same postal code.
--        Uses the MODE (most frequent value) for higher accuracy.
-- ─────────────────────────────────────────────────────────────────────────────
postal_code_lookup AS (
  SELECT country, state, city, postal_code, COUNT(*) AS freq
  FROM base
  WHERE NULLIF(postal_code, '') IS NOT NULL
  GROUP BY country, state, city, postal_code
),
postal_code_mode AS (
  SELECT
    country, state, city,
    postal_code AS postal_code_mode,
    ROW_NUMBER() OVER (
      PARTITION BY country, state, city
      ORDER BY freq DESC
    ) AS rn
  FROM postal_code_lookup
),

enriched_postal AS (
  SELECT
    e.*,
    COALESCE(
      NULLIF(e.postal_code, ''),
      pm.postal_code_mode
    ) AS postal_code_enriched
  FROM enriched_customer e
  LEFT JOIN postal_code_mode pm
    ON e.country = pm.country
    AND e.state = pm.state
    AND e.city = pm.city
    AND pm.rn = 1
),

-- ─────────────────────────────────────────────────────────────────────────────
-- CTE 5: Normalize region
--   Central Region, Ctr  → Central
--   East Region          → East
--   Sth                  → South
--   WST                  → West
-- ─────────────────────────────────────────────────────────────────────────────
normalized_region AS (
  SELECT
    e.*,
    CASE UPPER(TRIM(e.region))
      WHEN 'CENTRAL REGION' THEN 'Central'
      WHEN 'CTR'            THEN 'Central'
      WHEN 'CENTRAL'        THEN 'Central'
      WHEN 'EAST REGION'    THEN 'East'
      WHEN 'EAST'           THEN 'East'
      WHEN 'STH'            THEN 'South'
      WHEN 'SOUTH REGION'   THEN 'South'
      WHEN 'SOUTH'          THEN 'South'
      WHEN 'WST'            THEN 'West'
      WHEN 'WEST REGION'    THEN 'West'
      WHEN 'WEST'           THEN 'West'
      ELSE TRIM(e.region) -- keeps original if not recognized
    END AS region_normalized
  FROM enriched_postal e
),

-- ─────────────────────────────────────────────────────────────────────────────
-- CTE 6: Enrich category — fills using product_id as lookup key
--        (fetches the category from another row with the same product_id)
-- ─────────────────────────────────────────────────────────────────────────────
enriched_category AS (
  SELECT
    e.*,
    COALESCE(
      NULLIF(NULLIF(e.category, ''), 'NAN'),
      (SELECT MAX(b2.category) FROM base b2
       WHERE b2.product_id = e.product_id
         AND NULLIF(b2.category, '') IS NOT NULL)
    ) AS category_enriched,

    COALESCE(
      NULLIF(NULLIF(e.sub_category, ''), 'NAN'),
      (SELECT MAX(b2.sub_category) FROM base b2
       WHERE b2.product_id = e.product_id
         AND NULLIF(b2.sub_category, '') IS NOT NULL)
    ) AS sub_category_enriched
  FROM normalized_region e
),

-- ─────────────────────────────────────────────────────────────────────────────
-- CTE 7: Enrich product_name
--   Strategy: for each product_id, defines the "canonical name" as the
--   most frequent product_name (MODE). This handles product_ids with
--   variant names or typos by adopting the dominant name.
--   The original column is preserved as product_name_original for auditing.
-- ─────────────────────────────────────────────────────────────────────────────
product_name_lookup AS (
  SELECT product_id, product_name, COUNT(*) AS freq
  FROM base
  WHERE NULLIF(product_name, '') IS NOT NULL
  GROUP BY product_id, product_name
),
product_name_canonical AS (
  SELECT
    product_id,
    product_name AS product_name_canonical,
    ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY freq DESC) AS rn
  FROM product_name_lookup
),

enriched_product AS (
  SELECT
    e.*,
    e.product_name AS product_name_original, -- original name kept for auditing
    COALESCE(pnc.product_name_canonical, e.product_name) AS product_name_enriched
  FROM enriched_category e
  LEFT JOIN product_name_canonical pnc
    ON e.product_id = pnc.product_id
    AND pnc.rn = 1
),

-- ─────────────────────────────────────────────────────────────────────────────
-- CTE 8: Treat discount — flip negatives to positive
-- ─────────────────────────────────────────────────────────────────────────────
treated_discount AS (
  SELECT
    e.*,
    ABS(e.discount) AS discount_treated
  FROM enriched_product e
),

-- ─────────────────────────────────────────────────────────────────────────────
-- CTE 8.5: Joins with Returns and People
-- ─────────────────────────────────────────────────────────────────────────────
joined_data AS (
  SELECT
    e.*,
    CASE WHEN r.order_id IS NOT NULL THEN 1 ELSE 0 END AS is_returned,
    p.regional_manager
  FROM treated_discount e
  LEFT JOIN prep_returns r
    ON e.order_id = r.order_id
  LEFT JOIN prep_people p
    ON e.region_normalized = p.region_normalized
),

-- ─────────────────────────────────────────────────────────────────────────────
-- CTE 9: Deduplication — removes 100% duplicate rows using ROW_NUMBER
-- ─────────────────────────────────────────────────────────────────────────────
deduplicated AS (
  SELECT
    order_id,
    customer_id,
    customer_name_enriched    AS customer_name,
    product_id,
    order_date,
    ship_date,
    ship_mode_enriched        AS ship_mode,
    segment,
    country,
    city,
    state,
    postal_code_enriched      AS postal_code,
    region_normalized         AS region,
    category_enriched         AS category,
    sub_category_enriched     AS sub_category,
    product_name_enriched     AS product_name,
    product_name_original,
    sales,
    CAST(quantity AS INTEGER) AS quantity,
    discount_treated          AS discount,
    profit,
    is_returned,
    regional_manager,
    ROW_NUMBER() OVER (
      PARTITION BY
        order_id,
        customer_id,
        customer_name_enriched,
        product_id,
        order_date,
        ship_date,
        ship_mode_enriched,
        segment,
        country,
        city,
        state,
        postal_code_enriched,
        region_normalized,
        category_enriched,
        sub_category_enriched,
        product_name_enriched,
        product_name_original,
        sales,
        quantity,
        discount_treated,
        profit,
        is_returned,
        regional_manager
      ORDER BY sales DESC
    ) AS row_num
  FROM joined_data
)

-- ─────────────────────────────────────────────────────────────────────────────
-- FINAL SELECT — only non-duplicate rows
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
  order_id,
  customer_id,
  customer_name,
  product_id,
  order_date,
  ship_date,
  ship_mode,
  segment,
  country,
  city,
  state,
  postal_code,
  CASE 
    WHEN country = 'United States' THEN CONCAT('US-',region)
    WHEN country = 'Canada' THEN CONCAT('CA-',region)
    ELSE region END AS region,
  category,
  sub_category,
  product_name,
  product_name_original,
  sales,
  quantity,
  discount,
  profit,
  is_returned,
  regional_manager
FROM deduplicated
WHERE row_num = 1;
