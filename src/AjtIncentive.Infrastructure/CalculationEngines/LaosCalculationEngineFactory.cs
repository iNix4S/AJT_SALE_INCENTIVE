using AjtIncentive.Application.Interfaces;

namespace AjtIncentive.Infrastructure.CalculationEngines;

/// <summary>
/// สร้าง <see cref="ILaosCalculationEngine"/> ตาม <see cref="CalculationEngineType"/> ที่เลือก
/// ใช้ config "CalculationEngine:LAOS" ใน appsettings.json เพื่อกำหนด engine ที่ใช้จริง
/// ค่า default = StoredProcedure (engine เดิม, ปลอดภัยที่สุด)
/// </summary>
public static class LaosCalculationEngineFactory
{
    public static ILaosCalculationEngine Create(string connectionString, string? engineName)
    {
        var type = ParseEngineType(engineName);

        return type switch
        {
            CalculationEngineType.SqlFunction => new LaosSqlFunctionEngine(connectionString),
            CalculationEngineType.NCalc => new LaosNCalcEngine(connectionString),
            _ => new LaosStoredProcedureEngine(connectionString)
        };
    }

    private static CalculationEngineType ParseEngineType(string? engineName)
    {
        if (Enum.TryParse<CalculationEngineType>(engineName, ignoreCase: true, out var parsed))
            return parsed;

        return CalculationEngineType.StoredProcedure;
    }
}
