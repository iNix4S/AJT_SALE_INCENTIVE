using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;
using AjtIncentive.Application.Interfaces;

namespace AjtIncentive.Infrastructure.CalculationEngines;

/// <summary>
/// Engine 2: เรียก dbo.usp_run_tt_incentive_calculation_via_function ซึ่ง persist ผลลัพธ์
/// จาก dbo.fn_calculate_tt_incentive_detail (SQL table-valued function) — ทดสอบแล้วว่าผลลัพธ์
/// ตรงกับ Engine 1 (Stored Procedure) 100% สำหรับ FY2026-04 (diff_count = 0)
/// </summary>
public sealed class TtSqlFunctionEngine : ITtCalculationEngine
{
    private readonly string _connectionString;

    public TtSqlFunctionEngine(string connectionString)
    {
        _connectionString = connectionString;
    }

    public CalculationEngineType EngineType => CalculationEngineType.SqlFunction;

    public async Task<int> RunAsync(string periodCode, string wsType, string? approvedBy = null)
    {
        await using var conn = new SqlConnection(_connectionString);

        var exists = await conn.ExecuteScalarAsync<int>(
            "SELECT CASE WHEN OBJECT_ID(N'dbo.usp_run_tt_incentive_calculation_via_function', N'P') IS NULL THEN 0 ELSE 1 END;");

        if (exists == 0)
            throw new InvalidOperationException("TT calculation (SqlFunction engine) is not available because SP usp_run_tt_incentive_calculation_via_function is not deployed.");

        var parameters = new DynamicParameters();
        parameters.Add("@PeriodCode", periodCode, DbType.String);
        parameters.Add("@WsType", wsType, DbType.String);
        parameters.Add("@ApprovedBy", approvedBy ?? "system", DbType.String);

        await conn.ExecuteAsync(
            "usp_run_tt_incentive_calculation_via_function",
            parameters,
            commandType: CommandType.StoredProcedure);

        var calcRunId = await conn.ExecuteScalarAsync<int?>(
            @"SELECT TOP (1) calc_run_id
              FROM dbo.trn_calc_run r
              INNER JOIN dbo.mst_period p ON p.period_id = r.period_id
              WHERE r.channel_id = 2
                AND p.period_code = @PeriodCode
              ORDER BY r.calc_run_id DESC;",
            new { PeriodCode = periodCode });

        if (!calcRunId.HasValue)
            throw new InvalidOperationException("TT calculation (SqlFunction engine) finished but calc_run_id was not found.");

        return calcRunId.Value;
    }
}
