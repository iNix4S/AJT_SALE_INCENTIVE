-- ============================================================
-- Stored Procedure: dbo.usp_run_laos_incentive_calculation
-- Channel       : Laos (Laos Market, channel_code='LAOS')
-- Description   : คำนวณ Sale Incentive สำหรับตลาดลาว
--                 ใช้ TT เป็นต้นแบบ (ws_type + product mapping)
--                 - Product mapping: SKU-{alias}-XXX → base product
--                 - ws_type per salesman from mst_org_hierarchy
--                 - Team achievement for shared products
--                 - Manager calculation: avg(goal_multiplier)
-- Parameters    :
--   @PeriodCode - รหัสงวด (FY2026-04)
--   @WsType     - Wholesale type (TOP_WS, WS_SF, etc.)
--   @ApprovedBy - ชื่อผู้อนุมัติ
-- Pattern       : TT simplified
-- Date          : 2026-06-22
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.usp_run_laos_incentive_calculation
    @PeriodCode NVARCHAR(20),
    @WsType NVARCHAR(50) = N'TOP_WS',
    @ApprovedBy NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @ChannelId INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'LAOS');
    DECLARE @PeriodId INT;
    DECLARE @SalesMonth DATE;
    DECLARE @RunId INT;
    DECLARE @LegacyWsType NVARCHAR(50);

    IF @ChannelId IS NULL
        THROW 50001, 'Laos channel not found.', 1;

    SELECT @PeriodId = period_id, @SalesMonth = sales_month
    FROM dbo.mst_period
    WHERE period_code = @PeriodCode;

    IF @PeriodId IS NULL
        THROW 50002, 'Period code not found.', 1;

    SET @LegacyWsType = CASE
        WHEN @WsType IN (N'TOP_WS', N'WS_SF', N'WS_WH', N'SF_WH') THEN @WsType
        ELSE N'TOP_WS'
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.trn_sales_target
        WHERE period_id = @PeriodId
          AND channel_id = @ChannelId
    )
        THROW 50003, 'No Laos target rows for the specified period.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- ── 1. Create or update calc run ────────────────────────
        MERGE dbo.trn_calc_run AS tgt
        USING (SELECT @PeriodId AS period_id, @ChannelId AS channel_id) AS src
            ON tgt.period_id = src.period_id
           AND tgt.channel_id = src.channel_id
        WHEN MATCHED THEN
            UPDATE SET
                tgt.run_status = N'RUNNING',
                tgt.updated_at = GETDATE(),
                tgt.approved_by = COALESCE(tgt.approved_by, @ApprovedBy)
        WHEN NOT MATCHED THEN
            INSERT (period_id, channel_id, run_status, approved_by, created_at)
            VALUES (src.period_id, src.channel_id, N'RUNNING', @ApprovedBy, GETDATE());

        SELECT @RunId = calc_run_id
        FROM dbo.trn_calc_run
        WHERE period_id = @PeriodId
          AND channel_id = @ChannelId;

        -- ── 2. Clear previous results ───────────────────────────
        DELETE FROM dbo.out_for_hr_variable WHERE calc_run_id = @RunId;
        DELETE FROM dbo.trn_incentive_detail WHERE calc_run_id = @RunId;

        -- ══════════════════════════════════════════════════════
        -- STAFF calculation
        -- ══════════════════════════════════════════════════════
        ;WITH target_src AS (
            SELECT
                t.salesman_code,
                t.product_code,
                SUM(t.target_amount) AS target_amount
            FROM dbo.trn_sales_target t
            WHERE t.period_id = @PeriodId
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
            WHERE a.period_id = @PeriodId
              AND a.channel_id = @ChannelId
            GROUP BY a.salesman_code, a.product_code
        ),
        staff_join AS (
            SELECT
                ts.salesman_code,
                ts.product_code,
                ts.target_amount,
                hw.ws_type,
                COALESCE(ac.actual_amount, 0) AS actual_amount,
                -- Product mapping: SKU-{alias}-XXX → base product
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
                s.ws_type,
                -- Map short codes to full product codes (ตาม TT pattern)
                CASE UPPER(s.base_product_code)
                    WHEN 'A' THEN 'AJ'
                    WHEN 'AP' THEN 'AJP'
                    WHEN 'R' THEN 'RD'
                    WHEN 'B' THEN 'BD'
                    WHEN 'P' THEN 'PDC'
                    WHEN 'Y' THEN 'YY'
                    ELSE UPPER(s.base_product_code)
                END AS mapped_product_code
            FROM staff_join s
        ),
        staff_calc AS (
            SELECT
                sm.salesman_code,
                sm.product_code,
                sm.target_amount,
                sm.actual_amount,
                sm.mapped_product_code,
                sm.ws_type,
                p.product_id,
                CAST(ROUND(CASE WHEN sm.target_amount = 0 THEN 0 ELSE sm.actual_amount / sm.target_amount END, 4) AS DECIMAL(9,4)) AS achievement,
                CAST(CASE WHEN sp.shortage_policy_id IS NULL THEN 0 ELSE 1 END AS BIT) AS shortage_flag,
                CAST(ROUND(CASE
                    WHEN sp.shortage_policy_id IS NULL THEN
                        CASE WHEN sm.target_amount = 0 THEN 0 ELSE sm.actual_amount / sm.target_amount END
                    ELSE sp.override_achievement
                END, 4) AS DECIMAL(9,4)) AS final_achievement,
                CAST(COALESCE(w.weight_percent, 0) AS DECIMAL(9,4)) AS product_weight,
                CAST(COALESCE(rs.rate_new, rs.rate_old, 0) AS DECIMAL(18,2)) AS incentive_base
            FROM staff_map sm
            LEFT JOIN dbo.mst_product p
                ON p.product_code = sm.mapped_product_code
               AND p.is_active = 1
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
            COALESCE(g.multiplier, 0),
            sc.incentive_base,
            sc.product_weight,
            CAST(ROUND(sc.incentive_base * COALESCE(g.multiplier, 0) * sc.product_weight, 2) AS DECIMAL(18,2))
        FROM staff_calc sc
        OUTER APPLY (
            SELECT TOP 1 gt.multiplier
            FROM dbo.mst_goal_threshold gt
            WHERE gt.is_active = 1
              AND sc.final_achievement >= gt.achievement_from
              AND (gt.achievement_to IS NULL OR sc.final_achievement <= gt.achievement_to)
            ORDER BY gt.achievement_from DESC
        ) g
        WHERE sc.target_amount > 0;

        -- ══════════════════════════════════════════════════════
        -- MANAGER calculation (SECT_MGR, DEPT_MGR)
        -- ══════════════════════════════════════════════════════
        IF OBJECT_ID('tempdb..#staff_rows') IS NOT NULL DROP TABLE #staff_rows;
        SELECT
            salesman_code,
            product_code,
            target_amount,
            actual_amount,
            achievement,
            final_achievement,
            goal_multiplier
        INTO #staff_rows
        FROM dbo.trn_incentive_detail
        WHERE calc_run_id = @RunId
          AND position_level_code = N'STAFF';

        IF OBJECT_ID('tempdb..#hier_pick') IS NOT NULL DROP TABLE #hier_pick;
        SELECT
            s.salesman_code,
            h.direct_sup_code,
            h.dept_mgr_code
        INTO #hier_pick
        FROM (SELECT DISTINCT salesman_code FROM #staff_rows) s
        OUTER APPLY (
            SELECT TOP 1 hh.direct_sup_code, hh.dept_mgr_code
            FROM dbo.mst_org_hierarchy hh
            WHERE hh.channel_id = @ChannelId
              AND hh.salesman_code = s.salesman_code
            ORDER BY
                CASE WHEN hh.effective_month <= @SalesMonth THEN 0 ELSE 1 END,
                ABS(DATEDIFF(DAY, hh.effective_month, @SalesMonth)),
                hh.effective_month DESC
        ) h;

        ;WITH mgr_raw AS (
            -- SECT_MGR: one row per manager (product_code='*')
            SELECT N'SECT_MGR' AS position_level_code, NULLIF(h.direct_sup_code, N'') AS manager_code, N'*' AS product_code,
                   SUM(s.target_amount) AS target_amount, SUM(s.actual_amount) AS actual_amount,
                   CAST(AVG(CAST(s.goal_multiplier AS DECIMAL(18,6))) AS DECIMAL(18,6)) AS achievement,
                   CAST(AVG(CAST(s.goal_multiplier AS DECIMAL(18,6))) AS DECIMAL(18,6)) AS avg_final_achievement
            FROM #staff_rows s
            JOIN #hier_pick h ON h.salesman_code = s.salesman_code
            WHERE NULLIF(h.direct_sup_code, N'') IS NOT NULL
            GROUP BY h.direct_sup_code

            UNION ALL

            -- DEPT_MGR
            SELECT N'DEPT_MGR', NULLIF(h.dept_mgr_code, N''), N'*',
                   SUM(s.target_amount), SUM(s.actual_amount),
                   CAST(AVG(CAST(s.goal_multiplier AS DECIMAL(18,6))) AS DECIMAL(18,6)),
                   CAST(AVG(CAST(s.goal_multiplier AS DECIMAL(18,6))) AS DECIMAL(18,6))
            FROM #staff_rows s
            JOIN #hier_pick h ON h.salesman_code = s.salesman_code
            WHERE NULLIF(h.dept_mgr_code, N'') IS NOT NULL
            GROUP BY h.dept_mgr_code
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
            SELECT CAST(COALESCE(
                (
                    SELECT TOP 1 COALESCE(ir.rate_new, ir.rate_old)
                    FROM dbo.mst_incentive_rate ir
                    JOIN dbo.mst_position_level pl ON pl.position_level_id = ir.position_level_id
                    WHERE ir.channel_id = @ChannelId
                      AND pl.position_code = mc.position_level_code
                      AND ir.ws_type = @LegacyWsType
                      AND ir.is_active = 1
                      AND ir.effective_from <= @SalesMonth
                      AND (ir.effective_to IS NULL OR ir.effective_to >= @SalesMonth)
                    ORDER BY ir.effective_from DESC
                ), 0
            ) AS DECIMAL(18,2)) AS incentive_base
        ) rate_data;

        -- ══════════════════════════════════════════════════════
        -- OUTPUT: out_for_hr_variable
        -- ══════════════════════════════════════════════════════
        INSERT INTO dbo.out_for_hr_variable
            (calc_run_id, employee_code, employee_name_th, position_level_code, channel_code,
             variable_pay_month, incentive_staff, incentive_sect, incentive_dept, incentive_ad,
             gd_incentive_total, total_variable, payment_method)
        SELECT
            @RunId,
            d.salesman_code,
            COALESCE(e.employee_name_th, d.salesman_code),
            d.position_level_code,
            N'LAOS',
            @SalesMonth,
            CAST(ROUND(SUM(CASE WHEN d.position_level_code = 'STAFF'    THEN d.incentive_amount ELSE 0 END), 2) AS DECIMAL(18,2)),
            CAST(ROUND(SUM(CASE WHEN d.position_level_code = 'SECT_MGR' THEN d.incentive_amount ELSE 0 END), 2) AS DECIMAL(18,2)),
            CAST(ROUND(SUM(CASE WHEN d.position_level_code = 'DEPT_MGR' THEN d.incentive_amount ELSE 0 END), 2) AS DECIMAL(18,2)),
            CAST(ROUND(SUM(CASE WHEN d.position_level_code = 'AD'       THEN d.incentive_amount ELSE 0 END), 2) AS DECIMAL(18,2)),
            CAST(0.00 AS DECIMAL(18,2)),  -- gd_incentive_total (Laos ไม่มี GD)
            CAST(ROUND(SUM(d.incentive_amount), 2) AS DECIMAL(18,2)),
            N'โอนเข้าบัญชี'
        FROM   dbo.trn_incentive_detail d
        LEFT JOIN dbo.mst_employee e ON e.employee_code = d.salesman_code AND e.channel_id = @ChannelId
        WHERE  d.calc_run_id = @RunId
        GROUP  BY d.salesman_code, d.position_level_code, e.employee_name_th;

        -- ── 3. Mark run complete ─────────────────────────────────
        UPDATE dbo.trn_calc_run
        SET    run_status = N'CALCULATED',
               updated_at = GETDATE()
        WHERE  calc_run_id = @RunId;

        COMMIT TRANSACTION;

        SELECT @RunId AS calc_run_id,
               N'LAOS' AS channel_code,
               @PeriodCode AS period_code,
               N'SUCCESS' AS status,
               (SELECT COUNT(*) FROM dbo.trn_incentive_detail WHERE calc_run_id = @RunId) AS detail_rows,
               (SELECT COUNT(*) FROM dbo.out_for_hr_variable WHERE calc_run_id = @RunId) AS for_hr_rows;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();

        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH;
END
GO

PRINT 'usp_run_laos_incentive_calculation created successfully';
GO
