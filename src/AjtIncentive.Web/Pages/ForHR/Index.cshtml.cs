using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using AjtIncentive.Web.Services;
using System.Text;

namespace AjtIncentive.Web.Pages.ForHR;

public class IndexModel : PageModel
{
    private readonly IPortalDataService _portalDataService;

    public IndexModel(IPortalDataService portalDataService)
    {
        _portalDataService = portalDataService;
    }

    [BindProperty(SupportsGet = true)]
    public int ChannelId { get; set; } = 1;

    [BindProperty(SupportsGet = true)]
    public int PeriodId { get; set; }

    [BindProperty(SupportsGet = true)]
    public int? CalcRunId { get; set; }

    public IReadOnlyList<ChannelItem> Channels { get; private set; } = Array.Empty<ChannelItem>();
    public IReadOnlyList<PeriodItem> Periods { get; private set; } = Array.Empty<PeriodItem>();
    public IReadOnlyList<ForHrRow> Rows { get; private set; } = Array.Empty<ForHrRow>();
    public IReadOnlyList<ForHrTtSheetRow> TtSheetRows { get; private set; } = Array.Empty<ForHrTtSheetRow>();
    public IReadOnlyList<ForHrTtSheetRow> MtSheetRows { get; private set; } = Array.Empty<ForHrTtSheetRow>();
    public IReadOnlyList<ForHrTtSheetRow> SiSheetRows { get; private set; } = Array.Empty<ForHrTtSheetRow>();
    public IReadOnlyList<ForHrTtSheetRow> LaosSheetRows { get; private set; } = Array.Empty<ForHrTtSheetRow>();

    public bool IsTtChannel => ChannelId == 2;
    public bool IsMtChannel => ChannelId == 1;
    public bool IsSiChannel => ChannelId == 3;
    public bool IsLaosChannel => ChannelId == 4;
    public bool UseSheetLayout => IsTtChannel || IsMtChannel || IsSiChannel || IsLaosChannel;
    public IReadOnlyList<ForHrTtSheetRow> ActiveSheetRows =>
        IsTtChannel ? TtSheetRows :
        IsMtChannel ? MtSheetRows :
        IsSiChannel ? SiSheetRows :
        IsLaosChannel ? LaosSheetRows :
        Array.Empty<ForHrTtSheetRow>();

    public async Task OnGetAsync()
    {
        await LoadDataAsync();
    }

    public async Task<IActionResult> OnGetExportCsvAsync()
    {
        await LoadDataAsync();

        if (CalcRunId is null || (Rows.Count == 0 && ActiveSheetRows.Count == 0))
        {
            TempData["Message"] = "ไม่พบข้อมูล For HR ตาม Channel และ Period ที่เลือก";
            return RedirectToPage(new { ChannelId, PeriodId });
        }

        string csv;
        string fileName;
        if (UseSheetLayout && ActiveSheetRows.Count > 0)
        {
            csv = BuildTtCsv(ActiveSheetRows);
            var channelCode = IsTtChannel ? "tt" : IsMtChannel ? "mt" : IsSiChannel ? "si" : "laos";
            fileName = $"for-hr-{channelCode}-period-{PeriodId}-run-{CalcRunId}.csv";
        }
        else
        {
            csv = BuildCsv(Rows);
            fileName = $"for-hr-channel-{ChannelId}-period-{PeriodId}-run-{CalcRunId}.csv";
        }

        return File(Encoding.UTF8.GetBytes(csv), "text/csv", fileName);
    }

    private async Task LoadDataAsync()
    {
        Channels = await _portalDataService.GetChannelsAsync();
        Periods = await _portalDataService.GetPeriodsAsync();

        if (PeriodId <= 0)
        {
            PeriodId = Periods.LastOrDefault()?.PeriodId ?? 1;
        }

        var effectiveCalcRunId = CalcRunId
            ?? await _portalDataService.GetLatestCalcRunIdByPeriodAsync(ChannelId, PeriodId);

        CalcRunId = effectiveCalcRunId;

        if (effectiveCalcRunId.HasValue)
        {
            if (IsTtChannel)
            {
                TtSheetRows = await _portalDataService.GetForHrTtSheetAsync(effectiveCalcRunId.Value, 1000);
            }
            else if (IsMtChannel)
            {
                MtSheetRows = await _portalDataService.GetForHrMtSheetAsync(effectiveCalcRunId.Value, 1000);
            }
            else if (IsSiChannel)
            {
                SiSheetRows = await _portalDataService.GetForHrSiSheetAsync(effectiveCalcRunId.Value, 1000);
            }
            else if (IsLaosChannel)
            {
                LaosSheetRows = await _portalDataService.GetForHrLaosSheetAsync(effectiveCalcRunId.Value, 1000);
            }
            else
            {
                Rows = await _portalDataService.GetForHrRowsAsync(effectiveCalcRunId.Value, 1000);
            }
        }
    }

    private static string BuildCsv(IReadOnlyList<ForHrRow> rows)
    {
        var sb = new StringBuilder();
                sb.AppendLine("EmployeeCode,EmployeeNameTh,PositionLevelCode,VariablePayMonth,PaymentMethod,IncentiveStaff,IncentiveSect,IncentiveDept,IncentiveDiv,IncentiveAd,GdIncentiveTotal,TotalVariable");

        foreach (var row in rows)
        {
            sb.Append(row.EmployeeCode).Append(',')
                            .Append(CsvEscape(row.EmployeeNameTh)).Append(',')
              .Append(row.PositionLevelCode).Append(',')
                            .Append(row.VariablePayMonth?.ToString("yyyy-MM") ?? string.Empty).Append(',')
                            .Append(row.PaymentMethod).Append(',')
                            .Append(row.IncentiveStaff.ToString("0.00")).Append(',')
                            .Append(row.IncentiveSect.ToString("0.00")).Append(',')
                            .Append(row.IncentiveDept.ToString("0.00")).Append(',')
                            .Append(row.IncentiveDiv.ToString("0.00")).Append(',')
                            .Append(row.IncentiveAd.ToString("0.00")).Append(',')
                            .Append(row.GdIncentiveTotal.ToString("0.00")).Append(',')
              .Append(row.TotalVariable.ToString("0.00"))
              .AppendLine();
        }

        return sb.ToString();
    }

    private static string BuildTtCsv(IReadOnlyList<ForHrTtSheetRow> rows)
    {
        var sb = new StringBuilder();
        sb.AppendLine("PeriodCode,UserEmployeeId,SalesmanCode,EmployeeNameTh,PositionLevelCode,PositionNameEn,HierarchyLevel," +
                      "JobFunctionCode,JobFunctionNameEn,DivisionName,DepartmentName,SectionName," +
                      "VariablePayMonth,PaymentMethod,TotalVariable,IncentiveStaff,IncentiveSect,IncentiveDept,IncentiveDiv," +
                      "DirectSupCode,DirectSupAchPct,DirectSupIncentive," +
                      "DeptMgrCode,DeptMgrAchPct,DeptMgrIncentive," +
                      "DivMgrCode,DivMgrAchPct,DivMgrIncentive");

        foreach (var r in rows)
        {
            sb.Append(r.PeriodCode).Append(',')
              .Append(r.UserEmployeeId).Append(',')
              .Append(r.SalesmanCode).Append(',')
              .Append(CsvEscape(r.EmployeeNameTh)).Append(',')
              .Append(r.PositionLevelCode).Append(',')
              .Append(CsvEscape(r.PositionNameEn)).Append(',')
              .Append(r.HierarchyLevel).Append(',')
              .Append(r.JobFunctionCode).Append(',')
              .Append(CsvEscape(r.JobFunctionNameEn)).Append(',')
              .Append(CsvEscape(r.DivisionName)).Append(',')
              .Append(CsvEscape(r.DepartmentName)).Append(',')
              .Append(CsvEscape(r.SectionName)).Append(',')
              .Append(r.VariablePayMonth?.ToString("yyyy-MM") ?? string.Empty).Append(',')
              .Append(r.PaymentMethod).Append(',')
              .Append(r.TotalVariable.ToString("0.00")).Append(',')
              .Append(r.IncentiveStaff.ToString("0.00")).Append(',')
              .Append(r.IncentiveSect.ToString("0.00")).Append(',')
              .Append(r.IncentiveDept.ToString("0.00")).Append(',')
              .Append(r.IncentiveDiv.ToString("0.00")).Append(',')
              .Append(r.DirectSupCode).Append(',')
              .Append(r.DirectSupAchPct.ToString("0.00")).Append(',')
              .Append(r.DirectSupIncentive.ToString("0.00")).Append(',')
              .Append(r.DeptMgrCode).Append(',')
              .Append(r.DeptMgrAchPct.ToString("0.00")).Append(',')
              .Append(r.DeptMgrIncentive.ToString("0.00")).Append(',')
              .Append(r.DivMgrCode).Append(',')
              .Append(r.DivMgrAchPct.ToString("0.00")).Append(',')
              .Append(r.DivMgrIncentive.ToString("0.00"))
              .AppendLine();
        }

        return sb.ToString();
    }

    public async Task<IActionResult> OnGetProrateDetailAsync(string employeeCode)
    {
        if (string.IsNullOrWhiteSpace(employeeCode) || PeriodId <= 0)
            return new JsonResult(Array.Empty<object>());

        var details = await _portalDataService.GetProrateDetailsAsync(PeriodId, ChannelId, employeeCode);
        return new JsonResult(details, new System.Text.Json.JsonSerializerOptions
        {
            PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase
        });
    }

    public async Task<IActionResult> OnGetSpecialAdjDetailAsync(string employeeCode)
    {
        if (string.IsNullOrWhiteSpace(employeeCode) || PeriodId <= 0)
            return new JsonResult(Array.Empty<object>());

        var details = await _portalDataService.GetSpecialAdjDetailsAsync(PeriodId, ChannelId, employeeCode);
        return new JsonResult(details, new System.Text.Json.JsonSerializerOptions
        {
            PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase
        });
    }

    private static string CsvEscape(string value)
    {
        if (string.IsNullOrEmpty(value)) return string.Empty;
        if (value.Contains(',') || value.Contains('"') || value.Contains('\n'))
            return $"\"{value.Replace("\"", "\"\"")}\"";
        return value;
    }
}
