# Chat Log - copilot_2026.06.14_010

วันที่: 2026-06-14  
Agent: Copilot (GPT-5.3-Codex)

## 1) วัตถุประสงค์ของงานรอบนี้
- ผู้ใช้สั่งให้โหลดข้อมูลจาก Sheet `Actual` ลงทั้ง 2 ตารางให้ครบถ้วน:
  - `stg_bi_sales`
  - `trn_sales_actual`
- ต้องรองรับทั้ง MT และ TT

## 2) สรุปสิ่งที่ดำเนินการแล้ว
- สร้างโครงสร้างสำหรับงานแปลง/โหลดข้อมูล:
  - `environment/scripts/`
  - `environment/generated/`
- สร้างสคริปต์ใหม่ `environment/scripts/convert_actual_sheet_to_stg.ps1`
  - อ่านไฟล์:
    - `4.System Analyst and Design/01.Raw-Extracts/MT/18_Actual.values.csv`
    - `4.System Analyst and Design/01.Raw-Extracts/TT/12_Actual.values.csv`
  - แปลงข้อมูลแบบ wide (Apr-Mar) -> normalized rows
  - รองรับคอลัมน์ `MaQh` (TT) ให้ map เป็น March
  - generate `batch_id` รายเดือนต่อ channel
  - export เป็นไฟล์ `environment/generated/stg_bi_sales_from_actual_sheet.csv`
  - รองรับโหลดเข้า DB โดยตรงผ่าน `SqlBulkCopy`
  - เพิ่ม de-dup ก่อน bulk insert โดยลบข้อมูลเดิมตาม `batch_id` ที่จะโหลด
- สร้าง SQL ใหม่ `environment/ddl/07_upsert_trn_sales_actual_from_stg.sql`
  - merge จาก `stg_bi_sales` -> `trn_sales_actual`
  - join `mst_period` และ `mst_channel`
  - MT: resolve `salesman_code` โดย priority:
    1) `mst_salesman_mapping`
    2) `stg_bi_sales.salesman_code`
    3) `stg_bi_sales.bi_sales_code`
  - TT: ใช้ `stg_bi_sales.salesman_code` ตรง
  - update/insert ตาม business key `(period_id, channel_id, salesman_code, product_code)`
  - แสดง unresolved rows ถ้ายังเหลือ
- รันโหลดจริงบน DEV (`AJT_SIS`) ด้วยค่าใน `environment/database-dev.env`
  - export + load staging + upsert transaction สำเร็จ

## 3) ไฟล์ที่เกี่ยวข้องหรือถูกแก้ไข
- สร้างใหม่:
  - `environment/scripts/convert_actual_sheet_to_stg.ps1`
  - `environment/ddl/07_upsert_trn_sales_actual_from_stg.sql`
  - `environment/generated/stg_bi_sales_from_actual_sheet.csv`
  - `chat-log/copilot_2026.06.14_010.md`

## 4) ปัญหาที่พบและวิธีแก้
1. ปัญหาอ่านคอลัมน์ `March` แล้วล้มใน TT
- สาเหตุ: ไฟล์ TT ใช้ header `MaQh`
- วิธีแก้: เพิ่ม safe column getter และ map `MaQh` -> March

2. ปัญหา SQL upsert ล้มด้วย `Invalid object name 'src_base'`
- สาเหตุ: CTE scope สิ้นสุดก่อน query รายงาน unresolved
- วิธีแก้: เปลี่ยนเป็น temp tables `#src_base` และ `#src_ready`

3. ความเสี่ยงข้อมูล staging ซ้ำเมื่อรันหลายรอบ
- วิธีแก้: ก่อน bulk insert ให้ลบข้อมูลเดิมของ `batch_id` เดียวกัน

## 5) สถานะปัจจุบัน (ผลตรวจหลังรัน)
ผลจาก DEV DB หลังโหลดล่าสุด:

- Exported rows จาก Sheet Actual: `2,287`
  - MT: `2,010`
  - TT: `277`
- `stg_bi_sales` (status VALIDATED/PROCESSED):
  - MT: `2,022`
  - TT: `285`
  - รวม: `2,307`
- `trn_sales_actual`:
  - MT: `2,020`
  - TT: `285`
  - รวม: `2,305`
- unresolved MT หลังใช้ fallback: `0`

หมายเหตุ:
- จำนวนใน `trn_sales_actual` ต่ำกว่า staging raw เพราะใช้ business key แบบ unique ทำให้ข้อมูลที่ซ้ำ key ถูก merge/update ไม่เพิ่มแถวใหม่

## 6) งานที่ยังค้างหรือคำถามที่ต้องส่งต่อ
- ปัจจุบันให้ fallback สำหรับ MT จากค่าบน sheet เพื่อให้โหลดครบถ้วน
- หากต้องการมาตรฐานแบบ strict (ห้าม fallback) ควรปิด fallback และบังคับเติม `mst_salesman_mapping` ให้ครบทุกเดือน/ทุก product group

## 7) ขั้นตอนถัดไปสำหรับ Agent คนต่อไป
1. ถ้าต้องการ strict mode ให้ปรับ SQL upsert ให้ MT ใช้ mapping เท่านั้น
2. เพิ่ม data quality report แยก:
   - rows imported
   - rows merged
   - rows updated
   - rows dropped (if strict)
3. พิจารณาเพิ่ม workflow schedule สำหรับรันสคริปต์รายเดือนอัตโนมัติ

## 8) ภาพรวมโปรเจกต์ที่เกี่ยวข้องกับงานรอบนี้
- รอบนี้ปิด gap สำคัญจากคำขอผู้ใช้ที่ต้องการให้ข้อมูลจาก Sheet `Actual` ลงครบทั้ง staging และ transaction
- เครื่องมือที่สร้างสามารถรันซ้ำได้ และรองรับ MT/TT พร้อมกันในคำสั่งเดียว

## 9) รูปแบบไฟล์งานที่ใช้จริง
- Script: `environment/scripts/convert_actual_sheet_to_stg.ps1`
- SQL Upsert: `environment/ddl/07_upsert_trn_sales_actual_from_stg.sql`
- Generated CSV: `environment/generated/stg_bi_sales_from_actual_sheet.csv`
- Chat log รอบนี้: `copilot_2026.06.14_010.md`
