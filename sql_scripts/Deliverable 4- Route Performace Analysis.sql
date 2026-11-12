/* ============================================================
   DELIVERABLE 4: DRIVER & ROUTE PERFORMANCE
   ============================================================
   Business question:
   Which drivers are underperforming? Is there a pattern —
   experience, vehicle type, employment type?

   Testing the Operations Manager's theory:
   "It is specific drivers and high-risk routes. A small
   group is responsible for the majority of delays." */


-- Build: Driver performance summary View


CREATE OR ALTER VIEW vw_DriverPerfromance AS
SELECT
    driver_id,
    driver_name,
    vehicle_type,
    experience_years,
    employment_type,
    performance_rating                  AS performance_rating,
    COUNT(*)                                            AS TotalShipments,
    SUM(on_time_flag)                                   AS OnTime,
    ROUND(100.00 * SUM(on_time_flag)
                    / COUNT(*), 1)                     AS OnTimePct,
    SUM(CASE WHEN delivery_status = 'Late'
                THEN 1 ELSE 0 END)                      AS LateCount,
    SUM(CASE WHEN delivery_status = 'Failed'
                THEN 1 ELSE 0 END)                      AS FailedCount,
    ROUND(AVG(CAST(delay_days AS FLOAT)),1)         AS AvgDelayDays,
    CASE
        WHEN experience_years <= 2 THEN '0-2 Years'
        WHEN experience_years <= 5 THEN '3-5 Years'
        WHEN experience_years <= 9 THEN '6-9 Years'
        ELSE                            '10+ Years'
    END                                                 AS ExperienceBand
FROM vw_ShipmentDetail
GROUP BY driver_id,driver_name,
    vehicle_type,experience_years,
    employment_type,performance_rating
GO


-- 4A: All drivers ranked by on-time rate
SELECT
    driver_name,
    vehicle_type,
    experience_years,
    employment_type,
    TotalShipments,
    OnTimePct,
    LateCount,
    FailedCount,
    AvgDelayDays,
    performance_rating,
    RANK() OVER (ORDER BY OnTimePct ASC)                AS WorstRank
FROM vw_DriverPerfromance 
ORDER BY OnTimePct ASC;

-- 4B: Performanband

SELECT
        ExperienceBand,
        COUNT(DISTINCT driver_id)                       AS DriversCount,
        SUM(TotalShipments)                             AS Shipments,
        ROUND(AVG(OnTimePct),1)                         AS AvgOnTime,
        ROUND(AVG(AvgDelayDays),1)                      AS AvgDelayDays
FROM vw_DriverPerfromance
GROUP BY ExperienceBand
ORDER BY ExperienceBand


-- 4C: Performance by Vehcile Type
SELECT
        vehicle_type,
        COUNT(DISTINCT driver_id)                       AS DriversCount,
        SUM(TotalShipments)                             AS Shipments,
        ROUND(AVG(OnTimePct),1)                         AS AvgOnTimePct,
        ROUND(AVG(AvgDelayDays),1)                      AS AvgDelayDays
FROM vw_DriverPerfromance
GROUP BY vehicle_type
ORDER BY AvgOnTimePct


-- 4D: Van Drivers on Cross-Border Routes

SELECT
    vehicle_type,
        route_type,
        COUNT(*),
    ROUND(100.0 * SUM(on_time_flag)/COUNT(*),1)             AS OnTimePct,
    ROUND(AVG(CAST(delay_days AS FLOAT)),1)                 AS AvgDelayDays
FROM vw_ShipmentDetail
GROUP BY vehicle_type,route_type
ORDER BY OnTimePct ASC

--4E: Employement type analysis

SELECT
    employment_type,
    COUNT(DISTINCT driver_id)                       AS Drivers,
    ROUND(AVG(CAST(experience_years AS FLOAT)),1)   AS AvgExperience,
    SUM(TotalShipments)                             AS Shipments,
    ROUND(AVG(OnTimePct), 1)                        AS AvgOnTimePct
FROM vw_DriverPerfromance
GROUP BY employment_type
ORDER BY AvgOnTimePct DESC;


SELECT TOP 5
    driver_name,
    vehicle_type,
    experience_years,
    TotalShipments,
    OnTimePct,
    LateCount
FROM vw_DriverPerfromance
ORDER BY OnTimePct ASC;