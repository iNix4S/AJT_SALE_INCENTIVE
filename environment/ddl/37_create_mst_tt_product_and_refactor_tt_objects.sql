SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*
Purpose:
- Create [dbo].[mst_tt_product] as TT-specific product master.
- Migrate TT product data from mst_product.
- Add tt_product_id FK column to mst_tt_ws_formula_matrix.
- Update vw_tt_formula_ws_matrix, vw_tt_incentive_formula_definition to use mst_tt_product.
- Update usp_run_tt_incentive_calculation to:
    (1) Replace hardcoded CASE alias mapping with mst_tt_product.tt_sheet_code lookup
    (2) Use mst_tt_product instead of mst_product for TT product lookup
    (3) Use tt_product_id for mst_tt_ws_formula_matrix JOIN
  Note: mst_product_weight and mst_shortage_policy still use mst_product.product_id.
        mst_tt_product.mst_product_id stores the reference for those legacy lookups.

Background:
- MT uses product_group_code for grouping; product_code is a subset.
- TT uses product_code directly (sheet "Actual" stores short aliases per salesman×product).
- Before: SP had hardcoded CASE (A→AJ, R→RD…) — fragile when products change.
- After: lookup mst_tt_product.tt_sheet_code — adding a product only requires INSERT.
*/

-- ============================================================
-- Step 1: Create mst_tt_product
-- ============================================================
-- Drop FK on mst_tt_ws_formula_matrix first (prevents DROP TABLE from failing on re-run)
IF OBJECT_ID('dbo.FK_formula_matrix_tt_product', 'F') IS NOT NULL
    ALTER TABLE dbo.mst_tt_ws_formula_matrix DROP CONSTRAINT FK_formula_matrix_tt_product;
IF OBJECT_ID('dbo.FK_mst_tt_ws_formula_matrix_tt_product', 'F') IS NOT NULL
    ALTER TABLE dbo.mst_tt_ws_formula_matrix DROP CONSTRAINT FK_mst_tt_ws_formula_matrix_tt_product;
GO

IF OBJECT_ID('dbo.mst_tt_product', 'U') IS NOT NULL
    DROP TABLE dbo.mst_tt_product;

CREATE TABLE dbo.mst_tt_product (
    tt_product_id         INT           IDENTITY(1,1) NOT NULL,
    product_code          NVARCHAR(50)  NOT NULL,           -- canonical code: AJ / RD / BD / AJP ...
    product_name_th       NVARCHAR(200) NULL,
    product_name_en       NVARCHAR(200) NULL,
    product_group_id      INT           NULL,               -- FK → mst_product_group
    g_group_code          NVARCHAR(20)  NULL,               -- G1 / G2 / G3 / OT (denormalized for joins)
    mst_product_id        INT           NULL,               -- reference to mst_product.product_id (for legacy FKs)
    is_active             BIT           NOT NULL CONSTRAINT DF_mst_tt_product_is_active    DEFAULT 1,
    created_at            DATETIME2(0)  NOT NULL CONSTRAINT DF_mst_tt_product_created_at  DEFAULT SYSUTCDATETIME(),
    updated_at            DATETIME2(0)  NULL,
    CONSTRAINT PK_mst_tt_product      PRIMARY KEY (tt_product_id),
    CONSTRAINT UQ_mst_tt_product_code UNIQUE (product_code)
);
GO

-- ============================================================
-- Step 2: Seed from mst_product (rows that have tt_sheet_code in mst_product)
-- product_code = TT short alias (mst_product.tt_sheet_code)
-- ============================================================
INSERT INTO dbo.mst_tt_product
    (product_code, product_name_th, product_name_en,
     product_group_id, g_group_code, mst_product_id, is_active)
SELECT
    p.tt_sheet_code,       -- TT short alias เป็น product_code
    p.product_name_th,
    p.product_name_en,
    p.product_group_id,
    pg.g_group_code,
    p.product_id,
    p.is_active
FROM dbo.mst_product p
LEFT JOIN dbo.mst_product_group pg ON pg.product_group_id = p.product_group_id
WHERE p.tt_sheet_code IS NOT NULL;

-- Add FK to mst_product_group
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_mst_tt_product_group')
    ALTER TABLE dbo.mst_tt_product
    ADD CONSTRAINT FK_mst_tt_product_group
        FOREIGN KEY (product_group_id)
        REFERENCES dbo.mst_product_group (product_group_id);

-- ============================================================
-- Step 3: Add tt_product_id to mst_tt_ws_formula_matrix
-- ============================================================
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.mst_tt_ws_formula_matrix') AND name = 'tt_product_id'
)
    ALTER TABLE dbo.mst_tt_ws_formula_matrix ADD tt_product_id INT NULL;
GO

-- Populate tt_product_id from existing product_id via mst_tt_product.mst_product_id
UPDATE m
SET m.tt_product_id = tp.tt_product_id
FROM dbo.mst_tt_ws_formula_matrix m
JOIN dbo.mst_tt_product tp ON tp.mst_product_id = m.product_id;

-- Add FK
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_mst_tt_ws_formula_matrix_tt_product')
    ALTER TABLE dbo.mst_tt_ws_formula_matrix
    ADD CONSTRAINT FK_mst_tt_ws_formula_matrix_tt_product
        FOREIGN KEY (tt_product_id)
        REFERENCES dbo.mst_tt_product (tt_product_id);

-- ============================================================
-- Step 4: Update vw_tt_formula_ws_matrix
-- ============================================================
GO
CREATE OR ALTER VIEW dbo.vw_tt_formula_ws_matrix
AS
SELECT
    c.channel_code,
    m.ws_type,
    p.product_code,
    p.product_name_th,
    m.g_group_code,
    m.product_weight_percent,
    m.incentive_base,
    m.use_team_achievement,
    m.effective_from,
    m.effective_to,
    m.is_active
FROM dbo.mst_tt_ws_formula_matrix m
JOIN dbo.mst_channel     c ON c.channel_id     = m.channel_id
JOIN dbo.mst_tt_product  p ON p.tt_product_id  = m.tt_product_id
WHERE c.channel_code = N'TT'
  AND m.is_active = 1;
GO

-- ============================================================
-- Step 5: Update vw_tt_formula_incentive_matrix
-- ============================================================
CREATE OR ALTER VIEW dbo.vw_tt_formula_incentive_matrix
AS
SELECT
    m.ws_type,
    m.g_group_code,
    m.product_code,
    m.product_name_th,
    CAST(m.product_weight_percent * 100 AS DECIMAL(5,2))           AS weight_pct,
    m.incentive_base,
    t.sequence_no                                                    AS band_seq,
    CAST(t.achievement_from * 100 AS DECIMAL(6,2))                  AS ach_from_pct,
    CAST(ISNULL(t.achievement_to, 9.9999) * 100 AS DECIMAL(6,2))   AS ach_to_pct,
    t.achievement_from,
    t.achievement_to,
    CAST(t.multiplier * 100 AS DECIMAL(6,2))                        AS goal_multiplier_pct,
    t.multiplier                                                     AS goal_multiplier,
    CAST(ROUND(m.incentive_base * m.product_weight_percent * t.multiplier, 2)
         AS DECIMAL(9,2))                                           AS incentive_per_product,
    m.effective_from,
    m.effective_to
FROM dbo.vw_tt_formula_ws_matrix    m
CROSS JOIN dbo.vw_tt_formula_goal_threshold t;
GO

-- ============================================================
-- Step 6: Update usp_run_tt_incentive_calculation
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.usp_run_tt_incentive_calculation
    @PeriodCode NVARCHAR(20),
    @WsType NVARCHAR(50) = N'TOP_WS',
    @ApprovedBy NVARCHAR(100) = N'system'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ChannelId INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'TT');
    DECLARE @PeriodId INT;
    DECLARE @SalesMonth DATE;
    DECLARE @RunId INT;
    DECLARE @VariablePayMonth DATE;
    DECLARE @LegacyWsType NVARCHAR(50);

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
        SELECT 1
        FROM dbo.trn_sales_target
        WHERE period_id = @PeriodId
          AND channel_id = @ChannelId
    )
        THROW 50003, 'No TT target rows for the specified period.', 1;

    MERGE dbo.trn_calc_run AS tgt
    USING (SELECT @PeriodId AS period_id, @ChannelId AS channel_id) AS src
        ON tgt.period_id = src.period_id
       AND tgt.channel_id = src.channel_id
    WHEN MATCHED THEN
        UPDATE SET
            tgt.run_status = N'CALCULATED',
            tgt.calculated_at = COALESCE(tgt.calculated_at, SYSUTCDATETIME()),
            tgt.updated_at = SYSUTCDATETIME(),
            tgt.approved_by = COALESCE(tgt.approved_by, @ApprovedBy)
    WHEN NOT MATCHED THEN
        INSERT (period_id, channel_id, run_status, calculated_at, approved_by)
        VALUES (src.period_id, src.channel_id, N'CALCULATED', SYSUTCDATETIME(), @ApprovedBy);

    SELECT @RunId = calc_run_id
    FROM dbo.trn_calc_run
    WHERE period_id = @PeriodId
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
            MAX(t.pct_salesman)  AS pct_salesman
        FROM dbo.trn_sales_target t
        WHERE t.period_id  = @PeriodId
          AND t.channel_id = @ChannelId
        GROUP BY t.salesman_code, t.product_code
    ),
    hier_ws AS (
        SELECT DISTINCT
            ts.salesman_code,
            COALESCE(
                (SELECT TOP 1 hh.ws_type
                 FROM dbo.mst_org_hierarchy hh
                 WHERE hh.channel_id     = @ChannelId
                   AND hh.salesman_code  = ts.salesman_code
                   AND hh.ws_type        IS NOT NULL
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
                - non-SKU: product_code เป็น short alias อยู่แล้ว (A/R/B...)
                - SKU rows (SKU-AJ-350): strip canonical (AJ) → lookup mst_product.tt_sheet_code → 'A' */
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
            ON ac.salesman_code = ts.salesman_code
           AND ac.product_code  = ts.product_code
        LEFT JOIN hier_ws hw
            ON hw.salesman_code = ts.salesman_code
    ),
    /*  TT product_code = short alias (A/R/B...) ตรง JOIN mst_tt_product.product_code ได้เลย
        SKU rows: base_product_code ถูก resolve ไปแล้วใน staff_join */
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
            p.mst_product_id AS product_id,    -- kept for legacy lookups (mst_product_weight, shortage)
            CAST(ROUND(CASE WHEN sj.target_amount = 0 THEN 0 ELSE sj.actual_amount / sj.target_amount END, 4) AS DECIMAL(9,4)) AS achievement,
            CAST(CASE WHEN sp.shortage_policy_id IS NULL THEN 0 ELSE 1 END AS BIT) AS shortage_flag,
            CAST(ROUND(CASE
                WHEN sp.shortage_policy_id IS NULL THEN
                    CASE
                        WHEN COALESCE(wm.use_team_achievement, 0) = 1
                            THEN COALESCE(ta.team_achievement, CASE WHEN sj.target_amount = 0 THEN 0 ELSE sj.actual_amount / sj.target_amount END)
                        WHEN sj.target_amount = 0 THEN 0
                        ELSE sj.actual_amount / sj.target_amount
                    END
                ELSE sp.override_achievement
            END, 4) AS DECIMAL(9,4)) AS final_achievement,
            CAST(COALESCE(wm.product_weight_percent, w.weight_percent, 0) AS DECIMAL(9,4)) AS product_weight,
            CAST(COALESCE(wm.incentive_base, rs.rate_new, rs.rate_old, 0) AS DECIMAL(18,2)) AS incentive_base,
            COALESCE(wm.g_group_code, p.g_group_code, N'OT') AS g_group_code
        FROM staff_join sj
        -- ★ JOIN mst_tt_product ตรงบน product_code (ไม่ใช้ tt_sheet_code อีกต่อไป)
        LEFT JOIN dbo.mst_tt_product p
            ON  p.product_code = sj.base_product_code
            AND p.is_active    = 1
        -- ★ Lookup formula matrix by tt_product_id
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
            -- Legacy: mst_product_weight still uses mst_product.product_id
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
            WHERE ir.channel_id  = @ChannelId
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
    -- ★ Map short code to canonical via mst_tt_product.tt_sheet_code (no CASE)
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
        WHERE d.calc_run_id        = @RunId
          AND d.position_level_code = N'STAFF'
    ) x
    -- ★ Lookup g_group_code จาก mst_tt_product โดยตรงบน product_code
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
            CAST(ROUND(m.actual_amount, 2) AS DECIMAL(18,2)) AS actual_amount,
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

    IF OBJECT_ID('dbo.trn_tt_special_kpi_detail', 'U') IS NOT NULL
    BEGIN
        ;WITH staff_group AS (
            SELECT s.salesman_code, s.g_group_code,
                   AVG(CAST(s.final_achievement AS DECIMAL(18,6))) AS avg_final_achievement
            FROM #staff_rows s
            GROUP BY s.salesman_code, s.g_group_code
        ),
        kpi_hit AS (
            SELECT
                sg.salesman_code, sg.g_group_code,
                CAST(ROUND(sg.avg_final_achievement, 4) AS DECIMAL(9,4)) AS avg_final_achievement,
                r.kpi_threshold, r.bonus_amount,
                ROW_NUMBER() OVER (PARTITION BY sg.salesman_code, sg.g_group_code ORDER BY r.effective_from DESC) AS rn
            FROM staff_group sg
            JOIN dbo.mst_tt_special_kpi_rule r
              ON r.channel_id  = @ChannelId
             AND r.ws_type     = @LegacyWsType
             AND r.g_group_code = sg.g_group_code
             AND r.is_active = 1
             AND r.effective_from <= @SalesMonth
             AND (r.effective_to IS NULL OR r.effective_to >= @SalesMonth)
            WHERE sg.avg_final_achievement >= r.kpi_threshold
        )
        INSERT INTO dbo.trn_tt_special_kpi_detail
            (calc_run_id, salesman_code, g_group_code, avg_final_achievement, kpi_threshold, bonus_amount)
        SELECT @RunId, k.salesman_code, k.g_group_code,
               k.avg_final_achievement, k.kpi_threshold, k.bonus_amount
        FROM kpi_hit k
        WHERE k.rn = 1;
    END

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
        ON e.employee_code = a.employee_code
       AND e.channel_id = @ChannelId
    LEFT JOIN dbo.mst_position_level pl
        ON pl.position_level_id = e.position_level_id;

    UPDATE dbo.trn_calc_run
    SET run_status    = N'CALCULATED',
        calculated_at = COALESCE(calculated_at, SYSUTCDATETIME()),
        updated_at    = SYSUTCDATETIME(),
        approved_by   = COALESCE(approved_by, @ApprovedBy)
    WHERE calc_run_id = @RunId;

    SELECT
        @RunId       AS calc_run_id,
        @PeriodCode  AS period_code,
        (SELECT COUNT(*) FROM dbo.trn_incentive_detail WHERE calc_run_id = @RunId) AS trn_incentive_detail_rows,
        (SELECT COUNT(*) FROM dbo.out_for_hr_variable   WHERE calc_run_id = @RunId) AS out_for_hr_variable_rows;

    IF OBJECT_ID('tempdb..#staff_rows') IS NOT NULL DROP TABLE #staff_rows;
    IF OBJECT_ID('tempdb..#hier_pick')  IS NOT NULL DROP TABLE #hier_pick;
END;
GO

-- ============================================================
-- Step 7: Verify
-- ============================================================
SELECT tt_product_id, product_code, g_group_code, mst_product_id, is_active
FROM dbo.mst_tt_product ORDER BY g_group_code, product_code;

SELECT COUNT(*) AS formula_matrix_rows_with_tt_product_id
FROM dbo.mst_tt_ws_formula_matrix
WHERE tt_product_id IS NOT NULL;
