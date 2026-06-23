using Microsoft.AspNetCore.Mvc.RazorPages;
using AjtIncentive.Web.Services;

namespace AjtIncentive.Web.Pages.Calculation;

public class IndexModel : PageModel
{
    private readonly IPortalDataService _portalDataService;

    public IndexModel(IPortalDataService portalDataService)
    {
        _portalDataService = portalDataService;
    }

    public DashboardSnapshot Snapshot { get; private set; } = new();
    public IReadOnlyList<DashboardChannelSummary> ChannelSummaries { get; private set; } = Array.Empty<DashboardChannelSummary>();
    public IReadOnlyList<CalcRunItem> RecentRuns { get; private set; } = Array.Empty<CalcRunItem>();
    public IReadOnlyList<PeriodItem> Periods { get; private set; } = Array.Empty<PeriodItem>();

    public async Task OnGetAsync()
    {
        var snapshotTask = _portalDataService.GetDashboardSnapshotAsync();
        var channelsTask = _portalDataService.GetDashboardChannelSummariesAsync();
        var runsTask = _portalDataService.GetRecentRunsAsync(8);
        var periodsTask = _portalDataService.GetPeriodsAsync();

        await Task.WhenAll(snapshotTask, channelsTask, runsTask, periodsTask);

        Snapshot = await snapshotTask;
        ChannelSummaries = await channelsTask;
        RecentRuns = await runsTask;
        Periods = await periodsTask;
    }
}
