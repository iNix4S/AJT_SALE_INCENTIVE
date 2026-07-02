using System.Data;
using System.Text.RegularExpressions;
using Dapper;
using Microsoft.Data.SqlClient;
using NCalc;
using AjtIncentive.Application.Interfaces;

namespace AjtIncentive.Infrastructure.CalculationEngines;

/// <summary>
/// Engine ทั่วไป (table-driven) สำหรับ channel ที่ยังไม่มี engine เฉพาะ (เช่น Channel#5 ที่เพิ่ง onboard)
/// ไม่ hardcode ต่อ channel — คำนวณจาก trn_sales_target/trn_sales_actual + master tables
/// (mst_incentive_rate, mst_product_weight, mst_goal_threshold, mst_shortage_policy)
/// แล้ว evaluate สูตรจาก mst_formula_expression (channel_id ตรงกับ channel ที่ระบุ)
/// รองรับ onboarding channel ใหม่โดยไม่ต้องเพิ่ม engine class ใหม่ต่อ channel
/// </summary>
public sealed class GenericChannelNCalcEngine : IGenericChannelCalculationEngine
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
        public string FormulaExpr { get; init; } = "[base_rate] * [weight_pct] * [goal_mult]";
        public decimal IncentiveAmount { get; set; }
    }

    public GenericChannelNCalcEngine(string connectionString)
    {
        _connectionString = connectionString;
    }

    public async Task<int> RunAsync(string channelCode, int periodId, string? approvedBy = null, string? wsType = null)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();

        var channelId = await conn.ExecuteScalarAsync<int?>(
            "SELECT channel_id FROM dbo.mst_channel WHERE UPPER(channel_code) = UPPER(@ChannelCode) AND is_active = 1;",
            new { ChannelCode = channelCode });

        if (!channelId.HasValue)
            throw new InvalidOperationException($"Channel '{channelCode}' is not configured in mst_channel.");

        var period = await conn.QuerySingleOrDefaultAsync<(int PeriodId, DateTime SalesMonth)?>(
            "SELECT period_id AS PeriodId, sales_month AS SalesMonth FROM dbo.mst_period WHERE period_id = @PeriodId;",
            new { PeriodId = periodId });

        if (!period.HasValue)
            throw new InvalidOperationException($"Period ID {periodId} not found in master data.");

        var hasFormula = await conn.ExecuteScalarAsync<int>(@"
SELECT CASE WHEN EXISTS(
    SELECT 1 FROM dbo.mst_formula_expression
    WHERE channel_id = @ChannelId
      AND formula_step = 'INCENTIVE_PER_PRODUCT'
      AND is_active = 1
) THEN 1 ELSE 0 END;", new { ChannelId = channelId.Value });

        if (hasFormula == 0)
            throw new InvalidOperationException($"Channel '{channelCode}' has no active formula in mst_formula_expression (INCENTIVE_PER_PRODUCT). Clone or create a formula before running.");

        await using var tx = await conn.BeginTransactionAsync();

        var runId = await CreateOrResetRunAsync(conn, tx, channelId.Value, periodId, approvedBy ?? "system");

        const string sql = @"
WITH src AS (
    SELECT t.salesman_code,
           t.product_code,
           t.target_amount,
           ISNULL(a.actual_amount, 0) AS actual_amount,
           CASE WHEN t.target_amount = 0 THEN 0 ELSE ROUND(ISNULL(a.actual_amount, 0) / t.target_amount, 4) END AS achievement
    FROM dbo.trn_sales_target t
    LEFT JOIN dbo.trn_sales_actual a
      ON a.period_id = t.period_id
     AND a.channel_id = t.channel_id
     AND a.salesman_code = t.salesman_code
     AND a.product_code = t.product_code
    WHERE t.period_id = @PeriodId
      AND t.channel_id = @ChannelId
)
SELECT
    src.salesman_code AS SalesmanCode,
    COALESCE(pl.position_code, N'STAFF') AS PositionLevelCode,
    src.product_code AS ProductCode,
    src.target_amount AS TargetAmount,
    src.actual_amount AS ActualAmount,
    src.achievement AS Achievement,
    CASE WHEN sp.shortage_policy_id IS NULL THEN CAST(0 AS BIT) ELSE CAST(1 AS BIT) END AS ShortageFlag,
    ISNULL(sp.override_achievement, src.achievement) AS FinalAchievement,
    ISNULL(g.multiplier, 1) AS GoalMultiplier,
    ISNULL(ir.rate_new, ISNULL(ir.rate_old, 0)) AS IncentiveBase,
    ISNULL(w.weight_percent, 1) AS ProductWeight,
    ISNULL(f.formula_expr, N'[base_rate] * [weight_pct] * [goal_mult]') AS FormulaExpr
FROM src
LEFT JOIN dbo.mst_employee e
       ON e.employee_code = src.salesman_code AND e.channel_id = @ChannelId
LEFT JOIN dbo.mst_position_level pl
       ON pl.position_level_id = e.position_level_id
LEFT JOIN dbo.mst_product p
       ON p.product_code = src.product_code
OUTER APPLY (
    SELECT TOP(1) sp.shortage_policy_id, sp.override_achievement
    FROM dbo.mst_shortage_policy sp
    WHERE sp.product_id = p.product_id
      AND sp.shortage_month = @SalesMonth
      AND sp.is_active = 1
) sp
OUTER APPLY (
    SELECT TOP(1) gt.multiplier
    FROM dbo.mst_goal_threshold gt
    WHERE gt.is_active = 1
      AND src.achievement >= gt.achievement_from
      AND (gt.achievement_to IS NULL OR src.achievement < gt.achievement_to)
    ORDER BY gt.sequence_no DESC
) g
OUTER APPLY (
    SELECT TOP(1) ir.rate_old, ir.rate_new
    FROM dbo.mst_incentive_rate ir
    WHERE ir.channel_id = @ChannelId
      AND ir.position_level_id = COALESCE(e.position_level_id, (SELECT TOP(1) position_level_id FROM dbo.mst_position_level WHERE position_code = N'STAFF'))
      AND (@WsType IS NULL OR ir.ws_type = @WsType)
      AND ir.is_active = 1
    ORDER BY ir.effective_from DESC
) ir
OUTER APPLY (
    SELECT TOP(1) pw.weight_percent
    FROM dbo.mst_product_weight pw
    WHERE pw.channel_id = @ChannelId
      AND pw.product_id = p.product_id
      AND (@WsType IS NULL OR pw.ws_type = @WsType)
      AND pw.is_active = 1
    ORDER BY pw.effective_from DESC
) w
OUTER APPLY (
    SELECT TOP(1) fe.formula_expr
    FROM dbo.mst_formula_expression fe
    WHERE fe.channel_id = @ChannelId
      AND fe.formula_step = N'INCENTIVE_PER_PRODUCT'
      AND fe.is_active = 1
      AND (fe.position_level_id IS NULL OR fe.position_level_id = e.position_level_id)
      AND (@WsType IS NULL OR fe.ws_type IS NULL OR fe.ws_type = @WsType)
    ORDER BY COALESCE(fe.formula_version, 1) DESC, fe.sort_order ASC, fe.formula_id DESC
) f;";

        var rows = (await conn.QueryAsync<DetailCalcRow>(
            new CommandDefinition(
                sql,
                new { ChannelId = channelId.Value, PeriodId = periodId, SalesMonth = period.Value.SalesMonth, WsType = wsType },
                transaction: tx))).ToList();

        foreach (var row in rows)
        {
            var normalizedFormula = NormalizeForNCalc(row.FormulaExpr);
            var expr = new Expression(normalizedFormula);
            expr.Parameters["base_rate"] = (double)row.IncentiveBase;
            expr.Parameters["weight_pct"] = (double)row.ProductWeight;
            expr.Parameters["goal_mult"] = (double)row.GoalMultiplier;
            expr.Parameters["pct_achievement"] = (double)row.FinalAchievement;
            row.IncentiveAmount = Math.Round(Convert.ToDecimal(expr.Evaluate()), 2);
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
                r.IncentiveAmount
            }),
            tx);

        await conn.ExecuteAsync(@"
INSERT INTO dbo.out_for_hr_variable
    (calc_run_id, employee_code, employee_name_th, position_level_code, channel_code,
     variable_pay_month, incentive_staff, incentive_sect, incentive_dept, incentive_div, incentive_ad,
     gd_incentive_total, total_variable, payment_method)
SELECT
    @RunId,
    d.salesman_code,
    COALESCE(e.employee_name_th, d.salesman_code),
    d.position_level_code,
    @ChannelCode,
    @SalesMonth,
    CAST(ROUND(SUM(CASE WHEN d.position_level_code = N'STAFF' THEN d.incentive_amount ELSE 0 END), 2) AS DECIMAL(18,2)),
    CAST(ROUND(SUM(CASE WHEN d.position_level_code = N'SECT_MGR' THEN d.incentive_amount ELSE 0 END), 2) AS DECIMAL(18,2)),
    CAST(ROUND(SUM(CASE WHEN d.position_level_code = N'DEPT_MGR' THEN d.incentive_amount ELSE 0 END), 2) AS DECIMAL(18,2)),
    CAST(ROUND(SUM(CASE WHEN d.position_level_code = N'DIV_MGR' THEN d.incentive_amount ELSE 0 END), 2) AS DECIMAL(18,2)),
    CAST(ROUND(SUM(CASE WHEN d.position_level_code = N'AD' THEN d.incentive_amount ELSE 0 END), 2) AS DECIMAL(18,2)),
    CAST(0.00 AS DECIMAL(18,2)),
    CAST(ROUND(SUM(d.incentive_amount), 2) AS DECIMAL(18,2)),
    N'BANK_TRANSFER'
FROM dbo.trn_incentive_detail d
LEFT JOIN dbo.mst_employee e ON e.employee_code = d.salesman_code AND e.channel_id = @ChannelId
WHERE d.calc_run_id = @RunId
GROUP BY d.salesman_code, d.position_level_code, e.employee_name_th;",
            new { RunId = runId, ChannelId = channelId.Value, ChannelCode = channelCode.Trim().ToUpperInvariant(), SalesMonth = period.Value.SalesMonth }, tx);

        await conn.ExecuteAsync(@"
UPDATE dbo.trn_calc_run
SET run_status = N'COMPLETED',
    calculated_at = GETDATE(),
    approved_by = COALESCE(approved_by, @ApprovedBy),
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
