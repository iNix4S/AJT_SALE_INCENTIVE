SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*
Purpose:
- Reusable DB test suite for TT.
- Return result sets that mirror AJT_TT_Database_Test_Guide checks.
*/
CREATE OR ALTER PROCEDURE dbo.usp_validate_tt_database_test_suite
    @PeriodCode NVARCHAR(20) = N'FY2026-05',
    @WsType NVARCHAR(50) = N'TOP_WS',
    @RunCalculation BIT = 0,
    @ApprovedBy NVARCHAR(100) = N'test_runner'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @tt INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'TT');
    DECLARE @period_id INT = (SELECT period_id FROM dbo.mst_period WHERE period_code = @PeriodCode);
    DECLARE @sales_month DATE = (SELECT sales_month FROM dbo.mst_period WHERE period_code = @PeriodCode);

    IF @tt IS NULL
        THROW 56001, 'TT channel not found.', 1;

    IF @period_id IS NULL
        THROW 56002, 'Period code not found.', 1;

    IF @RunCalculation = 1
    BEGIN
        EXEC dbo.usp_run_tt_incentive_calculation
             @PeriodCode = @PeriodCode,
             @WsType = @WsType,
             @ApprovedBy = @ApprovedBy;
    END

    DECLARE @run_id INT = (
        SELECT TOP 1 calc_run_id
        FROM dbo.trn_calc_run
        WHERE channel_id = @tt
          AND period_id = @period_id
        ORDER BY calc_run_id DESC
    );

    /* RS1: Context */
    SELECT
        @PeriodCode AS period_code,
        @WsType AS ws_type,
        @sales_month AS sales_month,
        @run_id AS latest_calc_run_id,
        @RunCalculation AS run_calculation_executed;

    /* RS2: Formula completeness by ws_type */
    SELECT
        ws_type,
        COUNT(*) AS matrix_rows,
        CAST(SUM(product_weight_percent) AS DECIMAL(18,4)) AS sum_weight
    FROM dbo.mst_tt_ws_formula_matrix
    WHERE channel_id = @tt
      AND is_active = 1
    GROUP BY ws_type
    ORDER BY ws_type;

    /* RS3: Special KPI completeness */
    SELECT
        ws_type,
        g_group_code,
        COUNT(*) AS rule_rows
    FROM dbo.mst_tt_special_kpi_rule
    WHERE channel_id = @tt
      AND is_active = 1
    GROUP BY ws_type, g_group_code
    ORDER BY ws_type, g_group_code;

    /* RS4: Position rate coverage by ws_type */
    SELECT
        pl.position_code,
        ir.ws_type,
        COUNT(*) AS rate_rows,
        MAX(COALESCE(ir.rate_new, ir.rate_old, 0)) AS sample_rate
    FROM dbo.mst_incentive_rate ir
    JOIN dbo.mst_position_level pl
      ON pl.position_level_id = ir.position_level_id
    WHERE ir.channel_id = @tt
      AND ir.is_active = 1
    GROUP BY pl.position_code, ir.ws_type
    ORDER BY pl.position_code, ir.ws_type;

    /* RS5: Sheet-mapped counts */
    SELECT
        (SELECT COUNT(*) FROM dbo.trn_sales_target WHERE channel_id = @tt) AS sales_target_rows,
        (SELECT COUNT(*) FROM dbo.trn_sales_actual WHERE channel_id = @tt) AS sales_actual_rows,
        (SELECT COUNT(*) FROM dbo.trn_incentive_detail d JOIN dbo.trn_calc_run r ON r.calc_run_id = d.calc_run_id WHERE r.channel_id = @tt) AS incentive_detail_rows,
        (SELECT COUNT(*) FROM dbo.out_for_hr_variable o JOIN dbo.trn_calc_run r ON r.calc_run_id = o.calc_run_id WHERE r.channel_id = @tt) AS for_hr_rows,
        (SELECT COUNT(*) FROM dbo.out_for_hr_variable o JOIN dbo.trn_calc_run r ON r.calc_run_id = o.calc_run_id WHERE r.channel_id = @tt AND o.incentive_ad IS NOT NULL) AS for_hr_ad_rows,
        (SELECT COUNT(*) FROM dbo.mst_shortage_policy) AS shortage_rows,
        (SELECT COUNT(*) FROM dbo.mst_goal_threshold WHERE is_active = 1) AS goal_threshold_rows,
        (SELECT COUNT(*) FROM dbo.mst_tt_option1_band b WHERE b.channel_id = @tt AND b.is_active = 1) AS option_band_rows,
        (SELECT COUNT(*) FROM dbo.mst_tt_option1_payout p JOIN dbo.mst_tt_option1_band b ON b.tt_option1_band_id = p.tt_option1_band_id WHERE b.channel_id = @tt AND b.is_active = 1 AND p.is_active = 1) AS option_payout_rows;

    /* RS6: View existence check */
    SELECT
        v.view_name,
        CASE WHEN EXISTS (SELECT 1 FROM sys.views s WHERE s.name = v.view_name) THEN 1 ELSE 0 END AS exists_flag
    FROM (VALUES
        (N'vw_tt_formula_goal_threshold'),
        (N'vw_tt_formula_rate_by_position'),
        (N'vw_tt_formula_ws_matrix'),
        (N'vw_tt_formula_option1_band_payout'),
        (N'vw_tt_formula_special_kpi'),
        (N'vw_tt_formula_catalog')
    ) v(view_name)
    ORDER BY v.view_name;

    /* RS7: ws_type coverage in views */
    DECLARE @expected TABLE(ws_type NVARCHAR(50) PRIMARY KEY);
    INSERT INTO @expected(ws_type) VALUES (N'TOP_WS'),(N'WS_SF'),(N'WS_WH'),(N'SF_WH');

    ;WITH checks AS (
        SELECT N'vw_tt_formula_ws_matrix' AS view_name, e.ws_type,
               CASE WHEN EXISTS (SELECT 1 FROM dbo.vw_tt_formula_ws_matrix v WHERE v.ws_type = e.ws_type) THEN 1 ELSE 0 END AS has_data
        FROM @expected e
        UNION ALL
        SELECT N'vw_tt_formula_rate_by_position', e.ws_type,
               CASE WHEN EXISTS (SELECT 1 FROM dbo.vw_tt_formula_rate_by_position v WHERE v.ws_type = e.ws_type) THEN 1 ELSE 0 END
        FROM @expected e
        UNION ALL
        SELECT N'vw_tt_formula_special_kpi', e.ws_type,
               CASE WHEN EXISTS (SELECT 1 FROM dbo.vw_tt_formula_special_kpi v WHERE v.ws_type = e.ws_type) THEN 1 ELSE 0 END
        FROM @expected e
        UNION ALL
        SELECT N'vw_tt_formula_catalog:POSITION_RATE', e.ws_type,
               CASE WHEN EXISTS (SELECT 1 FROM dbo.vw_tt_formula_catalog v WHERE v.formula_type = N'POSITION_RATE' AND v.ws_type = e.ws_type) THEN 1 ELSE 0 END
        FROM @expected e
        UNION ALL
        SELECT N'vw_tt_formula_catalog:WS_MATRIX', e.ws_type,
               CASE WHEN EXISTS (SELECT 1 FROM dbo.vw_tt_formula_catalog v WHERE v.formula_type = N'WS_MATRIX' AND v.ws_type = e.ws_type) THEN 1 ELSE 0 END
        FROM @expected e
    )
    SELECT
        view_name,
        SUM(has_data) AS pass_ws_type_count,
        COUNT(*) AS expected_ws_type_count,
        CASE WHEN SUM(has_data) = COUNT(*) THEN N'PASS' ELSE N'FAIL' END AS status
    FROM checks
    GROUP BY view_name
    ORDER BY view_name;

    /* RS8: High-level status summary */
    ;WITH ws_matrix AS (
        SELECT ws_type, COUNT(*) AS c, SUM(product_weight_percent) AS w
        FROM dbo.mst_tt_ws_formula_matrix
        WHERE channel_id = @tt AND is_active = 1
        GROUP BY ws_type
    ),
    gates AS (
        SELECT
            CAST((SELECT COUNT(*) FROM ws_matrix WHERE ws_type IN (N'TOP_WS',N'WS_SF',N'WS_WH',N'SF_WH')) AS INT) AS ws_type_present_count,
            CAST((SELECT COUNT(*) FROM ws_matrix WHERE ws_type IN (N'TOP_WS',N'WS_SF',N'WS_WH',N'SF_WH') AND c = 11) AS INT) AS ws_type_11_rows_count,
            CAST((SELECT COUNT(*) FROM ws_matrix WHERE ws_type IN (N'TOP_WS',N'WS_SF',N'WS_WH',N'SF_WH') AND CAST(w AS DECIMAL(9,4)) = 1.0000) AS INT) AS ws_type_weight_1_count,
            CAST((SELECT COUNT(*) FROM dbo.mst_goal_threshold WHERE is_active = 1) AS INT) AS goal_rows,
            CAST((SELECT COUNT(*) FROM dbo.trn_sales_target WHERE channel_id = @tt) AS INT) AS target_rows,
            CAST((SELECT COUNT(*) FROM dbo.trn_sales_actual WHERE channel_id = @tt) AS INT) AS actual_rows,
            CAST((SELECT COUNT(*) FROM dbo.out_for_hr_variable o JOIN dbo.trn_calc_run r ON r.calc_run_id = o.calc_run_id WHERE r.channel_id = @tt) AS INT) AS for_hr_rows
    )
    SELECT
        ws_type_present_count,
        ws_type_11_rows_count,
        ws_type_weight_1_count,
        goal_rows,
        target_rows,
        actual_rows,
        for_hr_rows,
        CASE WHEN ws_type_present_count = 4 AND ws_type_11_rows_count = 4 AND ws_type_weight_1_count = 4 THEN N'PASS' ELSE N'FAIL' END AS matrix_gate,
        CASE WHEN goal_rows > 0 THEN N'PASS' ELSE N'FAIL' END AS goal_gate,
        CASE WHEN target_rows > 0 AND actual_rows > 0 THEN N'PASS' ELSE N'FAIL' END AS input_gate,
        CASE WHEN for_hr_rows > 0 THEN N'PASS' ELSE N'FAIL' END AS output_gate
    FROM gates;
END
GO
