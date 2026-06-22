-- =============================================================
-- AJT_SIS: Seed + Sample Data — Full Design (All Groups)
-- Date: 2026-06-13  Version: v1.0
-- Groups:
--   A) Interface sample (BI/DWC + HCM + Batch log)
--   B) Transaction sample (target, actual, calc run, incentive detail)
--   C) Output sample (For HR variable + fixed)
--   D) Audit sample (parameter change + approval)
-- Dependency: 01_ajt_sis_poc_master_tables.sql +
--             02_ajt_sis_poc_seed_data.sql +
--             03_ajt_sis_transaction_tables.sql must run first
-- =============================================================

USE [AJT_SIS];
GO

-- ============================================================
-- REFERENCE SETUP: Period เดือน Apr-2026 (ถ้ายังไม่มี)
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM dbo.mst_period WHERE period_code = 'FY2026-04')
INSERT INTO dbo.mst_period (period_code, sales_month, year_no, month_no, status, is_closed)
VALUES ('FY2026-04', '2026-04-01', 2026, 4, 'OPEN', 0);
GO

-- ============================================================
-- M1. MASTER COMPLETENESS: mst_period (12 months)
-- ============================================================
INSERT INTO dbo.mst_period (period_code, sales_month, year_no, month_no, status, is_closed)
SELECT v.period_code, v.sales_month, v.year_no, v.month_no, 'OPEN', 0
FROM (VALUES
    ('FY2026-04', '2026-04-01', 2026, 4),
    ('FY2026-05', '2026-05-01', 2026, 5),
    ('FY2026-06', '2026-06-01', 2026, 6),
    ('FY2026-07', '2026-07-01', 2026, 7),
    ('FY2026-08', '2026-08-01', 2026, 8),
    ('FY2026-09', '2026-09-01', 2026, 9),
    ('FY2026-10', '2026-10-01', 2026, 10),
    ('FY2026-11', '2026-11-01', 2026, 11),
    ('FY2026-12', '2026-12-01', 2026, 12),
    ('FY2027-01', '2027-01-01', 2027, 1),
    ('FY2027-02', '2027-02-01', 2027, 2),
    ('FY2027-03', '2027-03-01', 2027, 3)
) v(period_code, sales_month, year_no, month_no)
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.mst_period p
    WHERE p.period_code = v.period_code
);
GO

-- ============================================================
-- M2. MASTER COMPLETENESS: Unicode repair for Thai labels
-- ============================================================
UPDATE dbo.mst_position_level
SET position_name_th = N'พนักงานขาย / Staff', updated_at = SYSUTCDATETIME()
WHERE position_code = 'STAFF';

UPDATE dbo.mst_job_function
SET job_function_name_th = N'พนักงานขาย', updated_at = SYSUTCDATETIME()
WHERE job_function_code = 'SALESMAN';

UPDATE dbo.mst_product
SET product_name_th = CASE product_code
    WHEN 'AJ' THEN N'อายิโนะโมะโต๊ะ'
    WHEN 'RD' THEN N'รสดี'
    WHEN 'BD' THEN N'เบอร์ดี้'
    WHEN 'YY' THEN N'ยำยำ'
    WHEN 'PDC' THEN N'พาวเดอร์ คอฟฟี่'
    WHEN 'AJP' THEN N'อาจิ-พลัส'
    WHEN 'RM' THEN N'รสดีเมนู'
    WHEN 'TKM' THEN N'ทาคุมิ-อาจิ'
    WHEN 'RDC' THEN N'รสดีคิวบ์'
    WHEN 'RKR' THEN N'รสดีเมนู กข.'
    WHEN 'RDNS' THEN N'รสดีนู้ดเดิ้ล'
END,
updated_at = SYSUTCDATETIME()
WHERE product_code IN ('AJ','RD','BD','YY','PDC','AJP','RM','TKM','RDC','RKR','RDNS');
GO

-- ============================================================
-- M3. MASTER COMPLETENESS: product mapping
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM dbo.mst_product_mapping)
INSERT INTO dbo.mst_product_mapping
    (source_system, source_product_code, target_product_id, mapping_type, remarks, is_active)
SELECT
    'BI', p.product_code, p.product_id, 'DIRECT_PRODUCT_CODE', N'POC direct mapping', 1
FROM dbo.mst_product p;
GO

-- ============================================================
-- M4. MASTER COMPLETENESS: salesman mapping (MT)
-- ============================================================
DECLARE @ch_mt_map INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'MT');

IF @ch_mt_map IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.mst_salesman_mapping)
INSERT INTO dbo.mst_salesman_mapping
    (channel_id, effective_month, bi_sales_code, product_group_code, salesman_code, is_active)
VALUES
    (@ch_mt_map, '2026-04-01', 'ACC001', 'AJ', 'SP001', 1),
    (@ch_mt_map, '2026-04-01', 'ACC001', 'RD', 'SP001', 1),
    (@ch_mt_map, '2026-04-01', 'ACC001', 'BD', 'SP001', 1),
    (@ch_mt_map, '2026-04-01', 'ACC002', 'AJ', 'SP002', 1),
    (@ch_mt_map, '2026-04-01', 'ACC002', 'RD', 'SP002', 1),
    (@ch_mt_map, '2026-04-01', 'ACC002', 'BD', 'SP002', 1),
    (@ch_mt_map, '2026-04-01', 'ACC003', 'AJ', 'SP003', 1),
    (@ch_mt_map, '2026-04-01', 'ACC003', 'RD', 'SP003', 1),
    (@ch_mt_map, '2026-04-01', 'ACC003', 'BD', 'SP003', 1),
    (@ch_mt_map, '2026-04-01', 'ACC004', 'AJ', 'SP004', 1),
    (@ch_mt_map, '2026-04-01', 'ACC004', 'RD', 'SP004', 1),
    (@ch_mt_map, '2026-04-01', 'ACC004', 'BD', 'SP004', 1);
GO

-- ============================================================
-- M5. MASTER COMPLETENESS: employee + org hierarchy
-- ============================================================
DECLARE @ch_mt_emp INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'MT');
DECLARE @ch_tt_emp INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'TT');
DECLARE @jf_salesman INT = (SELECT job_function_id FROM dbo.mst_job_function WHERE job_function_code = 'SALESMAN');
DECLARE @jf_section INT = (SELECT job_function_id FROM dbo.mst_job_function WHERE job_function_code = 'SECTION_MANAGER');
DECLARE @pl_staff INT = (SELECT position_level_id FROM dbo.mst_position_level WHERE position_code = 'STAFF');
DECLARE @pl_sect INT = (SELECT position_level_id FROM dbo.mst_position_level WHERE position_code = 'SECT_MGR');

IF NOT EXISTS (SELECT 1 FROM dbo.mst_employee)
INSERT INTO dbo.mst_employee
    (employee_code, employee_name_th, employee_name_en, channel_id, job_function_id, position_level_id,
     cost_center, company_code, effective_from, effective_to, is_active)
VALUES
    ('SP001', N'นาย ก. ใจดี', 'Mr. A Jaidee', @ch_mt_emp, @jf_salesman, @pl_staff, 'CC-MT-01', 'AJT', '2026-04-01', NULL, 1),
    ('SP002', N'นาย ข. รักชาติ', 'Mr. B Rakchat', @ch_mt_emp, @jf_salesman, @pl_staff, 'CC-MT-01', 'AJT', '2026-04-01', NULL, 1),
    ('SM001', N'นาย ค. มั่นคง', 'Mr. C Mankong', @ch_mt_emp, @jf_section, @pl_sect, 'CC-MT-01', 'AJT', '2026-04-01', NULL, 1),
    ('TT001', N'นาง ง. สดใส', 'Mrs. D Sodsai', @ch_tt_emp, @jf_salesman, @pl_staff, 'CC-TT-01', 'AJT', '2026-04-01', NULL, 1),
    ('TT002', N'นาย จ. มีสุข', 'Mr. E Meesuk', @ch_tt_emp, @jf_salesman, @pl_staff, 'CC-TT-01', 'AJT', '2026-04-01', NULL, 1);

IF @ch_mt_emp IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.mst_org_hierarchy)
INSERT INTO dbo.mst_org_hierarchy
    (channel_id, effective_month, salesman_code, direct_sup_code, dept_mgr_code, div_mgr_code, ad_code, is_active)
VALUES
    (@ch_mt_emp, '2026-04-01', 'SP001', 'SM001', 'DM001', 'DV001', 'AD001', 1),
    (@ch_mt_emp, '2026-04-01', 'SP002', 'SM001', 'DM001', 'DV001', 'AD001', 1),
    (@ch_mt_emp, '2026-04-01', 'SP003', 'SM002', 'DM001', 'DV001', 'AD001', 1),
    (@ch_mt_emp, '2026-04-01', 'SP004', 'SM002', 'DM001', 'DV001', 'AD001', 1);
GO

-- ============================================================
-- M6. MASTER COMPLETENESS: incentive rate / product weight
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM dbo.mst_incentive_rate)
INSERT INTO dbo.mst_incentive_rate
    (channel_id, position_level_id, ws_type, rate_old, rate_new, effective_from, effective_to, is_active)
SELECT c.channel_id, pl.position_level_id, v.ws_type, v.rate_old, v.rate_new, '2026-04-01', NULL, 1
FROM dbo.mst_channel c
JOIN (VALUES
    ('STAFF','OLD',12000.00,15000.00),
    ('SECT_MGR','OLD',9000.00,11000.00),
    ('DEPT_MGR','OLD',7000.00,8500.00),
    ('AD','OLD',5000.00,6500.00)
) v(position_code, ws_type, rate_old, rate_new)
    ON 1 = 1
JOIN dbo.mst_position_level pl ON pl.position_code = v.position_code
WHERE c.channel_code IN ('MT','TT');

IF NOT EXISTS (SELECT 1 FROM dbo.mst_product_weight)
INSERT INTO dbo.mst_product_weight
    (channel_id, product_id, ws_type, weight_percent, effective_from, effective_to, is_active)
SELECT c.channel_id, p.product_id, 'OLD', v.weight_percent, '2026-04-01', NULL, 1
FROM dbo.mst_channel c
JOIN (VALUES
    ('AJ', 0.3000),
    ('RD', 0.2000),
    ('BD', 0.1500)
) v(product_code, weight_percent)
    ON 1 = 1
JOIN dbo.mst_product p ON p.product_code = v.product_code
WHERE c.channel_code IN ('MT','TT');
GO

-- ============================================================
-- M7. MASTER COMPLETENESS: shortage / system parameter
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM dbo.mst_shortage_policy)
INSERT INTO dbo.mst_shortage_policy
    (product_id, shortage_month, override_achievement, reason_code, remarks, is_active)
SELECT p.product_id, '2026-04-01', 1.0000, 'SUPPLY_SHORTAGE', N'สินค้าไม่พอในตลาด ปรับ achievement override ตาม policy', 1
FROM dbo.mst_product p
WHERE p.product_code = 'RD';

IF NOT EXISTS (SELECT 1 FROM dbo.mst_system_parameter)
INSERT INTO dbo.mst_system_parameter
    (parameter_group, parameter_code, parameter_value, parameter_type, effective_from, effective_to, is_active)
VALUES
    ('CALCULATION','GOAL_ROUND_SCALE','4','INT','2026-04-01',NULL,1),
    ('CALCULATION','INCENTIVE_ROUND_SCALE','2','INT','2026-04-01',NULL,1),
    ('EXPORT','DEFAULT_FORMAT','SSRS','STRING','2026-04-01',NULL,1),
    ('POLICY','MIN_ACHIEVEMENT_FOR_PAYOUT','0.90','DECIMAL','2026-04-01',NULL,1);
GO

DECLARE @period_id      INT = (SELECT period_id FROM dbo.mst_period WHERE period_code = 'FY2026-04');
DECLARE @ch_mt          INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'MT');
DECLARE @ch_tt          INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'TT');
DECLARE @calc_run_id_mt INT;
DECLARE @calc_run_id_tt INT;

-- ============================================================
-- A1. INTERFACE: Import Batch Log — BI Sales (MT)
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM dbo.int_import_batch WHERE batch_id = 'BATCH-BI-MT-202604-001')
INSERT INTO dbo.int_import_batch
    (batch_id, batch_type, source_system, data_month, file_name, total_rows, valid_rows, error_rows, status, started_at, completed_at, created_by)
VALUES
    ('BATCH-BI-MT-202604-001', 'BI_SALES', 'BI', '2026-04-01',
     'BI_Sales_MT_202604.csv', 12, 12, 0, 'COMPLETED',
     '2026-05-02 08:00:00', '2026-05-02 08:05:00', 'sales_ops');
GO

-- ============================================================
-- A2. INTERFACE: Import Batch Log — BI Sales (TT)
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM dbo.int_import_batch WHERE batch_id = 'BATCH-BI-TT-202604-001')
INSERT INTO dbo.int_import_batch
    (batch_id, batch_type, source_system, data_month, file_name, total_rows, valid_rows, error_rows, status, started_at, completed_at, created_by)
VALUES
    ('BATCH-BI-TT-202604-001', 'BI_SALES', 'BI', '2026-04-01',
     'BI_Sales_TT_202604.csv', 20, 20, 0, 'COMPLETED',
     '2026-05-02 08:10:00', '2026-05-02 08:14:00', 'sales_ops');
GO

-- ============================================================
-- A3. INTERFACE: Import Batch Log — HCM Employee
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM dbo.int_import_batch WHERE batch_id = 'BATCH-HCM-202604-001')
INSERT INTO dbo.int_import_batch
    (batch_id, batch_type, source_system, data_month, file_name, total_rows, valid_rows, error_rows, status, started_at, completed_at, created_by)
VALUES
    ('BATCH-HCM-202604-001', 'HCM_EMPLOYEE', 'HCM', '2026-04-01',
     'HCM_PersonalEmployment_Main_Active_202604.csv', 5, 5, 0, 'COMPLETED',
     '2026-05-02 08:20:00', '2026-05-02 08:22:00', 'sales_ops');
GO

-- ============================================================
-- A4. INTERFACE: Staging — BI Sales Raw (MT: 4 accounts × 3 products)
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM dbo.stg_bi_sales WHERE batch_id = 'BATCH-BI-MT-202604-001')
INSERT INTO dbo.stg_bi_sales
    (batch_id, source_system, data_month, channel_code,
     bi_sales_code, salesman_code, product_code, actual_amount, actual_qty, raw_row_no, status)
VALUES
    -- Account ACC001 → maps to SP001 (Salesman A) for AJ group
    ('BATCH-BI-MT-202604-001','BI','2026-04-01','MT','ACC001',NULL,'AJ',  980000.00, NULL, 1, 'PROCESSED'),
    ('BATCH-BI-MT-202604-001','BI','2026-04-01','MT','ACC001',NULL,'RD',  540000.00, NULL, 2, 'PROCESSED'),
    ('BATCH-BI-MT-202604-001','BI','2026-04-01','MT','ACC001',NULL,'BD',  320000.00, NULL, 3, 'PROCESSED'),
    -- Account ACC002 → maps to SP002 (Salesman B)
    ('BATCH-BI-MT-202604-001','BI','2026-04-01','MT','ACC002',NULL,'AJ', 1100000.00, NULL, 4, 'PROCESSED'),
    ('BATCH-BI-MT-202604-001','BI','2026-04-01','MT','ACC002',NULL,'RD',  620000.00, NULL, 5, 'PROCESSED'),
    ('BATCH-BI-MT-202604-001','BI','2026-04-01','MT','ACC002',NULL,'BD',  440000.00, NULL, 6, 'PROCESSED'),
    -- Account ACC003 → maps to SP003 (Salesman C — Section Mgr territory)
    ('BATCH-BI-MT-202604-001','BI','2026-04-01','MT','ACC003',NULL,'AJ',  870000.00, NULL, 7, 'PROCESSED'),
    ('BATCH-BI-MT-202604-001','BI','2026-04-01','MT','ACC003',NULL,'RD',  490000.00, NULL, 8, 'PROCESSED'),
    ('BATCH-BI-MT-202604-001','BI','2026-04-01','MT','ACC003',NULL,'BD',  280000.00, NULL, 9, 'PROCESSED'),
    -- Account ACC004 → maps to SP004
    ('BATCH-BI-MT-202604-001','BI','2026-04-01','MT','ACC004',NULL,'AJ',  760000.00, NULL,10, 'PROCESSED'),
    ('BATCH-BI-MT-202604-001','BI','2026-04-01','MT','ACC004',NULL,'RD',  430000.00, NULL,11, 'PROCESSED'),
    ('BATCH-BI-MT-202604-001','BI','2026-04-01','MT','ACC004',NULL,'BD',  215000.00, NULL,12, 'PROCESSED');
GO

-- ============================================================
-- A5. INTERFACE: Staging — BI Sales Raw (TT: Salesman code direct)
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM dbo.stg_bi_sales WHERE batch_id = 'BATCH-BI-TT-202604-001')
INSERT INTO dbo.stg_bi_sales
    (batch_id, source_system, data_month, channel_code,
     bi_sales_code, salesman_code, product_code, actual_amount, actual_qty, raw_row_no, status)
VALUES
    ('BATCH-BI-TT-202604-001','BI','2026-04-01','TT',NULL,'TT001','SKU-AJ-350', 125000.00, 5000, 1, 'PROCESSED'),
    ('BATCH-BI-TT-202604-001','BI','2026-04-01','TT',NULL,'TT001','SKU-AJ-600',  88000.00, 2200, 2, 'PROCESSED'),
    ('BATCH-BI-TT-202604-001','BI','2026-04-01','TT',NULL,'TT001','SKU-RD-400',  67000.00, 3350, 3, 'PROCESSED'),
    ('BATCH-BI-TT-202604-001','BI','2026-04-01','TT',NULL,'TT002','SKU-AJ-350', 143000.00, 5720, 4, 'PROCESSED'),
    ('BATCH-BI-TT-202604-001','BI','2026-04-01','TT',NULL,'TT002','SKU-AJ-600',  92000.00, 2300, 5, 'PROCESSED'),
    ('BATCH-BI-TT-202604-001','BI','2026-04-01','TT',NULL,'TT002','SKU-RD-400',  71000.00, 3550, 6, 'PROCESSED'),
    ('BATCH-BI-TT-202604-001','BI','2026-04-01','TT',NULL,'TT003','SKU-AJ-350',  98000.00, 3920, 7, 'PROCESSED'),
    ('BATCH-BI-TT-202604-001','BI','2026-04-01','TT',NULL,'TT003','SKU-BD-500',  55000.00, 1100, 8, 'PROCESSED');
GO

-- ============================================================
-- A6. INTERFACE: Staging — HCM Employee Raw
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM dbo.stg_hcm_employee WHERE batch_id = 'BATCH-HCM-202604-001')
INSERT INTO dbo.stg_hcm_employee
    (batch_id, source_system, data_month,
     employee_code, employee_name_th, employee_name_en,
     company_code, cost_center, position_code, job_function_code, channel_code,
     employment_status, hire_date, raw_row_no, status)
VALUES
    ('BATCH-HCM-202604-001','HCM','2026-04-01',
    'SP001',N'นาย ก. ใจดี','Mr. A Jaidee',
     'AJT','CC-MT-01','STAFF','JF-MT-STAFF','MT','Active','2020-01-15',1,'PROCESSED'),

    ('BATCH-HCM-202604-001','HCM','2026-04-01',
        'SP002',N'นาย ข. รักชาติ','Mr. B Rakchat',
     'AJT','CC-MT-01','STAFF','JF-MT-STAFF','MT','Active','2021-03-01',2,'PROCESSED'),

    ('BATCH-HCM-202604-001','HCM','2026-04-01',
        'SM001',N'นาย ค. มั่นคง','Mr. C Mankong',
     'AJT','CC-MT-01','SECT_MGR','JF-MT-SECT','MT','Active','2018-07-01',3,'PROCESSED'),

    ('BATCH-HCM-202604-001','HCM','2026-04-01',
        'TT001',N'นาง ง. สดใส','Mrs. D Sodsai',
     'AJT','CC-TT-01','STAFF','JF-TT-STAFF','TT','Active','2022-05-10',4,'PROCESSED'),

    ('BATCH-HCM-202604-001','HCM','2026-04-01',
        'TT002',N'นาย จ. มีสุข','Mr. E Meesuk',
     'AJT','CC-TT-01','STAFF','JF-TT-STAFF','TT','Active','2023-01-01',5,'PROCESSED');
GO

-- ============================================================
-- B1. TRANSACTION: Sales Target — MT Apr-2026
-- ============================================================
DECLARE @period_id INT = (SELECT period_id FROM dbo.mst_period WHERE period_code = 'FY2026-04');
DECLARE @ch_mt     INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'MT');
DECLARE @ch_tt     INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'TT');

IF NOT EXISTS (SELECT 1 FROM dbo.trn_sales_target WHERE period_id = @period_id AND channel_id = @ch_mt)
INSERT INTO dbo.trn_sales_target
    (period_id, channel_id, salesman_code, product_code, target_amount, approved_by, approved_at)
VALUES
    (@period_id, @ch_mt, 'SP001', 'AJ',  900000.00, 'business_owner', '2026-04-01'),
    (@period_id, @ch_mt, 'SP001', 'RD',  500000.00, 'business_owner', '2026-04-01'),
    (@period_id, @ch_mt, 'SP001', 'BD',  300000.00, 'business_owner', '2026-04-01'),
    (@period_id, @ch_mt, 'SP002', 'AJ', 1000000.00, 'business_owner', '2026-04-01'),
    (@period_id, @ch_mt, 'SP002', 'RD',  600000.00, 'business_owner', '2026-04-01'),
    (@period_id, @ch_mt, 'SP002', 'BD',  400000.00, 'business_owner', '2026-04-01');
GO

-- ============================================================
-- B2. TRANSACTION: Sales Target — TT Apr-2026
-- ============================================================
DECLARE @period_id INT = (SELECT period_id FROM dbo.mst_period WHERE period_code = 'FY2026-04');
DECLARE @ch_tt     INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'TT');

IF NOT EXISTS (SELECT 1 FROM dbo.trn_sales_target WHERE period_id = @period_id AND channel_id = @ch_tt)
INSERT INTO dbo.trn_sales_target
    (period_id, channel_id, salesman_code, product_code, target_amount, approved_by, approved_at)
VALUES
    (@period_id, @ch_tt, 'TT001', 'SKU-AJ-350', 120000.00, 'business_owner', '2026-04-01'),
    (@period_id, @ch_tt, 'TT001', 'SKU-AJ-600',  85000.00, 'business_owner', '2026-04-01'),
    (@period_id, @ch_tt, 'TT001', 'SKU-RD-400',  70000.00, 'business_owner', '2026-04-01'),
    (@period_id, @ch_tt, 'TT002', 'SKU-AJ-350', 130000.00, 'business_owner', '2026-04-01'),
    (@period_id, @ch_tt, 'TT002', 'SKU-AJ-600',  90000.00, 'business_owner', '2026-04-01'),
    (@period_id, @ch_tt, 'TT002', 'SKU-RD-400',  75000.00, 'business_owner', '2026-04-01');
GO

-- ============================================================
-- B3. TRANSACTION: Sales Actual — MT Apr-2026 (after mapping)
-- ============================================================
DECLARE @period_id INT = (SELECT period_id FROM dbo.mst_period WHERE period_code = 'FY2026-04');
DECLARE @ch_mt     INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'MT');

IF NOT EXISTS (SELECT 1 FROM dbo.trn_sales_actual WHERE period_id = @period_id AND channel_id = @ch_mt)
INSERT INTO dbo.trn_sales_actual
    (period_id, channel_id, salesman_code, product_code, actual_amount, source_batch_id)
VALUES
    (@period_id, @ch_mt, 'SP001', 'AJ',  980000.00, 'BATCH-BI-MT-202604-001'),
    (@period_id, @ch_mt, 'SP001', 'RD',  540000.00, 'BATCH-BI-MT-202604-001'),
    (@period_id, @ch_mt, 'SP001', 'BD',  320000.00, 'BATCH-BI-MT-202604-001'),
    (@period_id, @ch_mt, 'SP002', 'AJ', 1100000.00, 'BATCH-BI-MT-202604-001'),
    (@period_id, @ch_mt, 'SP002', 'RD',  620000.00, 'BATCH-BI-MT-202604-001'),
    (@period_id, @ch_mt, 'SP002', 'BD',  440000.00, 'BATCH-BI-MT-202604-001');
GO

-- ============================================================
-- B4. TRANSACTION: Sales Actual — TT Apr-2026
-- ============================================================
DECLARE @period_id INT = (SELECT period_id FROM dbo.mst_period WHERE period_code = 'FY2026-04');
DECLARE @ch_tt     INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'TT');

IF NOT EXISTS (SELECT 1 FROM dbo.trn_sales_actual WHERE period_id = @period_id AND channel_id = @ch_tt)
INSERT INTO dbo.trn_sales_actual
    (period_id, channel_id, salesman_code, product_code, actual_amount, actual_qty, source_batch_id)
VALUES
    (@period_id, @ch_tt, 'TT001', 'SKU-AJ-350', 125000.00, 5000, 'BATCH-BI-TT-202604-001'),
    (@period_id, @ch_tt, 'TT001', 'SKU-AJ-600',  88000.00, 2200, 'BATCH-BI-TT-202604-001'),
    (@period_id, @ch_tt, 'TT001', 'SKU-RD-400',  67000.00, 3350, 'BATCH-BI-TT-202604-001'),
    (@period_id, @ch_tt, 'TT002', 'SKU-AJ-350', 143000.00, 5720, 'BATCH-BI-TT-202604-001'),
    (@period_id, @ch_tt, 'TT002', 'SKU-AJ-600',  92000.00, 2300, 'BATCH-BI-TT-202604-001'),
    (@period_id, @ch_tt, 'TT002', 'SKU-RD-400',  71000.00, 3550, 'BATCH-BI-TT-202604-001');
GO

-- ============================================================
-- B5. TRANSACTION: Calc Run (MT + TT Apr-2026)
-- ============================================================
DECLARE @period_id INT = (SELECT period_id FROM dbo.mst_period WHERE period_code = 'FY2026-04');
DECLARE @ch_mt     INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'MT');
DECLARE @ch_tt     INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'TT');

IF NOT EXISTS (SELECT 1 FROM dbo.trn_calc_run WHERE period_id = @period_id AND channel_id = @ch_mt)
INSERT INTO dbo.trn_calc_run
    (period_id, channel_id, run_status, calculated_at, reviewed_at, approved_at, approved_by)
VALUES
    (@period_id, @ch_mt, 'APPROVED', '2026-05-03 09:00:00', '2026-05-04 10:00:00', '2026-05-05 11:00:00', 'business_owner');

IF NOT EXISTS (SELECT 1 FROM dbo.trn_calc_run WHERE period_id = @period_id AND channel_id = @ch_tt)
INSERT INTO dbo.trn_calc_run
    (period_id, channel_id, run_status, calculated_at, reviewed_at, approved_at, approved_by)
VALUES
    (@period_id, @ch_tt, 'APPROVED', '2026-05-03 09:30:00', '2026-05-04 10:30:00', '2026-05-05 11:30:00', 'business_owner');
GO

-- ============================================================
-- B6. TRANSACTION: Incentive Detail — MT Staff Level
-- Achievement examples: SP001/AJ = 980000/900000 = 1.0889 → GOAL 1.06
--                       SP002/AJ = 1100000/1000000 = 1.10   → GOAL 1.10
-- ============================================================
DECLARE @run_mt INT = (
    SELECT cr.calc_run_id
    FROM dbo.trn_calc_run cr
    JOIN dbo.mst_period p ON p.period_id = cr.period_id
    JOIN dbo.mst_channel c ON c.channel_id = cr.channel_id
    WHERE p.period_code = 'FY2026-04' AND c.channel_code = 'MT'
);

IF @run_mt IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.trn_incentive_detail WHERE calc_run_id = @run_mt)
INSERT INTO dbo.trn_incentive_detail
    (calc_run_id, salesman_code, position_level_code, product_code,
     target_amount, actual_amount, achievement, shortage_flag, final_achievement,
     goal_multiplier, incentive_base, product_weight, incentive_amount)
VALUES
    -- SP001 / AJ: achievement 1.0889 → final 1.0889 → GOAL 1.06
    (@run_mt,'SP001','STAFF','AJ',  900000, 980000, 1.0889, 0, 1.0889, 1.0600, 15000, 0.3000, 4770.00),
    -- SP001 / RD: achievement 1.0800 → GOAL 1.06
    (@run_mt,'SP001','STAFF','RD',  500000, 540000, 1.0800, 0, 1.0800, 1.0600,  8000, 0.2000, 1696.00),
    -- SP001 / BD: achievement 1.0667 → GOAL 1.06
    (@run_mt,'SP001','STAFF','BD',  300000, 320000, 1.0667, 0, 1.0667, 1.0600,  5000, 0.1500,  795.00),
    -- SP002 / AJ: achievement 1.10 → GOAL 1.10
    (@run_mt,'SP002','STAFF','AJ', 1000000,1100000, 1.1000, 0, 1.1000, 1.1000, 15000, 0.3000, 4950.00),
    -- SP002 / RD: achievement 1.0333 → GOAL 1.03
    (@run_mt,'SP002','STAFF','RD',  600000, 620000, 1.0333, 0, 1.0333, 1.0300,  8000, 0.2000, 1648.00),
    -- SP002 / BD: achievement 1.10 → GOAL 1.10
    (@run_mt,'SP002','STAFF','BD',  400000, 440000, 1.1000, 0, 1.1000, 1.1000,  5000, 0.1500,  825.00);
GO

-- ============================================================
-- B7. TRANSACTION: GD Incentive Detail — sample
-- ============================================================
DECLARE @run_mt_gd INT = (
    SELECT cr.calc_run_id
    FROM dbo.trn_calc_run cr
    JOIN dbo.mst_period p ON p.period_id = cr.period_id
    JOIN dbo.mst_channel c ON c.channel_id = cr.channel_id
    WHERE p.period_code = 'FY2026-04' AND c.channel_code = 'MT'
);
DECLARE @gd_ap INT = (SELECT gd_product_id FROM dbo.mst_gd_product WHERE gd_product_code = 'AP');
DECLARE @gd_q  INT = (SELECT gd_product_id FROM dbo.mst_gd_product WHERE gd_product_code = 'Q');

IF @run_mt_gd IS NOT NULL AND @gd_ap IS NOT NULL AND @gd_q IS NOT NULL
AND NOT EXISTS (SELECT 1 FROM dbo.trn_gd_incentive_detail WHERE calc_run_id = @run_mt_gd)
INSERT INTO dbo.trn_gd_incentive_detail
    (calc_run_id, salesman_code, gd_product_id, incentive_month, target_amount, actual_amount, achievement, payout_amount)
VALUES
    (@run_mt_gd, 'SP001', @gd_ap, '2026-04-01', 100000.00, 108000.00, 1.0800, 212.00),
    (@run_mt_gd, 'SP001', @gd_q,  '2026-04-01',  80000.00,  88000.00, 1.1000, 440.00),
    (@run_mt_gd, 'SP002', @gd_ap, '2026-04-01', 110000.00, 121000.00, 1.1000, 220.00),
    (@run_mt_gd, 'SP002', @gd_q,  '2026-04-01',  90000.00,  99000.00, 1.1000, 440.00);
GO

-- ============================================================
-- C1. OUTPUT: For HR Variable — MT Apr-2026
-- pay_month = Jun-2026 (from mst_payment_cycle Apr → Jun Variable)
-- ============================================================
DECLARE @run_mt INT = (
    SELECT cr.calc_run_id
    FROM dbo.trn_calc_run cr
    JOIN dbo.mst_period p ON p.period_id = cr.period_id
    JOIN dbo.mst_channel c ON c.channel_id = cr.channel_id
    WHERE p.period_code = 'FY2026-04' AND c.channel_code = 'MT'
);

IF @run_mt IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.out_for_hr_variable WHERE calc_run_id = @run_mt)
INSERT INTO dbo.out_for_hr_variable
    (calc_run_id, employee_code, employee_name_th, position_level_code, channel_code,
     variable_pay_month, incentive_staff, incentive_sect, incentive_dept, incentive_ad,
     gd_incentive_total, total_variable, payment_method)
VALUES
    -- SP001: Staff incentive total = 4770+1696+795 = 7261
    (@run_mt,'SP001',N'นาย ก. ใจดี','STAFF','MT','2026-06-01', 7261.00,0,0,0, 0.00,  7261.00,N'โอนเข้าบัญชี'),
    -- SP002: Staff incentive total = 4950+1648+825 = 7423
    (@run_mt,'SP002',N'นาย ข. รักชาติ','STAFF','MT','2026-06-01', 7423.00,0,0,0, 0.00,  7423.00,N'โอนเข้าบัญชี'),
    -- SM001 (Sect Mgr): cascade ระดับ Sect (ตัวอย่าง)
    (@run_mt,'SM001',N'นาย ค. มั่นคง','SECT_MGR','MT','2026-06-01',0, 3800.00,0,0, 0.00,  3800.00,N'โอนเข้าบัญชี');
GO

-- ============================================================
-- C2. OUTPUT: For HR Fixed — MT Apr-2026
-- fixed_pay_month = May-2026 (from mst_payment_cycle Apr → May Fixed)
-- ============================================================
DECLARE @run_mt INT = (
    SELECT cr.calc_run_id
    FROM dbo.trn_calc_run cr
    JOIN dbo.mst_period p ON p.period_id = cr.period_id
    JOIN dbo.mst_channel c ON c.channel_id = cr.channel_id
    WHERE p.period_code = 'FY2026-04' AND c.channel_code = 'MT'
);

IF @run_mt IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.out_for_hr_fixed WHERE calc_run_id = @run_mt)
INSERT INTO dbo.out_for_hr_fixed
    (calc_run_id, employee_code, employee_name_th, job_function_code, channel_code,
     fixed_pay_month, fix_rate_amount, total_fixed, payment_method)
VALUES
    (@run_mt,'SP001',N'นาย ก. ใจดี','JF-MT-STAFF','MT','2026-05-01', 2000.00, 2000.00,N'โอนเข้าบัญชี'),
    (@run_mt,'SP002',N'นาย ข. รักชาติ','JF-MT-STAFF','MT','2026-05-01', 2000.00, 2000.00,N'โอนเข้าบัญชี'),
    (@run_mt,'SM001',N'นาย ค. มั่นคง','JF-MT-SECT','MT','2026-05-01',  3500.00, 3500.00,N'โอนเข้าบัญชี');
GO

-- ============================================================
-- C3. OUTPUT: Export Batch
-- ============================================================
DECLARE @run_mt_export INT = (
    SELECT cr.calc_run_id
    FROM dbo.trn_calc_run cr
    JOIN dbo.mst_period p ON p.period_id = cr.period_id
    JOIN dbo.mst_channel c ON c.channel_id = cr.channel_id
    WHERE p.period_code = 'FY2026-04' AND c.channel_code = 'MT'
);

IF @run_mt_export IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.out_export_batch WHERE export_batch_id = 'EXP-MT-202604-001')
INSERT INTO dbo.out_export_batch
    (export_batch_id, calc_run_id, export_type, export_format, file_name, total_employees, total_amount, exported_at, exported_by)
VALUES
    ('EXP-MT-202604-001', @run_mt_export, 'ALL', 'SSRS', 'ForHR_MT_202604.xlsx', 3, 20484.00, '2026-05-06 09:00:00', 'sales_ops');
GO

-- ============================================================
-- D1. AUDIT: Parameter Change Log — example
-- (ปรับ goal threshold row 6 จาก 1.08 เป็น 1.06)
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM dbo.aud_parameter_change WHERE table_name = 'mst_goal_threshold' AND record_id = '6')
INSERT INTO dbo.aud_parameter_change
    (table_name, record_id, field_name, old_value, new_value, change_reason, changed_by, changed_at)
VALUES
    ('mst_goal_threshold', '6', 'multiplier', '1.0800', '1.0600',
    N'ยืนยันจาก Business Owner: policy กำหนด 108% -> 1.06 ไม่ใช่ 1.08 (ดู BRD OQ-1)',
     'sales_ops', '2026-04-01 09:00:00');
GO

-- ============================================================
-- D2. AUDIT: Approval Log — MT Apr-2026 run
-- ============================================================
DECLARE @run_mt INT = (
    SELECT cr.calc_run_id
    FROM dbo.trn_calc_run cr
    JOIN dbo.mst_period p ON p.period_id = cr.period_id
    JOIN dbo.mst_channel c ON c.channel_id = cr.channel_id
    WHERE p.period_code = 'FY2026-04' AND c.channel_code = 'MT'
);

IF @run_mt IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.aud_approval_log WHERE calc_run_id = @run_mt)
INSERT INTO dbo.aud_approval_log
    (calc_run_id, action, from_status, to_status, performed_by, performed_at, remarks)
VALUES
    (@run_mt,'SUBMIT',  'DRAFT',      'CALCULATED', 'sales_ops',     '2026-05-03 09:00:00', N'คำนวณครบ MT Apr-2026'),
    (@run_mt,'REVIEW',  'CALCULATED', 'REVIEWED',   'sales_ops',     '2026-05-04 10:00:00', N'ตรวจสอบ trace ครบถ้วน'),
    (@run_mt,'APPROVE', 'REVIEWED',   'APPROVED',   'business_owner','2026-05-05 11:00:00', N'อนุมัติจ่าย');
GO

-- ============================================================
-- R1. FINAL REPAIR: force Thai fields in output table to Unicode
-- ============================================================
UPDATE dbo.out_for_hr_variable
SET employee_name_th = CASE employee_code
        WHEN 'SP001' THEN N'นาย ก. ใจดี'
        WHEN 'SP002' THEN N'นาย ข. รักชาติ'
        WHEN 'SM001' THEN N'นาย ค. มั่นคง'
        ELSE employee_name_th
    END,
    payment_method = N'โอนเข้าบัญชี'
WHERE employee_code IN ('SP001','SP002','SM001');

UPDATE dbo.out_for_hr_fixed
SET employee_name_th = CASE employee_code
        WHEN 'SP001' THEN N'นาย ก. ใจดี'
        WHEN 'SP002' THEN N'นาย ข. รักชาติ'
        WHEN 'SM001' THEN N'นาย ค. มั่นคง'
        ELSE employee_name_th
    END,
    payment_method = N'โอนเข้าบัญชี'
WHERE employee_code IN ('SP001','SP002','SM001');
GO
