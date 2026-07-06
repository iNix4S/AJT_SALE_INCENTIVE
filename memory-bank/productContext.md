# Product Context — AJT New Sale Incentive

## ปัญหาที่ระบบนี้แก้

ก่อนมีระบบนี้ AJT คำนวณ incentive ผ่าน Excel หลายไฟล์แยกต่อ channel (MT/TT/SI/LAOS) ทำให้:
- คำนวณช้า, เสี่ยง human error, ตรวจสอบย้อนหลังยาก
- แต่ละ channel มีสูตรคำนวณต่างกันมาก (cascade 4 ระดับ vs single-sheet เฉลี่ย 5 ระดับ)
- กรณีพิเศษ (พนักงานเข้า/ออกกลางเดือน, สินค้าขาด, สถานการณ์พิเศษ) ต้องปรับ Excel มือ
- ไม่มี audit trail ว่าทำไมพนักงานคนหนึ่งได้ incentive เท่านี้

ระบบนี้แปลง logic จาก Excel เดิม → SQL Server (stored procedures + views) + Web UI
เพื่อให้คำนวณอัตโนมัติ, ตรวจสอบได้, และแก้ไข parameter ได้โดยไม่ต้องแก้โค้ด

## ผู้ใช้งานหลัก (Personas)

| บทบาท | ใช้ทำอะไร |
|---|---|
| **Sales Admin / HR** | รันรอบคำนวณ (Calculation), ตรวจสอบผล, export For HR |
| **System Analyst / Finance** | ปรับ master data (rate, threshold, formula), ดู Dashboard/Executive View |
| **IT/Dev (Implementation team)** | ต่อยอด channel ใหม่, ปรับ formula ผ่าน API, ดูแล data archive |

## Flow การทำงานหลัก (End-to-End)

1. **Target/Actual data เข้า** ผ่าน DWC/BI interface → เก็บใน `trn_sales_target`, `trn_sales_actual`
2. **Prorate/Special Adjustment** (ถ้ามี) — บันทึกผ่านหน้า Prorate/SpecialAdjust ก่อนรันคำนวณ
3. **รัน Calculation** ต่อ channel → เรียก stored procedure (หรือ SqlFunction/NCalc engine) → เขียนผลลง
   `trn_incentive_detail`, `out_for_hr_variable`
4. **Validation Gate** (Data Interface page) — เช็คความครบถ้วนของข้อมูลก่อนอนุมัติ
5. **For HR Export** — ดึงผลจาก view (`vw_for_hr_{channel}_sheet`) ออกเป็น CSV/Excel ให้ HR
6. **Dashboard** — ดูสถานะรอบคำนวณ, KPI, top performers, sales trend

## UX/Design Goals

- **Fluent Design** (Microsoft Fluent) เป็นแนวทาง UI หลัก — สี primary `#0078d4`, สี neutral
  เทา `#64748b`/`#94a3b8` (เริ่มใช้ตั้งแต่ 2026-07-03 ที่ Dashboard + Data Interface)
- Semantic color ต้องคงไว้เสมอ (PASS=เขียว, FAIL=แดง, PENDING=เทา) แม้จะเปลี่ยน theme
- รองรับ bilingual TH/EN ในหน้าที่ผู้ใช้ AJT ต้องอ่าน (Prorate, SpecialAdjust)
- Drill-down modal สำหรับรายละเอียด (Prorate/Special Adjustment) แทนการแสดงทุกอย่างในตาราง

## Business Rules สำคัญที่ต้องคงไว้เสมอ

- **Threshold-based multiplier**: achievement % → step-down multiplier ตาม `mst_goal_threshold`
  (เช่น <90% = ไม่ได้ incentive, ≥130% = cap ที่ 1.30)
- **Prorate types**: `JOIN`, `RESIGN`, `TRANSFER`, `POSITION_CHANGE` — ปรับสัดส่วนวันทำงาน
- **Special Adjustment types**: `SHORTAGE` (สินค้าขาด → ปรับ Actual = 100%), `SPECIAL_SITUATION`
  (ปรับ Sales Target และ/หรือ % Allocation Weight)
- **Manager Cascade**: Section → Dept → Div → AD ใช้ team achievement เฉลี่ยของลูกทีมในการคำนวณ
  (สำคัญมากสำหรับ TT/SI/LAOS ที่มี org hierarchy หลายชั้น)
- **Fixed rate**: บาง job function (เช่น TT Cash Van Sales) มีค่าตอบแทนอัตราคงที่แยกจาก formula ปกติ

## Open Business Decisions (ยังไม่ปิด — ดู progress.md ด้วย)

- **DL-001**: Policy 108% → ใช้ multiplier 1.06 จริงหรือควรเป็น 1.08?
- **DL-002**: Laos ถือเป็น scope ของ TT department หรือแยกนอก scope?
- **DL-003**: GD (Growth Driver) payout รวมกับ For HR (additive) หรือแยก (replace)?
