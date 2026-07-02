using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using System.Text.Json;
using AjtIncentive.Web.Services;

namespace AjtIncentive.Web.Pages;

public class IndexModel : PageModel
{
    private static readonly JsonSerializerOptions CamelCaseJson = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    private readonly IPortalDataService _portalDataService;

    public IndexModel(IPortalDataService portalDataService)
    {
        _portalDataService = portalDataService;
    }

    public DashboardSnapshot Snapshot { get; private set; } = new();
    public IReadOnlyList<CalcRunItem> RecentRuns { get; private set; } = Array.Empty<CalcRunItem>();
    public IReadOnlyList<DashboardChannelSummary> ChannelSummaries { get; private set; } = Array.Empty<DashboardChannelSummary>();
    public ExecutiveSummary ExecutiveSummary { get; private set; } = new();
    public IReadOnlyList<PeriodIncentiveTrendItem> IncentiveTrend { get; private set; } = Array.Empty<PeriodIncentiveTrendItem>();
    public IReadOnlyList<TopEmployeeItem> TopEmployees { get; private set; } = Array.Empty<TopEmployeeItem>();
    public IReadOnlyList<ChannelSalesPerformance> ChannelSales { get; private set; } = Array.Empty<ChannelSalesPerformance>();
    public IReadOnlyList<PeriodSalesTrendItem> SalesTrend { get; private set; } = Array.Empty<PeriodSalesTrendItem>();
    public IReadOnlyList<EmployeeListItem> EmployeeOptions { get; private set; } = Array.Empty<EmployeeListItem>();

    public string ChannelChartDataJson { get; private set; } = "[]";
    public string TrendChartDataJson { get; private set; } = "[]";
    public string ChannelSalesChartDataJson { get; private set; } = "[]";
    public string SalesTrendChartDataJson { get; private set; } = "[]";

    public async Task OnGetAsync()
    {
        Snapshot = await _portalDataService.GetDashboardSnapshotAsync();
        RecentRuns = await _portalDataService.GetRecentRunsAsync(8);
        ChannelSummaries = await _portalDataService.GetDashboardChannelSummariesAsync();
        ExecutiveSummary = await _portalDataService.GetExecutiveSummaryAsync();
        IncentiveTrend = await _portalDataService.GetIncentiveTrendAsync(12);
        TopEmployees = await _portalDataService.GetTopEmployeesAsync(10);
        ChannelSales = await _portalDataService.GetChannelSalesPerformanceAsync();
        SalesTrend = await _portalDataService.GetSalesTrendAsync(12);
        EmployeeOptions = await _portalDataService.GetActiveEmployeesAsync();

        ChannelChartDataJson = JsonSerializer.Serialize(
            ExecutiveSummary.ChannelBreakdown.Select(c => new { c.ChannelCode, c.TotalIncentive }),
            CamelCaseJson);

        TrendChartDataJson = JsonSerializer.Serialize(
            IncentiveTrend.Select(t => new { t.PeriodCode, t.TotalIncentive }),
            CamelCaseJson);

        ChannelSalesChartDataJson = JsonSerializer.Serialize(
            ChannelSales.Select(c => new { c.ChannelCode, c.TargetAmount, c.ActualAmount }),
            CamelCaseJson);

        SalesTrendChartDataJson = JsonSerializer.Serialize(
            SalesTrend.Select(t => new { t.PeriodCode, t.TargetAmount, t.ActualAmount }),
            CamelCaseJson);
    }

    public async Task<IActionResult> OnGetEmployeeProfileAsync(string employeeCode)
    {
        if (string.IsNullOrWhiteSpace(employeeCode))
            return new JsonResult(null);

        var profile = await _portalDataService.GetEmployeeIncentiveProfileAsync(employeeCode.Trim());
        return new JsonResult(profile, new System.Text.Json.JsonSerializerOptions
        {
            PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase
        });
    }
}
