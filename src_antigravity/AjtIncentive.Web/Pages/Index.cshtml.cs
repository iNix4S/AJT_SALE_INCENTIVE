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
    public IReadOnlyList<DashboardChannelSummary> ChannelSummaries { get; private set; } = Array.Empty<DashboardChannelSummary>();

    public async Task OnGetAsync()
    {
        Snapshot = await _portalDataService.GetDashboardSnapshotAsync();
        RecentRuns = await _portalDataService.GetRecentRunsAsync(8);
        ChannelSummaries = await _portalDataService.GetDashboardChannelSummariesAsync();
    }
}
