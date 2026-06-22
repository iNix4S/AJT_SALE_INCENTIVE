using Microsoft.AspNetCore.Mvc.RazorPages;
using AjtIncentive.Web.Services;

namespace AjtIncentive.Web.Pages.Parameters;

public class IndexModel : PageModel
{
    private readonly IPortalDataService _portalDataService;

    public IndexModel(IPortalDataService portalDataService)
    {
        _portalDataService = portalDataService;
    }

    public IReadOnlyList<ChannelItem> Channels { get; private set; } = Array.Empty<ChannelItem>();
    public DashboardSnapshot Snapshot { get; private set; } = new();

    public async Task OnGetAsync()
    {
        Channels = await _portalDataService.GetChannelsAsync();
        Snapshot = await _portalDataService.GetDashboardSnapshotAsync();
    }
}
