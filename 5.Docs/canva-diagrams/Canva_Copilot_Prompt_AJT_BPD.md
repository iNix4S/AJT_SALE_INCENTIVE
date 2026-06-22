# Canva Copilot Prompt - AJT New Sale Incentive

วันที่: 2026-06-13
วัตถุประสงค์: ใช้ข้อความในไฟล์นี้วางใน Canva Copilot (ผ่าน Microsoft Teams) เพื่อให้ระบบสร้างไดอะแกรม/สไลด์ต่อได้อัตโนมัติ

---

## Prompt แบบละเอียด (Full Prompt)

ช่วยสร้างชุดไดอะแกรมและสไลด์พรีเซนเทชันภาษาไทยสำหรับโครงการ AJT New Sale Incentive โดยอ้างอิง Business Process Design เวอร์ชันล่าสุด และให้ผลลัพธ์เป็นงานที่พร้อมใช้งานจริงสำหรับประชุมกับ Business Owner, Sales Ops, HR, IT

เป้าหมายงาน
1. สร้างภาพสรุปกระบวนการ End-to-End ตั้งแต่ Start Monthly ถึง End
2. แสดงบทบาทและความรับผิดชอบแบบ Swimlane + RACI
3. แสดง Control Points, KPI/SLA และ Traceability ให้ครบ
4. โทนงานต้องเป็นมืออาชีพ อ่านง่าย ใช้ในองค์กรได้ทันที

รูปแบบงานที่ต้องสร้าง
1. Slide 1: End-to-End Business Process
- โฟลว์หลัก: Start Monthly -> M1 Set Period -> M2 Import BI Sales -> M3 Update ASTBase -> M4 Import HCM Data -> Validation Gate -> MT/TT Path -> GD -> Fixed Rate -> Generate For HR -> Approval -> Export to HR -> HR Payment -> Audit + Period Close -> End
- แสดง loop:
- Rejected จาก Approval ย้อนกลับไป Calculation
- Exception ย้อนกลับไป Validation
- As-needed Adjustments (N1-N5) เชื่อมไปขั้นคำนวณ/ผลลัพธ์

2. Slide 2: Swimlane + RACI
- Lanes: Sales Operations, System, Business Owner, HR, Data Team, HCM Owner
- ใส่ RACI ต่อ stage:
- START/Period: Sales Ops เป็น R/A
- INPUT BI/HCM: Data Team และ HCM Owner เป็น A ตามแหล่งข้อมูล
- VALIDATE: System เป็น R, Sales Ops เป็น A
- CALC MT/TT/GD/FIX: System เป็น R/A
- APPROVAL: Business Owner เป็น A
- EXPORT: System เป็น R, HR เป็น R ฝั่งรับ
- CLOSE/AUDIT: System เป็น R, Sales Ops เป็น A

3. Slide 3: Control Points + Exception Handling
- แสดง CP-1 ถึง CP-9 พร้อมความหมายสั้น:
- CP-1 Period alignment
- CP-2 Data completeness
- CP-3 Hierarchy consistency
- CP-4 Approval before export
- CP-5 Audit completeness
- CP-6 Interface completeness
- CP-7 Data reconciliation
- CP-8 Output integrity
- CP-9 Period close governance
- แสดง Error Codes:
- E-PERIOD-001, E-REQ-002, E-MAP-003, E-HIER-004, E-APP-005
- ใส่ action: Block -> Fix at source -> Re-validate

4. Slide 4: KPI/SLA Monitoring
- KPI:
- Validation Pass Rate >= 98%
- Accuracy เทียบ baseline >= 99.5%
- Rework หลัง Review <= 5%
- Export Timeliness ภายใน payroll cut-off
- Monthly Cycle Time <= 1 วันทำการหลังข้อมูลครบ
- แสดง mapping ว่า KPI ไหนวัดที่ stage ไหน

5. Slide 5: Traceability Matrix
- Mapping:
- Input/Validate -> FR-006 ถึง FR-009 -> CP-1,2,6
- MT Path -> FR-010 ถึง FR-014 -> CP-3,7
- TT Path -> FR-015 -> CP-7
- GD -> FR-023 ถึง FR-029 -> CP-7
- Output/Export -> FR-016,018,020 -> CP-8
- Approval -> FR-019,022 -> CP-4
- Audit/Close -> FR-021 -> CP-5,9

สไตล์ภาพที่ต้องการ
1. Professional corporate, clean, modern
2. ภาษาไทยเป็นหลัก และมีคำอังกฤษกำกับเฉพาะคำเทคนิค
3. สีแนะนำ:
- Start: เขียวอ่อน
- Process steps: ฟ้าอ่อน
- Validation/Output gate: เหลืองอ่อน
- Exception: แดงอ่อน
- Audit/Close: ชมพูอ่อน
4. ฟอนต์อ่านง่ายสำหรับภาษาไทย เช่น Sarabun หรือ Tahoma
5. ใช้ไอคอนเรียบง่ายสื่อความหมาย Input, Validation, Approval, Export, Audit

เงื่อนไขคุณภาพงาน
1. แต่ละสไลด์ต้องไม่แน่นเกินไป อ่านจบใน 30-60 วินาที
2. ข้อความในกล่องสั้น กระชับ ไม่เกิน 2-3 บรรทัด
3. ลูกศร flow ต้องชัดเจน ทิศทางเดียวกัน
4. มี legend สำหรับสีและสัญลักษณ์
5. พร้อมนำเสนอทันทีโดยไม่ต้องแก้โครง

ถ้าข้อมูลแน่นเกิน ให้แตกเป็น 6-7 สไลด์ โดยรักษาเนื้อหาครบทั้งหมดตามรายการด้านบน

---

## Prompt แบบสั้น (Quick Prompt)

สร้างสไลด์ภาษาไทยแบบมืออาชีพสำหรับ AJT New Sale Incentive จำนวน 5-7 หน้า ประกอบด้วย: (1) End-to-End Flow: Start -> M1..M8 -> End พร้อม loop Rejected/Exception/As-needed, (2) Swimlane + RACI สำหรับ Sales Ops/System/Business Owner/HR/Data Team/HCM Owner, (3) Control Points CP-1..CP-9 + Error Codes E-PERIOD-001,E-REQ-002,E-MAP-003,E-HIER-004,E-APP-005, (4) KPI/SLA: Validation>=98%, Accuracy>=99.5%, Rework<=5%, Export on payroll cut-off, Cycle time<=1 business day, (5) Traceability Flow->FR->CP โดยใช้ mapping: Input/Validate FR-006..009 CP-1,2,6; MT FR-010..014 CP-3,7; TT FR-015 CP-7; GD FR-023..029 CP-7; Output/Export FR-016,018,020 CP-8; Approval FR-019,022 CP-4; Audit/Close FR-021 CP-5,9. โทนสี corporate, อ่านง่าย, พร้อมนำเสนอทันที.

---

## วิธีใช้งาน

1. เปิด Canva Copilot ใน Microsoft Teams
2. คัดลอก Prompt แบบละเอียดหรือแบบสั้นจากไฟล์นี้
3. วางและสั่งให้ Copilot สร้างงาน
4. ตรวจคำสะกด/คำศัพท์เฉพาะองค์กรก่อนใช้งานจริง
