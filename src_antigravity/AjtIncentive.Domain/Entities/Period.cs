namespace AjtIncentive.Domain.Entities;

public class Period
{
    public int PeriodId { get; set; }
    public string PeriodName { get; set; } = string.Empty;
    public DateOnly SalesMonth { get; set; }
    public bool IsActive { get; set; }
}
