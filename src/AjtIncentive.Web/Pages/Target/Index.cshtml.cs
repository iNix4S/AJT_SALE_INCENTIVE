using Dapper;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Data.SqlClient;
using AjtIncentive.Web.Services;
using System.IO.Compression;
using System.Text;
using System.Data;

namespace AjtIncentive.Web.Pages.Target;

public class IndexModel : PageModel
{
    private readonly IPortalDataService _portalDataService;
    private readonly ITargetImportService _importService;
    private readonly string _connectionString;

    public IndexModel(
        IPortalDataService portalDataService,
        ITargetImportService importService,
        IConfiguration config)
    {
        _portalDataService = portalDataService;
        _importService = importService;
        _connectionString = config.GetConnectionString("DefaultConnection")!;
    }

    [BindProperty(SupportsGet = true)] public int ChannelId { get; set; } = 1;
    [BindProperty(SupportsGet = true)] public int PeriodId { get; set; }
    [BindProperty(SupportsGet = true)] public string? Keyword { get; set; }
    [BindProperty(SupportsGet = true)] public string? FilterSalesmanCode { get; set; }
    [BindProperty(SupportsGet = true)] public string? FilterProductCode { get; set; }
    [BindProperty(SupportsGet = true)] public string? FilterApprovedBy { get; set; }
    [BindProperty(SupportsGet = true)] public string? ActiveTab { get; set; }
    [BindProperty(SupportsGet = true)] public long? EditId { get; set; }
    [BindProperty(SupportsGet = true)] public int PageNumber { get; set; } = 1;

    public IReadOnlyList<ChannelItem> Channels { get; private set; } = Array.Empty<ChannelItem>();
    public IReadOnlyList<PeriodItem> Periods { get; private set; } = Array.Empty<PeriodItem>();
    public IReadOnlyList<EmployeeItem> Employees { get; private set; } = Array.Empty<EmployeeItem>();
    public IReadOnlyList<ProductItem> Products { get; private set; } = Array.Empty<ProductItem>();
    public IReadOnlyList<TargetRow> TargetRows { get; private set; } = Array.Empty<TargetRow>();
    public IReadOnlyList<TargetRow> PagedTargetRows { get; private set; } = Array.Empty<TargetRow>();
    public IReadOnlyList<string> ApprovedByOptions { get; private set; } = Array.Empty<string>();
    public TargetEditForm EditForm { get; private set; } = new();
    public string SelectedChannelCode { get; private set; } = string.Empty;
    public string SelectedPeriodCode { get; private set; } = string.Empty;
    public bool IsEditMode => EditForm.SalesTargetId.HasValue;
    public const int PageSize = 20;
    public int TotalRows => TargetRows.Count;
    public int TotalPages => Math.Max(1, (int)Math.Ceiling(TotalRows / (double)PageSize));

    // Import-related properties
    public ImportValidationResult? ImportPreview { get; set; }
    public string ImportMessage { get; set; } = string.Empty;

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

            var parameters = new DynamicParameters();
            parameters.Add("SalesTargetId", salesTargetId, dbType: DbType.Int64, direction: ParameterDirection.InputOutput);
            parameters.Add("PeriodId", PeriodId);
            parameters.Add("ChannelId", ChannelId);
            parameters.Add("SalesmanCode", salesmanCode);
            parameters.Add("ProductCode", productCode);
            parameters.Add("TargetAmount", targetAmount);
            parameters.Add("PctSalesman", pctSalesman);
            parameters.Add("ApprovedBy", approvedBy);
            parameters.Add("ApprovedAt", approvedAt);

            await conn.ExecuteAsync(
                "dbo.usp_trn_sales_target_upsert",
                parameters,
                commandType: CommandType.StoredProcedure);

            var savedId = parameters.Get<long>("SalesTargetId");
            TempData["Message"] = salesTargetId.HasValue
                ? $"อัปเดต Target ID {savedId} เรียบร้อย"
                : $"เพิ่ม Target สำหรับ {salesmanCode}/{productCode} เรียบร้อย (ID={savedId})";
        }
        catch (Exception ex)
        {
            TempData["Message"] = $"Error: {ex.Message}";
        }

        return RedirectToPage(new { ChannelId, PeriodId, Keyword, FilterSalesmanCode, FilterProductCode, FilterApprovedBy, PageNumber, ActiveTab = "manage" });
    }

    public async Task<IActionResult> OnPostDeleteAsync(long salesTargetId)
    {
        try
        {
            await using var conn = new SqlConnection(_connectionString);
                        var affected = await conn.ExecuteScalarAsync<int>(
                                "dbo.usp_trn_sales_target_delete",
                                new { SalesTargetId = salesTargetId, PeriodId, ChannelId },
                                commandType: CommandType.StoredProcedure);

            TempData["Message"] = affected > 0
                ? "ลบ Target เรียบร้อย"
                : "ไม่พบข้อมูล Target ที่ต้องการลบ";
        }
        catch (Exception ex)
        {
            TempData["Message"] = $"Error: {ex.Message}";
        }

        return RedirectToPage(new { ChannelId, PeriodId, Keyword, FilterSalesmanCode, FilterProductCode, FilterApprovedBy, PageNumber, ActiveTab = "manage" });
    }

    public async Task<IActionResult> OnPostUploadAsync(IFormFile? targetFile)
    {
        try
        {
            if (targetFile == null || targetFile.Length == 0)
            {
                ImportMessage = "Error: ไม่พบไฟล์ที่อัปโหลด";
                await LoadDataAsync();
                return Page();
            }

            // Validate file type
            var allowedExtensions = new[] { ".csv", ".xlsx", ".xls" };
            var fileExt = Path.GetExtension(targetFile.FileName).ToLower();
            if (!allowedExtensions.Contains(fileExt))
            {
                ImportMessage = $"Error: ประเภทไฟล์ '{fileExt}' ไม่ได้รับการสนับสนุน (CSV, XLSX เท่านั้น)";
                await LoadDataAsync();
                return Page();
            }

            // Read master data for validation
            var (salesmanCodes, productCodes) = await GetMasterCodesAsync();

            // Parse and validate file
            using var stream = targetFile.OpenReadStream();
            ImportPreview = await _importService.ParseAndValidateAsync(
                stream,
                targetFile.FileName,
                salesmanCodes,
                productCodes);

            await LoadDataAsync();

            // Store preview in session for confirmation (serialize to JSON bytes)
            var previewJson = System.Text.Json.JsonSerializer.Serialize(ImportPreview);
            var previewBytes = System.Text.Encoding.UTF8.GetBytes(previewJson);
            HttpContext.Session.Set("ImportPreview", previewBytes);

            ImportMessage = $"✅ อัปโหลดไฟล์เรียบร้อย — {ImportPreview.TotalRows} แถว, {ImportPreview.ValidRowCount} ถูกต้อง, {ImportPreview.ErrorRowCount} error";
            return Page();
        }
        catch (Exception ex)
        {
            ImportMessage = $"Error: {ex.Message}";
            await LoadDataAsync();
            return Page();
        }
    }

    public async Task<IActionResult> OnPostImportAsync()
    {
        try
        {
            // Retrieve preview from session
            if (!HttpContext.Session.TryGetValue("ImportPreview", out var previewData))
            {
                TempData["Message"] = "Error: ไม่พบข้อมูล preview — โปรดอัปโหลดไฟล์ใหม่";
                return RedirectToPage(new { ChannelId, PeriodId, FilterSalesmanCode, FilterProductCode, FilterApprovedBy, PageNumber, ActiveTab = "manage" });
            }

            var preview = System.Text.Json.JsonSerializer.Deserialize<ImportValidationResult>(
                System.Text.Encoding.UTF8.GetString(previewData));

            if (preview == null || preview.ValidRows.Count == 0)
            {
                TempData["Message"] = "Error: ไม่มีแถวที่ถูกต้องเพื่อนำเข้า";
                return RedirectToPage(new { ChannelId, PeriodId, FilterSalesmanCode, FilterProductCode, FilterApprovedBy, PageNumber, ActiveTab = "manage" });
            }

            // Bulk insert valid rows
            await using var conn = new SqlConnection(_connectionString);
            await conn.OpenAsync();

            var insertedCount = 0;
            foreach (var row in preview.ValidRows)
            {
                var parameters = new DynamicParameters();
                parameters.Add("SalesTargetId", dbType: DbType.Int64, direction: ParameterDirection.Output);
                parameters.Add("PeriodId", PeriodId);
                parameters.Add("ChannelId", ChannelId);
                parameters.Add("SalesmanCode", row.SalesmanCode);
                parameters.Add("ProductCode", row.ProductCode);
                parameters.Add("TargetAmount", row.TargetAmount);
                parameters.Add("PctSalesman", row.PctSalesman);
                parameters.Add("ApprovedBy", row.ApprovedBy ?? string.Empty);
                parameters.Add("ApprovedAt", row.ApprovedAt);

                await conn.ExecuteAsync(
                    "dbo.usp_trn_sales_target_upsert",
                    parameters,
                    commandType: CommandType.StoredProcedure);
                insertedCount++;
            }

            // Clear session
            HttpContext.Session.Remove("ImportPreview");

            TempData["Message"] = $"✅ นำเข้า {insertedCount} แถวเรียบร้อย";
            return RedirectToPage(new { ChannelId, PeriodId, FilterSalesmanCode, FilterProductCode, FilterApprovedBy, PageNumber, ActiveTab = "manage" });
        }
        catch (Exception ex)
        {
            TempData["Message"] = $"Error: {ex.Message}";
            return RedirectToPage(new { ChannelId, PeriodId, FilterSalesmanCode, FilterProductCode, FilterApprovedBy, PageNumber, ActiveTab = "manage" });
        }
    }

    public async Task<IActionResult> OnGetDownloadTemplate()
    {
        try
        {
            var bytes = await BuildTemplatePackAsync();
            return File(bytes, "application/zip", "target-template-pack.zip");
        }
        catch (Exception ex)
        {
            TempData["Message"] = $"Error: {ex.Message}";
            return RedirectToPage();
        }
    }

    private async Task<byte[]> BuildTemplatePackAsync()
    {
        var channels = (await _portalDataService.GetChannelsAsync())
            .Where(channel => channel.IsActive)
            .OrderBy(channel => channel.ChannelId)
            .ToList();

        var periods = (await _portalDataService.GetPeriodsAsync())
            .OrderBy(period => period.PeriodId)
            .ToList();

        await using var conn = new SqlConnection(_connectionString);

        var productCode = await conn.ExecuteScalarAsync<string>(@"
SELECT TOP (1) product_code
FROM dbo.mst_product
WHERE is_active = 1
ORDER BY product_code;");

        var salesmanRows = (await conn.QueryAsync<TemplateSalesmanRow>(@"
SELECT channel_id AS ChannelId,
       employee_code AS EmployeeCode
FROM dbo.mst_employee
WHERE is_active = 1
ORDER BY channel_id, employee_code;")).ToList();

        using var zipStream = new MemoryStream();
        using (var archive = new ZipArchive(zipStream, ZipArchiveMode.Create, leaveOpen: true))
        {
            var readmeEntry = archive.CreateEntry("README.txt");
            await using (var writer = new StreamWriter(readmeEntry.Open(), Encoding.UTF8, leaveOpen: false))
            {
                await writer.WriteLineAsync("Target template pack generated from current database data.");
                await writer.WriteLineAsync("Each CSV is tailored for one channel and a period that currently has no target rows.");
                await writer.WriteLineAsync("Use the matching Channel + Period selection on the Target page before uploading.");
                await writer.WriteLineAsync(string.Empty);
                await writer.WriteLineAsync("Files included:");

                foreach (var channel in channels)
                {
                    var readiness = await _portalDataService.GetPeriodReadinessAsync(channel.ChannelId);
                    var emptyPeriod = periods.FirstOrDefault(period =>
                        readiness.TryGetValue(period.PeriodId, out var periodStatus) && periodStatus.TargetRows == 0)
                        ?? periods.FirstOrDefault();

                    var salesmanCode = salesmanRows.FirstOrDefault(row => row.ChannelId == channel.ChannelId)?.EmployeeCode ?? string.Empty;
                    await writer.WriteLineAsync($"- {channel.ChannelCode}: {(emptyPeriod?.PeriodCode ?? "N/A")}");
                }
            }

            foreach (var channel in channels)
            {
                var readiness = await _portalDataService.GetPeriodReadinessAsync(channel.ChannelId);
                var emptyPeriod = periods.FirstOrDefault(period =>
                    readiness.TryGetValue(period.PeriodId, out var periodStatus) && periodStatus.TargetRows == 0)
                    ?? periods.FirstOrDefault();

                var salesmanCode = salesmanRows.FirstOrDefault(row => row.ChannelId == channel.ChannelId)?.EmployeeCode;
                if (string.IsNullOrWhiteSpace(salesmanCode) || string.IsNullOrWhiteSpace(productCode) || emptyPeriod is null)
                {
                    continue;
                }

                var csvContent = BuildTemplateCsv(
                    channel.ChannelCode,
                    emptyPeriod.PeriodCode,
                    salesmanCode,
                    productCode);

                var entry = archive.CreateEntry($"target-template-{channel.ChannelCode}-{emptyPeriod.PeriodCode}.csv");
                await using var entryWriter = new StreamWriter(entry.Open(), new UTF8Encoding(false), leaveOpen: false);
                await entryWriter.WriteAsync(csvContent);
            }
        }

        return zipStream.ToArray();
    }

    private static string BuildTemplateCsv(string channelCode, string periodCode, string salesmanCode, string productCode)
    {
        var builder = new StringBuilder();
        builder.AppendLine("Salesman Code,Product Code,Target Amount,Pct Salesman,Approved By,Approved At");
        builder.AppendLine($"{EscapeCsv(salesmanCode)},{EscapeCsv(productCode)},100000,1.0,ADMIN,{DateTime.Today:yyyy-MM-dd}");
        builder.AppendLine($"{EscapeCsv(salesmanCode)},{EscapeCsv(productCode)},150000,0.5,ADMIN,{DateTime.Today:yyyy-MM-dd}");
        builder.AppendLine($"{EscapeCsv(salesmanCode)},{EscapeCsv(productCode)},200000,1.0,,");
        return builder.ToString();
    }

    private static string EscapeCsv(string value)
        => value.Contains(',') || value.Contains('"') || value.Contains('\n') || value.Contains('\r')
            ? $"\"{value.Replace("\"", "\"\"")}\""
            : value;

    private async Task<(HashSet<string>, HashSet<string>)> GetMasterCodesAsync()
    {
        await using var conn = new SqlConnection(_connectionString);

        // Get valid salesman codes (for current channel)
        var salesmanCodes = (await conn.QueryAsync<string>(@"
SELECT UPPER(employee_code)
FROM dbo.mst_employee
WHERE is_active = 1 AND channel_id = @ChannelId
ORDER BY employee_code;",
            new { ChannelId })).ToHashSet();

        // Get valid product codes
        var productCodes = (await conn.QueryAsync<string>(@"
SELECT UPPER(product_code)
FROM dbo.mst_product
WHERE is_active = 1
ORDER BY product_code;")).ToHashSet();

        return (salesmanCodes, productCodes);
    }

    private sealed class TemplateSalesmanRow
    {
        public int ChannelId { get; init; }
        public string EmployeeCode { get; init; } = string.Empty;
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
        var filterSalesman = string.IsNullOrWhiteSpace(FilterSalesmanCode) ? null : FilterSalesmanCode.Trim();
        var filterProduct = string.IsNullOrWhiteSpace(FilterProductCode) ? null : FilterProductCode.Trim();
        var filterApprovedBy = string.IsNullOrWhiteSpace(FilterApprovedBy) ? null : FilterApprovedBy.Trim();
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
    t.approved_at AS ApprovedAt,
    t.updated_at AS UpdatedAt
FROM dbo.trn_sales_target t
INNER JOIN dbo.mst_period p ON p.period_id = t.period_id
INNER JOIN dbo.mst_channel c ON c.channel_id = t.channel_id
LEFT JOIN dbo.mst_employee e ON e.employee_code = t.salesman_code AND e.channel_id = t.channel_id
LEFT JOIN dbo.mst_product pr ON pr.product_code = t.product_code
WHERE t.channel_id = @ChannelId
  AND t.period_id = @PeriodId
    AND (@FilterSalesmanCode IS NULL OR t.salesman_code = @FilterSalesmanCode)
    AND (@FilterProductCode IS NULL OR t.product_code = @FilterProductCode)
    AND (@FilterApprovedBy IS NULL OR ISNULL(t.approved_by, '') = @FilterApprovedBy)
  AND (
      @Keyword IS NULL
      OR t.salesman_code LIKE '%' + @Keyword + '%'
      OR ISNULL(e.employee_name_th, '') LIKE '%' + @Keyword + '%'
      OR t.product_code LIKE '%' + @Keyword + '%'
      OR ISNULL(pr.product_name_th, '') LIKE '%' + @Keyword + '%'
  )
ORDER BY t.salesman_code, t.product_code, t.sales_target_id;",
            new
            {
                ChannelId,
                PeriodId,
                Keyword = keyword,
                FilterSalesmanCode = filterSalesman,
                FilterProductCode = filterProduct,
                FilterApprovedBy = filterApprovedBy
            })).ToList();

        ApprovedByOptions = TargetRows
            .Select(row => row.ApprovedBy)
            .Where(value => !string.IsNullOrWhiteSpace(value))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(value => value)
            .Cast<string>()
            .ToList();

        if (PageNumber < 1)
        {
            PageNumber = 1;
        }

        if (PageNumber > TotalPages)
        {
            PageNumber = TotalPages;
        }

        var skip = (PageNumber - 1) * PageSize;
        PagedTargetRows = TargetRows
            .Skip(skip)
            .Take(PageSize)
            .ToList();

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
    public DateTime? UpdatedAt { get; init; }
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
