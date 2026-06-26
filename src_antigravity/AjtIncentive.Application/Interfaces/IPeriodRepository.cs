using AjtIncentive.Domain.Entities;

namespace AjtIncentive.Application.Interfaces;

public interface IPeriodRepository
{
    Task<IEnumerable<Period>> GetAllAsync();
    Task<Period?> GetByIdAsync(int periodId);
}
