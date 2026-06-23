using Dapper;
using Microsoft.Data.SqlClient;

namespace AjtIncentive.Web.Services;

public interface IPortalDataService
{
    Task<DashboardSnapshot> GetDashboardSnapshotAsync();
    Task<IReadOnlyList<PeriodItem>> GetPeriodsAsync();
    Task<IReadOnlyList<ChannelItem>> GetChannelsAsync();
    Task<IReadOnlyList<CalcRunItem>> GetRecentRunsAsync(int top = 12);
    Task<IReadOnlyList<ForHrRow>> GetForHrRowsAsync(int calcRunId, int top = 200);
    Task<IReadOnlyList<CalcRunDetailItem>> GetCalcRunDetailAsync(int calcRunId, int top = 200);
    Task<IReadOnlyList<FormulaExpression>> GetFormulasByChannelAsync(string channelCode);
    Task<IReadOnlyList<CalcRunHistoryItem>> GetCalcRunHistoryAsync(int channelId, int top = 10);
    Task<IReadOnlyList<FormulaPreviewRow>> GetFormulaPreviewAsync(int periodId, string channelCode);
    Task<int?> GetLatestCalcRunIdAsync(int channelId);
    Task<int?> GetLatestCalcRunIdByPeriodAsync(int channelId, int periodId);
    Task<IReadOnlyList<string>> GetTtWsTypesAsync();
    Task<IReadOnlyDictionary<int, PeriodReadiness>> GetPeriodReadinessAsync(int channelId);
    Task<IReadOnlyList<DashboardChannelSummary>> GetDashboardChannelSummariesAsync();
}

public sealed class PortalDataService : IPortalDataService
{
    private readonly string _connectionString;

    public PortalDataService(string connectionString)
    {
        _connectionString = connectionString;
    }

    public async Task<DashboardSnapshot> GetDashboardSnapshotAsync()
    {
        await using var conn = new SqlConnection(_connectionString);

        var sql = @"
SELECT
  (SELECT COUNT(*) FROM dbo.mst_period) AS PeriodCount,
  (SELECT COUNT(*) FROM dbo.mst_channel WHERE is_active = 1) AS ActiveChannelCount,
  (SELECT COUNT(*) FROM dbo.mst_employee WHERE is_active = 1) AS ActiveEmployeeCount,
  (SELECT COUNT(*) FROM dbo.trn_calc_run) AS CalcRunCount,
  (SELECT TOP (1) calc_run_id FROM dbo.trn_calc_run WHERE channel_id = 1 ORDER BY calc_run_id DESC) AS LatestMtRunId,
  (SELECT TOP (1) calc_run_id FROM dbo.trn_calc_run WHERE channel_id = 2 ORDER BY calc_run_id DESC) AS LatestTtRunId,
  (SELECT CASE WHEN OBJECT_ID(N'dbo.usp_run_mt_incentive_calculation', N'P') IS NULL THEN 0 ELSE 1 END) AS HasMtSp,
  (SELECT CASE WHEN OBJECT_ID(N'dbo.usp_run_tt_incentive_calculation', N'P') IS NULL THEN 0 ELSE 1 END) AS HasTtSp,
  (SELECT CASE WHEN OBJECT_ID(N'dbo.usp_run_si_incentive_calculation', N'P') IS NULL THEN 0 ELSE 1 END) AS HasSiSp,
  (SELECT CASE WHEN OBJECT_ID(N'dbo.usp_run_laos_incentive_calculation', N'P') IS NULL THEN 0 ELSE 1 END) AS HasLaosSp,
  (SELECT CASE WHEN EXISTS (
      SELECT 1
      FROM sys.columns
      WHERE object_id = OBJECT_ID(N'dbo.mst_employee')
        AND name = N'start_date'
  ) THEN 1 ELSE 0 END) AS HasStartDate,
  (SELECT CASE WHEN OBJECT_ID(N'dbo.incentive_adjustments', N'U') IS NULL THEN 0 ELSE 1 END) AS HasAdjustmentTable;
";

        var row = await conn.QuerySingleAsync<DashboardSnapshotRow>(sql);

        return new DashboardSnapshot
        {
            PeriodCount = row.PeriodCount,
            ActiveChannelCount = row.ActiveChannelCount,
            ActiveEmployeeCount = row.ActiveEmployeeCount,
            CalcRunCount = row.CalcRunCount,
            LatestMtRunId = row.LatestMtRunId,
            LatestTtRunId = row.LatestTtRunId,
            HasMtSp = row.HasMtSp == 1,
            HasTtSp = row.HasTtSp == 1,
            HasSiSp = row.HasSiSp == 1,
            HasLaosSp = row.HasLaosSp == 1,
            HasStartDate = row.HasStartDate == 1,
            HasAdjustmentTable = row.HasAdjustmentTable == 1
        };
    }

    public async Task<IReadOnlyList<PeriodItem>> GetPeriodsAsync()
    {
        await using var conn = new SqlConnection(_connectionString);
        var sql = @"
SELECT period_id AS PeriodId,
       period_code AS PeriodCode,
       sales_month AS SalesMonth
FROM dbo.mst_period
ORDER BY period_id;";

        var rows = await conn.QueryAsync<PeriodItem>(sql);
        return rows.ToList();
    }

    public async Task<IReadOnlyList<ChannelItem>> GetChannelsAsync()
    {
        await using var conn = new SqlConnection(_connectionString);
        var sql = @"
SELECT channel_id AS ChannelId,
       channel_code AS ChannelCode,
       channel_name_en AS ChannelNameEn,
       calc_type AS CalcType,
       is_active AS IsActive
FROM dbo.mst_channel
ORDER BY channel_id;";

        var rows = await conn.QueryAsync<ChannelItem>(sql);
        return rows.ToList();
    }

    public async Task<IReadOnlyList<CalcRunItem>> GetRecentRunsAsync(int top = 12)
    {
        await using var conn = new SqlConnection(_connectionString);
        var sql = @"
SELECT TOP (@Top)
       r.calc_run_id AS CalcRunId,
       r.channel_id AS ChannelId,
       c.channel_code AS ChannelCode,
       p.period_code AS PeriodCode,
       r.run_status AS RunStatus,
       r.approved_by AS ApprovedBy,
       r.updated_at AS UpdatedAt
FROM dbo.trn_calc_run r
LEFT JOIN dbo.mst_channel c ON c.channel_id = r.channel_id
LEFT JOIN dbo.mst_period p ON p.period_id = r.period_id
ORDER BY r.calc_run_id DESC;";

        var rows = await conn.QueryAsync<CalcRunItem>(sql, new { Top = top });
        return rows.ToList();
    }

    public async Task<IReadOnlyList<ForHrRow>> GetForHrRowsAsync(int calcRunId, int top = 200)
    {
        await using var conn = new SqlConnection(_connectionString);

        var sql = @"
SELECT TOP (@Top)
       h.calc_run_id AS CalcRunId,
       h.employee_code AS EmployeeCode,
       h.position_level_code AS PositionLevelCode,
       h.total_variable AS TotalVariable
FROM dbo.out_for_hr_variable h
WHERE h.calc_run_id = @CalcRunId
ORDER BY h.employee_code;";

        var rows = await conn.QueryAsync<ForHrRow>(sql, new { CalcRunId = calcRunId, Top = top });
        return rows.ToList();
    }

    public async Task<IReadOnlyList<CalcRunDetailItem>> GetCalcRunDetailAsync(int calcRunId, int top = 200)
    {
        await using var conn = new SqlConnection(_connectionString);

        var sql = @"
SELECT TOP (@Top)
       r.calc_run_id AS CalcRunId,
       c.channel_code AS ChannelCode,
       p.period_code AS PeriodCode,
       r.run_status AS RunStatus,
       r.updated_at AS UpdatedAt,
       h.employee_code AS EmployeeCode,
       h.position_level_code AS PositionLevelCode,
       h.total_variable AS TotalVariable
FROM dbo.out_for_hr_variable h
INNER JOIN dbo.trn_calc_run r ON r.calc_run_id = h.calc_run_id
LEFT JOIN dbo.mst_channel c ON c.channel_id = r.channel_id
LEFT JOIN dbo.mst_period p ON p.period_id = r.period_id
WHERE h.calc_run_id = @CalcRunId
ORDER BY h.employee_code;";

        var rows = await conn.QueryAsync<CalcRunDetailItem>(sql, new { CalcRunId = calcRunId, Top = top });
        return rows.ToList();
    }

    public async Task<IReadOnlyList<FormulaExpression>> GetFormulasByChannelAsync(string channelCode)
    {
        await using var conn = new SqlConnection(_connectionString);

        var sql = @"
SELECT formula_id AS FormulaId,
       formula_code AS FormulaCode,
       formula_name AS FormulaName,
       formula_step AS FormulaStep,
       channel_id AS ChannelId,
       channel_code AS ChannelCode,
       position_level_id AS PositionLevelId,
       position_code AS PositionCode,
       ws_type AS WsType,
       formula_expr AS FormulaExpr,
       variables_json AS VariablesJson,
       description AS Description,
       sort_order AS SortOrder,
       effective_from AS EffectiveFrom,
         effective_to AS EffectiveTo
FROM dbo.vw_formula_expression_active
WHERE channel_code = @ChannelCode
   OR channel_code = N'SHARED'
ORDER BY
    CASE formula_step
        WHEN N'PCT_ACHIEVEMENT' THEN 1
        WHEN N'INCENTIVE_PER_PRODUCT' THEN 2
        WHEN N'SPECIAL_KPI' THEN 3
        WHEN N'ROLLUP' THEN 4
        ELSE 99
    END,
    sort_order,
    formula_code;";

        var rows = await conn.QueryAsync<FormulaExpressionRow>(sql, new { ChannelCode = channelCode });
        return rows.Select(MapFormulaExpression).ToList();
    }

    private static FormulaExpression MapFormulaExpression(FormulaExpressionRow row)
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
            IsActive = true
        };
    }

    public async Task<IReadOnlyList<CalcRunHistoryItem>> GetCalcRunHistoryAsync(int channelId, int top = 10)
    {
        await using var conn = new SqlConnection(_connectionString);

        var sql = @"
SELECT TOP (@Top)
       r.calc_run_id AS CalcRunId,
       r.channel_id AS ChannelId,
       c.channel_code AS ChannelCode,
       p.period_code AS PeriodCode,
       r.run_status AS RunStatus,
       r.approved_by AS ApprovedBy,
       r.updated_at AS UpdatedAt,
       ISNULL(hr.for_hr_row_count, 0) AS ForHrRowCount
FROM dbo.trn_calc_run r
LEFT JOIN dbo.mst_channel c ON c.channel_id = r.channel_id
LEFT JOIN dbo.mst_period p ON p.period_id = r.period_id
OUTER APPLY (
    SELECT COUNT(*) AS for_hr_row_count
    FROM dbo.out_for_hr_variable h
    WHERE h.calc_run_id = r.calc_run_id
) hr
WHERE r.channel_id = @ChannelId
ORDER BY r.calc_run_id DESC;";

        var rows = await conn.QueryAsync<CalcRunHistoryItem>(sql, new { ChannelId = channelId, Top = top });
        return rows.ToList();
    }

    public async Task<IReadOnlyList<FormulaPreviewRow>> GetFormulaPreviewAsync(int periodId, string channelCode)
    {
        await using var conn = new SqlConnection(_connectionString);

        var sql = @"
EXEC dbo.usp_formula_expression_preview
    @PeriodId = @PeriodId,
    @ChannelCode = @ChannelCode;";

        var rows = await conn.QueryAsync<FormulaPreviewRowRaw>(sql, new { PeriodId = periodId, ChannelCode = channelCode });
        return rows.Select(MapFormulaPreviewRow).ToList();
    }

    private static FormulaPreviewRow MapFormulaPreviewRow(FormulaPreviewRowRaw r) => new()
    {
        ChannelCode       = r.channel_code,
        SalesmanCode      = r.salesman_code,
        PositionCode      = r.position_code,
        WsType            = r.ws_type_salesman,
        ProductCode       = r.product_code,
        TargetAmount      = r.target_amount,
        ActualAmount      = r.actual_amount,
        PctAchievement    = r.pct_achievement,
        GoalMult          = r.goal_mult,
        BaseRate          = r.base_rate,
        WeightPct         = r.weight_pct,
        FormulaCodePct    = r.formula_code_pct,
        FormulaExprPct    = r.formula_expr_pct,
        FormulaCodeIncent = r.formula_code_incent,
        FormulaExprIncent = r.formula_expr_incent,
        IncentiveAmount   = r.incentive_amount
    };

    public async Task<int?> GetLatestCalcRunIdAsync(int channelId)
    {
        await using var conn = new SqlConnection(_connectionString);
        var sql = @"
SELECT TOP (1) calc_run_id
FROM dbo.trn_calc_run
WHERE channel_id = @ChannelId
ORDER BY calc_run_id DESC;";

        return await conn.ExecuteScalarAsync<int?>(sql, new { ChannelId = channelId });
    }

    public async Task<int?> GetLatestCalcRunIdByPeriodAsync(int channelId, int periodId)
    {
        await using var conn = new SqlConnection(_connectionString);
        var sql = @"
SELECT TOP (1) calc_run_id
FROM dbo.trn_calc_run
WHERE channel_id = @ChannelId
  AND period_id = @PeriodId
ORDER BY calc_run_id DESC;";

        return await conn.ExecuteScalarAsync<int?>(sql, new { ChannelId = channelId, PeriodId = periodId });
    }

    public async Task<IReadOnlyList<string>> GetTtWsTypesAsync()
    {
        await using var conn = new SqlConnection(_connectionString);
        var sql = "SELECT DISTINCT ws_type FROM dbo.vw_tt_salesman_ws_type WHERE ws_type IS NOT NULL ORDER BY ws_type;";
        var rows = await conn.QueryAsync<string>(sql);
        return rows.ToList();
    }

    public async Task<IReadOnlyDictionary<int, PeriodReadiness>> GetPeriodReadinessAsync(int channelId)
    {
        await using var conn = new SqlConnection(_connectionString);
        var sql = @"
SELECT p.period_id AS PeriodId,
       (SELECT COUNT(*)
        FROM dbo.trn_sales_target t
        WHERE t.channel_id = @ChannelId
          AND t.period_id = p.period_id) AS TargetRows,
       (SELECT COUNT(*)
        FROM dbo.trn_sales_actual a
        WHERE a.channel_id = @ChannelId
          AND a.period_id = p.period_id) AS ActualRows
FROM dbo.mst_period p
ORDER BY p.period_id;";

        var rows = await conn.QueryAsync<PeriodReadiness>(sql, new { ChannelId = channelId });
        return rows.ToDictionary(row => row.PeriodId);
    }

    public async Task<IReadOnlyList<DashboardChannelSummary>> GetDashboardChannelSummariesAsync()
    {
        await using var conn = new SqlConnection(_connectionString);
        var sql = @"
WITH period_stats AS (
    SELECT c.channel_id,
           p.period_id,
           p.period_code,
           SUM(CASE WHEN src.src_type = 'TARGET' THEN src.row_count ELSE 0 END) AS target_rows,
           SUM(CASE WHEN src.src_type = 'ACTUAL' THEN src.row_count ELSE 0 END) AS actual_rows
    FROM dbo.mst_channel c
    CROSS JOIN dbo.mst_period p
    LEFT JOIN (
        SELECT channel_id, period_id, COUNT(*) AS row_count, 'TARGET' AS src_type
        FROM dbo.trn_sales_target
        GROUP BY channel_id, period_id
        UNION ALL
        SELECT channel_id, period_id, COUNT(*) AS row_count, 'ACTUAL' AS src_type
        FROM dbo.trn_sales_actual
        GROUP BY channel_id, period_id
    ) src ON src.channel_id = c.channel_id AND src.period_id = p.period_id
    WHERE c.channel_id IN (1, 2, 3, 4)
    GROUP BY c.channel_id, p.period_id, p.period_code
),
latest_ready AS (
    SELECT ps.channel_id,
           ps.period_id,
           ps.period_code,
           ps.target_rows,
           ps.actual_rows,
           ROW_NUMBER() OVER (PARTITION BY ps.channel_id ORDER BY ps.period_id DESC) AS rn
    FROM period_stats ps
    WHERE ps.target_rows > 0 AND ps.actual_rows > 0
),
ready_counts AS (
    SELECT channel_id,
           COUNT(*) AS ready_period_count
    FROM period_stats
    WHERE target_rows > 0 AND actual_rows > 0
    GROUP BY channel_id
),
latest_runs AS (
    SELECT r.channel_id,
           r.calc_run_id,
           r.run_status,
           r.updated_at,
           p.period_code,
           ROW_NUMBER() OVER (PARTITION BY r.channel_id ORDER BY r.calc_run_id DESC) AS rn
    FROM dbo.trn_calc_run r
    LEFT JOIN dbo.mst_period p ON p.period_id = r.period_id
    WHERE r.channel_id IN (1, 2, 3, 4)
),
for_hr_rows AS (
    SELECT calc_run_id, COUNT(*) AS for_hr_row_count
    FROM dbo.out_for_hr_variable
    GROUP BY calc_run_id
)
SELECT c.channel_id AS ChannelId,
       c.channel_code AS ChannelCode,
       c.channel_name_en AS ChannelNameEn,
       c.calc_type AS CalcType,
       CASE
           WHEN c.channel_code = 'MT'   THEN CASE WHEN OBJECT_ID(N'dbo.usp_run_mt_incentive_calculation', N'P') IS NULL THEN CAST(0 AS bit) ELSE CAST(1 AS bit) END
           WHEN c.channel_code = 'TT'   THEN CASE WHEN OBJECT_ID(N'dbo.usp_run_tt_incentive_calculation', N'P') IS NULL THEN CAST(0 AS bit) ELSE CAST(1 AS bit) END
           WHEN c.channel_code = 'SI'   THEN CASE WHEN OBJECT_ID(N'dbo.usp_run_si_incentive_calculation', N'P') IS NULL THEN CAST(0 AS bit) ELSE CAST(1 AS bit) END
           WHEN c.channel_code = 'LAOS' THEN CASE WHEN OBJECT_ID(N'dbo.usp_run_laos_incentive_calculation', N'P') IS NULL THEN CAST(0 AS bit) ELSE CAST(1 AS bit) END
           ELSE CAST(0 AS bit)
       END AS HasProcedure,
       ISNULL(rc.ready_period_count, 0) AS ReadyPeriodCount,
       lr.period_id AS LatestReadyPeriodId,
       lr.period_code AS LatestReadyPeriodCode,
       ISNULL(lr.target_rows, 0) AS LatestReadyTargetRows,
       ISNULL(lr.actual_rows, 0) AS LatestReadyActualRows,
       run.calc_run_id AS LatestCalcRunId,
       run.period_code AS LatestRunPeriodCode,
       run.run_status AS LatestRunStatus,
       run.updated_at AS LatestRunUpdatedAt,
       ISNULL(hr.for_hr_row_count, 0) AS LatestForHrRowCount
FROM dbo.mst_channel c
LEFT JOIN ready_counts rc ON rc.channel_id = c.channel_id
LEFT JOIN latest_ready lr ON lr.channel_id = c.channel_id AND lr.rn = 1
LEFT JOIN latest_runs run ON run.channel_id = c.channel_id AND run.rn = 1
LEFT JOIN for_hr_rows hr ON hr.calc_run_id = run.calc_run_id
WHERE c.channel_id IN (1, 2, 3, 4)
ORDER BY c.channel_id;";

        var rows = await conn.QueryAsync<DashboardChannelSummary>(sql);
        return rows.ToList();
    }

    private sealed class DashboardSnapshotRow
    {
        public int PeriodCount { get; init; }
        public int ActiveChannelCount { get; init; }
        public int ActiveEmployeeCount { get; init; }
        public int CalcRunCount { get; init; }
        public int? LatestMtRunId { get; init; }
        public int? LatestTtRunId { get; init; }
        public int HasMtSp { get; init; }
        public int HasTtSp { get; init; }
        public int HasSiSp { get; init; }
        public int HasLaosSp { get; init; }
        public int HasStartDate { get; init; }
        public int HasAdjustmentTable { get; init; }
    }
}

public sealed class DashboardSnapshot
{
    public int PeriodCount { get; init; }
    public int ActiveChannelCount { get; init; }
    public int ActiveEmployeeCount { get; init; }
    public int CalcRunCount { get; init; }
    public int? LatestMtRunId { get; init; }
    public int? LatestTtRunId { get; init; }
    public bool HasMtSp { get; init; }
    public bool HasTtSp { get; init; }
    public bool HasSiSp { get; init; }
    public bool HasLaosSp { get; init; }
    public bool HasStartDate { get; init; }
    public bool HasAdjustmentTable { get; init; }
}

public sealed class PeriodItem
{
    public int PeriodId { get; init; }
    public string PeriodCode { get; init; } = string.Empty;
    public DateTime SalesMonth { get; init; }
}

public sealed class PeriodReadiness
{
    public int PeriodId { get; init; }
    public int TargetRows { get; init; }
    public int ActualRows { get; init; }
    public bool IsReady => TargetRows > 0 && ActualRows > 0;
    public bool HasTarget => TargetRows > 0;
}

public sealed class ChannelItem
{
    public int ChannelId { get; init; }
    public string ChannelCode { get; init; } = string.Empty;
    public string ChannelNameEn { get; init; } = string.Empty;
    public string CalcType { get; init; } = string.Empty;
    public bool IsActive { get; init; }
}

public sealed class CalcRunItem
{
    public int CalcRunId { get; init; }
    public int ChannelId { get; init; }
    public string ChannelCode { get; init; } = string.Empty;
    public string PeriodCode { get; init; } = string.Empty;
    public string RunStatus { get; init; } = string.Empty;
    public string ApprovedBy { get; init; } = string.Empty;
    public DateTime? UpdatedAt { get; init; }
}

public sealed class ForHrRow
{
    public int CalcRunId { get; init; }
    public string EmployeeCode { get; init; } = string.Empty;
    public string PositionLevelCode { get; init; } = string.Empty;
    public decimal TotalVariable { get; init; }
}

public sealed class CalcRunDetailItem
{
    public int CalcRunId { get; init; }
    public string ChannelCode { get; init; } = string.Empty;
    public string PeriodCode { get; init; } = string.Empty;
    public string RunStatus { get; init; } = string.Empty;
    public DateTime? UpdatedAt { get; init; }
    public string EmployeeCode { get; init; } = string.Empty;
    public string PositionLevelCode { get; init; } = string.Empty;
    public decimal TotalVariable { get; init; }
}

public sealed class CalcRunHistoryItem
{
    public int CalcRunId { get; init; }
    public int ChannelId { get; init; }
    public string ChannelCode { get; init; } = string.Empty;
    public string PeriodCode { get; init; } = string.Empty;
    public string RunStatus { get; init; } = string.Empty;
    public string? ApprovedBy { get; init; }
    public DateTime? UpdatedAt { get; init; }
    public int ForHrRowCount { get; init; }
}

public sealed class FormulaPreviewRow
{
    public int CalcRunId { get; init; }
    public string ChannelCode { get; init; } = string.Empty;
    public string SalesmanCode { get; init; } = string.Empty;
    public string PositionCode { get; init; } = string.Empty;
    public string? WsType { get; init; }
    public string ProductCode { get; init; } = string.Empty;
    public decimal TargetAmount { get; init; }
    public decimal ActualAmount { get; init; }
    public decimal PctAchievement { get; init; }
    public decimal GoalMult { get; init; }
    public decimal BaseRate { get; init; }
    public decimal WeightPct { get; init; }
    public string? FormulaCodePct { get; init; }
    public string? FormulaExprPct { get; init; }
    public string? FormulaCodeIncent { get; init; }
    public string? FormulaExprIncent { get; init; }
    public decimal IncentiveAmount { get; init; }
}

internal sealed class FormulaPreviewRowRaw
{
    public string channel_code       { get; init; } = string.Empty;
    public string salesman_code      { get; init; } = string.Empty;
    public string position_code      { get; init; } = string.Empty;
    public string? ws_type_salesman  { get; init; }
    public string product_code       { get; init; } = string.Empty;
    public decimal target_amount     { get; init; }
    public decimal actual_amount     { get; init; }
    public decimal pct_achievement   { get; init; }
    public decimal goal_mult         { get; init; }
    public decimal base_rate         { get; init; }
    public decimal weight_pct        { get; init; }
    public string? formula_code_pct  { get; init; }
    public string? formula_expr_pct  { get; init; }
    public string? formula_code_incent { get; init; }
    public string? formula_expr_incent { get; init; }
    public decimal incentive_amount  { get; init; }
}

internal sealed class FormulaExpressionRow
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
}

public sealed class DashboardChannelSummary
{
    public int ChannelId { get; init; }
    public string ChannelCode { get; init; } = string.Empty;
    public string ChannelNameEn { get; init; } = string.Empty;
    public string CalcType { get; init; } = string.Empty;
    public bool HasProcedure { get; init; }
    public int ReadyPeriodCount { get; init; }
    public int? LatestReadyPeriodId { get; init; }
    public string LatestReadyPeriodCode { get; init; } = string.Empty;
    public int LatestReadyTargetRows { get; init; }
    public int LatestReadyActualRows { get; init; }
    public int? LatestCalcRunId { get; init; }
    public string LatestRunPeriodCode { get; init; } = string.Empty;
    public string LatestRunStatus { get; init; } = string.Empty;
    public DateTime? LatestRunUpdatedAt { get; init; }
    public int LatestForHrRowCount { get; init; }
}
