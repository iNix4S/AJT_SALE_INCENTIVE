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
    // หมายเหตุ: business rule (FK check, duplicate/overlap check ของ effective_from/effective_to)
    // ถูก centralize ไว้ใน stored procedure ฝั่ง DB แล้ว (usp_master_{table}_upsert / _deactivate)
    // ดู database/scripts/usp_master_data_management.sql — service ชั้นนี้ทำหน้าที่แค่ map
    // column ที่อนุญาต (WritableColumns) ไปเป็น parameter ของ SP เท่านั้น ไม่มี business logic ซ้ำซ้อนอีก
    private static readonly Dictionary<string, MasterTableDef> SupportedTables = new(StringComparer.OrdinalIgnoreCase)
    {
        ["mst_channel"] = new("mst_channel", "channel_id", ["channel_code", "channel_name_th", "channel_name_en", "calc_type", "is_active"]),
        ["mst_product"] = new("mst_product", "product_id", ["product_code", "product_name_th", "product_name_en", "product_group_code", "product_group_name", "is_gd_product", "gd_product_code", "product_group_id", "tt_sheet_code", "is_active"]),
        ["mst_product_weight"] = new("mst_product_weight", "product_weight_id", ["channel_id", "product_id", "ws_type", "weight_percent", "effective_from", "effective_to", "is_active"]),
        ["mst_incentive_rate"] = new("mst_incentive_rate", "incentive_rate_id", ["channel_id", "position_level_id", "ws_type", "rate_old", "rate_new", "effective_from", "effective_to", "is_active"]),
        ["mst_goal_threshold"] = new("mst_goal_threshold", "goal_threshold_id", ["achievement_from", "achievement_to", "multiplier", "sequence_no", "is_active"]),
        ["mst_shortage_policy"] = new("mst_shortage_policy", "shortage_policy_id", ["product_id", "shortage_month", "override_achievement", "reason_code", "remarks", "is_active"]),
        ["mst_org_hierarchy"] = new("mst_org_hierarchy", "hierarchy_id", ["channel_id", "effective_month", "salesman_code", "direct_sup_code", "dept_mgr_code", "div_mgr_code", "ad_code", "ws_type", "is_active"])
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

        var param = BuildUpsertParameters(def, filtered, id: null);

        try
        {
            await conn.ExecuteAsync(new CommandDefinition(
                UpsertSpName(def), param, commandType: CommandType.StoredProcedure, cancellationToken: cancellationToken));
            return param.Get<int>(IdParameterName(def));
        }
        catch (SqlException ex) when (IsBusinessRuleViolation(ex))
        {
            throw new InvalidOperationException(ex.Message, ex);
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

        var param = BuildUpsertParameters(def, filtered, id: id);

        try
        {
            await conn.ExecuteAsync(new CommandDefinition(
                UpsertSpName(def), param, commandType: CommandType.StoredProcedure, cancellationToken: cancellationToken));
            return 1;
        }
        catch (SqlException ex) when (IsBusinessRuleViolation(ex))
        {
            throw new InvalidOperationException(ex.Message, ex);
        }
        catch (SqlException ex) when (IsConstraintViolation(ex))
        {
            throw new InvalidOperationException(TranslateConstraintError(ex, def.TableName), ex);
        }
    }

    /// <summary>
    /// Business rule (FK check, duplicate key, overlap ของ effective_from/effective_to) ทั้งหมดถูก
    /// centralize ไว้ใน stored procedure ฝั่ง DB แล้ว — SP จะ THROW ด้วย error number ช่วง 51000-51999
    /// เมื่อ validation ไม่ผ่าน ส่วนนี้แค่แปลง error message ของ SP กลับเป็น 400 BadRequest ที่อ่านง่าย
    /// </summary>
    private static bool IsBusinessRuleViolation(SqlException ex) => ex.Number is >= 51000 and < 52000;

    /// <summary>
    /// สร้าง DynamicParameters สำหรับเรียก usp_master_{table}_upsert โดย map ชื่อ column (snake_case)
    /// เป็นชื่อ parameter (PascalCase) ให้ตรงกับ stored procedure ฝั่ง DB โดยอัตโนมัติ
    /// </summary>
    private static DynamicParameters BuildUpsertParameters(MasterTableDef def, Dictionary<string, object?> filtered, long? id)
    {
        var parameters = new DynamicParameters();
        var idParamName = IdParameterName(def);

        if (id.HasValue)
        {
            parameters.Add(idParamName, (int)id.Value, dbType: DbType.Int32, direction: ParameterDirection.InputOutput);
        }
        else
        {
            parameters.Add(idParamName, dbType: DbType.Int32, direction: ParameterDirection.Output);
        }

        foreach (var kv in filtered)
        {
            parameters.Add(ToPascalCase(kv.Key), kv.Value);
        }

        return parameters;
    }

    private static string SpSuffix(MasterTableDef def) => def.TableName["mst_".Length..];

    private static string UpsertSpName(MasterTableDef def) => $"dbo.usp_master_{SpSuffix(def)}_upsert";

    private static string DeactivateSpName(MasterTableDef def) => $"dbo.usp_master_{SpSuffix(def)}_deactivate";

    private static string IdParameterName(MasterTableDef def) => ToPascalCase(def.PrimaryKey);

    /// <summary>แปลงชื่อ column แบบ snake_case (เช่น "ws_type") เป็น PascalCase ("WsType") ให้ตรงกับชื่อ parameter ของ SP</summary>
    private static string ToPascalCase(string snakeCase)
    {
        var sb = new StringBuilder();
        foreach (var part in snakeCase.Split('_', StringSplitOptions.RemoveEmptyEntries))
        {
            sb.Append(char.ToUpperInvariant(part[0]));
            if (part.Length > 1)
            {
                sb.Append(part[1..]);
            }
        }

        return sb.ToString();
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
        var param = new DynamicParameters();
        param.Add(IdParameterName(def), (int)id);

        await using var conn = new SqlConnection(holder.Value);
        try
        {
            return await conn.ExecuteScalarAsync<int>(new CommandDefinition(
                DeactivateSpName(def), param, commandType: CommandType.StoredProcedure, cancellationToken: cancellationToken));
        }
        catch (SqlException ex) when (IsBusinessRuleViolation(ex))
        {
            throw new InvalidOperationException(ex.Message, ex);
        }
    }

    public async Task<int> CreateChannelAsync(string channelCode, string channelNameTh, string channelNameEn, string calcType, CancellationToken cancellationToken)
    {
        var param = new DynamicParameters();
        param.Add("ChannelId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        param.Add("ChannelCode", channelCode.Trim().ToUpperInvariant());
        param.Add("ChannelNameTh", channelNameTh.Trim());
        param.Add("ChannelNameEn", channelNameEn.Trim());
        param.Add("CalcType", calcType.Trim().ToUpperInvariant());
        param.Add("IsActive", true);

        await using var conn = new SqlConnection(holder.Value);
        try
        {
            await conn.ExecuteAsync(new CommandDefinition(
                "dbo.usp_master_channel_upsert", param, commandType: CommandType.StoredProcedure, cancellationToken: cancellationToken));
            return param.Get<int>("ChannelId");
        }
        catch (SqlException ex) when (IsBusinessRuleViolation(ex))
        {
            throw new InvalidOperationException(ex.Message, ex);
        }
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
        IReadOnlyCollection<string> WritableColumns);
}
