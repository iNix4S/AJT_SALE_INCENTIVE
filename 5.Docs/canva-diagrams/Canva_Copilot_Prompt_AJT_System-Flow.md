# Canva Copilot Prompt - System Flow Design (AJT New Sale Incentive)

วันที่: 2026-06-13
วัตถุประสงค์: วางข้อความในไฟล์นี้ใน Canva Copilot (ผ่าน Microsoft Teams) เพื่อให้สร้างไดอะแกรม/สไลด์ System Flow ต่ออัตโนมัติ
อ้างอิง: System-Flow-Design_AJT-New-Sale-Incentive_v1.0_2026-06-13.md

---

## Prompt แบบละเอียด (Full Prompt)

ช่วยสร้างชุดสไลด์ภาษาไทยแบบมืออาชีพสำหรับ System Flow ของโครงการ AJT New Sale Incentive เพื่อใช้นำเสนอกับทีม IT, Business Owner, Sales Ops และ HR โดยให้ผลลัพธ์พร้อมใช้งานจริง

เป้าหมายงาน
1. แสดง System Flow ตั้งแต่รับข้อมูลเข้าจนส่งออกให้ HR
2. แยกเส้นทาง MT และ TT ชัดเจน รวม GD และ Fixed Rate
3. แสดง mapping กับ Control, RACI, KPI/SLA และ Traceability
4. โทนงาน corporate, clean, modern

รูปแบบงานที่ต้องสร้าง
1. Slide 1: End-to-End System Flow
- Start (Monthly) -> Input Data (BI Sales + HCM Employee) -> Validation Gate (Period/Fields/Hierarchy)
- ถ้า Failed -> Error Notification -> Fix & Retry -> วนกลับ Validation
- ถ้า Passed -> Channel? -> MT Path (Mapping + Cascade) หรือ TT Path (Single-Sheet)
- ทั้งสองเส้นทาง -> GD Special Incentive -> Fixed Rate -> Generate Output (For HR Variable + Fixed)
- -> Approval Workflow -> ถ้า Approved -> Export to HR (SSRS) -> HR Payment -> Audit Trail + Period Close -> End
- ถ้า Rejected -> วนกลับขั้นคำนวณ

2. Slide 2: MT Channel Flow (4-Level Cascade)
- MT Input (BI SalesCode + ProductGroup) -> Mapping (BI SalesCode -> Salesman)
- Calculation Staff Level: achievement = ROUND(Actual/Target,4), Shortage override -> 1.0, GOAL = XLOOKUP, incentive = base x GOAL x weight
- Cascade: Section -> Department -> AD (แต่ละระดับ SUMIFS Target+Actual แล้วคำนวณใหม่)
- รวม: For HR = MAX(floor, Σ Staff+Sect+Dept+AD)

3. Slide 3: TT Channel Flow (Single-Sheet)
- TT Input (Salesman Code + SKU) -> Calculation All Levels ใน sheet เดียว
- achievement = ROUND(Actual/Target,4) per SKU, Shortage override -> 1.0, GOAL = XLOOKUP, incentive = base x GOAL x weight
- Output: For HR (Variable) + For HR (AD)

4. Slide 4: GD Special Incentive + Fixed Rate
- GD: Input Target+Actual ราย salesman ต่อสินค้า GD -> achievement ROUND 4 -> payout = VLOOKUP(achievement, GD payout table แยกคอลัมน์ต่อสินค้า) -> รวมรายปี = SUM payout 12 เดือน
- สินค้า GD: Aji Plus, RDQ (Rosdee Cube), RDM (Rosdee Menu), RDNS (Rosdee Noodle)
- Posting Route ยังรอยืนยัน: Additive (บวกเข้า For HR) หรือ Separate (แยกชุดจ่าย)
- Fixed Rate: Lookup ตาม Job Function/พนักงาน -> กำหนดเดือนจ่ายจาก M_Month -> For HR (Fixed)

5. Slide 5: Control + RACI + KPI Mapping
- Control: INPUT/VALIDATE CP-1,2,6; MT Path CP-3,7; TT/GD CP-7; APPROVAL CP-4; OUTPUT/EXPORT CP-8; AUDIT/CLOSE CP-5,9
- RACI ตาม stage: Period (Sales Ops R/A), Input (Data Team/HCM Owner A), Validate (System R, Sales Ops A), Calc (System R/A), Approval (Business Owner A), Export (System R, HR R), Close (System R, Sales Ops A)
- KPI/SLA: Validation Pass Rate >=98%, Accuracy >=99.5%, Rework <=5%, Export ภายใน payroll cut-off, Cycle Time <=1 วันทำการ

6. Slide 6: Traceability (Flow -> FR -> Control)
- Input/Validate -> FR-006..009 -> CP-1,2,6
- MT Path -> FR-010..014 -> CP-3,7
- TT Path -> FR-015 -> CP-7
- GD -> FR-023..029 -> CP-7
- Fixed/Output -> FR-016,017,018 -> CP-8
- Approval -> FR-019,022 -> CP-4
- Export -> FR-020 -> CP-8
- Audit/Close -> FR-021 -> CP-5,9

สไตล์ภาพที่ต้องการ
1. Professional corporate, clean, modern
2. ภาษาไทยเป็นหลัก มีคำอังกฤษกำกับเฉพาะคำเทคนิค
3. สีแนะนำ: Start เขียวอ่อน, Validation เหลืองอ่อน, MT ฟ้า, TT ม่วงอ่อน, GD ส้มอ่อน, Error แดงอ่อน, Payment ฟ้าอมเขียว
4. ฟอนต์อ่านง่ายภาษาไทย เช่น Sarabun หรือ Tahoma
5. ใช้ไอคอนสื่อความหมาย Input, Validation, Calculation, Approval, Export, Audit

เงื่อนไขคุณภาพงาน
1. แต่ละสไลด์ไม่แน่นเกินไป อ่านจบใน 30-60 วินาที
2. กล่องข้อความสั้น กระชับ 2-3 บรรทัด
3. ลูกศร flow ชัดเจน ทิศทางเดียวกัน
4. มี legend สำหรับสีและสัญลักษณ์
5. พร้อมนำเสนอทันทีโดยไม่ต้องแก้โครง

---

## Prompt แบบสั้น (Quick Prompt)

สร้างสไลด์ภาษาไทยมืออาชีพ 5-6 หน้าสำหรับ System Flow ของ AJT New Sale Incentive ประกอบด้วย (1) End-to-End Flow: Start -> Input BI/HCM -> Validation -> Channel MT/TT -> GD -> Fixed -> For HR -> Approval -> Export -> Payment -> Audit/Close -> End พร้อม loop Error และ Rejected, (2) MT Flow: Mapping -> Staff Calc (achievement=ROUND(Actual/Target,4), GOAL=XLOOKUP, base x GOAL x weight) -> Cascade Sect/Dept/AD -> For HR=MAX(floor, Σ ทุกระดับ), (3) TT Flow: Single-sheet per SKU, (4) GD: payout=VLOOKUP step ต่อสินค้า (Aji Plus/RDQ/RDM/RDNS) + Fixed Rate ตาม Job Function ผ่าน M_Month, (5) Mapping Control CP-1..CP-9 + RACI + KPI (Validation>=98%, Accuracy>=99.5%, Rework<=5%), (6) Traceability Flow->FR->CP. โทน corporate, แยกสีเส้นทาง MT/TT/GD, พร้อมนำเสนอ.

---

## วิธีใช้งาน

1. เปิด Canva Copilot ใน Microsoft Teams
2. คัดลอก Prompt แบบละเอียดหรือแบบสั้นจากไฟล์นี้
3. วางและสั่งให้ Copilot สร้างงาน
4. ตรวจคำศัพท์เฉพาะองค์กรก่อนใช้งานจริง
