/* ============================================================
   DELIVERABLE 5: CUSTOMER PERFORMANCE 
   ============================================================
*/
-- ── Build: Customer performance summary View 

CREATE OR ALTER VIEW vw_CustomerPerformance AS
SELECT
    customer_id,
    customer_name,
    customer_segment,
    contract_tier,
    sla_threshold_days,
    customer_country,
    COUNT(*)                                        AS TotalShipments,
    SUM(on_time_flag)                               AS OnTime,
    ROUND(100.0 * SUM(on_time_flag)
          / COUNT(*), 1)                            AS OnTimePct,
    SUM(CASE WHEN delivery_status = 'Late'
             THEN 1 ELSE 0 END)                     AS LateShipments,
    SUM(CASE WHEN delivery_status = 'Failed'
             THEN 1 ELSE 0 END)                     AS FailedShipments,
    COALESCE(SUM(delay_days), 0)                    AS TotalDelayDays,
    ROUND(SUM(shipment_value_eur), 2)               AS TotalShipmentValue,
    ROUND(AVG(CAST(delay_days AS FLOAT)), 1)        AS AvgDelayDays
FROM vw_ShipmentDetail
GROUP BY
    customer_id, customer_name, customer_segment,
    contract_tier, sla_threshold_days, customer_country;
GO

-- 5A: Allcustomers aranked by on-time rate
SELECT
    customer_name,
    customer_segment,
    customer_country,
    TotalShipments,
    OnTimePct,
    85.0                                                    AS  SLA_Threshold,   
    ROUND(OnTimePct-85.0,1)                                 AS Gap_threshold,
    LateShipments,
    FailedShipments,
    TotalDelayDays,
    RANK() OVER (ORDER BY OnTimePct ASC)                    AS WorstRank
FROM vw_CustomerPerformance
ORDER BY OnTimePct

-- 5B: Contract tier Analysis

SELECT  
    contract_tier,
    COUNT(customer_id)                             AS Cusomters,
    SUM(TotalShipments)                                     AS Shipments,
    ROUND(AVG(OnTimePct),1)                                 AS AvgOnTime,
    SUM(TotalDelayDays)                                     AS TotalDelayDays
FROM vw_CustomerPerformance
GROUP BY contract_tier
ORDER BY
    CASE contract_tier
        WHEN 'Plantinum' THEN 1
        WHEN 'Gold'      THEN 2
        WHEN 'Silver'    THEN 3
        WHEN 'Bronze'    THEN 4
    END;

-- 5c: Customer Segment Analysis

SELECT 
    customer_segment,
    COUNT(DISTINCT customer_id)                      AS Customers,
    SUM(TotalShipments)                             AS Shipments,
    ROUND(AVG(OnTimePct),1)                         AS AvgOnTimePct,
    SUM(LateShipments)                              AS TotalLateShipments
FROM vw_CustomerPerformance
GROUP BY customer_segment
ORDER BY AvgOnTimePct DESC;


-- 5D: Hartwell Group Deep dive

SELECT
   'Hartwell Group',
   year,
   quarter,
   COUNT(*)                                             AS Shipments,
   ROUND(100.0 * SUM(on_time_flag)
                / COUNT(*),1)                           AS OnTimePct,
   SUM(CASE WHEN delivery_status = 'Late'
               THEN 1 ELSE 0 END)                       AS LateShipment,
   SUM(CASE WHEN delivery_status = 'Failed'
               THEN 1 ELSE 0 END)                       AS FailedShipment
FROM vw_ShipmentDetail
WHERE customer_name = 'Hartwell Group'
GROUP BY year,quarter
ORDER BY year,quarter,OnTimePct


-- 5E: Which routes are failing Hartwell Group?
SELECT
    route_name,
    route_type,
    COUNT(*)                                           AS Shipment,
    ROUND(100.0 * SUM(on_time_flag)
                   /COUNT(*),1)                        AS OnTimePct,
    SUM(CASE WHEN delivery_status = 'Late'
             THEN 1 ELSE 0 END)                     AS LateCount
FROM vw_ShipmentDetail
WHERE customer_name = 'Hartwell Group'
GROUP BY route_name, route_type
ORDER BY OnTimePct ASC;

