using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using AjtIncentive.Application.Interfaces;

namespace AjtIncentive.Web.Pages.Calculation;

public class IndexModel : PageModel
{
    private readonly ICalculationService _calculationService;

    public IndexModel(ICalculationService calculationService)
    {
        _calculationService = calculationService;
    }

    public void OnGet()
    {
    }

    public async Task<IActionResult> OnPostRunMtAsync(int periodId)
    {
        try
        {
            var calcRunId = await _calculationService.RunMtCalculationAsync(periodId);
            TempData["Message"] = $"MT Calculation started successfully. Calc Run ID: {calcRunId}";
        }
        catch (Exception ex)
        {
            TempData["Message"] = $"Error running MT Calculation: {ex.Message}";
        }

        return RedirectToPage();
    }

    public async Task<IActionResult> OnPostRunTtAsync(int periodId)
    {
        try
        {
            var calcRunId = await _calculationService.RunTtCalculationAsync(periodId);
            TempData["Message"] = $"TT Calculation started successfully. Calc Run ID: {calcRunId}";
        }
        catch (Exception ex)
        {
            TempData["Message"] = $"Error running TT Calculation: {ex.Message}";
        }

        return RedirectToPage();
    }
}
