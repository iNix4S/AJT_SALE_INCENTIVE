using AjtIncentive.Domain.Entities;

namespace AjtIncentive.Application.Interfaces;

public interface ICalculationService
{
    Task<int> RunMtCalculationAsync(int periodId);
    Task<int> RunTtCalculationAsync(string periodCode, string wsType);
    Task<int> RunSiCalculationAsync(int periodId);
    Task<int> RunLaosCalculationAsync(int periodId);
    Task<IEnumerable<IncentiveResult>> GetForHrResultsAsync(int periodId, int channelId);
}
