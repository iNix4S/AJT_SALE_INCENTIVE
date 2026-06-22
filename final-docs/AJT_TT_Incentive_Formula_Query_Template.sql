/*
AJT TT Incentive Formula Query Template
Purpose:
- ให้ทีม Business ใช้ตรวจสูตรคำนวณ TT ตาม ws_type และเดือนที่ต้องการ
- ครอบคลุม matrix, rate, goal threshold, option1 payout, special KPI

วิธีใช้:
1) ตั้งค่า @WsType
2) ใส่ @PeriodCode หรือ @SalesMonth อย่างใดอย่างหนึ่ง
3) รันทีละ section
*/

DECLARE @WsType NVARCHAR(50) = N'TOP_WS';
DECLARE @PeriodCode NVARCHAR(20) = N'FY2026-05';
DECLARE @SalesMonth DATE = NULL;
DECLARE @AchievementForSimulation DECIMAL(9,4) = 1.0500;

IF @SalesMonth IS NULL
BEGIN
    SELECT @SalesMonth = p.sales_month
    FROM dbo.mst_period p
    WHERE p.period_code = @PeriodCode;
END;

IF @SalesMonth IS NULL
BEGIN
    THROW 51001, 'SalesMonth not found. Please set @PeriodCode or @SalesMonth.', 1;
END;

PRINT CONCAT('Using WsType=', @WsType, ', SalesMonth=', CONVERT(NVARCHAR(10), @SalesMonth, 120));

/* ============================================================
Section A: สูตรหลักราย Product ตาม ws_type + เดือนที่เลือก
============================================================ */
;WITH base_matrix AS (
    SELECT
        m.channel_id,
        c.channel_code,
        m.ws_type,
        m.product_id,
        p.product_code,
        p.product_name_th,
        m.g_group_code,
        m.product_weight_percent,
        m.incentive_base,
        m.effective_from,
        m.effective_to
    FROM dbo.mst_tt_ws_formula_matrix m
    JOIN dbo.mst_channel c
      ON c.channel_id = m.channel_id
    JOIN dbo.mst_product p
      ON p.product_id = m.product_id
    WHERE c.channel_code = N'TT'
      AND m.ws_type = @WsType
      AND m.is_active = 1
      AND m.effective_from <= @SalesMonth
      AND (m.effective_to IS NULL OR m.effective_to >= @SalesMonth)
),
rate_staff AS (
    SELECT TOP 1 ir.channel_id, ir.ws_type, COALESCE(ir.rate_new, ir.rate_old, 0) AS rate_staff
    FROM dbo.mst_incentive_rate ir
    JOIN dbo.mst_position_level pl
      ON pl.position_level_id = ir.position_level_id
    JOIN dbo.mst_channel c
      ON c.channel_id = ir.channel_id
    WHERE c.channel_code = N'TT'
      AND ir.ws_type = @WsType
      AND pl.position_code = N'STAFF'
      AND ir.is_active = 1
      AND ir.effective_from <= @SalesMonth
      AND (ir.effective_to IS NULL OR ir.effective_to >= @SalesMonth)
    ORDER BY ir.effective_from DESC
),
rate_sect AS (
    SELECT TOP 1 ir.channel_id, ir.ws_type, COALESCE(ir.rate_new, ir.rate_old, 0) AS rate_sect
    FROM dbo.mst_incentive_rate ir
    JOIN dbo.mst_position_level pl
      ON pl.position_level_id = ir.position_level_id
    JOIN dbo.mst_channel c
      ON c.channel_id = ir.channel_id
    WHERE c.channel_code = N'TT'
      AND ir.ws_type = @WsType
      AND pl.position_code = N'SECT_MGR'
      AND ir.is_active = 1
      AND ir.effective_from <= @SalesMonth
      AND (ir.effective_to IS NULL OR ir.effective_to >= @SalesMonth)
    ORDER BY ir.effective_from DESC
),
rate_dept AS (
    SELECT TOP 1 ir.channel_id, ir.ws_type, COALESCE(ir.rate_new, ir.rate_old, 0) AS rate_dept
    FROM dbo.mst_incentive_rate ir
    JOIN dbo.mst_position_level pl
      ON pl.position_level_id = ir.position_level_id
    JOIN dbo.mst_channel c
      ON c.channel_id = ir.channel_id
    WHERE c.channel_code = N'TT'
      AND ir.ws_type = @WsType
      AND pl.position_code = N'DEPT_MGR'
      AND ir.is_active = 1
      AND ir.effective_from <= @SalesMonth
      AND (ir.effective_to IS NULL OR ir.effective_to >= @SalesMonth)
    ORDER BY ir.effective_from DESC
),
rate_div AS (
    SELECT TOP 1 ir.channel_id, ir.ws_type, COALESCE(ir.rate_new, ir.rate_old, 0) AS rate_div
    FROM dbo.mst_incentive_rate ir
    JOIN dbo.mst_position_level pl
      ON pl.position_level_id = ir.position_level_id
    JOIN dbo.mst_channel c
      ON c.channel_id = ir.channel_id
    WHERE c.channel_code = N'TT'
      AND ir.ws_type = @WsType
      AND pl.position_code = N'DIV_MGR'
      AND ir.is_active = 1
      AND ir.effective_from <= @SalesMonth
      AND (ir.effective_to IS NULL OR ir.effective_to >= @SalesMonth)
    ORDER BY ir.effective_from DESC
),
rate_ad AS (
    SELECT TOP 1 ir.channel_id, ir.ws_type, COALESCE(ir.rate_new, ir.rate_old, 0) AS rate_ad
    FROM dbo.mst_incentive_rate ir
    JOIN dbo.mst_position_level pl
      ON pl.position_level_id = ir.position_level_id
    JOIN dbo.mst_channel c
      ON c.channel_id = ir.channel_id
    WHERE c.channel_code = N'TT'
      AND ir.ws_type = @WsType
      AND pl.position_code = N'AD'
      AND ir.is_active = 1
      AND ir.effective_from <= @SalesMonth
      AND (ir.effective_to IS NULL OR ir.effective_to >= @SalesMonth)
    ORDER BY ir.effective_from DESC
),
kpi AS (
    SELECT
        r.channel_id,
        r.ws_type,
        r.g_group_code,
        r.kpi_threshold,
        r.bonus_amount,
        r.effective_from,
        r.effective_to,
        ROW_NUMBER() OVER (PARTITION BY r.channel_id, r.ws_type, r.g_group_code ORDER BY r.effective_from DESC) AS rn
    FROM dbo.mst_tt_special_kpi_rule r
    JOIN dbo.mst_channel c
      ON c.channel_id = r.channel_id
    WHERE c.channel_code = N'TT'
      AND r.ws_type = @WsType
      AND r.is_active = 1
      AND r.effective_from <= @SalesMonth
      AND (r.effective_to IS NULL OR r.effective_to >= @SalesMonth)
)
SELECT
    bm.ws_type,
    bm.product_code,
    bm.product_name_th,
    bm.g_group_code,
    bm.product_weight_percent,
    bm.incentive_base,
    rs.rate_staff,
    rsc.rate_sect,
    rd.rate_dept,
    COALESCE(rv.rate_div, rd.rate_dept) AS rate_div_with_fallback,
    ra.rate_ad,
    k.kpi_threshold,
    k.bonus_amount AS special_kpi_bonus,
    bm.effective_from,
    bm.effective_to
FROM base_matrix bm
LEFT JOIN rate_staff rs ON 1 = 1
LEFT JOIN rate_sect rsc ON 1 = 1
LEFT JOIN rate_dept rd ON 1 = 1
LEFT JOIN rate_div rv ON 1 = 1
LEFT JOIN rate_ad ra ON 1 = 1
LEFT JOIN kpi k
  ON k.channel_id = bm.channel_id
 AND k.ws_type = bm.ws_type
 AND k.g_group_code = bm.g_group_code
 AND k.rn = 1
ORDER BY bm.g_group_code, bm.product_code;

/* ============================================================
Section B: Goal Threshold Table (ตัวคูณตาม Achievement)
============================================================ */
SELECT
    gt.goal_threshold_id,
    gt.achievement_from,
    gt.achievement_to,
    gt.multiplier,
    gt.sequence_no,
    gt.is_active
FROM dbo.mst_goal_threshold gt
WHERE gt.is_active = 1
ORDER BY gt.achievement_from, gt.sequence_no;

/* ============================================================
Section C: Option1 Band + Payout (ตาม ws_type เดือนที่เลือก)
============================================================ */
SELECT
    b.band_code,
    b.achievement_from,
    b.achievement_to,
    b.sequence_no,
    p.g_group_code,
    p.payout_amount,
    b.effective_from,
    b.effective_to
FROM dbo.mst_tt_option1_band b
JOIN dbo.mst_channel c
  ON c.channel_id = b.channel_id
LEFT JOIN dbo.mst_tt_option1_payout p
  ON p.tt_option1_band_id = b.tt_option1_band_id
 AND p.is_active = 1
WHERE c.channel_code = N'TT'
  AND b.is_active = 1
  AND b.effective_from <= @SalesMonth
  AND (b.effective_to IS NULL OR b.effective_to >= @SalesMonth)
ORDER BY b.sequence_no, p.g_group_code;

/* ============================================================
Section D: Simulation payout ตาม Achievement ที่ระบุ
============================================================ */
;WITH matrix_pick AS (
    SELECT
        m.channel_id,
        m.ws_type,
        p.product_code,
        m.g_group_code,
        m.product_weight_percent,
        m.incentive_base
    FROM dbo.mst_tt_ws_formula_matrix m
    JOIN dbo.mst_channel c
      ON c.channel_id = m.channel_id
    JOIN dbo.mst_product p
      ON p.product_id = m.product_id
    WHERE c.channel_code = N'TT'
      AND m.ws_type = @WsType
      AND m.is_active = 1
      AND m.effective_from <= @SalesMonth
      AND (m.effective_to IS NULL OR m.effective_to >= @SalesMonth)
)
SELECT
    mp.ws_type,
    mp.product_code,
    mp.g_group_code,
    @AchievementForSimulation AS achievement_input,
    goal_pick.multiplier AS goal_multiplier,
    band_pick.band_code AS option1_band_code,
    payout_pick.payout_amount AS option1_payout,
    CAST(ROUND(mp.incentive_base * COALESCE(goal_pick.multiplier, 0) * mp.product_weight_percent, 2) AS DECIMAL(18,2)) AS simulated_staff_incentive
FROM matrix_pick mp
OUTER APPLY (
    SELECT TOP 1 gt.multiplier
    FROM dbo.mst_goal_threshold gt
    WHERE gt.is_active = 1
      AND @AchievementForSimulation >= gt.achievement_from
      AND (gt.achievement_to IS NULL OR @AchievementForSimulation <= gt.achievement_to)
    ORDER BY gt.achievement_from DESC, gt.sequence_no DESC
) goal_pick
OUTER APPLY (
    SELECT TOP 1 b.tt_option1_band_id, b.band_code
    FROM dbo.mst_tt_option1_band b
    WHERE b.channel_id = mp.channel_id
      AND b.is_active = 1
      AND b.effective_from <= @SalesMonth
      AND (b.effective_to IS NULL OR b.effective_to >= @SalesMonth)
      AND @AchievementForSimulation >= b.achievement_from
      AND (b.achievement_to IS NULL OR @AchievementForSimulation <= b.achievement_to)
    ORDER BY b.sequence_no DESC
) band_pick
OUTER APPLY (
    SELECT TOP 1 p.payout_amount
    FROM dbo.mst_tt_option1_payout p
    WHERE p.tt_option1_band_id = band_pick.tt_option1_band_id
      AND p.g_group_code = mp.g_group_code
      AND p.is_active = 1
) payout_pick
ORDER BY mp.g_group_code, mp.product_code;
