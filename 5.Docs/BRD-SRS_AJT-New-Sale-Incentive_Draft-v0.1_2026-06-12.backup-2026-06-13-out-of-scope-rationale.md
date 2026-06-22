# BRD + SRS (Draft) — AJT New Sale Incentive

เวอร์ชัน: Draft v0.2  
วันที่: 2026-06-13 (เพิ่ม Functional Area: Special Product Incentive — GD)  
สถานะ: สำหรับ Review ร่วม Business, HR, Sales Ops, IT

---

## 1. Objective

โครงการนี้มีเป้าหมายเพื่อออกแบบและพัฒนาระบบคำนวณ Sales Incentive ที่ย้ายจากการทำงานบน Excel ไปสู่ระบบที่ควบคุมได้ ตรวจสอบย้อนหลังได้ และลดความเสี่ยงจากงาน manual โดยครอบคลุม 2 ช่องทางขาย:

1. MT (Modern Trade): คิดตาม Product Group และมีโครงสร้างคำนวณแบบ Cascade 4 ระดับ
2. TT (Traditional Trade): คิดตาม SKU/Product และคำนวณรวมใน Target & Cal หลัก

ผลลัพธ์สุดท้ายของระบบต้องสามารถสร้างชุดข้อมูลพร้อมจ่ายให้ HR ได้ตรงตามรอบเวลา และมีหลักฐานการคำนวณที่ตรวจสอบได้

---

## 2. Scope (In / Out)

### 2.1 In-Scope

1. นำเข้าข้อมูลจาก BI/DWC (ยอดขายรายเดือน)
2. นำเข้าข้อมูลพนักงานจาก HCM (Personal Employment Main & Active)
3. จัดการข้อมูลโครงสร้างองค์กร (ASTBase)
4. จัดการพารามิเตอร์คำนวณ Incentive:
- Period
- M_Month
- Table
- T_SectAbove
- Shortage
- Fix Rate
5. คำนวณ Incentive สำหรับ MT และ TT ตามตรรกะที่ยืนยันแล้ว
6. รองรับการคำนวณแบบ Cascade (MT: Staff -> Sect -> Dept -> AD)
6.1 คำนวณ **Special Product Incentive (Growth Driver — GD)** แยกสำหรับสินค้า Aji Plus / RDQ (Rosdee Cube) / RDM (Rosdee Menu) / RDNS (Rosdee Noodle)
7. สร้างผลลัพธ์สำหรับ HR:
- Variable Incentive
- Fixed Incentive
8. รองรับการตรวจสอบย้อนหลัง (Audit Trail) ของการเปลี่ยนพารามิเตอร์
9. รายงานและไฟล์ส่งออกเพื่อใช้จ่ายเงิน
10. Develop by Nintex K2 Workflow and Smart form
11. Service API .Net Core 10
12. Overview Dashboard by Chart.Js
13. Print out Form by MS SQL SSRS
14. Interface BI/DWC


### 2.2 Out-of-Scope

1. การจ่ายเงินจริงผ่านระบบ Payroll/Banking โดยตรง
2. การปรับโครงสร้าง Job Function นอกเหนือข้อมูลที่รับมาจาก HCM
3. การ redesign กระบวนการ BI/HCM ต้นทาง
4. การออกแบบ Incentive Policy ใหม่ทั้งหมด

---

## 3. Business Drivers และ Success Criteria

### 3.1 Business Drivers

1. ลดความผิดพลาดจากการ copy สูตรและงาน manual หลายขั้น
2. ลดเวลา closing รอบ Incentive รายเดือน
3. เพิ่มความโปร่งใส ตรวจสอบได้ว่าใครได้เท่าไร และเพราะเหตุใด
4. รองรับความต่างของ MT และ TT อย่างเป็นระบบเดียวกัน

### 3.2 Success Criteria (วัดผลได้)

1. Accuracy:
- ผลคำนวณจากระบบใหม่ต้องตรงกับ baseline Excel อย่างน้อย 99.5% ในชุด UAT ที่ตกลงร่วมกัน

2. Timeliness:
- รอบคำนวณรายเดือนเสร็จภายใน SLA ที่กำหนดร่วม (ตัวอย่าง: ภายใน 1 วันทำการหลังข้อมูลครบ)

3. Data Integrity:
- ไม่พบกรณี period mismatch ระหว่าง Sales และ HR ในรอบที่อนุมัติจ่าย

4. Auditability:
- ทุกการปรับค่า As-needed parameter ต้องมีผู้แก้ไข เวลา และเหตุผล

---

## 4. Stakeholders และบทบาท

1. Business Owner (Sales/Commercial): อนุมัติ policy และผลคำนวณ
2. Sales Operations: ดูแลข้อมูล Target/Shortage/Fix Rate และรอบเดือน
3. HR/Compensation: รับผลลัพธ์เพื่อจ่าย Incentive
4. IT/SA/Dev: ออกแบบและพัฒนาระบบ
5. Data Team (BI/DWC): ดูแล feed ยอดขาย
6. HCM Owner: ดูแล feed ข้อมูลพนักงาน

---

## 5. As-Is / To-Be และ Gap Analysis

### 5.1 As-Is

1. ทำงานบน Excel หลายชีตและหลายไฟล์
2. อาศัยการ paste และ copy สูตรรายเดือน
3. มีความเสี่ยง human error สูง
4. Audit trail ไม่ครบทุกจุด

### 5.2 To-Be

1. ระบบรวมศูนย์สำหรับ import, calculate, approve, export
2. Validation ก่อนคำนวณและก่อนอนุมัติจ่าย
3. Rule engine สำหรับ MT/TT และ policy overrides
4. Audit log ครบทุก transaction สำคัญ

### 5.3 Gap สำคัญ

1. ยังไม่มี gate บังคับ period alignment แบบอัตโนมัติใน As-Is
2. การ map Product Code MT บางตัว (AJA, AMV, FP, QM) ยังไม่ยืนยัน
3. บาง policy ยังรอ Business confirmation (เช่น 108% -> 1.06)

---

## 6. Functional Requirements (SRS)

รหัส FR ต่อไปนี้เป็นข้อกำหนดเชิงฟังก์ชันหลัก

### 6.1 Master และ Parameter Management

FR-001: ระบบต้องรองรับการตั้งค่า Period ของรอบคำนวณรายเดือน  
FR-002: ระบบต้องรองรับการตั้งค่า M_Month เพื่อ map เดือนยอดขายไปเดือนจ่าย Incentive ของ Variable และ Fixed  
FR-003: ระบบต้องจัดการตาราง Incentive Table และ T_SectAbove ได้  
FR-004: ระบบต้องจัดการ Shortage ราย Product x Month ได้  
FR-005: ระบบต้องจัดการ Fix Rate รายพนักงานหรือราย Job Function ได้

### 6.2 Data Integration

FR-006: ระบบต้องนำเข้ายอดขายจาก BI/DWC ตามรูปแบบที่ตกลงร่วมกัน  
FR-007: ระบบต้องนำเข้าข้อมูลพนักงานจาก HCM ได้  
FR-008: ระบบต้องนำเข้าหรือดูแลข้อมูล ASTBase เพื่อ hierarchy mapping ได้  
FR-009: ระบบต้องทำ data validation ก่อนคำนวณ (required fields, key uniqueness, period consistency)

### 6.3 Calculation Engine

FR-010: ระบบต้องคำนวณ achievement ราย product ด้วยสูตร round 4 ตำแหน่ง  
FR-011: ระบบต้องรองรับ shortage override ให้ achievement = 1.0 ตามเงื่อนไข  
FR-012: ระบบต้อง lookup GOAL แบบ step-down ตาม threshold  
FR-013: ระบบต้องคำนวณ incentive รายสินค้าและรวมรายคนได้  
FR-014: ระบบต้องรองรับ Cascade MT:
- Staff -> Sect -> Dept -> AD โดย SUMIFS target+actual แล้วคำนวณใหม่ในแต่ละระดับ

FR-015: ระบบต้องรองรับ TT calculation ตามโครงสร้าง Target & Cal ของ TT  
FR-016: ระบบต้องสร้างผลลัพธ์ For HR สำหรับ Variable Incentive ได้  
FR-017: ระบบต้องสร้างผลลัพธ์ Fixed Incentive ได้ตาม policy  
FR-018: ระบบต้องคำนวณ final payable แบบ floor logic ตาม policy ที่กำหนด

### 6.4 Approval, Output, Audit

FR-019: ระบบต้องมีสถานะรอบงานอย่างน้อย Draft, Calculated, Reviewed, Approved, Exported  
FR-020: ระบบต้อง export ผลลัพธ์ในรูปแบบที่ HR ใช้งานได้  
FR-021: ระบบต้องบันทึก audit trail ของการแก้ไขพารามิเตอร์และการอนุมัติ  
FR-022: ระบบต้องแสดง trace รายการคำนวณเพื่ออธิบายผลลัพธ์รายพนักงานได้

### 6.5 Special Product Incentive (Growth Driver — GD)

> Functional area แยกสำหรับสินค้ากลุ่ม G2 (GD) ที่ถูกผลักดันยอดเป็นพิเศษ — Aji Plus, RDQ (Rosdee Cube), RDM (Rosdee Menu), RDNS (Rosdee Noodle) มีครบทั้ง MT และ TT
> หลักฐาน: [02.Sheet-Understanding/MT/11_Special-Product-Incentive](../4.System%20Analyst%20and%20Design/02.Sheet-Understanding/MT/11_Special-Product-Incentive_AjiPlus-RDQ-RDM-RDNS.md)

FR-023: ระบบต้องรองรับการตั้งค่า **Target รายเดือน (12 เดือน) ราย salesman ต่อสินค้า GD** แยกจาก Target หลัก  
FR-024: ระบบต้องนำเข้า **Actual รายเดือน ราย salesman ต่อสินค้า GD** จาก BI (ชุดข้อมูลแยกจาก Actual หลัก)  
FR-025: ระบบต้องคำนวณ achievement = ROUND(Actual ÷ Target, 4) ราย product GD ราย salesman ราย เดือน  
FR-026: ระบบต้อง lookup **payout เป็นจำนวนเงินคงที่ตามขั้น achievement** จากตาราง GD payout โดย **แต่ละสินค้าใช้คอลัมน์ payout ของตนเอง** (เช่น Aji Plus ฐาน 200, RDQ ฐาน 400) — ไม่ใช้ base × goal × weight แบบสูตรหลัก  
FR-027: ระบบต้องรวม payout รายเดือนเป็น **incentive รวมรายปี ราย salesman ต่อสินค้า GD** (Σ 12 เดือน)  
FR-028: ระบบต้องกำหนดได้ว่า GD incentive จะ **รวมเข้าผลลัพธ์ For HR (บวกเพิ่ม)** หรือ **ออกเป็นชุดจ่ายแยก** ตาม policy ที่ Business ยืนยัน (ดู OQ-7, OQ-9)  
FR-029: ระบบต้องป้องกัน **การคิดซ้ำซ้อน (double-count)** ระหว่าง GD scheme กับน้ำหนัก G2 ในสูตรหลัก ตามกฎที่ยืนยัน (ดู BR-009, OQ-8)

---

## 7. Non-Functional Requirements

NFR-001: Security
- กำหนดสิทธิ์การเข้าถึงตามบทบาท (RBAC)
- จำกัดสิทธิ์แก้ไขเฉพาะผู้มีอำนาจ

NFR-002: Performance
- รองรับการคำนวณรอบเดือนภายใน SLA ที่ตกลง

NFR-003: Reliability
- มีการจัดการความผิดพลาดจากไฟล์ข้อมูลและแจ้งเตือนที่เข้าใจง่าย

NFR-004: Auditability
- เก็บ log การแก้ไข/อนุมัติย้อนหลังได้อย่างน้อยตามนโยบายองค์กร

NFR-005: Maintainability
- แยก rule configuration ออกจากโค้ดหลักเพื่อปรับ policy ได้ง่าย

NFR-006: Data Quality
- ต้องมี pre-check สำคัญก่อนอนุมัติรอบ:
- period alignment
- required fields
- hierarchy consistency

---

## 8. Business Rules (ยืนยันแล้ว)

BR-001: Achievement = ROUND(actual/target, 4) ราย product  
BR-002: ถ้า Shortage flag ตรง product+month ให้ achievement = 1.0  
BR-003: GOAL lookup แบบ step-down ตาม threshold table  
BR-004: MT Cascade ใช้ SUMIFS Target+Actual แล้วคำนวณใหม่ทุกระดับ  
BR-005: Final payout ใน For HR ใช้หลัก max floor กับผลรวม incentive ตาม policy

**Special Product Incentive (GD) — ยืนยันจากสูตรจริง ✅**

BR-006: GD achievement = ROUND(Actual ÷ Target, 4) คิดราย product GD ราย salesman ราย เดือน  
BR-007: GD payout = VLOOKUP(achievement, ตาราง GD payout) คืน **จำนวนเงินตามขั้น** (step) โดยแต่ละสินค้าใช้คอลัมน์ payout เฉพาะของตน — ไม่มี weight และไม่มี incentive base ตามตำแหน่ง  
BR-008: GD incentive รวมรายปี = SUM(payout 12 เดือน) ต่อ salesman ต่อสินค้า  

**Special Product Incentive (GD) — ยังรอยืนยันจาก Business ❓**

BR-009: ความสัมพันธ์ระหว่าง GD scheme กับน้ำหนัก G2 ในสูตรหลัก — เป็น **incentive เพิ่มเติม (additive)** หรือ **แทนที่ (replace)** เพื่อกันการจ่ายซ้ำซ้อน (ดู OQ-8)

หมายเหตุ: บาง rule ยังรอยืนยันเพิ่มเติมในส่วน Open Questions

---

## 9. Data Requirements

### 9.1 Core Data Entities

1. Period
2. Employee (จาก HCM)
3. Organization Hierarchy (ASTBase)
4. Sales Actual (BI/DWC)
5. Target
6. Product Mapping (MT/TT)
7. Incentive Parameter (Table, T_SectAbove, Shortage, Fix Rate)
8. Calculation Result
9. HR Output
10. **GD Product Target** — Target รายเดือน (12 เดือน) ราย salesman ต่อสินค้า GD (Aji Plus/RDQ/RDM/RDNS)
11. **GD Product Actual** — Actual รายเดือน ราย salesman ต่อสินค้า GD (จาก BI, ชุดแยก)
12. **GD Payout Table** — ตารางขั้น achievement → จำนวนเงิน payout โดยแยกคอลัมน์ราย product GD
13. **GD Calculation Result** — achievement / payout รายเดือน + ยอดรวมรายปี ราย salesman ต่อสินค้า GD

### 9.2 Key Data Rules

1. Employee ID ต้อง unique และสัมพันธ์กับ hierarchy
2. Product code ต้อง map ได้ตาม channel
3. รอบเวลาของ Sales และ Employee ต้องตรงกับ Period
4. Target/Actual ต้องอยู่ในเดือนที่รองรับ
5. GD Product Target/Actual ต้องผูกกับ Salesman Code และ Period เดียวกับสูตรหลัก
6. สินค้า GD แต่ละตัวต้องชี้ไปคอลัมน์ payout ที่ถูกต้องใน GD Payout Table (mapping product → column)

---

## 10. Integration Requirements

IR-001: BI/DWC -> Incentive System
- ข้อมูลยอดขายรายเดือนระดับที่ต้องใช้คำนวณ

IR-002: HCM -> Incentive System
- ข้อมูลพนักงาน active และโครงสร้างที่เกี่ยวข้อง

IR-003: Incentive System -> HR Process
- Export ไฟล์ผลลัพธ์รอบจ่าย (Variable/Fixed)

---

## 11. User Stories และ Acceptance Criteria

US-001: ตั้งค่ารอบเดือน
- ในฐานะ Sales Ops ต้องการตั้ง Period เพื่อเริ่มรอบคำนวณเดือนใหม่
- AC-001.1: บันทึก Period ได้
- AC-001.2: ระบบป้องกันการคำนวณหากยังไม่ตั้ง Period

US-002: นำเข้าข้อมูลยอดขายและพนักงาน
- ในฐานะผู้ปฏิบัติการ ต้องการ import BI/HCM เพื่อเตรียมคำนวณ
- AC-002.1: ระบบแจ้งจำนวนแถวรับเข้าและรายการผิดรูปแบบ
- AC-002.2: ไม่อนุญาตให้ผ่านหาก period mismatch

US-003: คำนวณ Incentive MT/TT
- ในฐานะผู้ปฏิบัติการ ต้องการรันคำนวณตาม policy ล่าสุด
- AC-003.1: ระบบคำนวณ achievement, goal, incentive ได้ครบ
- AC-003.2: MT รองรับ cascade 4 ระดับครบ

US-004: ตรวจสอบและอนุมัติผล
- ในฐานะ Business Owner ต้องการตรวจสอบก่อนอนุมัติจ่าย
- AC-004.1: ดูรายละเอียด trace รายพนักงานได้
- AC-004.2: มีการเก็บผู้อนุมัติและเวลาอนุมัติ

US-005: ส่งออกให้ HR
- ในฐานะ HR ต้องการไฟล์ผลลัพธ์ที่พร้อมจ่าย
- AC-005.1: Export ได้ตาม template ที่กำหนด
- AC-005.2: มี checksum/summary ยืนยันความครบถ้วน

---

## 12. Backlog และ Priorities

### Priority P1 (ต้องมี)

1. Data import + validation (BI/HCM/AST)
2. Calculation engine MT/TT
3. For HR output + export
4. Approval workflow + audit trail

### Priority P2 (ควรมี)

1. Parameter change log ที่ละเอียดขึ้น
2. Reconciliation report เทียบรอบก่อนหน้า
3. Dashboard สรุปผลคำนวณรายรอบ

### Priority P3 (เพิ่มคุณค่า)

1. Scenario simulation สำหรับ policy ใหม่
2. แจ้งเตือนอัตโนมัติเมื่อพบความผิดปกติของข้อมูล

---

## 13. Risks and Dependencies

### 13.1 Risks

R-001: Policy ambiguity
- Trigger: ยังไม่ยืนยัน rule บางข้อ
- Impact: สูตรคลาดเคลื่อน
- Mitigation: ทำ Requirement Sign-off ต่อ rule
- Owner: Business Owner

R-002: Data quality issue
- Trigger: BI/HCM ส่งข้อมูลไม่ครบหรือไม่ตรงเดือน
- Impact: คำนวณผิด/รอบจ่ายล่าช้า
- Mitigation: บังคับ pre-validation และ reject พร้อม error report
- Owner: Data Team + Sales Ops

R-003: Mapping uncertainty (MT codes)
- Trigger: ยังไม่ยืนยัน AJA/AMV/FP/QM
- Impact: Incentive product mapping ผิด
- Mitigation: ยืนยัน mapping master ก่อน UAT
- Owner: Business + SA

R-004: Manual override without governance
- Trigger: ปรับ As-needed โดยไม่มี audit
- Impact: ตรวจสอบย้อนหลังไม่ได้
- Mitigation: RBAC + mandatory reason + approval log
- Owner: IT + Process Owner

### 13.2 Dependencies

1. ความพร้อมของ feed BI/DWC
2. ความพร้อมของ feed HCM
3. การยืนยัน policy จาก Business
4. ความพร้อม template ส่งออกฝั่ง HR

---

## 14. Delivery Plan (High-Level)

Milestone 1: Requirement Baseline และ Sign-off
- ผลลัพธ์: BRD/SRS baseline + open items list

Milestone 2: Solution Design
- ผลลัพธ์: Data model, integration spec, rule spec

Milestone 3: Build และ SIT
- ผลลัพธ์: ระบบคำนวณครบ MT/TT + validation + export

Milestone 4: UAT
- ผลลัพธ์: UAT sign-off เทียบ baseline Excel

Milestone 5: Go-Live และ Hypercare
- ผลลัพธ์: เริ่มใช้งานจริง + แผนรองรับปัญหาหลังขึ้นระบบ

---

## 15. Assumptions

1. BI/DWC และ HCM สามารถส่งข้อมูลตามรอบได้สม่ำเสมอ
2. โครงสร้าง Employee ID เป็น key หลักร่วมกันได้
3. HR ยอมรับรูปแบบไฟล์ output ที่กำหนดร่วมกัน
4. Policy หลักที่ยืนยันแล้วจะไม่เปลี่ยนระหว่างรอบพัฒนาแรก

---

## 16. Open Questions (ต้องยืนยันก่อน Sign-off)

1. เหตุผลเชิง policy ของจุด 108% -> 1.06 (ไม่ใช่ 1.08)
2. เงื่อนไขใช้งาน EXTRA, Special KPI, Option1
3. เงื่อนไขการเลือก Incentive Base แบบ Old vs New
4. Mapping ของรหัส MT เพิ่มเติม: AJA, AMV, FP, QM
5. บทบาทของ Sales Target sheet ใน flow หลัก
6. Scope และ policy ของ Laos Dept ใน TT For HR (AD)

**Special Product Incentive (GD)** — อ้างอิง [11_Special-Product-Incentive](../4.System%20Analyst%20and%20Design/02.Sheet-Understanding/MT/11_Special-Product-Incentive_AjiPlus-RDQ-RDM-RDNS.md)

7. **(OQ-7 / SP-1)** GD incentive ถูกนำไปจ่ายอย่างไร — รวมเข้า For HR (บวกเพิ่ม) หรือจ่ายแยกคนละก้อน
8. **(OQ-8 / SP-3)** สินค้า GD ถูกคิด incentive ซ้ำซ้อนหรือไม่ (มีน้ำหนัก G2 ในสูตรหลัก + scheme แยกนี้) → additive หรือ replace
9. **(OQ-9 / SP-2)** เหตุใดในไฟล์ทดสอบ GD ยังไม่ wire เข้า For HR — scheme ใหม่ที่ยัง prototype หรือ workbook ไม่สมบูรณ์
10. **(SP-4)** GD Target รายเดือนมาจากแหล่งใด ใครอนุมัติ
11. **(SP-5)** ค่าฐาน payout ของ RDM, RDNS และฝั่ง TT ที่เหลือ (ต้องสกัดเพิ่มจาก raw extracts)
12. **(SP-6)** รอบ GD scheme เป็นครึ่งปีหรือเต็มปี (Actual ทดสอบมีแค่ Apr–Sep / 6 เดือน)

---

## 17. Definition of Done (เอกสารฉบับนี้)

เอกสาร BRD+SRS ฉบับนี้ถือว่าเป็น baseline พร้อมรีวิว เมื่อ:

1. Stakeholders หลัก review ครบ
2. FR/NFR/BR/IR มี owner ชัดเจน
3. Open Questions ถูก assigned ผู้รับผิดชอบและ due date
4. ได้รับ sign-off เพื่อเข้าสู่ Solution Design ต่อไป

## 18.Project Estimate Manday(s) by Roles
	1. Project Manager (1)
    2. Business Analyst (1)
    3. System Analyst (1)
    4. Developer K2 (2)
    5. Developer Service API (1)
    6. QA Tester and Documenter (1)

