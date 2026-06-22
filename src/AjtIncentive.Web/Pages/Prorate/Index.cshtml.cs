using Dapper;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Data.SqlClient;
using AjtIncentive.Web.Services;

namespace AjtIncentive.Web.Pages.Prorate;

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

    public IReadOnlyList<ChannelItem>   Channels       { get; private set; } = [];
    public IReadOnlyList<PeriodItem>    Periods        { get; private set; } = [];
    public IReadOnlyList<EmployeeItem>  Employees      { get; private set; } = [];
    public IReadOnlyList<ProrateRow>    ProrateRecords { get; private set; } = [];
    public string SelectedChannelCode  { get; private set; } = string.Empty;
    public string SelectedPeriodCode   { get; private set; } = string.Empty;

    public async Task OnGetAsync()
    {
        await LoadDataAsync();
    }

    public async Task<IActionResult> OnPostSaveAsync(
        string employeeCode, string prorateType,
        int actualDays, int totalDays,
        string? approvedBy, string? remarks)
    {
        try
        {
            await using var conn = new SqlConnection(_connectionString);
            await conn.ExecuteAsync(@"
                MERGE dbo.trn_prorate_adjustment AS tgt
                USING (SELECT @PeriodId AS period_id, @ChannelId AS channel_id, @EmployeeCode AS employee_code) AS src
                    ON tgt.period_id = src.period_id AND tgt.channel_id = src.channel_id AND tgt.employee_code = src.employee_code
                WHEN MATCHED THEN
                    UPDATE SET prorate_type = @ProrateType, actual_days = @ActualDays, total_days = @TotalDays,
                               approved_by = @ApprovedBy, remarks = @Remarks, updated_at = SYSUTCDATETIME()
                WHEN NOT MATCHED THEN
                    INSERT (period_id, channel_id, employee_code, prorate_type, actual_days, total_days, approved_by, remarks)
                    VALUES (@PeriodId, @ChannelId, @EmployeeCode, @ProrateType, @ActualDays, @TotalDays, @ApprovedBy, @Remarks);",
                new { PeriodId, ChannelId, EmployeeCode = employeeCode, ProrateType = prorateType,
                      ActualDays = actualDays, TotalDays = totalDays, ApprovedBy = approvedBy, Remarks = remarks });

            TempData["Message"] = $"บันทึก Prorate ของ {employeeCode} ({prorateType}: {actualDays}/{totalDays}) เรียบร้อย";
        }
        catch (Exception ex)
        {
            TempData["Message"] = $"Error: {ex.Message}";
        }
        return RedirectToPage(new { ChannelId, PeriodId });
    }

    public async Task<IActionResult> OnPostDeleteAsync(int prorateId)
    {
        try
        {
            await using var conn = new SqlConnection(_connectionString);
            await conn.ExecuteAsync(
                "DELETE FROM dbo.trn_prorate_adjustment WHERE prorate_id = @Id",
                new { Id = prorateId });
            TempData["Message"] = "ลบ Prorate record เรียบร้อย";
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
        SelectedChannelCode = ch?.ChannelCode  ?? string.Empty;
        SelectedPeriodCode  = pr?.PeriodCode   ?? string.Empty;

        await using var conn = new SqlConnection(_connectionString);

        Employees = (await conn.QueryAsync<EmployeeItem>(@"
            SELECT employee_code AS EmployeeCode, employee_name_th AS EmployeeNameTh
            FROM dbo.mst_employee
            WHERE channel_id = @ChannelId AND is_active = 1
            ORDER BY employee_code;",
            new { ChannelId })).ToList();

        ProrateRecords = (await conn.QueryAsync<ProrateRow>(@"
            SELECT pa.prorate_id AS ProrateId,
                   pa.employee_code AS EmployeeCode,
                   COALESCE(e.employee_name_th, pa.employee_code) AS EmployeeNameTh,
                   pa.prorate_type AS ProrateType,
                   pa.actual_days AS ActualDays,
                   pa.total_days AS TotalDays,
                   pa.remarks AS Remarks,
                   pa.approved_by AS ApprovedBy
            FROM dbo.trn_prorate_adjustment pa
            LEFT JOIN dbo.mst_employee e ON e.employee_code = pa.employee_code AND e.channel_id = pa.channel_id
            WHERE pa.channel_id = @ChannelId AND pa.period_id = @PeriodId AND pa.is_active = 1
            ORDER BY pa.employee_code;",
            new { ChannelId, PeriodId })).ToList();
    }
}

public sealed class ProrateRow
{
    public int    ProrateId      { get; init; }
    public string EmployeeCode   { get; init; } = string.Empty;
    public string EmployeeNameTh { get; init; } = string.Empty;
    public string ProrateType    { get; init; } = string.Empty;
    public int    ActualDays     { get; init; }
    public int    TotalDays      { get; init; }
    public string Remarks        { get; init; } = string.Empty;
    public string ApprovedBy     { get; init; } = string.Empty;
}

public sealed class EmployeeItem
{
    public string EmployeeCode   { get; init; } = string.Empty;
    public string EmployeeNameTh { get; init; } = string.Empty;
}
