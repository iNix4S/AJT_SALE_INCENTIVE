-- ============================================================
-- Setup Laos Channel (ตาม TT pattern)
-- Description: เพิ่มข้อมูล Laos channel สำหรับทดสอบ
--              ใช้ TT เป็นต้นแบบ (ws_type + product mapping)
-- Date: 2026-06-22
-- ============================================================

USE [AJT_SALE_INCENTIVE];
GO

-- ============================================================
-- 1. เพิ่ม Laos channel ใน mst_channel
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM dbo.mst_channel WHERE channel_code = 'LAOS')
BEGIN
    INSERT INTO dbo.mst_channel (channel_code, channel_name_en, channel_name_th, calc_type, is_active)
    VALUES ('LAOS', 'Laos Market', N'ตลาดลาว', 'PER_PRODUCT_WS', 1);
    PRINT 'Laos channel created';
END
ELSE
BEGIN
    PRINT 'Laos channel already exists';
END
GO

DECLARE @ch_laos INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'LAOS');
DECLARE @period_id INT = (SELECT TOP 1 period_id FROM dbo.mst_period ORDER BY period_id);
DECLARE @period_code NVARCHAR(20) = (SELECT TOP 1 period_code FROM dbo.mst_period ORDER BY period_id);
DECLARE @sales_month DATE = (SELECT TOP 1 sales_month FROM dbo.mst_period ORDER BY period_id);

-- ============================================================
-- 2. เพิ่ม Employee สำหรับ Laos (3 staff + managers)
-- ============================================================
DECLARE @jf_salesman INT = (SELECT job_function_id FROM dbo.mst_job_function WHERE job_function_code = 'SALESMAN');
DECLARE @jf_section INT = (SELECT job_function_id FROM dbo.mst_job_function WHERE job_function_code = 'SECTION_MANAGER');
DECLARE @jf_dept INT = (SELECT job_function_id FROM dbo.mst_job_function WHERE job_function_code = 'DEPT_MANAGER');
DECLARE @pl_staff INT = (SELECT position_level_id FROM dbo.mst_position_level WHERE position_code = 'STAFF');
DECLARE @pl_sect INT = (SELECT position_level_id FROM dbo.mst_position_level WHERE position_code = 'SECT_MGR');
DECLARE @pl_dept INT = (SELECT position_level_id FROM dbo.mst_position_level WHERE position_code = 'DEPT_MGR');

IF NOT EXISTS (SELECT 1 FROM dbo.mst_employee WHERE employee_code = 'LA001')
BEGIN
    INSERT INTO dbo.mst_employee
        (employee_code, employee_name_th, employee_name_en, channel_id, job_function_id, position_level_id,
         cost_center, company_code, effective_from, effective_to, is_active)
    VALUES
        ('LA001', N'นาย ล. ขายลาว', 'Mr. L Laosales', @ch_laos, @jf_salesman, @pl_staff, 'CC-LA-01', 'AJT', @sales_month, NULL, 1),
        ('LA002', N'นาง อ. ส่งออก', 'Mrs. A Export', @ch_laos, @jf_salesman, @pl_staff, 'CC-LA-01', 'AJT', @sales_month, NULL, 1),
        ('LA003', N'นาย ว. นำเข้า', 'Mr. V Import', @ch_laos, @jf_salesman, @pl_staff, 'CC-LA-01', 'AJT', @sales_month, NULL, 1),
        ('LAM01', N'นาง ล. หัวหน้า', 'Mrs. L Sectmgr', @ch_laos, @jf_section, @pl_sect, 'CC-LA-01', 'AJT', @sales_month, NULL, 1),
        ('LAD01', N'นาย อ. ผู้จัดการ', 'Mr. A Deptmgr', @ch_laos, @jf_dept, @pl_dept, 'CC-LA-01', 'AJT', @sales_month, NULL, 1);
    PRINT 'Laos employees created';
END
ELSE
BEGIN
    PRINT 'Laos employees already exist';
END
GO

-- ============================================================
-- 3. เพิ่ม org hierarchy สำหรับ Laos
-- ============================================================
DECLARE @ch_laos2 INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'LAOS');
DECLARE @sales_month2 DATE = (SELECT TOP 1 sales_month FROM dbo.mst_period ORDER BY period_id);

IF NOT EXISTS (SELECT 1 FROM dbo.mst_org_hierarchy WHERE channel_id = @ch_laos2 AND salesman_code = 'LA001')
BEGIN
    INSERT INTO dbo.mst_org_hierarchy
        (channel_id, effective_month, salesman_code, direct_sup_code, dept_mgr_code, div_mgr_code, ad_code, ws_type, is_active)
    VALUES
        (@ch_laos2, @sales_month2, 'LA001', 'LAM01', 'LAD01', 'DV001', 'AD001', 'TOP_WS', 1),
        (@ch_laos2, @sales_month2, 'LA002', 'LAM01', 'LAD01', 'DV001', 'AD001', 'TOP_WS', 1),
        (@ch_laos2, @sales_month2, 'LA003', 'LAM01', 'LAD01', 'DV001', 'AD001', 'WS_SF', 1);
    PRINT 'Laos org hierarchy created';
END
ELSE
BEGIN
    PRINT 'Laos org hierarchy already exists';
END
GO

-- ============================================================
-- 4. เพิ่ม incentive rate สำหรับ Laos (ตาม TT pattern)
-- ============================================================
DECLARE @ch_laos3 INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'LAOS');
DECLARE @sales_month3 DATE = (SELECT TOP 1 sales_month FROM dbo.mst_period ORDER BY period_id);

IF NOT EXISTS (SELECT 1 FROM dbo.mst_incentive_rate WHERE channel_id = @ch_laos3)
BEGIN
    INSERT INTO dbo.mst_incentive_rate
        (channel_id, position_level_id, ws_type, rate_old, rate_new, effective_from, effective_to, is_active)
    SELECT @ch_laos3, pl.position_level_id, v.ws_type, v.rate_old, v.rate_new, @sales_month3, NULL, 1
    FROM (VALUES
        ('STAFF',    'TOP_WS', 10000.00, 12000.00),
        ('STAFF',    'WS_SF',   9000.00, 11000.00),
        ('SECT_MGR', 'TOP_WS',  7000.00,  9000.00),
        ('DEPT_MGR', 'TOP_WS',  6000.00,  8000.00),
        ('AD',       'TOP_WS',  5000.00,  7000.00)
    ) v(position_code, ws_type, rate_old, rate_new)
    JOIN dbo.mst_position_level pl ON pl.position_code = v.position_code;
    PRINT 'Laos incentive rates created';
END
ELSE
BEGIN
    PRINT 'Laos incentive rates already exist';
END
GO

-- ============================================================
-- 5. เพิ่ม product weight สำหรับ Laos (ตาม TT pattern)
-- ============================================================
DECLARE @ch_laos4 INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'LAOS');
DECLARE @sales_month4 DATE = (SELECT TOP 1 sales_month FROM dbo.mst_period ORDER BY period_id);

IF NOT EXISTS (SELECT 1 FROM dbo.mst_product_weight WHERE channel_id = @ch_laos4)
BEGIN
    INSERT INTO dbo.mst_product_weight
        (channel_id, product_id, ws_type, weight_percent, effective_from, effective_to, is_active)
    SELECT @ch_laos4, p.product_id, v.ws_type, v.weight_percent, @sales_month4, NULL, 1
    FROM (VALUES
        ('AJ',  'TOP_WS', 0.2500),
        ('RD',  'TOP_WS', 0.2000),
        ('BD',  'TOP_WS', 0.1500),
        ('YY',  'TOP_WS', 0.1000),
        ('AJ',  'WS_SF',  0.2200),
        ('RD',  'WS_SF',  0.1800),
        ('BD',  'WS_SF',  0.1400)
    ) v(product_code, ws_type, weight_percent)
    JOIN dbo.mst_product p ON p.product_code = v.product_code;
    PRINT 'Laos product weights created';
END
ELSE
BEGIN
    PRINT 'Laos product weights already exist';
END
GO

-- ============================================================
-- 6. เพิ่ม TT product master สำหรับ Laos (ถ้ายังไม่มี)
-- ============================================================
DECLARE @ch_laos5 INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'LAOS');

-- ตาราง mst_tt_product สำหรับ product mapping (ตาม TT pattern)
IF OBJECT_ID('dbo.mst_tt_product', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.mst_tt_product WHERE channel_id = @ch_laos5)
    BEGIN
        INSERT INTO dbo.mst_tt_product
            (channel_id, product_id, short_alias, is_active, effective_from, effective_to)
        SELECT @ch_laos5, p.product_id, v.short_alias, 1, '2026-04-01', NULL
        FROM (VALUES
            ('AJ',  'A'),
            ('RD',  'R'),
            ('BD',  'B'),
            ('YY',  'Y'),
            ('AJP', 'AP'),
            ('PDC', 'P')
        ) v(product_code, short_alias)
        JOIN dbo.mst_product p ON p.product_code = v.product_code;
        PRINT 'Laos TT product mapping created';
    END
    ELSE
    BEGIN
        PRINT 'Laos TT product mapping already exists';
    END
END
GO

-- ============================================================
-- 7. เพิ่ม sample target data สำหรับ Laos
-- ============================================================
DECLARE @ch_laos6 INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'LAOS');
DECLARE @period_id2 INT = (SELECT TOP 1 period_id FROM dbo.mst_period ORDER BY period_id);

IF NOT EXISTS (SELECT 1 FROM dbo.trn_sales_target WHERE channel_id = @ch_laos6 AND period_id = @period_id2)
BEGIN
    -- ใช้ SKU- format ตาม TT pattern (SKU-{short_alias}-XXX)
    INSERT INTO dbo.trn_sales_target
        (period_id, channel_id, salesman_code, product_code, target_amount)
    VALUES
        -- LA001 targets (TOP_WS)
        (@period_id2, @ch_laos6, 'LA001', 'SKU-A-001',  900000.00),
        (@period_id2, @ch_laos6, 'LA001', 'SKU-R-001',  600000.00),
        (@period_id2, @ch_laos6, 'LA001', 'SKU-B-001',  400000.00),
        -- LA002 targets (TOP_WS)
        (@period_id2, @ch_laos6, 'LA002', 'SKU-A-002', 1100000.00),
        (@period_id2, @ch_laos6, 'LA002', 'SKU-R-002',  700000.00),
        (@period_id2, @ch_laos6, 'LA002', 'SKU-B-002',  500000.00),
        -- LA003 targets (WS_SF)
        (@period_id2, @ch_laos6, 'LA003', 'SKU-A-003',  750000.00),
        (@period_id2, @ch_laos6, 'LA003', 'SKU-R-003',  500000.00),
        (@period_id2, @ch_laos6, 'LA003', 'SKU-B-003',  350000.00);
    PRINT 'Laos sample targets created';
END
ELSE
BEGIN
    PRINT 'Laos sample targets already exist';
END
GO

-- ============================================================
-- 8. เพิ่ม sample actual data สำหรับ Laos
-- ============================================================
DECLARE @ch_laos7 INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'LAOS');
DECLARE @period_id3 INT = (SELECT TOP 1 period_id FROM dbo.mst_period ORDER BY period_id);

IF NOT EXISTS (SELECT 1 FROM dbo.trn_sales_actual WHERE channel_id = @ch_laos7 AND period_id = @period_id3)
BEGIN
    INSERT INTO dbo.trn_sales_actual
        (period_id, channel_id, salesman_code, product_code, actual_amount, source_batch_id)
    VALUES
        -- LA001 actuals (108% achievement)
        (@period_id3, @ch_laos7, 'LA001', 'SKU-A-001',  972000.00, 'LAOS_SAMPLE'),
        (@period_id3, @ch_laos7, 'LA001', 'SKU-R-001',  648000.00, 'LAOS_SAMPLE'),
        (@period_id3, @ch_laos7, 'LA001', 'SKU-B-001',  432000.00, 'LAOS_SAMPLE'),
        -- LA002 actuals (112% achievement)
        (@period_id3, @ch_laos7, 'LA002', 'SKU-A-002', 1232000.00, 'LAOS_SAMPLE'),
        (@period_id3, @ch_laos7, 'LA002', 'SKU-R-002',  784000.00, 'LAOS_SAMPLE'),
        (@period_id3, @ch_laos7, 'LA002', 'SKU-B-002',  560000.00, 'LAOS_SAMPLE'),
        -- LA003 actuals (102% achievement)
        (@period_id3, @ch_laos7, 'LA003', 'SKU-A-003',  765000.00, 'LAOS_SAMPLE'),
        (@period_id3, @ch_laos7, 'LA003', 'SKU-R-003',  510000.00, 'LAOS_SAMPLE'),
        (@period_id3, @ch_laos7, 'LA003', 'SKU-B-003',  357000.00, 'LAOS_SAMPLE');
    PRINT 'Laos sample actuals created';
END
ELSE
BEGIN
    PRINT 'Laos sample actuals already exist';
END
GO

PRINT '';
PRINT '══════════════════════════════════════════════════';
PRINT 'Laos Channel Setup Complete';
PRINT '══════════════════════════════════════════════════';
PRINT 'Next step: Run usp_run_laos_incentive_calculation.sql';
GO
