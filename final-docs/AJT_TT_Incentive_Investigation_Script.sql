/*
AJT TT – Incentive Calculation Investigation Script
Purpose :
  ตรวจสาเหตุที่ผลการคำนวณใน DB ไม่ตรงกับ sheet ทีละ Layer

Layer ที่ตรวจ:
  L1  Context   – period / run / salesman
  L2  Input     – target & actual per product
  L3  Individual achievement
  L4  Team achievement (R, Y = team-level)
  L5  Goal threshold lookup (individual & team)
  L6  Incentive amount per product (DB vs Sheet)
  L7  For HR output
  L8  Product-level cross-check (require vs actual mult)
  L9  Summary pass/fail

How to use:
  1. ปรับ @SalesmanCode และ @PeriodCode ตามที่ต้องการ
  2. ปรับ @TeamProductCsv ถ้า product อื่นๆ ใช้ team-level achievement ด้วย (default: R,Y)
  3. รัน script ทั้งหมด → ดู result set ครั้งละ 1 layer
*/

/*
  Known Fix History (salesman 110001, FY2026-05):
  ─────────────────────────────────────────────────────────────────────
  Fix 1: mst_goal_threshold ปรับ band แรก [0,0.90) mult=0.00 → mult=0.90
         และ shift ทุก tier ขึ้น 1 ระดับ  (script 25_update_mst_goal_threshold_sheet_aligned.sql)
         ผล: 2190 → 4190 (ลด gap จาก -2100 → -100)

  Fix 2: mst_tt_ws_formula_matrix เพิ่ม use_team_achievement=1 สำหรับ RD, YY
         SP usp_run_tt_incentive_calculation เพิ่ม team_ach CTE
         (script 26_add_use_team_achievement_to_formula_matrix.sql)
         ผล: 4190 → 4330 (ลด gap จาก -100 → -40 แต่ยังมี R=-20, Y=+60)

  Remaining gap (สาเหตุ):
    - R: team achievement = 0.92 → band [0.9001,0.9501) → mult=0.95 → 380 (sheet ต้องการ 400/mult=1.0)
    - Y: team achievement = 1.07 → band [1.0601,1.1001) → mult=1.10 → 660 (sheet ต้องการ 600/mult=1.0)
    ทั้ง 2 ต้องการ mult=1.0 ซึ่งต้องการ team_ach ใน [0.9501,1.0001)
    ในข้อมูล test (14 salesmen) R=0.92 และ Y=1.07 ออกนอก band นั้น
    → ข้อมูลต้น test scenario อาจไม่ได้สะท้อนยอดทีมจริงในระบบ production
    → ตรวจด้วย L4 (team achievement) และ L10 (breakdown per ws_type) ด้านล่าง
*/

DECLARE @PeriodCode   NVARCHAR(20)  = N'FY2026-05';
DECLARE @SalesmanCode NVARCHAR(50)  = N'110001';
DECLARE @TeamProductCsv NVARCHAR(MAX) = N'R,Y';  -- products ที่ใช้ team-level achievement

/* ─────────────────────────── resolve IDs ──────────────────────────────── */
DECLARE @tt        INT  = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'TT');
DECLARE @period_id INT  = (SELECT period_id  FROM dbo.mst_period  WHERE period_code  = @PeriodCode);
DECLARE @run_id    INT  = (
    SELECT TOP 1 calc_run_id
    FROM dbo.trn_calc_run
    WHERE channel_id = @tt AND period_id = @period_id
    ORDER BY calc_run_id DESC
);

IF @tt        IS NULL THROW 60001, 'TT channel not found.', 1;
IF @period_id IS NULL THROW 60002, 'Period not found.',     1;
IF @run_id    IS NULL THROW 60003, 'No calc_run found – run calculation first.', 1;

DECLARE @team_products TABLE (product_code NVARCHAR(50) PRIMARY KEY);
INSERT INTO @team_products(product_code)
SELECT LTRIM(RTRIM(value))
FROM STRING_SPLIT(@TeamProductCsv, N',')
WHERE LTRIM(RTRIM(value)) <> N'';

/* ═══════════════════════════════════════════════════════════════════════
   L1  Context
   ═══════════════════════════════════════════════════════════════════════ */
SELECT
    @SalesmanCode AS salesman_code,
    @PeriodCode   AS period_code,
    @period_id    AS period_id,
    @run_id       AS calc_run_id,
    @TeamProductCsv AS team_level_products,
    N'Check L2 next: target & actual inputs' AS next_step;

/* ═══════════════════════════════════════════════════════════════════════
   L2  Target & Actual inputs from DB
       อ้างอิง: sheet 3)Target & Cal (col Target/Actual)
                file  11_3)Target & Cal.values.csv
   ═══════════════════════════════════════════════════════════════════════ */
SELECT
    t.product_code,
    CAST(t.target_amount AS DECIMAL(18,2)) AS db_target,
    CAST(COALESCE(a.actual_amount, 0) AS DECIMAL(18,2)) AS db_actual,
    N'trn_sales_target.target_amount' AS source_target_col,
    N'trn_sales_actual.actual_amount' AS source_actual_col,
    N'sheet: 11_3)Target & Cal.values.csv  col May_T / May_A' AS sheet_ref
FROM dbo.trn_sales_target t
LEFT JOIN dbo.trn_sales_actual a
    ON  a.channel_id  = t.channel_id
    AND a.period_id   = t.period_id
    AND a.salesman_code = t.salesman_code
    AND a.product_code  = t.product_code
WHERE t.channel_id    = @tt
  AND t.period_id     = @period_id
  AND t.salesman_code = @SalesmanCode
ORDER BY t.product_code;

/* ═══════════════════════════════════════════════════════════════════════
   L3  Individual achievement per product
   ═══════════════════════════════════════════════════════════════════════ */
;WITH ind AS (
    SELECT
        t.product_code,
        t.target_amount,
        COALESCE(a.actual_amount, 0) AS actual_amount,
        CAST(ROUND(CASE WHEN t.target_amount = 0 THEN 0
                        ELSE COALESCE(a.actual_amount, 0) / t.target_amount
                   END, 4) AS DECIMAL(9,4)) AS individual_achievement
    FROM dbo.trn_sales_target t
    LEFT JOIN dbo.trn_sales_actual a
        ON  a.channel_id    = t.channel_id
        AND a.period_id     = t.period_id
        AND a.salesman_code = t.salesman_code
        AND a.product_code  = t.product_code
    WHERE t.channel_id    = @tt
      AND t.period_id     = @period_id
      AND t.salesman_code = @SalesmanCode
)
SELECT
    ind.product_code,
    ind.target_amount,
    ind.actual_amount,
    ind.individual_achievement,
    CASE WHEN tp.product_code IS NOT NULL THEN N'TEAM-LEVEL'
         ELSE N'INDIVIDUAL' END AS achievement_type,
    N'sheet: 11_3)Target & Cal.values.csv  col May_P (Pct Actual vs Target)' AS sheet_ref
FROM ind
LEFT JOIN @team_products tp ON tp.product_code = ind.product_code
ORDER BY ind.product_code;

/* ═══════════════════════════════════════════════════════════════════════
   L4  Team achievement per product (สำหรับ R, Y = top-level ws_type pool)
       อ้างอิง: ชีตใช้ยอดรวมทุกคนใน ws_type เดียวกันสำหรับ R และ Y
   ═══════════════════════════════════════════════════════════════════════ */
SELECT
    t.product_code,
    SUM(t.target_amount) AS team_target,
    SUM(COALESCE(a.actual_amount, 0)) AS team_actual,
    CAST(ROUND(SUM(COALESCE(a.actual_amount,0)) / NULLIF(SUM(t.target_amount),0), 4) AS DECIMAL(9,4)) AS team_achievement,
    N'SUM across all salesmen in same ws_type/channel period' AS note,
    N'sheet: 11_3)Target & Cal.values.csv  col May_P → shows team pct for R,Y' AS sheet_ref
FROM dbo.trn_sales_target t
LEFT JOIN dbo.trn_sales_actual a
    ON  a.channel_id    = t.channel_id
    AND a.period_id     = t.period_id
    AND a.salesman_code = t.salesman_code
    AND a.product_code  = t.product_code
WHERE t.channel_id = @tt
  AND t.period_id  = @period_id
  AND t.product_code IN (SELECT product_code FROM @team_products)
GROUP BY t.product_code
ORDER BY t.product_code;

/* ═══════════════════════════════════════════════════════════════════════
   L5  Goal threshold lookup comparison
       Individual vs Team achievement → which multiplier band?
   ═══════════════════════════════════════════════════════════════════════ */
;WITH ind AS (
    SELECT
        t.product_code,
        CAST(ROUND(CASE WHEN t.target_amount = 0 THEN 0
                        ELSE COALESCE(a.actual_amount, 0) / t.target_amount
                   END, 4) AS DECIMAL(9,4)) AS individual_achievement
    FROM dbo.trn_sales_target t
    LEFT JOIN dbo.trn_sales_actual a
        ON  a.channel_id = t.channel_id AND a.period_id = t.period_id
        AND a.salesman_code = t.salesman_code AND a.product_code = t.product_code
    WHERE t.channel_id = @tt AND t.period_id = @period_id AND t.salesman_code = @SalesmanCode
),
team AS (
    SELECT
        t.product_code,
        CAST(ROUND(SUM(COALESCE(a.actual_amount,0)) / NULLIF(SUM(t.target_amount),0), 4) AS DECIMAL(9,4)) AS team_achievement
    FROM dbo.trn_sales_target t
    LEFT JOIN dbo.trn_sales_actual a
        ON  a.channel_id = t.channel_id AND a.period_id = t.period_id
        AND a.salesman_code = t.salesman_code AND a.product_code = t.product_code
    WHERE t.channel_id = @tt AND t.period_id = @period_id
      AND t.product_code IN (SELECT product_code FROM @team_products)
    GROUP BY t.product_code
)
SELECT
    i.product_code,
    i.individual_achievement,
    COALESCE(tm.team_achievement, i.individual_achievement) AS effective_achievement,
    CASE WHEN tp.product_code IS NOT NULL THEN N'TEAM' ELSE N'INDIVIDUAL' END AS achievement_type,
    g_ind.multiplier AS mult_individual,
    COALESCE(g_team.multiplier, g_ind.multiplier) AS mult_effective,
    N'mst_goal_threshold' AS threshold_table
FROM ind i
LEFT JOIN @team_products tp ON tp.product_code = i.product_code
LEFT JOIN team tm ON tm.product_code = i.product_code
OUTER APPLY (
    SELECT TOP 1 gt.multiplier
    FROM dbo.mst_goal_threshold gt
    WHERE gt.is_active = 1
      AND i.individual_achievement >= gt.achievement_from
      AND (gt.achievement_to IS NULL OR i.individual_achievement < gt.achievement_to)
    ORDER BY gt.achievement_from DESC
) g_ind
OUTER APPLY (
    SELECT TOP 1 gt.multiplier
    FROM dbo.mst_goal_threshold gt
    WHERE gt.is_active = 1
      AND COALESCE(tm.team_achievement, i.individual_achievement) >= gt.achievement_from
      AND (gt.achievement_to IS NULL OR COALESCE(tm.team_achievement, i.individual_achievement) < gt.achievement_to)
    ORDER BY gt.achievement_from DESC
) g_team
ORDER BY i.product_code;

/* ═══════════════════════════════════════════════════════════════════════
   L6  Incentive amount comparison: DB (current) vs Sheet
       อ้างอิง: 11_3)Target & Cal.values.csv  col May_I (Staff Incentive)
   ═══════════════════════════════════════════════════════════════════════ */
SELECT
    d.product_code,
    d.incentive_base,
    d.product_weight,
    CAST(d.goal_multiplier AS DECIMAL(9,4)) AS mult_used_in_db,
    d.incentive_amount AS db_incentive_amount,
    -- Sheet reference values for salesman 110001
    CASE d.product_code
        WHEN 'A'  THEN 180.00  WHEN 'R'  THEN 400.00  WHEN 'B'  THEN 1040.00
        WHEN 'P'  THEN 360.00  WHEN 'Y'  THEN 600.00  WHEN 'AP' THEN 200.00
        WHEN 'M'  THEN 190.00  WHEN 'Q'  THEN 520.00  WHEN 'RK' THEN 180.00
        WHEN 'NS' THEN 360.00  WHEN 'T'  THEN 260.00  ELSE NULL
    END AS sheet_incentive_amount,
    d.incentive_amount - CASE d.product_code
        WHEN 'A'  THEN 180.00  WHEN 'R'  THEN 400.00  WHEN 'B'  THEN 1040.00
        WHEN 'P'  THEN 360.00  WHEN 'Y'  THEN 600.00  WHEN 'AP' THEN 200.00
        WHEN 'M'  THEN 190.00  WHEN 'Q'  THEN 520.00  WHEN 'RK' THEN 180.00
        WHEN 'NS' THEN 360.00  WHEN 'T'  THEN 260.00  ELSE 0
    END AS gap_db_minus_sheet,
    N'11_3)Target & Cal.values.csv  col May_I' AS sheet_ref
FROM dbo.trn_incentive_detail d
WHERE d.calc_run_id         = @run_id
  AND d.salesman_code       = @SalesmanCode
  AND d.position_level_code = N'STAFF'
ORDER BY d.product_code;

/* ═══════════════════════════════════════════════════════════════════════
   L7  For HR output
       อ้างอิง: 15_1) For HR.values.csv  col Salesman / Monthly Sales compensation
   ═══════════════════════════════════════════════════════════════════════ */
SELECT
    o.employee_code,
    o.incentive_staff   AS db_incentive_staff,
    o.gd_incentive_total,
    o.total_variable    AS db_total_variable,
    4290.00             AS sheet_monthly_sales_compensation,
    o.total_variable - 4290.00 AS gap_total_variable_vs_sheet,
    N'15_1) For HR.values.csv  col Monthly Sales compensation (=Salesman col)' AS sheet_ref
FROM dbo.out_for_hr_variable o
WHERE o.calc_run_id   = @run_id
  AND o.employee_code = @SalesmanCode;

/* ═══════════════════════════════════════════════════════════════════════
   L8  Required multiplier back-calculation from sheet incentive
       เทียบ: multiplier ที่ชีตใช้จริง vs ที่ DB ใช้
   ═══════════════════════════════════════════════════════════════════════ */
SELECT
    d.product_code,
    d.incentive_base,
    d.product_weight,
    -- What multiplier does the SHEET incentive imply?
    CAST(
        CASE d.product_code
            WHEN 'A'  THEN 180.00  WHEN 'R'  THEN 400.00  WHEN 'B'  THEN 1040.00
            WHEN 'P'  THEN 360.00  WHEN 'Y'  THEN 600.00  WHEN 'AP' THEN 200.00
            WHEN 'M'  THEN 190.00  WHEN 'Q'  THEN 520.00  WHEN 'RK' THEN 180.00
            WHEN 'NS' THEN 360.00  WHEN 'T'  THEN 260.00  ELSE NULL
        END / NULLIF(d.incentive_base * d.product_weight, 0)
    AS DECIMAL(9,4)) AS sheet_implied_multiplier,
    CAST(d.goal_multiplier AS DECIMAL(9,4)) AS db_multiplier_used,
    CASE
        WHEN ABS(CAST(
            CASE d.product_code
                WHEN 'A'  THEN 180.00  WHEN 'R'  THEN 400.00  WHEN 'B'  THEN 1040.00
                WHEN 'P'  THEN 360.00  WHEN 'Y'  THEN 600.00  WHEN 'AP' THEN 200.00
                WHEN 'M'  THEN 190.00  WHEN 'Q'  THEN 520.00  WHEN 'RK' THEN 180.00
                WHEN 'NS' THEN 360.00  WHEN 'T'  THEN 260.00  ELSE 0
            END / NULLIF(d.incentive_base * d.product_weight, 0)
        AS DECIMAL(9,4)) - CAST(d.goal_multiplier AS DECIMAL(9,4))) < 0.0001
            THEN N'PASS'
            ELSE N'FAIL – multiplier mismatch'
    END AS multiplier_status
FROM dbo.trn_incentive_detail d
WHERE d.calc_run_id         = @run_id
  AND d.salesman_code       = @SalesmanCode
  AND d.position_level_code = N'STAFF'
ORDER BY d.product_code;

/* ═══════════════════════════════════════════════════════════════════════
   L9  Summary PASS / FAIL
   ═══════════════════════════════════════════════════════════════════════ */
;WITH total AS (
    SELECT SUM(d.incentive_amount) AS db_total
    FROM dbo.trn_incentive_detail d
    WHERE d.calc_run_id = @run_id AND d.salesman_code = @SalesmanCode AND d.position_level_code = N'STAFF'
)
SELECT
    @SalesmanCode AS salesman_code,
    @PeriodCode   AS period_code,
    db_total      AS db_incentive_staff_total,
    4290.00       AS sheet_incentive_staff_total,
    db_total - 4290.00 AS gap,
    CASE WHEN ABS(db_total - 4290.00) < 1.00 THEN N'PASS' ELSE N'FAIL – see L6/L8 for product-level detail' END AS overall_status,
    N'For remaining gap: R & Y may need team-level achievement (see L4/L5)' AS investigation_note
FROM total;

/* ═══════════════════════════════════════════════════════════════════════
   L10  Team achievement scope breakdown  (ใช้ตรวจเมื่อ R/Y ยังไม่ตรง)
        ตรวจว่า team_target/actual มาจากกี่ salesman และ ws_type ไหนบ้าง
        เป้าหมาย: R team_ach ต้องอยู่ใน [0.9501,1.0001) → mult=1.00 → 400
                  Y team_ach ต้องอยู่ใน [0.9501,1.0001) → mult=1.00 → 600
   ═══════════════════════════════════════════════════════════════════════ */
SELECT
    t.product_code,
    COUNT(DISTINCT t.salesman_code) AS salesman_count,
    SUM(t.target_amount)                              AS team_target,
    SUM(COALESCE(a.actual_amount, 0))                 AS team_actual,
    CAST(SUM(COALESCE(a.actual_amount,0)) /
         NULLIF(SUM(t.target_amount),0) AS DECIMAL(9,4)) AS team_achievement,
    CAST(
        CASE
            WHEN SUM(COALESCE(a.actual_amount,0)) / NULLIF(SUM(t.target_amount),0) >= 1.2001 THEN 1.30
            WHEN SUM(COALESCE(a.actual_amount,0)) / NULLIF(SUM(t.target_amount),0) >= 1.1501 THEN 1.20
            WHEN SUM(COALESCE(a.actual_amount,0)) / NULLIF(SUM(t.target_amount),0) >= 1.1001 THEN 1.15
            WHEN SUM(COALESCE(a.actual_amount,0)) / NULLIF(SUM(t.target_amount),0) >= 1.0601 THEN 1.10
            WHEN SUM(COALESCE(a.actual_amount,0)) / NULLIF(SUM(t.target_amount),0) >= 1.0301 THEN 1.06
            WHEN SUM(COALESCE(a.actual_amount,0)) / NULLIF(SUM(t.target_amount),0) >= 1.0001 THEN 1.03
            WHEN SUM(COALESCE(a.actual_amount,0)) / NULLIF(SUM(t.target_amount),0) >= 0.9501 THEN 1.00
            WHEN SUM(COALESCE(a.actual_amount,0)) / NULLIF(SUM(t.target_amount),0) >= 0.9001 THEN 0.95
            ELSE 0.90
        END AS DECIMAL(9,4)
    ) AS mapped_multiplier,
    CASE t.product_code
        WHEN 'R' THEN CAST(4000 * 0.10 *
            CASE
                WHEN SUM(COALESCE(a.actual_amount,0))/NULLIF(SUM(t.target_amount),0) >= 1.2001 THEN 1.30
                WHEN SUM(COALESCE(a.actual_amount,0))/NULLIF(SUM(t.target_amount),0) >= 1.1501 THEN 1.20
                WHEN SUM(COALESCE(a.actual_amount,0))/NULLIF(SUM(t.target_amount),0) >= 1.1001 THEN 1.15
                WHEN SUM(COALESCE(a.actual_amount,0))/NULLIF(SUM(t.target_amount),0) >= 1.0601 THEN 1.10
                WHEN SUM(COALESCE(a.actual_amount,0))/NULLIF(SUM(t.target_amount),0) >= 1.0301 THEN 1.06
                WHEN SUM(COALESCE(a.actual_amount,0))/NULLIF(SUM(t.target_amount),0) >= 1.0001 THEN 1.03
                WHEN SUM(COALESCE(a.actual_amount,0))/NULLIF(SUM(t.target_amount),0) >= 0.9501 THEN 1.00
                WHEN SUM(COALESCE(a.actual_amount,0))/NULLIF(SUM(t.target_amount),0) >= 0.9001 THEN 0.95
                ELSE 0.90 END AS DECIMAL(18,2))
        WHEN 'Y' THEN CAST(4000 * 0.15 *
            CASE
                WHEN SUM(COALESCE(a.actual_amount,0))/NULLIF(SUM(t.target_amount),0) >= 1.2001 THEN 1.30
                WHEN SUM(COALESCE(a.actual_amount,0))/NULLIF(SUM(t.target_amount),0) >= 1.1501 THEN 1.20
                WHEN SUM(COALESCE(a.actual_amount,0))/NULLIF(SUM(t.target_amount),0) >= 1.1001 THEN 1.15
                WHEN SUM(COALESCE(a.actual_amount,0))/NULLIF(SUM(t.target_amount),0) >= 1.0601 THEN 1.10
                WHEN SUM(COALESCE(a.actual_amount,0))/NULLIF(SUM(t.target_amount),0) >= 1.0301 THEN 1.06
                WHEN SUM(COALESCE(a.actual_amount,0))/NULLIF(SUM(t.target_amount),0) >= 1.0001 THEN 1.03
                WHEN SUM(COALESCE(a.actual_amount,0))/NULLIF(SUM(t.target_amount),0) >= 0.9501 THEN 1.00
                WHEN SUM(COALESCE(a.actual_amount,0))/NULLIF(SUM(t.target_amount),0) >= 0.9001 THEN 0.95
                ELSE 0.90 END AS DECIMAL(18,2))
        ELSE NULL
    END AS estimated_incentive,
    CASE t.product_code WHEN 'R' THEN 400 WHEN 'Y' THEN 600 ELSE NULL END AS sheet_incentive,
    N'team_ach must be in [0.9501,1.0001) for mult=1.00' AS required_band
FROM dbo.trn_sales_target t
LEFT JOIN dbo.trn_sales_actual a
    ON  a.channel_id    = t.channel_id
    AND a.period_id     = t.period_id
    AND a.salesman_code = t.salesman_code
    AND a.product_code  = t.product_code
WHERE t.channel_id = @tt
  AND t.period_id  = @period_id
  AND t.product_code IN (SELECT product_code FROM @team_products)
GROUP BY t.product_code
ORDER BY t.product_code;

