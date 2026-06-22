SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*
Purpose:
- เปลี่ยน product_code ใน [dbo].[mst_tt_product] จาก canonical code (AJ/RD/BD/AJP/RDC/RM/RDNS/PDC/YY/RKR/TKM)
  ไปใช้ TT short alias (A/R/B/AP/Q/M/NS/P/Y/RK/T) ซึ่งเป็น product_code ที่ใช้งานจริงใน TT

- Migrate product_code ใน tables ที่เกี่ยวข้องกับ TT ให้ใช้ short alias ตามมาตรฐาน TT:
    - trn_sales_target (TT channel)
    - trn_sales_actual (TT channel)
    - trn_incentive_detail (TT calc runs)

- อัพเดต SP usp_run_tt_incentive_calculation ให้:
    - JOIN mst_tt_product บน product_code (short alias)
    - สำหรับ SKU rows (SKU-AJ-350): resolve canonical code → TT short alias ผ่าน mst_product.tt_sheet_code

Mapping (canonical → TT short alias):
    AJ → A   |  RD → R   |  BD → B   |  AJP → AP  |  RDC → Q
    RM → M   |  RDNS → NS|  PDC → P  |  YY → Y    |  RKR → RK  |  TKM → T

Note:
- mst_tt_product.mst_product_id ยังคงอ้างอิง mst_product.product_id (canonical) ไว้สำหรับ
  legacy lookups (mst_product_weight, mst_shortage_policy)
- SKU product_code (SKU-AJ-350 ฯลฯ) ไม่เปลี่ยน — stored ตามเดิมใน trn_sales_target/actual
- mst_tt_ws_formula_matrix ใช้ tt_product_id (surrogate key) → ไม่กระทบ
*/

-- ============================================================
-- Step 1: Update mst_tt_product.product_code → TT short alias
-- (idempotent: ถ้า product_code เป็น short alias อยู่แล้ว UPDATE ไม่กระทบ)
-- ============================================================
PRINT 'Step 1: Update mst_tt_product.product_code → TT short alias ...';

-- DROP UQ ก่อน (ป้องกัน duplicate ระหว่าง update)
IF EXISTS (SELECT 1 FROM sys.key_constraints
           WHERE name = 'UQ_mst_tt_product_code'
             AND parent_object_id = OBJECT_ID('dbo.mst_tt_product'))
    ALTER TABLE dbo.mst_tt_product DROP CONSTRAINT UQ_mst_tt_product_code;

UPDATE tp
SET tp.product_code = mp.tt_sheet_code
FROM dbo.mst_tt_product tp
JOIN dbo.mst_product mp ON mp.product_id = tp.mst_product_id
WHERE mp.tt_sheet_code IS NOT NULL;

PRINT CAST(@@ROWCOUNT AS NVARCHAR(20)) + ' rows updated in mst_tt_product';

-- ADD UQ กลับ
ALTER TABLE dbo.mst_tt_product
ADD CONSTRAINT UQ_mst_tt_product_code UNIQUE (product_code);
GO

-- ============================================================
-- Step 2: Revert trn_sales_target (TT, non-SKU) → TT short alias
-- (idempotent: rows ที่เป็น short alias อยู่แล้ว JOIN ไม่ match → 0 rows affected)
-- ============================================================
PRINT 'Step 2: Revert trn_sales_target (TT) → TT short alias ...';

UPDATE ts
SET ts.product_code = mp.tt_sheet_code
FROM dbo.trn_sales_target ts
JOIN dbo.mst_product mp
    ON  mp.product_code    = ts.product_code   -- match canonical code
    AND mp.tt_sheet_code   IS NOT NULL
WHERE ts.channel_id = 2                        -- TT channel
  AND ts.product_code NOT LIKE N'SKU-%';

PRINT CAST(@@ROWCOUNT AS NVARCHAR(20)) + ' rows updated in trn_sales_target';
GO

-- ============================================================
-- Step 3: Revert trn_sales_actual (TT, non-SKU) → TT short alias
-- ============================================================
PRINT 'Step 3: Revert trn_sales_actual (TT) → TT short alias ...';

UPDATE a
SET a.product_code = mp.tt_sheet_code
FROM dbo.trn_sales_actual a
JOIN dbo.mst_product mp
    ON  mp.product_code  = a.product_code
    AND mp.tt_sheet_code IS NOT NULL
WHERE a.channel_id = 2
  AND a.product_code NOT LIKE N'SKU-%';

PRINT CAST(@@ROWCOUNT AS NVARCHAR(20)) + ' rows updated in trn_sales_actual';
GO

-- ============================================================
-- Step 4: Update trn_incentive_detail (TT runs, STAFF rows, non-SKU, non-*)
-- แก้ canonical product_code ที่ถูก INSERT จาก SP รุ่นเก่า → TT short alias
-- ============================================================
PRINT 'Step 4: Update trn_incentive_detail (TT runs) → TT short alias ...';

UPDATE d
SET d.product_code = mp.tt_sheet_code
FROM dbo.trn_incentive_detail d
JOIN dbo.trn_calc_run cr ON cr.calc_run_id = d.calc_run_id
JOIN dbo.mst_product mp
    ON  mp.product_code  = d.product_code
    AND mp.tt_sheet_code IS NOT NULL
WHERE cr.channel_id   = 2              -- TT channel
  AND d.product_code NOT LIKE N'SKU-%'
  AND d.product_code <> N'*';

PRINT CAST(@@ROWCOUNT AS NVARCHAR(20)) + ' rows updated in trn_incentive_detail';
GO

-- ============================================================
-- Step 5: Rebuild vw_tt_formula_ws_matrix
-- (p.product_code ตอนนี้เป็น short alias อัตโนมัติ — rebuild เพื่อ refresh metadata)
-- ============================================================
CREATE OR ALTER VIEW dbo.vw_tt_formula_ws_matrix
AS
SELECT
    c.channel_code,
    m.ws_type,
    p.product_code,         -- TT short alias: A/R/B/AP/Q/M/NS/P/Y/RK/T
    p.product_name_th,
    m.g_group_code,
    m.product_weight_percent,
    m.incentive_base,
    m.use_team_achievement,
    m.effective_from,
    m.effective_to,
    m.is_active
FROM dbo.mst_tt_ws_formula_matrix m
JOIN dbo.mst_channel     c ON c.channel_id    = m.channel_id
JOIN dbo.mst_tt_product  p ON p.tt_product_id = m.tt_product_id
WHERE c.channel_code = N'TT'
  AND m.is_active = 1;
GO

-- ============================================================
-- Step 6: Update usp_run_tt_incentive_calculation
--   - trn_sales_target/actual ใช้ TT short alias แล้ว → JOIN mst_tt_product บน product_code โดยตรง
--   - SKU rows (SKU-AJ-350): strip canonical code (AJ) → lookup mst_product.tt_sheet_code → short alias (A)
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.usp_run_tt_incentive_calculation
    @PeriodCode  NVARCHAR(20),
    @WsType      NVARCHAR(20)  = N'TOP_WS',
    @ApprovedBy  NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @ChannelId        INT,
        @ChannelCode      NVARCHAR(20)  = N'TT',
        @PeriodId         INT,
        @SalesMonth       DATE,
        @RunId            INT,
        @VariablePayMonth DATE,
        @LegacyWsType     NVARCHAR(20);

    SELECT @ChannelId = channel_id FROM dbo.mst_channel WHERE channel_code = @ChannelCode;

    IF @ChannelId IS NULL
        THROW 50001, 'TT channel not found.', 1;

    SELECT @PeriodId = period_id, @SalesMonth = sales_month
    FROM dbo.mst_period
    WHERE period_code = @PeriodCode;

    IF @PeriodId IS NULL
        THROW 50002, 'Period code not found.', 1;

    SET @LegacyWsType = CASE
        WHEN @WsType IN (N'TOP_WS', N'WS_SF', N'WS_WH', N'SF_WH') THEN @WsType
        WHEN @WsType = N'OLD' THEN N'TOP_WS'
        ELSE @WsType
    END;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.trn_sales_target
        WHERE period_id  = @PeriodId
          AND channel_id = @ChannelId
    )
        THROW 50003, 'No TT target rows for the specified period.', 1;

    MERGE dbo.trn_calc_run AS tgt
    USING (SELECT @PeriodId AS period_id, @ChannelId AS channel_id) AS src
        ON tgt.period_id  = src.period_id
       AND tgt.channel_id = src.channel_id
    WHEN MATCHED THEN
        UPDATE SET
            tgt.run_status    = N'CALCULATED',
            tgt.calculated_at = COALESCE(tgt.calculated_at, SYSUTCDATETIME()),
            tgt.updated_at    = SYSUTCDATETIME(),
            tgt.approved_by   = COALESCE(tgt.approved_by, @ApprovedBy)
    WHEN NOT MATCHED THEN
        INSERT (period_id, channel_id, run_status, calculated_at, approved_by)
        VALUES (src.period_id, src.channel_id, N'CALCULATED', SYSUTCDATETIME(), @ApprovedBy);

    SELECT @RunId = calc_run_id
    FROM dbo.trn_calc_run
    WHERE period_id  = @PeriodId
      AND channel_id = @ChannelId;

    SELECT @VariablePayMonth = variable_pay_month
    FROM dbo.mst_payment_cycle
    WHERE sales_month = @SalesMonth
      AND is_active = 1;

    IF @VariablePayMonth IS NULL
        SET @VariablePayMonth = @SalesMonth;

    DELETE FROM dbo.out_for_hr_variable WHERE calc_run_id = @RunId;
    DELETE FROM dbo.trn_incentive_detail WHERE calc_run_id = @RunId;
    IF OBJECT_ID('dbo.trn_tt_special_kpi_detail', 'U') IS NOT NULL
        DELETE FROM dbo.trn_tt_special_kpi_detail WHERE calc_run_id = @RunId;

    ;WITH target_src AS (
        SELECT
            t.salesman_code,
            t.product_code,
            SUM(t.target_amount) AS target_amount,
            MAX(t.pct_salesman)  AS pct_salesman   -- pre-computed goal_multiplier from sheet
        FROM dbo.trn_sales_target t
        WHERE t.period_id  = @PeriodId
          AND t.channel_id = @ChannelId
        GROUP BY t.salesman_code, t.product_code
    ),
    /*  Per-salesman ws_type from mst_org_hierarchy.
        Falls back to @LegacyWsType when no hierarchy row exists. */
    hier_ws AS (
        SELECT DISTINCT
            ts.salesman_code,
            COALESCE(
                (SELECT TOP 1 hh.ws_type
                 FROM dbo.mst_org_hierarchy hh
                 WHERE hh.channel_id    = @ChannelId
                   AND hh.salesman_code = ts.salesman_code
                   AND hh.ws_type IS NOT NULL
                 ORDER BY
                     CASE WHEN hh.effective_month <= @SalesMonth THEN 0 ELSE 1 END,
                     ABS(DATEDIFF(DAY, hh.effective_month, @SalesMonth)),
                     hh.effective_month DESC),
                @LegacyWsType
            ) AS ws_type
        FROM dbo.trn_sales_target ts
        WHERE ts.period_id  = @PeriodId
          AND ts.channel_id = @ChannelId
    ),
    actual_src AS (
        SELECT
            a.salesman_code,
            a.product_code,
            SUM(a.actual_amount) AS actual_amount
        FROM dbo.trn_sales_actual a
        WHERE a.period_id  = @PeriodId
          AND a.channel_id = @ChannelId
        GROUP BY a.salesman_code, a.product_code
    ),
    staff_join AS (
        SELECT
            ts.salesman_code,
            ts.product_code,
            ts.target_amount,
            ts.pct_salesman,
            hw.ws_type,
            COALESCE(ac.actual_amount, 0) AS actual_amount,
            /*  base_product_code: TT short alias ที่ใช้ JOIN กับ mst_tt_product.product_code
                - non-SKU rows: product_code เป็น short alias อยู่แล้ว (A/R/B...)
                - SKU rows (SKU-AJ-350): strip canonical code (AJ) แล้ว lookup tt_sheet_code
                  จาก mst_product เพื่อได้ short alias (A) */
            UPPER(CASE
                WHEN ts.product_code LIKE N'SKU-%' THEN
                    COALESCE(
                        (SELECT mp.tt_sheet_code
                         FROM dbo.mst_product mp
                         WHERE mp.product_code =
                               LEFT(SUBSTRING(ts.product_code, 5, 100),
                                    CHARINDEX('-', SUBSTRING(ts.product_code, 5, 100) + '-') - 1)
                           AND mp.tt_sheet_code IS NOT NULL),
                        LEFT(SUBSTRING(ts.product_code, 5, 100),
                             CHARINDEX('-', SUBSTRING(ts.product_code, 5, 100) + '-') - 1)
                    )
                ELSE ts.product_code   -- already TT short alias
            END) AS base_product_code
        FROM target_src ts
        LEFT JOIN actual_src ac
            ON  ac.salesman_code = ts.salesman_code
            AND ac.product_code  = ts.product_code
        LEFT JOIN hier_ws hw
            ON hw.salesman_code = ts.salesman_code
    ),
    /*  Team-level achievement: sum all target/actual for products
        flagged use_team_achievement = 1 in the formula matrix. */
    team_ach AS (
        SELECT
            t_all.product_code,
            CAST(ROUND(
                SUM(COALESCE(a_all.actual_amount, 0)) / NULLIF(SUM(t_all.target_amount), 0)
            , 4) AS DECIMAL(9,4)) AS team_achievement
        FROM dbo.trn_sales_target t_all
        LEFT JOIN dbo.trn_sales_actual a_all
            ON  a_all.channel_id    = t_all.channel_id
            AND a_all.period_id     = t_all.period_id
            AND a_all.salesman_code = t_all.salesman_code
            AND a_all.product_code  = t_all.product_code
        WHERE t_all.channel_id = @ChannelId
          AND t_all.period_id  = @PeriodId
        GROUP BY t_all.product_code
    ),
    staff_calc AS (
        SELECT
            sj.salesman_code,
            sj.product_code,
            sj.target_amount,
            sj.actual_amount,
            sj.pct_salesman,
            sj.ws_type,
            p.tt_product_id,
            p.mst_product_id AS product_id,    -- ใช้สำหรับ mst_product_weight / mst_shortage_policy
            CAST(ROUND(CASE WHEN sj.target_amount = 0 THEN 0 ELSE sj.actual_amount / sj.target_amount END, 4) AS DECIMAL(9,4)) AS achievement,
            CAST(CASE WHEN sp.shortage_policy_id IS NULL THEN 0 ELSE 1 END AS BIT) AS shortage_flag,
            CAST(ROUND(CASE
                WHEN sp.shortage_policy_id IS NULL THEN
                    CASE
                        WHEN COALESCE(wm.use_team_achievement, 0) = 1
                            THEN COALESCE(ta.team_achievement,
                                          CASE WHEN sj.target_amount = 0 THEN 0
                                               ELSE sj.actual_amount / sj.target_amount END)
                        WHEN sj.target_amount = 0 THEN 0
                        ELSE sj.actual_amount / sj.target_amount
                    END
                ELSE sp.override_achievement
            END, 4) AS DECIMAL(9,4)) AS final_achievement,
            CAST(COALESCE(wm.product_weight_percent, w.weight_percent, 0) AS DECIMAL(9,4)) AS product_weight,
            CAST(COALESCE(wm.incentive_base, rs.rate_new, rs.rate_old, 0) AS DECIMAL(18,2)) AS incentive_base,
            COALESCE(wm.g_group_code, p.g_group_code, N'OT') AS g_group_code
        FROM staff_join sj
        -- JOIN mst_tt_product บน TT short alias
        LEFT JOIN dbo.mst_tt_product p
            ON  p.product_code = sj.base_product_code
            AND p.is_active    = 1
        -- Lookup formula matrix by tt_product_id
        OUTER APPLY (
            SELECT TOP 1 m.product_weight_percent, m.incentive_base, m.g_group_code,
                         m.use_team_achievement
            FROM dbo.mst_tt_ws_formula_matrix m
            WHERE m.channel_id    = @ChannelId
              AND m.tt_product_id = p.tt_product_id
              AND m.ws_type       = COALESCE(sj.ws_type, @LegacyWsType)
              AND m.is_active = 1
              AND m.effective_from <= @SalesMonth
              AND (m.effective_to IS NULL OR m.effective_to >= @SalesMonth)
            ORDER BY m.effective_from DESC
        ) wm
        LEFT JOIN team_ach ta
            ON ta.product_code = sj.product_code
        OUTER APPLY (
            -- Legacy: mst_product_weight ใช้ mst_product.product_id
            SELECT TOP 1 pw.weight_percent
            FROM dbo.mst_product_weight pw
            WHERE pw.channel_id  = @ChannelId
              AND pw.product_id  = p.mst_product_id
              AND pw.ws_type     = COALESCE(sj.ws_type, @LegacyWsType)
              AND pw.is_active = 1
              AND pw.effective_from <= @SalesMonth
              AND (pw.effective_to IS NULL OR pw.effective_to >= @SalesMonth)
            ORDER BY pw.effective_from DESC
        ) w
        LEFT JOIN dbo.mst_shortage_policy sp
            ON sp.product_id     = p.mst_product_id
           AND sp.shortage_month = @SalesMonth
           AND sp.is_active = 1
        OUTER APPLY (
            SELECT TOP 1 ir.rate_old, ir.rate_new
            FROM dbo.mst_incentive_rate ir
            JOIN dbo.mst_position_level pl
              ON pl.position_level_id = ir.position_level_id
            WHERE ir.channel_id   = @ChannelId
              AND pl.position_code = N'STAFF'
              AND ir.ws_type       = COALESCE(sj.ws_type, @LegacyWsType)
              AND ir.is_active     = 1
              AND ir.effective_from <= @SalesMonth
              AND (ir.effective_to IS NULL OR ir.effective_to >= @SalesMonth)
            ORDER BY ir.effective_from DESC
        ) rs
    )
    INSERT INTO dbo.trn_incentive_detail
        (calc_run_id, salesman_code, position_level_code, product_code,
         target_amount, actual_amount, achievement, shortage_flag, final_achievement,
         goal_multiplier, incentive_base, product_weight, incentive_amount)
    SELECT
        @RunId,
        sc.salesman_code,
        N'STAFF',
        sc.product_code,
        sc.target_amount,
        sc.actual_amount,
        sc.achievement,
        sc.shortage_flag,
        sc.final_achievement,
        COALESCE(sc.pct_salesman, g.multiplier, 0),
        sc.incentive_base,
        sc.product_weight,
        CAST(ROUND(sc.incentive_base * COALESCE(sc.pct_salesman, g.multiplier, 0) * sc.product_weight, 2) AS DECIMAL(18,2))
    FROM staff_calc sc
    OUTER APPLY (
        SELECT TOP 1 gt.multiplier
        FROM dbo.mst_goal_threshold gt
        WHERE gt.is_active = 1
          AND sc.final_achievement >= gt.achievement_from
          AND (gt.achievement_to IS NULL OR sc.final_achievement <= gt.achievement_to)
        ORDER BY gt.achievement_from DESC, gt.sequence_no DESC
    ) g
    WHERE sc.target_amount > 0;

    -- -------------------------------------------------------------------------
    -- #staff_rows: snapshot STAFF results for manager cascade
    -- SKU rows: strip canonical code → lookup TT short alias ผ่าน mst_product.tt_sheet_code
    -- -------------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#staff_rows') IS NOT NULL DROP TABLE #staff_rows;
    SELECT
        x.salesman_code,
        x.product_code,
        x.target_amount,
        x.actual_amount,
        x.achievement,
        x.final_achievement,
        x.goal_multiplier,
        COALESCE(tp.g_group_code, N'OT') AS g_group_code
    INTO #staff_rows
    FROM (
        SELECT
            d.salesman_code,
            d.product_code,
            d.target_amount,
            d.actual_amount,
            d.achievement,
            d.final_achievement,
            d.goal_multiplier,
            /*  base_code: TT short alias สำหรับ JOIN กับ mst_tt_product.product_code
                - non-SKU: product_code เป็น short alias อยู่แล้ว
                - SKU rows: strip canonical → lookup tt_sheet_code */
            UPPER(CASE WHEN d.product_code LIKE N'SKU-%'
                       THEN COALESCE(
                                (SELECT mp.tt_sheet_code
                                 FROM dbo.mst_product mp
                                 WHERE mp.product_code =
                                       LEFT(SUBSTRING(d.product_code, 5, 100),
                                            CHARINDEX('-', SUBSTRING(d.product_code, 5, 100) + '-') - 1)
                                   AND mp.tt_sheet_code IS NOT NULL),
                                LEFT(SUBSTRING(d.product_code, 5, 100),
                                     CHARINDEX('-', SUBSTRING(d.product_code, 5, 100) + '-') - 1)
                            )
                       ELSE d.product_code
                  END) AS base_code
        FROM dbo.trn_incentive_detail d
        WHERE d.calc_run_id         = @RunId
          AND d.position_level_code = N'STAFF'
    ) x
    LEFT JOIN dbo.mst_tt_product tp
        ON  tp.product_code = x.base_code
        AND tp.is_active    = 1;

    IF OBJECT_ID('tempdb..#hier_pick') IS NOT NULL DROP TABLE #hier_pick;
    SELECT
        s.salesman_code,
        h.direct_sup_code,
        h.dept_mgr_code,
        h.div_mgr_code,
        h.ad_code
    INTO #hier_pick
    FROM (SELECT DISTINCT salesman_code FROM #staff_rows) s
    OUTER APPLY (
        SELECT TOP 1 hh.direct_sup_code, hh.dept_mgr_code, hh.div_mgr_code, hh.ad_code
        FROM dbo.mst_org_hierarchy hh
        WHERE hh.channel_id    = @ChannelId
          AND hh.salesman_code = s.salesman_code
        ORDER BY
            CASE WHEN hh.effective_month <= @SalesMonth THEN 0 ELSE 1 END,
            ABS(DATEDIFF(DAY, hh.effective_month, @SalesMonth)),
            hh.effective_month DESC
    ) h;

    ;WITH mgr_raw AS (
        SELECT N'SECT_MGR' AS position_level_code, NULLIF(h.direct_sup_code, N'') AS manager_code, N'*' AS product_code,
               SUM(s.target_amount) AS target_amount, SUM(s.actual_amount) AS actual_amount,
               CAST(AVG(CAST(s.goal_multiplier AS DECIMAL(18,6))) AS DECIMAL(18,6)) AS achievement,
               CAST(AVG(CAST(s.goal_multiplier AS DECIMAL(18,6))) AS DECIMAL(18,6)) AS avg_final_achievement
        FROM #staff_rows s
        JOIN #hier_pick h ON h.salesman_code = s.salesman_code
        WHERE NULLIF(h.direct_sup_code, N'') IS NOT NULL
        GROUP BY h.direct_sup_code
        UNION ALL
        SELECT N'DEPT_MGR', NULLIF(h.dept_mgr_code, N''), N'*',
               SUM(s.target_amount), SUM(s.actual_amount),
               CAST(AVG(CAST(s.goal_multiplier AS DECIMAL(18,6))) AS DECIMAL(18,6)),
               CAST(AVG(CAST(s.goal_multiplier AS DECIMAL(18,6))) AS DECIMAL(18,6))
        FROM #staff_rows s
        JOIN #hier_pick h ON h.salesman_code = s.salesman_code
        WHERE NULLIF(h.dept_mgr_code, N'') IS NOT NULL
        GROUP BY h.dept_mgr_code
        UNION ALL
        SELECT N'DIV_MGR', NULLIF(h.div_mgr_code, N''), N'*',
               SUM(s.target_amount), SUM(s.actual_amount),
               CAST(AVG(CAST(s.goal_multiplier AS DECIMAL(18,6))) AS DECIMAL(18,6)),
               CAST(AVG(CAST(s.goal_multiplier AS DECIMAL(18,6))) AS DECIMAL(18,6))
        FROM #staff_rows s
        JOIN #hier_pick h ON h.salesman_code = s.salesman_code
        WHERE NULLIF(h.div_mgr_code, N'') IS NOT NULL
        GROUP BY h.div_mgr_code
        UNION ALL
        SELECT N'AD', NULLIF(h.ad_code, N''), N'*',
               SUM(s.target_amount), SUM(s.actual_amount),
               CAST(AVG(CAST(s.goal_multiplier AS DECIMAL(18,6))) AS DECIMAL(18,6)),
               CAST(AVG(CAST(s.goal_multiplier AS DECIMAL(18,6))) AS DECIMAL(18,6))
        FROM #staff_rows s
        JOIN #hier_pick h ON h.salesman_code = s.salesman_code
        WHERE NULLIF(h.ad_code, N'') IS NOT NULL
        GROUP BY h.ad_code
    ),
    mgr_calc AS (
        SELECT
            m.position_level_code,
            m.manager_code,
            m.product_code,
            CAST(ROUND(m.target_amount, 2) AS DECIMAL(18,2)) AS target_amount,
            CAST(ROUND(m.actual_amount,  2) AS DECIMAL(18,2)) AS actual_amount,
            CAST(ROUND(m.achievement, 4) AS DECIMAL(9,4)) AS achievement,
            CAST(ROUND(m.avg_final_achievement, 4) AS DECIMAL(9,4)) AS final_achievement,
            m.avg_final_achievement AS raw_achievement
        FROM mgr_raw m
    )
    INSERT INTO dbo.trn_incentive_detail
        (calc_run_id, salesman_code, position_level_code, product_code,
         target_amount, actual_amount, achievement, shortage_flag, final_achievement,
         goal_multiplier, incentive_base, product_weight, incentive_amount)
    SELECT
        @RunId,
        mc.manager_code,
        mc.position_level_code,
        mc.product_code,
        mc.target_amount,
        mc.actual_amount,
        mc.achievement,
        CAST(0 AS BIT),
        mc.final_achievement,
        mc.final_achievement,
        rate_data.incentive_base,
        CAST(1.0000 AS DECIMAL(9,4)),
        CAST(ROUND(rate_data.incentive_base * mc.raw_achievement, 2) AS DECIMAL(18,2))
    FROM mgr_calc mc
    OUTER APPLY (
        SELECT CAST(
            CASE
                WHEN mc.position_level_code = N'DIV_MGR' THEN
                    COALESCE(
                        (SELECT TOP 1 COALESCE(ir1.rate_new, ir1.rate_old)
                         FROM dbo.mst_incentive_rate ir1
                         JOIN dbo.mst_position_level pl1 ON pl1.position_level_id = ir1.position_level_id
                         WHERE ir1.channel_id = @ChannelId AND pl1.position_code = N'DIV_MGR'
                           AND ir1.ws_type = @LegacyWsType AND ir1.is_active = 1
                           AND ir1.effective_from <= @SalesMonth
                           AND (ir1.effective_to IS NULL OR ir1.effective_to >= @SalesMonth)
                         ORDER BY ir1.effective_from DESC),
                        (SELECT TOP 1 COALESCE(ir2.rate_new, ir2.rate_old)
                         FROM dbo.mst_incentive_rate ir2
                         JOIN dbo.mst_position_level pl2 ON pl2.position_level_id = ir2.position_level_id
                         WHERE ir2.channel_id = @ChannelId AND pl2.position_code = N'DEPT_MGR'
                           AND ir2.ws_type = @LegacyWsType AND ir2.is_active = 1
                           AND ir2.effective_from <= @SalesMonth
                           AND (ir2.effective_to IS NULL OR ir2.effective_to >= @SalesMonth)
                         ORDER BY ir2.effective_from DESC),
                        0
                    )
                ELSE COALESCE(
                    (SELECT TOP 1 COALESCE(ir3.rate_new, ir3.rate_old)
                     FROM dbo.mst_incentive_rate ir3
                     JOIN dbo.mst_position_level pl3 ON pl3.position_level_id = ir3.position_level_id
                     WHERE ir3.channel_id = @ChannelId AND pl3.position_code = mc.position_level_code
                       AND ir3.ws_type = @LegacyWsType AND ir3.is_active = 1
                       AND ir3.effective_from <= @SalesMonth
                       AND (ir3.effective_to IS NULL OR ir3.effective_to >= @SalesMonth)
                     ORDER BY ir3.effective_from DESC),
                    0
                )
            END
        AS DECIMAL(18,2)) AS incentive_base
    ) rate_data
    WHERE mc.manager_code IS NOT NULL
      AND mc.manager_code <> N'';

    ;WITH agg AS (
        SELECT
            d.salesman_code AS employee_code,
            SUM(CASE WHEN d.position_level_code = N'STAFF'    THEN d.incentive_amount ELSE 0 END) AS incentive_staff,
            SUM(CASE WHEN d.position_level_code = N'SECT_MGR' THEN d.incentive_amount ELSE 0 END) AS incentive_sect,
            SUM(CASE WHEN d.position_level_code = N'DEPT_MGR' THEN d.incentive_amount ELSE 0 END) AS incentive_dept,
            SUM(CASE WHEN d.position_level_code = N'DIV_MGR'  THEN d.incentive_amount ELSE 0 END) AS incentive_div,
            SUM(CASE WHEN d.position_level_code = N'AD'       THEN d.incentive_amount ELSE 0 END) AS incentive_ad,
            COALESCE((SELECT SUM(k.bonus_amount)
                      FROM dbo.trn_tt_special_kpi_detail k
                      WHERE k.calc_run_id   = @RunId
                        AND k.salesman_code = d.salesman_code), 0) AS special_kpi_bonus
        FROM dbo.trn_incentive_detail d
        WHERE d.calc_run_id = @RunId
        GROUP BY d.salesman_code
    )
    INSERT INTO dbo.out_for_hr_variable
        (calc_run_id, employee_code, employee_name_th, position_level_code, channel_code,
         variable_pay_month, incentive_staff, incentive_sect, incentive_dept, incentive_div, incentive_ad,
         gd_incentive_total, total_variable, payment_method)
    SELECT
        @RunId,
        a.employee_code,
        COALESCE(e.employee_name_th, a.employee_code),
        COALESCE(pl.position_code, N'STAFF'),
        N'TT',
        @VariablePayMonth,
        CAST(ROUND(a.incentive_staff, 2) AS DECIMAL(18,2)),
        CAST(ROUND(a.incentive_sect,  2) AS DECIMAL(18,2)),
        CAST(ROUND(a.incentive_dept,  2) AS DECIMAL(18,2)),
        CAST(ROUND(a.incentive_div,   2) AS DECIMAL(18,2)),
        CAST(ROUND(a.incentive_ad,    2) AS DECIMAL(18,2)),
        CAST(ROUND(a.special_kpi_bonus, 2) AS DECIMAL(18,2)),
        CAST(ROUND(a.incentive_staff + a.incentive_sect + a.incentive_dept
                   + a.incentive_div + a.incentive_ad + a.special_kpi_bonus, 2) AS DECIMAL(18,2)),
        N'BANK_TRANSFER'
    FROM agg a
    LEFT JOIN dbo.mst_employee e
        ON  e.employee_code = a.employee_code
        AND e.channel_id    = @ChannelId
    LEFT JOIN dbo.mst_position_level pl
        ON pl.position_level_id = e.position_level_id;

    UPDATE dbo.trn_calc_run
    SET run_status    = N'CALCULATED',
        calculated_at = COALESCE(calculated_at, SYSUTCDATETIME()),
        updated_at    = SYSUTCDATETIME(),
        approved_by   = COALESCE(approved_by, @ApprovedBy)
    WHERE calc_run_id = @RunId;

    SELECT
        @RunId      AS calc_run_id,
        @PeriodCode AS period_code,
        (SELECT COUNT(*) FROM dbo.trn_incentive_detail WHERE calc_run_id = @RunId) AS trn_incentive_detail_rows,
        (SELECT COUNT(*) FROM dbo.out_for_hr_variable   WHERE calc_run_id = @RunId) AS out_for_hr_variable_rows;
END
GO

-- ============================================================
-- Step 7: Verify
-- ============================================================
PRINT 'Verify ...';

SELECT 'mst_tt_product' AS tbl, product_code, g_group_code, mst_product_id
FROM dbo.mst_tt_product ORDER BY product_code;

SELECT 'trn_sales_target (TT)' AS tbl, product_code, COUNT(*) AS cnt
FROM dbo.trn_sales_target WHERE channel_id = 2 GROUP BY product_code ORDER BY product_code;

SELECT 'trn_sales_actual (TT)' AS tbl, product_code, COUNT(*) AS cnt
FROM dbo.trn_sales_actual WHERE channel_id = 2 GROUP BY product_code ORDER BY product_code;
GO
