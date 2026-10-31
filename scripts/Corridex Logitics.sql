/* ============================================================
   CORRIDEX LOGISTICS — DELIVERY PERFORMANCE INVESTIGATION
   ============================================================
   ProjectName:  Operation Last Mile — SQL Analysis
   Dataset:  CorridexLogisticsDB (6 tables, 15,000 shipments)
   Author:   Mustapha Anuhi
   Date:     2026

   
   Deliverables:
   -------------
   1. Situation Assessment      — Baseline KPIs and trend
   2. Geographic Breakdown      — Routes and city pairs
   3. Warehouse & Stock         — Stock readiness analysis
   4. Driver Performance        — Driver and vehicle analysis
   5. Customer Impact           — Client-level risk
   6. Delivery Risk Score       — Composite risk per shipment

   Analysis Pipeline:
   ------------------
   Step 1 : Built foundation Views
   Step 2 : Built summary Views
   Step 3 : Answer each deliverable by querying Views
   Step 4 : Each query tells one piece of the story

   Schema:
   -------
   fact_shipments  — 15,000 rows, one per shipment
   dim_customer    — 12 customers
   dim_driver      — 20 drivers
   dim_route       — 15 routes
   dim_warehouse   — 5 warehouses
   dim_date        — 731 calendar dates (2024-2025)
   ============================================================ */

-- Create a Database specifically for this project

CREATE DATABASE CorridexLogisticsDB;
GO

USE CorridexLogisticsDB
GO


/* ============================================================
   STEP 1: EXPLORE THE SCHEMA
   ============================================================
   Before writing a single analytical query, understand
   the data. Know the grain of each table, the key columns,
   and how the tables connect.

   This is always the first step in a real investigation.
   ============================================================ */

 -- How many shipments do we have?

SELECT
	COUNT(*) AS Total_Shipments
FROM fact_shipments;

-- What delivery statuses exist and how are they distributed?
SELECT 
	delivery_status,
	COUNT(*)				AS Total_Shipments,
	ROUND(100.00 *
		COUNT(*) / SUM(COUNT(*)) OVER(),1)		Pct_Distribution
FROM fact_shipments
GROUP BY delivery_status
ORDER BY Total_Shipments

/* ============================================================
   STEP 2: BUILD FOUNDATION VIEWS
   ============================================================
   These Views are the backbone of the entire analysis.
   Every deliverable query will reference vw_ShipmentDetail.
   Build them once. Query them everywhere.
   ============================================================ */


-- Foundation View: Full shipment detail --
-- Joins all 6 tables into one clean, flat result set.
-- Every analytical query in this project builds on this View.

CREATE OR ALTER VIEW vw_ShipmentDetail AS
SELECT
	-- Shipment identifiers
    f.shipment_id,
    f.shipment_date,
    f.promised_delivery_date,
    f.actual_delivery_date,
    f.expected_transit_days,

    -- Delivery outcome
    f.delivery_status,
    f.delay_days,
    f.delivery_attempt_count,
    f.failed_delivery_reason,
    f.is_returned,

    -- Shipment attributes
    f.shipment_category,
    f.shipment_weight_kg,
    f.shipment_value_eur,
    f.priority_tier,

    -- Stock & warehouse at dispatch
    f.stock_ready_flag,
    f.stock_issue_type,
    f.warehouse_delay_hours,

    -- Customer
    f.customer_id,
    c.customer_name,
    c.customer_segment,
    c.contract_tier,
    c.sla_threshold_days,
    c.country                       AS customer_country,
    c.city                          AS customer_city,

    -- Driver
    f.driver_id,
    d.driver_name,
    d.vehicle_type,
    d.experience_years,
    d.performance_rating,
    d.employment_type,

    -- Route
    f.route_id,
    r.route_name,
    r.origin_city,
    r.destination_city,
    r.route_type,
    r.risk_level                    AS route_risk_level,
    r.distance_km,
    r.standard_transit_days,

    -- Warehouse
    f.warehouse_id,
    w.warehouse_name,
    w.city                          AS warehouse_city,
    w.region,

    -- Date dimensions
    dt.year,
    dt.quarter,
    dt.month_number,
    dt.month_name,
    dt.day_of_week,
    dt.is_weekend,
    dt.is_public_holiday,

    -- Derived: on-time flag (1 = on-time, 0 = late or failed)
    -- Use this in every aggregation instead of filtering by status
    CASE WHEN f.delivery_status = 'On-Time' THEN 1 ELSE 0 END AS on_time_flag
FROM
	fact_shipments f
INNER JOIN dim_customer   c   ON f.customer_id = c.customer_id
INNER JOIN dim_driver     d   ON f.driver_id     = d.driver_id
INNER JOIN dim_route      r   ON f.route_id      = r.route_id
INNER JOIN dim_warehouse  w   ON f.warehouse_id  = w.warehouse_id
INNER JOIN dim_date       dt  ON f.shipment_date = dt.date_id;
GO

SELECT *
FROM vw_ShipmentDetail

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
                /COUNT(*)-85.00, 1)
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
    ROUND(AVG(CAST(delay_days AS FLOAT))

FROM vw_ShipmentDetail
GROUP BY priority_tier
ORDER BY OnTimePct DESC

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


/* ============================================================
   DELIVERABLE 3: WAREHOUSE & STOCK ANALYSIS
   ============================================================
   Business question:
   Are shipments being delayed before they even leave the
   warehouse? Does stock readiness predict delivery outcome?

   Testing the Warehouse Head's theory:
   "Stock is not ready when shipments are scheduled.
   Warehouse delays are adding hours before a vehicle
   even leaves the facility." */


-- ── Build: Warehouse performance summary View ─────────────────

CREATE OR ALTER VIEW vw_WarehousePerformance AS
SELECT
   warehouse_id,
   warehouse_name,
   warehouse_city,
   region,
   COUNT(*)                                             AS TotalShipments,
   SUM(on_time_flag)                                    AS OnTime,
   ROUND(100.0 * SUM(on_time_flag)
                / COUNT(*), 1)                          AS OnTimePct,
-- Stock readiness metrics
SUM(CASE WHEN stock_ready_flag = 0
            THEN 1 ELSE 0 END)                          AS StockNotReadyCount,
ROUND(100.0 * SUM(CASE WHEN stock_ready_flag = 0
                            THEN 1 ELSE 0 END)
                               / COUNT(*), 1)           AS StockIssueRate,
-- Warehouse delay hours
ROUND(AVG(CAST(warehouse_delay_hours AS FLOAT)),1)      AS AvgWarehouseDelayHrs,
MAX(warehouse_delay_hours)                              AS MaxWarehouse,
-- Stock issue breakdown
SUM(CASE WHEN stock_issue_type = 'Out of Stock'
            THEN 1 ELSE 0 END)                          AS OutOfStockCount,
SUM(CASE WHEN stock_issue_type = 'Damaged Goods'
            THEN 1 ELSE 0 END)                          AS DamagedCount,
SUM(CASE WHEN stock_issue_type = 'Late Supplier'
            THEN 1 ELSE 0 END)                          AS lateSupplierCount
FROM vw_shipmentDetail
GROUP BY warehouse_id, warehouse_name, warehouse_city, region;
GO


-- 3A: Warehosue on-time rate and stock issue rate

SELECT
    warehouse_name,
    warehouse_city,
    region,
    TotalShipments,
    OnTimePct,
    StockIssueRate,
    AvgWarehouseDelayHrs,
    RANK () OVER (ORDER BY OnTimePct ASC)              AS Perfromance_Rank
FROM vw_WarehousePerformance
ORDER BY OnTimePct ASC;


-- 3B: The key question - does stock readiness predict outcome?
-- Compare on-time rates when stock IS and IS NOT ready

SELECT
    CASE WHEN stock_ready_flag = 1
        THEN 'Stock Ready'
        ELSE 'Stock NOT Ready'
    END                                             AS StockStatus,
    COUNT(*)                                        AS Shipments,
    SUM(on_time_flag)                               AS OnTime,
    FORMAT(ROUND(100.0 * SUM(on_time_flag)
          / COUNT(*),1),'0.00')                            AS OnTimePct,
    ROUND(AVG(CAST(warehouse_delay_hours AS FLOAT)),1) AS AvgWarehouseDelayHrs,
    ROUND(AVG(CAST(delay_days AS FLOAT)), 1)        AS AvgDelayDays
FROM vw_ShipmentDetail
GROUP BY stock_ready_flag
ORDER BY stock_ready_flag DESC;



-- 3C: Stock issue type breakdown
-- What kind of stock problems are causing the delays?

SELECT
    stock_issue_type,
    COUNT(*)                                            AS Occurrences,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 1)   AS PctOfIssues,
    ROUND(100.0 * SUM(on_time_flag)
            / COUNT(*),1)                               AS OnTimePct,
    ROUND(AVG(CAST(warehouse_delay_hours AS FLOAT)),1)  AS AvgDelayHrs
FROM vw_ShipmentDetail
WHERE stock_ready_flag = 0
GROUP BY stock_issue_type
ORDER BY Occurrences DESC;


-- 3D: Warehouse stock readiness vs on-time rate
-- Per warehouse: how often is stock not ready, and how does
-- that correlate with the delivery outcome?


SELECT
    warehouse_city,
    TotalShipments,
    StockIssueRate,
    OnTimePct,
    AvgWarehouseDelayHrs,
    OutOfStockCount,
    DamagedGoodsCount,
    LateSupplierCount
FROM vw_WarehousePerformance
ORDER BY StockIssueRate DESC;

-- 3E: Warehouse + stock interaction

-- For Amsterdam and Warsaw specifically: how much of their
-- underperformance is explained by stock issues?

SELECT
    warehouse_city,
    CASE WHEN stock_ready_flag = 1
         THEN 'Stock Ready'
         ELSE 'Stock NOT Ready'
    END                                             AS StockStatus,
    COUNT(*)                                        AS Shipments,
    ROUND(100.0 * SUM(on_time_flag)
          / COUNT(*), 1)                            AS OnTimePct
FROM vw_ShipmentDetail
WHERE warehouse_city IN ('Amsterdam', 'Warsaw')
GROUP BY warehouse_city, stock_ready_flag
ORDER BY warehouse_city, stock_ready_flag DESC;


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


/* ============================================================
   DELIVERABLE 6: DELIVERY RISK SCORE
   ============================================================
   Business question:
   Which shipments carry the highest delivery risk?
   Can we build a composite score that predicts failure
   before it happens?

   Scoring logic:
   Each risk factor contributes points to a total score.
   Higher score = higher risk of being late or failed.

   Factor                    Points
   ─────────────────────────────────────
   Route risk: High          +3
   Route risk: Medium        +1
   Cross-Border route        +2
   Warehouse: Amsterdam/Warsaw +2
   Experience: 0-2 years     +4
   Experience: 3-5 years     +2
   Vehicle: Van + Cross-Border +3
   Stock NOT ready           +5
   Priority: Standard        +1
   Priority: Critical        -2 (managed more carefully)
   ─────────────────────────────────────
   Max possible score: 20
   Score >= 10: HIGH RISK
   Score 5-9:  MEDIUM RISK
   Score < 5:  LOW RISK

*/

--  Build: Risk score View

CREATE OR ALTER VIEW vw_RiskScore AS
SELECT
    shipment_id,
    shipment_date,
    customer_name,
    contract_tier,
    driver_name,
    experience_years,
    vehicle_type,
    route_name,
    route_type,
    route_risk_level,
    warehouse_city,
    priority_tier,
    stock_ready_flag,
    stock_issue_type,
    delivery_status,
    on_time_flag,
    delay_days,
    year,
    quarter,

    -- Build the composite risk score
    (
        -- Route risk
        CASE route_risk_level
            WHEN 'High'   THEN 3
            WHEN 'Medium' THEN 1
            ELSE               0
        END
        +
        -- Cross-border penalty
        CASE route_type
            WHEN 'Cross-Border' THEN 2
            ELSE                     0
        END
        +
        -- Warehouse risk
        CASE warehouse_city
            WHEN 'Amsterdam' THEN 2
            WHEN 'Warsaw'    THEN 2
            ELSE                  0
        END
        +
        -- Driver experience
        CASE
            WHEN experience_years <= 2 THEN 4
            WHEN experience_years <= 5 THEN 2
            ELSE                            0
        END
        +
        -- Van on cross-border
        CASE
            WHEN vehicle_type = 'Van'
             AND route_type   = 'Cross-Border' THEN 3
            ELSE                                    0
        END
        +
        -- Stock readiness — strongest single factor
        CASE stock_ready_flag
            WHEN 0 THEN 5
            ELSE        0
        END
        +
        -- Priority tier
        CASE priority_tier
            WHEN 'Standard'  THEN 1
            WHEN 'Critical'  THEN -2
            ELSE                   0
        END
    )                                               AS RiskScore,

    -- Risk tier classification
    CASE
        WHEN (
            CASE route_risk_level WHEN 'High' THEN 3 WHEN 'Medium' THEN 1 ELSE 0 END
            + CASE route_type WHEN 'Cross-Border' THEN 2 ELSE 0 END
            + CASE warehouse_city WHEN 'Amsterdam' THEN 2 WHEN 'Warsaw' THEN 2 ELSE 0 END
            + CASE WHEN experience_years <= 2 THEN 4 WHEN experience_years <= 5 THEN 2 ELSE 0 END
            + CASE WHEN vehicle_type = 'Van' AND route_type = 'Cross-Border' THEN 3 ELSE 0 END
            + CASE stock_ready_flag WHEN 0 THEN 5 ELSE 0 END
            + CASE priority_tier WHEN 'Standard' THEN 1 WHEN 'Critical' THEN -2 ELSE 0 END
        ) >= 10 THEN 'HIGH RISK'
        WHEN (
            CASE route_risk_level WHEN 'High' THEN 3 WHEN 'Medium' THEN 1 ELSE 0 END
            + CASE route_type WHEN 'Cross-Border' THEN 2 ELSE 0 END
            + CASE warehouse_city WHEN 'Amsterdam' THEN 2 WHEN 'Warsaw' THEN 2 ELSE 0 END
            + CASE WHEN experience_years <= 2 THEN 4 WHEN experience_years <= 5 THEN 2 ELSE 0 END
            + CASE WHEN vehicle_type = 'Van' AND route_type = 'Cross-Border' THEN 3 ELSE 0 END
            + CASE stock_ready_flag WHEN 0 THEN 5 ELSE 0 END
            + CASE priority_tier WHEN 'Standard' THEN 1 WHEN 'Critical' THEN -2 ELSE 0 END
        ) >= 5  THEN 'MEDIUM RISK'
        ELSE         'LOW RISK'
    END                                             AS RiskTier

FROM vw_ShipmentDetail;
GO

SELECT * FROM vw_RiskScore



-- 6A: Risk Tier distribution

SELECT
    RiskTier,
    COUNT(*)                                        AS Shipments,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 1) AS PctOfTotal,
    SUM(on_time_flag)                               AS OnTime,
    ROUND(100.0 * SUM(on_time_flag) / COUNT(*), 1)  AS OnTimePct,
    SUM(CASE WHEN delivery_status = 'Failed'
             THEN 1 ELSE 0 END)                     AS FailedCount
FROM vw_RiskScore
GROUP BY RiskTier
ORDER BY
    CASE RiskTier
        WHEN 'HIGH RISK'   THEN 1
        WHEN 'MEDIUM RISK' THEN 2
        WHEN 'LOW RISK'    THEN 3
    END;

-- 6B: Risk score distribution

SELECT
    RiskScore,
    COUNT(*)                                        AS Shipments,
    ROUND(100.0 * SUM(on_time_flag) / COUNT(*), 1)  AS OnTimePct
FROM vw_RiskScore
GROUP BY RiskScore
ORDER BY RiskScore;

-- 6C: Highest Risk Shipment Profiles
SELECT TOP 20
    shipment_id,
    customer_name,
    route_name,
    warehouse_city,
    driver_name,
    experience_years,
    vehicle_type,
    priority_tier,
    stock_ready_flag,
    Riskscore,
    RiskTier,
    delivery_status  
FROM vw_RiskScore
ORDER BY RiskScore DESC, delivery_status

-- 6D: Risk tier by customer
SELECT
     customer_name,
     contract_tier,
     COUNT(*)                                                        AS Shipments,
     SUM(CASE WHEN RiskTier = 'HIGH RISK' THEN 1 ELSE 0 END)        AS HighRiskCount,
     ROUND(100.0 * SUM(CASE WHEN RiskTier = 'HIGH RISK' 
                        THEN 1 ELSE 0 END) / COUNT(*), 1)              AS HighRiskPct
FROM vw_RiskScore
GROUP BY customer_name,contract_tier
ORDER BY HighRiskPct DESC;


/* 
   ================================================================================
                       THE VERDICT - Which Theory is Right?
   ================================================================================
   One final summary query that puts all four theories side by side. 
   This is the answer to the COO's question.
   -------------------------------------------------------------------------------- 
*/

-- Theory 1: Operations Manager — drivers and routes
SELECT
    'Operations Manager Theory'                     AS Theory,
    'Partially Correct'                             AS Verdict,
    'Experience matters strongly. But it is a profile '
    + '(low experience + Van + cross-border), '
    + 'not specific bad individuals.'               AS Finding
UNION ALL
-- Theory 2: Warehouse Head — stock readiness
SELECT
    'Warehouse Head Theory'                         AS Theory,
    'Correct — but incomplete'                      AS Verdict,
    'Stock not ready reduces on-time rate sharply. '
    + 'Amsterdam and Warsaw are the problem warehouses. '
    + 'Berlin and Lyon are clean.'                  AS Finding
UNION ALL
-- Theory 3: Regional Director — city concentration
SELECT
    'Regional Director Theory'                      AS Theory,
    'Partially Correct'                             AS Verdict,
    'Performance is concentrated — but it is '
    + 'Cross-Border route TYPE, not any single city. '
    + 'Fixing Warsaw routes alone is not enough.'   AS Finding
UNION ALL
-- Theory 4: Finance Director — priority deprioritisation
SELECT
    'Finance Director Theory'                       AS Theory,
    'Weakest'                                       AS Verdict,
    'Standard tier underperforms, but so does '
    + 'Express on bad routes. Priority tier alone '
    + 'does not explain the 15pp breach. '
    + 'This is an operational problem.'             AS Finding;