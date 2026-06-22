-- ============================================================
-- Stored Procedure: dbo.usp_run_si_incentive_calculation
-- Channel       : S&I (Sales & Import, channel_code='SI')
-- Description   : คำนวณ Sale Incentive สำหรับช่องทาง S&I
--                 - per-product: mst_product_weight (channel-level, ไม่ per-salesman)
--                 - incentive_rate: lookup ตาม position_level ของแต่ละ employee
--                 - shortage override: ถ้ามี mst_shortage_policy
--                 - rounding: ROUND(.,2) ทุก level
-- Parameters    :
--   @PeriodId   - รหัสงวด (1=Apr2026 ... 12=Mar2027)
--   @ApprovedBy - ชื่อผู้อนุมัติ (ถ้ามี)
-- Pattern       : Per-product × per-salesman, rate by position
-- Date          : 2026-06-22
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.usp_run_si_incentive_calculation
    @PeriodId   INT,
    @ApprovedBy NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @ChannelId   INT          = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'SI');
    DECLARE @ChannelCode NVARCHAR(10) = N'SI';
    DECLARE @RunId       INT;
    DECLARE @SalesMonth  DATE;

    IF @ChannelId IS NULL
        THROW 50001, N'S&I channel not found in mst_channel', 1;

    -- ── 1. Validate period ──────────────────────────────────
    SELECT @SalesMonth = p.sales_month
    FROM   dbo.mst_period p
    WHERE  p.period_id = @PeriodId;

    IF @SalesMonth IS NULL
        THROW 50002, N'Invalid @PeriodId - period not found', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- ── 2. Remove existing run for same channel+period ──────
        DELETE FROM dbo.out_for_hr_variable
        WHERE  calc_run_id IN (SELECT calc_run_id FROM dbo.trn_calc_run WHERE channel_id=@ChannelId AND period_id=@PeriodId);

        DELETE FROM dbo.trn_incentive_detail
        WHERE  calc_run_id IN (SELECT calc_run_id FROM dbo.trn_calc_run WHERE channel_id=@ChannelId AND period_id=@PeriodId);

        DELETE FROM dbo.trn_calc_run
        WHERE  channel_id = @ChannelId AND period_id = @PeriodId;

        -- ── 3. Create new calc run ───────────────────────────────
        INSERT INTO dbo.trn_calc_run
            (period_id, channel_id, run_status, approved_by, created_at)
        VALUES
            (@PeriodId, @ChannelId, N'RUNNING', @ApprovedBy, GETDATE());

        SET @RunId = SCOPE_IDENTITY();

        -- ════════════════════════════════════════════════════════
        -- INSERT : trn_incentive_detail  (STAFF-level)
        --
        -- ตรรกะหลัก:
        --   incentive = incentive_base × product_weight × goal_multiplier
        --   incentive_base  → lookup จาก mst_incentive_rate ตาม position_level
        --   product_weight  → lookup จาก mst_product_weight ตาม channel + product
        --   goal_multiplier → lookup จาก mst_goal_threshold ตาม achievement%
        -- ════════════════════════════════════════════════════════
        ;WITH
        -- Product weights per product (channel-level, ไม่ขึ้นกับ salesman)
        pw AS (
            SELECT p.product_code,
                   pw.weight_percent
            FROM   dbo.mst_product_weight pw
            JOIN   dbo.mst_product p ON p.product_id = pw.product_id
            WHERE  pw.channel_id      = @ChannelId
              AND  pw.is_active       = 1
              AND  pw.effective_from <= @SalesMonth
              AND  (pw.effective_to IS NULL OR pw.effective_to >= @SalesMonth)
        ),
        -- Targets (only products that have a weight configured)
        tgt AS (
            SELECT t.salesman_code, t.product_code, t.target_amount
            FROM   dbo.trn_sales_target t
            JOIN   pw ON pw.product_code = t.product_code
            WHERE  t.channel_id = @ChannelId
              AND  t.period_id  = @PeriodId
              AND  t.target_amount > 0
        ),
        -- Actuals for the period
        act AS (
            SELECT a.salesman_code, a.product_code,
                   SUM(a.actual_amount) AS actual_amount
            FROM   dbo.trn_sales_actual a
            WHERE  a.channel_id = @ChannelId AND a.period_id = @PeriodId
            GROUP  BY a.salesman_code, a.product_code
        ),
        -- Shortage products (achievement forced to 1.0)
        shortage AS (
            SELECT p.product_code
            FROM   dbo.mst_shortage_policy sp
            JOIN   dbo.mst_product p ON p.product_id = sp.product_id
            WHERE  sp.shortage_month = @SalesMonth AND sp.is_active = 1
        ),
        -- Target + Actual + Achievement per salesman per product
        ta AS (
            SELECT t.salesman_code,
                   t.product_code,
                   t.target_amount,
                   COALESCE(a.actual_amount, 0) AS actual_amount,
                   CAST(CASE WHEN s.product_code IS NOT NULL THEN 1 ELSE 0 END AS BIT) AS shortage_flag,
                   CAST(ROUND(
                       CASE WHEN s.product_code IS NOT NULL THEN 1.0
                            ELSE COALESCE(a.actual_amount, 0) / t.target_amount
                       END, 4) AS DECIMAL(9,4)) AS raw_achievement
            FROM   tgt t
            LEFT JOIN act      a ON a.salesman_code = t.salesman_code AND a.product_code = t.product_code
            LEFT JOIN shortage s ON s.product_code  = t.product_code
        ),
        -- Achievement → goal_multiplier
        ta_gm AS (
            SELECT ta.*,
                   COALESCE(
                       (SELECT TOP 1 gt.multiplier
                        FROM   dbo.mst_goal_threshold gt
                        WHERE  gt.is_active = 1
                          AND  ta.raw_achievement >= gt.achievement_from
                          AND  (gt.achievement_to IS NULL OR ta.raw_achievement < gt.achievement_to)
                        ORDER  BY gt.achievement_from DESC),
                       0
                   ) AS goal_multiplier
            FROM   ta
        )
        INSERT INTO dbo.trn_incentive_detail
            (calc_run_id, salesman_code, position_level_code, product_code,
             target_amount, actual_amount, achievement, shortage_flag, final_achievement,
             goal_multiplier, incentive_base, product_weight, incentive_amount)
        SELECT
            @RunId,
            gm.salesman_code,
            pl.position_code,
            gm.product_code,
            CAST(ROUND(gm.target_amount, 2)   AS DECIMAL(18,2)),
            CAST(ROUND(gm.actual_amount,  2)   AS DECIMAL(18,2)),
            gm.raw_achievement,
            gm.shortage_flag,
            gm.raw_achievement,
            CAST(ROUND(gm.goal_multiplier, 4) AS DECIMAL(9,4)),
            ir.incentive_base,
            pw.weight_percent,
            -- incentive = base × weight × multiplier
            CAST(ROUND(ir.incentive_base * pw.weight_percent * gm.goal_multiplier, 2) AS DECIMAL(18,2))
        FROM   ta_gm gm
        -- Employee info for position level and rate lookup
        JOIN   dbo.mst_employee       e  ON e.employee_code     = gm.salesman_code
                                        AND e.channel_id        = @ChannelId
                                        AND e.is_active         = 1
        JOIN   dbo.mst_position_level pl ON pl.position_level_id = e.position_level_id
        -- Incentive rate by position level
        OUTER APPLY (
            SELECT TOP 1 COALESCE(ir2.rate_new, ir2.rate_old) AS incentive_base
            FROM   dbo.mst_incentive_rate ir2
            WHERE  ir2.channel_id       = @ChannelId
              AND  ir2.position_level_id = e.position_level_id
              AND  ir2.is_active         = 1
              AND  ir2.effective_from   <= @SalesMonth
              AND  (ir2.effective_to IS NULL OR ir2.effective_to >= @SalesMonth)
            ORDER  BY ir2.effective_from DESC
        ) ir
        -- Product weight
        JOIN   pw ON pw.product_code = gm.product_code;

        -- ════════════════════════════════════════════════════════
        -- OUTPUT : out_for_hr_variable
        --          aggregate incentive_amount per employee
        -- ════════════════════════════════════════════════════════
        INSERT INTO dbo.out_for_hr_variable
            (calc_run_id, employee_code, employee_name_th, position_level_code, channel_code,
             variable_pay_month, incentive_staff, incentive_sect, incentive_dept, incentive_ad,
             gd_incentive_total, total_variable, payment_method)
        SELECT
            @RunId,
            d.salesman_code,
            COALESCE(e.employee_name_th, d.salesman_code),
            d.position_level_code,
            @ChannelCode,
            @SalesMonth,
            -- incentive breakdown by position
            CAST(ROUND(SUM(CASE WHEN d.position_level_code = 'STAFF'    THEN d.incentive_amount ELSE 0 END), 2) AS DECIMAL(18,2)),
            CAST(ROUND(SUM(CASE WHEN d.position_level_code = 'SECT_MGR' THEN d.incentive_amount ELSE 0 END), 2) AS DECIMAL(18,2)),
            CAST(ROUND(SUM(CASE WHEN d.position_level_code = 'DEPT_MGR' THEN d.incentive_amount ELSE 0 END), 2) AS DECIMAL(18,2)),
            CAST(ROUND(SUM(CASE WHEN d.position_level_code = 'AD'       THEN d.incentive_amount ELSE 0 END), 2) AS DECIMAL(18,2)),
            CAST(0.00 AS DECIMAL(18,2)),  -- gd_incentive_total (S&I ไม่มี GD)
            CAST(ROUND(SUM(d.incentive_amount), 2) AS DECIMAL(18,2)),
            N'โอนเข้าบัญชี'
        FROM   dbo.trn_incentive_detail d
        LEFT JOIN dbo.mst_employee e ON e.employee_code = d.salesman_code AND e.channel_id = @ChannelId
        WHERE  d.calc_run_id = @RunId
        GROUP  BY d.salesman_code, d.position_level_code, e.employee_name_th;

        -- ── 4. Mark run complete ─────────────────────────────────
        UPDATE dbo.trn_calc_run
        SET    run_status = N'CALCULATED',
               updated_at = GETDATE()
        WHERE  calc_run_id = @RunId;

        COMMIT TRANSACTION;

        SELECT @RunId AS calc_run_id,
               @ChannelCode AS channel_code,
               @PeriodId AS period_id,
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

PRINT 'usp_run_si_incentive_calculation created successfully';
GO
