/*
 * Description: 
 * This query checks the returned orders to see what kinds of quantities 
 * are recorded, helping verify if any negative quantities exist by mistake.
 */
SELECT  
    DISTINCT quantity
FROM superstore_db.raw_orders 
LEFT JOIN superstore_db.raw_returns
    ON raw_orders."order id" = raw_returns."order id"
WHERE raw_returns."order id" IS NOT NULL;
