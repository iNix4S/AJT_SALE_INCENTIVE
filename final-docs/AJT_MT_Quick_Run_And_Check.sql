-- ============================================================
-- File    : AJT_MT_Quick_Run_And_Check.sql
-- Purpose : รัน incentive calculation + ตรวจผลรายพนักงาน + ดูข้อมูล MT
-- Usage   : เปลี่ยน @PeriodId ให้ตรงกับ period_id ที่ต้องการ
--           (ดู period_id ↔ period_code ได้จาก Step 0)
-- ============================================================

-- ════════════════════════════════════════════════════════════
-- Step 0 : ดู period ทั้งหมด (หา period_id ที่ต้องใช้)
-- ════════════════════════════════════════════════════════════
SELECT period_id, period_code, sales_month
FROM   dbo.mst_period
ORDER BY period_id;


-- ════════════════════════════════════════════════════════════
-- Step 1 : คำนวณ incentive MT
--          เปลี่ยน @PeriodId = <period_id ที่ต้องการ>
-- ════════════════════════════════════════════════════════════
EXEC dbo.usp_run_mt_incentive_calculation
    @PeriodId   = 1,
    @ApprovedBy = N'system';


-- ════════════════════════════════════════════════════════════
-- Step 2 : ตรวจผล For HR รายพนักงาน (เทียบกับชีต "1) For HR")
--          เปลี่ยน calc_run_id ให้ตรงกับ run ล่าสุด (หรือใช้ sub-query)
-- ════════════════════════════════════════════════════════════

-- 2a) ดู calc_run ล่าสุดของ MT
SELECT TOP 5
    cr.calc_run_id,
    p.period_code,
    p.sales_month,
    cr.created_at,
    cr.approved_by,
    cr.incentive_detail_rows,
    cr.for_hr_rows
FROM   dbo.trn_calc_run cr
JOIN   dbo.mst_period   p  ON p.period_id  = cr.period_id
WHERE  cr.channel_id = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'MT')
ORDER BY cr.calc_run_id DESC;

-- 2b) For HR summary — เรียงตาม employee_code
SELECT
    h.employee_code,
    h.employee_name_th,
    h.position_level_code,
    h.variable_pay_month,
    h.incentive_staff,
    h.incentive_sect,
    h.incentive_dept,
    h.incentive_div,
    h.incentive_ad,
    h.gd_incentive_total,
    h.total_variable,
    h.payment_method
FROM   dbo.out_for_hr_variable h
WHERE  h.calc_run_id = (
           SELECT MAX(calc_run_id)
           FROM   dbo.trn_calc_run
           WHERE  channel_id = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'MT')
       )
ORDER BY h.employee_code;

-- 2c) For HR สำหรับ period เจาะจง (เปลี่ยน period_code ตามต้องการ)
SELECT
    h.employee_code,
    h.employee_name_th,
    h.position_level_code,
    h.total_variable,
    h.variable_pay_month
FROM   dbo.out_for_hr_variable h
JOIN   dbo.trn_calc_run        cr ON cr.calc_run_id = h.calc_run_id
JOIN   dbo.mst_period          p  ON p.period_id    = cr.period_id
WHERE  p.period_code = N'FY2026-04'
  AND  h.channel_code = N'MT'
ORDER BY h.employee_code;


-- ════════════════════════════════════════════════════════════
-- Step 3 : ดู incentive detail รายสินค้า (breakdown ต่อพนักงาน)
--          เปลี่ยน salesman_code ตามต้องการ
-- ════════════════════════════════════════════════════════════
SELECT
    d.salesman_code,
    d.position_level_code,
    d.product_code,
    d.target_amount,
    d.actual_amount,
    CAST(d.achievement * 100         AS DECIMAL(6,2)) AS achievement_pct,
    d.shortage_flag,
    CAST(d.final_achievement * 100   AS DECIMAL(6,2)) AS final_ach_pct,
    CAST(d.goal_multiplier * 100     AS DECIMAL(6,2)) AS multiplier_pct,
    d.incentive_base,
    CAST(d.product_weight * 100      AS DECIMAL(7,4)) AS [weight_%],
    d.incentive_amount
FROM   dbo.trn_incentive_detail d
WHERE  d.calc_run_id  = (
           SELECT MAX(calc_run_id)
           FROM   dbo.trn_calc_run
           WHERE  channel_id = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'MT')
       )
  AND  d.salesman_code = N'5490000701'   -- ← เปลี่ยน salesman_code
ORDER BY d.product_code;


-- ════════════════════════════════════════════════════════════
-- Step 4 : ดู actual pivot รายเดือน (Apr → Mar)
--          เปลี่ยน salesman_code ตามต้องการ
-- ════════════════════════════════════════════════════════════
SELECT *
FROM   dbo.vw_trn_sales_actual_pivot_fiscal_month
WHERE  salesman_code = N'5490000701';   -- ← เปลี่ยน salesman_code


-- ════════════════════════════════════════════════════════════
-- Step 5 : ดู MT incentive rate ทุก position × salesman (เทียบกับชีต)
--          vw_mt_incentive_rate
-- ════════════════════════════════════════════════════════════
SELECT
    r.position_code,
    r.position_name_en,
    r.hierarchy_level,
    r.salesman_code,
    r.rate_old,
    r.rate_new,
    r.rate_effective,
    r.effective_from
FROM   dbo.vw_mt_incentive_rate r
WHERE  r.is_active = 1
ORDER BY r.hierarchy_level, r.salesman_code;


-- ════════════════════════════════════════════════════════════
-- Step 6 : Goal Threshold Step Table (เทียบกับ "2) หลักการคำนวน Table")
--          vw_mt_formula_goal_threshold
-- ════════════════════════════════════════════════════════════
SELECT
    sequence_no                                             AS step_no,
    CAST(achievement_from * 100 AS DECIMAL(6,2))            AS ach_from_pct,
    CAST(ISNULL(achievement_to - 0.0001, 99.9999)
         * 100 AS DECIMAL(6,2))                             AS ach_to_pct,
    CAST(multiplier * 100 AS DECIMAL(6,2))                  AS goal_multiplier_pct,
    achievement_from,
    achievement_to,
    multiplier                                              AS goal_multiplier
FROM   dbo.vw_mt_formula_goal_threshold
ORDER BY sequence_no;


-- ════════════════════════════════════════════════════════════
-- Step 7 : MT incentive matrix (base × weight × multiplier)
--          เทียบกับ "2) หลักการคำนวน Table" ในชีต
-- ════════════════════════════════════════════════════════════

-- 7a) raw matrix: weight % + base rate per salesman × product
--     vw_mt_formula_product_weight
SELECT
    m.salesman_code,
    m.product_code,
    m.product_name_th,
    CAST(m.product_weight_percent * 100 AS DECIMAL(5,4))   AS [weight_%],
    m.incentive_base
FROM   dbo.vw_mt_formula_product_weight m
ORDER BY m.salesman_code, m.product_code;

-- 7b) full matrix × 9 goal bands (pivot แนวนอน)
SELECT
    m.salesman_code,
    m.product_code,
    CAST(m.product_weight_percent * 100 AS DECIMAL(5,4))   AS [weight_%],
    m.incentive_base                                        AS [base_฿],
    MAX(CASE WHEN t.multiplier = 0.90 THEN CAST(ROUND(m.incentive_base * m.product_weight_percent * t.multiplier, 0) AS DECIMAL(9,2)) END) AS [GOAL_90%],
    MAX(CASE WHEN t.multiplier = 0.95 THEN CAST(ROUND(m.incentive_base * m.product_weight_percent * t.multiplier, 0) AS DECIMAL(9,2)) END) AS [GOAL_95%],
    MAX(CASE WHEN t.multiplier = 1.00 THEN CAST(ROUND(m.incentive_base * m.product_weight_percent * t.multiplier, 0) AS DECIMAL(9,2)) END) AS [GOAL_100%],
    MAX(CASE WHEN t.multiplier = 1.03 THEN CAST(ROUND(m.incentive_base * m.product_weight_percent * t.multiplier, 0) AS DECIMAL(9,2)) END) AS [GOAL_103%],
    MAX(CASE WHEN t.multiplier = 1.08 THEN CAST(ROUND(m.incentive_base * m.product_weight_percent * t.multiplier, 0) AS DECIMAL(9,2)) END) AS [GOAL_108%],
    MAX(CASE WHEN t.multiplier = 1.10 THEN CAST(ROUND(m.incentive_base * m.product_weight_percent * t.multiplier, 0) AS DECIMAL(9,2)) END) AS [GOAL_110%],
    MAX(CASE WHEN t.multiplier = 1.15 THEN CAST(ROUND(m.incentive_base * m.product_weight_percent * t.multiplier, 0) AS DECIMAL(9,2)) END) AS [GOAL_115%],
    MAX(CASE WHEN t.multiplier = 1.20 THEN CAST(ROUND(m.incentive_base * m.product_weight_percent * t.multiplier, 0) AS DECIMAL(9,2)) END) AS [GOAL_120%],
    MAX(CASE WHEN t.multiplier = 1.30 THEN CAST(ROUND(m.incentive_base * m.product_weight_percent * t.multiplier, 0) AS DECIMAL(9,2)) END) AS [GOAL_130%]
FROM   dbo.vw_mt_formula_product_weight         m
CROSS JOIN dbo.vw_mt_formula_goal_threshold     t
GROUP BY m.salesman_code, m.product_code, m.product_weight_percent, m.incentive_base
ORDER BY m.salesman_code, m.product_code;

-- 7c) long format × 9 bands (เทียบ vw_tt_formula_incentive_matrix)
--     vw_mt_formula_incentive_matrix
SELECT *
FROM   dbo.vw_mt_formula_incentive_matrix
ORDER BY salesman_code, product_code, band_seq;

-- filter เฉพาะ salesman + band ที่ต้องการ
SELECT *
FROM   dbo.vw_mt_formula_incentive_matrix
WHERE  salesman_code = N'5490000701' AND band_seq = 3;  -- band 100%


-- ════════════════════════════════════════════════════════════
-- Step 8 : ดู target ของ MT รายสินค้า
--          เปลี่ยน period_code ตามต้องการ
-- ════════════════════════════════════════════════════════════
SELECT
    t.salesman_code,
    t.product_code,
    t.target_amount
FROM   dbo.trn_sales_target t
JOIN   dbo.mst_period       p ON p.period_id = t.period_id
WHERE  t.channel_id = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'MT')
  AND  p.period_code = N'FY2026-04'    -- ← เปลี่ยน period_code
ORDER BY t.salesman_code, t.product_code;


-- ════════════════════════════════════════════════════════════
-- Step 9 : ดู actual ของ MT รายสินค้า
--          เปลี่ยน period_code ตามต้องการ
-- ════════════════════════════════════════════════════════════
SELECT
    a.salesman_code,
    a.product_code,
    a.actual_amount,
    a.source_batch_id
FROM   dbo.trn_sales_actual a
JOIN   dbo.mst_period       p ON p.period_id = a.period_id
WHERE  a.channel_id = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'MT')
  AND  p.period_code = N'FY2026-04'    -- ← เปลี่ยน period_code
ORDER BY a.salesman_code, a.product_code;


-- ════════════════════════════════════════════════════════════
-- Step 10 : ดู org hierarchy ต่อ period
--           vw_mt_salesman_hierarchy
-- ════════════════════════════════════════════════════════════
SELECT
    h.period_code,
    h.salesman_code,
    h.sect_mgr_code,
    h.dept_mgr_code,
    h.ad_code,
    h.is_active
FROM   dbo.vw_mt_salesman_hierarchy h
WHERE  h.period_code = N'FY2026-04'   -- ← เปลี่ยน period_code
ORDER BY h.salesman_code;


-- ════════════════════════════════════════════════════════════
-- Step 11 : ดู unified formula catalog (ตรวจ config ทั้งหมดในที่เดียว)
--           vw_mt_formula_catalog
-- ════════════════════════════════════════════════════════════
SELECT *
FROM   dbo.vw_mt_formula_catalog
ORDER BY formula_type, salesman_code, item_code;


-- ════════════════════════════════════════════════════════════
-- Step 12 : ดู product mapping (BI sales code → internal product)
-- ════════════════════════════════════════════════════════════
SELECT
    m.salesman_code,
    m.bi_sales_code,
    m.product_group_code,
    m.internal_product_code,
    m.product_name_th,
    m.product_mapping_type,
    m.effective_month_ym
FROM   dbo.vw_mst_mt_mapping_detail m
WHERE  m.mapping_is_active = 1
ORDER BY m.salesman_code, m.bi_sales_code;
