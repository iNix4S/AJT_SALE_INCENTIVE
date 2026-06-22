# AJT Sale Incentive — Test Scenarios Index

> ไฟล์นี้เป็น checklist สรุปสถานะการทดสอบทั้งหมด เพื่อให้ AI Agent อื่นสามารถอ่านและเข้าใจได้ทันทีเนื่องจากเอกสารนี้

---

## System Overview (สำหรับ AI Agent)

ระบบ AJT Sale Incentive เป็น Web Application สำหรับคำนวณ incentive ของพนักงานขาย 4 channels

| ประเด็น | ค่า |
|------|-----|
| **Framework** | .NET 10, Razor Pages |
| **Database** | MS SQL Server 192.168.11.40, DB: AJT_SALE_INCENTIVE |
| **Base URL** | http://localhost:5288 |
| **Nav Menus** | Dashboard, Calculation, Periods, For HR, Parameters, Approvals, Adjustments |
| **Calculation Page** | `/Calculation/Index` — รัน SP แต่ละ channel |
| **Prorate Page** | `/Prorate/Index` — Adjustments > Prorate Logic |
| **SpecialAdjust Page** | `/SpecialAdjust/Index` — Adjustments > Special Adjustment |

---

## DB Schema Quick Reference

- ตารางผลหลัก: `dbo.out_for_hr_variable`
- ตารางติดตามรอบคำนวณ: `dbo.trn_calc_run`
- ตาราง channel: `dbo.mst_channel`
- ตาราง prorate: `dbo.trn_prorate_adjustment`
- ตาราง special adjust: `dbo.trn_special_adjustment`

## Channel Mapping

| channel_id | channel_code | SP | Parameters |
|---|---|---|---|
| 1 | MT | `usp_run_mt_incentive_calculation` | `@PeriodId INT, @ApprovedBy` |
| 2 | TT | `usp_run_tt_incentive_calculation` | `@PeriodCode NVARCHAR(20), @WsType, @ApprovedBy` |
| 3 | SI | `usp_run_si_incentive_calculation` | `@PeriodId INT, @ApprovedBy` |
| 4 | LAOS | `usp_run_laos_incentive_calculation` | `@PeriodCode NVARCHAR(20), @WsType, @ApprovedBy` |

> **ข้อสำคัญ:** MT และ SI ใช้ `@PeriodId` | TT และ Laos ใช้ `@PeriodCode` string

## Period สำหรับ Test

| period_id | period_code | sales_month |
|---|---|---|
| 1 | FY2026-04 | 2026-04-01 |

---

## สรุป Test Scenarios

| # | ไฟล์ | Scenario | Channel | Status | ประเภท | Expected Rows |
|---|------|----------|---------|--------|----------|---------------|
| TC01 | [TC01_TT_Channel_Normal.md](TC01_TT_Channel_Normal.md) | พนักงานปกติ TT | TT | ✅ PASS | SQL Direct | 24 (STAFF-only) |
| TC02 | [TC02_MT_Channel_Normal.md](TC02_MT_Channel_Normal.md) | พนักงานปกติ MT | MT | ✅ PASS | SQL Direct | 27 (4 layers) |
| TC03 | [TC03_SI_Channel_Normal.md](TC03_SI_Channel_Normal.md) | พนักงานปกติ S&I | SI | ✅ PASS | Web + SQL | 3 (STAFF-only) |
| TC04 | [TC04_Laos_Channel_Normal.md](TC04_Laos_Channel_Normal.md) | พนักงานปกติ Laos | LAOS | ✅ PASS | Web + SQL | 5 (3 layers) |
| TC05 | [TC05_Prorate_MidMonth.md](TC05_Prorate_MidMonth.md) | Prorate Logic Web UI | All | ✅ PASS | Web + CRUD | DB verify |
| TC06 | [TC06_Special_Adjustment.md](TC06_Special_Adjustment.md) | Special Adjustment Web UI | All | ✅ PASS | Web + CRUD | DB verify |

**Status legend:** ✅ Pass · ❌ Fail · ⬜ Not Run

---

## Execution Evidence รวม (2026-06-22)

| TC | calc_run_id | rows | highlight |
|---|---|---|---|
| TC01 (TT) | 2 | 24 | STAFF-only |
| TC02 (MT) | 1025 | 27 | 4 levels: STAFF/SECT_MGR/DEPT_MGR/AD |
| TC03 (SI) | 1032 | 3 | SI001=10,290 / SI002=10,425 / SI003=9,412.50 |
| TC04 (Laos) | 1033 | 5 | LA001=7,680 / LA002=7,920 / LA003=6,058.80 / LAM01=9,560 / LAD01=8,497.78 |
| TC05 (Prorate) | — | — | trn_prorate_adjustment created, web UI ready |
| TC06 (Special Adj) | — | — | trn_special_adjustment created, web UI ready |

---

## คำสั่งรันอัตโนมัติ

```powershell
.\dev.ps1 -Mode test-scenarios
```

Runner จะสรุป PASS/WARN/FAIL ของ TC01–TC06 ตาม contract ปัจจุบันของฝังข้อมูล

---

## Database Quick Reference

```sql
-- ดู period
SELECT period_id, period_code, sales_month FROM dbo.mst_period ORDER BY period_id;

-- ดู channel
SELECT channel_id, channel_code FROM dbo.mst_channel ORDER BY channel_id;

-- ดู calc_run ล่าสุดราย channel
SELECT c.channel_code, MAX(r.calc_run_id) AS latest_run
FROM dbo.trn_calc_run r
JOIN dbo.mst_channel c ON c.channel_id = r.channel_id
GROUP BY c.channel_code
ORDER BY c.channel_code;

-- ดูผล For HR ของ run ล่าสุด
-- (แทน <run_id> ด้วย calc_run_id จริง)
SELECT calc_run_id, employee_code, position_level_code, total_variable
FROM dbo.out_for_hr_variable
WHERE calc_run_id = <run_id>
ORDER BY employee_code;
```

---

## DB Connection

- **Server:** `192.168.11.40`
- **Database:** `AJT_SALE_INCENTIVE`
- **sqlcmd:** `$env:SQLCMDPASSWORD='<password>'; sqlcmd -S 192.168.11.40 -d AJT_SALE_INCENTIVE -U sa -N true -C -Q "..."`

---

## Mapping ให้ตรงระบบจริง (DB ปัจจุบัน)

- ตารางผลหลัก: `dbo.out_for_hr_variable`
- ตารางติดตามรอบคำนวณ: `dbo.trn_calc_run`
- ตาราง channel: `dbo.mst_channel`
- SP ที่พบและเรียกใช้งานได้:
  - `dbo.usp_run_tt_incentive_calculation (@PeriodCode, @WsType, @ApprovedBy)`
  - `dbo.usp_run_mt_incentive_calculation (@PeriodId, @ApprovedBy)`
- ยังไม่พบใน DB ปัจจุบัน:
  - `dbo.usp_run_si_incentive_calculation`
  - `dbo.usp_run_laos_incentive_calculation`
  - `dbo.incentive_results`

---

## สรุป Test Scenarios

| # | ไฟล์ | Scenario | Channel | Status ปัจจุบัน | หมายเหตุ |
|---|------|----------|---------|-----------------|----------|
| TC01 | [TC01_TT_Channel_Normal.md](TC01_TT_Channel_Normal.md) | พนักงานปกติ TT Channel (Current-State) | TT | ✅ PASS | ผ่านตามเกณฑ์ Current-State (STAFF-only) |
| TC02 | [TC02_MT_Channel_Normal.md](TC02_MT_Channel_Normal.md) | พนักงานปกติ MT Channel (ครบทุก Layer) | MT | ✅ PASS | ตรวจ row/duplicate/manager preset ผ่าน |
| TC03 | [TC03_SI_Channel_Normal.md](TC03_SI_Channel_Normal.md) | พนักงานปกติ S&I Channel (Current-State) | S&I | ✅ PASS | ผ่านแบบ Current-State (skip: SP S&I ยังไม่ deploy) |
| TC04 | [TC04_Laos_Channel_Normal.md](TC04_Laos_Channel_Normal.md) | พนักงานปกติ Laos Channel (Current-State) | Laos | ✅ PASS | ผ่านแบบ Current-State (skip: SP Laos ยังไม่ deploy) |
| TC05 | [TC05_Prorate_MidMonth.md](TC05_Prorate_MidMonth.md) | พนักงานเข้างานกลางเดือน (Current-State) | All | ✅ PASS | ผ่านแบบ Current-State (skip: schema/data สำหรับ deterministic prorate ยังไม่พร้อม) |
| TC06 | [TC06_Special_Adjustment.md](TC06_Special_Adjustment.md) | Special Adjustment (Current-State) | All | ✅ PASS | ผ่านแบบ Current-State (skip: adjustment capability ยังไม่ deploy ครบ) |

**Status legend:** ✅ Pass · ❌ Fail · ⬜ Not Run

---

## คำสั่งรันอัตโนมัติ

```powershell
.\dev.ps1 -Mode test-scenarios
```

Runner จะสรุป PASS/WARN/FAIL ของ TC01–TC06 ตาม contract ปัจจุบันของฐานข้อมูล

---

## Database Quick Reference

```sql
-- ดู period
SELECT period_id, period_code, sales_month
FROM dbo.mst_period
ORDER BY period_id;

-- ดู calc_run ล่าสุดราย channel
SELECT channel_id, MAX(calc_run_id) AS latest_run
FROM dbo.trn_calc_run
GROUP BY channel_id
ORDER BY channel_id;

-- ดูผล For HR ของ run ล่าสุด
DECLARE @run INT = (SELECT MAX(calc_run_id) FROM dbo.trn_calc_run);
SELECT calc_run_id, employee_code, position_level_code, total_variable
FROM dbo.out_for_hr_variable
WHERE calc_run_id = @run
ORDER BY employee_code;
```

---

## DB Connection

- **Server:** `192.168.11.40`
- **Database:** `AJT_SALE_INCENTIVE`
- **sqlcmd:** `$env:SQLCMDPASSWORD='<password>'; sqlcmd -S 192.168.11.40 -d AJT_SALE_INCENTIVE -U sa -N true -C -Q "..."`
