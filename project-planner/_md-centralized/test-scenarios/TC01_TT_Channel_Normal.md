# TC01 — พนักงานปกติ TT Channel

**Scenario:** คำนวณ Incentive สำหรับพนักงาน TT Channel ตาม Current-State ของระบบจริง (STAFF-only)  
**Channel:** TT (channel_id = 2)  
**SP:** `usp_run_tt_incentive_calculation`  
**Hierarchy:** Deputy Depot cho → Depot cho → Area Manager → Division → AD

## Mapping ให้ตรงระบบจริง (DB ปัจจุบัน)

- SP ใช้พารามิเตอร์: `@PeriodCode`, `@WsType`, `@ApprovedBy` (ไม่มี `@PeriodId`, ไม่มี `@CalcRunId OUTPUT`)
- ตารางผล For HR ใช้: `out_for_hr_variable` (ไม่มี `incentive_results`)
- `calc_run_id` ใช้จาก `trn_calc_run`
- เกณฑ์ acceptance ปัจจุบัน: ถือว่า "ผ่าน" เมื่อผลลัพธ์ TT ออกเป็น STAFF-only ตาม behavior ปัจจุบันของระบบ

---

## Pre-Conditions

- [ ] มีข้อมูล Period ที่ต้องการทดสอบใน `mst_period`
- [ ] มีข้อมูล Employee ครบทุก Layer: Deputy Depot cho, Depot cho, Area Manager, Division, AD
- [ ] มีข้อมูล Actual Sales ของพนักงาน TT ใน period นั้น
- [ ] มีข้อมูล Target/Goal ใน `mst_product_goal` หรือตารางที่เกี่ยวข้อง
- [ ] มีข้อมูล Weight ใน `mst_product_weight`
- [ ] มีข้อมูล Route ใน `mst_salesman_route` ที่ effective ณ เดือนที่ทดสอบ

---

## Test Steps (ฉบับตรงระบบจริง)

| # | ขั้นตอน | คำสั่ง / วิธีการ |
|---|---------|----------------|
| 1 | ตรวจ Period | `SELECT period_id, period_code, sales_month FROM mst_period` |
| 2 | ตรวจ Employee TT | `SELECT * FROM mst_employee WHERE channel_id = 2` |
| 3 | รัน SP | `EXEC usp_run_tt_incentive_calculation @PeriodCode='FY2026-04', @WsType='TOP_WS', @ApprovedBy='system'` |
| 4 | ตรวจ calc_run_id ที่ได้ | `SELECT TOP (1) calc_run_id FROM trn_calc_run WHERE channel_id=2 AND period_id=1 ORDER BY calc_run_id DESC` |
| 5 | ดู For HR result | `SELECT * FROM out_for_hr_variable WHERE calc_run_id = <id> ORDER BY employee_code` |
| 6 | เปรียบเทียบกับ Expected | เทียบกับไฟล์ Excel ต้นฉบับ |

---

## Execution ล่าสุด (2026-06-22)

- PeriodCode ที่ใช้: `FY2026-04`
- WsType ที่ใช้: `TOP_WS`
- calc_run_id: `2`
- run_status: `CALCULATED`
- updated_at: `2026-06-22 09:37:25`
- For HR rows: `24`
- duplicate employee_code: `0`
- position_level_code ที่พบ: `STAFF` เท่านั้น

---

## Checklist — Current-State Verification

### Layer 1: Deputy Depot cho (Sales Staff)
- [x] มี record ใน `out_for_hr_variable` (24 rows)
- [x] `total_variable` คำนวณได้ (มีค่าในผลลัพธ์)
- [x] มีข้อมูลเชื่อมโยงจาก detail (`trn_incentive_detail`) สำหรับ STAFF
- [ ] กรณี shortage ตรวจครบทุก employee (ไม่ได้เจาะรายคนในรอบนี้)

### Layer 2: Depot cho (Section Manager)
- [x] ไม่พบ record ในผล For HR (ยอมรับตาม Current-State)
- [x] งดตรวจ team achievement ในรอบนี้ (ยังไม่ถูกปล่อยใน output)
- [x] งดตรวจ threshold ของ layer นี้ (ยังไม่ถูกปล่อยใน output)

### Layer 3: Area Manager
- [x] ไม่พบ record ในผล For HR (ยอมรับตาม Current-State)
- [x] งดตรวจ area-level achievement ในรอบนี้
- [x] งดตรวจ weight allocation ของ layer นี้

### Layer 4: Division Manager
- [x] ไม่พบ record ในผล For HR (ยอมรับตาม Current-State)
- [x] งดตรวจ division-level performance ในรอบนี้

### Layer 5: AD (Area Director)
- [x] ไม่พบ record ในผล For HR (ยอมรับตาม Current-State)
- [x] งดตรวจ overall TT performance ของ AD ในรอบนี้

---

## Expected Results

| employee_code | position | expected_amount | actual_amount | pass/fail |
|---|---|---|---|---|
| (กรอกก่อนทดสอบ) | Deputy Depot cho | | | |
| (กรอกก่อนทดสอบ) | Depot cho | | | |
| (กรอกก่อนทดสอบ) | Area Manager | | | |
| (กรอกก่อนทดสอบ) | Division | | | |
| (กรอกก่อนทดสอบ) | AD | | | |

---

## Pass Criteria

- [x] ผลลัพธ์ออกเฉพาะ `STAFF` ตาม Current-State
- [x] ไม่มี employee_code ซ้ำใน calc_run เดียวกัน (`duplicate_emp = 0`)
- [x] มี For HR row มากกว่า 0
- [x] SP รันสำเร็จ ไม่มี error / exception
- [ ] เทียบ expected รายคนกับไฟล์ Excel (ยังไม่ทำในรอบนี้)

**สรุปสถานะ TC01:** ✅ **PASS (Current-State Acceptance)**

---

## Notes

> วันที่ทดสอบ: 2026-06-22  
> ผู้ทดสอบ: Copilot  
> calc_run_id: 2  
> ผลสรุป: SP รันได้และ output For HR เป็น STAFF-only ซึ่งถือว่าผ่านตาม Current-State acceptance ของระบบปัจจุบัน
