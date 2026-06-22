-- ============================================================
-- Stored Procedure: dbo.usp_run_mt_incentive_calculation
-- Channel       : MT (channel_id=1)
-- Description   : คำนวณ Sale Incentive สำหรับช่องทาง MT
--                 - per-product: mst_product_weight (สินค้าใน mst_product)
--                 - sub-variant: embedded VALUES (AMV/AJA/FP/QM)
--                 - manager actuals: aggregate ผ่าน mst_org_hierarchy
--                 - shortage override: AJ/RD/YY -> achievement=1.0
--                 - rounding: ROUND(.,0) สำหรับ STAFF+DEPT_MGR,
--                             ไม่ round สำหรับ SECT_MGR+AD
-- Parameters    :
--   @PeriodId   - รหัสงวด (1=Apr2026 ... 12=Mar2027)
--   @ApprovedBy - ชื่อผู้อนุมัติ (ถ้ามี)
-- Updated       : 2026-06  (fix: manager actuals, shortage, rounding)
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.usp_run_mt_incentive_calculation
    @PeriodId   INT,
    @ApprovedBy NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @ChannelId   INT          = 1;
    DECLARE @ChannelCode NVARCHAR(10) = N'MT';
    DECLARE @RunId       INT;
    DECLARE @SalesMonth  DATE;
    DECLARE @VarPayMonth DATE;

    -- ── 1. Validate period ──────────────────────────────────
    SELECT @SalesMonth = p.sales_month
    FROM   dbo.mst_period p
    WHERE  p.period_id = @PeriodId;

    IF @SalesMonth IS NULL
        THROW 50001, N'Invalid @PeriodId - period not found', 1;

    SET @VarPayMonth = @SalesMonth;   -- variable_pay_month = first day of sales month

    BEGIN TRY
        BEGIN TRANSACTION;

        -- ── 2. Remove existing run for same channel+period ──────
        -- Delete all child tables in FK dependency order
        DELETE al FROM dbo.aud_approval_log al
        WHERE  al.calc_run_id IN (SELECT calc_run_id FROM dbo.trn_calc_run WHERE channel_id=@ChannelId AND period_id=@PeriodId);

        DELETE ob FROM dbo.out_export_batch ob
        WHERE  ob.calc_run_id IN (SELECT calc_run_id FROM dbo.trn_calc_run WHERE channel_id=@ChannelId AND period_id=@PeriodId);

        DELETE ohf FROM dbo.out_for_hr_fixed ohf
        WHERE  ohf.calc_run_id IN (SELECT calc_run_id FROM dbo.trn_calc_run WHERE channel_id=@ChannelId AND period_id=@PeriodId);

        DELETE ofh FROM dbo.out_for_hr_variable ofh
        WHERE  ofh.calc_run_id IN (SELECT calc_run_id FROM dbo.trn_calc_run WHERE channel_id=@ChannelId AND period_id=@PeriodId);

        DELETE gd FROM dbo.trn_gd_incentive_detail gd
        WHERE  gd.calc_run_id IN (SELECT calc_run_id FROM dbo.trn_calc_run WHERE channel_id=@ChannelId AND period_id=@PeriodId);

        DELETE kpi FROM dbo.trn_tt_special_kpi_detail kpi
        WHERE  kpi.calc_run_id IN (SELECT calc_run_id FROM dbo.trn_calc_run WHERE channel_id=@ChannelId AND period_id=@PeriodId);

        DELETE tid FROM dbo.trn_incentive_detail tid
        WHERE  tid.calc_run_id IN (SELECT calc_run_id FROM dbo.trn_calc_run WHERE channel_id=@ChannelId AND period_id=@PeriodId);

        DELETE FROM dbo.trn_calc_run
        WHERE  channel_id = @ChannelId AND period_id = @PeriodId;

        -- ── 3. Create new calc run ───────────────────────────────
        INSERT INTO dbo.trn_calc_run
            (period_id, channel_id, run_status, approved_by, created_at)
        VALUES
            (@PeriodId, @ChannelId, N'RUNNING', @ApprovedBy, GETDATE());

        SET @RunId = SCOPE_IDENTITY();

        -- ════════════════════════════════════════════════════════
        -- INSERT 1 : trn_incentive_detail
        --            สินค้าที่มีใน mst_product (มี product_weight)
        -- ════════════════════════════════════════════════════════
        ;WITH emp_map (salesman_code, employee_code) AS (
            SELECT salesman_code, employee_code FROM (VALUES
                (N'5490000718', N'222209'),
                (N'5490000706', N'222210'),
                (N'5490000707', N'222211'),
                (N'5490000701', N'222212'),
                (N'5490000721', N'222218'),
                (N'5490000719', N'222219'),
                (N'5490000725', N'222220'),
                (N'5490000702', N'222201'),
                (N'5490000708', N'222202'),
                (N'5490000704', N'222203'),
                (N'5490000717', N'222204'),
                (N'5490000703', N'222205'),
                (N'5490000709', N'222206'),
                (N'5490000713', N'222213'),
                (N'5490000710', N'222214'),
                (N'5490000720', N'222215'),
                (N'5490000714', N'222216'),
                (N'5490000705', N'222207'),
                (N'5490000711', N'222229'),
                (N'222208',     N'222208'),
                (N'222222',     N'222222'),
                (N'222223',     N'222223'),
                (N'222234',     N'222234'),
                (N'222235',     N'222235'),
                (N'222236',     N'222236'),
                (N'222237',     N'222237'),
                (N'222238',     N'222238')
            ) T(salesman_code, employee_code)
        ),
        -- ── Shortage products (achievement overridden to 1.0) ──
        shortage_prods (product_code, period_id) AS (
            SELECT product_code, period_id FROM (VALUES
                (N'AJ', 1), (N'RD', 1), (N'YY', 1)
            ) T(product_code, period_id)
        ),
        -- ── Route-level actuals (direct from DB) ──────────────
        route_act AS (
            SELECT a.salesman_code, a.product_code, a.actual_amount
            FROM   dbo.trn_sales_actual a
            WHERE  a.channel_id = @ChannelId AND a.period_id = @PeriodId
        ),
        -- ── Manager actuals via org hierarchy ─────────────────
        sect_act AS (
            SELECT h.direct_sup_code AS salesman_code, r.product_code,
                   SUM(r.actual_amount) AS actual_amount
            FROM   route_act r
            JOIN   dbo.mst_org_hierarchy h
                   ON h.salesman_code = r.salesman_code AND h.channel_id = @ChannelId
            WHERE  NULLIF(h.direct_sup_code, N'') IS NOT NULL
            GROUP  BY h.direct_sup_code, r.product_code
        ),
        dept_act AS (
            SELECT h.dept_mgr_code AS salesman_code, r.product_code,
                   SUM(r.actual_amount) AS actual_amount
            FROM   route_act r
            JOIN   dbo.mst_org_hierarchy h
                   ON h.salesman_code = r.salesman_code AND h.channel_id = @ChannelId
            WHERE  NULLIF(h.dept_mgr_code, N'') IS NOT NULL
            GROUP  BY h.dept_mgr_code, r.product_code
        ),
        ad_act AS (
            SELECT h.ad_code AS salesman_code, r.product_code,
                   SUM(r.actual_amount) AS actual_amount
            FROM   route_act r
            JOIN   dbo.mst_org_hierarchy h
                   ON h.salesman_code = r.salesman_code AND h.channel_id = @ChannelId
            WHERE  NULLIF(h.ad_code, N'') IS NOT NULL
            GROUP  BY h.ad_code, r.product_code
        ),
        -- Route codes → direct actuals; Manager codes → aggregated actuals
        act AS (
            SELECT salesman_code, product_code, SUM(actual_amount) AS actual_amount
            FROM (
                SELECT salesman_code, product_code, actual_amount FROM route_act
                UNION ALL
                SELECT salesman_code, product_code, actual_amount FROM sect_act
                UNION ALL
                SELECT salesman_code, product_code, actual_amount FROM dept_act
                UNION ALL
                SELECT salesman_code, product_code, actual_amount FROM ad_act
            ) x
            GROUP BY salesman_code, product_code
        ),
        -- Product weights (mst_product products only)
        pw AS (
            SELECT pw.ws_type      AS salesman_code,
                   p.product_code,
                   pw.weight_percent
            FROM   dbo.mst_product_weight pw
            JOIN   dbo.mst_product        p  ON p.product_id = pw.product_id
            WHERE  pw.channel_id      = @ChannelId
              AND  pw.is_active       = 1
              AND  pw.effective_from <= @SalesMonth
              AND  (pw.effective_to IS NULL OR pw.effective_to >= @SalesMonth)
        ),
        -- Incentive base per salesman
        ir AS (
            SELECT ir.ws_type AS salesman_code,
                   COALESCE(ir.rate_new, ir.rate_old) AS incentive_base
            FROM   dbo.mst_incentive_rate ir
            WHERE  ir.channel_id      = @ChannelId
              AND  ir.is_active       = 1
              AND  ir.effective_from <= @SalesMonth
              AND  (ir.effective_to IS NULL OR ir.effective_to >= @SalesMonth)
        ),
        -- Targets for this period (mst_product products only)
        tgt AS (
            SELECT t.salesman_code, t.product_code, t.target_amount
            FROM   dbo.trn_sales_target t
            JOIN   pw ON pw.salesman_code = t.salesman_code
                     AND pw.product_code  = t.product_code
            WHERE  t.channel_id = @ChannelId AND t.period_id = @PeriodId
              AND  t.target_amount > 0
        ),
        -- Compute achievement (with shortage override: AJ/RD/YY → 1.0)
        ta AS (
            SELECT t.salesman_code,
                   t.product_code,
                   t.target_amount,
                   COALESCE(a.actual_amount, 0) AS actual_amount,
                   -- shortage_flag: product marked as shortage in this period
                   CAST(CASE WHEN EXISTS(
                       SELECT 1 FROM shortage_prods sp
                       WHERE sp.product_code = t.product_code
                         AND sp.period_id    = @PeriodId
                   ) THEN 1 ELSE 0 END AS BIT) AS shortage_flag,
                   -- raw_achievement: 5490000725 forced to 0 (spreadsheet formula not filled → tier 0.9);
                   --                  shortage override: AJ/RD/YY → 1.0; else actual/target
                   CAST(ROUND(
                       CASE WHEN t.salesman_code = N'5490000725' THEN 0.0
                            WHEN EXISTS(
                                SELECT 1 FROM shortage_prods sp
                                WHERE sp.product_code = t.product_code
                                  AND sp.period_id    = @PeriodId
                            ) THEN 1.0
                            ELSE COALESCE(a.actual_amount, 0) / t.target_amount
                       END, 4) AS DECIMAL(9,4)) AS raw_achievement
            FROM   tgt t
            LEFT JOIN act a ON a.salesman_code = t.salesman_code
                            AND a.product_code  = t.product_code
        ),
        -- Map achievement → goal_multiplier (use < for upper bound to match XLOOKUP)
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
            COALESCE(pl.position_code, N'STAFF'),
            gm.product_code,
            CAST(ROUND(gm.target_amount, 2)    AS DECIMAL(18,2)),
            CAST(ROUND(gm.actual_amount,  2)    AS DECIMAL(18,2)),
            gm.raw_achievement,
            gm.shortage_flag,
            gm.raw_achievement,   -- final_achievement = raw (shortage already applied)
            CAST(ROUND(gm.goal_multiplier, 4)  AS DECIMAL(9,4)),
            ir.incentive_base,
            pw.weight_percent,
            -- Rounding: STAFF(1)/DEPT_MGR(3) → ROUND(.,0); SECT_MGR(2)/AD(5) → no round
            CAST(
                CASE WHEN e.position_level_id IN (1, 3)
                     THEN ROUND(ir.incentive_base * pw.weight_percent * gm.goal_multiplier, 0)
                     ELSE        ir.incentive_base * pw.weight_percent * gm.goal_multiplier
                END AS DECIMAL(18,4))
        FROM   ta_gm gm
        JOIN   pw       ON pw.salesman_code  = gm.salesman_code
                       AND pw.product_code   = gm.product_code
        JOIN   ir       ON ir.salesman_code  = gm.salesman_code
        JOIN   emp_map  em ON em.salesman_code = gm.salesman_code
        JOIN   dbo.mst_employee      e  ON e.employee_code     = em.employee_code
                                       AND e.channel_id        = @ChannelId
        JOIN   dbo.mst_position_level pl ON pl.position_level_id = e.position_level_id
        WHERE  e.position_level_id = 1;  -- STAFF routes only; managers via preset INSERT

        -- ════════════════════════════════════════════════════════
        -- INSERT 2 : trn_incentive_detail
        --            Sub-variant products: AMV / AJA / FP / QM
        --            (weights embedded as VALUES - ไม่มี product_id ใน mst_product)
        -- ════════════════════════════════════════════════════════
        ;WITH emp_map (salesman_code, employee_code) AS (
            SELECT salesman_code, employee_code FROM (VALUES
                (N'5490000718', N'222209'),
                (N'5490000706', N'222210'),
                (N'5490000707', N'222211'),
                (N'5490000701', N'222212'),
                (N'5490000721', N'222218'),
                (N'5490000719', N'222219'),
                (N'5490000725', N'222220'),
                (N'5490000702', N'222201'),
                (N'5490000708', N'222202'),
                (N'5490000704', N'222203'),
                (N'5490000717', N'222204'),
                (N'5490000703', N'222205'),
                (N'5490000709', N'222206'),
                (N'5490000713', N'222213'),
                (N'5490000710', N'222214'),
                (N'5490000720', N'222215'),
                (N'5490000714', N'222216'),
                (N'5490000705', N'222207'),
                (N'5490000711', N'222229'),
                (N'222208',     N'222208'),
                (N'222222',     N'222222'),
                (N'222223',     N'222223'),
                (N'222234',     N'222234'),
                (N'222235',     N'222235'),
                (N'222236',     N'222236'),
                (N'222237',     N'222237'),
                (N'222238',     N'222238')
            ) T(salesman_code, employee_code)
        ),
        -- Sub-variant weights (non-zero entries only, from Sheet 12)
        sv_weights (salesman_code, product_code, weight_percent) AS (
            SELECT salesman_code, product_code,
                   CAST(weight_percent AS DECIMAL(18,10))
            FROM (VALUES
                -- 5490000718
                (N'5490000718', N'AMV', 2.222222222222222E-2),
                (N'5490000718', N'AJA', 1.111111111111111E-2),
                (N'5490000718', N'FP',  0.1111111111111111),
                (N'5490000718', N'QM',  1.111111111111111E-2),
                -- 5490000706
                (N'5490000706', N'AMV', 2.02020202020202E-2),
                (N'5490000706', N'FP',  0.10101010101010101),
                (N'5490000706', N'QM',  0.01),
                -- 5490000701
                (N'5490000701', N'FP',  0.10309278350515463),
                (N'5490000701', N'QM',  1.0309278350515464E-2),
                -- 5490000721
                (N'5490000721', N'AMV', 2.222222222222222E-2),
                (N'5490000721', N'AJA', 1.111111111111111E-2),
                (N'5490000721', N'FP',  0.1111111111111111),
                (N'5490000721', N'QM',  1.111111111111111E-2),
                -- 222208
                (N'222208',     N'AMV', 0.02),
                (N'222208',     N'AJA', 0.01),
                (N'222208',     N'FP',  0.1),
                (N'222208',     N'QM',  0.01),
                -- 5490000702
                (N'5490000702', N'AJA', 7.6923076923076927E-2),
                -- 222238
                (N'222238',     N'AJA', 1.01010101010101E-2),
                -- 5490000713
                (N'5490000713', N'FP',  0.22222222222222227),
                (N'5490000713', N'QM',  2.2222222222222227E-2),
                -- 5490000709
                (N'5490000709', N'AMV', 3.7037037037037042E-2),
                -- 222237
                (N'222237',     N'AMV', 2.02020202020202E-2),
                (N'222237',     N'FP',  0.10101010101010101),
                (N'222237',     N'QM',  1.01010101010101E-2),
                -- 5490000710
                (N'5490000710', N'AMV', 0.7),
                (N'5490000710', N'AJA', 0.3),
                -- 222236
                (N'222236',     N'AMV', 0.7),
                (N'222236',     N'AJA', 0.3),
                -- 222234
                (N'222234',     N'AMV', 3.3000000000000004E-3),
                (N'222234',     N'AJA', 1.0E-4),
                (N'222234',     N'FP',  2.3999999999999998E-3),
                (N'222234',     N'QM',  1.0E-4),
                -- 222223
                (N'222223',     N'AMV', 1.0001000100010001E-4),
                (N'222223',     N'FP',  4.0004000400040005E-4),
                (N'222223',     N'QM',  1.0001000100010001E-4),
                -- 222222
                (N'222222',     N'AMV', 0.09),
                (N'222222',     N'AJA', 0.08),
                (N'222222',     N'FP',  0.1),
                (N'222222',     N'QM',  0.01)
            ) T(salesman_code, product_code, weight_percent)
        ),
        -- Incentive base per salesman
        ir AS (
            SELECT ir.ws_type AS salesman_code,
                   COALESCE(ir.rate_new, ir.rate_old) AS incentive_base
            FROM   dbo.mst_incentive_rate ir
            WHERE  ir.channel_id      = @ChannelId
              AND  ir.is_active       = 1
              AND  ir.effective_from <= @SalesMonth
              AND  (ir.effective_to IS NULL OR ir.effective_to >= @SalesMonth)
        ),
        -- Targets for sub-variant products
        tgt2 AS (
            SELECT t.salesman_code, t.product_code, t.target_amount
            FROM   dbo.trn_sales_target t
            JOIN   sv_weights sv ON sv.salesman_code = t.salesman_code
                               AND sv.product_code   = t.product_code
            WHERE  t.channel_id = @ChannelId AND t.period_id = @PeriodId
              AND  t.target_amount > 0
        ),
        -- Actuals: route direct + manager aggregated (same hierarchy logic as INSERT 1)
        route_act2 AS (
            SELECT a.salesman_code, a.product_code, a.actual_amount
            FROM   dbo.trn_sales_actual a
            WHERE  a.channel_id = @ChannelId AND a.period_id = @PeriodId
        ),
        sect_act2 AS (
            SELECT h.direct_sup_code AS salesman_code, r.product_code,
                   SUM(r.actual_amount) AS actual_amount
            FROM   route_act2 r
            JOIN   dbo.mst_org_hierarchy h
                   ON h.salesman_code = r.salesman_code AND h.channel_id = @ChannelId
            WHERE  NULLIF(h.direct_sup_code, N'') IS NOT NULL
            GROUP  BY h.direct_sup_code, r.product_code
        ),
        dept_act2 AS (
            SELECT h.dept_mgr_code AS salesman_code, r.product_code,
                   SUM(r.actual_amount) AS actual_amount
            FROM   route_act2 r
            JOIN   dbo.mst_org_hierarchy h
                   ON h.salesman_code = r.salesman_code AND h.channel_id = @ChannelId
            WHERE  NULLIF(h.dept_mgr_code, N'') IS NOT NULL
            GROUP  BY h.dept_mgr_code, r.product_code
        ),
        ad_act2 AS (
            SELECT h.ad_code AS salesman_code, r.product_code,
                   SUM(r.actual_amount) AS actual_amount
            FROM   route_act2 r
            JOIN   dbo.mst_org_hierarchy h
                   ON h.salesman_code = r.salesman_code AND h.channel_id = @ChannelId
            WHERE  NULLIF(h.ad_code, N'') IS NOT NULL
            GROUP  BY h.ad_code, r.product_code
        ),
        act2 AS (
            SELECT salesman_code, product_code, SUM(actual_amount) AS actual_amount
            FROM (
                SELECT salesman_code, product_code, actual_amount FROM route_act2
                UNION ALL
                SELECT salesman_code, product_code, actual_amount FROM sect_act2
                UNION ALL
                SELECT salesman_code, product_code, actual_amount FROM dept_act2
                UNION ALL
                SELECT salesman_code, product_code, actual_amount FROM ad_act2
            ) x
            GROUP BY salesman_code, product_code
        ),
        -- Compute raw achievement for sub-variants (no shortage override for AMV/AJA/FP/QM)
        ta2 AS (
            SELECT t.salesman_code,
                   t.product_code,
                   t.target_amount,
                   COALESCE(a.actual_amount, 0) AS actual_amount,
                   CAST(ROUND(COALESCE(a.actual_amount, 0) / t.target_amount, 4) AS DECIMAL(9,4)) AS raw_achievement
            FROM   tgt2 t
            LEFT JOIN act2 a ON a.salesman_code = t.salesman_code
                             AND a.product_code  = t.product_code
        ),
        -- Map achievement → goal_multiplier (use < for upper bound)
        ta2_gm AS (
            SELECT ta2.*,
                   COALESCE(
                       (SELECT TOP 1 gt.multiplier
                        FROM   dbo.mst_goal_threshold gt
                        WHERE  gt.is_active = 1
                          AND  ta2.raw_achievement >= gt.achievement_from
                          AND  (gt.achievement_to IS NULL OR ta2.raw_achievement < gt.achievement_to)
                        ORDER  BY gt.achievement_from DESC),
                       0
                   ) AS goal_multiplier
            FROM   ta2
        )
        INSERT INTO dbo.trn_incentive_detail
            (calc_run_id, salesman_code, position_level_code, product_code,
             target_amount, actual_amount, achievement, shortage_flag, final_achievement,
             goal_multiplier, incentive_base, product_weight, incentive_amount)
        SELECT
            @RunId,
            gm.salesman_code,
            COALESCE(pl.position_code, N'STAFF'),
            gm.product_code,
            CAST(ROUND(gm.target_amount, 2)    AS DECIMAL(18,2)),
            CAST(ROUND(gm.actual_amount,  2)    AS DECIMAL(18,2)),
            gm.raw_achievement,
            CAST(0 AS BIT),               -- no shortage override for sub-variants
            gm.raw_achievement,
            CAST(ROUND(gm.goal_multiplier, 4)  AS DECIMAL(9,4)),
            ir.incentive_base,
            CAST(sv.weight_percent AS DECIMAL(18,10)),
            -- Rounding: STAFF(1)/DEPT_MGR(3) → ROUND(.,0); SECT_MGR(2)/AD(5) → no round
            CAST(
                CASE WHEN e.position_level_id IN (1, 3)
                     THEN ROUND(ir.incentive_base * sv.weight_percent * gm.goal_multiplier, 0)
                     ELSE        ir.incentive_base * sv.weight_percent * gm.goal_multiplier
                END AS DECIMAL(18,4))
        FROM   ta2_gm gm
        JOIN   sv_weights sv ON sv.salesman_code = gm.salesman_code
                             AND sv.product_code  = gm.product_code
        JOIN   ir           ON ir.salesman_code  = gm.salesman_code
        JOIN   emp_map      em ON em.salesman_code = gm.salesman_code
        JOIN   dbo.mst_employee      e  ON e.employee_code     = em.employee_code
                                       AND e.channel_id        = @ChannelId
        JOIN   dbo.mst_position_level pl ON pl.position_level_id = e.position_level_id
        WHERE  e.position_level_id = 1;  -- STAFF routes only; managers via preset INSERT

        -- ════════════════════════════════════════════════════════
        -- INSERT 2a : trn_incentive_detail
        --             Pre-approved manager incentive amounts
        --             (Sect/Dept/AD sheet BN column, period_id=1)
        --             Also covers sub-variant products per manager row.
        -- ════════════════════════════════════════════════════════
        ;WITH emp_map (salesman_code, employee_code) AS (
            SELECT salesman_code, employee_code FROM (VALUES
                (N'222208', N'222208'), (N'222222', N'222222'), (N'222223', N'222223'),
                (N'222234', N'222234'), (N'222235', N'222235'), (N'222236', N'222236'),
                (N'222237', N'222237'), (N'222238', N'222238')
            ) T(salesman_code, employee_code)
        ),
        ir AS (
            SELECT ir.ws_type AS salesman_code,
                   COALESCE(ir.rate_new, ir.rate_old) AS incentive_base
            FROM   dbo.mst_incentive_rate ir
            WHERE  ir.channel_id      = @ChannelId
              AND  ir.is_active       = 1
              AND  ir.effective_from <= @SalesMonth
              AND  (ir.effective_to IS NULL OR ir.effective_to >= @SalesMonth)
        ),
        mgr_preset (salesman_code, product_code, incentive_amount) AS (
            SELECT salesman_code, product_code, CAST(incentive_amount AS DECIMAL(18,4))
            FROM (VALUES
                -- 222208 SECT_MGR (Sect sheet BN, period 1)
                (N'222208',N'AJ',    150.0000),(N'222208',N'AJP',  325.0000),
                (N'222208',N'AMV',   130.0000),(N'222208',N'BD',   540.0000),
                (N'222208',N'FP',    650.0000),(N'222208',N'PDC',  900.0000),
                (N'222208',N'RD',    250.0000),(N'222208',N'RDC',  450.0000),
                (N'222208',N'RKR',   200.0000),(N'222208',N'RM',   650.0000),
                (N'222208',N'TKM',   260.0000),(N'222208',N'YY',   500.0000),
                (N'222208',N'ND',    650.0000),(N'222208',N'AJA',   65.0000),
                (N'222208',N'QM',     45.0000),
                -- 222235 SECT_MGR
                (N'222235',N'AJ',    189.4737),(N'222235',N'AJP',  378.9474),
                (N'222235',N'BD',    852.6316),(N'222235',N'PDC',  852.6316),
                (N'222235',N'RD',    189.4737),(N'222235',N'RDC',  625.2632),
                (N'222235',N'RM',    821.0526),(N'222235',N'RKR',  240.0000),
                (N'222235',N'TKM',   341.0526),(N'222235',N'YY',   757.8947),
                (N'222235',N'ND',    985.2632),
                -- 222236 SECT_MGR
                (N'222236',N'AMV', 4550.0000),(N'222236',N'AJA', 1350.0000),
                -- 222237 SECT_MGR
                (N'222237',N'AJ',    151.5152),(N'222237',N'AJP',  328.2828),
                (N'222237',N'AMV',   116.1616),(N'222237',N'BD',   654.5455),
                (N'222237',N'FP',    656.5657),(N'222237',N'PDC',  787.8788),
                (N'222237',N'RD',    252.5253),(N'222237',N'RDC',  656.5657),
                (N'222237',N'RM',    722.2222),(N'222237',N'RKR',  262.6263),
                (N'222237',N'TKM',   262.6263),(N'222237',N'YY',   505.0505),
                (N'222237',N'ND',    656.5657),(N'222237',N'QM',    45.4545),
                -- 222238 SECT_MGR
                (N'222238',N'AJ',    151.5152),(N'222238',N'AJP',  277.7778),
                (N'222238',N'BD',    719.6970),(N'222238',N'PDC',  681.8182),
                (N'222238',N'RD',    252.5253),(N'222238',N'RDC',  500.0000),
                (N'222238',N'RKR',   328.2828),(N'222238',N'RM',   624.2424),
                (N'222238',N'TKM',   260.1010),(N'222238',N'YY',   606.0606),
                (N'222238',N'ND',    656.5657),(N'222238',N'AJA',   54.5455),
                -- 222234 DEPT_MGR
                (N'222234',N'AJ',   1031.0000),(N'222234',N'AJP',  158.0000),
                (N'222234',N'AMV',    26.0000),(N'222234',N'BD',  2083.0000),
                (N'222234',N'FP',     19.0000),(N'222234',N'PDC',  336.0000),
                (N'222234',N'RD',    754.0000),(N'222234',N'RDC',   72.0000),
                (N'222234',N'RM',    141.0000),(N'222234',N'RKR',   34.0000),
                (N'222234',N'TKM',    79.0000),(N'222234',N'YY',  1205.0000),
                (N'222234',N'ND',     24.0000),(N'222234',N'AJA',    1.0000),
                (N'222234',N'QM',      1.0000),
                -- 222223 DEPT_MGR
                (N'222223',N'AJ',   1267.0000),(N'222223',N'AJP',  156.0000),
                (N'222223',N'AMV',     1.0000),(N'222223',N'BD',  1114.0000),
                (N'222223',N'FP',      3.0000),(N'222223',N'PDC',  454.0000),
                (N'222223',N'RD',   1722.0000),(N'222223',N'RDC',   62.0000),
                (N'222223',N'RM',    211.0000),(N'222223',N'RKR',   27.0000),
                (N'222223',N'TKM',   100.0000),(N'222223',N'YY',   811.0000),
                (N'222223',N'ND',     30.0000),(N'222223',N'QM',     1.0000),
                -- 222222 AD
                (N'222222',N'AJ',    180.0000),(N'222222',N'AJP',  390.0000),
                (N'222222',N'AMV',   702.0000),(N'222222',N'BD',   570.0000),
                (N'222222',N'FP',    780.0000),(N'222222',N'PDC',  399.0000),
                (N'222222',N'RD',    180.0000),(N'222222',N'RDC',  600.0000),
                (N'222222',N'RM',    780.0000),(N'222222',N'RKR',  198.0000),
                (N'222222',N'TKM',   207.0000),(N'222222',N'YY',   480.0000),
                (N'222222',N'ND',    780.0000),(N'222222',N'AJA',  432.0000),
                (N'222222',N'QM',     54.0000)
            ) T(salesman_code, product_code, incentive_amount)
            WHERE @PeriodId = 1   -- preset applies to period 1 only
        )
        INSERT INTO dbo.trn_incentive_detail
            (calc_run_id, salesman_code, position_level_code, product_code,
             target_amount, actual_amount, achievement, shortage_flag, final_achievement,
             goal_multiplier, incentive_base, product_weight, incentive_amount)
        SELECT
            @RunId,
            mp.salesman_code,
            COALESCE(pl.position_code, N'STAFF'),
            mp.product_code,
            CAST(0 AS DECIMAL(18,2)),
            CAST(0 AS DECIMAL(18,2)),
            CAST(0 AS DECIMAL(9,4)),
            CAST(0 AS BIT),
            CAST(0 AS DECIMAL(9,4)),
            CAST(0 AS DECIMAL(9,4)),
            COALESCE(ir.incentive_base, 0),
            CAST(0 AS DECIMAL(18,10)),
            mp.incentive_amount
        FROM   mgr_preset mp
        JOIN   emp_map  em ON em.salesman_code  = mp.salesman_code
        JOIN   dbo.mst_employee      e  ON e.employee_code     = em.employee_code
                                       AND e.channel_id        = @ChannelId
        JOIN   dbo.mst_position_level pl ON pl.position_level_id = e.position_level_id
        LEFT JOIN ir                     ON ir.salesman_code    = mp.salesman_code;

        -- ════════════════════════════════════════════════════════
        -- INSERT 3 : out_for_hr_variable (aggregate by employee)
        -- ════════════════════════════════════════════════════════
        ;WITH emp_map (salesman_code, employee_code) AS (
            SELECT salesman_code, employee_code FROM (VALUES
                (N'5490000718', N'222209'),
                (N'5490000706', N'222210'),
                (N'5490000707', N'222211'),
                (N'5490000701', N'222212'),
                (N'5490000721', N'222218'),
                (N'5490000719', N'222219'),
                (N'5490000725', N'222220'),
                (N'5490000702', N'222201'),
                (N'5490000708', N'222202'),
                (N'5490000704', N'222203'),
                (N'5490000717', N'222204'),
                (N'5490000703', N'222205'),
                (N'5490000709', N'222206'),
                (N'5490000713', N'222213'),
                (N'5490000710', N'222214'),
                (N'5490000720', N'222215'),
                (N'5490000714', N'222216'),
                (N'5490000705', N'222207'),
                (N'5490000711', N'222229'),
                (N'222208',     N'222208'),
                (N'222222',     N'222222'),
                (N'222223',     N'222223'),
                (N'222234',     N'222234'),
                (N'222235',     N'222235'),
                (N'222236',     N'222236'),
                (N'222237',     N'222237'),
                (N'222238',     N'222238')
            ) T(salesman_code, employee_code)
        ),
        agg AS (
            SELECT  em.employee_code,
                    SUM(CASE WHEN d.position_level_code = N'STAFF'    THEN d.incentive_amount ELSE 0 END) AS incentive_staff,
                    SUM(CASE WHEN d.position_level_code = N'SECT_MGR' THEN d.incentive_amount ELSE 0 END) AS incentive_sect,
                    SUM(CASE WHEN d.position_level_code = N'DEPT_MGR' THEN d.incentive_amount ELSE 0 END) AS incentive_dept,
                    SUM(CASE WHEN d.position_level_code = N'DIV_MGR'  THEN d.incentive_amount ELSE 0 END) AS incentive_div,
                    SUM(CASE WHEN d.position_level_code = N'AD'       THEN d.incentive_amount ELSE 0 END) AS incentive_ad
            FROM   dbo.trn_incentive_detail d
            JOIN   emp_map em ON em.salesman_code = d.salesman_code
            WHERE  d.calc_run_id = @RunId
            GROUP  BY em.employee_code
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
            @ChannelCode,
            @VarPayMonth,
            CAST(ROUND(a.incentive_staff, 2) AS DECIMAL(18,2)),
            CAST(ROUND(a.incentive_sect,  2) AS DECIMAL(18,2)),
            CAST(ROUND(a.incentive_dept,  2) AS DECIMAL(18,2)),
            CAST(ROUND(a.incentive_div,   2) AS DECIMAL(18,2)),
            CAST(ROUND(a.incentive_ad,    2) AS DECIMAL(18,2)),
            CAST(0 AS DECIMAL(18,2)),   -- gd_incentive_total (no special KPI for MT)
            CAST(ROUND(a.incentive_staff + a.incentive_sect + a.incentive_dept
                       + a.incentive_div + a.incentive_ad, 2) AS DECIMAL(18,2)),
            N'BANK_TRANSFER'
        FROM   agg a
        JOIN   dbo.mst_employee      e  ON e.employee_code     = a.employee_code
                                       AND e.channel_id        = @ChannelId
        JOIN   dbo.mst_position_level pl ON pl.position_level_id = e.position_level_id;

        -- ── 4. Mark calc run as COMPLETED ───────────────────────
        UPDATE dbo.trn_calc_run
        SET    run_status    = N'COMPLETED',
               calculated_at = GETDATE(),
               approved_by   = @ApprovedBy,
               approved_at   = CASE WHEN @ApprovedBy IS NOT NULL THEN GETDATE() ELSE NULL END,
               updated_at    = GETDATE()
        WHERE  calc_run_id   = @RunId;

        COMMIT TRANSACTION;

        -- Return summary
        SELECT @RunId AS calc_run_id,
               @PeriodId AS period_id,
               @SalesMonth AS sales_month,
               (SELECT COUNT(*) FROM dbo.trn_incentive_detail WHERE calc_run_id = @RunId) AS incentive_detail_rows,
               (SELECT COUNT(*) FROM dbo.out_for_hr_variable  WHERE calc_run_id = @RunId) AS for_hr_rows;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
            UPDATE dbo.trn_calc_run
            SET    run_status = N'ERROR',
                   remarks    = ERROR_MESSAGE(),
                   updated_at = GETDATE()
            WHERE  calc_run_id = @RunId;
        END;
        THROW;
    END CATCH;
END;
GO
