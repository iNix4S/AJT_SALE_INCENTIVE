namespace AjtIncentive.Application.Interfaces;

/// <summary>
/// ประเภทของ engine ที่ใช้คำนวณ Incentive
/// - StoredProcedure : T-SQL stored procedure (engine ดั้งเดิม, ใช้งานจริงตั้งแต่ POC)
/// - SqlFunction      : T-SQL multi-statement table-valued function (แยก logic ออกจาก SP เดิม
///                      เพื่อให้เรียกใช้ซ้ำ/ตรวจสอบ query ได้อิสระจาก persistence)
/// - NCalc            : .NET service ที่ดึง target/actual/master data ผ่าน Dapper แล้ว evaluate
///                      สูตรด้วย library NCalc (อ่านสูตรจาก mst_formula_expression)
/// </summary>
public enum CalculationEngineType
{
    StoredProcedure,
    SqlFunction,
    NCalc
}

/// <summary>
/// Engine สำหรับคำนวณ Incentive ของ channel TT — รองรับ 3 engine ตาม <see cref="CalculationEngineType"/>
/// เลือก engine ที่จะใช้งานจริงผ่าน config "CalculationEngine:TT" ใน appsettings.json
/// </summary>
public interface ITtCalculationEngine
{
    CalculationEngineType EngineType { get; }

    /// <summary>รันคำนวณ Incentive ของ TT สำหรับ period + ws_type ที่ระบุ คืนค่า calc_run_id</summary>
    Task<int> RunAsync(string periodCode, string wsType, string? approvedBy = null);
}

/// <summary>
/// Engine สำหรับคำนวณ Incentive ของ channel LAOS — รองรับ 3 engine ตาม <see cref="CalculationEngineType"/>
/// เลือก engine ที่จะใช้งานจริงผ่าน config "CalculationEngine:LAOS" ใน appsettings.json
/// </summary>
public interface ILaosCalculationEngine
{
    CalculationEngineType EngineType { get; }

    /// <summary>รันคำนวณ Incentive ของ LAOS สำหรับ period_code ที่ระบุ คืนค่า calc_run_id</summary>
    Task<int> RunAsync(string periodCode, string? approvedBy = null);
}

/// <summary>
/// Engine สำหรับคำนวณ Incentive ของ channel MT — รองรับ 3 engine ตาม <see cref="CalculationEngineType"/>
/// เลือก engine ที่จะใช้งานจริงผ่าน config "CalculationEngine:MT" ใน appsettings.json
/// </summary>
public interface IMtCalculationEngine
{
    CalculationEngineType EngineType { get; }

    /// <summary>รันคำนวณ Incentive ของ MT สำหรับ period_id ที่ระบุ คืนค่า calc_run_id</summary>
    Task<int> RunAsync(int periodId, string? approvedBy = null);
}

/// <summary>
/// Engine สำหรับคำนวณ Incentive ของ channel S&I — รองรับ 3 engine ตาม <see cref="CalculationEngineType"/>
/// เลือก engine ที่จะใช้งานจริงผ่าน config "CalculationEngine:SI" ใน appsettings.json
/// </summary>
public interface ISiCalculationEngine
{
    CalculationEngineType EngineType { get; }

    /// <summary>รันคำนวณ Incentive ของ S&I สำหรับ period_id ที่ระบุ คืนค่า calc_run_id</summary>
    Task<int> RunAsync(int periodId, string? approvedBy = null);
}

/// <summary>
/// Engine ทั่วไปสำหรับ channel ใหม่ (เช่น Channel#5) ที่ยังไม่มี engine เฉพาะ (StoredProcedure/SqlFunction)
/// ทำงานล้วนจาก config/master/formula (table-driven) โดยไม่ต้องเขียนโค้ด engine เพิ่มต่อ channel
/// อ่าน target/actual จาก trn_sales_target/trn_sales_actual, rate/weight/goal จาก master tables,
/// และ evaluate สูตรจาก mst_formula_expression (channel_id ตรงกับ channel ที่ระบุ)
/// </summary>
public interface IGenericChannelCalculationEngine
{
    /// <summary>รันคำนวณ Incentive สำหรับ channel ที่ระบุด้วย channel_code + period_id คืนค่า calc_run_id</summary>
    Task<int> RunAsync(string channelCode, int periodId, string? approvedBy = null, string? wsType = null);
}
