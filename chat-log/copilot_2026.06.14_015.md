# Chat Log - copilot_2026.06.14_015

วันที่: 2026-06-14
Agent: Copilot (GPT-5.3-Codex)

## 1) วัตถุประสงค์ของงานรอบนี้
- ตรวจว่า `mst_org_hierarchy` มีข้อมูลครบตาม sheet ASTBase หรือไม่

## 2) สรุปสิ่งที่ดำเนินการแล้ว
- ตรวจไฟล์ ASTBase จาก raw extracts:
  - MT: `4.System Analyst and Design/01.Raw-Extracts/MT/11_ASTBase.values.csv`
  - TT: `4.System Analyst and Design/01.Raw-Extracts/TT/13_ASTBase.values.csv`
- สร้างสคริปต์ตรวจเทียบ key ระหว่าง sheet กับ DB:
  - `environment/scripts/check_org_hierarchy_vs_sheet.ps1`
- รันสคริปต์และดึงผลเทียบ `(effective_month + salesman_code)` แยกตาม channel

## 3) ไฟล์ที่เกี่ยวข้องหรือถูกแก้ไข
- สร้างใหม่:
  - `environment/scripts/check_org_hierarchy_vs_sheet.ps1`
  - `chat-log/copilot_2026.06.14_015.md`

## 4) ปัญหาที่พบและวิธีแก้
- ไฟล์ CSV ASTBase มี header ซ้ำ (`Salesman Code`) ทำให้ Import-Csv ปกติใช้งานไม่ได้
- แก้โดยเขียน loader ที่ rename header ซ้ำเป็นชื่อ unique ก่อน parse

## 5) สถานะปัจจุบัน (ผลตรวจ)
ผลจากสคริปต์:
- SHEET_MT_KEYS = 19
- SHEET_TT_KEYS = 20
- DB_MT_KEYS = 4
- DB_TT_KEYS = 0
- MISSING_MT_KEYS = 19
- MISSING_TT_KEYS = 20

สรุป: `mst_org_hierarchy` ยังไม่ครบตาม ASTBase sheet (ทั้ง MT และ TT)

## 6) งานที่ยังค้างหรือคำถามที่ต้องส่งต่อ
- ต้องทำสคริปต์โหลด/merge ข้อมูล ASTBase เข้า `mst_org_hierarchy` ให้ครบทั้ง MT และ TT

## 7) ขั้นตอนถัดไปสำหรับ Agent คนต่อไป
1. สร้าง script load hierarchy จาก ASTBase sheet (รองรับ month + channel)
2. รัน load แล้วตรวจซ้ำด้วยสคริปต์ check เดิมจน missing = 0

## 8) ภาพรวมโปรเจกต์ที่เกี่ยวข้องกับงานรอบนี้
- งานรอบนี้ยืนยัน data completeness gap ของ hierarchy ซึ่งเป็น control point สำคัญต่อการคำนวณ MT/TT cascade

## 9) รูปแบบไฟล์งานที่ใช้จริง
- Validation script: `environment/scripts/check_org_hierarchy_vs_sheet.ps1`
- Chat log รอบนี้: `copilot_2026.06.14_015.md`
