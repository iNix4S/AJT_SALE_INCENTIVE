using Dapper;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Data.SqlClient;
using AjtIncentive.Web.Services;
using System.Data;

namespace AjtIncentive.Web.Pages.SpecialAdjust;

public sealed class IndexModel : PageModel
{
    private readonly IPortalDataService _data;
    private readonly string _connectionString;

    public IndexModel(IPortalDataService data, IConfiguration config)
    {
        _data = data;
        _connectionString = config.GetConnectionString("DefaultConnection")!;
    }

    [BindProperty(SupportsGet = true)] public int ChannelId { get; set; } = 1;
    [BindProperty(SupportsGet = true)] public int PeriodId  { get; set; }

    public IReadOnlyList<ChannelItem>     Channels       { get; private set; } = [];
    public IReadOnlyList<PeriodItem>      Periods        { get; private set; } = [];
    public IReadOnlyList<EmployeeItem>    Employees      { get; private set; } = [];
    public IReadOnlyList<ProductItem>     Products       { get; private set; } = [];
    public IReadOnlyList<SpecialAdjRow>   ShortageRecords { get; private set; } = [];
    public IReadOnlyList<SpecialAdjRow>   SpecialRecords  { get; private set; } = [];
    public string SelectedChannelCode { get; private set; } = string.Empty;
    public string SelectedPeriodCode  { get; private set; } = string.Empty;

    public async Task OnGetAsync()
    {
        await LoadDataAsync();
    }

    public async Task<IActionResult> OnPostSaveShortageAsync(
        string? employeeCode, string productCode, decimal overrideAchievement,
        string reason, string? approvedBy)
    {
        try
        {
            await using var conn = new SqlConnection(_connectionString);
            var parameters = new DynamicParameters();
            parameters.Add("AdjustmentId", dbType: DbType.Int32, direction: ParameterDirection.Output);
            parameters.Add("PeriodId", PeriodId);
            parameters.Add("ChannelId", ChannelId);
            parameters.Add("AdjustmentType", "SHORTAGE");
            parameters.Add("EmployeeCode", string.IsNullOrEmpty(employeeCode) ? null : employeeCode);
            parameters.Add("ProductCode", productCode);
            parameters.Add("OverrideAchievement", overrideAchievement);
            parameters.Add("AdjustedTargetAmount", null);
            parameters.Add("AdjustedWeightPercent", null);
            parameters.Add("Reason", reason);
            parameters.Add("ApprovedBy", approvedBy);
            parameters.Add("IsActive", true);

            await conn.ExecuteAsync(
                "dbo.usp_trn_special_adjustment_upsert",
                parameters,
                commandType: CommandType.StoredProcedure);

            TempData["Message"] = $"บันทึก Shortage Adjustment สำหรับ {productCode} (override={overrideAchievement:P0}) เรียบร้อย";
        }
        catch (Exception ex)
        {
            TempData["Message"] = $"Error: {ex.Message}";
        }
        return RedirectToPage(new { ChannelId, PeriodId });
    }

    public async Task<IActionResult> OnPostSaveSpecialAsync(
        string? employeeCode, string? productCode,
        decimal? adjustedTargetAmount, decimal? adjustedWeightPercent,
        string reason, string? approvedBy)
    {
        try
        {
            await using var conn = new SqlConnection(_connectionString);
            var parameters = new DynamicParameters();
            parameters.Add("AdjustmentId", dbType: DbType.Int32, direction: ParameterDirection.Output);
            parameters.Add("PeriodId", PeriodId);
            parameters.Add("ChannelId", ChannelId);
            parameters.Add("AdjustmentType", "SPECIAL_SITUATION");
            parameters.Add("EmployeeCode", string.IsNullOrEmpty(employeeCode) ? null : employeeCode);
            parameters.Add("ProductCode", string.IsNullOrEmpty(productCode) ? null : productCode);
            parameters.Add("OverrideAchievement", null);
            parameters.Add("AdjustedTargetAmount", adjustedTargetAmount);
            parameters.Add("AdjustedWeightPercent", adjustedWeightPercent);
            parameters.Add("Reason", reason);
            parameters.Add("ApprovedBy", approvedBy);
            parameters.Add("IsActive", true);

            await conn.ExecuteAsync(
                "dbo.usp_trn_special_adjustment_upsert",
                parameters,
                commandType: CommandType.StoredProcedure);

            TempData["Message"] = "บันทึก Special Situation Adjustment เรียบร้อย";
        }
        catch (Exception ex)
        {
            TempData["Message"] = $"Error: {ex.Message}";
        }
        return RedirectToPage(new { ChannelId, PeriodId });
    }

    public async Task<IActionResult> OnPostDeleteAsync(int adjustmentId)
    {
        try
        {
            await using var conn = new SqlConnection(_connectionString);
            await conn.ExecuteScalarAsync<int>(
                "dbo.usp_trn_special_adjustment_delete",
                new { AdjustmentId = adjustmentId },
                commandType: CommandType.StoredProcedure);
            TempData["Message"] = "ลบ Adjustment record เรียบร้อย";
        }
        catch (Exception ex)
        {
            TempData["Message"] = $"Error: {ex.Message}";
        }
        return RedirectToPage(new { ChannelId, PeriodId });
    }

    private async Task LoadDataAsync()
    {
        Channels = await _data.GetChannelsAsync();
        Periods  = await _data.GetPeriodsAsync();

        if (PeriodId == 0 && Periods.Count > 0)
            PeriodId = Periods[0].PeriodId;

        var ch = Channels.FirstOrDefault(c => c.ChannelId == ChannelId);
        var pr = Periods.FirstOrDefault(p => p.PeriodId  == PeriodId);
        SelectedChannelCode = ch?.ChannelCode ?? string.Empty;
        SelectedPeriodCode  = pr?.PeriodCode  ?? string.Empty;

        await using var conn = new SqlConnection(_connectionString);

        Employees = (await conn.QueryAsync<EmployeeItem>(@"
            SELECT employee_code AS EmployeeCode, employee_name_th AS EmployeeNameTh
            FROM dbo.mst_employee
            WHERE channel_id = @ChannelId AND is_active = 1
            ORDER BY employee_code;",
            new { ChannelId })).ToList();

        Products = (await conn.QueryAsync<ProductItem>(@"
            SELECT product_code AS ProductCode, product_name_th AS ProductNameTh
            FROM dbo.mst_product
            WHERE is_active = 1
            ORDER BY product_code;")).ToList();

        var allAdj = (await conn.QueryAsync<SpecialAdjRow>(@"
            SELECT adjustment_id AS AdjustmentId,
                   adjustment_type AS AdjustmentType,
                   employee_code AS EmployeeCode,
                   product_code AS ProductCode,
                   override_achievement AS OverrideAchievement,
                   adjusted_target_amount AS AdjustedTargetAmount,
                   adjusted_weight_percent AS AdjustedWeightPercent,
                   reason AS Reason,
                   approved_by AS ApprovedBy
            FROM dbo.trn_special_adjustment
            WHERE channel_id = @ChannelId AND period_id = @PeriodId AND is_active = 1
            ORDER BY adjustment_id;",
            new { ChannelId, PeriodId })).ToList();

        ShortageRecords = allAdj.Where(r => r.AdjustmentType == "SHORTAGE").ToList();
        SpecialRecords  = allAdj.Where(r => r.AdjustmentType == "SPECIAL_SITUATION").ToList();
    }
}

public sealed class SpecialAdjRow
{
    public int      AdjustmentId           { get; init; }
    public string   AdjustmentType         { get; init; } = string.Empty;
    public string?  EmployeeCode           { get; init; }
    public string?  ProductCode            { get; init; }
    public decimal? OverrideAchievement    { get; init; }
    public decimal? AdjustedTargetAmount   { get; init; }
    public decimal? AdjustedWeightPercent  { get; init; }
    public string   Reason                 { get; init; } = string.Empty;
    public string?  ApprovedBy             { get; init; }
}

public sealed class ProductItem
{
    public string ProductCode    { get; init; } = string.Empty;
    public string ProductNameTh  { get; init; } = string.Empty;
}

public sealed class EmployeeItem
{
    public string EmployeeCode   { get; init; } = string.Empty;
    public string EmployeeNameTh { get; init; } = string.Empty;
}
