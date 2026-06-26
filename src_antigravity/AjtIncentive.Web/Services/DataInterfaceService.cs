using Dapper;
using Microsoft.Data.SqlClient;

namespace AjtIncentive.Web.Services;

// ─────────────────────────────────────────────────────────────────────────────
// Public models
// ─────────────────────────────────────────────────────────────────────────────

public record ValidationCheckResult(
    int    CheckNo,
    string CheckName,
    string Status,      // PASS | FAIL | PENDING
    int    TotalRows,
    int    FailedRows,
    string Detail
);

public record StagingDataStatus(
    int       BiTotalCurrent,
    int       HrTotalCurrent,
    DateTime? BiLastImport,
    DateTime? HrLastImport
);

public record ValidationRunSummary(
    int?     ValidationRunId,
    string   PeriodCode,
    DateOnly SalesMonth,
    string   OverallStatus,
    string   Check1Status,
    string   Check1Detail,
    string   Check2Status,
    string   Check2Detail,
    string   Check3Status,
    string   Check3Detail,
    string   Check4Status,
    string   Check4Detail,
    int      BiTotalRows,
    int      BiValidRows,
    int      BiInvalidRows,
    int      HrTotalRows,
    int      HrValidRows,
    int      HrInvalidRows,
    int      HierarchyRowCount,
    int      MtUnmappedRowCount,
    DateTime? RunAt,
    string   RunBy
);

public record StagingErrorRow(
    int     RawRowNo,
    string  ChannelCode,
    string? BusinessKey,
    string  ErrorCode,
    string  ErrorMessage
);

public record ValidationRunHistoryItem(
    int?     ValidationRunId,
    string   OverallStatus,
    DateTime? RunAt,
    string   RunBy
);

public record ValidationGateResult(
    ValidationRunSummary?           Summary,
    StagingDataStatus?              StagingStatus,
    IReadOnlyList<ValidationCheckResult>      Checks,
    IReadOnlyList<StagingErrorRow>            BiErrors,
    IReadOnlyList<StagingErrorRow>            HrErrors,
    IReadOnlyList<StagingErrorRow>            MtMappingGaps,
    IReadOnlyList<ValidationRunHistoryItem>   RecentRuns
);

// ─────────────────────────────────────────────────────────────────────────────
// Interface
// ─────────────────────────────────────────────────────────────────────────────

public interface IDataInterfaceService
{
    /// <summary>
    /// Returns the latest validation run summary for <paramref name="periodId"/>
    /// plus live staging table counts and recent run history.
    /// Does NOT re-run validation.
    /// </summary>
    Task<ValidationGateResult> GetStatusAsync(int periodId);

    /// <summary>
    /// Executes usp_run_validation_gate, persists the result to trn_validation_run,
    /// and returns the fresh summary.
    /// </summary>
    Task<ValidationRunSummary?> RunValidationGateAsync(string periodCode, string runBy);

    /// <summary>
    /// Returns BI Sales rows with errors for the given period (read-only query).
    /// </summary>
    Task<IReadOnlyList<StagingErrorRow>> GetBiErrorsAsync(DateOnly salesMonth);

    /// <summary>
    /// Returns HR Employee rows with errors for the given period (read-only query).
    /// </summary>
    Task<IReadOnlyList<StagingErrorRow>> GetHrErrorsAsync(DateOnly salesMonth);

    /// <summary>
    /// Returns MT stg rows that cannot be mapped to a salesman_code (read-only query).
    /// </summary>
    Task<IReadOnlyList<StagingErrorRow>> GetMtMappingGapsAsync(DateOnly salesMonth);
}

// ─────────────────────────────────────────────────────────────────────────────
// Implementation
// ─────────────────────────────────────────────────────────────────────────────

public sealed class DataInterfaceService : IDataInterfaceService
{
    private readonly string _connectionString;

    public DataInterfaceService(string connectionString)
    {
        _connectionString = connectionString;
    }

    // ── GetStatusAsync ───────────────────────────────────────────────
    public async Task<ValidationGateResult> GetStatusAsync(int periodId)
    {
        try
        {
            await using var conn = new SqlConnection(_connectionString);

            using var multi = await conn.QueryMultipleAsync(
                "dbo.usp_get_validation_gate_status",
                new { PeriodId = periodId },
                commandType: System.Data.CommandType.StoredProcedure,
                commandTimeout: 60);

            var summaryRow = await multi.ReadSingleOrDefaultAsync<VgSummaryRow>();
            var stagingRow = await multi.ReadSingleOrDefaultAsync<VgStagingRow>();
            var historyRows = (await multi.ReadAsync<VgHistoryRow>()).ToList();

            var summary = summaryRow is null ? null : MapSummary(summaryRow);
            var staging = stagingRow is null
                ? null
                : new StagingDataStatus(
                    stagingRow.BiTotalCurrent,
                    stagingRow.HrTotalCurrent,
                    stagingRow.BiLastImport,
                    stagingRow.HrLastImport);

            var checks = summary is null ? BuildPendingChecks() : BuildChecks(summary);
            var recentRuns = historyRows
                .Select(r => new ValidationRunHistoryItem(r.ValidationRunId, r.OverallStatus, r.RunAt, r.RunBy))
                .ToList();

            // Error detail rows are fetched separately (caller decides whether to load them)
            return new ValidationGateResult(summary, staging, checks, [], [], [], recentRuns);
        }
        catch
        {
            // DB not reachable or table not yet created — return safe empty state
            return new ValidationGateResult(null, null, BuildPendingChecks(), [], [], [], []);
        }
    }

    // ── RunValidationGateAsync ───────────────────────────────────────
    public async Task<ValidationRunSummary?> RunValidationGateAsync(string periodCode, string runBy)
    {
        await using var conn = new SqlConnection(_connectionString);

        using var multi = await conn.QueryMultipleAsync(
            "dbo.usp_run_validation_gate",
            new { PeriodCode = periodCode, RunBy = runBy },
            commandType: System.Data.CommandType.StoredProcedure,
            commandTimeout: 120);

        var summaryRow = await multi.ReadSingleOrDefaultAsync<VgSummaryRow>();
        return summaryRow is null ? null : MapSummary(summaryRow);
    }

    // ── GetBiErrorsAsync ─────────────────────────────────────────────
    public async Task<IReadOnlyList<StagingErrorRow>> GetBiErrorsAsync(DateOnly salesMonth)
    {
        await using var conn = new SqlConnection(_connectionString);

        var salesMonthDate = salesMonth.ToDateTime(TimeOnly.MinValue);
        var sql = @"
SELECT TOP 200
    COALESCE(s.raw_row_no, 0)     AS RawRowNo,
    s.channel_code                AS ChannelCode,
    s.bi_sales_code               AS BusinessKey,
    CASE
        WHEN s.status = N'ERROR'       THEN N'IMPORT_ERROR'
        WHEN s.actual_amount IS NULL   THEN N'MISSING_AMOUNT'
        ELSE N'UNKNOWN'
    END                           AS ErrorCode,
    COALESCE(s.error_message,
        CASE
            WHEN s.actual_amount IS NULL THEN N'actual_amount is NULL'
            ELSE N'Import error'
        END)                      AS ErrorMessage
FROM dbo.stg_bi_sales s
WHERE s.data_month = @SalesMonth
  AND (s.status = N'ERROR' OR s.actual_amount IS NULL)
ORDER BY s.raw_row_no;";

        var rows = await conn.QueryAsync<VgErrorRow>(sql, new { SalesMonth = salesMonthDate });
        return rows.Select(MapError).ToList();
    }

    // ── GetHrErrorsAsync ─────────────────────────────────────────────
    public async Task<IReadOnlyList<StagingErrorRow>> GetHrErrorsAsync(DateOnly salesMonth)
    {
        await using var conn = new SqlConnection(_connectionString);

        var salesMonthDate = salesMonth.ToDateTime(TimeOnly.MinValue);
        var sql = @"
SELECT TOP 200
    COALESCE(h.raw_row_no, 0)     AS RawRowNo,
    h.channel_code                AS ChannelCode,
    h.employee_code               AS BusinessKey,
    CASE
        WHEN h.status = N'ERROR'                               THEN N'IMPORT_ERROR'
        WHEN ISNULL(LTRIM(RTRIM(h.employee_code)), N'') = N'' THEN N'MISSING_EMPLOYEE_CODE'
        ELSE N'UNKNOWN'
    END                           AS ErrorCode,
    COALESCE(h.error_message,
        CASE
            WHEN ISNULL(LTRIM(RTRIM(h.employee_code)), N'') = N''
                THEN N'employee_code is empty'
            ELSE N'Import error'
        END)                      AS ErrorMessage
FROM dbo.stg_hcm_employee h
WHERE h.data_month = @SalesMonth
  AND (h.status = N'ERROR'
    OR ISNULL(LTRIM(RTRIM(h.employee_code)), N'') = N'')
ORDER BY h.raw_row_no;";

        var rows = await conn.QueryAsync<VgErrorRow>(sql, new { SalesMonth = salesMonthDate });
        return rows.Select(MapError).ToList();
    }

    // ── GetMtMappingGapsAsync ────────────────────────────────────────
    public async Task<IReadOnlyList<StagingErrorRow>> GetMtMappingGapsAsync(DateOnly salesMonth)
    {
        await using var conn = new SqlConnection(_connectionString);

        // Check view exists before querying
        var viewExists = await conn.ExecuteScalarAsync<int>(
            "SELECT COUNT(*) FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.vw_mst_mt_mapping_detail') AND type = N'V'");

        if (viewExists == 0)
            return Array.Empty<StagingErrorRow>();

        var salesMonthDate = salesMonth.ToDateTime(TimeOnly.MinValue);
        var sql = @"
SELECT TOP 200
    COALESCE(s.raw_row_no, 0)   AS RawRowNo,
    s.channel_code              AS ChannelCode,
    s.bi_sales_code             AS BusinessKey,
    N'MAPPING_INCOMPLETE_MT'    AS ErrorCode,
    CONCAT(N'bi_sales_code [', s.bi_sales_code,
           N'] has no active mapping in vw_mst_mt_mapping_detail')
                                AS ErrorMessage
FROM dbo.stg_bi_sales s
WHERE s.data_month   = @SalesMonth
  AND s.channel_code = N'MT'
  AND NOT EXISTS (
          SELECT 1
          FROM   dbo.vw_mst_mt_mapping_detail m
          WHERE  m.bi_sales_code    = s.bi_sales_code
            AND  m.mapping_is_active = 1
      )
ORDER BY s.raw_row_no;";

        var rows = await conn.QueryAsync<VgErrorRow>(sql, new { SalesMonth = salesMonthDate });
        return rows.Select(MapError).ToList();
    }

    // ─────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────

    private static ValidationRunSummary MapSummary(VgSummaryRow r) => new(
        r.ValidationRunId,
        r.PeriodCode,
        DateOnly.FromDateTime(r.SalesMonth),
        r.OverallStatus,
        r.Check1Status, r.Check1Detail,
        r.Check2Status, r.Check2Detail,
        r.Check3Status, r.Check3Detail,
        r.Check4Status, r.Check4Detail,
        r.BiTotalRows, r.BiValidRows, r.BiInvalidRows,
        r.HrTotalRows, r.HrValidRows, r.HrInvalidRows,
        r.HierarchyRowCount,
        r.MtUnmappedRowCount,
        r.RunAt,
        r.RunBy ?? ""
    );

    private static StagingErrorRow MapError(VgErrorRow r) =>
        new(r.RawRowNo, r.ChannelCode, r.BusinessKey, r.ErrorCode, r.ErrorMessage);

    private static IReadOnlyList<ValidationCheckResult> BuildChecks(ValidationRunSummary s) =>
    [
        new(1, "Period Alignment",
            s.Check1Status,
            s.BiTotalRows + s.HrTotalRows,
            0,
            s.Check1Detail),
        new(2, "Required Fields Completeness",
            s.Check2Status,
            s.BiTotalRows + s.HrTotalRows,
            s.BiInvalidRows + s.HrInvalidRows,
            s.Check2Detail),
        new(3, "Hierarchy Consistency",
            s.Check3Status,
            s.HierarchyRowCount,
            0,
            s.Check3Detail),
        new(4, "Mapping Completeness (MT)",
            s.Check4Status,
            0,
            s.MtUnmappedRowCount,
            s.Check4Detail),
    ];

    private static IReadOnlyList<ValidationCheckResult> BuildPendingChecks() =>
    [
        new(1, "Period Alignment",          "PENDING", 0, 0, "Run Validation Gate to check."),
        new(2, "Required Fields Completeness","PENDING", 0, 0, "Run Validation Gate to check."),
        new(3, "Hierarchy Consistency",     "PENDING", 0, 0, "Run Validation Gate to check."),
        new(4, "Mapping Completeness (MT)", "PENDING", 0, 0, "Run Validation Gate to check."),
    ];

    // ─────────────────────────────────────────────────────────────────
    // Private DTOs for Dapper (PascalCase aliases from SP column aliases)
    // ─────────────────────────────────────────────────────────────────

    private sealed class VgSummaryRow
    {
        public int?     ValidationRunId   { get; init; }
        public string   PeriodCode        { get; init; } = "";
        public DateTime SalesMonth        { get; init; }
        public string   OverallStatus     { get; init; } = "PENDING";
        public string   Check1Status      { get; init; } = "PENDING";
        public string   Check1Detail      { get; init; } = "";
        public string   Check2Status      { get; init; } = "PENDING";
        public string   Check2Detail      { get; init; } = "";
        public string   Check3Status      { get; init; } = "PENDING";
        public string   Check3Detail      { get; init; } = "";
        public string   Check4Status      { get; init; } = "PENDING";
        public string   Check4Detail      { get; init; } = "";
        public int      BiTotalRows       { get; init; }
        public int      BiValidRows       { get; init; }
        public int      BiInvalidRows     { get; init; }
        public int      HrTotalRows       { get; init; }
        public int      HrValidRows       { get; init; }
        public int      HrInvalidRows     { get; init; }
        public int      HierarchyRowCount { get; init; }
        public int      MtUnmappedRowCount{ get; init; }
        public DateTime? RunAt            { get; init; }
        public string?  RunBy             { get; init; }
    }

    private sealed class VgStagingRow
    {
        public int       BiTotalCurrent { get; init; }
        public int       HrTotalCurrent { get; init; }
        public DateTime? BiLastImport   { get; init; }
        public DateTime? HrLastImport   { get; init; }
    }

    private sealed class VgHistoryRow
    {
        public int?      ValidationRunId { get; init; }
        public string    OverallStatus   { get; init; } = "";
        public DateTime? RunAt           { get; init; }
        public string    RunBy           { get; init; } = "";
    }

    private sealed class VgErrorRow
    {
        public int     RawRowNo     { get; init; }
        public string  ChannelCode  { get; init; } = "";
        public string? BusinessKey  { get; init; }
        public string  ErrorCode    { get; init; } = "";
        public string  ErrorMessage { get; init; } = "";
    }
}
