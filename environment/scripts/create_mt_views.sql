-- ============================================================
-- File    : create_mt_views.sql
-- Purpose : สร้าง MT database views สำหรับตรวจสอบข้อมูล
--           (คู่ขนานกับ TT views)
-- Views   :
--   1. vw_mt_formula_goal_threshold    ← mst_goal_threshold (active rows)
--   2. vw_mt_incentive_rate            ← incentive rate × position (channel=MT)
--   3. vw_mt_formula_product_weight    ← product weights × base rate (เทียบ vw_tt_formula_ws_matrix)
--   4. vw_mt_formula_incentive_matrix  ← full matrix × 9 goal bands (long format)
--   5. vw_mt_formula_catalog           ← unified formula catalog (เทียบ vw_tt_formula_catalog)
--   6. vw_mt_salesman_hierarchy        ← org hierarchy per period (เทียบ vw_tt_salesman_ws_type)
-- ============================================================

-- ════════════════════════════════════════════════════════════
-- 1. vw_mt_formula_goal_threshold
--    Goal Threshold step table (active rows only)
--    เทียบกับ: vw_tt_formula_goal_threshold
-- ════════════════════════════════════════════════════════════
CREATE OR ALTER VIEW dbo.vw_mt_formula_goal_threshold
AS
SELECT
    goal_threshold_id,
    achievement_from,
    achievement_to,
    multiplier,
    sequence_no,
    is_active
FROM dbo.mst_goal_threshold
WHERE is_active = 1;
GO

-- ════════════════════════════════════════════════════════════
-- 2. vw_mt_incentive_rate
--    Incentive rate ต่อ salesman_code × position level สำหรับ MT
--    เทียบกับ: vw_tt_incentive_rate
-- ════════════════════════════════════════════════════════════
CREATE OR ALTER VIEW dbo.vw_mt_incentive_rate
AS
/*
Purpose:
- MT-specific view for mst_incentive_rate joined with position level.
- Filters channel_code = 'MT' only.
- Shows rate_old, rate_new, and rate_effective (rate_new priority) per salesman × position.
- Use for verification that rates match the approved sheet.

Position codes for MT:
  STAFF     = salesman route (5490000xxx)  → rate 4,000
  SECT_MGR  = section manager (222208, 222235-222238)
  DEPT_MGR  = department manager (222223, 222234)
  AD        = associate director (222222)
*/
SELECT
    pl.position_code,
    pl.position_name_th,
    pl.position_name_en,
    pl.hierarchy_level,
    ir.ws_type                                 AS salesman_code,
    ir.rate_old,
    ir.rate_new,
    COALESCE(ir.rate_new, ir.rate_old)         AS rate_effective,
    ir.effective_from,
    ir.effective_to,
    ir.is_active,
    ir.incentive_rate_id,
    ir.channel_id
FROM dbo.mst_incentive_rate   ir
JOIN dbo.mst_position_level   pl ON pl.position_level_id = ir.position_level_id
JOIN dbo.mst_channel          c  ON c.channel_id         = ir.channel_id
WHERE c.channel_code = N'MT';
GO

-- ════════════════════════════════════════════════════════════
-- 3. vw_mt_formula_product_weight
--    Product weight × incentive base ต่อ salesman × product
--    เทียบกับ: vw_tt_formula_ws_matrix
-- ════════════════════════════════════════════════════════════
CREATE OR ALTER VIEW dbo.vw_mt_formula_product_weight
AS
/*
Purpose:
- แสดง product weight percent + incentive base ต่อ salesman route × product
- ใช้ตรวจสอบว่า weight และ rate ตรงกับ "2) หลักการคำนวน Table" ในชีต
- product_weight_percent × incentive_base × goal_multiplier = incentive ต่อ product
*/
SELECT
    c.channel_code,
    pw.ws_type                                 AS salesman_code,
    p.product_id,
    p.product_code,
    p.product_name_th,
    pw.weight_percent                          AS product_weight_percent,
    COALESCE(ir.rate_new, ir.rate_old)         AS incentive_base,
    ir.rate_old,
    ir.rate_new,
    pw.effective_from,
    pw.effective_to,
    pw.is_active
FROM dbo.mst_product_weight   pw
JOIN dbo.mst_channel          c  ON c.channel_id   = pw.channel_id
JOIN dbo.mst_product          p  ON p.product_id   = pw.product_id
JOIN dbo.mst_incentive_rate   ir ON ir.channel_id  = pw.channel_id
                                AND ir.ws_type      = pw.ws_type
                                AND ir.is_active    = 1
WHERE c.channel_code = N'MT'
  AND pw.is_active   = 1;
GO

-- ════════════════════════════════════════════════════════════
-- 4. vw_mt_formula_incentive_matrix
--    Full matrix: salesman × product × 9 goal bands (long format)
--    เทียบกับ: vw_tt_formula_incentive_matrix
-- ════════════════════════════════════════════════════════════
CREATE OR ALTER VIEW dbo.vw_mt_formula_incentive_matrix
AS
/*
Purpose:
- แสดง incentive ที่จะได้รับต่อ product ในแต่ละ achievement band (9 bands)
- Long format: 1 row per salesman × product × band
- incentive_per_product = incentive_base × product_weight_percent × goal_multiplier
- ใช้ตรวจสอบตาราง "2) หลักการคำนวน Table" ในชีต Excel
- STAFF: ROUND(incentive_per_product, 0) ใน SP
*/
SELECT
    m.salesman_code,
    m.product_code,
    m.product_name_th,
    CAST(m.product_weight_percent * 100 AS DECIMAL(7,4))          AS weight_pct,
    m.incentive_base,
    t.sequence_no                                                   AS band_seq,
    CAST(t.achievement_from * 100 AS DECIMAL(6,2))                 AS ach_from_pct,
    CAST(ISNULL(t.achievement_to, 9.9999) * 100 AS DECIMAL(6,2))  AS ach_to_pct,
    t.achievement_from,
    t.achievement_to,
    CAST(t.multiplier * 100 AS DECIMAL(6,2))                       AS goal_multiplier_pct,
    t.multiplier                                                    AS goal_multiplier,
    -- raw (ก่อน ROUND)
    CAST(m.incentive_base * m.product_weight_percent * t.multiplier
         AS DECIMAL(12,6))                                         AS incentive_raw,
    -- STAFF rounds to 0 dp (position_level_id=1)
    CAST(ROUND(m.incentive_base * m.product_weight_percent * t.multiplier, 0)
         AS DECIMAL(9,2))                                          AS incentive_rounded,
    m.effective_from,
    m.effective_to
FROM dbo.vw_mt_formula_product_weight   m
CROSS JOIN dbo.vw_mt_formula_goal_threshold t;
GO

-- ════════════════════════════════════════════════════════════
-- 5. vw_mt_formula_catalog
--    Unified formula catalog รวม 3 ส่วน
--    เทียบกับ: vw_tt_formula_catalog
-- ════════════════════════════════════════════════════════════
CREATE OR ALTER VIEW dbo.vw_mt_formula_catalog
AS
/*
Purpose:
- Unified catalog รวม GOAL_THRESHOLD, INCENTIVE_RATE, และ PRODUCT_WEIGHT
- ใช้ query single source เพื่อตรวจสอบ formula config ทั้งหมดของ MT
- source_sheet อ้างอิงชื่อ sheet ใน Excel workbook

Columns:
  source_sheet   = ชื่อ sheet อ้างอิง
  formula_type   = GOAL_THRESHOLD | INCENTIVE_RATE | PRODUCT_WEIGHT
  salesman_code  = route code หรือ employee code
  item_code      = product_code หรือ position_code
  value_1        = ค่าหลัก (multiplier / rate_effective / incentive_base)
  value_2        = ค่าเสริม (product_weight_percent)
*/
-- Part 1: Goal Threshold
SELECT
    N'2) หลักการคำนวน Table'             AS source_sheet,
    N'GOAL_THRESHOLD'                     AS formula_type,
    CAST(NULL AS NVARCHAR(50))            AS salesman_code,
    CAST(NULL AS NVARCHAR(50))            AS item_code,
    achievement_from,
    achievement_to,
    CAST(multiplier AS DECIMAL(18,4))     AS value_1,
    CAST(NULL AS DECIMAL(18,4))           AS value_2
FROM dbo.vw_mt_formula_goal_threshold

UNION ALL

-- Part 2: Incentive Rate per salesman
SELECT
    N'1) Incentive Rate',
    N'INCENTIVE_RATE',
    salesman_code,
    position_code,
    CAST(NULL AS DECIMAL(9,4)),
    CAST(NULL AS DECIMAL(9,4)),
    CAST(rate_effective AS DECIMAL(18,4)),
    CAST(NULL AS DECIMAL(18,4))
FROM dbo.vw_mt_incentive_rate
WHERE is_active = 1

UNION ALL

-- Part 3: Product Weight per salesman × product
SELECT
    N'2) หลักการคำนวน Table',
    N'PRODUCT_WEIGHT',
    salesman_code,
    product_code,
    CAST(NULL AS DECIMAL(9,4)),
    CAST(NULL AS DECIMAL(9,4)),
    CAST(incentive_base AS DECIMAL(18,4)),
    CAST(product_weight_percent AS DECIMAL(18,4))
FROM dbo.vw_mt_formula_product_weight;
GO

-- ════════════════════════════════════════════════════════════
-- 6. vw_mt_salesman_hierarchy
--    Org hierarchy ต่อ period สำหรับ MT
--    เทียบกับ: vw_tt_salesman_ws_type
-- ════════════════════════════════════════════════════════════
CREATE OR ALTER VIEW dbo.vw_mt_salesman_hierarchy
AS
/*
Purpose:
- แสดง chain of command ต่อ salesman route ต่อ period
- STAFF → sect_mgr_code (SECT_MGR) → dept_mgr_code (DEPT_MGR) → ad_code (AD)
- MT ไม่มี DIV_MGR level (ad_code อาจ NULL ถ้าไม่ได้กรอกใน hierarchy)
- ใช้ range-based join: เลือก hierarchy ที่ effective_month ล่าสุด ≤ period.sales_month
  เพื่อให้ routes ที่ set up ก่อน period แสดงขึ้นมาถูกต้อง
- เทียบ: vw_tt_salesman_ws_type
*/
SELECT
    p.period_code,
    p.sales_month,
    c.channel_code,
    h.salesman_code,
    h.effective_month          AS hierarchy_effective_month,
    h.direct_sup_code          AS sect_mgr_code,
    h.dept_mgr_code,
    h.ad_code,
    h.is_active
FROM dbo.mst_org_hierarchy h
JOIN dbo.mst_channel       c ON c.channel_id    = h.channel_id
CROSS JOIN dbo.mst_period  p
WHERE c.channel_code = N'MT'
  AND h.effective_month <= p.sales_month
  AND NOT EXISTS (
      -- เลือกเฉพาะ effective_month ล่าสุดสำหรับ salesman × period
      SELECT 1
      FROM   dbo.mst_org_hierarchy h2
      WHERE  h2.channel_id      = h.channel_id
        AND  h2.salesman_code   = h.salesman_code
        AND  h2.effective_month <= p.sales_month
        AND  h2.effective_month >  h.effective_month
  );
GO

-- ════════════════════════════════════════════════════════════
-- Verify: แสดง view list ที่สร้างเสร็จ
-- ════════════════════════════════════════════════════════════
SELECT name, create_date, modify_date
FROM   sys.objects
WHERE  name IN (
    'vw_mt_formula_goal_threshold',
    'vw_mt_incentive_rate',
    'vw_mt_formula_product_weight',
    'vw_mt_formula_incentive_matrix',
    'vw_mt_formula_catalog',
    'vw_mt_salesman_hierarchy'
)
ORDER BY name;
GO
