using System.Data;
using System.Text.RegularExpressions;
using Dapper;
using Microsoft.Data.SqlClient;
using NCalc;
using AjtIncentive.Application.Interfaces;

namespace AjtIncentive.Infrastructure.CalculationEngines;

/// <summary>
/// Engine 3 (S&I): .NET + NCalc
/// อ่านฐานข้อมูลจาก function และ evaluate สูตรจาก mst_formula_expression
/// </summary>
public sealed class SiNCalcEngine : ISiCalculationEngine
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

    public SiNCalcEngine(string connectionString)
    {
        _connectionString = connectionString;
    }

    public CalculationEngineType EngineType => CalculationEngineType.NCalc;

    public async Task<int> RunAsync(int periodId, string? approvedBy = null)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();

        var channelId = await conn.ExecuteScalarAsync<int?>(
            "SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'SI';");

        if (!channelId.HasValue)
            throw new InvalidOperationException("S&I channel is not configured in mst_channel.");

        var periodInfo = await conn.QuerySingleOrDefaultAsync<(int PeriodId, DateTime SalesMonth)?>(
            "SELECT period_id AS PeriodId, sales_month AS SalesMonth FROM dbo.mst_period WHERE period_id = @PeriodId;",
            new { PeriodId = periodId });

        if (!periodInfo.HasValue)
            throw new InvalidOperationException($"Period ID {periodId} not found in master data.");

        var hasFunction = await conn.ExecuteScalarAsync<int>(
            "SELECT CASE WHEN OBJECT_ID(N'dbo.fn_calculate_si_incentive_detail', N'TF') IS NULL THEN 0 ELSE 1 END;");

        if (hasFunction == 0)
            throw new InvalidOperationException("S&I NCalc engine requires dbo.fn_calculate_si_incentive_detail to be deployed.");

        var formulaCandidates = (await conn.QueryAsync<string>(@"
SELECT formula_expr
FROM dbo.mst_formula_expression
WHERE channel_id = @ChannelId
  AND formula_step = 'INCENTIVE_PER_PRODUCT'
  AND is_active = 1
  AND formula_expr IS NOT NULL
  AND LTRIM(RTRIM(formula_expr)) <> '';
", new { ChannelId = channelId.Value })).ToList();

        if (formulaCandidates.Count == 0)
            throw new InvalidOperationException("S&I NCalc engine requires active formula in mst_formula_expression (INCENTIVE_PER_PRODUCT).");

        var selectedFormula = formulaCandidates
            .FirstOrDefault(x => x.IndexOf("ROUND", StringComparison.OrdinalIgnoreCase) < 0)
            ?? formulaCandidates[0];

        await using var tx = await conn.BeginTransactionAsync();

        var runId = await CreateOrResetRunAsync(conn, tx, channelId.Value, periodId, approvedBy ?? "system");

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
FROM dbo.fn_calculate_si_incentive_detail(@PeriodId);",
            new { PeriodId = periodId }, tx)).ToList();

        var normalizedFormula = NormalizeForNCalc(selectedFormula);
        foreach (var row in rows)
        {
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
                IncentiveAmount = Math.Round(r.IncentiveAmount, 2)
            }),
            tx);

        await conn.ExecuteAsync(@"
INSERT INTO dbo.out_for_hr_variable
    (calc_run_id, employee_code, employee_name_th, position_level_code, channel_code,
     variable_pay_month, incentive_staff, incentive_sect, incentive_dept, incentive_ad,
     incentive_div, gd_incentive_total, total_variable, payment_method)
SELECT
    @RunId,
    d.salesman_code,
    COALESCE(e.employee_name_th, d.salesman_code),
    d.position_level_code,
    N'SI',
    @SalesMonth,
    CAST(ROUND(SUM(CASE WHEN d.position_level_code = N'STAFF' THEN d.incentive_amount ELSE 0 END), 2) AS DECIMAL(18,2)),
    CAST(ROUND(SUM(CASE WHEN d.position_level_code = N'SECT_MGR' THEN d.incentive_amount ELSE 0 END), 2) AS DECIMAL(18,2)),
    CAST(ROUND(SUM(CASE WHEN d.position_level_code = N'DEPT_MGR' THEN d.incentive_amount ELSE 0 END), 2) AS DECIMAL(18,2)),
    CAST(ROUND(SUM(CASE WHEN d.position_level_code = N'AD' THEN d.incentive_amount ELSE 0 END), 2) AS DECIMAL(18,2)),
    CAST(0.00 AS DECIMAL(18,2)),
    CAST(0.00 AS DECIMAL(18,2)),
    CAST(ROUND(SUM(d.incentive_amount), 2) AS DECIMAL(18,2)),
    N'BANK_TRANSFER'
FROM dbo.trn_incentive_detail d
LEFT JOIN dbo.mst_employee e ON e.employee_code = d.salesman_code AND e.channel_id = @ChannelId
WHERE d.calc_run_id = @RunId
GROUP BY d.salesman_code, d.position_level_code, e.employee_name_th;",
            new { RunId = runId, SalesMonth = periodInfo.Value.SalesMonth, ChannelId = channelId.Value }, tx);

        await conn.ExecuteAsync(@"
UPDATE dbo.trn_calc_run
SET run_status = N'COMPLETED',
    updated_at = GETDATE()
WHERE calc_run_id = @RunId;",
            new { RunId = runId }, tx);

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
DELETE FROM dbo.out_for_hr_variable
WHERE calc_run_id IN (SELECT calc_run_id FROM dbo.trn_calc_run WHERE channel_id=@ChannelId AND period_id=@PeriodId);

DELETE FROM dbo.trn_incentive_detail
WHERE calc_run_id IN (SELECT calc_run_id FROM dbo.trn_calc_run WHERE channel_id=@ChannelId AND period_id=@PeriodId);

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
