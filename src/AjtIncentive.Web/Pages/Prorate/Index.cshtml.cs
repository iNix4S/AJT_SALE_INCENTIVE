using Dapper;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Data.SqlClient;
using System.Data;
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
    [BindProperty] public AdjustmentInput Input { get; set; } = new();

    public IReadOnlyList<ChannelItem>   Channels       { get; private set; } = [];
    public IReadOnlyList<PeriodItem>    Periods        { get; private set; } = [];
    public IReadOnlyList<EmployeeItem>  Employees      { get; private set; } = [];
    public IReadOnlyList<ProrateRow>    ProrateRecords { get; private set; } = [];
    public IReadOnlyList<AdjustmentFormulaRow> ActiveFormulas { get; private set; } = [];
    public IReadOnlyList<AdjustmentTestRow> TestSummaries { get; private set; } = [];
    public AdjustmentCalcResult? LastCalcResult { get; private set; }
    public string SelectedChannelCode  { get; private set; } = string.Empty;
    public string SelectedPeriodCode   { get; private set; } = string.Empty;

    public async Task OnGetAsync()
    {
        await LoadDataAsync();
        SetDefaultInput();
    }

    public async Task<IActionResult> OnPostSaveAsync(
        string employeeCode, string prorateType,
        int actualDays, int totalDays,
        string? approvedBy, string? remarks)
    {
        try
        {
            await using var conn = new SqlConnection(_connectionString);
            var parameters = new DynamicParameters();
            parameters.Add("ProrateId", dbType: DbType.Int32, direction: ParameterDirection.Output);
            parameters.Add("PeriodId", PeriodId);
            parameters.Add("ChannelId", ChannelId);
            parameters.Add("EmployeeCode", employeeCode);
            parameters.Add("ProrateType", prorateType);
            parameters.Add("ActualDays", actualDays);
            parameters.Add("TotalDays", totalDays);
            parameters.Add("ApprovedBy", approvedBy);
            parameters.Add("Remarks", remarks);
            parameters.Add("IsActive", true);

            await conn.ExecuteAsync(
                "dbo.usp_trn_prorate_adjustment_upsert",
                parameters,
                commandType: CommandType.StoredProcedure);

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
            await conn.ExecuteScalarAsync<int>(
                "dbo.usp_trn_prorate_adjustment_delete",
                new { ProrateId = prorateId },
                commandType: CommandType.StoredProcedure);
            TempData["Message"] = "ลบ Prorate record เรียบร้อย";
        }
        catch (Exception ex)
        {
            TempData["Message"] = $"Error: {ex.Message}";
        }
        return RedirectToPage(new { ChannelId, PeriodId });
    }

    public async Task<IActionResult> OnPostApplyAdjustmentsAsync()
    {
        try
        {
            await using var conn = new SqlConnection(_connectionString);

            var p = new DynamicParameters();
            p.Add("@BaseIncentive", Input.BaseIncentive);
            p.Add("@ActualAmount", Input.ActualAmount);
            p.Add("@TargetAmount", Input.TargetAmount);
            p.Add("@Standard100Pct", Input.Standard100Pct);
            p.Add("@ShortageConfigEnabled", Input.ShortageConfigEnabled);
            p.Add("@SpecialApproved", Input.SpecialApproved);
            p.Add("@AllocationWeightPct", Input.AllocationWeightPct);
            p.Add("@WorkDays", Input.WorkDays);
            p.Add("@PeriodDays", Input.PeriodDays);
            p.Add("@AdjustedIncentive", dbType: DbType.Decimal, direction: ParameterDirection.Output, precision: 18, scale: 2);
            p.Add("@AdjustmentLogJson", dbType: DbType.String, direction: ParameterDirection.Output, size: -1);

            await conn.ExecuteAsync("dbo.usp_apply_adjustments", p, commandType: CommandType.StoredProcedure);

            LastCalcResult = new AdjustmentCalcResult
            {
                AdjustedIncentive = p.Get<decimal>("@AdjustedIncentive"),
                AdjustmentLogJson = p.Get<string>("@AdjustmentLogJson")
            };

            TempData["Message"] = "คำนวณ Adjustment ผ่าน Stored Procedure สำเร็จ";
        }
        catch (Exception ex)
        {
            TempData["Message"] = $"Error: {ex.Message}";
        }

        await LoadDataAsync();
        return Page();
    }

    public async Task<IActionResult> OnPostRunTestAsync(string testCaseCode)
    {
        try
        {
            await using var conn = new SqlConnection(_connectionString);

            var result = await conn.QueryFirstAsync<TestRunResult>(@"
                EXEC dbo.usp_run_adjustment_test
                    @TestCaseCode = @TestCaseCode,
                    @ToleranceBaht = @ToleranceBaht;",
                new { TestCaseCode = testCaseCode, ToleranceBaht = 0.01m });

            var diffText = result.DiffBaht.HasValue ? $", diff={result.DiffBaht.Value:0.00}" : string.Empty;
            TempData["Message"] = $"Run test {result.TestCaseCode}: {result.Result}{diffText}";
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

        ActiveFormulas = (await conn.QueryAsync<AdjustmentFormulaRow>(@"
            SELECT adjustment_formula_id AS AdjustmentFormulaId,
                   adjustment_code AS AdjustmentCode,
                   adjustment_name AS AdjustmentName,
                   adjustment_type AS AdjustmentType,
                   calc_order AS CalcOrder,
                   calc_order_label AS CalcOrderLabel,
                   requires_approval AS RequiresApproval,
                   requires_config AS RequiresConfig,
                   config_key AS ConfigKey,
                   description AS Description
            FROM dbo.vw_active_adjustment_formulas
                 ORDER BY calc_order, sort_order, adjustment_formula_id;")).ToList();

        TestSummaries = (await conn.QueryAsync<AdjustmentTestRow>(@"
            SELECT test_case_code AS TestCaseCode,
                   test_group_label AS TestGroupLabel,
                   test_case_name AS TestCaseName,
                   adjustment_type AS AdjustmentType,
                   calc_order AS CalcOrder,
                   expected_output AS ExpectedOutput,
                   expected_condition AS ExpectedCondition,
                   test_status AS TestStatus,
                   fail_reason AS FailReason,
                   is_edge_case AS IsEdgeCase
            FROM dbo.vw_adjustment_test_summary
                 ORDER BY test_group, test_case_code;")).ToList();
    }

    private void SetDefaultInput()
    {
        if (Input.PeriodDays <= 0)
        {
            Input = new AdjustmentInput
            {
                BaseIncentive = 10000,
                ActualAmount = 10000,
                TargetAmount = 10000,
                Standard100Pct = 8000,
                ShortageConfigEnabled = false,
                SpecialApproved = false,
                AllocationWeightPct = 100,
                WorkDays = 30,
                PeriodDays = 30
            };
        }
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

public sealed class AdjustmentFormulaRow
{
    public int AdjustmentFormulaId { get; init; }
    public string AdjustmentCode { get; init; } = string.Empty;
    public string AdjustmentName { get; init; } = string.Empty;
    public string AdjustmentType { get; init; } = string.Empty;
    public int CalcOrder { get; init; }
    public string CalcOrderLabel { get; init; } = string.Empty;
    public bool RequiresApproval { get; init; }
    public bool RequiresConfig { get; init; }
    public string? ConfigKey { get; init; }
    public string? Description { get; init; }
}

public sealed class AdjustmentTestRow
{
    public string TestCaseCode { get; init; } = string.Empty;
    public string TestGroupLabel { get; init; } = string.Empty;
    public string TestCaseName { get; init; } = string.Empty;
    public string? AdjustmentType { get; init; }
    public int? CalcOrder { get; init; }
    public decimal? ExpectedOutput { get; init; }
    public string? ExpectedCondition { get; init; }
    public string TestStatus { get; init; } = string.Empty;
    public string? FailReason { get; init; }
    public bool IsEdgeCase { get; init; }
}

public sealed class AdjustmentInput
{
    public decimal BaseIncentive { get; set; }
    public decimal ActualAmount { get; set; }
    public decimal TargetAmount { get; set; }
    public decimal Standard100Pct { get; set; }
    public bool ShortageConfigEnabled { get; set; }
    public bool SpecialApproved { get; set; }
    public decimal AllocationWeightPct { get; set; }
    public int WorkDays { get; set; }
    public int PeriodDays { get; set; }
}

public sealed class AdjustmentCalcResult
{
    public decimal AdjustedIncentive { get; init; }
    public string AdjustmentLogJson { get; init; } = string.Empty;
}

public sealed class TestRunResult
{
    public string TestCaseCode { get; init; } = string.Empty;
    public string Result { get; init; } = string.Empty;
    public decimal? DiffBaht { get; init; }
}
