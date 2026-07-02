using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;
using AjtIncentive.Application.Interfaces;

namespace AjtIncentive.Infrastructure.CalculationEngines;

/// <summary>
/// Engine 2: เรียก dbo.usp_run_si_incentive_calculation_via_function ซึ่ง persist ผลลัพธ์
/// จาก dbo.fn_calculate_si_incentive_detail (SQL table-valued function)
/// </summary>
public sealed class SiSqlFunctionEngine : ISiCalculationEngine
{
    private readonly string _connectionString;

    public SiSqlFunctionEngine(string connectionString)
    {
        _connectionString = connectionString;
    }

    public CalculationEngineType EngineType => CalculationEngineType.SqlFunction;

    public async Task<int> RunAsync(int periodId, string? approvedBy = null)
    {
        await using var conn = new SqlConnection(_connectionString);

        var exists = await conn.ExecuteScalarAsync<int>(
            "SELECT CASE WHEN OBJECT_ID(N'dbo.usp_run_si_incentive_calculation_via_function', N'P') IS NULL THEN 0 ELSE 1 END;");

        if (exists == 0)
            throw new InvalidOperationException("S&I calculation (SqlFunction engine) is not available because SP usp_run_si_incentive_calculation_via_function is not deployed.");

        var parameters = new DynamicParameters();
        parameters.Add("@PeriodId", periodId, DbType.Int32);
        parameters.Add("@ApprovedBy", approvedBy ?? "system", DbType.String);

        await conn.ExecuteAsync(
            "usp_run_si_incentive_calculation_via_function",
            parameters,
            commandType: CommandType.StoredProcedure);

        var calcRunId = await conn.ExecuteScalarAsync<int?>(
            @"SELECT TOP (1) calc_run_id
              FROM dbo.trn_calc_run
              WHERE channel_id = 3
                AND period_id = @PeriodId
              ORDER BY calc_run_id DESC;",
            new { PeriodId = periodId });

        if (!calcRunId.HasValue)
            throw new InvalidOperationException("S&I calculation (SqlFunction engine) finished but calc_run_id was not found.");

        return calcRunId.Value;
    }
}
