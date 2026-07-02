using System.Text.RegularExpressions;
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
        var hasVersionColumns = await HasVersionColumnsAsync(conn, cancellationToken);

        var formulaCode = request.FormulaCode.Trim().ToUpperInvariant();

        if (hasVersionColumns)
        {
            const string sql = @"
DECLARE @NextVersion INT = ISNULL((
    SELECT MAX(formula_version)
    FROM dbo.mst_formula_expression
    WHERE UPPER(formula_code) = UPPER(@FormulaCode)
), 0) + 1;

INSERT INTO dbo.mst_formula_expression
(
    formula_code, formula_name, formula_step, channel_id, position_level_id, ws_type,
    formula_expr, variables_json, description, sort_order,
    effective_from, effective_to, is_active,
    formula_version, parent_formula_id, status,
    created_at, updated_at
)
VALUES
(
    @FormulaCode, @FormulaName, @FormulaStep, @ChannelId, @PositionLevelId, @WsType,
    @FormulaExpr, @VariablesJson, @Description, @SortOrder,
    @EffectiveFrom, @EffectiveTo, @IsActive,
    @NextVersion, NULL, CASE WHEN @IsActive = 1 THEN N'ACTIVE' ELSE N'DRAFT' END,
    SYSUTCDATETIME(), NULL
);

SELECT CAST(SCOPE_IDENTITY() AS INT);";

            return await conn.ExecuteScalarAsync<int>(
                new CommandDefinition(sql,
                    new
                    {
                        FormulaCode = formulaCode,
                        request.FormulaName,
                        request.FormulaStep,
                        request.ChannelId,
                        request.PositionLevelId,
                        request.WsType,
                        request.FormulaExpr,
                        request.VariablesJson,
                        request.Description,
                        request.SortOrder,
                        request.EffectiveFrom,
                        request.EffectiveTo,
                        request.IsActive
                    },
                    cancellationToken: cancellationToken));
        }

        const string fallbackSql = @"
INSERT INTO dbo.mst_formula_expression
(
    formula_code, formula_name, formula_step, channel_id, position_level_id, ws_type,
    formula_expr, variables_json, description, sort_order,
    effective_from, effective_to, is_active,
    created_at, updated_at
)
VALUES
(
    @FormulaCode, @FormulaName, @FormulaStep, @ChannelId, @PositionLevelId, @WsType,
    @FormulaExpr, @VariablesJson, @Description, @SortOrder,
    @EffectiveFrom, @EffectiveTo, @IsActive,
    SYSUTCDATETIME(), NULL
);

SELECT CAST(SCOPE_IDENTITY() AS INT);";

        return await conn.ExecuteScalarAsync<int>(
            new CommandDefinition(fallbackSql,
                new
                {
                    FormulaCode = formulaCode,
                    request.FormulaName,
                    request.FormulaStep,
                    request.ChannelId,
                    request.PositionLevelId,
                    request.WsType,
                    request.FormulaExpr,
                    request.VariablesJson,
                    request.Description,
                    request.SortOrder,
                    request.EffectiveFrom,
                    request.EffectiveTo,
                    request.IsActive
                },
                cancellationToken: cancellationToken));
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
        var hasVersionColumns = await HasVersionColumnsAsync(conn, cancellationToken);

        if (hasVersionColumns)
        {
            const string sql = @"
DECLARE @ParentId INT = (
    SELECT TOP(1) formula_id
    FROM dbo.mst_formula_expression
    WHERE UPPER(formula_code) = UPPER(@FormulaCode)
    ORDER BY COALESCE(formula_version, 1) DESC, formula_id DESC
);

DECLARE @NextVersion INT = ISNULL((
    SELECT MAX(formula_version)
    FROM dbo.mst_formula_expression
    WHERE UPPER(formula_code) = UPPER(@FormulaCode)
), 0) + 1;

INSERT INTO dbo.mst_formula_expression
(
    formula_code, formula_name, formula_step, channel_id, position_level_id, ws_type,
    formula_expr, variables_json, description, sort_order,
    effective_from, effective_to, is_active,
    formula_version, parent_formula_id, status,
    created_at, updated_at
)
VALUES
(
    @FormulaCode, @FormulaName, @FormulaStep, @ChannelId, @PositionLevelId, @WsType,
    @FormulaExpr, @VariablesJson, @Description, @SortOrder,
    @EffectiveFrom, @EffectiveTo, @IsActive,
    @NextVersion, @ParentId, CASE WHEN @IsActive = 1 THEN N'ACTIVE' ELSE N'DRAFT' END,
    SYSUTCDATETIME(), NULL
);

SELECT CAST(SCOPE_IDENTITY() AS INT);";

            return await conn.ExecuteScalarAsync<int>(
                new CommandDefinition(sql,
                    new
                    {
                        FormulaCode = normalizedCode,
                        request.FormulaName,
                        request.FormulaStep,
                        request.ChannelId,
                        request.PositionLevelId,
                        request.WsType,
                        request.FormulaExpr,
                        request.VariablesJson,
                        request.Description,
                        request.SortOrder,
                        request.EffectiveFrom,
                        request.EffectiveTo,
                        request.IsActive
                    },
                    cancellationToken: cancellationToken));
        }

        const string fallbackSql = @"
UPDATE dbo.mst_formula_expression
SET formula_name = @FormulaName,
    formula_step = @FormulaStep,
    channel_id = @ChannelId,
    position_level_id = @PositionLevelId,
    ws_type = @WsType,
    formula_expr = @FormulaExpr,
    variables_json = @VariablesJson,
    description = @Description,
    sort_order = @SortOrder,
    effective_from = @EffectiveFrom,
    effective_to = @EffectiveTo,
    is_active = @IsActive,
    updated_at = SYSUTCDATETIME()
WHERE UPPER(formula_code) = UPPER(@FormulaCode);

SELECT @@ROWCOUNT;";

        return await conn.ExecuteScalarAsync<int>(
            new CommandDefinition(fallbackSql,
                new
                {
                    FormulaCode = normalizedCode,
                    request.FormulaName,
                    request.FormulaStep,
                    request.ChannelId,
                    request.PositionLevelId,
                    request.WsType,
                    request.FormulaExpr,
                    request.VariablesJson,
                    request.Description,
                    request.SortOrder,
                    request.EffectiveFrom,
                    request.EffectiveTo,
                    request.IsActive
                },
                cancellationToken: cancellationToken));
    }

    public async Task<int> ActivateAsync(string formulaCode, bool isActive, CancellationToken cancellationToken)
    {
        await using var conn = new SqlConnection(holder.Value);
        var hasStatus = await HasColumnAsync(conn, "dbo", "mst_formula_expression", "status", cancellationToken);

        if (hasStatus)
        {
            const string sql = @"
UPDATE dbo.mst_formula_expression
SET is_active = @IsActive,
    status = CASE WHEN @IsActive = 1 THEN N'ACTIVE' ELSE N'RETIRED' END,
    updated_at = SYSUTCDATETIME()
WHERE UPPER(formula_code) = UPPER(@FormulaCode);";

            return await conn.ExecuteAsync(
                new CommandDefinition(sql, new { FormulaCode = formulaCode, IsActive = isActive }, cancellationToken: cancellationToken));
        }

        const string fallbackSql = @"
UPDATE dbo.mst_formula_expression
SET is_active = @IsActive,
    updated_at = SYSUTCDATETIME()
WHERE UPPER(formula_code) = UPPER(@FormulaCode);";

        return await conn.ExecuteAsync(
            new CommandDefinition(fallbackSql, new { FormulaCode = formulaCode, IsActive = isActive }, cancellationToken: cancellationToken));
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
        const string sql = @"
DECLARE @SourceChannelId INT = (
    SELECT TOP(1) channel_id FROM dbo.mst_channel WHERE UPPER(channel_code) = UPPER(@SourceChannel)
);
DECLARE @TargetChannelId INT = (
    SELECT TOP(1) channel_id FROM dbo.mst_channel WHERE UPPER(channel_code) = UPPER(@TargetChannel)
);

IF @SourceChannelId IS NULL OR @TargetChannelId IS NULL
BEGIN
    RAISERROR(N'Invalid source or target channel', 16, 1);
    RETURN;
END;

INSERT INTO dbo.mst_formula_expression
(
    formula_code, formula_name, formula_step, channel_id, position_level_id, ws_type,
    formula_expr, variables_json, description, sort_order,
    effective_from, effective_to, is_active,
    formula_version, parent_formula_id, status,
    created_at, updated_at
)
SELECT
    CONCAT(@TargetChannel, N'_', source.formula_code, N'_', FORMAT(SYSUTCDATETIME(), 'yyyyMMddHHmmss')),
    source.formula_name,
    source.formula_step,
    @TargetChannelId,
    source.position_level_id,
    source.ws_type,
    source.formula_expr,
    source.variables_json,
    CONCAT(N'Cloned from ', @SourceChannel, N': ', source.formula_code),
    source.sort_order,
    source.effective_from,
    source.effective_to,
    CASE WHEN @SetInactive = 1 THEN 0 ELSE source.is_active END,
    1,
    source.formula_id,
    CASE WHEN @SetInactive = 1 THEN N'DRAFT' ELSE N'ACTIVE' END,
    SYSUTCDATETIME(),
    NULL
FROM dbo.mst_formula_expression source
WHERE source.channel_id = @SourceChannelId
  AND source.is_active = 1;

SELECT @@ROWCOUNT;";

        await using var conn = new SqlConnection(holder.Value);
        var hasVersionColumns = await HasVersionColumnsAsync(conn, cancellationToken);

        if (hasVersionColumns)
        {
            return await conn.ExecuteScalarAsync<int>(
                new CommandDefinition(sql,
                    new { TargetChannel = targetChannel, SourceChannel = sourceChannel, SetInactive = setInactive },
                    cancellationToken: cancellationToken));
        }

        const string fallbackSql = @"
DECLARE @SourceChannelId INT = (
    SELECT TOP(1) channel_id FROM dbo.mst_channel WHERE UPPER(channel_code) = UPPER(@SourceChannel)
);
DECLARE @TargetChannelId INT = (
    SELECT TOP(1) channel_id FROM dbo.mst_channel WHERE UPPER(channel_code) = UPPER(@TargetChannel)
);

INSERT INTO dbo.mst_formula_expression
(
    formula_code, formula_name, formula_step, channel_id, position_level_id, ws_type,
    formula_expr, variables_json, description, sort_order,
    effective_from, effective_to, is_active,
    created_at, updated_at
)
SELECT
    CONCAT(@TargetChannel, N'_', source.formula_code, N'_', FORMAT(SYSUTCDATETIME(), 'yyyyMMddHHmmss')),
    source.formula_name,
    source.formula_step,
    @TargetChannelId,
    source.position_level_id,
    source.ws_type,
    source.formula_expr,
    source.variables_json,
    CONCAT(N'Cloned from ', @SourceChannel, N': ', source.formula_code),
    source.sort_order,
    source.effective_from,
    source.effective_to,
    CASE WHEN @SetInactive = 1 THEN 0 ELSE source.is_active END,
    SYSUTCDATETIME(),
    NULL
FROM dbo.mst_formula_expression source
WHERE source.channel_id = @SourceChannelId
  AND source.is_active = 1;

SELECT @@ROWCOUNT;";

        return await conn.ExecuteScalarAsync<int>(
            new CommandDefinition(fallbackSql,
                new { TargetChannel = targetChannel, SourceChannel = sourceChannel, SetInactive = setInactive },
                cancellationToken: cancellationToken));
    }

    private static async Task<bool> HasVersionColumnsAsync(SqlConnection conn, CancellationToken cancellationToken)
    {
        var hasFormulaVersion = await HasColumnAsync(conn, "dbo", "mst_formula_expression", "formula_version", cancellationToken);
        var hasStatus = await HasColumnAsync(conn, "dbo", "mst_formula_expression", "status", cancellationToken);
        var hasParent = await HasColumnAsync(conn, "dbo", "mst_formula_expression", "parent_formula_id", cancellationToken);
        return hasFormulaVersion && hasStatus && hasParent;
    }

    private static async Task<bool> HasColumnAsync(SqlConnection conn, string schema, string table, string column, CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT CASE WHEN EXISTS (
    SELECT 1
    FROM sys.columns c
    INNER JOIN sys.tables t ON t.object_id = c.object_id
    INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE s.name = @SchemaName
      AND t.name = @TableName
      AND c.name = @ColumnName
) THEN 1 ELSE 0 END;";

        var found = await conn.ExecuteScalarAsync<int>(
            new CommandDefinition(sql,
                new { SchemaName = schema, TableName = table, ColumnName = column },
                cancellationToken: cancellationToken));
        return found == 1;
    }
}
