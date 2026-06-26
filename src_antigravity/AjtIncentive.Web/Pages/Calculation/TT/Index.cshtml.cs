using AjtIncentive.Application.Interfaces;
using AjtIncentive.Web.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace AjtIncentive.Web.Pages.Calculation.TT;

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
            TempData["Message"] = "Please select a Period before running TT Calculation.";
            return Page();
        }

        var periodsTask = _portalDataService.GetPeriodsAsync();
        var wsTypesTask  = _portalDataService.GetTtWsTypesAsync();
        await Task.WhenAll(periodsTask, wsTypesTask);

        var periodCode = periodsTask.Result
            .FirstOrDefault(p => p.PeriodId == PeriodId)?.PeriodCode ?? string.Empty;

        if (string.IsNullOrWhiteSpace(periodCode))
        {
            TempData["Message"] = "Selected period was not found.";
            return RedirectToPage(new { PeriodId, ShowPreview = false });
        }

        var wsTypes   = wsTypesTask.Result;
        var successes = new List<string>();
        var errors    = new List<string>();

        foreach (var wsType in wsTypes)
        {
            try
            {
                var calcRunId = await _calculationService.RunTtCalculationAsync(periodCode, wsType);
                successes.Add($"{wsType} (Run {calcRunId})");
            }
            catch (Exception ex)
            {
                errors.Add($"{wsType}: {ex.Message}");
            }
        }

        var parts = new List<string>();
        if (successes.Count > 0)
            parts.Add($"Completed: {string.Join(", ", successes)}");
        if (errors.Count > 0)
            parts.Add($"Errors — {string.Join("; ", errors)}");

        TempData["Message"] = string.Join(" | ", parts);
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
        var readinessTask = _portalDataService.GetPeriodReadinessAsync(2);
        var wsTypesTask = _portalDataService.GetTtWsTypesAsync();
        var formulasTask = _portalDataService.GetFormulasByChannelAsync("TT");
        var historyTask = _portalDataService.GetCalcRunHistoryAsync(2, 10);

        await Task.WhenAll(periodsTask, readinessTask, wsTypesTask, formulasTask, historyTask);

        Periods = await periodsTask;
        Readiness = await readinessTask;
        WsTypes = await wsTypesTask;
        Formulas = await formulasTask;
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
            PreviewRows = (await _portalDataService.GetFormulaPreviewAsync(PeriodId, "TT"))
                .ToList();
        }
        catch
        {
            PreviewRows = Array.Empty<FormulaPreviewRow>();
        }
    }
}
