SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*
17_create_proc_validate_tt_26_sheets_pass_fail.sql
Purpose:
- Validate TT 26-sheet mapping against database for one period.
- Compare source extract metrics (#tt_sheet_source_metrics temp table) vs DB metrics.

Input contract:
- Caller should create and populate #tt_sheet_source_metrics with columns:
    sheet_no INT,
    sheet_name NVARCHAR(100),
    source_row_count INT NULL,
    source_amount DECIMAL(18,2) NULL,
    compare_mode NVARCHAR(20) NOT NULL  -- EXACT | NONZERO | INFO
    row_tolerance INT NULL,
    amount_tolerance DECIMAL(18,2) NULL
*/
CREATE OR ALTER PROCEDURE dbo.usp_validate_tt_26_sheets_pass_fail
    @PeriodCode NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ChannelId INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'TT');
    DECLARE @PeriodId INT;
    DECLARE @SalesMonth DATE;
    DECLARE @CalcRunId INT;

    IF @ChannelId IS NULL
        THROW 51001, 'TT channel not found.', 1;

    SELECT @PeriodId = period_id, @SalesMonth = sales_month
    FROM dbo.mst_period
    WHERE period_code = @PeriodCode;

    IF @PeriodId IS NULL
        THROW 51002, 'Period code not found.', 1;

    SELECT TOP 1 @CalcRunId = calc_run_id
    FROM dbo.trn_calc_run
    WHERE period_id = @PeriodId
      AND channel_id = @ChannelId
    ORDER BY calc_run_id DESC;

    IF OBJECT_ID('tempdb..#tt_sheet_source_metrics', 'U') IS NULL
        THROW 51003, '#tt_sheet_source_metrics temp table is required.', 1;

    IF OBJECT_ID('tempdb..#sheet_catalog', 'U') IS NOT NULL DROP TABLE #sheet_catalog;
    CREATE TABLE #sheet_catalog (
        sheet_no INT NOT NULL PRIMARY KEY,
        sheet_name NVARCHAR(100) NOT NULL
    );

    INSERT INTO #sheet_catalog(sheet_no, sheet_name)
    VALUES
        (1, N'01_Top WS'),
        (2, N'02_WS SF'),
        (3, N'03_WS WH'),
        (4, N'04_Test'),
        (5, N'05_SF WH'),
        (6, N'06_M_Month'),
        (7, N'07_Product'),
        (8, N'08_T_SectAbove'),
        (9, N'09_2) หลักการคำนวน Table'),
        (10, N'10_Period'),
        (11, N'11_3)Target & Cal'),
        (12, N'12_Actual'),
        (13, N'13_ASTBase'),
        (14, N'14_HR Rep'),
        (15, N'15_1) For HR'),
        (16, N'16_1) For HR (AD)'),
        (17, N'17_Shortage'),
        (18, N'18_Aji Plus'),
        (19, N'19_Actual_Aji Plus'),
        (20, N'20_RDQ'),
        (21, N'21_Actual_RDQ'),
        (22, N'22_RDM'),
        (23, N'23_Actual_RDM'),
        (24, N'24_RDNS'),
        (25, N'25_Actual_RDNS'),
        (26, N'26_Sales Target');

    ;WITH db_metrics AS (
        SELECT 1 AS sheet_no, N'01_Top WS' AS sheet_name,
               COUNT(*) AS db_row_count,
               CAST(SUM(t.target_amount) AS DECIMAL(18,2)) AS db_amount
        FROM dbo.trn_sales_target t
        WHERE t.period_id = @PeriodId AND t.channel_id = @ChannelId

        UNION ALL
        SELECT 2, N'02_WS SF', COUNT(*), CAST(SUM(t.target_amount) AS DECIMAL(18,2))
        FROM dbo.trn_sales_target t
        WHERE t.period_id = @PeriodId AND t.channel_id = @ChannelId

        UNION ALL
        SELECT 3, N'03_WS WH', COUNT(*), CAST(SUM(t.target_amount) AS DECIMAL(18,2))
        FROM dbo.trn_sales_target t
        WHERE t.period_id = @PeriodId AND t.channel_id = @ChannelId

        UNION ALL
        SELECT 4, N'04_Test', COUNT(*), CAST(NULL AS DECIMAL(18,2))
        FROM dbo.trn_calc_run r
        WHERE r.period_id = @PeriodId AND r.channel_id = @ChannelId

        UNION ALL
        SELECT 5, N'05_SF WH', COUNT(*), CAST(SUM(t.target_amount) AS DECIMAL(18,2))
        FROM dbo.trn_sales_target t
        WHERE t.period_id = @PeriodId AND t.channel_id = @ChannelId

        UNION ALL
        SELECT 6, N'06_M_Month', COUNT(*), CAST(NULL AS DECIMAL(18,2))
        FROM dbo.mst_payment_cycle pc
        WHERE pc.sales_month = @SalesMonth

        UNION ALL
        SELECT 7, N'07_Product', COUNT(*), CAST(NULL AS DECIMAL(18,2))
        FROM dbo.mst_product p
        WHERE p.is_active = 1

        UNION ALL
        SELECT 8, N'08_T_SectAbove', COUNT(*), CAST(SUM(COALESCE(ir.rate_new, ir.rate_old)) AS DECIMAL(18,2))
        FROM dbo.mst_incentive_rate ir
        WHERE ir.channel_id = @ChannelId
          AND ir.is_active = 1
          AND ir.effective_from <= @SalesMonth
          AND (ir.effective_to IS NULL OR ir.effective_to >= @SalesMonth)

        UNION ALL
        SELECT 9, N'09_2) หลักการคำนวน Table', COUNT(*), CAST(SUM(gt.multiplier) AS DECIMAL(18,2))
        FROM dbo.mst_goal_threshold gt
        WHERE gt.is_active = 1

        UNION ALL
        SELECT 10, N'10_Period', COUNT(*), CAST(NULL AS DECIMAL(18,2))
        FROM dbo.mst_period p
        WHERE p.period_id = @PeriodId

        UNION ALL
        SELECT 11, N'11_3)Target & Cal', COUNT(*), CAST(SUM(t.target_amount) AS DECIMAL(18,2))
        FROM dbo.trn_sales_target t
        WHERE t.period_id = @PeriodId AND t.channel_id = @ChannelId

        UNION ALL
        SELECT 12, N'12_Actual', COUNT(*), CAST(SUM(a.actual_amount) AS DECIMAL(18,2))
        FROM dbo.trn_sales_actual a
        WHERE a.period_id = @PeriodId AND a.channel_id = @ChannelId

        UNION ALL
        SELECT 13, N'13_ASTBase', COUNT(*), CAST(NULL AS DECIMAL(18,2))
        FROM dbo.mst_org_hierarchy h
        WHERE h.channel_id = @ChannelId
          AND h.effective_month = @SalesMonth

        UNION ALL
        SELECT 14, N'14_HR Rep', COUNT(*), CAST(NULL AS DECIMAL(18,2))
        FROM dbo.mst_employee e
        WHERE e.channel_id = @ChannelId
          AND e.is_active = 1

        UNION ALL
        SELECT 15, N'15_1) For HR', COUNT(*), CAST(SUM(o.total_variable) AS DECIMAL(18,2))
        FROM dbo.out_for_hr_variable o
        WHERE o.calc_run_id = @CalcRunId

        UNION ALL
        SELECT 16, N'16_1) For HR (AD)', COUNT(*), CAST(SUM(o.incentive_ad) AS DECIMAL(18,2))
        FROM dbo.out_for_hr_variable o
        WHERE o.calc_run_id = @CalcRunId
          AND o.position_level_code = N'AD'

        UNION ALL
        SELECT 17, N'17_Shortage', COUNT(*), CAST(NULL AS DECIMAL(18,2))
        FROM dbo.mst_shortage_policy sp
        WHERE sp.shortage_month = @SalesMonth
          AND sp.is_active = 1

        UNION ALL
        SELECT 18, N'18_Aji Plus', COUNT(*), CAST(SUM(gd.payout_amount) AS DECIMAL(18,2))
        FROM dbo.trn_gd_incentive_detail gd
        INNER JOIN dbo.mst_gd_product gp ON gp.gd_product_id = gd.gd_product_id
        WHERE gd.calc_run_id = @CalcRunId
          AND gp.gd_product_code = N'AJP'

        UNION ALL
        SELECT 19, N'19_Actual_Aji Plus', COUNT(*), CAST(SUM(a.actual_amount) AS DECIMAL(18,2))
        FROM dbo.trn_sales_actual a
        WHERE a.period_id = @PeriodId
          AND a.channel_id = @ChannelId
          AND a.product_code IN (N'AP', N'SKU-AP')

        UNION ALL
        SELECT 20, N'20_RDQ', COUNT(*), CAST(SUM(gd.payout_amount) AS DECIMAL(18,2))
        FROM dbo.trn_gd_incentive_detail gd
        INNER JOIN dbo.mst_gd_product gp ON gp.gd_product_id = gd.gd_product_id
        WHERE gd.calc_run_id = @CalcRunId
          AND gp.gd_product_code IN (N'RDC', N'RDQ')

        UNION ALL
        SELECT 21, N'21_Actual_RDQ', COUNT(*), CAST(SUM(a.actual_amount) AS DECIMAL(18,2))
        FROM dbo.trn_sales_actual a
        WHERE a.period_id = @PeriodId
          AND a.channel_id = @ChannelId
          AND a.product_code IN (N'Q', N'SKU-Q')

        UNION ALL
        SELECT 22, N'22_RDM', COUNT(*), CAST(SUM(gd.payout_amount) AS DECIMAL(18,2))
        FROM dbo.trn_gd_incentive_detail gd
        INNER JOIN dbo.mst_gd_product gp ON gp.gd_product_id = gd.gd_product_id
        WHERE gd.calc_run_id = @CalcRunId
          AND gp.gd_product_code IN (N'RM', N'RDM')

        UNION ALL
        SELECT 23, N'23_Actual_RDM', COUNT(*), CAST(SUM(a.actual_amount) AS DECIMAL(18,2))
        FROM dbo.trn_sales_actual a
        WHERE a.period_id = @PeriodId
          AND a.channel_id = @ChannelId
          AND a.product_code IN (N'M', N'SKU-M')

        UNION ALL
        SELECT 24, N'24_RDNS', COUNT(*), CAST(SUM(gd.payout_amount) AS DECIMAL(18,2))
        FROM dbo.trn_gd_incentive_detail gd
        INNER JOIN dbo.mst_gd_product gp ON gp.gd_product_id = gd.gd_product_id
        WHERE gd.calc_run_id = @CalcRunId
          AND gp.gd_product_code = N'RDNS'

        UNION ALL
        SELECT 25, N'25_Actual_RDNS', COUNT(*), CAST(SUM(a.actual_amount) AS DECIMAL(18,2))
        FROM dbo.trn_sales_actual a
        WHERE a.period_id = @PeriodId
          AND a.channel_id = @ChannelId
          AND a.product_code IN (N'NS', N'SKU-NS')

        UNION ALL
        SELECT 26, N'26_Sales Target', COUNT(*), CAST(SUM(t.target_amount) AS DECIMAL(18,2))
        FROM dbo.trn_sales_target t
        WHERE t.period_id = @PeriodId AND t.channel_id = @ChannelId
    )
    SELECT
        @PeriodCode AS period_code,
        sc.sheet_no,
        sc.sheet_name,
        sm.source_row_count,
        sm.source_amount,
        dm.db_row_count,
        dm.db_amount,
        COALESCE(sm.compare_mode, N'INFO') AS compare_mode,
        CASE
            WHEN COALESCE(sm.compare_mode, N'INFO') = N'INFO' THEN N'INFO'
            WHEN sm.source_row_count IS NULL THEN N'CHECK'
            WHEN COALESCE(sm.compare_mode, N'NONZERO') = N'EXACT'
                 AND ABS(COALESCE(dm.db_row_count, 0) - COALESCE(sm.source_row_count, 0)) <= COALESCE(sm.row_tolerance, 0)
                 AND (
                        sm.source_amount IS NULL
                        OR ABS(COALESCE(dm.db_amount, 0) - sm.source_amount) <= COALESCE(sm.amount_tolerance, 0)
                     )
                THEN N'PASS'
            WHEN COALESCE(sm.compare_mode, N'NONZERO') = N'NONZERO'
                 AND COALESCE(dm.db_row_count, 0) > 0
                 AND (
                        sm.source_amount IS NULL
                        OR COALESCE(dm.db_amount, 0) > 0
                     )
                THEN N'PASS'
            ELSE N'FAIL'
        END AS validation_status,
        ABS(COALESCE(dm.db_row_count, 0) - COALESCE(sm.source_row_count, 0)) AS row_gap_abs,
        CASE
            WHEN sm.source_amount IS NULL THEN NULL
            ELSE ABS(COALESCE(dm.db_amount, 0) - sm.source_amount)
        END AS amount_gap_abs
    FROM #sheet_catalog sc
    LEFT JOIN #tt_sheet_source_metrics sm
        ON sm.sheet_no = sc.sheet_no
    LEFT JOIN db_metrics dm
        ON dm.sheet_no = sc.sheet_no
    ORDER BY sc.sheet_no;
END
GO
