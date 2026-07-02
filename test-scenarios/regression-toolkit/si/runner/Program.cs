using AjtIncentive.Application.Interfaces;
using AjtIncentive.Infrastructure.CalculationEngines;

if (args.Length < 3)
{
    Console.Error.WriteLine("Usage: dotnet run --project test-scenarios/regression-toolkit/si/runner -- <StoredProcedure|SqlFunction|NCalc> <periodId> <connectionString>");
    return 1;
}

if (!Enum.TryParse<CalculationEngineType>(args[0], ignoreCase: true, out var engineType))
{
    Console.Error.WriteLine($"Invalid engine type: {args[0]}");
    return 2;
}

if (!int.TryParse(args[1], out var periodId))
{
    Console.Error.WriteLine($"Invalid periodId: {args[1]}");
    return 3;
}

var connectionString = args[2];

ISiCalculationEngine engine = engineType switch
{
    CalculationEngineType.StoredProcedure => new SiStoredProcedureEngine(connectionString),
    CalculationEngineType.SqlFunction => new SiSqlFunctionEngine(connectionString),
    CalculationEngineType.NCalc => new SiNCalcEngine(connectionString),
    _ => throw new InvalidOperationException("Unsupported engine type.")
};

var runId = await engine.RunAsync(periodId, "runner");
Console.WriteLine($"Engine={engineType}; Period={periodId}; CalcRunId={runId}");
return 0;
