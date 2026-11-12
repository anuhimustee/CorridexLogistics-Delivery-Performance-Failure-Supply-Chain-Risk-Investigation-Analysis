/* ============================================================
   DELIVERABLE 1: SITUATION ASSESSMENT
   ============================================================
   Business question:
   What does Corridex delivery performance actually look like
   across 2024 and 2025? Establish the baseline before testing
   any theory.

   Key metrics:
   - Overall on-time rate vs 85% SLA threshold
   - Year-over-year trend
   - Quarterly breakdown
   - Performance by priority tier  */

-- 1A Overall on-time rate

SELECT 
        COUNT(*)                    as Total_Shipments,
        SUM(on_time_flag)           as OnTime_Count,
        COUNT(*) - SUM(on_time_flag)                        AS Late_Count,
        ROUND(100.0 * SUM(on_time_flag)/COUNT(*), 1)        AS OnTime_Pct,
        85.00                                               AS SLA_Threshold,
        ROUND(100.0 * SUM(on_time_flag)
                /COUNT(*)-85.00, 1)                         AS Gap_To_SLA
FROM vw_ShipmentDetail


-- 1B Year-Over-Year Comparison 

SELECT
    year                        AS Year,
    COUNT(*)                    as Total_Shipments,
        SUM(on_time_flag)           as OnTime_Count,
        COUNT(*) - SUM(on_time_flag)                        AS Late_Count,
        ROUND(100.0 * SUM(on_time_flag)/COUNT(*), 1)        AS OnTime_Pct,
        85.00                                               AS SLA_Threshold,
        ROUND(100.0 * SUM(on_time_flag)
                /COUNT(*)-85.00, 1)                         AS Gap_To_SLA
FROM vw_ShipmentDetail
GROUP BY year
ORDER BY Total_Shipments


-- 1C Quarterly Breakdown
SELECT year,quarter,
COUNT(*)                    as Total_Shipments,
        SUM(on_time_flag)           as OnTime_Count,
        COUNT(*) - SUM(on_time_flag)                        AS Late_Count,
        ROUND(100.0 * SUM(on_time_flag)/COUNT(*), 1)        AS OnTime_Pct,
        85.00                                               AS SLA_Threshold,
        ROUND(100.0 * SUM(on_time_flag)
                /COUNT(*)-85.00, 1)
FROM vw_ShipmentDetail
GROUP BY year, quarter
ORDER BY year, quarter


-- ID Monthly Breakdown
SELECT
    year,
    month_number,
    month_name,
    COUNT(*)                    as Total_Shipments,
        SUM(on_time_flag)           as OnTime_Count,
        COUNT(*) - SUM(on_time_flag)                        AS Late_Count,
        ROUND(100.0 * SUM(on_time_flag)/COUNT(*), 1)        AS OnTime_Pct,
        85.00                                               AS SLA_Threshold,
        ROUND(100.0 * SUM(on_time_flag)
                /COUNT(*)-85.00, 1)                         AS Gap_To_SLA
FROM vw_ShipmentDetail
GROUP BY year, month_number, month_name
ORDER BY year, month_number;


-- 1E Performance by priority tier
SELECT
    priority_tier,
    COUNT(*)                    as Total_Shipments,
    SUM(on_time_flag)           as OnTime_Count,
    ROUND(100.0 * SUM(on_time_flag)/COUNT(*), 1)        AS OnTime_Pct,
    85.00                                               AS SLA_Threshold,
    ROUND(AVG(CAST(delay_days AS FLOAT)),1)
FROM vw_ShipmentDetail
GROUP BY priority_tier
ORDER BY OnTime_Pct DESC

-- 1F Delivery Status Breakdown
-- Split Late vs Failed - different problems, different fixes.

SELECT
    year,
    delivery_status,
    COUNT(*)                                    AS Total_Shipments,
    FORMAT(ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY year), 1),'0.00') as PctOfYear
FROM vw_ShipmentDetail
GROUP BY year, delivery_status
ORDER BY year, delivery_status