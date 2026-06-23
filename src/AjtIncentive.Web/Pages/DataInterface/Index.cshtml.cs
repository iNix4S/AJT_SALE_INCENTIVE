using AjtIncentive.Web.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace AjtIncentive.Web.Pages.DataInterface;

public class IndexModel : PageModel
{
    private readonly IDataInterfaceService _dataInterfaceService;
    private readonly IPortalDataService _portalDataService;

    public IndexModel(IDataInterfaceService dataInterfaceService, IPortalDataService portalDataService)
    {
        _dataInterfaceService = dataInterfaceService;
        _portalDataService = portalDataService;
    }

    [BindProperty(SupportsGet = true)]
    public int PeriodId { get; set; }

    [BindProperty(SupportsGet = true)]
    public bool ShowDetails { get; set; }

    public IReadOnlyList<PeriodItem> Periods { get; private set; } = Array.Empty<PeriodItem>();
    public ValidationGateResult? GateResult { get; private set; }

    // Convenience properties for the view
    public ValidationRunSummary? Summary => GateResult?.Summary;
    public StagingDataStatus? StagingStatus => GateResult?.StagingStatus;
    public IReadOnlyList<ValidationCheckResult> Checks => GateResult?.Checks ?? Array.Empty<ValidationCheckResult>();
    public IReadOnlyList<ValidationRunHistoryItem> RecentRuns => GateResult?.RecentRuns ?? Array.Empty<ValidationRunHistoryItem>();

    public async Task OnGetAsync()
    {
        await LoadAsync();
    }

    public async Task<IActionResult> OnPostRunValidationAsync()
    {
        if (PeriodId <= 0)
        {
            TempData["Message"] = "Please select a period before running validation.";
            return RedirectToPage(new { PeriodId, ShowDetails = false });
        }

        var periods = await _portalDataService.GetPeriodsAsync();
        var period = periods.FirstOrDefault(p => p.PeriodId == PeriodId);
        if (period is null)
        {
            TempData["Message"] = "Period not found.";
            return RedirectToPage(new { PeriodId, ShowDetails = false });
        }

        var runBy = User.Identity?.Name ?? "system";

        try
        {
            var summary = await _dataInterfaceService.RunValidationGateAsync(period.PeriodCode, runBy);
            var status = summary?.OverallStatus ?? "UNKNOWN";
            TempData["Message"] = $"Validation Gate completed for {period.PeriodCode} — Overall: {status}";
        }
        catch (Exception ex)
        {
            TempData["Message"] = $"Validation error: {ex.Message}";
        }

        return RedirectToPage(new { PeriodId, ShowDetails = true });
    }

    public IActionResult OnPostProceed()
    {
        return Redirect("/Calculation");
    }

    private async Task LoadAsync()
    {
        Periods = await _portalDataService.GetPeriodsAsync();

        if (PeriodId <= 0)
            PeriodId = Periods.FirstOrDefault()?.PeriodId ?? 0;

        if (PeriodId <= 0) return;

        // Always load summary + staging counts + recent runs
        var statusResult = await _dataInterfaceService.GetStatusAsync(PeriodId);

        // If ShowDetails and there is a previous run result, also load error rows
        if (ShowDetails && statusResult.Summary is not null)
        {
            var salesMonth = statusResult.Summary.SalesMonth;

            var biErrorsTask  = _dataInterfaceService.GetBiErrorsAsync(salesMonth);
            var hrErrorsTask  = _dataInterfaceService.GetHrErrorsAsync(salesMonth);
            var mtGapsTask    = _dataInterfaceService.GetMtMappingGapsAsync(salesMonth);

            await Task.WhenAll(biErrorsTask, hrErrorsTask, mtGapsTask);

            GateResult = statusResult with
            {
                BiErrors      = await biErrorsTask,
                HrErrors      = await hrErrorsTask,
                MtMappingGaps = await mtGapsTask,
            };
        }
        else
        {
            GateResult = statusResult;
        }
    }
}
