# Chat Log - copilot_2026.06.14_023

วันที่: 2026-06-14
Agent: Copilot (GPT-5.3-Codex)

## 1) วัตถุประสงค์ของงานรอบนี้
- สร้างสคริปต์โหลด HR Rep -> stg_hcm_employee -> merge mst_employee
- รันซ้ำจน Missing = 0 และจัดทำรายงานก่อน-หลัง

## 2) สรุปสิ่งที่ดำเนินการแล้ว
- สร้างสคริปต์ใหม่ `environment/scripts/load_mst_employee_from_hr_sheet.ps1`
- Logic หลักของสคริปต์:
  - parse CSV ที่มี header ซ้ำ
  - normalize EmpCode
  - derive `position_code` และ `job_function_code`
  - bulk load เข้า `stg_hcm_employee`
  - merge upsert เข้า `mst_employee`
- แก้บั๊กระหว่างรัน:
  - DataTable return ถูก enumerate จนเป็น null -> แก้เป็น `return ,$dt`
  - SQL aggregate `MAX(bit)` ใช้ไม่ได้ -> แก้ด้วย cast tinyint แล้ว cast กลับ bit
- รันสำเร็จ:
  - `BATCH_ID=HR_REP_20260614_174849`
  - `STG_LOADED_ROWS=118`

## 3) ผลตรวจก่อน-หลัง
- ก่อนโหลด:
  - MT: Missing 28
  - TT: Missing 90
- หลังโหลด:
  - MT: Missing 0
  - TT: Missing 0

## 4) ไฟล์ที่เกี่ยวข้องหรือถูกแก้ไข
- สร้างใหม่:
  - `environment/scripts/load_mst_employee_from_hr_sheet.ps1`
  - `environment/scripts/check_mst_employee_vs_hr_sheet.ps1`
  - `final-docs/AJT_HR-Rep_to_mst_employee_Before-After_Report_2026-06-14.md`
  - `chat-log/copilot_2026.06.14_023.md`

## 5) สถานะปัจจุบัน
- เป้าหมายสำเร็จตามเงื่อนไข: Missing MT/TT = 0
