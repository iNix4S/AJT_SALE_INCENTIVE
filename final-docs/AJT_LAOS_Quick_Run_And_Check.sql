-- ============================================================
-- Quick Run Script: Laos Channel Test
-- Description: รัน Laos calculation และตรวจสอบผลลัพธ์
-- Date: 2026-06-22
-- ============================================================

USE [AJT_SALE_INCENTIVE];
GO

-- ══════════════════════════════════════════════════════════
-- 1. Setup Laos channel (รันครั้งแรก)
-- ══════════════════════════════════════════════════════════
-- Un-comment the line below to run setup first time
-- :r .\setup_laos_channel_full.sql
-- GO

-- ══════════════════════════════════════════════════════════
-- 2. Create SP (รันครั้งแรก)
-- ══════════════════════════════════════════════════════════
-- Un-comment the line below to create SP first time
-- :r .\usp_run_laos_incentive_calculation.sql
-- GO

-- ══════════════════════════════════════════════════════════
-- 3. Run Laos Calculation
-- ══════════════════════════════════════════════════════════
DECLARE @period_code NVARCHAR(20) = (SELECT TOP 1 period_code FROM dbo.mst_period ORDER BY period_id);

PRINT '══════════════════════════════════════════════════';
PRINT 'Running Laos Calculation...';
PRINT '══════════════════════════════════════════════════';

EXEC dbo.usp_run_laos_incentive_calculation
    @PeriodCode = @period_code,
    @WsType     = N'TOP_WS',
    @ApprovedBy = N'SYSTEM_TEST';
GO

-- ══════════════════════════════════════════════════════════
-- 4. Check Results
-- ══════════════════════════════════════════════════════════
DECLARE @ch_laos INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'LAOS');
DECLARE @period_id INT = (SELECT TOP 1 period_id FROM dbo.mst_period ORDER BY period_id);
DECLARE @calc_run_id INT = (SELECT TOP 1 calc_run_id FROM dbo.trn_calc_run 
                             WHERE channel_id = @ch_laos AND period_id = @period_id 
                             ORDER BY created_at DESC);

PRINT '';
PRINT '══════════════════════════════════════════════════';
PRINT 'Laos Calculation Run Summary';
PRINT '══════════════════════════════════════════════════';
SELECT
    r.calc_run_id,
    c.channel_code,
    c.channel_name_en,
    p.period_code,
    r.run_status,
    r.approved_by,
    r.created_at,
    (SELECT COUNT(*) FROM dbo.trn_incentive_detail d WHERE d.calc_run_id = r.calc_run_id) AS detail_count,
    (SELECT COUNT(*) FROM dbo.out_for_hr_variable h WHERE h.calc_run_id = r.calc_run_id) AS for_hr_count
FROM dbo.trn_calc_run r
JOIN dbo.mst_channel c ON c.channel_id = r.channel_id
JOIN dbo.mst_period p ON p.period_id = r.period_id
WHERE r.calc_run_id = @calc_run_id;

PRINT '';
PRINT '══════════════════════════════════════════════════';
PRINT 'Laos Incentive Detail (Top 10)';
PRINT '══════════════════════════════════════════════════';
SELECT TOP 10
    d.salesman_code,
    e.employee_name_th,
    d.position_level_code,
    d.product_code,
    d.target_amount,
    d.actual_amount,
    d.achievement,
    d.goal_multiplier,
    d.product_weight,
    d.incentive_amount
FROM dbo.trn_incentive_detail d
JOIN dbo.mst_employee e ON e.employee_code = d.salesman_code
WHERE d.calc_run_id = @calc_run_id
ORDER BY d.salesman_code, d.product_code;

PRINT '';
PRINT '══════════════════════════════════════════════════';
PRINT 'Laos For HR Summary';
PRINT '══════════════════════════════════════════════════';
SELECT
    h.employee_code,
    e.employee_name_th,
    h.position_level_code,
    h.total_variable
FROM dbo.out_for_hr_variable h
JOIN dbo.mst_employee e ON e.employee_code = h.employee_code
WHERE h.calc_run_id = @calc_run_id
ORDER BY h.employee_code;

PRINT '';
PRINT '══════════════════════════════════════════════════';
PRINT 'Laos Product Mapping Check';
PRINT '══════════════════════════════════════════════════';
-- Check product code mapping (SKU-X-XXX → base product)
SELECT DISTINCT
    d.product_code AS sku_code,
    CASE
        WHEN d.product_code LIKE 'SKU-%' THEN
            CASE UPPER(LEFT(SUBSTRING(d.product_code, 5, 100), CHARINDEX('-', SUBSTRING(d.product_code, 5, 100) + '-') - 1))
                WHEN 'A' THEN 'AJ'
                WHEN 'R' THEN 'RD'
                WHEN 'B' THEN 'BD'
                WHEN 'Y' THEN 'YY'
                ELSE LEFT(SUBSTRING(d.product_code, 5, 100), CHARINDEX('-', SUBSTRING(d.product_code, 5, 100) + '-') - 1)
            END
        ELSE d.product_code
    END AS mapped_product_code
FROM dbo.trn_incentive_detail d
WHERE d.calc_run_id = @calc_run_id
  AND d.position_level_code = 'STAFF'
ORDER BY sku_code;

PRINT '';
PRINT '══════════════════════════════════════════════════';
PRINT 'Laos Quick Run Complete';
PRINT '══════════════════════════════════════════════════';
GO
