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
    Task<int?> GetLatestCalcRunIdAsync(int channelId);
    Task<int?> GetLatestCalcRunIdByPeriodAsync(int channelId, int periodId);
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
      SELECT 1 FROM sys.columns
      WHERE object_id = OBJECT_ID(N'dbo.mst_employee') AND name = N'start_date'
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
