using AjtIncentive.Domain.Entities;

namespace AjtIncentive.Application.Interfaces;

public interface ICalculationService
{
    Task<int> RunMtCalculationAsync(int periodId);
    Task<int> RunTtCalculationAsync(int periodId);
    Task<IEnumerable<IncentiveResult>> GetForHrResultsAsync(int periodId, int channelId);
}
