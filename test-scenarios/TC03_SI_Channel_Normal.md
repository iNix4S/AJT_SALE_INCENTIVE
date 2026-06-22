# TC03 — พนักงานปกติ S&I Channel

**Scenario:** คำนวณ Incentive สำหรับพนักงาน S&I Channel — ทดสอบแบบ Full Execution พร้อมยืนยันตัวเลขรายคน  
**Channel:** S&I (`channel_id = 3`, `channel_code = 'SI'`)  
**SP:** `dbo.usp_run_si_incentive_calculation`  
**Parameters:** `@PeriodId INT`, `@ApprovedBy NVARCHAR(100)`  
**Hierarchy:** STAFF only (SIM01 เป็น SECT_MGR แต่ไม่ถูกปล่อยออก `out_for_hr_variable` — S&I ไม่คำนวณ manager layer)  
**Base URL (Web):** `http://localhost:5288`

---

## Context สำหรับ AI Agent

ระบบ AJT Sale Incentive เป็น .NET 10 Razor Pages + SQL Server 192.168.11.40/AJT_SALE_INCENTIVE

- S&I SP ถูก deploy แล้ว และ test data ถูก setup แล้วใน DB
- SP ใช้ `@PeriodId` (INT) — **ไม่ใช่** `@PeriodCode` (string)
- ตาราง output: `dbo.out_for_hr_variable` (เชื่อมผ่าน `calc_run_id` กับ `dbo.trn_calc_run`)
- หน้าเว็บคำนวณ: `/Calculation/Index` → card "S&I Calculation" → ปุ่ม "Run S&I Calculation"

---

## Test Data ที่ Setup ในระบบ

| Employee Code | ชื่อ | Position | Channel |
|---|---|---|---|
| SI001 | นาย ส. นำเข้า | STAFF | S&I (channel_id=3) |
| SI002 | นาง ศ. ส่งออก | STAFF | S&I |
| SI003 | นาย ษ. ขายดี | STAFF | S&I |
| SIM01 | นาง ส. หัวหน้า | SECT_MGR | S&I (ไม่มีใน output) |

- **Period:** `FY2026-04` (period_id=1, sales_month=2026-04-01)
- **Products:** AJ, RD, BD, YY, PDC, AJP
- **Rate Lookup:** ใช้ `mst_incentive_rate` JOIN ด้วย `position_level_id`

---

## Pre-Conditions

- [x] Channel S&I มีใน `mst_channel` (channel_id=3, channel_code='SI')
- [x] Employee SI001–SI003 และ SIM01 มีใน `mst_employee`
- [x] มีข้อมูล target, actual, product_weight, incentive_rate สำหรับ period_id=1
- [x] SP `usp_run_si_incentive_calculation` deploy แล้ว
- [x] Period FY2026-04 มีใน `mst_period` (period_id=1)

---

## Test Steps — ผ่าน Web UI

| # | ขั้นตอน | รายละเอียด |
|---|---------|------------|
| 1 | เปิดหน้า Calculation | ไปที่ `http://localhost:5288/Calculation/Index` |
| 2 | ตรวจสอบ S&I card | card "S&I Calculation" ต้องแสดงปุ่มที่ **ไม่ disabled** (แปลว่า SP deploy แล้ว) |
| 3 | เลือก Period | เลือก `1 - FY2026-04 (2026-04)` จาก dropdown |
| 4 | กด "Run S&I Calculation" | ระบบส่ง POST ไป `OnPostRunSiAsync` → เรียก `RunSiCalculationAsync(SiPeriodId)` |
| 5 | ตรวจ flash message | ต้องแสดง `S&I Calculation started successfully. Calc Run ID: <id>` |
| 6 | ตรวจ Recent Runs table | ต้องมีแถวใหม่ channel=SI, status=CALCULATED |

---

## Test Steps — ผ่าน SQL Direct (สำหรับ Automated Test)

| # | ขั้นตอน | คำสั่ง SQL |
|---|---------|------------|
| 1 | รัน SP | `EXEC dbo.usp_run_si_incentive_calculation @PeriodId=1, @ApprovedBy='system';` |
| 2 | หา calc_run_id ใหม่ | `SELECT TOP 1 calc_run_id FROM dbo.trn_calc_run WHERE channel_id=3 ORDER BY calc_run_id DESC;` |
| 3 | ดูผล For HR | `SELECT employee_code, position_level_code, CAST(total_variable AS DECIMAL(18,2)) FROM dbo.out_for_hr_variable WHERE calc_run_id=<id> ORDER BY employee_code;` |
| 4 | ตรวจ row count | `SELECT COUNT(*) FROM dbo.out_for_hr_variable WHERE calc_run_id=<id>;` → ต้องได้ **3** |
| 5 | ตรวจ duplicate | `SELECT COUNT(*) FROM (SELECT employee_code FROM dbo.out_for_hr_variable WHERE calc_run_id=<id> GROUP BY employee_code HAVING COUNT(*)>1) d;` → ต้องได้ **0** |
| 6 | ตรวจ AD rows | `SELECT COUNT(*) FROM dbo.out_for_hr_variable WHERE calc_run_id=<id> AND position_level_code='AD';` → ต้องได้ **0** |

---

## Expected Results

| employee_code | ชื่อ | position_level_code | expected_total_variable | tolerance |
|---|---|---|---|---|
| SI001 | นาย ส. นำเข้า | STAFF | 10,290.00 | ±0.05 |
| SI002 | นาง ศ. ส่งออก | STAFF | 10,425.00 | ±0.05 |
| SI003 | นาย ษ. ขายดี | STAFF | 9,412.50 | ±0.05 |
| SIM01 | นาง ส. หัวหน้า | — | **ไม่มีแถว** | — |

> หมายเหตุ: total_variable ของแต่ละคนมาจาก Σ (achievement_rate × weight × rate) ข้ามทุก product

---

## Pass Criteria

- [ ] SP รันสำเร็จ ไม่มี exception หรือ error message
- [ ] มี `calc_run_id` ใหม่ใน `trn_calc_run` (run_status = 'CALCULATED')
- [ ] จำนวน row ใน `out_for_hr_variable` = **3**
- [ ] ไม่มี employee_code ซ้ำใน run เดียวกัน (duplicate = 0)
- [ ] ไม่มีแถว position_level_code = 'AD' (S&I ไม่มี AD layer)
- [ ] SI001 total_variable = 10,290.00 (±0.05)
- [ ] SI002 total_variable = 10,425.00 (±0.05)
- [ ] SI003 total_variable = 9,412.50 (±0.05)

---

## Execution Evidence ล่าสุด (2026-06-22)

- calc_run_id: `1032`
- run_status: `CALCULATED`
- For HR rows: **3** (SI001, SI002, SI003)
- Duplicate employee: **0**
- AD rows: **0**
- SI001 = 10,290.00 ✅ | SI002 = 10,425.00 ✅ | SI003 = 9,412.50 ✅

**สรุปสถานะ TC03:** ✅ **PASS (Fully Deployed & Tested)**

---

## Notes

> วันที่ทดสอบ: 2026-06-22  
> ผู้ทดสอบ: Copilot  
> calc_run_id: 1032  
> ผลสรุป: SP รันได้และ output ตรง expected amounts ทุกราย
