namespace AjtIncentive.Api.Contracts;

public sealed class FormulaUpsertRequest
{
    public string FormulaCode { get; set; } = string.Empty;
    public string FormulaName { get; set; } = string.Empty;
    public string FormulaStep { get; set; } = string.Empty;
    public int? ChannelId { get; set; }
    public int? PositionLevelId { get; set; }
    public string? WsType { get; set; }
    public string FormulaExpr { get; set; } = string.Empty;
    public string? VariablesJson { get; set; }
    public string? Description { get; set; }
    public int SortOrder { get; set; }
    public DateOnly EffectiveFrom { get; set; }
    public DateOnly? EffectiveTo { get; set; }
    public bool IsActive { get; set; } = true;
}

public sealed class FormulaValidationRequest
{
    public string FormulaExpr { get; set; } = string.Empty;
    public Dictionary<string, decimal>? SampleVariables { get; set; }
}

public sealed class FormulaValidationResponse
{
    public bool IsValid { get; set; }
    public string? ErrorMessage { get; set; }
    public decimal? SampleResult { get; set; }
    public IReadOnlyCollection<string> Variables { get; set; } = Array.Empty<string>();
}

public sealed class FormulaCloneRequest
{
    public string SourceChannel { get; set; } = string.Empty;
    public bool SetInactive { get; set; } = true;
}
