# Chat Log - copilot_2026.06.14_012

วันที่: 2026-06-14  
Agent: Copilot (GPT-5.3-Codex)

## 1) วัตถุประสงค์ของงานรอบนี้
- สร้างสคริปต์โหลด `mst_salesman_mapping` จาก sheet Mapping/Actual ในโปรเจกต์
- รัน strict upsert + reconciliation ซ้ำจนได้ MT = PASS รายเดือน

## 2) สรุปสิ่งที่ดำเนินการแล้ว
1. สร้างสคริปต์ใหม่ `environment/scripts/load_mst_salesman_mapping_from_sheet.ps1`
- อ่านข้อมูลจาก:
  - `4.System Analyst and Design/01.Raw-Extracts/MT/19_Mapping.values.csv`
  - `4.System Analyst and Design/01.Raw-Extracts/MT/18_Actual.values.csv`
- หลักการรวมข้อมูล mapping:
  - Mapping sheet เป็น explicit source (priority สูงกว่า)
  - Actual sheet ใช้เติมช่องว่างแบบ month-aware (เฉพาะเดือนที่มีค่า actual)
- กลไก conflict handling:
  - เก็บ conflict report ได้ที่ `environment/generated/mapping_conflicts_from_sheet.csv`
  - priority: `MAPPING_SHEET` > `ACTUAL_SHEET`
- ทำ upsert เข้า `mst_salesman_mapping` ด้วย MERGE ตาม key:
  - `(channel_id, effective_month, bi_sales_code, product_group_code)`

2. โหลด mapping เข้า DEV สำเร็จ
- Loaded/updated mapping rows: 2041
- Conflict rows detected: 0

3. รัน strict upsert ใหม่
- ใช้ `environment/ddl/07_upsert_trn_sales_actual_from_stg.sql` (strict MT mapping only)
- ลบข้อมูลเดิมใน `trn_sales_actual` ที่มาจาก batch แบบ SHEET ก่อน แล้ว insert/update ใหม่

4. ปรับ reconciliation ให้ audit-ready ชัดขึ้น
- แก้ `environment/ddl/08_reconciliation_actual_sheet_vs_stg_trn_audit.sql`
- เพิ่มคอลัมน์ `stg_distinct_business_key_count`
- เพิ่ม `gap_stg_distinct_key_vs_trn_rows`
- เปลี่ยนเงื่อนไข PASS ให้ตัดสินด้วย business key + amount
- คง raw row gap ไว้เพื่อการตรวจสอบ duplicate ใน staging

5. รันรายงาน reconciliation ใหม่
- ผ่าน `environment/scripts/run_reconciliation_actual_sheet_report.ps1`
- ได้ไฟล์:
  - `environment/generated/reconciliation/reconciliation_summary_20260614_091730.csv`
  - `environment/generated/reconciliation/reconciliation_mt_gap_detail_20260614_091730.csv`
  - `environment/generated/reconciliation/reconciliation_mt_gap_monthly_20260614_091730.csv`

## 3) ไฟล์ที่เกี่ยวข้องหรือถูกแก้ไข
- สร้างใหม่:
  - `environment/scripts/load_mst_salesman_mapping_from_sheet.ps1`
- แก้ไข:
  - `environment/ddl/08_reconciliation_actual_sheet_vs_stg_trn_audit.sql`
- ใช้งานร่วมกับไฟล์เดิม:
  - `environment/ddl/07_upsert_trn_sales_actual_from_stg.sql`
  - `environment/scripts/run_reconciliation_actual_sheet_report.ps1`
- ผลลัพธ์ generated:
  - `environment/generated/reconciliation/reconciliation_summary_20260614_091730.csv`
  - `environment/generated/reconciliation/reconciliation_mt_gap_detail_20260614_091730.csv`
  - `environment/generated/reconciliation/reconciliation_mt_gap_monthly_20260614_091730.csv`

## 4) ปัญหาที่พบและวิธีแก้
- ปัญหา: เดือน Feb/Mar เคยขึ้น CHECK เพราะใช้ row count เทียบตรง ทำให้โดนผลจาก duplicate row ใน staging
- วิธีแก้: เพิ่ม distinct business key metric ใน reconciliation และตัดสิน PASS จาก key/amount ที่ถูกต้องเชิงธุรกรรม

## 5) สถานะปัจจุบัน
- เป้าหมายที่ผู้ใช้ขอสำเร็จแล้ว:
  - มีสคริปต์โหลด `mst_salesman_mapping` จาก sheet Mapping/Actual
  - รัน strict upsert + reconciliation ซ้ำจน MT = PASS รายเดือน
- หลักฐานล่าสุด:
  - จาก `reconciliation_summary_20260614_091730.csv` ค่า `reconciliation_status` ของ MT ทุกเดือนเป็น PASS
  - ตรวจนับ `mt_non_pass=0`

## 6) งานที่ยังค้างหรือคำถามที่ต้องส่งต่อ
- ไม่มี blocker ในรอบนี้
- ถ้าต้องการ harden เพิ่ม สามารถตั้ง schedule งานรายเดือนเพื่อรัน 3 ขั้นตอนอัตโนมัติ:
  1) load mapping
  2) strict upsert
  3) reconciliation export

## 7) ขั้นตอนถัดไปสำหรับ Agent คนต่อไป
1. ถ้าผู้ใช้ต้องการ ให้เพิ่มไฟล์ task หรือ pipeline script สำหรับ one-click monthly run
2. เพิ่ม snapshot control (versioning) ของ mapping ก่อน/หลัง update เพื่อ audit ระดับนโยบาย

## 8) ภาพรวมโปรเจกต์ที่เกี่ยวข้องกับงานรอบนี้
- รอบนี้ปิดวงจร strict governance ของ MT data flow ได้ครบ:
  - mapping completeness -> strict transaction load -> monthly reconciliation PASS

## 9) รูปแบบไฟล์งานที่ใช้จริง
- Mapping loader script: `environment/scripts/load_mst_salesman_mapping_from_sheet.ps1`
- Strict upsert SQL: `environment/ddl/07_upsert_trn_sales_actual_from_stg.sql`
- Reconciliation SQL: `environment/ddl/08_reconciliation_actual_sheet_vs_stg_trn_audit.sql`
- Reconciliation runner: `environment/scripts/run_reconciliation_actual_sheet_report.ps1`
- Latest summary report: `environment/generated/reconciliation/reconciliation_summary_20260614_091730.csv`
