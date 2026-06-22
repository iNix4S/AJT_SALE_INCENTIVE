-- ============================================================
-- Setup S&I Channel (ตาม MT pattern)
-- Description: เพิ่มข้อมูล S&I channel สำหรับทดสอบ
--              ใช้ MT เป็นต้นแบบ (per-product calculation)
-- Date: 2026-06-22
-- ============================================================

USE [AJT_SALE_INCENTIVE];
GO

-- ============================================================
-- 1. เพิ่ม S&I channel ใน mst_channel
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM dbo.mst_channel WHERE channel_code = 'SI')
BEGIN
    INSERT INTO dbo.mst_channel (channel_code, channel_name_en, channel_name_th, calc_type, is_active)
    VALUES ('SI', 'Sales & Import', N'ฝ่ายขาย และนำเข้า', 'PER_PRODUCT', 1);
    PRINT 'S&I channel created';
END
ELSE
BEGIN
    PRINT 'S&I channel already exists';
END
GO

DECLARE @ch_si INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'SI');
DECLARE @period_id INT = (SELECT TOP 1 period_id FROM dbo.mst_period ORDER BY period_id);
DECLARE @sales_month DATE = (SELECT TOP 1 sales_month FROM dbo.mst_period ORDER BY period_id);

-- ============================================================
-- 2. เพิ่ม Employee สำหรับ S&I (3 staff + 1 section manager)
-- ============================================================
DECLARE @jf_salesman INT = (SELECT job_function_id FROM dbo.mst_job_function WHERE job_function_code = 'SALESMAN');
DECLARE @jf_section INT = (SELECT job_function_id FROM dbo.mst_job_function WHERE job_function_code = 'SECTION_MANAGER');
DECLARE @pl_staff INT = (SELECT position_level_id FROM dbo.mst_position_level WHERE position_code = 'STAFF');
DECLARE @pl_sect INT = (SELECT position_level_id FROM dbo.mst_position_level WHERE position_code = 'SECT_MGR');

IF NOT EXISTS (SELECT 1 FROM dbo.mst_employee WHERE employee_code = 'SI001')
BEGIN
    INSERT INTO dbo.mst_employee
        (employee_code, employee_name_th, employee_name_en, channel_id, job_function_id, position_level_id,
         cost_center, company_code, effective_from, effective_to, is_active)
    VALUES
        ('SI001', N'นาย ส. นำเข้า', 'Mr. S Import', @ch_si, @jf_salesman, @pl_staff, 'CC-SI-01', 'AJT', @sales_month, NULL, 1),
        ('SI002', N'นาง ศ. ส่งออก', 'Mrs. S Export', @ch_si, @jf_salesman, @pl_staff, 'CC-SI-01', 'AJT', @sales_month, NULL, 1),
        ('SI003', N'นาย ษ. ขายดี', 'Mr. S Sellwell', @ch_si, @jf_salesman, @pl_staff, 'CC-SI-01', 'AJT', @sales_month, NULL, 1),
        ('SIM01', N'นาง ส. หัวหน้า', 'Mrs. S Manager', @ch_si, @jf_section, @pl_sect, 'CC-SI-01', 'AJT', @sales_month, NULL, 1);
    PRINT 'S&I employees created';
END
ELSE
BEGIN
    PRINT 'S&I employees already exist';
END
GO

-- ============================================================
-- 3. เพิ่ม org hierarchy สำหรับ S&I
-- ============================================================
DECLARE @ch_si2 INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'SI');
DECLARE @sales_month2 DATE = (SELECT TOP 1 sales_month FROM dbo.mst_period ORDER BY period_id);

IF NOT EXISTS (SELECT 1 FROM dbo.mst_org_hierarchy WHERE channel_id = @ch_si2 AND salesman_code = 'SI001')
BEGIN
    INSERT INTO dbo.mst_org_hierarchy
        (channel_id, effective_month, salesman_code, direct_sup_code, dept_mgr_code, div_mgr_code, ad_code, is_active)
    VALUES
        (@ch_si2, @sales_month2, 'SI001', 'SIM01', 'DM001', 'DV001', 'AD001', 1),
        (@ch_si2, @sales_month2, 'SI002', 'SIM01', 'DM001', 'DV001', 'AD001', 1),
        (@ch_si2, @sales_month2, 'SI003', 'SIM01', 'DM001', 'DV001', 'AD001', 1);
    PRINT 'S&I org hierarchy created';
END
ELSE
BEGIN
    PRINT 'S&I org hierarchy already exists';
END
GO

-- ============================================================
-- 4. เพิ่ม incentive rate สำหรับ S&I (ตาม MT pattern)
-- ============================================================
DECLARE @ch_si3 INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'SI');
DECLARE @sales_month3 DATE = (SELECT TOP 1 sales_month FROM dbo.mst_period ORDER BY period_id);

IF NOT EXISTS (SELECT 1 FROM dbo.mst_incentive_rate WHERE channel_id = @ch_si3)
BEGIN
    INSERT INTO dbo.mst_incentive_rate
        (channel_id, position_level_id, ws_type, rate_old, rate_new, effective_from, effective_to, is_active)
    SELECT @ch_si3, pl.position_level_id, 'OLD', v.rate_old, v.rate_new, @sales_month3, NULL, 1
    FROM (VALUES
        ('STAFF',    12000.00, 15000.00),
        ('SECT_MGR',  9000.00, 11000.00),
        ('DEPT_MGR',  7000.00,  8500.00),
        ('AD',        5000.00,  6500.00)
    ) v(position_code, rate_old, rate_new)
    JOIN dbo.mst_position_level pl ON pl.position_code = v.position_code;
    PRINT 'S&I incentive rates created';
END
ELSE
BEGIN
    PRINT 'S&I incentive rates already exist';
END
GO

-- ============================================================
-- 5. เพิ่ม product weight สำหรับ S&I (ตาม MT pattern)
-- ============================================================
DECLARE @ch_si4 INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'SI');
DECLARE @sales_month4 DATE = (SELECT TOP 1 sales_month FROM dbo.mst_period ORDER BY period_id);

IF NOT EXISTS (SELECT 1 FROM dbo.mst_product_weight WHERE channel_id = @ch_si4)
BEGIN
    INSERT INTO dbo.mst_product_weight
        (channel_id, product_id, ws_type, weight_percent, effective_from, effective_to, is_active)
    SELECT @ch_si4, p.product_id, 'OLD', v.weight_percent, @sales_month4, NULL, 1
    FROM (VALUES
        ('AJ',  0.3000),
        ('RD',  0.2000),
        ('BD',  0.1500),
        ('YY',  0.1000),
        ('AJP', 0.0800),
        ('PDC', 0.0700)
    ) v(product_code, weight_percent)
    JOIN dbo.mst_product p ON p.product_code = v.product_code;
    PRINT 'S&I product weights created';
END
ELSE
BEGIN
    PRINT 'S&I product weights already exist';
END
GO

-- ============================================================
-- 6. เพิ่ม sample target data สำหรับ S&I
-- ============================================================
DECLARE @ch_si5 INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'SI');
DECLARE @period_id2 INT = (SELECT TOP 1 period_id FROM dbo.mst_period ORDER BY period_id);

IF NOT EXISTS (SELECT 1 FROM dbo.trn_sales_target WHERE channel_id = @ch_si5 AND period_id = @period_id2)
BEGIN
    INSERT INTO dbo.trn_sales_target
        (period_id, channel_id, salesman_code, product_code, target_amount)
    VALUES
        -- SI001 targets
        (@period_id2, @ch_si5, 'SI001', 'AJ',  1000000.00),
        (@period_id2, @ch_si5, 'SI001', 'RD',   600000.00),
        (@period_id2, @ch_si5, 'SI001', 'BD',   400000.00),
        -- SI002 targets
        (@period_id2, @ch_si5, 'SI002', 'AJ',  1200000.00),
        (@period_id2, @ch_si5, 'SI002', 'RD',   700000.00),
        (@period_id2, @ch_si5, 'SI002', 'BD',   500000.00),
        -- SI003 targets
        (@period_id2, @ch_si5, 'SI003', 'AJ',   800000.00),
        (@period_id2, @ch_si5, 'SI003', 'RD',   500000.00),
        (@period_id2, @ch_si5, 'SI003', 'BD',   300000.00);
    PRINT 'S&I sample targets created';
END
ELSE
BEGIN
    PRINT 'S&I sample targets already exist';
END
GO

-- ============================================================
-- 7. เพิ่ม sample actual data สำหรับ S&I
-- ============================================================
DECLARE @ch_si6 INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'SI');
DECLARE @period_id3 INT = (SELECT TOP 1 period_id FROM dbo.mst_period ORDER BY period_id);

IF NOT EXISTS (SELECT 1 FROM dbo.trn_sales_actual WHERE channel_id = @ch_si6 AND period_id = @period_id3)
BEGIN
    INSERT INTO dbo.trn_sales_actual
        (period_id, channel_id, salesman_code, product_code, actual_amount, source_batch_id)
    VALUES
        -- SI001 actuals (105% achievement)
        (@period_id3, @ch_si6, 'SI001', 'AJ',  1050000.00, 'SI_SAMPLE'),
        (@period_id3, @ch_si6, 'SI001', 'RD',   630000.00, 'SI_SAMPLE'),
        (@period_id3, @ch_si6, 'SI001', 'BD',   420000.00, 'SI_SAMPLE'),
        -- SI002 actuals (110% achievement)
        (@period_id3, @ch_si6, 'SI002', 'AJ',  1320000.00, 'SI_SAMPLE'),
        (@period_id3, @ch_si6, 'SI002', 'RD',   770000.00, 'SI_SAMPLE'),
        (@period_id3, @ch_si6, 'SI002', 'BD',   550000.00, 'SI_SAMPLE'),
        -- SI003 actuals (95% achievement)
        (@period_id3, @ch_si6, 'SI003', 'AJ',   760000.00, 'SI_SAMPLE'),
        (@period_id3, @ch_si6, 'SI003', 'RD',   475000.00, 'SI_SAMPLE'),
        (@period_id3, @ch_si6, 'SI003', 'BD',   285000.00, 'SI_SAMPLE');
    PRINT 'S&I sample actuals created';
END
ELSE
BEGIN
    PRINT 'S&I sample actuals already exist';
END
GO

PRINT '';
PRINT '══════════════════════════════════════════════════';
PRINT 'S&I Channel Setup Complete';
PRINT '══════════════════════════════════════════════════';
PRINT 'Next step: Run usp_run_si_incentive_calculation.sql';
GO
