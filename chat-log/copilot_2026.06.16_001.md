# Copilot Chat Log — 2026-06-16 (#001)

## 1) วัตถุประสงค์ของงานรอบนี้

อัปเดตเอกสารสรุปขอบเขตโครงการ `AJT_Project-Scope-Summary.md` ให้สอดคล้องกับ:

- เอกสารวิเคราะห์ในโฟลเดอร์ `4.System Analyst and Design`
- การออกแบบ/สถานะ Demo และ DDL ในโฟลเดอร์ `environment`
- ข้อมูลจริงจากตาราง `dbo.mst_channel` (4 channels)
- เพิ่มหัวข้อ `Prorate Logic` และ `Special Adjustment`
- เพิ่มสรุปสูตรคำนวณหลักครบทั้ง 4 channel เพื่อใช้ประกอบ Project Scope

---

## 2) สรุปสิ่งที่ดำเนินการแล้ว

### 2.1 ทบทวนแหล่งข้อมูลหลัก
อ่าน/ตรวจข้อมูลจากไฟล์หลักดังนี้:

- `4.System Analyst and Design/03.Calculation-Logic/00_สรุปตรรกะการคำนวณ_ตั้งต้น.md`
- `4.System Analyst and Design/04.Data-Dictionary/01_Product-Code-Mapping.md`
- `4.System Analyst and Design/05.Process-Flow/01_Data-Flow-Diagram.md`
- `4.System Analyst and Design/database design/DB-Design_AJT-New-Sale-Incentive_v1.0_2026-06-13.md`
- `5.Docs/Sales Incentive System for POC.md`
- ตรวจค่า channel จริงจาก `dbo.mst_channel` (MT, TT, SI, LAOS)

### 2.2 อัปเดตไฟล์ Scope Summary (สำเร็จ)
ปรับเนื้อหาใน `final-docs/AJT_Project-Scope-Summary.md` โดยเพิ่ม/ปรับหัวข้อสำคัญ:

1. **Section 2b: สถานะ POC ปัจจุบัน**
- เพิ่มสถานะ DDL 01–39, TT SP v9, และส่วนที่ยังรอ implement

2. **Section 3.2: ช่องทางขายที่รองรับ (ยึด `mst_channel`)**
- เปลี่ยนเป็น 4 channels ตาม master data จริง
- MT: `CASCADE_4_LEVEL`
- TT: `SINGLE_SHEET_5_LEVEL_AVG`
- SI: `CASCADE_4_LEVEL`
- LAOS: `SINGLE_SHEET`
- ระบุว่า GD/Fixed เป็น sub-calculation ไม่ใช่ channel

3. **Section 3b: โครงสร้างฐานข้อมูล AJT_SIS**
- สรุป 32 ตาราง และแบ่งกลุ่ม master/staging/trn/output/audit
- ระบุ master table สำคัญที่กระทบการคำนวณ

4. **Section 5b: สูตรคำนวณหลัก (Core Formula)**
- สูตรพื้นฐาน incentive
- ตาราง achievement → GOAL multiplier
- base rate ตามตำแหน่ง
- product weight ตาม ws_type
- เพิ่มสรุปสูตรแยกตาม 4 channels

5. **Section 5c: Prorate Logic**
- เพิ่มกรณีใช้งานสำคัญ (เข้า/ออกกลางเดือน, transfer, เปลี่ยนตำแหน่ง)
- ระบุสถานะยืนยัน/รอยืนยัน
- ใส่สูตร prorate เบื้องต้นและ Open Question เพื่อปิดกับ Business/HR

6. **Section 5d: Special Adjustment**
- เพิ่มประเภท adjustment หลัก + logic + ตาราง DB + สถานะ
- เพิ่ม Fix Rate ที่ยืนยันแล้ว
- เพิ่ม Control Gate (approval + audit trail + before/after)

7. **Section 10: MT vs TT comparison**
- ปรับ `calc_type` MT ให้ตรงฐานข้อมูลจริง (`CASCADE_4_LEVEL`)

8. **Section 12: เอกสารอ้างอิงหลัก**
- เพิ่มลิงก์เอกสาร SA Analysis, DB Design, และ `environment/ddl/`

---

## 3) ไฟล์ที่เกี่ยวข้อง/ถูกแก้ไข

- แก้ไขหลัก: `final-docs/AJT_Project-Scope-Summary.md`
- สร้างใหม่: `chat-log/copilot_2026.06.16_001.md`

---

## 4) ปัญหาที่พบและวิธีแก้

1. **ข้อมูล channel ใน scope เดิมไม่ตรง master data**
- เดิมเขียนเป็น MT/TT/GD/Fixed
- แก้โดยยึด `dbo.mst_channel` เป็น source of truth (MT/TT/SI/LAOS)

2. **Prorate policy ยังไม่ปิดกับ Business/HR บางกรณี**
- แก้โดยใส่เป็น Open Question ชัดเจนใน scope
- ระบุว่าระบบต้องรองรับ scenario และ block เคสที่ policy ยังไม่ชัด

3. **Special Adjustment เดิมกระจายอยู่หลายเอกสาร**
- แก้โดยรวมสรุปไว้ใน section เดียว พร้อมผูกกับตาราง DB ที่เกี่ยวข้อง

---

## 5) สถานะปัจจุบัน

### สถานะเอกสาร
- `final-docs/AJT_Project-Scope-Summary.md` อัปเดตแล้วและพร้อมใช้อ้างอิงในการคุย scope
- เนื้อหาครอบคลุม project scope + calculation logic + special cases มากขึ้น

### สถานะระบบ/เทคนิค (ภาพรวม)
- DDL 01–39: deployed แล้ว
- TT calculation engine (SP v9): ผ่านการตรวจผล FY2026-05
- MT/SI/LAOS engine: ยังอยู่ใน phase implement
- GD/Fixed: schema พร้อม แต่ยังต้อง implement flow production

---

## 6) งานค้าง / คำถามที่ต้องส่งต่อ

1. **Prorate policy ที่ต้อง finalize ก่อน UAT**
- พนักงานลาออกกลางเดือน: prorate หรือไม่จ่าย
- เปลี่ยน position กลางเดือน: ใช้ position ใดคำนวณ
- transfer ข้าม region/channel: สูตรแบ่งวันและ cutoff rule ที่เป็นทางการ

2. **Special Situation governance**
- ใครอนุมัติ, ใช้หลักฐานอะไร, rollback อย่างไร
- ต้องการ config-level หรือ case-by-case transaction-level

3. **LAOS implementation detail**
- แม้มีใน `mst_channel` แล้ว แต่ logic production ยังไม่ finalize

---

## 7) ขั้นตอนถัดไป (สำหรับ Agent คนต่อไป)

1. ปิด OQ ด้าน Prorate กับ Business/HR/Finance และออก policy matrix เวอร์ชันอนุมัติ
2. แปลง policy ที่อนุมัติเป็น rule ใน DB/API (พร้อม test case)
3. เพิ่ม section acceptance criteria สำหรับ prorate/special adjustment ในเอกสาร scope
4. อัปเดตเอกสารคู่มือ run/check ให้สะท้อน MT/SI/LAOS ตาม `calc_type` จริง
5. เตรียม UAT scenarios สำหรับ 4 channels + mid-month events

---

## 8) ภาพรวมโปรเจกต์ที่ต้องคงไว้

- โครงการ: AJT New Sale Incentive System
- เป้าหมาย: ย้ายจาก Excel ไปสู่ระบบที่คุมได้, ตรวจสอบย้อนหลังได้, ลด manual
- Source of truth ด้านช่องทางขาย: `dbo.mst_channel`
- TT product_code มาตรฐาน: short alias (A/R/B/AP/Q/M/NS/P/Y/RK/T)
- หลักคำนวณรวม: achievement → GOAL → base × GOAL × weight

---

## 9) Metadata งานรอบนี้

- Agent: Copilot (GPT-5.3-Codex)
- Date: 2026-06-16
- Workspace: `28.AJT New Sale Incentive`
- ไฟล์หลักที่ส่งมอบรอบนี้: `final-docs/AJT_Project-Scope-Summary.md`
