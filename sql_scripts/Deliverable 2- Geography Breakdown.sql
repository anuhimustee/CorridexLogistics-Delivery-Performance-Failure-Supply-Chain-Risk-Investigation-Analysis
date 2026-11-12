/* ============================================================
   DELIVERABLE 2: GEOGRAPHIC BREAKDOWN
   ============================================================
   Business question:
   Is the underperformance everywhere, or is it concentrated
   in specific routes and city pairs?

   Testing the Regional Director's theory:
   "One or two city pairs are dragging down the overall
   number. Fix those routes and the SLA recovers."
*/

-- Build: Route performance Summary View

CREATE OR ALTER VIEW vw_RoutePerformance AS
SELECT
    route_id,
    route_name,
    origin_city,
    destination_city,
    route_type,
    route_risk_level,
    standard_transit_days,
    COUNT(*)                                                AS Total_Shipments,
    SUM(on_time_flag)                                       AS OnTime,
    ROUND(100.0 * SUM(on_time_flag) / COUNT(*),1)           AS OnTimePct,
    ROUND(AVG(CAST(delay_days AS FLOAT)),1)                 AS AvgDelays,
    SUM(CASE WHEN delivery_status = 'Failed'
              THEN 1 ELSE 0 END)                            AS FailedCount,
    SUM(CASE WHEN delivery_status = 'Late'
               THEN 1 ELSE 0 END)                           AS LateCount
FROM vw_ShipmentDetail
GROUP BY 
        route_id, route_name, origin_city, destination_city,
    route_type,route_risk_level,standard_transit_days

-- 2A: On-time rate by route type

SELECT
    route_type,
    COUNT(DISTINCT route_id)                            AS RouteCount,
    SUM(Total_Shipments)                                 AS TotalShipments,
    FORMAT(ROUND(AVG(OnTimePct),1),'0.00')                            AS AvgOnTimePct,
    FORMAT(ROUND(MIN(OnTimePct),1),'0.00')                             AS WorstRoute,
    FORMAT(ROUND(MAX(OnTimePct),1),'0.00')                             AS BestRoute
FROM vw_RoutePerformance
GROUP BY route_type 
ORDER BY AvgOnTimePct DESC;


-- 2B: All routes ranked by on-time rate

SELECT
    route_name,
    route_type,
    route_risk_level,
    Total_Shipments,
    OnTimePct,
    AvgDelays,
    FailedCount,
    RANK() OVER (ORDER BY OnTimePct ASC)            AS WorstRank
FROM vw_RoutePerformance
ORDER BY OnTimePct ASC

-- 2C: Performance by risk level

SELECT 
    route_risk_level,
    COUNT(DISTINCT route_id)                        AS Routes,
    SUM(Total_Shipments)                             AS Shipments,
    FORMAT(ROUND(AVG(OnTimePct),1),'0.00')                AS AvgOnTime
FROM vw_RoutePerformance
GROUP BY route_risk_level
ORDER BY AvgOnTime   DESC;


-- 2D: Origin City Performance
-- Which departure cities are the problem?

SELECT
    origin_city,
    COUNT(DISTINCT route_id)                            AS RouteCount,
    SUM(Total_Shipments)                                AS Shipments,
    FORMAT(ROUND(100.0 * SUM(OnTime) 
                / SUM(Total_Shipments),1),'0.00')        AS OnTimePct,
    FORMAT(ROUND(AVG(AvgDelays),1),'0.00')               AS AvgDelayDays
FROM vw_RoutePerformance
GROUP BY origin_city
ORDER BY OnTimePct ASC;

-- 2E: Cross-border vs domestic by year

SELECT
    year,
    route_type,
    COUNT(*)                                            AS Shipments,
    FORMAT(ROUND(100.0 * SUM(on_time_flag)
                    / COUNT(*), 1),'0.00')                      AS OnTimePct
FROM vw_ShipmentDetail
GROUP BY year, route_type
ORDER BY year, route_type;
