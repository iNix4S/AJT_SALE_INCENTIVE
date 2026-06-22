-- ============================================================
-- File    : AJT_TT_Quick_Run_And_Check.sql
-- Purpose : รัน incentive calculation + ตรวจผลรายพนักงาน + ดู actual pivot
-- Usage   : เปลี่ยน @PeriodCode และ @EmployeeListCsv ตามต้องการ
-- ============================================================

-- Step 1: คำนวณ incentive TT
EXEC dbo.usp_run_tt_incentive_calculation
    @PeriodCode = N'FY2026-05',
    @WsType     = N'TOP_WS',
    @ApprovedBy = N'system';

-- Step 2: ตรวจผลรายพนักงานเทียบกับชีต (5 result sets)
-- หมายเหตุ: @InputSheetName และ @InputSheetFile มี default อยู่แล้ว ('1) For HR' / '15_1) For HR.values.csv')
/*
EXEC dbo.usp_check_tt_sheet_employee_reference
    @PeriodCode      = N'FY2026-05',
    @EmployeeListCsv = N'110001,110002,110003,120001,120002,130001,130002,130003,140001,140002,140003,150001,160001,160002',
    @ChannelCode     = N'TT';
*/


EXEC dbo.usp_check_tt_incentive_result
    @PeriodCode      = N'FY2026-05',
    @EmployeeListCsv = N'110000,110001,110002,110003,120000,120001,120002,130000,130001,130002,130003,140000,140001,140002,140003,150000,150001,160000,160001,160002',
    @ChannelCode     = N'TT';

-- Step 3: ดู actual pivot รายเดือน (Apr→Mar)
SELECT *
FROM dbo.vw_trn_sales_actual_pivot_fiscal_month
WHERE salesman_code = '110001';


-- Step 4: ดู TT incentive rate ทุก position × ws_type (เทียบกับ T_SectAbove ในชีต)
SELECT position_code, position_name_en, hierarchy_level, ws_type, rate_old, rate_new, rate_effective, effective_from
FROM dbo.vw_tt_incentive_rate
WHERE is_active = 1
ORDER BY hierarchy_level, ws_type;

  -- ============================================================
-- "2) หลักการคำนวน Table" — Goal Threshold Step Table
-- ใช้ lookup: actual_achievement อยู่ใน [achievement_from, achievement_to)
--   → ได้ goal_multiplier = value_1
-- ============================================================
SELECT
    ROW_NUMBER() OVER (ORDER BY achievement_from)   AS step_no,
    CAST(achievement_from * 100 AS DECIMAL(6,2))    AS ach_from_pct,
    CAST(ISNULL(achievement_to - 0.0001, 99.9999)
         * 100  AS DECIMAL(6,2))                    AS ach_to_pct,
    CAST(value_1 * 100 AS DECIMAL(6,2))             AS goal_multiplier_pct,
    -- raw values (ตรงกับ DB จริง)
    achievement_from,
    achievement_to,
    value_1                                         AS goal_multiplier
FROM dbo.vw_tt_formula_catalog
WHERE source_sheet  = N'2) หลักการคำนวน Table'
  AND formula_type  = N'GOAL_THRESHOLD'
ORDER BY achievement_from;

-- ============================================================
-- "2) หลักการคำนวน Table" — full incentive matrix
-- WS Matrix × GOAL Threshold 9 bands (pivot แนวนอน)
-- = incentive_base × product_weight × goal_multiplier
-- ============================================================
SELECT
    m.ws_type,
    m.g_group_code,
    m.product_code,
    CAST(m.product_weight_percent * 100 AS DECIMAL(5,1))   AS [weight_%],
    m.incentive_base                                        AS [base_฿],
    -- แต่ละ band: base × weight × multiplier
    CAST(ROUND(m.incentive_base * m.product_weight_percent * 0.90, 2) AS DECIMAL(9,2)) AS [GOAL_90%],
    CAST(ROUND(m.incentive_base * m.product_weight_percent * 0.95, 2) AS DECIMAL(9,2)) AS [GOAL_95%],
    CAST(ROUND(m.incentive_base * m.product_weight_percent * 1.00, 2) AS DECIMAL(9,2)) AS [GOAL_100%],
    CAST(ROUND(m.incentive_base * m.product_weight_percent * 1.03, 2) AS DECIMAL(9,2)) AS [GOAL_103%],
    CAST(ROUND(m.incentive_base * m.product_weight_percent * 1.06, 2) AS DECIMAL(9,2)) AS [GOAL_106%],
    CAST(ROUND(m.incentive_base * m.product_weight_percent * 1.10, 2) AS DECIMAL(9,2)) AS [GOAL_110%],
    CAST(ROUND(m.incentive_base * m.product_weight_percent * 1.15, 2) AS DECIMAL(9,2)) AS [GOAL_115%],
    CAST(ROUND(m.incentive_base * m.product_weight_percent * 1.20, 2) AS DECIMAL(9,2)) AS [GOAL_120%],
    CAST(ROUND(m.incentive_base * m.product_weight_percent * 1.30, 2) AS DECIMAL(9,2)) AS [GOAL_130%]
FROM dbo.vw_tt_formula_ws_matrix m
WHERE m.is_active = 1
ORDER BY
    CASE m.ws_type
        WHEN N'TOP_WS' THEN 1 WHEN N'WS_SF' THEN 2
        WHEN N'WS_WH'  THEN 3 WHEN N'SF_WH' THEN 4
    END,
    CASE m.g_group_code
        WHEN N'G1' THEN 1 WHEN N'G2' THEN 2
        WHEN N'G3' THEN 3 ELSE 4
    END,
    m.product_code;


-- dynamic version: CROSS JOIN + pivot
SELECT
    m.ws_type, m.g_group_code, m.product_code,
    CAST(m.product_weight_percent * 100 AS DECIMAL(5,1)) AS [weight_%],
    m.incentive_base,
    MAX(CASE WHEN t.multiplier = 0.90 THEN CAST(ROUND(m.incentive_base * m.product_weight_percent * t.multiplier, 2) AS DECIMAL(9,2)) END) AS [GOAL_90%],
    MAX(CASE WHEN t.multiplier = 0.95 THEN CAST(ROUND(m.incentive_base * m.product_weight_percent * t.multiplier, 2) AS DECIMAL(9,2)) END) AS [GOAL_95%],
    MAX(CASE WHEN t.multiplier = 1.00 THEN CAST(ROUND(m.incentive_base * m.product_weight_percent * t.multiplier, 2) AS DECIMAL(9,2)) END) AS [GOAL_100%],
    MAX(CASE WHEN t.multiplier = 1.03 THEN CAST(ROUND(m.incentive_base * m.product_weight_percent * t.multiplier, 2) AS DECIMAL(9,2)) END) AS [GOAL_103%],
    MAX(CASE WHEN t.multiplier = 1.06 THEN CAST(ROUND(m.incentive_base * m.product_weight_percent * t.multiplier, 2) AS DECIMAL(9,2)) END) AS [GOAL_106%],
    MAX(CASE WHEN t.multiplier = 1.10 THEN CAST(ROUND(m.incentive_base * m.product_weight_percent * t.multiplier, 2) AS DECIMAL(9,2)) END) AS [GOAL_110%],
    MAX(CASE WHEN t.multiplier = 1.15 THEN CAST(ROUND(m.incentive_base * m.product_weight_percent * t.multiplier, 2) AS DECIMAL(9,2)) END) AS [GOAL_115%],
    MAX(CASE WHEN t.multiplier = 1.20 THEN CAST(ROUND(m.incentive_base * m.product_weight_percent * t.multiplier, 2) AS DECIMAL(9,2)) END) AS [GOAL_120%],
    MAX(CASE WHEN t.multiplier = 1.30 THEN CAST(ROUND(m.incentive_base * m.product_weight_percent * t.multiplier, 2) AS DECIMAL(9,2)) END) AS [GOAL_130%]
FROM dbo.vw_tt_formula_ws_matrix  m
CROSS JOIN dbo.vw_tt_formula_goal_threshold t   -- 9 bands
WHERE m.is_active = 1
GROUP BY m.ws_type, m.g_group_code, m.product_code, m.product_weight_percent, m.incentive_base
ORDER BY
    CASE m.ws_type WHEN N'TOP_WS' THEN 1 WHEN N'WS_SF' THEN 2 WHEN N'WS_WH' THEN 3 ELSE 4 END,
    CASE m.g_group_code WHEN N'G1' THEN 1 WHEN N'G2' THEN 2 WHEN N'G3' THEN 3 ELSE 4 END,
    m.product_code;


-- ดูทั้งหมด (long format)
SELECT * FROM dbo.vw_tt_formula_incentive_matrix
ORDER BY
    CASE ws_type WHEN 'TOP_WS' THEN 1 WHEN 'WS_SF' THEN 2 WHEN 'WS_WH' THEN 3 ELSE 4 END,
    CASE g_group_code WHEN 'G1' THEN 1 WHEN 'G2' THEN 2 WHEN 'G3' THEN 3 ELSE 4 END,
    product_code, band_seq;

-- filter เฉพาะ ws_type + band ที่ต้องการ
SELECT * FROM dbo.vw_tt_formula_incentive_matrix
WHERE ws_type = N'TOP_WS' AND band_seq = 7;  -- band 110% ทุก product

-- ดู target ของ TT period ล่าสุด
SELECT t.salesman_code, t.product_code, t.target_amount, t.pct_salesman
FROM dbo.trn_sales_target t
JOIN dbo.mst_period p ON p.period_id = t.period_id
WHERE t.channel_id = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'TT')
  AND p.period_code = N'FY2026-05'
ORDER BY t.salesman_code, t.product_code;

-- ดู actual ของ TT
SELECT a.salesman_code, a.product_code, a.actual_amount
FROM dbo.trn_sales_actual a
JOIN dbo.mst_period p ON p.period_id = a.period_id
WHERE a.channel_id = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'TT')
  AND p.period_code = N'FY2026-05'
ORDER BY a.salesman_code, a.product_code;