namespace AjtIncentive.Api.Contracts;

public sealed class SandboxRunRequest
{
    public string TargetChannel { get; set; } = string.Empty;
    public string SourceTransactionChannel { get; set; } = string.Empty;
    public int PeriodId { get; set; }
    public string Engine { get; set; } = "NCalc";
    public string FormulaSetRef { get; set; } = "draft";
    public bool Persist { get; set; } = false;
    public string? WsType { get; set; }
    public string? ApprovedBy { get; set; }
}

public sealed class SandboxRunResponse
{
    public long SandboxRunId { get; set; }
    public int RowCount { get; set; }
    public decimal TotalIncentive { get; set; }
    public bool Persisted { get; set; }
}

public sealed class SandboxCompareRequest
{
    public long SandboxRunId { get; set; }
    public int BaselineCalcRunId { get; set; }
}

public sealed class SandboxCompareResponse
{
    public decimal SandboxTotal { get; set; }
    public decimal BaselineTotal { get; set; }
    public decimal Delta { get; set; }
    public int SandboxRows { get; set; }
    public int BaselineRows { get; set; }
}
