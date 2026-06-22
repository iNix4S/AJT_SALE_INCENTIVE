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
        await using var conn = new SqlConnection(_connectionString);
        var parameters = new DynamicParameters();
        parameters.Add("@PeriodId", periodId, DbType.Int32);
        parameters.Add("@ApprovedBy", "system", DbType.String);

        await conn.ExecuteAsync(
            "usp_run_mt_incentive_calculation",
            parameters,
            commandType: CommandType.StoredProcedure);

        var calcRunId = await conn.ExecuteScalarAsync<int?>(
            @"SELECT TOP (1) calc_run_id
              FROM dbo.trn_calc_run
              WHERE channel_id = 1 AND period_id = @PeriodId
              ORDER BY calc_run_id DESC;",
            new { PeriodId = periodId });

        if (!calcRunId.HasValue)
        {
            throw new InvalidOperationException("MT calculation finished but calc_run_id was not found.");
        }

        return calcRunId.Value;
    }

    public async Task<int> RunTtCalculationAsync(int periodId)
    {
        await using var conn = new SqlConnection(_connectionString);
        var parameters = new DynamicParameters();
        parameters.Add("@PeriodId", periodId, DbType.Int32);
        parameters.Add("@CalcRunId", dbType: DbType.Int32, direction: ParameterDirection.Output);

        await conn.ExecuteAsync(
            "usp_run_tt_incentive_calculation",
            parameters,
            commandType: CommandType.StoredProcedure);

        return parameters.Get<int>("@CalcRunId");
    }

    public async Task<IEnumerable<IncentiveResult>> GetForHrResultsAsync(int periodId, int channelId)
    {
        await using var conn = new SqlConnection(_connectionString);
        var sql = @"
            SELECT r.calc_run_id AS CalcRunId,
                   r.period_id   AS PeriodId,
                   r.employee_code AS EmployeeCode,
                   e.full_name   AS FullName,
                   r.channel_id  AS ChannelId,
                   r.incentive_amount AS IncentiveAmount,
                   r.status      AS Status
            FROM   incentive_results r
            JOIN   mst_employee e ON e.employee_code = r.employee_code
            WHERE  r.period_id  = @PeriodId
              AND  r.channel_id = @ChannelId
            ORDER  BY r.employee_code";

        return await conn.QueryAsync<IncentiveResult>(sql, new { PeriodId = periodId, ChannelId = channelId });
    }
}
