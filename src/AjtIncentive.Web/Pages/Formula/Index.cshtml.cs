using Dapper;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Data.SqlClient;
using AjtIncentive.Web.Services;

namespace AjtIncentive.Web.Pages.Formula;

public class IndexModel : PageModel
{
    private readonly IFormulaEvaluatorService _formulaService;
    private readonly IPortalDataService _portalDataService;
    private readonly string _connectionString;

    public IndexModel(IFormulaEvaluatorService formulaService,
                      IPortalDataService portalDataService,
                      IConfiguration config)
    {
        _formulaService   = formulaService;
        _portalDataService = portalDataService;
        _connectionString = config.GetConnectionString("DefaultConnection")!;
    }

    // ── Filter ──
    [BindProperty(SupportsGet = true)] public string? FilterChannel { get; set; }
    [BindProperty(SupportsGet = true)] public string? FilterStep    { get; set; }
    [BindProperty(SupportsGet = true)] public int?    EditId        { get; set; }

    // ── Data ──
    public IReadOnlyList<FormulaExpression> Formulas { get; private set; }
        = Array.Empty<FormulaExpression>();
    public IReadOnlyList<ChannelItem>      Channels { get; private set; }
        = Array.Empty<ChannelItem>();
    public IReadOnlyList<PositionItem>     Positions { get; private set; }
        = Array.Empty<PositionItem>();

    // ── Edit form ──
    public FormulaEditForm EditForm { get; private set; } = new();
    public bool IsEditMode => EditId.HasValue;

    // ── Test panel ──
    public FormulaEvalResult? TestResult { get; private set; }

    // ── SP Preview panel ──
    public IReadOnlyList<PeriodItem>        Periods     { get; private set; } = Array.Empty<PeriodItem>();
    public IReadOnlyList<FormulaPreviewRow> PreviewRows { get; private set; } = Array.Empty<FormulaPreviewRow>();
    public string? PreviewError    { get; private set; }
    public int     PreviewPeriodId { get; private set; }
    public string? PreviewChannel  { get; private set; }
    public string  ActiveTestTab   { get; private set; } = "quick";

    public static IReadOnlyList<string> FormulaSteps { get; } =
        ["PCT_ACHIEVEMENT", "INCENTIVE_PER_PRODUCT", "ROLLUP", "SPECIAL_KPI"];

    public async Task OnGetAsync()
    {
        await LoadAsync();
        if (EditId.HasValue)
            await PrefillEditFormAsync(EditId.Value);
    }

    public async Task<IActionResult> OnPostSaveAsync(
        int?    formulaId,
        string  formulaCode,
        string  formulaName,
        string  formulaStep,
        int?    channelId,
        int?    positionLevelId,
        string? wsType,
        string  formulaExpr,
        string? variablesJson,
        string? description,
        int     sortOrder,
        DateOnly effectiveFrom,
        DateOnly? effectiveTo,
        bool    isActive)
    {
        var (valid, errMsg) = _formulaService.Validate(formulaExpr);
        if (!valid)
        {
            TempData["Message"] = $"Error: Invalid formula syntax — {errMsg}";
            return RedirectToPage(new { FilterChannel, FilterStep });
        }

        var entity = new FormulaExpression
        {
            FormulaId       = formulaId ?? 0,
            FormulaCode     = formulaCode.Trim().ToUpperInvariant(),
            FormulaName     = formulaName.Trim(),
            FormulaStep     = formulaStep,
            ChannelId       = channelId,
            PositionLevelId = positionLevelId,
            WsType          = string.IsNullOrWhiteSpace(wsType) ? null : wsType.Trim(),
            FormulaExpr     = formulaExpr.Trim(),
            VariablesJson   = string.IsNullOrWhiteSpace(variablesJson) ? null : variablesJson.Trim(),
            Description     = string.IsNullOrWhiteSpace(description) ? null : description.Trim(),
            SortOrder       = sortOrder,
            EffectiveFrom   = effectiveFrom,
            EffectiveTo     = effectiveTo,
            IsActive        = isActive
        };

        await _formulaService.SaveAsync(entity);
        TempData["Message"] = formulaId.HasValue
            ? $"Formula '{formulaCode}' updated successfully."
            : $"Formula '{formulaCode}' added successfully.";

        return RedirectToPage(new { FilterChannel, FilterStep });
    }

    public async Task<IActionResult> OnPostDeleteAsync(int formulaId)
    {
        await _formulaService.DeleteAsync(formulaId);
        TempData["Message"] = "Formula deleted successfully.";
        return RedirectToPage(new { FilterChannel, FilterStep });
    }

    public async Task<IActionResult> OnPostTestAsync(
        string  formulaExpr,
        string? testVarsJson)
    {
        await LoadAsync();
        var variables = new Dictionary<string, decimal>();
        if (!string.IsNullOrWhiteSpace(testVarsJson))
        {
            try
            {
                var parsed = System.Text.Json.JsonSerializer
                    .Deserialize<Dictionary<string, decimal>>(testVarsJson);
                if (parsed is not null) variables = parsed;
            }
            catch { /* ไม่ต้อง throw */ }
        }
        TestResult   = _formulaService.Evaluate(formulaExpr, variables, "TEST");
        ActiveTestTab = "quick";
        return Page();
    }

    public async Task<IActionResult> OnPostPreviewAsync(
        int    previewPeriodId,
        string previewChannel)
    {
        await LoadAsync();
        PreviewPeriodId = previewPeriodId;
        PreviewChannel  = previewChannel;
        ActiveTestTab   = "sp";
        try
        {
            PreviewRows = await _portalDataService.GetFormulaPreviewAsync(previewPeriodId, previewChannel);
        }
        catch (Exception ex)
        {
            PreviewError = ex.Message;
        }
        return Page();
    }

    private async Task LoadAsync()
    {
        var all = await _formulaService.GetAllAsync();
        Formulas = all
            .Where(f => (FilterChannel is null || f.ChannelCode == FilterChannel || (f.ChannelCode is null && FilterChannel == "SHARED"))
                     && (FilterStep is null || f.FormulaStep == FilterStep))
            .ToList();

        Channels  = await _portalDataService.GetChannelsAsync();
        Periods   = await _portalDataService.GetPeriodsAsync();

        await using var conn = new SqlConnection(_connectionString);
        Positions = (await conn.QueryAsync<PositionItem>(@"
SELECT position_level_id AS PositionLevelId, position_code AS PositionCode,
       position_name_th AS PositionNameTh, hierarchy_level AS HierarchyLevel
FROM dbo.mst_position_level WHERE is_active = 1 ORDER BY hierarchy_level;"))
            .ToList();
    }

    private async Task PrefillEditFormAsync(int id)
    {
        var all = await _formulaService.GetAllAsync();
        var f = all.FirstOrDefault(x => x.FormulaId == id);
        if (f is null) return;
        EditForm = new FormulaEditForm
        {
            FormulaId       = f.FormulaId,
            FormulaCode     = f.FormulaCode,
            FormulaName     = f.FormulaName,
            FormulaStep     = f.FormulaStep,
            ChannelId       = f.ChannelId,
            PositionLevelId = f.PositionLevelId,
            WsType          = f.WsType,
            FormulaExpr     = f.FormulaExpr,
            VariablesJson   = f.VariablesJson,
            Description     = f.Description,
            SortOrder       = f.SortOrder,
            EffectiveFrom   = f.EffectiveFrom,
            EffectiveTo     = f.EffectiveTo,
            IsActive        = f.IsActive
        };
    }
}

public sealed class FormulaEditForm
{
    public int      FormulaId       { get; set; }
    public string   FormulaCode     { get; set; } = string.Empty;
    public string   FormulaName     { get; set; } = string.Empty;
    public string   FormulaStep     { get; set; } = "INCENTIVE_PER_PRODUCT";
    public int?     ChannelId       { get; set; }
    public int?     PositionLevelId { get; set; }
    public string?  WsType          { get; set; }
    public string   FormulaExpr     { get; set; } = string.Empty;
    public string?  VariablesJson   { get; set; }
    public string?  Description     { get; set; }
    public int      SortOrder       { get; set; }
    public DateOnly EffectiveFrom   { get; set; } = DateOnly.FromDateTime(DateTime.Today);
    public DateOnly? EffectiveTo    { get; set; }
    public bool     IsActive        { get; set; } = true;
}

public sealed class PositionItem
{
    public int    PositionLevelId { get; init; }
    public string PositionCode    { get; init; } = string.Empty;
    public string PositionNameTh  { get; init; } = string.Empty;
    public int    HierarchyLevel  { get; init; }
}
