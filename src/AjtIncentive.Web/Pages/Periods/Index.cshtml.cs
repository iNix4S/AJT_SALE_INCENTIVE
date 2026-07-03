using Dapper;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Data.SqlClient;
using System.Data;

namespace AjtIncentive.Web.Pages.Periods;

public sealed class IndexModel : PageModel
{
    private readonly string _connectionString;

    public IndexModel(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("DefaultConnection")!;
    }

    [BindProperty(SupportsGet = true)]
    public int? EditId { get; set; }

    [BindProperty]
    public PeriodFormInput Input { get; set; } = new();

    public IReadOnlyList<PeriodAdminRow> Periods { get; private set; } = [];

    public bool IsEditMode => Input.PeriodId > 0;

    public async Task OnGetAsync()
    {
        await LoadDataAsync();
    }

    public async Task<IActionResult> OnPostSaveAsync()
    {
        if (!ModelState.IsValid)
        {
            await LoadDataAsync();
            return Page();
        }

        try
        {
            await using var conn = new SqlConnection(_connectionString);
            var parameters = new DynamicParameters();
            parameters.Add("PeriodId", Input.PeriodId > 0 ? Input.PeriodId : null, dbType: DbType.Int32, direction: ParameterDirection.InputOutput);
            parameters.Add("PeriodCode", Input.PeriodCode);
            parameters.Add("SalesMonth", Input.SalesMonth);
            parameters.Add("YearNo", Input.YearNo);
            parameters.Add("MonthNo", Input.MonthNo);
            parameters.Add("Status", Input.Status);
            parameters.Add("IsClosed", Input.IsClosed);

            await conn.ExecuteAsync(
                "dbo.usp_master_period_upsert",
                parameters,
                commandType: CommandType.StoredProcedure);

            var savedId = parameters.Get<int>("PeriodId");
            TempData["Message"] = Input.PeriodId > 0
                ? $"อัปเดต Period {Input.PeriodCode} เรียบร้อย (ID={savedId})"
                : $"เพิ่ม Period {Input.PeriodCode} เรียบร้อย (ID={savedId})";

            return RedirectToPage();
        }
        catch (Exception ex)
        {
            TempData["Message"] = $"Error: {ex.Message}";
            await LoadDataAsync();
            return Page();
        }
    }

    public async Task<IActionResult> OnPostDeleteAsync(int periodId)
    {
        try
        {
            await using var conn = new SqlConnection(_connectionString);
            var deletedRows = await conn.ExecuteScalarAsync<int>(
                "dbo.usp_master_period_delete",
                new { PeriodId = periodId },
                commandType: CommandType.StoredProcedure);
            TempData["Message"] = deletedRows > 0
                ? $"ลบ Period ID {periodId} เรียบร้อย"
                : "ไม่พบ Period ที่ต้องการลบ";
        }
        catch (Exception ex)
        {
            TempData["Message"] = $"ลบไม่ได้: {ex.Message}";
        }

        return RedirectToPage();
    }

    public IActionResult OnPostCancelEdit()
    {
        return RedirectToPage();
    }

    private async Task LoadDataAsync()
    {
        await using var conn = new SqlConnection(_connectionString);

        Periods = (await conn.QueryAsync<PeriodAdminRow>(@"
SELECT period_id AS PeriodId,
       period_code AS PeriodCode,
       sales_month AS SalesMonth,
       year_no AS YearNo,
       month_no AS MonthNo,
       status AS Status,
       is_closed AS IsClosed,
       created_at AS CreatedAt,
       updated_at AS UpdatedAt
FROM dbo.mst_period
ORDER BY period_id;"))
            .ToList();

        if (EditId.HasValue)
        {
            var editRow = Periods.FirstOrDefault(p => p.PeriodId == EditId.Value);
            if (editRow is not null)
            {
                Input = new PeriodFormInput
                {
                    PeriodId = editRow.PeriodId,
                    PeriodCode = editRow.PeriodCode,
                    SalesMonth = editRow.SalesMonth,
                    YearNo = editRow.YearNo,
                    MonthNo = editRow.MonthNo,
                    Status = editRow.Status,
                    IsClosed = editRow.IsClosed
                };
                return;
            }
        }

        Input = new PeriodFormInput
        {
            SalesMonth = new DateTime(DateTime.Today.Year, DateTime.Today.Month, 1),
            YearNo = DateTime.Today.Year,
            MonthNo = (byte)DateTime.Today.Month,
            Status = "OPEN",
            IsClosed = false
        };
    }
}

public sealed class PeriodFormInput
{
    public int PeriodId { get; set; }
    public string PeriodCode { get; set; } = string.Empty;
    public DateTime SalesMonth { get; set; }
    public int YearNo { get; set; }
    public byte MonthNo { get; set; }
    public string Status { get; set; } = "OPEN";
    public bool IsClosed { get; set; }
}

public sealed class PeriodAdminRow
{
    public int PeriodId { get; init; }
    public string PeriodCode { get; init; } = string.Empty;
    public DateTime SalesMonth { get; init; }
    public int YearNo { get; init; }
    public byte MonthNo { get; init; }
    public string Status { get; init; } = string.Empty;
    public bool IsClosed { get; init; }
    public DateTime CreatedAt { get; init; }
    public DateTime? UpdatedAt { get; init; }
}
