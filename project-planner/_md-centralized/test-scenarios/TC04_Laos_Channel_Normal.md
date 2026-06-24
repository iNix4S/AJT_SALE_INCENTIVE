# TC04 — พนักงานปกติ Laos Channel

**Scenario:** คำนวณ Incentive สำหรับพนักงาน Laos Channel — ทดสอบแบบ Full Execution ทุก Layer  
**Channel:** Laos (`channel_id = 4`, `channel_code = 'LAOS'`)  
**SP:** `dbo.usp_run_laos_incentive_calculation`  
**Parameters:** ให้ตรวจ signature ใน DB ของ environment ปัจจุบันก่อนทดสอบ (`sys.parameters`)  
**Hierarchy:** STAFF → SECT_MGR → DEPT_MGR (ไม่มี DIVISION, ไม่มี AD)  
**Base URL (Web):** `http://localhost:5288`

---

## Context สำหรับ AI Agent

- Laos SP ถูก deploy แล้ว และ test data ถูก setup แล้วใน DB
- **ข้อสำคัญ:** หน้าเว็บใช้ Period dropdown เดียวกับ channel อื่น และ service layer จะจัดการพารามิเตอร์ตาม implementation ปัจจุบัน
- Laos ทำ **SKU mapping inline ใน SP**: A→AJ, R→RD, B→BD, Y→YY (ไม่ต้องใช้ mst_tt_product)
- Manager hierarchy: LAM01 (SECT_MGR) → LAD01 (DEPT_MGR) — ทั้งสองคนอยู่ใน `out_for_hr_variable`
- หน้าเว็บคำนวณ: `/Calculation/Index` → card "Laos Calculation" → เลือก Period → ปุ่ม "Run Laos Calculation" (service layer แปลง PeriodId → PeriodCode อัตโนมัติ)

---

## Test Data ที่ Setup ในระบบ

| Employee Code | ชื่อ | Position | Channel |
|---|---|---|---|
| LA001 | นาย ล. ขายลาว | STAFF | Laos (channel_id=4) |
| LA002 | นาง อ. ส่งออก | STAFF | Laos |
| LA003 | นาย ว. นำเข้า | STAFF | Laos |
| LAM01 | นาง ล. หัวหน้า | SECT_MGR | Laos |
| LAD01 | นาย อ. ผู้จัดการ | DEPT_MGR | Laos |

- **Period:** `FY2026-04` (period_id=1, sales_month=2026-04-01)
- **WsType:** `TOP_WS`
- **Products:** AJ, RD, BD, YY (มาจาก SKU-A, SKU-R, SKU-B, SKU-Y)

---

## Pre-Conditions

- [x] Channel Laos มีใน `mst_channel` (channel_id=4, channel_code='LAOS')
- [x] Employee LA001–LA003, LAM01, LAD01 มีใน `mst_employee`
- [x] มีข้อมูล target, actual, product_weight, incentive_rate สำหรับ period_id=1
- [x] SP `usp_run_laos_incentive_calculation` deploy แล้ว
- [x] Period FY2026-04 มีใน `mst_period` (period_id=1)

---

## Test Steps — ผ่าน Web UI

| # | ขั้นตอน | รายละเอียด |
|---|---------|------------|
| 1 | เปิดหน้า Calculation | ไปที่ `http://localhost:5288/Calculation/Index` |
| 2 | ตรวจสอบ Laos card | card "Laos Calculation" ต้องแสดงปุ่มที่ **ไม่ disabled** |
| 3 | เลือก Period | เลือก `1 - FY2026-04` |
| 4 | กด "Run Laos Calculation" | ระบบ POST ไป `OnPostRunLaosAsync` → `RunLaosCalculationAsync(LaosPeriodId)` → service แปลง PeriodId→PeriodCode |
| 5 | ตรวจ flash message | ต้องแสดง `Laos Calculation started successfully. Calc Run ID: <id>` |
| 6 | ตรวจ Recent Runs | ต้องมีแถวใหม่ channel=LAOS, status=CALCULATED |

---

## Test Steps — ผ่าน SQL Direct (สำหรับ Automated Test)

| # | ขั้นตอน | คำสั่ง SQL |
|---|---------|------------|
| 1 | รัน SP | `EXEC dbo.usp_run_laos_incentive_calculation @PeriodCode='FY2026-04', @WsType='TOP_WS', @ApprovedBy='system';` |
| 2 | หา calc_run_id | `SELECT TOP 1 calc_run_id FROM dbo.trn_calc_run WHERE channel_id=4 ORDER BY calc_run_id DESC;` |
| 3 | ดูผล For HR | `SELECT employee_code, position_level_code, CAST(total_variable AS DECIMAL(18,2)) FROM dbo.out_for_hr_variable WHERE calc_run_id=<id> ORDER BY employee_code;` |
| 4 | ตรวจ row count | `SELECT COUNT(*) FROM dbo.out_for_hr_variable WHERE calc_run_id=<id>;` → ต้องได้ **5** |
| 5 | ตรวจ DIVISION ไม่มี | `SELECT COUNT(*) FROM dbo.out_for_hr_variable WHERE calc_run_id=<id> AND position_level_code LIKE '%DIV%';` → **0** |
| 6 | ตรวจ amounts | เทียบกับ expected table ด้านล่าง |

---

## Expected Results

| employee_code | ชื่อ | position_level_code | expected_total_variable | tolerance |
|---|---|---|---|---|
| LA001 | นาย ล. ขายลาว | STAFF | 7,680.00 | ±0.05 |
| LA002 | นาง อ. ส่งออก | STAFF | 7,920.00 | ±0.05 |
| LA003 | นาย ว. นำเข้า | STAFF | 6,058.80 | ±0.05 |
| LAM01 | นาง ล. หัวหน้า | SECT_MGR | 9,560.00 | ±0.05 |
| LAD01 | นาย อ. ผู้จัดการ | DEPT_MGR | 8,497.78 | ±0.05 |

---

## Pass Criteria

- [ ] SP รันสำเร็จ ไม่มี exception
- [ ] มี `calc_run_id` ใหม่ใน `trn_calc_run`
- [ ] จำนวน row = **5**
- [ ] ไม่มี employee_code ซ้ำ
- [ ] ไม่มีแถว position_level_code LIKE '%DIV%'
- [ ] LA001 = 7,680.00 (±0.05)
- [ ] LA002 = 7,920.00 (±0.05)
- [ ] LA003 = 6,058.80 (±0.05)
- [ ] LAM01 = 9,560.00 (±0.05)
- [ ] LAD01 = 8,497.78 (±0.05)

---

## Execution Evidence ล่าสุด (2026-06-22)

- calc_run_id: `1033`
- run_status: `CALCULATED`
- For HR rows: **5** (LA001, LA002, LA003, LAM01, LAD01)
- Duplicate employee: **0**
- DIVISION rows: **0**
- LA001=7,680 ✅ | LA002=7,920 ✅ | LA003=6,058.80 ✅ | LAM01=9,560 ✅ | LAD01=8,497.78 ✅

**สรุปสถานะ TC04:** ✅ **PASS (Fully Deployed & Tested)**

---

## Notes

> วันที่ทดสอบ: 2026-06-22  
> ผู้ทดสอบ: Copilot  
> calc_run_id: 1033  
> ประเด็นสำคัญ: ให้ยืนยัน signature ของ SP ใน DB ทุกครั้งก่อนรัน SQL direct
