using AjtIncentive.Application.Interfaces;

namespace AjtIncentive.Infrastructure.CalculationEngines;

/// <summary>
/// สร้าง <see cref="IMtCalculationEngine"/> ตาม <see cref="CalculationEngineType"/> ที่เลือก
/// ใช้ config "CalculationEngine:MT" ใน appsettings.json เพื่อกำหนด engine ที่ใช้จริง
/// ค่า default = StoredProcedure (engine เดิม, ปลอดภัยที่สุด)
/// </summary>
public static class MtCalculationEngineFactory
{
    public static IMtCalculationEngine Create(string connectionString, string? engineName)
    {
        var type = ParseEngineType(engineName);

        return type switch
        {
            CalculationEngineType.SqlFunction => new MtSqlFunctionEngine(connectionString),
            CalculationEngineType.NCalc => new MtNCalcEngine(connectionString),
            _ => new MtStoredProcedureEngine(connectionString)
        };
    }

    private static CalculationEngineType ParseEngineType(string? engineName)
    {
        if (Enum.TryParse<CalculationEngineType>(engineName, ignoreCase: true, out var parsed))
            return parsed;

        return CalculationEngineType.StoredProcedure;
    }
}
