using AjtIncentive.Application.Interfaces;
using AjtIncentive.Web.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace AjtIncentive.Web.Pages.Calculation.LAOS;

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
    public IReadOnlyList<string> WsTypes { get; private set; } = Array.Empty<string>();
    public IReadOnlyList<FormulaExpression> Formulas { get; private set; } = Array.Empty<FormulaExpression>();
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
            TempData["Message"] = "Please select a Period before running LAOS Calculation.";
            return Page();
        }

        try
        {
            var calcRunId = await _calculationService.RunLaosCalculationAsync(PeriodId);
            TempData["Message"] = $"LAOS Calculation completed. Calc Run ID: {calcRunId}";
        }
        catch (Exception ex)
        {
            TempData["Message"] = $"Error running LAOS Calculation: {ex.Message}";
        }

        return RedirectToPage(new { PeriodId, ShowPreview = false });
    }

    public IActionResult OnPostPreview()
    {
        if (PeriodId <= 0)
        {
            TempData["Message"] = "Please select a Period before Preview.";
            return RedirectToPage(new { ShowPreview = false });
        }

        return RedirectToPage(new { PeriodId, ShowPreview = true });
    }

    private async Task LoadAsync()
    {
        var periodsTask = _portalDataService.GetPeriodsAsync();
        var readinessTask = _portalDataService.GetPeriodReadinessAsync(4);
        var wsTypesTask = _portalDataService.GetTtWsTypesAsync();
        var formulasTask = _portalDataService.GetFormulasByChannelAsync("LAOS");
        var historyTask = _portalDataService.GetCalcRunHistoryAsync(4, 10);

        await Task.WhenAll(periodsTask, readinessTask, wsTypesTask, formulasTask, historyTask);

        Periods = await periodsTask;
        Readiness = await readinessTask;
        Formulas = await formulasTask;
        RunHistory = await historyTask;
        WsTypes = (await wsTypesTask).Distinct(StringComparer.OrdinalIgnoreCase).ToList();

        if (WsTypes.Count == 0)
        {
            WsTypes = new[] { "TOP_WS", "WS_SF" };
        }

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
            PreviewRows = (await _portalDataService.GetFormulaPreviewAsync(PeriodId, "LAOS"))
                .ToList();
        }
        catch
        {
            PreviewRows = Array.Empty<FormulaPreviewRow>();
        }
    }
}
