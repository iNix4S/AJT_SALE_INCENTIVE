using Dapper;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Data.SqlClient;
using AjtIncentive.Web.Services;

namespace AjtIncentive.Web.Pages.Target;

public class IndexModel : PageModel
{
    private readonly IPortalDataService _portalDataService;
    private readonly string _connectionString;

    public IndexModel(IPortalDataService portalDataService, IConfiguration config)
    {
        _portalDataService = portalDataService;
        _connectionString = config.GetConnectionString("DefaultConnection")!;
    }

    [BindProperty(SupportsGet = true)] public int ChannelId { get; set; } = 1;
    [BindProperty(SupportsGet = true)] public int PeriodId { get; set; }
    [BindProperty(SupportsGet = true)] public string? Keyword { get; set; }
    [BindProperty(SupportsGet = true)] public long? EditId { get; set; }

    public IReadOnlyList<ChannelItem> Channels { get; private set; } = Array.Empty<ChannelItem>();
    public IReadOnlyList<PeriodItem> Periods { get; private set; } = Array.Empty<PeriodItem>();
    public IReadOnlyList<EmployeeItem> Employees { get; private set; } = Array.Empty<EmployeeItem>();
    public IReadOnlyList<ProductItem> Products { get; private set; } = Array.Empty<ProductItem>();
    public IReadOnlyList<TargetRow> TargetRows { get; private set; } = Array.Empty<TargetRow>();
    public TargetEditForm EditForm { get; private set; } = new();
    public string SelectedChannelCode { get; private set; } = string.Empty;
    public string SelectedPeriodCode { get; private set; } = string.Empty;
    public bool IsEditMode => EditForm.SalesTargetId.HasValue;

    public async Task OnGetAsync()
    {
        await LoadDataAsync();
    }

    public async Task<IActionResult> OnPostSaveAsync(
        long? salesTargetId,
        string salesmanCode,
        string productCode,
        decimal targetAmount,
        decimal? pctSalesman,
        string? approvedBy,
        DateTime? approvedAt)
    {
        try
        {
            await using var conn = new SqlConnection(_connectionString);

            if (salesTargetId.HasValue)
            {
                var affected = await conn.ExecuteAsync(@"
UPDATE dbo.trn_sales_target
SET salesman_code = @SalesmanCode,
    product_code = @ProductCode,
    target_amount = @TargetAmount,
    pct_salesman = @PctSalesman,
    approved_by = NULLIF(@ApprovedBy, ''),
    approved_at = @ApprovedAt,
    updated_at = SYSUTCDATETIME()
WHERE sales_target_id = @SalesTargetId
  AND period_id = @PeriodId
  AND channel_id = @ChannelId;",
                    new
                    {
                        SalesTargetId = salesTargetId.Value,
                        PeriodId,
                        ChannelId,
                        SalesmanCode = salesmanCode,
                        ProductCode = productCode,
                        TargetAmount = targetAmount,
                        PctSalesman = pctSalesman,
                        ApprovedBy = approvedBy,
                        ApprovedAt = approvedAt
                    });

                TempData["Message"] = affected > 0
                    ? $"อัปเดต Target ID {salesTargetId.Value} เรียบร้อย"
                    : "ไม่พบข้อมูล Target ที่ต้องการแก้ไข";
            }
            else
            {
                await conn.ExecuteAsync(@"
INSERT INTO dbo.trn_sales_target
    (period_id, channel_id, salesman_code, product_code, target_amount, pct_salesman, approved_by, approved_at)
VALUES
    (@PeriodId, @ChannelId, @SalesmanCode, @ProductCode, @TargetAmount, @PctSalesman, NULLIF(@ApprovedBy, ''), @ApprovedAt);",
                    new
                    {
                        PeriodId,
                        ChannelId,
                        SalesmanCode = salesmanCode,
                        ProductCode = productCode,
                        TargetAmount = targetAmount,
                        PctSalesman = pctSalesman,
                        ApprovedBy = approvedBy,
                        ApprovedAt = approvedAt
                    });

                TempData["Message"] = $"เพิ่ม Target สำหรับ {salesmanCode}/{productCode} เรียบร้อย";
            }
        }
        catch (Exception ex)
        {
            TempData["Message"] = $"Error: {ex.Message}";
        }

        return RedirectToPage(new { ChannelId, PeriodId, Keyword });
    }

    public async Task<IActionResult> OnPostDeleteAsync(long salesTargetId)
    {
        try
        {
            await using var conn = new SqlConnection(_connectionString);
            var affected = await conn.ExecuteAsync(@"
DELETE FROM dbo.trn_sales_target
WHERE sales_target_id = @SalesTargetId
  AND period_id = @PeriodId
  AND channel_id = @ChannelId;",
                new { SalesTargetId = salesTargetId, PeriodId, ChannelId });

            TempData["Message"] = affected > 0
                ? "ลบ Target เรียบร้อย"
                : "ไม่พบข้อมูล Target ที่ต้องการลบ";
        }
        catch (Exception ex)
        {
            TempData["Message"] = $"Error: {ex.Message}";
        }

        return RedirectToPage(new { ChannelId, PeriodId, Keyword });
    }

    private async Task LoadDataAsync()
    {
        Channels = await _portalDataService.GetChannelsAsync();
        Periods = await _portalDataService.GetPeriodsAsync();

        if (PeriodId == 0 && Periods.Count > 0)
        {
            PeriodId = Periods[0].PeriodId;
        }

        var ch = Channels.FirstOrDefault(c => c.ChannelId == ChannelId);
        var pr = Periods.FirstOrDefault(p => p.PeriodId == PeriodId);
        SelectedChannelCode = ch?.ChannelCode ?? string.Empty;
        SelectedPeriodCode = pr?.PeriodCode ?? string.Empty;

        await using var conn = new SqlConnection(_connectionString);

        Employees = (await conn.QueryAsync<EmployeeItem>(@"
SELECT employee_code AS EmployeeCode,
       employee_name_th AS EmployeeNameTh
FROM dbo.mst_employee
WHERE is_active = 1
  AND channel_id = @ChannelId
ORDER BY employee_code;",
            new { ChannelId })).ToList();

        Products = (await conn.QueryAsync<ProductItem>(@"
SELECT product_code AS ProductCode,
       product_name_th AS ProductNameTh
FROM dbo.mst_product
WHERE is_active = 1
ORDER BY product_code;")).ToList();

        var keyword = string.IsNullOrWhiteSpace(Keyword) ? null : Keyword.Trim();
        TargetRows = (await conn.QueryAsync<TargetRow>(@"
SELECT t.sales_target_id AS SalesTargetId,
       t.period_id AS PeriodId,
       p.period_code AS PeriodCode,
       t.channel_id AS ChannelId,
       c.channel_code AS ChannelCode,
       t.salesman_code AS SalesmanCode,
       e.employee_name_th AS EmployeeNameTh,
       t.product_code AS ProductCode,
       pr.product_name_th AS ProductNameTh,
       t.target_amount AS TargetAmount,
       t.pct_salesman AS PctSalesman,
       t.approved_by AS ApprovedBy,
       t.approved_at AS ApprovedAt
FROM dbo.trn_sales_target t
INNER JOIN dbo.mst_period p ON p.period_id = t.period_id
INNER JOIN dbo.mst_channel c ON c.channel_id = t.channel_id
LEFT JOIN dbo.mst_employee e ON e.employee_code = t.salesman_code AND e.channel_id = t.channel_id
LEFT JOIN dbo.mst_product pr ON pr.product_code = t.product_code
WHERE t.channel_id = @ChannelId
  AND t.period_id = @PeriodId
  AND (
      @Keyword IS NULL
      OR t.salesman_code LIKE '%' + @Keyword + '%'
      OR ISNULL(e.employee_name_th, '') LIKE '%' + @Keyword + '%'
      OR t.product_code LIKE '%' + @Keyword + '%'
      OR ISNULL(pr.product_name_th, '') LIKE '%' + @Keyword + '%'
  )
ORDER BY t.salesman_code, t.product_code, t.sales_target_id;",
            new { ChannelId, PeriodId, Keyword = keyword })).ToList();

        if (EditId.HasValue)
        {
            var edit = TargetRows.FirstOrDefault(r => r.SalesTargetId == EditId.Value);
            if (edit is not null)
            {
                EditForm = new TargetEditForm
                {
                    SalesTargetId = edit.SalesTargetId,
                    SalesmanCode = edit.SalesmanCode,
                    ProductCode = edit.ProductCode,
                    TargetAmount = edit.TargetAmount,
                    PctSalesman = edit.PctSalesman,
                    ApprovedBy = edit.ApprovedBy,
                    ApprovedAt = edit.ApprovedAt
                };
                return;
            }
        }

        EditForm = new TargetEditForm();

        if (Employees.Count > 0)
        {
            EditForm.SalesmanCode = Employees[0].EmployeeCode;
        }

        if (Products.Count > 0)
        {
            EditForm.ProductCode = Products[0].ProductCode;
        }
    }
}

public sealed class TargetRow
{
    public long SalesTargetId { get; init; }
    public int PeriodId { get; init; }
    public string PeriodCode { get; init; } = string.Empty;
    public int ChannelId { get; init; }
    public string ChannelCode { get; init; } = string.Empty;
    public string SalesmanCode { get; init; } = string.Empty;
    public string? EmployeeNameTh { get; init; }
    public string ProductCode { get; init; } = string.Empty;
    public string? ProductNameTh { get; init; }
    public decimal TargetAmount { get; init; }
    public decimal? PctSalesman { get; init; }
    public string? ApprovedBy { get; init; }
    public DateTime? ApprovedAt { get; init; }
}

public sealed class TargetEditForm
{
    public long? SalesTargetId { get; init; }
    public string SalesmanCode { get; set; } = string.Empty;
    public string ProductCode { get; set; } = string.Empty;
    public decimal TargetAmount { get; set; }
    public decimal? PctSalesman { get; set; }
    public string? ApprovedBy { get; set; }
    public DateTime? ApprovedAt { get; set; }
}

public sealed class EmployeeItem
{
    public string EmployeeCode { get; init; } = string.Empty;
    public string EmployeeNameTh { get; init; } = string.Empty;
}

public sealed class ProductItem
{
    public string ProductCode { get; init; } = string.Empty;
    public string ProductNameTh { get; init; } = string.Empty;
}
