using System.Data;
using System.Text.RegularExpressions;
using Dapper;
using Microsoft.Data.SqlClient;
using NCalc;
using AjtIncentive.Application.Interfaces;

namespace AjtIncentive.Infrastructure.CalculationEngines;

/// <summary>
/// Engine 3 (MT): .NET + NCalc (table-driven)
/// อ่านฐานข้อมูลจาก function และ master tables โดยไม่ใช้ hardcoded VALUES ในโค้ด
/// </summary>
public sealed class MtNCalcEngine : IMtCalculationEngine
{
    private readonly string _connectionString;

    private sealed class DetailCalcRow
    {
        public string SalesmanCode { get; init; } = "";
        public string PositionLevelCode { get; init; } = "";
        public string ProductCode { get; init; } = "";
        public decimal TargetAmount { get; init; }
        public decimal ActualAmount { get; init; }
        public decimal Achievement { get; init; }
        public bool ShortageFlag { get; init; }
        public decimal FinalAchievement { get; init; }
        public decimal GoalMultiplier { get; init; }
        public decimal IncentiveBase { get; init; }
        public decimal ProductWeight { get; init; }
        public decimal IncentiveAmount { get; set; }
    }

    public MtNCalcEngine(string connectionString)
    {
        _connectionString = connectionString;
    }

    public CalculationEngineType EngineType => CalculationEngineType.NCalc;

    public async Task<int> RunAsync(int periodId, string? approvedBy = null)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();

        var channelId = await conn.ExecuteScalarAsync<int?>(
            "SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'MT';");

        if (!channelId.HasValue)
            throw new InvalidOperationException("MT channel is not configured in mst_channel.");

        var periodExists = await conn.ExecuteScalarAsync<int>(
            "SELECT COUNT(*) FROM dbo.mst_period WHERE period_id = @PeriodId;",
            new { PeriodId = periodId });

        if (periodExists == 0)
            throw new InvalidOperationException($"Period ID {periodId} not found in master data.");

        var hasFunction = await conn.ExecuteScalarAsync<int>(
            "SELECT CASE WHEN OBJECT_ID(N'dbo.fn_calculate_mt_incentive_detail', N'TF') IS NULL THEN 0 ELSE 1 END;");

        if (hasFunction == 0)
            throw new InvalidOperationException("MT NCalc engine requires dbo.fn_calculate_mt_incentive_detail to be deployed.");

        var hasFormula = await conn.ExecuteScalarAsync<int>(@"
SELECT CASE WHEN EXISTS(
    SELECT 1
    FROM dbo.mst_formula_expression
    WHERE channel_id = @ChannelId
      AND formula_step = 'INCENTIVE_PER_PRODUCT'
      AND is_active = 1
) THEN 1 ELSE 0 END;", new { ChannelId = channelId.Value });

        if (hasFormula == 0)
            throw new InvalidOperationException("MT NCalc engine requires active formula in mst_formula_expression (INCENTIVE_PER_PRODUCT).");

        await using var tx = await conn.BeginTransactionAsync();

        var runId = await CreateOrResetRunAsync(conn, tx, channelId.Value, periodId, approvedBy ?? "system");

        var formulaExpr = await conn.ExecuteScalarAsync<string?>(@"
SELECT TOP (1) formula_expr
FROM dbo.mst_formula_expression
WHERE channel_id = @ChannelId
  AND formula_step = 'INCENTIVE_PER_PRODUCT'
  AND is_active = 1
ORDER BY CASE WHEN ws_type IS NULL THEN 0 ELSE 1 END, formula_id;",
            new { ChannelId = channelId.Value }, tx);

        if (string.IsNullOrWhiteSpace(formulaExpr))
            throw new InvalidOperationException("Cannot resolve MT formula expression for NCalc.");

        var rows = (await conn.QueryAsync<DetailCalcRow>(@"
SELECT
    salesman_code AS SalesmanCode,
    position_level_code AS PositionLevelCode,
    product_code AS ProductCode,
    target_amount AS TargetAmount,
    actual_amount AS ActualAmount,
    achievement AS Achievement,
    shortage_flag AS ShortageFlag,
    final_achievement AS FinalAchievement,
    goal_multiplier AS GoalMultiplier,
    incentive_base AS IncentiveBase,
    product_weight AS ProductWeight,
    incentive_amount AS IncentiveAmount
FROM dbo.fn_calculate_mt_incentive_detail(@PeriodId);",
            new { PeriodId = periodId }, tx)).ToList();

        var normalizedFormula = NormalizeForNCalc(formulaExpr);
        foreach (var row in rows)
        {
            if (!string.Equals(row.PositionLevelCode, "STAFF", StringComparison.OrdinalIgnoreCase) || row.TargetAmount <= 0)
                continue;

            var expr = new Expression(normalizedFormula);
            expr.Parameters["base_rate"] = (double)row.IncentiveBase;
            expr.Parameters["weight_pct"] = (double)row.ProductWeight;
            expr.Parameters["goal_mult"] = (double)row.GoalMultiplier;
            row.IncentiveAmount = Convert.ToDecimal(expr.Evaluate());
        }

        await conn.ExecuteAsync(@"
INSERT INTO dbo.trn_incentive_detail
    (calc_run_id, salesman_code, position_level_code, product_code,
     target_amount, actual_amount, achievement, shortage_flag, final_achievement,
     goal_multiplier, incentive_base, product_weight, incentive_amount)
VALUES
    (@RunId, @SalesmanCode, @PositionLevelCode, @ProductCode,
     @TargetAmount, @ActualAmount, @Achievement, @ShortageFlag, @FinalAchievement,
     @GoalMultiplier, @IncentiveBase, @ProductWeight, @IncentiveAmount);",
            rows.Select(r => new
            {
                RunId = runId,
                r.SalesmanCode,
                r.PositionLevelCode,
                r.ProductCode,
                r.TargetAmount,
                r.ActualAmount,
                r.Achievement,
                r.ShortageFlag,
                r.FinalAchievement,
                r.GoalMultiplier,
                r.IncentiveBase,
                r.ProductWeight,
                IncentiveAmount = Math.Round(r.IncentiveAmount, 4)
            }),
            tx);

        await conn.ExecuteAsync(@"
;WITH emap_raw AS (
    SELECT m.salesman_code, m.employee_code,
           ROW_NUMBER() OVER (
               PARTITION BY m.salesman_code
               ORDER BY CASE WHEN m.period_id = @PeriodId THEN 0 ELSE 1 END,
                        m.mt_map_id DESC
           ) AS rn
    FROM dbo.mst_mt_salesman_employee_map m
    WHERE m.channel_id = @ChannelId
      AND m.is_active = 1
      AND (m.period_id = @PeriodId OR m.period_id IS NULL)
),
emap AS (
    SELECT salesman_code, employee_code FROM emap_raw WHERE rn = 1
),
agg AS (
    SELECT
        em.employee_code,
        SUM(CASE WHEN d.position_level_code = N'STAFF'    THEN d.incentive_amount ELSE 0 END) AS incentive_staff,
        SUM(CASE WHEN d.position_level_code = N'SECT_MGR' THEN d.incentive_amount ELSE 0 END) AS incentive_sect,
        SUM(CASE WHEN d.position_level_code = N'DEPT_MGR' THEN d.incentive_amount ELSE 0 END) AS incentive_dept,
        SUM(CASE WHEN d.position_level_code = N'DIV_MGR'  THEN d.incentive_amount ELSE 0 END) AS incentive_div,
        SUM(CASE WHEN d.position_level_code = N'AD'       THEN d.incentive_amount ELSE 0 END) AS incentive_ad
    FROM dbo.trn_incentive_detail d
    JOIN emap em ON em.salesman_code = d.salesman_code
    WHERE d.calc_run_id = @RunId
    GROUP BY em.employee_code
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
    N'MT',
    p.sales_month,
    CAST(ROUND(a.incentive_staff, 2) AS DECIMAL(18,2)),
    CAST(ROUND(a.incentive_sect, 2) AS DECIMAL(18,2)),
    CAST(ROUND(a.incentive_dept, 2) AS DECIMAL(18,2)),
    CAST(ROUND(a.incentive_div, 2) AS DECIMAL(18,2)),
    CAST(ROUND(a.incentive_ad, 2) AS DECIMAL(18,2)),
    CAST(0 AS DECIMAL(18,2)),
    CAST(ROUND(a.incentive_staff + a.incentive_sect + a.incentive_dept + a.incentive_div + a.incentive_ad, 2) AS DECIMAL(18,2)),
    N'BANK_TRANSFER'
FROM agg a
JOIN dbo.mst_employee e ON e.employee_code = a.employee_code AND e.channel_id = @ChannelId
LEFT JOIN dbo.mst_position_level pl ON pl.position_level_id = e.position_level_id
JOIN dbo.mst_period p ON p.period_id = @PeriodId;",
            new { RunId = runId, PeriodId = periodId, ChannelId = channelId.Value }, tx);

        await conn.ExecuteAsync(@"
UPDATE dbo.trn_calc_run
SET run_status = N'COMPLETED',
    calculated_at = GETDATE(),
    approved_by = COALESCE(approved_by, @ApprovedBy),
    approved_at = CASE WHEN @ApprovedBy IS NOT NULL THEN GETDATE() ELSE NULL END,
    updated_at = GETDATE()
WHERE calc_run_id = @RunId;",
            new { RunId = runId, ApprovedBy = approvedBy ?? "system" }, tx);

        await tx.CommitAsync();
        return runId;
    }

    private static string NormalizeForNCalc(string formulaExpr)
    {
        return Regex.Replace(formulaExpr, @"\bROUND\b", "Round", RegexOptions.IgnoreCase);
    }

    private static async Task<int> CreateOrResetRunAsync(
        SqlConnection conn,
        IDbTransaction tx,
        int channelId,
        int periodId,
        string approvedBy)
    {
        await conn.ExecuteAsync(@"
DELETE al FROM dbo.aud_approval_log al
WHERE al.calc_run_id IN (SELECT calc_run_id FROM dbo.trn_calc_run WHERE channel_id=@ChannelId AND period_id=@PeriodId);

DELETE ob FROM dbo.out_export_batch ob
WHERE ob.calc_run_id IN (SELECT calc_run_id FROM dbo.trn_calc_run WHERE channel_id=@ChannelId AND period_id=@PeriodId);

DELETE ohf FROM dbo.out_for_hr_fixed ohf
WHERE ohf.calc_run_id IN (SELECT calc_run_id FROM dbo.trn_calc_run WHERE channel_id=@ChannelId AND period_id=@PeriodId);

DELETE ofh FROM dbo.out_for_hr_variable ofh
WHERE ofh.calc_run_id IN (SELECT calc_run_id FROM dbo.trn_calc_run WHERE channel_id=@ChannelId AND period_id=@PeriodId);

DELETE gd FROM dbo.trn_gd_incentive_detail gd
WHERE gd.calc_run_id IN (SELECT calc_run_id FROM dbo.trn_calc_run WHERE channel_id=@ChannelId AND period_id=@PeriodId);

DELETE kpi FROM dbo.trn_tt_special_kpi_detail kpi
WHERE kpi.calc_run_id IN (SELECT calc_run_id FROM dbo.trn_calc_run WHERE channel_id=@ChannelId AND period_id=@PeriodId);

DELETE tid FROM dbo.trn_incentive_detail tid
WHERE tid.calc_run_id IN (SELECT calc_run_id FROM dbo.trn_calc_run WHERE channel_id=@ChannelId AND period_id=@PeriodId);

DELETE FROM dbo.trn_calc_run
WHERE channel_id = @ChannelId AND period_id = @PeriodId;

INSERT INTO dbo.trn_calc_run(period_id, channel_id, run_status, approved_by, created_at)
VALUES(@PeriodId, @ChannelId, N'RUNNING', @ApprovedBy, GETDATE());",
            new { ChannelId = channelId, PeriodId = periodId, ApprovedBy = approvedBy }, tx);

                return await conn.ExecuteScalarAsync<int>(@"
SELECT TOP (1) calc_run_id
FROM dbo.trn_calc_run
WHERE channel_id = @ChannelId
    AND period_id = @PeriodId
ORDER BY calc_run_id DESC;",
                        new { ChannelId = channelId, PeriodId = periodId }, tx);
    }
}
