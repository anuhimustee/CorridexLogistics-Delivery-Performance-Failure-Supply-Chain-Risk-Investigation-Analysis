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


-- ?? Build: Warehouse performance summary View ?????????????????

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
