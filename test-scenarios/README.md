# AJT Sale Incentive — Test Scenarios Index

ไฟล์นี้สรุป test scenarios ที่ใช้กับระบบจริงในปัจจุบัน โดยอ้างอิงหน้าเว็บ Razor Pages และฐานข้อมูล `AJT_SALE_INCENTIVE` ตาม implementation ล่าสุด

---

## System Overview

| ประเด็น | ค่า |
|---|---|
| Framework | .NET 10, Razor Pages |
| Database | MS SQL Server `192.168.11.40`, DB `AJT_SALE_INCENTIVE` |
| Base URL | `http://localhost:5288` |
| Nav Menus | Dashboard, Calculation, Periods, For HR, Approvals, Adjustments, Parameters |
| Calculation Page | `/Calculation/Index` |
| Prorate Page | `/Prorate/Index` |
| Special Adjustment Page | `/SpecialAdjust/Index` |

---

## Channel Mapping (ตรงระบบจริง)

| channel_id | channel_code | Stored Procedure | Parameter สำคัญ |
|---|---|---|---|
| 1 | MT | `usp_run_mt_incentive_calculation` | `@PeriodId`, `@ApprovedBy` |
| 2 | TT | `usp_run_tt_incentive_calculation` | `@PeriodCode`, `@WsType`, `@ApprovedBy` |
| 3 | SI | `usp_run_si_incentive_calculation` | `@PeriodId`, `@ApprovedBy` |
| 4 | LAOS | `usp_run_laos_incentive_calculation` | ใช้ตาม signature ที่ deploy ใน DB |

หมายเหตุ

1. หน้า `Calculation` รับค่า period จาก dropdown ทั้ง 4 cards
2. TT ในระบบปัจจุบันรันทุก WS Type อัตโนมัติในหนึ่งครั้ง
3. สำหรับ Laos ให้ยึด signature จาก DB จริงของ environment นั้นๆ

---

## ตารางหลักที่ใช้ตรวจผล

1. `dbo.trn_calc_run` : เก็บรอบรัน calculation
2. `dbo.out_for_hr_variable` : ผลลัพธ์สำหรับ For HR
3. `dbo.trn_prorate_adjustment` : ข้อมูล prorate
4. `dbo.trn_special_adjustment` : ข้อมูล special adjustment

---

## สรุป Test Scenarios

| TC | ไฟล์ | Scenario | ชนิดทดสอบ | เกณฑ์หลัก |
|---|---|---|---|---|
| TC01 | [TC01_TT_Channel_Normal.md](TC01_TT_Channel_Normal.md) | TT Channel Normal | SQL + Runner | STAFF-only current-state, no duplicate |
| TC02 | [TC02_MT_Channel_Normal.md](TC02_MT_Channel_Normal.md) | MT Channel Normal | SQL + Runner | 27 rows (period 1), 4 levels, manager preset |
| TC03 | [TC03_SI_Channel_Normal.md](TC03_SI_Channel_Normal.md) | S&I Channel Normal | Web + SQL + Runner | 3 rows, amount match |
| TC04 | [TC04_Laos_Channel_Normal.md](TC04_Laos_Channel_Normal.md) | Laos Channel Normal | Web + SQL + Runner | 5 rows, amount match |
| TC05 | [TC05_Prorate_MidMonth.md](TC05_Prorate_MidMonth.md) | Prorate CRUD | Web + SQL + Runner | MERGE upsert + delete verify |
| TC06 | [TC06_Special_Adjustment.md](TC06_Special_Adjustment.md) | Special Adjustment CRUD | Web + SQL + Runner | SHORTAGE/SPECIAL_SITUATION CRUD |

---

## Evidence ล่าสุด (2026-06-22)

| TC | calc_run_id | ผลลัพธ์ |
|---|---|---|
| TC01 (TT) | 2 | PASS, rows=24 (STAFF-only) |
| TC02 (MT) | 1025 | PASS, rows=27, 4 levels |
| TC03 (SI) | 1032 | PASS, rows=3, amount match |
| TC04 (Laos) | 1033 | PASS, rows=5, amount match |
| TC05 | - | PASS, `trn_prorate_adjustment` CRUD |
| TC06 | - | PASS, `trn_special_adjustment` CRUD |

---

## การรันอัตโนมัติ

```powershell
.\test-scenarios\run-test-scenarios.ps1
```

ผลลัพธ์จะแสดงสรุป PASS/WARN/FAIL ของ TC01-TC06

---

## DB Quick Queries

```sql
SELECT period_id, period_code, sales_month FROM dbo.mst_period ORDER BY period_id;

SELECT channel_id, channel_code FROM dbo.mst_channel ORDER BY channel_id;

SELECT c.channel_code, MAX(r.calc_run_id) AS latest_run
FROM dbo.trn_calc_run r
JOIN dbo.mst_channel c ON c.channel_id = r.channel_id
GROUP BY c.channel_code
ORDER BY c.channel_code;

SELECT calc_run_id, employee_code, position_level_code, total_variable
FROM dbo.out_for_hr_variable
WHERE calc_run_id = <run_id>
ORDER BY employee_code;
```

---

## DB Connection

1. Server: `192.168.11.40`
2. Database: `AJT_SALE_INCENTIVE`
3. SQLCMD ตัวอย่าง:

```powershell
$env:SQLCMDPASSWORD='<password>'
sqlcmd -S 192.168.11.40 -d AJT_SALE_INCENTIVE -U sa -N true -C -Q "SELECT 1"
```
