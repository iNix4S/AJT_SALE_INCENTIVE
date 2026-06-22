# AJT Business Flow vs System Flow Comparison

วันที่: 2026-06-14  
เวอร์ชัน: v1.0  
วัตถุประสงค์: ตารางเปรียบเทียบแบบ 1 หน้า สำหรับใช้ review หรือ present ความต่างระหว่าง Business Flow และ System Flow

---

## ตารางเปรียบเทียบ

| หัวข้อ | Business Flow | System Flow |
|---|---|---|
| มุมมองหลัก | มองจากกระบวนการทำงานของคนและบทบาท | มองจากลำดับการทำงานของระบบและ logic ภายใน |
| คำถามที่ตอบ | ใครทำอะไร เมื่อไร ส่งต่อให้ใคร | ระบบรับอะไร ตรวจอะไร คำนวณอย่างไร ส่งอะไรออก |
| จุดเริ่ม | การตั้ง Period และเตรียมข้อมูลของรอบเดือน | การรับ Input Data จาก BI และ HCM |
| เจ้าของ flow | Sales Ops, Business Owner, HR | System, Calculation Engine, Workflow, Export |
| โฟกัสหลัก | Operational process และ governance | Validation, calculation logic, channel branching, output generation |
| Input สำคัญ | Period, Actual, ASTBase, HR Rep, As-needed parameter | BI Sales, HCM Employee, Mapping, Target, Hierarchy, Parameter |
| Validation | เน้น control point เชิงธุรกิจ เช่น period alignment, completeness, approval | เน้น validation gate และ error flow ก่อนคำนวณ |
| MT | มองเป็นขั้นตอนในกระบวนการ monthly operation | มองเป็น path ที่มี Mapping + Cascade 4 ระดับ |
| TT | มองเป็นอีกช่องทางหนึ่งใน process เดียวกัน | มองเป็น path ที่คำนวณแบบ single-sheet แต่มี 5-level hierarchy |
| GD Special Incentive | เป็นกิจกรรมเสริมที่ต้องรวมในกระบวนการ | เป็น flow แยกของ calculation logic และ payout table |
| Fixed Rate | เป็น parameter/องค์ประกอบการจ่ายคงที่ | เป็น sub-flow ที่ lookup rate และ payment month |
| Output | For HR Variable / Fixed พร้อมให้ HR ใช้จ่าย | Generate Output -> Approval -> Export |
| Approval | Business Owner ต้อง review และ approve ก่อนส่ง HR | เป็น workflow state ก่อน export |
| Audit | ใช้ยืนยันว่ากระบวนการปิดรอบครบถ้วน | เป็น system state + log หลัง export |
| สิ้นสุด | HR รับผลไปจ่าย และปิดรอบ | Exported -> Audit Trail -> Period Close |
| เอกสารอ้างอิงหลัก | Business-Process-Design, Sales Incentive Guide | System-Flow-Design, Calculation Logic |
| เหมาะกับผู้อ่าน | Business, Sales Ops, HR, Process Owner | SA, Dev, QA, Architect |

---

## สรุปสั้น

1. `Business Flow` อธิบาย “งานเดินอย่างไร”
2. `System Flow` อธิบาย “ระบบทำงานอย่างไร”
3. ทั้งสองเอกสารต้องใช้คู่กัน:
- Business Flow ใช้คุมกระบวนการและบทบาท
- System Flow ใช้คุม logic, validation และ implementation

---

## ตัวอย่างการใช้งานเอกสารนี้

### ใช้ใน review meeting

1. เปิดดูแถว `MT` และ `TT` เพื่อทำความเข้าใจความต่างของ logic
2. เปิดดูแถว `Validation`, `Approval`, `Audit` เพื่อคุยเรื่อง control point
3. เปิดดูแถว `Output` เพื่อยืนยันสิ่งที่ HR จะได้รับ

### ใช้ในงาน present

1. เริ่มจาก `สรุปสั้น`
2. ใช้ตารางเปรียบเทียบเป็นภาพรวมหน้าเดียว
3. ถ้าต้องลงลึก ให้เปิดเอกสาร Business Flow หรือ System Flow ต่อ