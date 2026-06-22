# Chat Log - copilot_2026.06.14_029

วันที่: 2026-06-14
Agent: Copilot (GPT-5.3-Codex)

## 1) วัตถุประสงค์ของงานรอบนี้
- เพิ่ม migration คอลัมน์ incentive_div ใน out_for_hr_variable
- ปรับ TT calculation procedure ให้เขียน incentive_div แยกใน output
- ขยาย runner ให้รันครบ FY และสร้าง reconciliation report อัตโนมัติใน final-docs
- เพิ่ม SQL validation ต่อ sheet ครบ 26 sheets แบบ pass/fail matrix

## 2) สิ่งที่ดำเนินการแล้ว
1. สร้าง migration ใหม่
- ไฟล์: environment/ddl/16_add_incentive_div_to_out_for_hr_variable.sql
- เพิ่มคอลัมน์ incentive_div และ default constraint
- ปรับเป็นหลาย GO batches เพื่อเลี่ยง compile-time invalid column ใน batch เดียว

2. ปรับ procedure คำนวณ TT
- ไฟล์: environment/ddl/15_create_proc_run_tt_incentive_calculation.sql
- เพิ่มการ insert ค่า incentive_div ลง out_for_hr_variable

3. สร้าง SQL validation 26 sheets
- ไฟล์: environment/ddl/17_create_proc_validate_tt_26_sheets_pass_fail.sql
- สร้าง proc dbo.usp_validate_tt_26_sheets_pass_fail @PeriodCode
- รองรับ compare_mode: EXACT / NONZERO / INFO
- ใช้ #tt_sheet_source_metrics จาก runner เพื่อเทียบ source extract กับ DB metrics

4. สร้าง FY runner แบบครบวงจร
- ไฟล์: environment/scripts/run_tt_fy_pipeline_and_reconciliation.ps1
- Deploy DDL: 16 -> 15 -> 17
- หา period ทั้ง FY (Apr-Mar)
- รัน usp_run_tt_incentive_calculation ทุก period ที่มี target
- โหลด source metrics จาก TT CSV
- เรียก validation proc ต่อ period
- ส่งออกไฟล์รายงานอัตโนมัติใน final-docs

## 3) ปัญหาที่พบและการแก้
1. Migration ล้มเหลวด้วย Invalid column incentive_div
- สาเหตุ: เพิ่มคอลัมน์และอ้างคอลัมน์ใน batch เดียว
- แก้ไข: แยก GO batch และแยกขั้นตอน add column / add constraint / update

2. Validation proc อ้างคอลัมน์ GD ผิด
- เดิมใช้ product_code, incentive_amount
- schema จริงใช้ gd_product_code, payout_amount
- แก้ไข query ให้ตรง schema DEV

3. Runner ล้มเหลวจาก DataTable null
- สาเหตุ: PowerShell enumerate DataTable ว่าง
- แก้ไข: return ,$dt

4. Runner ล้มเหลวจากไฟล์ single-line
- สาเหตุ: Get-Content คืน string เดี่ยว ไม่มี Count
- แก้ไข: ห่อเป็น array ด้วย @(Get-Content ...)

## 4) ผลลัพธ์การรันจริง
- รันสำเร็จครบ 12 periods ใน FY2026 (Apr 2026 - Mar 2027)
- output:
  - final-docs/AJT_TT_FY_Reconciliation_Report_20260614_193558.md
  - final-docs/AJT_TT_FY_Run_Result_20260614_193558.csv
  - final-docs/AJT_TT_26Sheet_Validation_Matrix_20260614_193558.csv

สรุปสถานะในรายงาน:
- PASS: 87
- FAIL: 45
- INFO: 180

## 5) ไฟล์ที่แก้ไข/เพิ่ม
- environment/ddl/15_create_proc_run_tt_incentive_calculation.sql
- environment/ddl/16_add_incentive_div_to_out_for_hr_variable.sql
- environment/ddl/17_create_proc_validate_tt_26_sheets_pass_fail.sql
- environment/scripts/run_tt_fy_pipeline_and_reconciliation.ps1
- chat-log/copilot_2026.06.14_029.md

## 6) สถานะปัจจุบัน
- งานตามคำขอทั้ง 3 ข้อดำเนินการครบและรันจริงแล้ว
- มีรายการ FAIL ที่สะท้อน data gap จริง (เช่น ASTBase บางเดือนไม่มี, AD sheet mismatch, shortage บางเดือนไม่มีข้อมูล)

## 7) ขั้นตอนถัดไป (สำหรับรอบถัดไป)
1. ปรับ rule compare_mode ราย sheet ให้ strict ตาม business expectation ต่อ sheet
2. ทำ source parser เฉพาะ sheet 18-25 เพื่อเปลี่ยนจาก INFO เป็น EXACT/NONZERO ได้แม่นขึ้น
3. เพิ่ม baseline/tolerance config แยก per sheet ในไฟล์ config กลาง เพื่อให้ QA ปรับเองได้
