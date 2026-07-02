using AjtIncentive.Application.Interfaces;
using AjtIncentive.Infrastructure.CalculationEngines;

if (args.Length < 3)
{
    Console.Error.WriteLine("Usage: dotnet run --project test-scenarios/mt-engine-runner -- <StoredProcedure|SqlFunction|NCalc> <periodId> <connectionString>");
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

IMtCalculationEngine engine = engineType switch
{
    CalculationEngineType.StoredProcedure => new MtStoredProcedureEngine(connectionString),
    CalculationEngineType.SqlFunction => new MtSqlFunctionEngine(connectionString),
    CalculationEngineType.NCalc => new MtNCalcEngine(connectionString),
    _ => throw new InvalidOperationException("Unsupported engine type.")
};

var runId = await engine.RunAsync(periodId, "runner");
Console.WriteLine($"Engine={engineType}; Period={periodId}; CalcRunId={runId}");
return 0;
