# Chat Log - copilot_2026.06.14_011

วันที่: 2026-06-14  
Agent: Copilot (GPT-5.3-Codex)

## 1) วัตถุประสงค์ของงานรอบนี้
- เปลี่ยนเป็นโหมด strict:
  1. MT ต้องผ่าน `mst_salesman_mapping` เท่านั้น (ไม่ใช้ fallback)
  2. เพิ่มรายงาน reconciliation รายเดือนเทียบ Sheet กับ `stg_bi_sales` และ `trn_sales_actual` แบบ audit-ready

## 2) สรุปสิ่งที่ดำเนินการแล้ว
- แก้ไฟล์ `environment/ddl/07_upsert_trn_sales_actual_from_stg.sql`
  - เปลี่ยน logic MT จาก fallback mode เป็น strict mode
  - เดิม: `COALESCE(msm.salesman_code, s.salesman_code, s.bi_sales_code)`
  - ใหม่: `msm.salesman_code` เท่านั้น
  - ปรับข้อความ unresolved reason ให้ชัดเจนว่าเป็น strict mode
- สร้างไฟล์ใหม่ `environment/ddl/08_reconciliation_actual_sheet_vs_stg_trn_audit.sql`
  - สรุปรายเดือน/ช่องทาง: row count + amount ของ Sheet vs STG vs TRN
  - คำนวณ gap (`sheet_vs_stg`, `stg_vs_trn`) ทั้งจำนวนแถวและยอดเงิน
  - สถานะ `PASS/CHECK` ต่อเดือน
  - รายละเอียด unresolved MT mapping (detail + monthly aggregate)
- สร้างไฟล์ใหม่ `environment/scripts/run_reconciliation_actual_sheet_report.ps1`
  - รัน SQL report และ export CSV อัตโนมัติ 3 ไฟล์
- รันโหลด Actual sheet ใหม่เข้า staging แล้วรัน strict upsert โดยลบข้อมูล sheet batch เดิมใน `trn_sales_actual` ก่อน
- รัน reconciliation report และสร้างไฟล์ผลลัพธ์ใน `environment/generated/reconciliation/`

## 3) ไฟล์ที่เกี่ยวข้องหรือถูกแก้ไข
- แก้ไข:
  - `environment/ddl/07_upsert_trn_sales_actual_from_stg.sql`
- สร้างใหม่:
  - `environment/ddl/08_reconciliation_actual_sheet_vs_stg_trn_audit.sql`
  - `environment/scripts/run_reconciliation_actual_sheet_report.ps1`
  - `chat-log/copilot_2026.06.14_011.md`
- ไฟล์ผลลัพธ์รายงาน (generated):
  - `environment/generated/reconciliation/reconciliation_summary_20260614_091418.csv`
  - `environment/generated/reconciliation/reconciliation_mt_gap_detail_20260614_091418.csv`
  - `environment/generated/reconciliation/reconciliation_mt_gap_monthly_20260614_091418.csv`

## 4) ปัญหาที่พบและวิธีแก้
- หลังเปิด strict mode พบว่า MT mapping ไม่ครบใน `mst_salesman_mapping`
- ผลคือข้อมูล MT จาก sheet ไม่สามารถเข้า `trn_sales_actual` ได้
- รายงาน reconciliation จึงแสดง `CHECK` ทุกเดือนของ MT พร้อมจำนวนและมูลค่าที่ตกหล่น

## 5) สถานะปัจจุบัน
- Strict mode ใช้งานแล้วจริง
- ผลใน DEV หลัง strict upsert:
  - `trn_sales_actual` (source batch แบบ SHEET):
    - TT = 277 rows
    - MT = 0 rows
  - unresolved MT จาก staging = 2010 rows
- Reconciliation report พร้อมใช้งานแบบ audit-ready แล้ว (CSV 3 ไฟล์)

## 6) งานที่ยังค้างหรือคำถามที่ต้องส่งต่อ
- ต้องเติมข้อมูลใน `mst_salesman_mapping` ให้ครอบคลุม MT ทุกเดือน/ทุก product group หากต้องการให้ MT เข้า `trn_sales_actual` ภายใต้ strict mode

## 7) ขั้นตอนถัดไปสำหรับ Agent คนต่อไป
1. สร้าง/โหลด mapping เพิ่มใน `mst_salesman_mapping` จาก source mapping sheet
2. รัน `07_upsert_trn_sales_actual_from_stg.sql` ซ้ำ
3. รัน `run_reconciliation_actual_sheet_report.ps1` ซ้ำเพื่อตรวจว่ากลายเป็น `PASS` ฝั่ง MT

## 8) ภาพรวมโปรเจกต์ที่เกี่ยวข้องกับงานรอบนี้
- รอบนี้ปรับจาก tolerance mode เป็น governance mode (strict) ตามคำขอผู้ใช้
- ระบบจึงทำหน้าที่เป็น quality gate ชัดเจน: ถ้า mapping ไม่ครบ จะไม่ปล่อยเข้าตาราง transaction

## 9) รูปแบบไฟล์งานที่ใช้จริง
- Strict upsert SQL: `environment/ddl/07_upsert_trn_sales_actual_from_stg.sql`
- Reconciliation SQL: `environment/ddl/08_reconciliation_actual_sheet_vs_stg_trn_audit.sql`
- Reconciliation runner: `environment/scripts/run_reconciliation_actual_sheet_report.ps1`
- Report output folder: `environment/generated/reconciliation/`
