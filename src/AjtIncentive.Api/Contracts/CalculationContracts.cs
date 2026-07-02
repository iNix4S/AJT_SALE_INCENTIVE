namespace AjtIncentive.Api.Contracts;

public sealed class RunCalculationRequest
{
    public int? PeriodId { get; set; }
    public string? PeriodCode { get; set; }
    public string? WsType { get; set; }
    public string? Engine { get; set; }
    public string? ApprovedBy { get; set; }
}

public sealed class RunCalculationResponse
{
    public required string Channel { get; init; }
    public required int CalcRunId { get; init; }
    public required string Status { get; init; }
}

public sealed class ApiEnvelope<T>
{
    public required bool Success { get; init; }
    public string? Message { get; init; }
    public T? Data { get; init; }

    public static ApiEnvelope<T> Ok(T data, string? message = null)
        => new() { Success = true, Data = data, Message = message };

    public static ApiEnvelope<T> Fail(string message)
        => new() { Success = false, Message = message, Data = default };
}

public sealed class CalcRunStatusDto
{
    public int CalcRunId { get; init; }
    public int PeriodId { get; init; }
    public int ChannelId { get; init; }
    public string ChannelCode { get; init; } = string.Empty;
    public string RunStatus { get; init; } = string.Empty;
    public DateTime? CalculatedAt { get; init; }
    public DateTime? ApprovedAt { get; init; }
    public string? ApprovedBy { get; init; }
    public DateTime CreatedAt { get; init; }
    public DateTime? UpdatedAt { get; init; }
    public int DetailRows { get; init; }
    public int HrRows { get; init; }
}
