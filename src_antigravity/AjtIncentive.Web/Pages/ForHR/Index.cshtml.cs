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

    public async Task OnGetAsync()
    {
        await LoadDataAsync();
    }

    public async Task<IActionResult> OnGetExportCsvAsync()
    {
        await LoadDataAsync();

        if (CalcRunId is null || Rows.Count == 0)
        {
            TempData["Message"] = "ไม่พบข้อมูล For HR ตาม Channel และ Period ที่เลือก";
            return RedirectToPage(new { ChannelId, PeriodId });
        }

        var csv = BuildCsv(Rows);
        var fileName = $"for-hr-channel-{ChannelId}-period-{PeriodId}-run-{CalcRunId}.csv";
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
            Rows = await _portalDataService.GetForHrRowsAsync(effectiveCalcRunId.Value, 1000);
        }
    }

    private static string BuildCsv(IReadOnlyList<ForHrRow> rows)
    {
        var sb = new StringBuilder();
        sb.AppendLine("EmployeeCode,PositionLevelCode,TotalVariable");

        foreach (var row in rows)
        {
            sb.Append(row.EmployeeCode).Append(',')
              .Append(row.PositionLevelCode).Append(',')
              .Append(row.TotalVariable.ToString("0.00"))
              .AppendLine();
        }

        return sb.ToString();
    }
}
