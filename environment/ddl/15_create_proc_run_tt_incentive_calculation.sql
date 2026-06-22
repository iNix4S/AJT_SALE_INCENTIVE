SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*
Purpose:
- Run TT incentive calculation in database from transactional tables.
- Populate trn_incentive_detail (STAFF/SECT_MGR/DEPT_MGR/DIV_MGR/AD)
- Populate out_for_hr_variable for TT channel.

Inputs:
- trn_sales_target, trn_sales_actual, mst_goal_threshold, mst_product_weight,
  mst_incentive_rate, mst_shortage_policy, mst_org_hierarchy, mst_payment_cycle

Notes:
- Product code mapping supports TT codes and SKU-* format.
- DIV_MGR rate fallback: use DEPT_MGR rate when DIV_MGR rate is missing.
*/
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
            MAX(t.pct_salesman)  AS pct_salesman   -- pre-computed goal_multiplier from sheet
        FROM dbo.trn_sales_target t
        WHERE t.period_id = @PeriodId
          AND t.channel_id = @ChannelId
        GROUP BY t.salesman_code, t.product_code
    ),
    /*  Per-salesman ws_type from mst_org_hierarchy.
        Falls back to @LegacyWsType when no hierarchy row exists.
        Allows multi-ws_type in one calculation run. */
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
        WHERE a.period_id = @PeriodId
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
            CASE
                WHEN ts.product_code LIKE 'SKU-%' THEN
                    LEFT(SUBSTRING(ts.product_code, 5, 100),
                         CHARINDEX('-', SUBSTRING(ts.product_code, 5, 100) + '-') - 1)
                ELSE ts.product_code
            END AS base_product_code
        FROM target_src ts
        LEFT JOIN actual_src ac
            ON ac.salesman_code = ts.salesman_code
           AND ac.product_code  = ts.product_code
        LEFT JOIN hier_ws hw
            ON hw.salesman_code = ts.salesman_code
    ),
    staff_map AS (
        SELECT
            s.salesman_code,
            s.product_code,
            s.target_amount,
            s.actual_amount,
            s.pct_salesman,
            s.ws_type,
            CASE UPPER(s.base_product_code)
                WHEN 'A' THEN 'AJ'
                WHEN 'AP' THEN 'AJP'
                WHEN 'R' THEN 'RD'
                WHEN 'B' THEN 'BD'
                WHEN 'P' THEN 'PDC'
                WHEN 'Q' THEN 'RDC'
                WHEN 'M' THEN 'RM'
                WHEN 'NS' THEN 'RDNS'
                WHEN 'RK' THEN 'RKR'
                WHEN 'T' THEN 'TKM'
                WHEN 'Y' THEN 'YY'
                ELSE UPPER(s.base_product_code)
            END AS mapped_product_code
        FROM staff_join s
    ),
    /*  Team-level achievement: sum all target/actual in the period for products
        that are flagged use_team_achievement = 1 in the formula matrix.
        Used for RD (R) and YY (Y) which are team-shared products in the sheet. */
    team_ach AS (
        SELECT
            t_all.product_code,
            CAST(ROUND(
                SUM(COALESCE(a_all.actual_amount, 0)) / NULLIF(SUM(t_all.target_amount), 0)
            , 4) AS DECIMAL(9,4)) AS team_achievement
        FROM dbo.trn_sales_target t_all
        LEFT JOIN dbo.trn_sales_actual a_all
            ON  a_all.channel_id   = t_all.channel_id
            AND a_all.period_id    = t_all.period_id
            AND a_all.salesman_code = t_all.salesman_code
            AND a_all.product_code  = t_all.product_code
        WHERE t_all.channel_id = @ChannelId
          AND t_all.period_id  = @PeriodId
        GROUP BY t_all.product_code
    ),
    staff_calc AS (
        SELECT
            sm.salesman_code,
            sm.product_code,
            sm.target_amount,
            sm.actual_amount,
            sm.mapped_product_code,
            sm.pct_salesman,
            sm.ws_type,
            p.product_id,
            CAST(ROUND(CASE WHEN sm.target_amount = 0 THEN 0 ELSE sm.actual_amount / sm.target_amount END, 4) AS DECIMAL(9,4)) AS achievement,
            CAST(CASE WHEN sp.shortage_policy_id IS NULL THEN 0 ELSE 1 END AS BIT) AS shortage_flag,
            CAST(ROUND(CASE
                WHEN sp.shortage_policy_id IS NULL THEN
                    CASE
                        /* Use team achievement when the product is flagged in the formula matrix */
                        WHEN COALESCE(wm.use_team_achievement, 0) = 1
                            THEN COALESCE(ta.team_achievement, CASE WHEN sm.target_amount = 0 THEN 0 ELSE sm.actual_amount / sm.target_amount END)
                        WHEN sm.target_amount = 0 THEN 0
                        ELSE sm.actual_amount / sm.target_amount
                    END
                ELSE sp.override_achievement
            END, 4) AS DECIMAL(9,4)) AS final_achievement,
            CAST(COALESCE(wm.product_weight_percent, w.weight_percent, 0) AS DECIMAL(9,4)) AS product_weight,
            CAST(COALESCE(wm.incentive_base, rs.rate_new, rs.rate_old, 0) AS DECIMAL(18,2)) AS incentive_base,
            COALESCE(wm.g_group_code,
                CASE
                    WHEN sm.mapped_product_code IN (N'AJ', N'RD', N'BD') THEN N'G1'
                    WHEN sm.mapped_product_code IN (N'AJP', N'RDC', N'RM', N'RDNS') THEN N'G2'
                    WHEN sm.mapped_product_code IN (N'YY', N'PDC') THEN N'G3'
                    ELSE N'OT'
                END
            ) AS g_group_code
        FROM staff_map sm
        LEFT JOIN dbo.mst_product p
            ON p.product_code = sm.mapped_product_code
           AND p.is_active = 1
        OUTER APPLY (
            SELECT TOP 1 m.product_weight_percent, m.incentive_base, m.g_group_code,
                         m.use_team_achievement
            FROM dbo.mst_tt_ws_formula_matrix m
            WHERE m.channel_id = @ChannelId
              AND m.product_id = p.product_id
              AND m.ws_type    = COALESCE(sm.ws_type, @LegacyWsType)
              AND m.is_active = 1
              AND m.effective_from <= @SalesMonth
              AND (m.effective_to IS NULL OR m.effective_to >= @SalesMonth)
            ORDER BY m.effective_from DESC
        ) wm
        LEFT JOIN team_ach ta
            ON ta.product_code = sm.product_code
        OUTER APPLY (
            SELECT TOP 1 pw.weight_percent
            FROM dbo.mst_product_weight pw
            WHERE pw.channel_id = @ChannelId
              AND pw.product_id = p.product_id
              AND pw.ws_type    = COALESCE(sm.ws_type, @LegacyWsType)
              AND pw.is_active = 1
              AND pw.effective_from <= @SalesMonth
              AND (pw.effective_to IS NULL OR pw.effective_to >= @SalesMonth)
            ORDER BY pw.effective_from DESC
        ) w
        LEFT JOIN dbo.mst_shortage_policy sp
            ON sp.product_id = p.product_id
           AND sp.shortage_month = @SalesMonth
           AND sp.is_active = 1
        OUTER APPLY (
            SELECT TOP 1 ir.rate_old, ir.rate_new
            FROM dbo.mst_incentive_rate ir
            JOIN dbo.mst_position_level pl
              ON pl.position_level_id = ir.position_level_id
            WHERE ir.channel_id  = @ChannelId
              AND pl.position_code = N'STAFF'
              AND ir.ws_type       = COALESCE(sm.ws_type, @LegacyWsType)
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
        -- pct_salesman (sheet pre-computed multiplier) takes priority over threshold lookup
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

    IF OBJECT_ID('tempdb..#staff_rows') IS NOT NULL DROP TABLE #staff_rows;
    SELECT
        salesman_code,
        product_code,
        target_amount,
        actual_amount,
        achievement,
        final_achievement,
        goal_multiplier,       -- pct_salesman or threshold multiplier, salesman-level (same for all products)
        CASE
            WHEN mapped_product_code IN (N'AJ', N'RD', N'BD') THEN N'G1'
            WHEN mapped_product_code IN (N'AJP', N'RDC', N'RM', N'RDNS') THEN N'G2'
            WHEN mapped_product_code IN (N'YY', N'PDC') THEN N'G3'
            ELSE N'OT'
        END AS g_group_code
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
            CASE UPPER(CASE WHEN d.product_code LIKE 'SKU-%'
                            THEN LEFT(SUBSTRING(d.product_code, 5, 100), CHARINDEX('-', SUBSTRING(d.product_code, 5, 100) + '-') - 1)
                            ELSE d.product_code END)
                WHEN 'A' THEN 'AJ'
                WHEN 'AP' THEN 'AJP'
                WHEN 'R' THEN 'RD'
                WHEN 'B' THEN 'BD'
                WHEN 'P' THEN 'PDC'
                WHEN 'Q' THEN 'RDC'
                WHEN 'M' THEN 'RM'
                WHEN 'NS' THEN 'RDNS'
                WHEN 'RK' THEN 'RKR'
                WHEN 'T' THEN 'TKM'
                WHEN 'Y' THEN 'YY'
                ELSE UPPER(CASE WHEN d.product_code LIKE 'SKU-%'
                                THEN LEFT(SUBSTRING(d.product_code, 5, 100), CHARINDEX('-', SUBSTRING(d.product_code, 5, 100) + '-') - 1)
                                ELSE d.product_code END)
            END AS mapped_product_code
        FROM dbo.trn_incentive_detail d
        WHERE d.calc_run_id = @RunId
          AND d.position_level_code = N'STAFF'
    ) x;

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
        WHERE hh.channel_id = @ChannelId
          AND hh.salesman_code = s.salesman_code
        ORDER BY
            CASE WHEN hh.effective_month <= @SalesMonth THEN 0 ELSE 1 END,
            ABS(DATEDIFF(DAY, hh.effective_month, @SalesMonth)),
            hh.effective_month DESC
    ) h;

    -- mgr_raw: group by manager_code only (no product_code), use direct AVG of goal_multiplier
    -- across ALL staff×product rows in the section.
    -- This gives a volume-neutral average consistent with the sheet's AVERAGEIFS over product rows.
    ;WITH mgr_raw AS (
        -- SECT_MGR: product_code = N'*' (one row per manager, not per product)
        -- achievement = direct AVG(goal_multiplier) of all product rows of all staff under this section manager
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
            -- Store 4dp for display; keep full precision for incentive_amount to avoid rounding loss
            CAST(ROUND(m.achievement, 4) AS DECIMAL(9,4)) AS achievement,
            CAST(ROUND(m.avg_final_achievement, 4) AS DECIMAL(9,4)) AS final_achievement,
            -- Managers ARE penalized when section avg is below 100% (no floor to 1.0)
            m.avg_final_achievement AS raw_achievement    -- full precision for multiplication
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
        -- Managers use avg_pct (final_achievement) directly — no stepped threshold lookup
        mc.final_achievement,
        rate_data.incentive_base,
        CAST(1.0000 AS DECIMAL(9,4)),
        -- Use raw_achievement (full precision) for multiplication to match sheet's exact values
        CAST(ROUND(rate_data.incentive_base * mc.raw_achievement, 2) AS DECIMAL(18,2))
    FROM mgr_calc mc
    -- Manager incentive_base = position-specific rate from mst_incentive_rate
    -- Matches T_SectAbove sheet: SECT_MGR=4,000 / DEPT_MGR=5,000 / DIV_MGR=5,000 / AD=6,000
    -- rate_new takes priority; DIV_MGR falls back to DEPT_MGR rate if not found
    OUTER APPLY (
        SELECT CAST(
            CASE
                WHEN mc.position_level_code = N'DIV_MGR' THEN
                    COALESCE(
                        (
                            SELECT TOP 1 COALESCE(ir1.rate_new, ir1.rate_old)
                            FROM dbo.mst_incentive_rate ir1
                            JOIN dbo.mst_position_level pl1 ON pl1.position_level_id = ir1.position_level_id
                            WHERE ir1.channel_id = @ChannelId
                              AND pl1.position_code = N'DIV_MGR'
                              AND ir1.ws_type = @LegacyWsType
                              AND ir1.is_active = 1
                              AND ir1.effective_from <= @SalesMonth
                              AND (ir1.effective_to IS NULL OR ir1.effective_to >= @SalesMonth)
                            ORDER BY ir1.effective_from DESC
                        ),
                        (
                            SELECT TOP 1 COALESCE(ir2.rate_new, ir2.rate_old)
                            FROM dbo.mst_incentive_rate ir2
                            JOIN dbo.mst_position_level pl2 ON pl2.position_level_id = ir2.position_level_id
                            WHERE ir2.channel_id = @ChannelId
                              AND pl2.position_code = N'DEPT_MGR'
                              AND ir2.ws_type = @LegacyWsType
                              AND ir2.is_active = 1
                              AND ir2.effective_from <= @SalesMonth
                              AND (ir2.effective_to IS NULL OR ir2.effective_to >= @SalesMonth)
                            ORDER BY ir2.effective_from DESC
                        ),
                        0
                    )
                ELSE COALESCE(
                    (
                        SELECT TOP 1 COALESCE(ir3.rate_new, ir3.rate_old)
                        FROM dbo.mst_incentive_rate ir3
                        JOIN dbo.mst_position_level pl3 ON pl3.position_level_id = ir3.position_level_id
                        WHERE ir3.channel_id = @ChannelId
                          AND pl3.position_code = mc.position_level_code
                          AND ir3.ws_type = @LegacyWsType
                          AND ir3.is_active = 1
                          AND ir3.effective_from <= @SalesMonth
                          AND (ir3.effective_to IS NULL OR ir3.effective_to >= @SalesMonth)
                        ORDER BY ir3.effective_from DESC
                    ),
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
            SELECT
                s.salesman_code,
                s.g_group_code,
                AVG(CAST(s.final_achievement AS DECIMAL(18,6))) AS avg_final_achievement
            FROM #staff_rows s
            GROUP BY s.salesman_code, s.g_group_code
        ),
        kpi_hit AS (
            SELECT
                sg.salesman_code,
                sg.g_group_code,
                CAST(ROUND(sg.avg_final_achievement, 4) AS DECIMAL(9,4)) AS avg_final_achievement,
                r.kpi_threshold,
                r.bonus_amount,
                ROW_NUMBER() OVER (PARTITION BY sg.salesman_code, sg.g_group_code ORDER BY r.effective_from DESC) AS rn
            FROM staff_group sg
            JOIN dbo.mst_tt_special_kpi_rule r
              ON r.channel_id = @ChannelId
             AND r.ws_type = @LegacyWsType
             AND r.g_group_code = sg.g_group_code
             AND r.is_active = 1
             AND r.effective_from <= @SalesMonth
             AND (r.effective_to IS NULL OR r.effective_to >= @SalesMonth)
            WHERE sg.avg_final_achievement >= r.kpi_threshold
        )
        INSERT INTO dbo.trn_tt_special_kpi_detail
            (calc_run_id, salesman_code, g_group_code, avg_final_achievement, kpi_threshold, bonus_amount)
        SELECT
            @RunId,
            k.salesman_code,
            k.g_group_code,
            k.avg_final_achievement,
            k.kpi_threshold,
            k.bonus_amount
        FROM kpi_hit k
        WHERE k.rn = 1;
    END

    ;WITH agg AS (
        SELECT
            d.salesman_code AS employee_code,
            SUM(CASE WHEN d.position_level_code = N'STAFF' THEN d.incentive_amount ELSE 0 END) AS incentive_staff,
            SUM(CASE WHEN d.position_level_code = N'SECT_MGR' THEN d.incentive_amount ELSE 0 END) AS incentive_sect,
            SUM(CASE WHEN d.position_level_code = N'DEPT_MGR' THEN d.incentive_amount ELSE 0 END) AS incentive_dept,
            SUM(CASE WHEN d.position_level_code = N'DIV_MGR' THEN d.incentive_amount ELSE 0 END) AS incentive_div,
            SUM(CASE WHEN d.position_level_code = N'AD' THEN d.incentive_amount ELSE 0 END) AS incentive_ad,
            COALESCE((SELECT SUM(k.bonus_amount)
                      FROM dbo.trn_tt_special_kpi_detail k
                      WHERE k.calc_run_id = @RunId
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
        CAST(ROUND(a.incentive_sect, 2) AS DECIMAL(18,2)),
        CAST(ROUND(a.incentive_dept, 2) AS DECIMAL(18,2)),
        CAST(ROUND(a.incentive_div, 2) AS DECIMAL(18,2)),
        CAST(ROUND(a.incentive_ad, 2) AS DECIMAL(18,2)),
        CAST(ROUND(a.special_kpi_bonus, 2) AS DECIMAL(18,2)),
        CAST(ROUND(a.incentive_staff + a.incentive_sect + a.incentive_dept + a.incentive_div + a.incentive_ad + a.special_kpi_bonus, 2) AS DECIMAL(18,2)),
        N'BANK_TRANSFER'
    FROM agg a
    LEFT JOIN dbo.mst_employee e
        ON e.employee_code = a.employee_code
       AND e.channel_id = @ChannelId
    LEFT JOIN dbo.mst_position_level pl
        ON pl.position_level_id = e.position_level_id;

    UPDATE dbo.trn_calc_run
    SET run_status = N'CALCULATED',
        calculated_at = COALESCE(calculated_at, SYSUTCDATETIME()),
        updated_at = SYSUTCDATETIME(),
        approved_by = COALESCE(approved_by, @ApprovedBy)
    WHERE calc_run_id = @RunId;

    SELECT
        @RunId AS calc_run_id,
        @PeriodCode AS period_code,
        (SELECT COUNT(*) FROM dbo.trn_incentive_detail WHERE calc_run_id = @RunId) AS trn_incentive_detail_rows,
        (SELECT COUNT(*) FROM dbo.out_for_hr_variable WHERE calc_run_id = @RunId) AS out_for_hr_variable_rows;
END
GO
