-- =============================================================
-- AJT_SIS: Master Tables Seed Data — POC
-- Source: 4.System Analyst and Design/01.Raw-Extracts/MT+TT
-- Date: 2026-06-13
-- Idempotent: each block checks IF NOT EXISTS before inserting
-- =============================================================

USE [AJT_SIS];
GO

-- Schema: dbo (default)

-- ----------------------------------------------------------------
-- 1. mst_channel (4 rows)
-- Source: BRD scope — MT, TT, S&I, Laos
-- ----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM dbo.mst_channel)
INSERT INTO dbo.mst_channel (channel_code, channel_name_th, channel_name_en, calc_type, is_active)
VALUES
    ('MT',   'Modern Trade',      'Modern Trade',                  'CASCADE_4_LEVEL', 1),
    ('TT',   'Traditional Trade', 'Traditional Trade',             'SINGLE_SHEET_5_LEVEL_AVG', 1),
    ('SI',   'S&I',               'Specialty & Institutional',     'CASCADE_4_LEVEL', 1),
    ('LAOS', 'Laos',              'Laos',                          'SINGLE_SHEET',    1);
GO

-- ----------------------------------------------------------------
-- 2. mst_position_level (5 rows)
-- Source: MT/09_T_SectAbove.values.csv, TT/08_T_SectAbove.values.csv
-- ----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM dbo.mst_position_level)
INSERT INTO dbo.mst_position_level (position_code, position_name_th, position_name_en, hierarchy_level, is_active)
VALUES
    ('STAFF',    N'พนักงานขาย / Staff', 'Salesman / Staff',    1, 1),
    ('SECT_MGR', 'Section Manager',    'Section Manager',     2, 1),
    ('DEPT_MGR', 'Department Manager', 'Department Manager',  3, 1),
    ('DIV_MGR',  'Division Manager',   'Division Manager',    4, 1),
    ('AD',       'Associate Director', 'Associate Director',  5, 1);
GO

-- ----------------------------------------------------------------
-- 3. mst_goal_threshold (10 rows)
-- Source: MT/01_Top WS.values.csv row header — 0.9, 0.95, 1.00, 1.03, 1.06, 1.10, 1.15, 1.20, 1.30
-- Step-down: achievement >= threshold → use that row's multiplier
-- ----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM dbo.mst_goal_threshold)
INSERT INTO dbo.mst_goal_threshold (achievement_from, achievement_to, multiplier, sequence_no, is_active)
VALUES
    (0.0000, 0.8999, 0.0000,  1, 1),  -- below 90% = no incentive
    (0.9000, 0.9499, 0.9000,  2, 1),  -- >= 90%
    (0.9500, 0.9999, 0.9500,  3, 1),  -- >= 95%
    (1.0000, 1.0299, 1.0000,  4, 1),  -- >= 100%
    (1.0300, 1.0599, 1.0300,  5, 1),  -- >= 103%
    (1.0600, 1.0999, 1.0600,  6, 1),  -- >= 106% (NOTE: OQ-1 re 108%)
    (1.1000, 1.1499, 1.1000,  7, 1),  -- >= 110%
    (1.1500, 1.1999, 1.1500,  8, 1),  -- >= 115%
    (1.2000, 1.2999, 1.2000,  9, 1),  -- >= 120%
    (1.3000, NULL,   1.3000, 10, 1);  -- >= 130% (cap, no upper bound)
GO

-- ----------------------------------------------------------------
-- 4. mst_payment_cycle (12 rows — FY2026-04 to FY2027-03)
-- Source: TT/06_M_Month.values.csv (same as MT/07_M_Month.values.csv)
-- Fixed pays 1 month before Variable
-- ----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM dbo.mst_payment_cycle)
INSERT INTO dbo.mst_payment_cycle (sales_month, variable_pay_month, fixed_pay_month, display_order, is_active)
VALUES
    ('2026-04-01', '2026-06-01', '2026-05-01',  1, 1),  -- Apr-26
    ('2026-05-01', '2026-07-01', '2026-06-01',  2, 1),  -- May-26
    ('2026-06-01', '2026-08-01', '2026-07-01',  3, 1),  -- Jun-26
    ('2026-07-01', '2026-09-01', '2026-08-01',  4, 1),  -- Jul-26
    ('2026-08-01', '2026-10-01', '2026-09-01',  5, 1),  -- Aug-26
    ('2026-09-01', '2026-11-01', '2026-10-01',  6, 1),  -- Sep-26
    ('2026-10-01', '2026-12-01', '2026-11-01',  7, 1),  -- Oct-26
    ('2026-11-01', '2027-01-01', '2026-12-01',  8, 1),  -- Nov-26
    ('2026-12-01', '2027-02-01', '2027-01-01',  9, 1),  -- Dec-26
    ('2027-01-01', '2027-03-01', '2027-02-01', 10, 1),  -- Jan-27
    ('2027-02-01', '2027-04-01', '2027-03-01', 11, 1),  -- Feb-27
    ('2027-03-01', '2027-05-01', '2027-04-01', 12, 1);  -- Mar-27
GO

-- ----------------------------------------------------------------
-- 5. mst_job_function (11 rows)
-- Source: MT/23_ค่าตอบแทนการขายในอัตราคงที่.values.csv (fixed-rate group)
--         + general cascade roles (non-fixed)
-- ----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM dbo.mst_job_function)
INSERT INTO dbo.mst_job_function (job_function_code, job_function_name_th, job_function_name_en, channel_id, is_fixed_rate_eligible, is_active)
VALUES
    -- TT fixed-rate job functions
    ('TT_SR_CV_SALES',  'TT Senior Cash Van Sales',       'TT Senior Cash Van Sales',       2, 1, 1),
    ('TT_SR_CV_FV',     'TT Senior Cash Van Food Vender', 'TT Senior Cash Van Food Vender', 2, 1, 1),
    ('TT_CV_SALES',     'TT Cash Van Sales',              'TT Cash Van Sales',              2, 1, 1),
    ('TT_CV_FV',        'TT Cash Van Food Vender',        'TT Cash Van Food Vender',        2, 1, 1),
    ('SHOP_FRONT',      'Shop Front',                     'Shop Front',                     NULL, 1, 1),
    ('SALES_ASSISTANT', 'Sales Assistant',                'Sales Assistant',                NULL, 1, 1),
    -- General cascade roles (MT + TT, not fixed-rate eligible)
    ('SALESMAN',        N'พนักงานขาย',                    'Salesman',                       NULL, 0, 1),
    ('SECTION_MANAGER', 'Section Manager',               'Section Manager',                NULL, 0, 1),
    ('DEPT_MANAGER',    'Department Manager',            'Department Manager',             NULL, 0, 1),
    ('DIV_MANAGER',     'Division Manager',              'Division Manager',               NULL, 0, 1),
    ('ASSOC_DIRECTOR',  'Associate Director',            'Associate Director',             NULL, 0, 1);
GO

-- ----------------------------------------------------------------
-- 6. mst_fix_rate (6 rows)
-- Source: MT/23_ค่าตอบแทนการขายในอัตราคงที่.values.csv
-- channel_id = 2 (TT), effective_from = 2026-04-01
-- ----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM dbo.mst_fix_rate)
INSERT INTO dbo.mst_fix_rate (channel_id, job_function_id, amount, effective_from, effective_to, is_active)
SELECT 2, jf.job_function_id, v.amount, '2026-04-01', NULL, 1
FROM (VALUES
    ('TT_SR_CV_SALES',  3000.00),
    ('TT_SR_CV_FV',     3000.00),
    ('TT_CV_SALES',     2500.00),
    ('TT_CV_FV',        2500.00),
    ('SHOP_FRONT',      1500.00),
    ('SALES_ASSISTANT', 1200.00)
) AS v(job_function_code, amount)
INNER JOIN dbo.mst_job_function jf ON jf.job_function_code = v.job_function_code;
GO

-- ----------------------------------------------------------------
-- 7. mst_product (11 rows)
-- Source: MT/08_Product.values.csv = TT/07_Product.values.csv
-- GD products: AJI-PLUS (AP), ROSDEE CUBE (Q), ROSDEE MENU (M), ROSDEE NOODLE (NS)
-- ----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM dbo.mst_product)
INSERT INTO dbo.mst_product (product_code, product_name_th, product_name_en, product_group_code, is_gd_product, gd_product_code, is_active)
VALUES
    ('AJ',   N'อายิโนะโมะโต๊ะ',   'AJINOMOTO',       'G1_CORE', 0, NULL, 1),
    ('RD',   N'รสดี',               'ROSDEE',           'G1_CORE', 0, NULL, 1),
    ('BD',   N'เบอร์ดี้',           'BIRDY',            'G1_CORE', 0, NULL, 1),
    ('YY',   N'ยำยำ',               'YUMYUM',           'G3_BB',   0, NULL, 1),
    ('PDC',  N'พาวเดอร์ คอฟฟี่',   'POWDER COFFEE',   'G3_BB',   0, NULL, 1),
    ('AJP',  N'อาจิ-พลัส',          'AJI-PLUS',         'G2_GD',   1, 'AP', 1),
    ('RM',   N'รสดีเมนู',            'ROSDEE MENU',      'G2_GD',   1, 'M',  1),
    ('TKM',  N'ทาคุมิ-อาจิ',         'Takumi-Aji',       'OTHERS',  0, NULL, 1),
    ('RDC',  N'รสดีคิวบ์',           'ROSDEE CUBE',      'G2_GD',   1, 'Q',  1),
    ('RKR',  N'รสดีเมนู กข.',       'ROSDEE MENU KKR', 'OTHERS',  0, NULL, 1),
    ('RDNS', N'รสดีนู้ดเดิ้ล',        'ROSDEE NOODLE',   'G2_GD',   1, 'NS', 1);
GO

-- ----------------------------------------------------------------
-- 8. mst_gd_product (4 rows — derived from mst_product G2_GD)
-- ----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM dbo.mst_gd_product)
INSERT INTO dbo.mst_gd_product (product_id, gd_product_code, gd_product_name_th, gd_product_name_en, channel_id, is_active)
SELECT p.product_id, p.gd_product_code, p.product_name_th, p.product_name_en, NULL, 1
FROM dbo.mst_product p
WHERE p.is_gd_product = 1;
GO

-- ----------------------------------------------------------------
-- 9. mst_gd_payout (40 rows = 4 products × 10 thresholds)
-- Source: MT/01_Top WS (base: AP=200, Q=400, M=200, NS=400)
-- Same thresholds as main GOAL table
-- ----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM dbo.mst_gd_payout)
INSERT INTO dbo.mst_gd_payout
    (gd_product_id, achievement_from, achievement_to, payout_amount, sequence_no, effective_from, effective_to, is_active)
SELECT
    gd.gd_product_id,
    steps.achievement_from,
    steps.achievement_to,
    ROUND(base_amt.base_amount * steps.multiplier, 2),
    steps.seq_no,
    '2026-04-01', NULL, 1
FROM dbo.mst_gd_product gd
CROSS APPLY (
    SELECT CASE gd.gd_product_code
               WHEN 'AP' THEN 200.00
               WHEN 'Q'  THEN 400.00
               WHEN 'M'  THEN 200.00
               WHEN 'NS' THEN 400.00
               ELSE 200.00
           END AS base_amount
) AS base_amt
CROSS JOIN (VALUES
    (0.0000, 0.8999, 0.00,  1),
    (0.9000, 0.9499, 0.90,  2),
    (0.9500, 0.9999, 0.95,  3),
    (1.0000, 1.0299, 1.00,  4),
    (1.0300, 1.0599, 1.03,  5),
    (1.0600, 1.0999, 1.06,  6),
    (1.1000, 1.1499, 1.10,  7),
    (1.1500, 1.1999, 1.15,  8),
    (1.2000, 1.2999, 1.20,  9),
    (1.3000, NULL,   1.30, 10)
) AS steps(achievement_from, achievement_to, multiplier, seq_no);
GO

-- ----------------------------------------------------------------
-- 10. mst_policy_rule (5 rows — open questions as PENDING rules)
-- Source: BRD § Open Questions OQ-1, OQ-7, OQ-8, OQ-9, BR-009
-- ----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM dbo.mst_policy_rule)
INSERT INTO dbo.mst_policy_rule (rule_code, rule_name, rule_value, rule_description, approval_status, effective_from, effective_to, is_active)
VALUES
    ('GOAL_108_POLICY',
     'Achievement 108% Multiplier Policy',
     'PENDING',
     'OQ-1: Confirm achievement 108% uses multiplier 1.06 (not 1.08) per step-down table',
     'PENDING', '2026-04-01', NULL, 1),
    ('GD_INTEGRATION_METHOD',
     'GD Scheme Integration: Additive vs Replace',
     'PENDING',
     'OQ-7/8: GD incentive adds to For HR (additive) OR replaces G2 weight in main formula',
     'PENDING', '2026-04-01', NULL, 1),
    ('GD_PAYOUT_METHOD',
     'GD Payout Output: Merged vs Separate',
     'PENDING',
     'OQ-9: GD incentive merged into single For HR output OR exported as separate output',
     'PENDING', '2026-04-01', NULL, 1),
    ('PRORATE_LOGIC',
     'Mid-Month Employee Prorate Policy',
     'PENDING',
     'OQ-?: Employee join/leave mid-month — apply prorate formula or pay full/no pay',
     'PENDING', '2026-04-01', NULL, 1),
    ('DOUBLE_COUNT_GUARD',
     'GD vs G2 Weight Double-Count Prevention',
     'PENDING',
     'BR-009/OQ-8: Prevent double-count between GD scheme and G2 weight in main calculation',
     'PENDING', '2026-04-01', NULL, 1);
GO

