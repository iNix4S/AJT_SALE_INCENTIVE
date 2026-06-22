# TC02 — พนักงานปกติ MT Channel

**Scenario:** คำนวณ Incentive สำหรับพนักงาน MT Channel ให้ครบ layer ตามโครงสร้างจริง
**Channel:** MT (`channel_id = 1`)
**SP:** `usp_run_mt_incentive_calculation`
**Hierarchy (จากผลจริง):** STAFF → SECT_MGR → DEPT_MGR → AD

## Mapping ให้ตรงระบบจริง (DB ปัจจุบัน)

- SP ใช้พารามิเตอร์: `@PeriodId`, `@ApprovedBy`
- ตารางผล For HR ใช้: `dbo.out_for_hr_variable`
- `calc_run_id` อ้างอิงจาก `dbo.trn_calc_run`
- ไม่มีการใช้งาน `dbo.incentive_results` ในระบบปัจจุบัน

---

## Pre-Conditions

- [ ] มี Period สำหรับ MT ใน `dbo.mst_period` (รอบมาตรฐานใช้ `period_id = 1`)
- [ ] มีข้อมูลพนักงาน MT ใน `dbo.mst_employee`
- [ ] มีข้อมูล sales/goal/weight ที่ใช้คำนวณครบ
- [ ] มีสิทธิ์เรียก SP และเขียน `trn_calc_run`

---

## Test Steps (ฉบับตรงระบบจริง)

| # | ขั้นตอน | คำสั่ง / วิธีการ |
|---|---------|------------------|
| 1 | ตรวจ period | `SELECT period_id, period_code FROM dbo.mst_period` |
| 2 | รัน SP | `EXEC dbo.usp_run_mt_incentive_calculation @PeriodId = 1, @ApprovedBy = 'system'` |
| 3 | หา calc_run_id ล่าสุดของ MT | `SELECT TOP (1) calc_run_id FROM dbo.trn_calc_run WHERE channel_id=1 AND period_id=1 ORDER BY calc_run_id DESC` |
| 4 | ตรวจผล For HR | `SELECT employee_code, position_level_code, total_variable FROM dbo.out_for_hr_variable WHERE calc_run_id=<id>` |
| 5 | ตรวจ duplicate employee | GROUP BY employee_code HAVING COUNT(*) > 1 |
| 6 | เทียบ preset manager | เทียบ employee_code กับ expected amount |

---

## Checklist — PASS/FAIL

### โครงสร้างผลลัพธ์
- [ ] row count ถูกต้อง (period_id=1 คาดหวัง 27 rows)
- [ ] ไม่มี employee_code ซ้ำ
- [ ] มีอย่างน้อย 4 level (`STAFF`, `SECT_MGR`, `DEPT_MGR`, `AD`)

### Manager preset verification
- [ ] 222208 = 5,765.00
- [ ] 222222 = 6,732.00
- [ ] 222223 = 5,959.00
- [ ] 222234 = 5,964.00
- [ ] 222235 = 6,233.68 (ยอมรับ tolerance จาก rounding)
- [ ] 222236 = 5,900.00
- [ ] 222237 = 6,058.59 (ยอมรับ tolerance จาก rounding)
- [ ] 222238 = 5,113.13 (ยอมรับ tolerance จาก rounding)

### Operational
- [ ] SP รันสำเร็จ ไม่มี error
- [ ] มี `calc_run_id` ใหม่ใน `trn_calc_run`

---

## Execution Evidence ล่าสุด (2026-06-22)

- calc_run_id ล่าสุด (MT): `1025`
- row count: `27`
- duplicate employee: `0`
- level ที่พบ: `AD, DEPT_MGR, SECT_MGR, STAFF`
- manager preset check: ผ่าน (difference ภายใน tolerance)

**สรุปสถานะ TC02:** ✅ **PASS**

---

## Notes

> วันที่ทดสอบ: 2026-06-22
> ผู้ทดสอบ: Copilot
> หมายเหตุ: ใช้ผลจาก `out_for_hr_variable` เท่านั้น
