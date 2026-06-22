using Microsoft.AspNetCore.Mvc.RazorPages;
using AjtIncentive.Web.Services;

namespace AjtIncentive.Web.Pages.Periods;

public class IndexModel : PageModel
{
    private readonly IPortalDataService _portalDataService;

    public IndexModel(IPortalDataService portalDataService)
    {
        _portalDataService = portalDataService;
    }

    public IReadOnlyList<PeriodItem> Periods { get; private set; } = Array.Empty<PeriodItem>();

    public async Task OnGetAsync()
    {
        Periods = await _portalDataService.GetPeriodsAsync();
    }
}
