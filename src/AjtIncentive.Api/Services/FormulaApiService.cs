using System.Text.RegularExpressions;
using System.Data;
using AjtIncentive.Api.Contracts;
using Dapper;
using Microsoft.Data.SqlClient;
using NCalc;

namespace AjtIncentive.Api.Services;

public interface IFormulaApiService
{
    Task<IReadOnlyCollection<dynamic>> ListAsync(string? channelCode, string? step, bool activeOnly, CancellationToken cancellationToken);
    Task<dynamic?> GetByCodeAsync(string formulaCode, CancellationToken cancellationToken);
    Task<int> CreateAsync(FormulaUpsertRequest request, CancellationToken cancellationToken);
    Task<int> UpdateAsync(string formulaCode, FormulaUpsertRequest request, CancellationToken cancellationToken);
    Task<int> ActivateAsync(string formulaCode, bool isActive, CancellationToken cancellationToken);
    FormulaValidationResponse Validate(FormulaValidationRequest request);
    Task<int> CloneChannelFormulasAsync(string targetChannel, string sourceChannel, bool setInactive, CancellationToken cancellationToken);
}

public sealed class FormulaApiService(ConnectionStringHolder holder) : IFormulaApiService
{
    private static readonly Regex VariableRegex = new(@"\[(?<name>[a-zA-Z0-9_]+)\]", RegexOptions.Compiled);

    private static readonly HashSet<string> AllowedVariables = new(StringComparer.OrdinalIgnoreCase)
    {
        "actual_amount",
        "target_amount",
        "base_rate",
        "weight_pct",
        "goal_mult",
        "special_kpi",
        "pct_achievement",
        "sum_incentive_per_product",
        "kpi_threshold",
        "bonus_amount"
    };

    public async Task<IReadOnlyCollection<dynamic>> ListAsync(string? channelCode, string? step, bool activeOnly, CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT f.formula_id, f.formula_code, f.formula_name, f.formula_step, f.channel_id,
       c.channel_code, f.position_level_id, f.ws_type, f.formula_expr, f.variables_json,
       f.description, f.sort_order, f.effective_from, f.effective_to, f.is_active,
       COALESCE(f.formula_version, 1) AS formula_version,
       COALESCE(f.status, CASE WHEN f.is_active = 1 THEN N'ACTIVE' ELSE N'DRAFT' END) AS status,
       f.parent_formula_id,
       f.created_at, f.updated_at
FROM dbo.mst_formula_expression f
LEFT JOIN dbo.mst_channel c ON c.channel_id = f.channel_id
WHERE (@ChannelCode IS NULL OR UPPER(c.channel_code) = UPPER(@ChannelCode))
  AND (@Step IS NULL OR UPPER(f.formula_step) = UPPER(@Step))
  AND (@ActiveOnly = 0 OR f.is_active = 1)
ORDER BY f.formula_code, COALESCE(f.formula_version, 1) DESC;";

        await using var conn = new SqlConnection(holder.Value);
        var rows = await conn.QueryAsync(
            new CommandDefinition(sql,
                new { ChannelCode = channelCode, Step = step, ActiveOnly = activeOnly },
                cancellationToken: cancellationToken));
        return rows.ToArray();
    }

    public async Task<dynamic?> GetByCodeAsync(string formulaCode, CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT TOP(1) f.formula_id, f.formula_code, f.formula_name, f.formula_step, f.channel_id,
       c.channel_code, f.position_level_id, f.ws_type, f.formula_expr, f.variables_json,
       f.description, f.sort_order, f.effective_from, f.effective_to, f.is_active,
       COALESCE(f.formula_version, 1) AS formula_version,
       COALESCE(f.status, CASE WHEN f.is_active = 1 THEN N'ACTIVE' ELSE N'DRAFT' END) AS status,
       f.parent_formula_id,
       f.created_at, f.updated_at
FROM dbo.mst_formula_expression f
LEFT JOIN dbo.mst_channel c ON c.channel_id = f.channel_id
WHERE UPPER(f.formula_code) = UPPER(@FormulaCode)
ORDER BY COALESCE(f.formula_version, 1) DESC, f.formula_id DESC;";

        await using var conn = new SqlConnection(holder.Value);
        return await conn.QuerySingleOrDefaultAsync(
            new CommandDefinition(sql, new { FormulaCode = formulaCode }, cancellationToken: cancellationToken));
    }

    public async Task<int> CreateAsync(FormulaUpsertRequest request, CancellationToken cancellationToken)
    {
        var validation = Validate(new FormulaValidationRequest { FormulaExpr = request.FormulaExpr });
        if (!validation.IsValid)
        {
            throw new InvalidOperationException(validation.ErrorMessage ?? "Invalid formula expression");
        }

        await using var conn = new SqlConnection(holder.Value);
        var formulaCode = request.FormulaCode.Trim().ToUpperInvariant();

        var parameters = new DynamicParameters();
        parameters.Add("FormulaId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        parameters.Add("FormulaCode", formulaCode);
        parameters.Add("FormulaName", request.FormulaName);
        parameters.Add("FormulaStep", request.FormulaStep);
        parameters.Add("ChannelId", request.ChannelId);
        parameters.Add("PositionLevelId", request.PositionLevelId);
        parameters.Add("WsType", request.WsType);
        parameters.Add("FormulaExpr", request.FormulaExpr);
        parameters.Add("VariablesJson", request.VariablesJson);
        parameters.Add("Description", request.Description);
        parameters.Add("SortOrder", request.SortOrder);
        parameters.Add("EffectiveFrom", request.EffectiveFrom);
        parameters.Add("EffectiveTo", request.EffectiveTo);
        parameters.Add("IsActive", request.IsActive);

        await conn.ExecuteAsync(
            new CommandDefinition(
                "dbo.usp_formula_expression_upsert_version",
                parameters,
                commandType: CommandType.StoredProcedure,
                cancellationToken: cancellationToken));

        return parameters.Get<int>("FormulaId");
    }

    public async Task<int> UpdateAsync(string formulaCode, FormulaUpsertRequest request, CancellationToken cancellationToken)
    {
        var normalizedCode = formulaCode.Trim().ToUpperInvariant();
        var validation = Validate(new FormulaValidationRequest { FormulaExpr = request.FormulaExpr });
        if (!validation.IsValid)
        {
            throw new InvalidOperationException(validation.ErrorMessage ?? "Invalid formula expression");
        }

        await using var conn = new SqlConnection(holder.Value);

        var parameters = new DynamicParameters();
        parameters.Add("FormulaId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        parameters.Add("FormulaCode", normalizedCode);
        parameters.Add("FormulaName", request.FormulaName);
        parameters.Add("FormulaStep", request.FormulaStep);
        parameters.Add("ChannelId", request.ChannelId);
        parameters.Add("PositionLevelId", request.PositionLevelId);
        parameters.Add("WsType", request.WsType);
        parameters.Add("FormulaExpr", request.FormulaExpr);
        parameters.Add("VariablesJson", request.VariablesJson);
        parameters.Add("Description", request.Description);
        parameters.Add("SortOrder", request.SortOrder);
        parameters.Add("EffectiveFrom", request.EffectiveFrom);
        parameters.Add("EffectiveTo", request.EffectiveTo);
        parameters.Add("IsActive", request.IsActive);

        await conn.ExecuteAsync(
            new CommandDefinition(
                "dbo.usp_formula_expression_upsert_version",
                parameters,
                commandType: CommandType.StoredProcedure,
                cancellationToken: cancellationToken));

        return parameters.Get<int>("FormulaId");
    }

    public async Task<int> ActivateAsync(string formulaCode, bool isActive, CancellationToken cancellationToken)
    {
        await using var conn = new SqlConnection(holder.Value);
        return await conn.ExecuteScalarAsync<int>(
            new CommandDefinition(
                "dbo.usp_formula_expression_set_active",
                new { FormulaCode = formulaCode, IsActive = isActive },
                commandType: CommandType.StoredProcedure,
                cancellationToken: cancellationToken));
    }

    public FormulaValidationResponse Validate(FormulaValidationRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.FormulaExpr))
        {
            return new FormulaValidationResponse { IsValid = false, ErrorMessage = "formulaExpr is required" };
        }

        var variables = VariableRegex.Matches(request.FormulaExpr)
            .Select(x => x.Groups["name"].Value)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();

        var forbidden = variables.Where(x => !AllowedVariables.Contains(x)).ToArray();
        if (forbidden.Length > 0)
        {
            return new FormulaValidationResponse
            {
                IsValid = false,
                ErrorMessage = $"Unsupported variables: {string.Join(",", forbidden)}",
                Variables = variables
            };
        }

        try
        {
            var normalizedFormula = Regex.Replace(request.FormulaExpr, @"\bROUND\b", "Round", RegexOptions.IgnoreCase);
            var expression = new Expression(normalizedFormula);
            var sample = request.SampleVariables ?? new Dictionary<string, decimal>(StringComparer.OrdinalIgnoreCase)
            {
                ["actual_amount"] = 100m,
                ["target_amount"] = 100m,
                ["base_rate"] = 100m,
                ["weight_pct"] = 1m,
                ["goal_mult"] = 1m,
                ["special_kpi"] = 0m,
                ["pct_achievement"] = 1m,
                ["sum_incentive_per_product"] = 100m,
                ["kpi_threshold"] = 1m,
                ["bonus_amount"] = 0m
            };

            foreach (var item in sample)
            {
                expression.Parameters[item.Key] = item.Value;
            }

            var eval = expression.Evaluate();
            decimal? result = eval is null ? null : Convert.ToDecimal(eval);

            return new FormulaValidationResponse
            {
                IsValid = true,
                Variables = variables,
                SampleResult = result
            };
        }
        catch (Exception ex)
        {
            return new FormulaValidationResponse
            {
                IsValid = false,
                ErrorMessage = ex.Message,
                Variables = variables
            };
        }
    }

    public async Task<int> CloneChannelFormulasAsync(string targetChannel, string sourceChannel, bool setInactive, CancellationToken cancellationToken)
    {
        await using var conn = new SqlConnection(holder.Value);
        return await conn.ExecuteScalarAsync<int>(
            new CommandDefinition(
                "dbo.usp_formula_expression_clone_channel",
                new { TargetChannel = targetChannel, SourceChannel = sourceChannel, SetInactive = setInactive },
                commandType: CommandType.StoredProcedure,
                cancellationToken: cancellationToken));
    }
}
