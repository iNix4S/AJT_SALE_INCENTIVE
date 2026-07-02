using AjtIncentive.Application.Interfaces;

namespace AjtIncentive.Infrastructure.CalculationEngines;

/// <summary>
/// สร้าง <see cref="ITtCalculationEngine"/> ตาม <see cref="CalculationEngineType"/> ที่เลือก
/// ใช้ config "CalculationEngine:TT" ใน appsettings.json เพื่อกำหนด engine ที่ใช้จริงใน production
/// ค่า default = StoredProcedure (engine เดิม, ปลอดภัยที่สุด)
/// </summary>
public static class TtCalculationEngineFactory
{
    public static ITtCalculationEngine Create(string connectionString, string? engineName)
    {
        var type = ParseEngineType(engineName);

        return type switch
        {
            CalculationEngineType.SqlFunction => new TtSqlFunctionEngine(connectionString),
            CalculationEngineType.NCalc => new TtNCalcEngine(connectionString),
            _ => new TtStoredProcedureEngine(connectionString)
        };
    }

    private static CalculationEngineType ParseEngineType(string? engineName)
    {
        if (Enum.TryParse<CalculationEngineType>(engineName, ignoreCase: true, out var parsed))
            return parsed;

        return CalculationEngineType.StoredProcedure;
    }
}
