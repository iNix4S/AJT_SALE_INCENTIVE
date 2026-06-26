namespace AjtIncentive.Domain.Entities;

public class Employee
{
    public int EmployeeId { get; set; }
    public string EmployeeCode { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public int PositionLevelId { get; set; }
    public int ChannelId { get; set; }
    public string JobFunction { get; set; } = string.Empty;
    public string Department { get; set; } = string.Empty;
    public bool IsActive { get; set; }
}
