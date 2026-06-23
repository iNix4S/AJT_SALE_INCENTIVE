using System.Text.RegularExpressions;
using Dapper;
using Microsoft.Data.SqlClient;
using NCalc;

namespace AjtIncentive.Web.Services;

// ─────────────────────────────────────────────────────────────
// Domain model
// ─────────────────────────────────────────────────────────────

public sealed class FormulaExpression
{
    public int FormulaId { get; init; }
    public string FormulaCode { get; init; } = string.Empty;
    public string FormulaName { get; init; } = string.Empty;
    public string FormulaStep { get; init; } = string.Empty;
    public int? ChannelId { get; init; }
    public string? ChannelCode { get; init; }
    public int? PositionLevelId { get; init; }
    public string? PositionCode { get; init; }
    public string? WsType { get; init; }
    public string FormulaExpr { get; init; } = string.Empty;
    public string? VariablesJson { get; init; }
    public string? Description { get; init; }
    public int SortOrder { get; init; }
    public DateOnly EffectiveFrom { get; init; }
    public DateOnly? EffectiveTo { get; init; }
    public bool IsActive { get; init; }
}

public sealed class FormulaEvalResult
{
    public bool Success { get; init; }
    public decimal Value { get; init; }
    public string? ErrorMessage { get; init; }
    public string FormulaCode { get; init; } = string.Empty;
    public string FormulaExpr { get; init; } = string.Empty;
    public IReadOnlyDictionary<string, decimal> Variables { get; init; }
        = new Dictionary<string, decimal>();
}

// ─────────────────────────────────────────────────────────────
// Interface
// ─────────────────────────────────────────────────────────────

public interface IFormulaEvaluatorService
{
    /// <summary>โหลด formula expressions ทั้งหมดจาก DB</summary>
    Task<IReadOnlyList<FormulaExpression>> GetAllAsync();

    /// <summary>โหลด formula expression ตาม code</summary>
    Task<FormulaExpression?> GetByCodeAsync(string formulaCode);

    /// <summary>Evaluate expression string ด้วย variables ที่ให้มา</summary>
    FormulaEvalResult Evaluate(string formulaExpr, Dictionary<string, decimal> variables,
                               string formulaCode = "");

    /// <summary>Evaluate โดยโหลด formula จาก DB ตาม code แล้ว inject variables</summary>
    Task<FormulaEvalResult> EvaluateByCodeAsync(string formulaCode,
                                                Dictionary<string, decimal> variables);

    /// <summary>ตรวจสอบว่า expression syntax ถูกต้องหรือไม่</summary>
    (bool IsValid, string? ErrorMessage) Validate(string formulaExpr);

    Task<int> SaveAsync(FormulaExpression formula);
    Task<int> DeleteAsync(int formulaId);
}

// ─────────────────────────────────────────────────────────────
// Implementation
// ─────────────────────────────────────────────────────────────

public sealed class FormulaEvaluatorService : IFormulaEvaluatorService
{
    private readonly string _connectionString;

    public FormulaEvaluatorService(string connectionString)
    {
        _connectionString = connectionString;
    }

    public async Task<IReadOnlyList<FormulaExpression>> GetAllAsync()
    {
        await using var conn = new SqlConnection(_connectionString);
        var rows = await conn.QueryAsync<FormulaExpressionDbRow>(@"
SELECT
    f.formula_id         AS FormulaId,
    f.formula_code       AS FormulaCode,
    f.formula_name       AS FormulaName,
    f.formula_step       AS FormulaStep,
    f.channel_id         AS ChannelId,
    c.channel_code       AS ChannelCode,
    f.position_level_id  AS PositionLevelId,
    pl.position_code     AS PositionCode,
    f.ws_type            AS WsType,
    f.formula_expr       AS FormulaExpr,
    f.variables_json     AS VariablesJson,
    f.description        AS Description,
    f.sort_order         AS SortOrder,
    f.effective_from     AS EffectiveFrom,
    f.effective_to       AS EffectiveTo,
    f.is_active          AS IsActive
FROM dbo.mst_formula_expression f
LEFT JOIN dbo.mst_channel        c  ON c.channel_id         = f.channel_id
LEFT JOIN dbo.mst_position_level pl ON pl.position_level_id = f.position_level_id
ORDER BY f.sort_order, f.formula_code;");
    return rows.Select(MapFormulaRow).ToList();
    }

    public async Task<FormulaExpression?> GetByCodeAsync(string formulaCode)
    {
        await using var conn = new SqlConnection(_connectionString);
        var row = await conn.QuerySingleOrDefaultAsync<FormulaExpressionDbRow>(@"
SELECT
    f.formula_id         AS FormulaId,
    f.formula_code       AS FormulaCode,
    f.formula_name       AS FormulaName,
    f.formula_step       AS FormulaStep,
    f.channel_id         AS ChannelId,
    c.channel_code       AS ChannelCode,
    f.position_level_id  AS PositionLevelId,
    pl.position_code     AS PositionCode,
    f.ws_type            AS WsType,
    f.formula_expr       AS FormulaExpr,
    f.variables_json     AS VariablesJson,
    f.description        AS Description,
    f.sort_order         AS SortOrder,
    f.effective_from     AS EffectiveFrom,
    f.effective_to       AS EffectiveTo,
    f.is_active          AS IsActive
FROM dbo.mst_formula_expression f
LEFT JOIN dbo.mst_channel        c  ON c.channel_id         = f.channel_id
LEFT JOIN dbo.mst_position_level pl ON pl.position_level_id = f.position_level_id
WHERE f.formula_code = @FormulaCode;",
            new { FormulaCode = formulaCode });

        return row is null ? null : MapFormulaRow(row);
    }

    private static FormulaExpression MapFormulaRow(FormulaExpressionDbRow row)
    {
        return new FormulaExpression
        {
            FormulaId = row.FormulaId,
            FormulaCode = row.FormulaCode,
            FormulaName = row.FormulaName,
            FormulaStep = row.FormulaStep,
            ChannelId = row.ChannelId,
            ChannelCode = row.ChannelCode,
            PositionLevelId = row.PositionLevelId,
            PositionCode = row.PositionCode,
            WsType = row.WsType,
            FormulaExpr = row.FormulaExpr,
            VariablesJson = row.VariablesJson,
            Description = row.Description,
            SortOrder = row.SortOrder,
            EffectiveFrom = DateOnly.FromDateTime(row.EffectiveFrom),
            EffectiveTo = row.EffectiveTo.HasValue ? DateOnly.FromDateTime(row.EffectiveTo.Value) : null,
            IsActive = row.IsActive
        };
    }

    // Regex-based normalization: converts any casing of known function names
    // to the exact casing NCalc v6 built-in dictionary expects (Pascal case).
    // IIF is not a built-in; it is mapped to NCalc's built-in 'if' function.
    private static readonly (Regex Re, string To)[] _fnNorm =
    [
        (new Regex(@"\bROUND\b",    RegexOptions.IgnoreCase | RegexOptions.Compiled), "Round"),
        (new Regex(@"\bABS\b",      RegexOptions.IgnoreCase | RegexOptions.Compiled), "Abs"),
        (new Regex(@"\bMAX\b",      RegexOptions.IgnoreCase | RegexOptions.Compiled), "Max"),
        (new Regex(@"\bMIN\b",      RegexOptions.IgnoreCase | RegexOptions.Compiled), "Min"),
        (new Regex(@"\bCEILING\b",  RegexOptions.IgnoreCase | RegexOptions.Compiled), "Ceiling"),
        (new Regex(@"\bFLOOR\b",    RegexOptions.IgnoreCase | RegexOptions.Compiled), "Floor"),
        (new Regex(@"\bSQRT\b",     RegexOptions.IgnoreCase | RegexOptions.Compiled), "Sqrt"),
        (new Regex(@"\bIIF\b",      RegexOptions.IgnoreCase | RegexOptions.Compiled), "if"),
    ];

    private static string NormalizeFormula(string formulaExpr)
    {
        foreach (var (re, to) in _fnNorm)
            formulaExpr = re.Replace(formulaExpr, to);
        return formulaExpr;
    }

    public FormulaEvalResult Evaluate(string formulaExpr, Dictionary<string, decimal> variables,
                                      string formulaCode = "")
    {
        try
        {
            // Normalize function names to NCalc-expected casing before parsing
            var expr = new Expression(NormalizeFormula(formulaExpr), ExpressionOptions.DecimalAsDefault);

            foreach (var (key, val) in variables)
            {
                // Strip [ ] brackets so NCalc v6 can match the parameter key
                var paramKey = key.TrimStart('[').TrimEnd(']');
                expr.Parameters[paramKey] = val;
            }

            var raw = expr.Evaluate();
            var result = Convert.ToDecimal(raw);

            return new FormulaEvalResult
            {
                Success     = true,
                Value       = result,
                FormulaCode = formulaCode,
                FormulaExpr = formulaExpr,
                Variables   = variables
            };
        }
        catch (Exception ex)
        {
            return new FormulaEvalResult
            {
                Success      = false,
                Value        = 0m,
                ErrorMessage = ex.Message,
                FormulaCode  = formulaCode,
                FormulaExpr  = formulaExpr,
                Variables    = variables
            };
        }
    }

    public async Task<FormulaEvalResult> EvaluateByCodeAsync(string formulaCode,
                                                             Dictionary<string, decimal> variables)
    {
        var formula = await GetByCodeAsync(formulaCode);
        if (formula is null)
        {
            return new FormulaEvalResult
            {
                Success      = false,
                Value        = 0m,
                ErrorMessage = $"Formula code '{formulaCode}' not found in database.",
                FormulaCode  = formulaCode,
                FormulaExpr  = string.Empty,
                Variables    = variables
            };
        }
        return Evaluate(formula.FormulaExpr, variables, formulaCode);
    }

    public (bool IsValid, string? ErrorMessage) Validate(string formulaExpr)
    {
        if (string.IsNullOrWhiteSpace(formulaExpr))
            return (false, "Formula expression must not be empty.");
        try
        {
            // Dry-run: normalize function names then parse with dummy variable values
            var expr = new Expression(NormalizeFormula(formulaExpr), ExpressionOptions.DecimalAsDefault);
            expr.EvaluateParameter += (name, args) => { args.Result = 1m; };
            expr.Evaluate();
            return (true, null);
        }
        catch (Exception ex)
        {
            return (false, ex.Message);
        }
    }

    public async Task<int> SaveAsync(FormulaExpression formula)
    {
        await using var conn = new SqlConnection(_connectionString);
        if (formula.FormulaId == 0)
        {
            return await conn.ExecuteAsync(@"
INSERT INTO dbo.mst_formula_expression
    (formula_code, formula_name, formula_step, channel_id, position_level_id,
     ws_type, formula_expr, variables_json, description, sort_order,
     effective_from, effective_to, is_active)
VALUES
    (@FormulaCode, @FormulaName, @FormulaStep, @ChannelId, @PositionLevelId,
     @WsType, @FormulaExpr, @VariablesJson, @Description, @SortOrder,
     @EffectiveFrom, @EffectiveTo, @IsActive);", formula);
        }
        return await conn.ExecuteAsync(@"
UPDATE dbo.mst_formula_expression SET
    formula_code       = @FormulaCode,
    formula_name       = @FormulaName,
    formula_step       = @FormulaStep,
    channel_id         = @ChannelId,
    position_level_id  = @PositionLevelId,
    ws_type            = @WsType,
    formula_expr       = @FormulaExpr,
    variables_json     = @VariablesJson,
    description        = @Description,
    sort_order         = @SortOrder,
    effective_from     = @EffectiveFrom,
    effective_to       = @EffectiveTo,
    is_active          = @IsActive,
    updated_at         = SYSUTCDATETIME()
WHERE formula_id = @FormulaId;", formula);
    }

    public async Task<int> DeleteAsync(int formulaId)
    {
        await using var conn = new SqlConnection(_connectionString);
        return await conn.ExecuteAsync(
            "DELETE FROM dbo.mst_formula_expression WHERE formula_id = @FormulaId;",
            new { FormulaId = formulaId });
    }
}

internal sealed class FormulaExpressionDbRow
{
    public int FormulaId { get; init; }
    public string FormulaCode { get; init; } = string.Empty;
    public string FormulaName { get; init; } = string.Empty;
    public string FormulaStep { get; init; } = string.Empty;
    public int? ChannelId { get; init; }
    public string? ChannelCode { get; init; }
    public int? PositionLevelId { get; init; }
    public string? PositionCode { get; init; }
    public string? WsType { get; init; }
    public string FormulaExpr { get; init; } = string.Empty;
    public string? VariablesJson { get; init; }
    public string? Description { get; init; }
    public int SortOrder { get; init; }
    public DateTime EffectiveFrom { get; init; }
    public DateTime? EffectiveTo { get; init; }
    public bool IsActive { get; init; }
}
