# Copilot Chat Log — 2026-06-19 (001)

## 1) วัตถุประสงค์ของงานรอบนี้
- ตรวจสอบความครบถ้วนของข้อมูล MT/TT เทียบกับ sheet อ้างอิง `T_SectAbove`
- ตรวจ table ที่ใช้เก็บข้อมูลจริงสำหรับ TT
- สร้าง view สำหรับ MT โดยเฉพาะ
- เติมข้อมูล master MT ให้ครบตาม reference

## 2) สรุปสิ่งที่ดำเนินการแล้ว
- เชื่อมต่อฐานข้อมูล `AJT_SIS` (server `localhost,1437`) และตรวจข้อมูลใน `dbo.mst_incentive_rate`
- เทียบ MT กับไฟล์อ้างอิง
  - `4.System Analyst and Design/01.Raw-Extracts/MT/09_T_SectAbove.values.csv`
- ผลก่อนแก้:
  - MT ขาด `Division Manager`
  - ค่า rate ของ `Section Manager`, `Department Manager`, `Associate Director` ไม่ตรงอ้างอิง
- ตรวจ TT ว่า `T_SectAbove` เก็บที่ table ไหน
  - ยืนยันว่ามิติ Position-level + rate อยู่ที่ `dbo.mst_incentive_rate`
  - `dbo.mst_fix_rate` เป็นคนละมิติ (job_function-based fix amount)
- สร้าง view ใหม่สำหรับ MT:
  - `dbo.vw_mt_mst_position_incentive_rate_detail`
  - กรองด้วย `channel_code = 'MT'`
- เติมข้อมูล master MT ด้วย upsert (ws_type = `OLD`)
  - เพิ่ม `DIV_MGR` ที่ขาด
  - ปรับค่าตาม reference:
    - `DIV_MGR` = 5000
    - `DEPT_MGR` = 5000
    - `SECT_MGR` = 4000
    - `AD` = 6000
- ผลหลังแก้:
  - สถานะเทียบ reference = `MATCH` ครบทั้ง 4 ตำแหน่ง
  - ไม่มี `MISSING` ในชุดอ้างอิง MT

## 3) ไฟล์/ออบเจกต์ที่เกี่ยวข้อง
- Reference files:
  - `4.System Analyst and Design/01.Raw-Extracts/MT/09_T_SectAbove.values.csv`
  - `4.System Analyst and Design/01.Raw-Extracts/TT/08_T_SectAbove.values.csv`
- Database objects:
  - `dbo.mst_incentive_rate`
  - `dbo.mst_position_level`
  - `dbo.mst_channel`
  - `dbo.mst_fix_rate`
  - `dbo.vw_mst_position_incentive_rate_detail`
  - `dbo.vw_mt_mst_position_incentive_rate_detail` (สร้างใหม่)

## 4) ปัญหาที่พบและวิธีแก้
- ปัญหา: ชื่อคอลัมน์บางตารางไม่ตรงที่คาด (เช่น `channel_name`, `position_level_name`, `job_function_name`)
- วิธีแก้: อ่าน schema จริงแล้วเปลี่ยนเป็นคอลัมน์ที่ถูกต้อง
  - `mst_channel`: `channel_name_th`, `channel_name_en`
  - `mst_position_level`: `position_name_th`, `position_name_en`
  - `mst_job_function`: `job_function_name_th`, `job_function_name_en`

## 5) สถานะปัจจุบัน
- MT master (ตาม T_SectAbove) = ครบและตรงค่าอ้างอิงแล้ว (ใน ws_type = `OLD`)
- View สำหรับ MT ใช้งานได้
  - `SELECT TOP (1000) * FROM dbo.vw_mt_mst_position_incentive_rate_detail ORDER BY position_level_id, effective_from DESC;`

## 6) งานที่ยังค้าง / คำถามส่งต่อ
- ต้องการนโยบายชัดเจนสำหรับรายการนอก reference ใน MT (เช่น `Salesman / Staff`)
  - ตอนนี้ยังคงไว้ ไม่ได้ลบ เพื่อเลี่ยงกระทบระบบส่วนอื่น
- ถ้าต้องการ strict master-by-reference อาจต้องเพิ่ม script cleanup พร้อม backup ก่อนลบ

## 7) ขั้นตอนถัดไป (สำหรับ Agent ถัดไป)
1. ทำ script รายงาน diff อัตโนมัติ (reference vs DB) สำหรับ MT/TT
2. ทำ validation rule ก่อน deploy (block ถ้ามี `MISSING`/`MISMATCH`)
3. หาก business ยืนยัน ให้จัดการรายการนอก reference (`Salesman / Staff`) ตามนโยบายข้อมูล

## 8) ภาพรวมโปรเจกต์ที่ต้องคงไว้
- โครงสร้างหลักอยู่ภายใต้โฟลเดอร์:
  - `3.Estimate Manday(s)` สำหรับเอกสารประเมิน
  - `4.System Analyst and Design` สำหรับ raw extracts และงานวิเคราะห์/ออกแบบ
  - `environment` สำหรับสคริปต์/เอกสารเทคนิค
- บริบทล่าสุดของงานด้าน DB: เน้นให้ master rate ของ MT/TT ตรงกับ sheet อ้างอิง และแยก view ตาม channel เพื่อใช้งานสะดวก

## 9) รูปแบบไฟล์งานที่ใช้จริงในรอบนี้
- chat-log file: `chat-log/copilot_2026.06.19_001.md`
- SQL object naming ที่เพิ่ม: `vw_mt_mst_position_incentive_rate_detail`
- วันที่อ้างอิง session: `2026-06-19`
