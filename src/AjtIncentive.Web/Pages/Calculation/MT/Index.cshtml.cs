using AjtIncentive.Application.Interfaces;
using AjtIncentive.Web.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace AjtIncentive.Web.Pages.Calculation.MT;

public class IndexModel : PageModel
{
    private readonly ICalculationService _calculationService;
    private readonly IPortalDataService _portalDataService;

    public IndexModel(ICalculationService calculationService, IPortalDataService portalDataService)
    {
        _calculationService = calculationService;
        _portalDataService = portalDataService;
    }

    [BindProperty(SupportsGet = true)]
    public int PeriodId { get; set; }

    [BindProperty(SupportsGet = true)]
    public bool ShowPreview { get; set; }

    public IReadOnlyList<PeriodItem> Periods { get; private set; } = Array.Empty<PeriodItem>();
    public IReadOnlyDictionary<int, PeriodReadiness> Readiness { get; private set; } = new Dictionary<int, PeriodReadiness>();
    public IReadOnlyList<CalcRunHistoryItem> RunHistory { get; private set; } = Array.Empty<CalcRunHistoryItem>();
    public IReadOnlyList<FormulaPreviewRow> PreviewRows { get; private set; } = Array.Empty<FormulaPreviewRow>();

    public async Task OnGetAsync()
    {
        await LoadAsync();
    }

    public async Task<IActionResult> OnPostRunAsync()
    {
        if (PeriodId <= 0)
        {
            await LoadAsync();
            TempData["Message"] = "กรุณาเลือก Period ก่อนรัน MT Calculation";
            return Page();
        }

        try
        {
            var calcRunId = await _calculationService.RunMtCalculationAsync(PeriodId);
            TempData["Message"] = $"MT Calculation started successfully. Calc Run ID: {calcRunId}";
        }
        catch (Exception ex)
        {
            TempData["Message"] = $"Error running MT Calculation: {ex.Message}";
        }

        return RedirectToPage(new { PeriodId, ShowPreview });
    }

    public IActionResult OnPostPreview()
    {
        if (PeriodId <= 0)
        {
            TempData["Message"] = "กรุณาเลือก Period ก่อน Preview";
            return RedirectToPage(new { ShowPreview = false });
        }

        return RedirectToPage(new { PeriodId, ShowPreview = true });
    }

    private async Task LoadAsync()
    {
        var periodsTask = _portalDataService.GetPeriodsAsync();
        var readinessTask = _portalDataService.GetPeriodReadinessAsync(1);
        var historyTask = _portalDataService.GetCalcRunHistoryAsync(1, 10);

        await Task.WhenAll(periodsTask, readinessTask, historyTask);

        Periods = await periodsTask;
        Readiness = await readinessTask;
        RunHistory = await historyTask;

        if (PeriodId <= 0)
        {
            PeriodId = Periods.FirstOrDefault()?.PeriodId ?? 1;
        }

        if (!ShowPreview)
        {
            PreviewRows = Array.Empty<FormulaPreviewRow>();
            return;
        }

        try
        {
            PreviewRows = await _portalDataService.GetFormulaPreviewAsync(PeriodId, "MT");
        }
        catch
        {
            PreviewRows = Array.Empty<FormulaPreviewRow>();
        }
    }
}
