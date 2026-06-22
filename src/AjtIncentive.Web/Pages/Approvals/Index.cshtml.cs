using Microsoft.AspNetCore.Mvc.RazorPages;
using AjtIncentive.Web.Services;

namespace AjtIncentive.Web.Pages.Approvals;

public class IndexModel : PageModel
{
    private readonly IPortalDataService _portalDataService;

    public IndexModel(IPortalDataService portalDataService)
    {
        _portalDataService = portalDataService;
    }

    public IReadOnlyList<CalcRunItem> Runs { get; private set; } = Array.Empty<CalcRunItem>();

    public async Task OnGetAsync()
    {
        Runs = await _portalDataService.GetRecentRunsAsync(20);
    }
}
