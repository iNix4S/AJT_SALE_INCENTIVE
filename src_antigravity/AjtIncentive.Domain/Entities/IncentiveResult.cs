namespace AjtIncentive.Domain.Entities;

public class IncentiveResult
{
    public int CalcRunId { get; set; }
    public int PeriodId { get; set; }
    public string EmployeeCode { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public int ChannelId { get; set; }
    public decimal IncentiveAmount { get; set; }
    public string Status { get; set; } = string.Empty;
}
