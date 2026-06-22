using Microsoft.AspNetCore.Mvc.RazorPages;
using AjtIncentive.Web.Services;

namespace AjtIncentive.Web.Pages;

public class IndexModel : PageModel
{
    private readonly IPortalDataService _portalDataService;

    public IndexModel(IPortalDataService portalDataService)
    {
        _portalDataService = portalDataService;
    }

    public DashboardSnapshot Snapshot { get; private set; } = new();
    public IReadOnlyList<CalcRunItem> RecentRuns { get; private set; } = Array.Empty<CalcRunItem>();

    public async Task OnGetAsync()
    {
        Snapshot = await _portalDataService.GetDashboardSnapshotAsync();
        RecentRuns = await _portalDataService.GetRecentRunsAsync(8);

    }
}
