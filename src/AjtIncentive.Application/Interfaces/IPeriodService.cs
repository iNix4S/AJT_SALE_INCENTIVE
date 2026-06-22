namespace AjtIncentive.Application.Interfaces;

using AjtIncentive.Domain.Entities;

public interface IPeriodService
{
    Task<IEnumerable<Period>> GetAllPeriodsAsync();
    Task<Period?> GetActivePeriodAsync();
    Task SetActivePeriodAsync(int periodId);
    Task ClosePeriodAsync(int periodId);
}
