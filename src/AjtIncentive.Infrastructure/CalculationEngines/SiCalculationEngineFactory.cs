using AjtIncentive.Application.Interfaces;

namespace AjtIncentive.Infrastructure.CalculationEngines;

/// <summary>
/// สร้าง <see cref="ISiCalculationEngine"/> ตาม <see cref="CalculationEngineType"/> ที่เลือก
/// ใช้ config "CalculationEngine:SI" ใน appsettings.json เพื่อกำหนด engine ที่ใช้จริง
/// ค่า default = StoredProcedure (engine เดิม, ปลอดภัยที่สุด)
/// </summary>
public static class SiCalculationEngineFactory
{
    public static ISiCalculationEngine Create(string connectionString, string? engineName)
    {
        var type = ParseEngineType(engineName);

        return type switch
        {
            CalculationEngineType.SqlFunction => new SiSqlFunctionEngine(connectionString),
            CalculationEngineType.NCalc => new SiNCalcEngine(connectionString),
            _ => new SiStoredProcedureEngine(connectionString)
        };
    }

    private static CalculationEngineType ParseEngineType(string? engineName)
    {
        if (Enum.TryParse<CalculationEngineType>(engineName, ignoreCase: true, out var parsed))
            return parsed;

        return CalculationEngineType.StoredProcedure;
    }
}
