using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;
using AjtIncentive.Application.Interfaces;
using AjtIncentive.Domain.Entities;

namespace AjtIncentive.Infrastructure.StoredProcedures;

public class MtCalculationRunner : ICalculationService
{
    private readonly string _connectionString;

    public MtCalculationRunner(string connectionString)
    {
        _connectionString = connectionString;
    }

    public async Task<int> RunMtCalculationAsync(int periodId)
    {
        return await RunPeriodBasedCalculationAsync(
            procName: "usp_run_mt_incentive_calculation",
            periodId: periodId,
            channelId: 1,
            channelName: "MT");
    }

    public async Task<int> RunSiCalculationAsync(int periodId)
    {
        return await RunPeriodBasedCalculationAsync(
            procName: "usp_run_si_incentive_calculation",
            periodId: periodId,
            channelId: 3,
            channelName: "S&I");
    }

    public async Task<int> RunLaosCalculationAsync(int periodId)
    {
        return await RunPeriodBasedCalculationAsync(
            procName: "usp_run_laos_incentive_calculation",
            periodId: periodId,
            channelId: 4,
            channelName: "LAOS");
    }

    public async Task<int> RunTtCalculationAsync(string periodCode, string wsType)
    {
        await using var conn = new SqlConnection(_connectionString);
        var exists = await conn.ExecuteScalarAsync<int>(
            "SELECT CASE WHEN OBJECT_ID(N'dbo.usp_run_tt_incentive_calculation', N'P') IS NULL THEN 0 ELSE 1 END;");

        if (exists == 0)
        {
            throw new InvalidOperationException("TT calculation is not available because SP usp_run_tt_incentive_calculation is not deployed.");
        }

        var parameters = new DynamicParameters();
        parameters.Add("@PeriodCode", periodCode, DbType.String);
        parameters.Add("@WsType", wsType, DbType.String);
        parameters.Add("@ApprovedBy", "system", DbType.String);

        await conn.ExecuteAsync(
            "usp_run_tt_incentive_calculation",
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
        {
            throw new InvalidOperationException("TT calculation finished but calc_run_id was not found.");
        }

        return calcRunId.Value;
    }

    private async Task<int> RunPeriodBasedCalculationAsync(string procName, int periodId, int channelId, string channelName)
    {
        await using var conn = new SqlConnection(_connectionString);

        var exists = await conn.ExecuteScalarAsync<int>(
            "SELECT CASE WHEN OBJECT_ID(@ProcObjectName, N'P') IS NULL THEN 0 ELSE 1 END;",
            new { ProcObjectName = $"dbo.{procName}" });

        if (exists == 0)
        {
            throw new InvalidOperationException($"{channelName} calculation is not available because SP {procName} is not deployed.");
        }

        var parameters = new DynamicParameters();
        parameters.Add("@PeriodId", periodId, DbType.Int32);
        parameters.Add("@ApprovedBy", "system", DbType.String);

        await conn.ExecuteAsync(
            procName,
            parameters,
            commandType: CommandType.StoredProcedure);

        var calcRunId = await conn.ExecuteScalarAsync<int?>(
            @"SELECT TOP (1) calc_run_id
              FROM dbo.trn_calc_run
              WHERE channel_id = @ChannelId
                AND period_id = @PeriodId
              ORDER BY calc_run_id DESC;",
            new { ChannelId = channelId, PeriodId = periodId });

        if (!calcRunId.HasValue)
        {
            throw new InvalidOperationException($"{channelName} calculation finished but calc_run_id was not found.");
        }

        return calcRunId.Value;
    }

    public async Task<IEnumerable<IncentiveResult>> GetForHrResultsAsync(int periodId, int channelId)
    {
        await using var conn = new SqlConnection(_connectionString);
        var sql = @"
                        WITH latest AS (
                                SELECT TOP (1) r.calc_run_id
                                FROM dbo.trn_calc_run r
                                WHERE r.period_id = @PeriodId
                                    AND r.channel_id = @ChannelId
                                ORDER BY r.calc_run_id DESC
                        )
                        SELECT h.calc_run_id AS CalcRunId,
                                     @PeriodId     AS PeriodId,
                                     h.employee_code AS EmployeeCode,
                                     e.full_name   AS FullName,
                                     @ChannelId    AS ChannelId,
                                     h.total_variable AS IncentiveAmount,
                                     N'CALCULATED' AS Status
                        FROM dbo.out_for_hr_variable h
                        INNER JOIN latest l ON l.calc_run_id = h.calc_run_id
                        LEFT JOIN dbo.mst_employee e ON e.employee_code = h.employee_code
                        ORDER BY h.employee_code";

        return await conn.QueryAsync<IncentiveResult>(sql, new { PeriodId = periodId, ChannelId = channelId });
    }
}
