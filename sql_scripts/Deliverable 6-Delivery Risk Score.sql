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
   ?????????????????????????????????????
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
   ?????????????????????????????????????
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