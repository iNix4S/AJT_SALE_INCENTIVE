using AjtIncentive.Api.Contracts;
using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;
using NCalc;

namespace AjtIncentive.Api.Services;

public interface ISandboxApiService
{
    Task<SandboxRunResponse> RunAsync(SandboxRunRequest request, CancellationToken cancellationToken);
    Task<IReadOnlyCollection<dynamic>> GetDetailsAsync(long sandboxRunId, CancellationToken cancellationToken);
    Task<SandboxCompareResponse> CompareAsync(SandboxCompareRequest request, CancellationToken cancellationToken);
}

public sealed class SandboxApiService(ConnectionStringHolder holder) : ISandboxApiService
{
    private sealed class TrialRow
    {
        public string SalesmanCode { get; init; } = string.Empty;
        public string ProductCode { get; init; } = string.Empty;
        public decimal TargetAmount { get; init; }
        public decimal ActualAmount { get; init; }
        public decimal Achievement { get; init; }
        public decimal GoalMult { get; init; }
        public decimal BaseRate { get; init; }
        public decimal WeightPct { get; init; }
        public string FormulaExpr { get; init; } = "[base_rate] * [weight_pct] * [goal_mult]";
    }

    public async Task<SandboxRunResponse> RunAsync(SandboxRunRequest request, CancellationToken cancellationToken)
    {
        if (request.PeriodId <= 0)
        {
            throw new InvalidOperationException("periodId must be > 0");
        }

        await using var conn = new SqlConnection(holder.Value);

        var sourceChannelId = await GetChannelIdAsync(conn, request.SourceTransactionChannel, cancellationToken);
        var targetChannelId = await GetChannelIdAsync(conn, request.TargetChannel, cancellationToken);

        var sql = @"
DECLARE @StaffPositionId INT = (
    SELECT TOP(1) position_level_id
    FROM dbo.mst_position_level
    WHERE position_code = N'STAFF'
);

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
      AND t.channel_id = @SourceChannelId
),
ctx AS (
    SELECT src.salesman_code,
           src.product_code,
           src.target_amount,
           src.actual_amount,
           src.achievement,
           ISNULL(g.multiplier, 1) AS goal_mult,
           ISNULL(ir.rate_new, ISNULL(ir.rate_old, 0)) AS base_rate,
           ISNULL(w.weight_percent, 1) AS weight_pct,
           ISNULL(f.formula_expr, N'[base_rate] * [weight_pct] * [goal_mult]') AS formula_expr
    FROM src
    LEFT JOIN dbo.mst_product p
      ON p.product_code = src.product_code
    OUTER APPLY (
        SELECT TOP(1) m.multiplier
        FROM dbo.mst_goal_threshold m
        WHERE m.is_active = 1
          AND src.achievement >= m.achievement_from
          AND (m.achievement_to IS NULL OR src.achievement < m.achievement_to)
        ORDER BY m.sequence_no DESC
    ) g
    OUTER APPLY (
        SELECT TOP(1) ir.rate_old, ir.rate_new
        FROM dbo.mst_incentive_rate ir
        WHERE ir.channel_id = @TargetChannelId
          AND ir.position_level_id = @StaffPositionId
          AND (@WsType IS NULL OR ir.ws_type = @WsType)
          AND ir.is_active = 1
        ORDER BY ir.effective_from DESC
    ) ir
    OUTER APPLY (
        SELECT TOP(1) pw.weight_percent
        FROM dbo.mst_product_weight pw
        WHERE pw.channel_id = @TargetChannelId
          AND pw.product_id = p.product_id
          AND (@WsType IS NULL OR pw.ws_type = @WsType)
          AND pw.is_active = 1
        ORDER BY pw.effective_from DESC
    ) w
    OUTER APPLY (
        SELECT TOP(1) f.formula_expr
        FROM dbo.mst_formula_expression f
        WHERE f.channel_id = @TargetChannelId
          AND f.formula_step = N'INCENTIVE_PER_PRODUCT'
          AND f.is_active = 1
          AND (@WsType IS NULL OR f.ws_type IS NULL OR f.ws_type = @WsType)
        ORDER BY COALESCE(f.formula_version, 1) DESC, f.sort_order ASC, f.formula_id DESC
    ) f
)
SELECT salesman_code AS SalesmanCode,
       product_code AS ProductCode,
       target_amount AS TargetAmount,
       actual_amount AS ActualAmount,
       achievement AS Achievement,
       goal_mult AS GoalMult,
       base_rate AS BaseRate,
       weight_pct AS WeightPct,
       formula_expr AS FormulaExpr
FROM ctx;";

        var trialRows = (await conn.QueryAsync<TrialRow>(
            new CommandDefinition(sql,
                new
                {
                    request.PeriodId,
                    SourceChannelId = sourceChannelId,
                    TargetChannelId = targetChannelId,
                    request.WsType
                },
                cancellationToken: cancellationToken))).ToArray();

        var approvedBy = string.IsNullOrWhiteSpace(request.ApprovedBy) ? "sandbox-api" : request.ApprovedBy;

        var outputRows = trialRows.Select(row =>
        {
            var incentive = Evaluate(row.FormulaExpr, new Dictionary<string, object?>
            {
                ["actual_amount"] = row.ActualAmount,
                ["target_amount"] = row.TargetAmount,
                ["base_rate"] = row.BaseRate,
                ["weight_pct"] = row.WeightPct,
                ["goal_mult"] = row.GoalMult,
                ["pct_achievement"] = row.Achievement,
                ["special_kpi"] = 0m
            });

            return new
            {
                row.SalesmanCode,
                row.ProductCode,
                row.TargetAmount,
                row.ActualAmount,
                row.Achievement,
                row.GoalMult,
                row.BaseRate,
                row.WeightPct,
                FormulaExpr = row.FormulaExpr,
                IncentiveAmount = incentive
            };
        }).ToArray();

        if (!request.Persist)
        {
            return new SandboxRunResponse
            {
                SandboxRunId = 0,
                RowCount = outputRows.Length,
                TotalIncentive = outputRows.Sum(x => x.IncentiveAmount),
                Persisted = false
            };
        }

        var runParameters = new DynamicParameters();
        runParameters.Add("SandboxRunId", dbType: DbType.Int64, direction: ParameterDirection.Output);
        runParameters.Add("TargetChannelId", targetChannelId);
        runParameters.Add("SourceChannelId", sourceChannelId);
        runParameters.Add("PeriodId", request.PeriodId);
        runParameters.Add("Engine", request.Engine);
        runParameters.Add("FormulaSetRef", request.FormulaSetRef);
        runParameters.Add("RunStatus", "CALCULATED");
        runParameters.Add("ApprovedBy", approvedBy);

        await conn.ExecuteAsync(
            new CommandDefinition(
                "dbo.usp_sbx_calc_run_create",
                runParameters,
                commandType: CommandType.StoredProcedure,
                cancellationToken: cancellationToken));

        var sandboxRunId = runParameters.Get<long>("SandboxRunId");

        foreach (var row in outputRows)
        {
            var detailParameters = new DynamicParameters();
            detailParameters.Add("SandboxIncentiveDetailId", dbType: DbType.Int64, direction: ParameterDirection.Output);
            detailParameters.Add("SandboxRunId", sandboxRunId);
            detailParameters.Add("SalesmanCode", row.SalesmanCode);
            detailParameters.Add("ProductCode", row.ProductCode);
            detailParameters.Add("TargetAmount", row.TargetAmount);
            detailParameters.Add("ActualAmount", row.ActualAmount);
            detailParameters.Add("Achievement", row.Achievement);
            detailParameters.Add("GoalMultiplier", row.GoalMult);
            detailParameters.Add("IncentiveBase", row.BaseRate);
            detailParameters.Add("ProductWeight", row.WeightPct);
            detailParameters.Add("FormulaExpr", row.FormulaExpr);
            detailParameters.Add("IncentiveAmount", row.IncentiveAmount);

            await conn.ExecuteAsync(
                new CommandDefinition(
                    "dbo.usp_sbx_incentive_detail_insert",
                    detailParameters,
                    commandType: CommandType.StoredProcedure,
                    cancellationToken: cancellationToken));
        }

        return new SandboxRunResponse
        {
            SandboxRunId = sandboxRunId,
            RowCount = outputRows.Length,
            TotalIncentive = outputRows.Sum(x => x.IncentiveAmount),
            Persisted = true
        };
    }

    public async Task<IReadOnlyCollection<dynamic>> GetDetailsAsync(long sandboxRunId, CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT d.sandbox_incentive_detail_id,
       d.sandbox_run_id,
       d.salesman_code,
       d.product_code,
       d.target_amount,
       d.actual_amount,
       d.achievement,
       d.goal_multiplier,
       d.incentive_base,
       d.product_weight,
       d.formula_expr,
       d.incentive_amount,
       d.created_at
FROM dbo.sbx_incentive_detail d
WHERE d.sandbox_run_id = @SandboxRunId
ORDER BY d.sandbox_incentive_detail_id;";

        await using var conn = new SqlConnection(holder.Value);
        var rows = await conn.QueryAsync(new CommandDefinition(sql, new { SandboxRunId = sandboxRunId }, cancellationToken: cancellationToken));
        return rows.ToArray();
    }

    public async Task<SandboxCompareResponse> CompareAsync(SandboxCompareRequest request, CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT
    ISNULL((SELECT SUM(incentive_amount) FROM dbo.sbx_incentive_detail WHERE sandbox_run_id = @SandboxRunId), 0) AS SandboxTotal,
    ISNULL((SELECT SUM(incentive_amount) FROM dbo.trn_incentive_detail WHERE calc_run_id = @BaselineCalcRunId), 0) AS BaselineTotal,
    ISNULL((SELECT COUNT(1) FROM dbo.sbx_incentive_detail WHERE sandbox_run_id = @SandboxRunId), 0) AS SandboxRows,
    ISNULL((SELECT COUNT(1) FROM dbo.trn_incentive_detail WHERE calc_run_id = @BaselineCalcRunId), 0) AS BaselineRows;";

        await using var conn = new SqlConnection(holder.Value);
        var row = await conn.QuerySingleAsync<(decimal SandboxTotal, decimal BaselineTotal, int SandboxRows, int BaselineRows)>(
            new CommandDefinition(sql,
                new { request.SandboxRunId, request.BaselineCalcRunId },
                cancellationToken: cancellationToken));

        return new SandboxCompareResponse
        {
            SandboxTotal = row.SandboxTotal,
            BaselineTotal = row.BaselineTotal,
            Delta = row.SandboxTotal - row.BaselineTotal,
            SandboxRows = row.SandboxRows,
            BaselineRows = row.BaselineRows
        };
    }

    private static decimal Evaluate(string formulaExpr, Dictionary<string, object?> vars)
    {
        var normalizedFormula = System.Text.RegularExpressions.Regex.Replace(
            formulaExpr, @"\bROUND\b", "Round", System.Text.RegularExpressions.RegexOptions.IgnoreCase);

        var expr = new Expression(normalizedFormula);
        foreach (var item in vars)
        {
            expr.Parameters[item.Key] = item.Value;
        }

        var eval = expr.Evaluate();
        return eval is null ? 0m : Math.Round(Convert.ToDecimal(eval), 2);
    }

    private static async Task<int> GetChannelIdAsync(SqlConnection conn, string channelCode, CancellationToken cancellationToken)
    {
        var id = await conn.ExecuteScalarAsync<int?>(
            new CommandDefinition(
                "SELECT TOP(1) channel_id FROM dbo.mst_channel WHERE UPPER(channel_code) = UPPER(@Code)",
                new { Code = channelCode },
                cancellationToken: cancellationToken));

        if (id is null)
        {
            throw new InvalidOperationException($"channel not found: {channelCode}");
        }

        return id.Value;
    }
}
