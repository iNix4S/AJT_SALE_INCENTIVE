using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using AjtIncentive.Application.Interfaces;
using AjtIncentive.Web.Services;

namespace AjtIncentive.Web.Pages.Calculation;

public class IndexModel : PageModel
{
    private readonly ICalculationService _calculationService;
    private readonly IPortalDataService _portalDataService;

    public IndexModel(ICalculationService calculationService, IPortalDataService portalDataService)
    {
        _calculationService = calculationService;
        _portalDataService = portalDataService;
    }

    [BindProperty]
    public int MtPeriodId { get; set; }

    [BindProperty]
    public string TtPeriodCode { get; set; } = string.Empty;

    [BindProperty]
    public string TtWsType { get; set; } = "TOP_WS";

    [BindProperty]
    public int SiPeriodId { get; set; }

    [BindProperty]
    public int LaosPeriodId { get; set; }

    public IReadOnlyList<PeriodItem> Periods { get; private set; } = Array.Empty<PeriodItem>();
    public IReadOnlyList<ChannelItem> Channels { get; private set; } = Array.Empty<ChannelItem>();
    public IReadOnlyList<CalcRunItem> RecentRuns { get; private set; } = Array.Empty<CalcRunItem>();
    public DashboardSnapshot Snapshot { get; private set; } = new();

    public async Task OnGetAsync()
    {
        await LoadMasterDataAsync();
    }

    public async Task<IActionResult> OnPostRunMtAsync()
    {
        try
        {
            var calcRunId = await _calculationService.RunMtCalculationAsync(MtPeriodId);
            TempData["Message"] = $"MT Calculation started successfully. Calc Run ID: {calcRunId}";
        }
        catch (Exception ex)
        {
            TempData["Message"] = $"Error running MT Calculation: {ex.Message}";
        }

        return RedirectToPage();
    }

    public async Task<IActionResult> OnPostRunTtAsync()
    {
        try
        {
            var calcRunId = await _calculationService.RunTtCalculationAsync(TtPeriodCode, TtWsType);
            TempData["Message"] = $"TT Calculation started successfully. Calc Run ID: {calcRunId}";
        }
        catch (Exception ex)
        {
            TempData["Message"] = $"Error running TT Calculation: {ex.Message}";
        }

        return RedirectToPage();
    }

    public async Task<IActionResult> OnPostRunSiAsync()
    {
        try
        {
            var calcRunId = await _calculationService.RunSiCalculationAsync(SiPeriodId);
            TempData["Message"] = $"S&I Calculation started successfully. Calc Run ID: {calcRunId}";
        }
        catch (Exception ex)
        {
            TempData["Message"] = $"Error running S&I Calculation: {ex.Message}";
        }

        return RedirectToPage();
    }

    public async Task<IActionResult> OnPostRunLaosAsync()
    {
        try
        {
            var calcRunId = await _calculationService.RunLaosCalculationAsync(LaosPeriodId);
            TempData["Message"] = $"Laos Calculation started successfully. Calc Run ID: {calcRunId}";
        }
        catch (Exception ex)
        {
            TempData["Message"] = $"Error running Laos Calculation: {ex.Message}";
        }

        return RedirectToPage();
    }

    private async Task LoadMasterDataAsync()
    {
        Periods = await _portalDataService.GetPeriodsAsync();
        Channels = await _portalDataService.GetChannelsAsync();
        RecentRuns = await _portalDataService.GetRecentRunsAsync(10);
        Snapshot = await _portalDataService.GetDashboardSnapshotAsync();

        if (MtPeriodId <= 0)
        {
            MtPeriodId = Periods.FirstOrDefault()?.PeriodId ?? 1;
        }

        if (string.IsNullOrWhiteSpace(TtPeriodCode))
        {
            TtPeriodCode = Periods.FirstOrDefault()?.PeriodCode ?? "FY2026-04";
        }

        if (SiPeriodId <= 0)
        {
            SiPeriodId = MtPeriodId;
        }

        if (LaosPeriodId <= 0)
        {
            LaosPeriodId = MtPeriodId;
        }
    }
}
