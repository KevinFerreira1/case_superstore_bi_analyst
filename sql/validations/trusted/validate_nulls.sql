/*
 * Description: 
 * This query counts the number of 'nan' string values across all columns 
 * in the raw_orders table to identify missing data.
 */
SELECT 
    column_name, 
    COUNT(*) AS null_count
FROM superstore_db.raw_orders
CROSS JOIN UNNEST(
  ARRAY['row_id','order_id','order_date','ship_date','ship_mode',
        'customer_id','customer_name','segment','country','city',
        'state','postal_code','region','product_id','category',
        'sub_category','product_name','sales','quantity','discount','profit'],
  ARRAY[
    "row id",
    "order id",
    "order date" ,
    "ship date",
    "ship mode",
    "customer id",
    "customer name",
    "segment",
    "country/region",
    "city",
    "state/province",
    "postal code",
    "region",
    "product id",
    "category",
    "sub-category",
    "product name",
    "sales" ,
    "quantity",
    "discount",
    "profit"
  ]
) AS t(column_name, column_value)
WHERE LOWER(TRIM(column_value)) = 'nan'
GROUP BY column_name
ORDER BY null_count DESC;
