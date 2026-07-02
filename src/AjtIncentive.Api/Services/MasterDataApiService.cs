using System.Data;
using System.Text;
using System.Text.Json.Nodes;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AjtIncentive.Api.Services;

public interface IMasterDataApiService
{
    Task<IReadOnlyCollection<dynamic>> ListRowsAsync(string table, int take, CancellationToken cancellationToken);
    Task<int> InsertRowAsync(string table, JsonObject values, CancellationToken cancellationToken);
    Task<int> UpdateRowAsync(string table, long id, JsonObject values, CancellationToken cancellationToken);
    Task<int> DeactivateRowAsync(string table, long id, CancellationToken cancellationToken);
    Task<int> CreateChannelAsync(string channelCode, string channelNameTh, string channelNameEn, string calcType, CancellationToken cancellationToken);
    Task<int> CloneMasterByChannelAsync(string targetChannel, string sourceChannel, CancellationToken cancellationToken);
}

public sealed class MasterDataApiService(ConnectionStringHolder holder) : IMasterDataApiService
{
    private static readonly Dictionary<string, MasterTableDef> SupportedTables = new(StringComparer.OrdinalIgnoreCase)
    {
        ["mst_channel"] = new("mst_channel", "channel_id", ["channel_code", "channel_name_th", "channel_name_en", "calc_type", "is_active"], null),
        ["mst_product"] = new("mst_product", "product_id", ["product_code", "product_name_th", "product_name_en", "product_group_code", "product_group_name", "is_gd_product", "gd_product_code", "is_active"], null),
        ["mst_product_weight"] = new("mst_product_weight", "product_weight_id", ["channel_id", "product_id", "ws_type", "weight_percent", "effective_from", "effective_to", "is_active"], ["channel_id", "product_id", "ws_type"]),
        ["mst_incentive_rate"] = new("mst_incentive_rate", "incentive_rate_id", ["channel_id", "position_level_id", "ws_type", "rate_old", "rate_new", "effective_from", "effective_to", "is_active"], ["channel_id", "position_level_id", "ws_type"]),
        ["mst_goal_threshold"] = new("mst_goal_threshold", "goal_threshold_id", ["achievement_from", "achievement_to", "multiplier", "sequence_no", "is_active"], null),
        ["mst_shortage_policy"] = new("mst_shortage_policy", "shortage_policy_id", ["product_id", "shortage_month", "override_achievement", "reason_code", "remarks", "is_active"], null),
        ["mst_org_hierarchy"] = new("mst_org_hierarchy", "hierarchy_id", ["channel_id", "effective_month", "salesman_code", "direct_sup_code", "dept_mgr_code", "div_mgr_code", "ad_code", "is_active"], null)
    };

    public async Task<IReadOnlyCollection<dynamic>> ListRowsAsync(string table, int take, CancellationToken cancellationToken)
    {
        var def = GetTable(table);
        var sql = $"SELECT TOP (@Take) * FROM dbo.{def.TableName} ORDER BY {def.PrimaryKey} DESC;";

        await using var conn = new SqlConnection(holder.Value);
        var rows = await conn.QueryAsync(new CommandDefinition(sql, new { Take = Math.Clamp(take, 1, 1000) }, cancellationToken: cancellationToken));
        return rows.ToArray();
    }

    public async Task<int> InsertRowAsync(string table, JsonObject values, CancellationToken cancellationToken)
    {
        var def = GetTable(table);
        var filtered = FilterColumns(def, values);
        if (filtered.Count == 0)
        {
            throw new InvalidOperationException("No writable columns provided.");
        }

        await using var conn = new SqlConnection(holder.Value);
        await conn.OpenAsync(cancellationToken);

        await CheckOverlapAsync(conn, def, filtered, excludeId: null, cancellationToken);

        var columnNames = string.Join(", ", filtered.Keys);
        var paramNames = string.Join(", ", filtered.Keys.Select(k => $"@{k}"));
        var sql = $@"
INSERT INTO dbo.{def.TableName} ({columnNames}, created_at, updated_at)
VALUES ({paramNames}, SYSUTCDATETIME(), NULL);
SELECT CAST(SCOPE_IDENTITY() AS INT);";

        var param = ToDynamicParameters(filtered);

        try
        {
            return await conn.ExecuteScalarAsync<int>(new CommandDefinition(sql, param, cancellationToken: cancellationToken));
        }
        catch (SqlException ex) when (IsConstraintViolation(ex))
        {
            throw new InvalidOperationException(TranslateConstraintError(ex, def.TableName), ex);
        }
    }

    public async Task<int> UpdateRowAsync(string table, long id, JsonObject values, CancellationToken cancellationToken)
    {
        var def = GetTable(table);
        var filtered = FilterColumns(def, values);
        if (filtered.Count == 0)
        {
            throw new InvalidOperationException("No writable columns provided.");
        }

        await using var conn = new SqlConnection(holder.Value);
        await conn.OpenAsync(cancellationToken);

        await CheckOverlapAsync(conn, def, filtered, excludeId: id, cancellationToken);

        var setters = string.Join(", ", filtered.Keys.Select(k => $"{k} = @{k}"));
        var sql = $@"
UPDATE dbo.{def.TableName}
SET {setters},
    updated_at = SYSUTCDATETIME()
WHERE {def.PrimaryKey} = @Id;
SELECT @@ROWCOUNT;";

        var param = ToDynamicParameters(filtered);
        param.Add("Id", id, DbType.Int64);

        try
        {
            return await conn.ExecuteScalarAsync<int>(new CommandDefinition(sql, param, cancellationToken: cancellationToken));
        }
        catch (SqlException ex) when (IsConstraintViolation(ex))
        {
            throw new InvalidOperationException(TranslateConstraintError(ex, def.TableName), ex);
        }
    }

    /// <summary>
    /// ตรวจ overlap ของช่วง effective_from/effective_to สำหรับ natural key เดียวกัน
    /// (ป้องกันข้อมูล rate/weight ที่ทับช่วงเวลากันโดยไม่ตั้งใจ ก่อน commit จริง)
    /// </summary>
    private static async Task CheckOverlapAsync(
        SqlConnection conn,
        MasterTableDef def,
        Dictionary<string, object?> values,
        long? excludeId,
        CancellationToken cancellationToken)
    {
        if (def.NaturalKeyColumns is null || def.NaturalKeyColumns.Count == 0)
        {
            return;
        }

        if (!values.ContainsKey("effective_from"))
        {
            // ไม่มีการเปลี่ยนช่วงวันที่ในคำขอนี้ ข้ามการตรวจ overlap
            return;
        }

        var missingKeyColumn = def.NaturalKeyColumns.FirstOrDefault(k => !values.ContainsKey(k));
        if (missingKeyColumn is not null)
        {
            throw new InvalidOperationException(
                $"Column '{missingKeyColumn}' is required together with effective_from to validate overlapping date ranges.");
        }

        var keyWhere = string.Join(" AND ", def.NaturalKeyColumns.Select(k => $"{k} = @{k}"));
        var excludeClause = excludeId.HasValue ? $"AND {def.PrimaryKey} <> @ExcludeId" : string.Empty;

        var sql = $@"
SELECT COUNT(1)
FROM dbo.{def.TableName}
WHERE {keyWhere}
  AND is_active = 1
  {excludeClause}
  AND effective_from <= @NewEffectiveTo
  AND (effective_to IS NULL OR effective_to >= @NewEffectiveFrom);";

        var param = ToDynamicParameters(values);
        param.Add("NewEffectiveFrom", values["effective_from"]);
        param.Add("NewEffectiveTo", values.TryGetValue("effective_to", out var to) && to is not null ? to : new DateTime(9999, 12, 31));
        if (excludeId.HasValue)
        {
            param.Add("ExcludeId", excludeId.Value, DbType.Int64);
        }

        var overlapCount = await conn.ExecuteScalarAsync<int>(
            new CommandDefinition(sql, param, cancellationToken: cancellationToken));

        if (overlapCount > 0)
        {
            throw new InvalidOperationException(
                $"Overlapping effective date range detected for the same key ({string.Join(", ", def.NaturalKeyColumns)}) in table '{def.TableName}'.");
        }
    }

    private static bool IsConstraintViolation(SqlException ex) =>
        ex.Errors.Cast<SqlError>().Any(e => e.Number is 2627 or 2601 or 547);

    private static string TranslateConstraintError(SqlException ex, string tableName)
    {
        var isForeignKey = ex.Errors.Cast<SqlError>().Any(e => e.Number == 547);
        return isForeignKey
            ? $"Foreign key violation while writing to '{tableName}'. Ensure referenced master data (channel/product/position) exists."
            : $"Duplicate or conflicting record while writing to '{tableName}'. Check unique key columns.";
    }

    public async Task<int> DeactivateRowAsync(string table, long id, CancellationToken cancellationToken)
    {
        var def = GetTable(table);
        var sql = $@"
UPDATE dbo.{def.TableName}
SET is_active = 0,
    updated_at = SYSUTCDATETIME()
WHERE {def.PrimaryKey} = @Id;
SELECT @@ROWCOUNT;";

        await using var conn = new SqlConnection(holder.Value);
        return await conn.ExecuteScalarAsync<int>(new CommandDefinition(sql, new { Id = id }, cancellationToken: cancellationToken));
    }

    public async Task<int> CreateChannelAsync(string channelCode, string channelNameTh, string channelNameEn, string calcType, CancellationToken cancellationToken)
    {
        const string sql = @"
INSERT INTO dbo.mst_channel
(channel_code, channel_name_th, channel_name_en, calc_type, is_active, created_at, updated_at)
VALUES
(@ChannelCode, @ChannelNameTh, @ChannelNameEn, @CalcType, 1, SYSUTCDATETIME(), NULL);
SELECT CAST(SCOPE_IDENTITY() AS INT);";

        await using var conn = new SqlConnection(holder.Value);
        return await conn.ExecuteScalarAsync<int>(
            new CommandDefinition(sql,
                new
                {
                    ChannelCode = channelCode.Trim().ToUpperInvariant(),
                    ChannelNameTh = channelNameTh.Trim(),
                    ChannelNameEn = channelNameEn.Trim(),
                    CalcType = calcType.Trim().ToUpperInvariant()
                },
                cancellationToken: cancellationToken));
    }

    public async Task<int> CloneMasterByChannelAsync(string targetChannel, string sourceChannel, CancellationToken cancellationToken)
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

DECLARE @rows INT = 0;

INSERT INTO dbo.mst_product_weight
(channel_id, product_id, ws_type, weight_percent, effective_from, effective_to, is_active, created_at, updated_at)
SELECT @TargetChannelId, product_id, ws_type, weight_percent, effective_from, effective_to, is_active, SYSUTCDATETIME(), NULL
FROM dbo.mst_product_weight src
WHERE src.channel_id = @SourceChannelId
  AND NOT EXISTS (
      SELECT 1 FROM dbo.mst_product_weight tgt
      WHERE tgt.channel_id = @TargetChannelId
        AND tgt.product_id = src.product_id
        AND tgt.ws_type = src.ws_type
        AND tgt.effective_from = src.effective_from
  );

SET @rows += @@ROWCOUNT;

INSERT INTO dbo.mst_incentive_rate
(channel_id, position_level_id, ws_type, rate_old, rate_new, effective_from, effective_to, is_active, created_at, updated_at)
SELECT @TargetChannelId, position_level_id, ws_type, rate_old, rate_new, effective_from, effective_to, is_active, SYSUTCDATETIME(), NULL
FROM dbo.mst_incentive_rate src
WHERE src.channel_id = @SourceChannelId
  AND NOT EXISTS (
      SELECT 1 FROM dbo.mst_incentive_rate tgt
      WHERE tgt.channel_id = @TargetChannelId
        AND tgt.position_level_id = src.position_level_id
        AND tgt.ws_type = src.ws_type
        AND tgt.effective_from = src.effective_from
  );

SET @rows += @@ROWCOUNT;
SELECT @rows;";

        await using var conn = new SqlConnection(holder.Value);
        return await conn.ExecuteScalarAsync<int>(
            new CommandDefinition(sql, new { TargetChannel = targetChannel, SourceChannel = sourceChannel }, cancellationToken: cancellationToken));
    }

    private static MasterTableDef GetTable(string table)
    {
        if (!SupportedTables.TryGetValue(table, out var def))
        {
            throw new InvalidOperationException("Unsupported master table");
        }

        return def;
    }

    private static Dictionary<string, object?> FilterColumns(MasterTableDef def, JsonObject values)
    {
        var result = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
        foreach (var kv in values)
        {
            if (!def.WritableColumns.Contains(kv.Key, StringComparer.OrdinalIgnoreCase))
            {
                continue;
            }

            result[kv.Key] = ToObject(kv.Value);
        }

        return result;
    }

    private static DynamicParameters ToDynamicParameters(Dictionary<string, object?> values)
    {
        var parameters = new DynamicParameters();
        foreach (var kv in values)
        {
            parameters.Add(kv.Key, kv.Value);
        }

        return parameters;
    }

    private static object? ToObject(JsonNode? node)
    {
        if (node is null)
        {
            return null;
        }

        if (node is JsonValue value)
        {
            if (value.TryGetValue<bool>(out var b)) return b;
            if (value.TryGetValue<int>(out var i)) return i;
            if (value.TryGetValue<long>(out var l)) return l;
            if (value.TryGetValue<decimal>(out var d)) return d;
            if (value.TryGetValue<double>(out var db)) return db;
            if (value.TryGetValue<DateTime>(out var dt)) return dt;
            if (value.TryGetValue<string>(out var s)) return string.IsNullOrWhiteSpace(s) ? null : s;
        }

        return node.ToString();
    }

    private sealed record MasterTableDef(
        string TableName,
        string PrimaryKey,
        IReadOnlyCollection<string> WritableColumns,
        IReadOnlyCollection<string>? NaturalKeyColumns);
}
