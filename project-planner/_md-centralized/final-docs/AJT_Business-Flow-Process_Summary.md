# AJT Business Flow Process Summary

วันที่: 2026-06-14  
เวอร์ชัน: v1.0  
ขอบเขต: สรุป Business Flow Process สำหรับ AJT New Sale Incentive โดยอ้างอิงเอกสาร BRD/SRS, Business Process Design และ Sales Incentive Guide

---

## 1. วัตถุประสงค์

เอกสารนี้สรุปภาพรวม Business Flow Process ของระบบ AJT New Sale Incentive ในภาษาที่อ่านง่าย เพื่อใช้เป็นเอกสารอ้างอิงกลางสำหรับ Business, Sales Operations, HR และทีมพัฒนา โดยอธิบายตั้งแต่การเตรียมข้อมูล การคำนวณ การอนุมัติ จนถึงการส่งออกผลลัพธ์ให้ HR

---

## 2. ภาพรวมกระบวนการ

Business Flow ของระบบนี้มี 3 จังหวะหลัก:

1. รอบประจำปี (Annually)
- ตั้งค่า `M_Month` เพื่อกำหนดความสัมพันธ์ระหว่างเดือนยอดขายกับเดือนจ่าย Incentive ของ Variable และ Fixed

2. รอบประจำเดือน (Monthly)
- ตั้ง `Period`
- นำเข้ายอดขายจาก BI/DWC
- อัปเดตโครงสร้างองค์กรจาก `ASTBase`
- อัปเดตข้อมูลพนักงานจาก `HR Rep`
- คำนวณ Incentive
- สร้างผลลัพธ์ `For HR`
- อนุมัติและส่งออกให้ HR

3. ปรับเมื่อจำเป็น (As-needed)
- ปรับ `T_SectAbove`
- ปรับ `Table`
- ปรับ `Target & Cal`
- ปรับ `Shortage`
- ปรับ `Fix Rate`

---

## 3. End-to-End Business Flow

### 3.1 เริ่มต้นรอบเดือน

1. Sales Operations ตั้ง `Period` ของเดือนที่ต้องการคำนวณ
2. ระบบใช้ `Period` เป็นจุดอ้างอิงสำหรับข้อมูลขาย ข้อมูลพนักงาน และเดือนจ่าย Incentive

### 3.2 นำเข้าข้อมูลต้นทาง

1. นำเข้ายอดขายจริงจาก BI/DWC ลง `Actual`
2. อัปเดตโครงสร้างสายบังคับบัญชาจาก `ASTBase`
3. นำเข้าข้อมูลพนักงาน active จาก HCM ลง `HR Rep`

### 3.3 Validation Gate

ก่อนเริ่มคำนวณ ระบบต้องตรวจสอบ:

1. `Period alignment`
- ยอดขายและข้อมูลพนักงานต้องเป็นเดือนเดียวกับรอบคำนวณ

2. `Data completeness`
- required fields ต้องครบ

3. `Hierarchy consistency`
- Salesman ต้องผูกกับสายบังคับบัญชาได้ครบ

4. `Mapping completeness`
- โดยเฉพาะ MT ต้อง map จาก BI SalesCode ไปเป็น Salesman ได้ครบ

ถ้าไม่ผ่าน ระบบต้องบล็อกและให้แก้ข้อมูลต้นทางก่อนคำนวณใหม่

### 3.4 แยกเส้นทางคำนวณตามช่องทาง

#### MT (Modern Trade)

1. ใช้ข้อมูลยอดขายในระดับ `Product Group`
2. ต้องทำ `Mapping` จาก BI SalesCode ไปเป็น Salesman Code ก่อน
3. คำนวณระดับ `Staff`
4. Cascade ขึ้น `Section -> Department -> AD`
5. วิธีหลักคือรวม Target+Actual แบบ `SUMIFS` แล้วคำนวณ achievement และ incentive ใหม่ทุกระดับ

#### TT (Traditional Trade)

1. ใช้ข้อมูลยอดขายในระดับ `SKU/Product`
2. ไม่ต้องทำ mapping แบบ MT เพราะใช้ Salesman Code ตรง
3. อยู่ในรูปแบบ single-sheet ในเชิง worksheet
4. แต่ผลคำนวณจริงมี hierarchy ครบ 5 ระดับ:
- `STAFF -> SECT_MGR -> DEPT_MGR -> DIV_MGR -> AD`
5. วิธีหลักคือใช้ `AVERAGEIFS` ดึงผลจากระดับล่างขึ้นระดับบน

### 3.5 คำนวณองค์ประกอบเสริม

1. `GD Special Incentive`
- ใช้กับสินค้า Growth Driver เช่น Aji Plus, RDQ, RDM, RDNS
- คิดแยกจากสูตรหลักตาม payout table ของแต่ละสินค้า

2. `Fixed Rate`
- ใช้อัตราคงที่ตาม Job Function หรือ policy ที่กำหนด
- เดือนจ่าย Fixed อ้างอิงจาก `M_Month`

### 3.6 สร้างผลลัพธ์สำหรับ HR

ระบบสร้างผลลัพธ์ 2 ชุดหลัก:

1. `For HR Variable`
- สรุป Variable Incentive รายคน

2. `For HR Fixed`
- สรุป Fixed Incentive รายคน

ผลลัพธ์ต้องพร้อมสำหรับการ review, approval และ export

### 3.7 Review, Approval, Export

1. Business Owner ตรวจ trace รายคน
2. ถ้าผลถูกต้อง ให้อนุมัติรอบงาน
3. เมื่ออนุมัติแล้ว ระบบจึง export ผลลัพธ์ให้ HR ผ่านรูปแบบที่กำหนด เช่น SSRS

### 3.8 HR Payment และปิดรอบ

1. HR รับผลลัพธ์ที่อนุมัติแล้วไปดำเนินการจ่าย
2. ระบบบันทึก Audit Trail
3. ปิดรอบเมื่อส่งออกสำเร็จและข้อมูล audit ครบ

---

## 4. บทบาทของผู้เกี่ยวข้อง

| บทบาท | หน้าที่หลัก |
|---|---|
| Sales Operations | ตั้ง Period, นำเข้าข้อมูล, อัปเดต ASTBase/HR Rep, ปรับ As-needed parameter |
| Business Owner | ตรวจสอบ trace และอนุมัติผลคำนวณ |
| HR / Compensation | รับผลลัพธ์และดำเนินการจ่าย |
| Data Team | จัดเตรียมข้อมูลยอดขายจาก BI/DWC |
| HCM Owner | จัดเตรียมข้อมูลพนักงานจาก HCM |
| System | Validation, Calculation, Output generation, Audit |

---

## 5. Control Points ที่สำคัญ

| รหัส | จุดควบคุม | ความหมาย |
|---|---|---|
| CP-1 | Period alignment | Sales และ HR ต้องตรงกับเดือนของ Period |
| CP-2 | Data completeness | required fields ต้องครบ |
| CP-3 | Hierarchy consistency | โครงสร้างสายบังคับบัญชาต้องครบ |
| CP-4 | Approval before export | ต้องอนุมัติก่อนส่งออกให้ HR |
| CP-5 | Audit completeness | ทุกการแก้ parameter ต้องมีเหตุผลและร่องรอย |
| CP-6 | Interface completeness | Import BI/HCM ต้องมี batch summary ครบ |
| CP-7 | Data reconciliation | ยอดขายหลัง mapping ต้อง reconcile กับต้นทาง |
| CP-8 | Output integrity | จำนวนพนักงานและยอดรวมใน output ต้องถูกต้อง |
| CP-9 | Period close governance | ปิดรอบได้เมื่อ export และ audit ครบ |

---

## 6. Input และ Output หลัก

### Input

1. BI/DWC Sales Feed
2. HCM Employee Feed
3. ASTBase / Hierarchy
4. Period / M_Month
5. Parameter sheets เช่น Table, T_SectAbove, Shortage, Fix Rate

### Output

1. For HR Variable
2. For HR Fixed
3. SSRS Export
4. Audit Log / Approval Log

---

## 7. ความต่างหลักระหว่าง MT และ TT

| หัวข้อ | MT | TT |
|---|---|---|
| หน่วยคำนวณ | Product Group | SKU / Product |
| Mapping | ต้องมี BI SalesCode -> Salesman | ไม่ต้องมีแบบ MT |
| วิธี cascade | SUMIFS Target+Actual แล้วคำนวณใหม่ | AVERAGEIFS จากระดับล่างขึ้นระดับบน |
| จำนวน hierarchy | 4 ระดับ | 5 ระดับ |
| ลักษณะ worksheet | แยกหลาย sheet ตามระดับ | single-sheet ในเชิง worksheet |
| Output Variable | Staff/Sect/Dept/AD | Staff/Sect/Dept/Div/AD |

---

## 8. สรุปสั้นที่สุด

Business Flow Process ของ AJT New Sale Incentive คือ:

`ตั้งงวด -> นำเข้าข้อมูล -> ตรวจความถูกต้อง -> คำนวณตามช่องทาง MT/TT -> รวมผล Variable/Fixed -> อนุมัติ -> ส่ง HR -> ปิดรอบพร้อม Audit`

ดังนั้นระบบนี้ไม่ได้มีหน้าที่แค่คำนวณ Incentive แต่เป็นกระบวนการควบคุมข้อมูล การอนุมัติ และการสร้างผลลัพธ์ที่พร้อมจ่ายจริงอย่างตรวจสอบย้อนหลังได้

---

## 9. เอกสารอ้างอิง

1. `BRD-SRS_AJT-New-Sale-Incentive_Draft-v0.1_2026-06-12.md`
2. `Business-Process-Design_AJT-New-Sale-Incentive_v1.0_2026-06-13.md`
3. `Sales Incentive System for POC.md`
4. `System-Flow-Design_AJT-New-Sale-Incentive_v1.0_2026-06-13.md`
5. `4.System Analyst and Design/06_Sales-Incentive-Guide-Explanation.md`# AJT New Sale Incentive — Business Flow Process Summary

**วันที่:** 2026-06-14
**เวอร์ชัน:** v1.0
**สถานะ:** Complete (Baseline Summary)
**จัดทำโดย:** สรุปรวมจาก BRD/SRS, Business Process Design, System Flow Design และ Sales Incentive Guide

---

## บทนำ

เอกสารนี้สรุป **Business Flow Process** ของโครงการ **AJT (Ajinomoto Thailand) New Sale Incentive** แบบอ่านง่าย เพื่อให้ Business, SA (System Analyst / นักวิเคราะห์ระบบ), Developer และ HR เห็นภาพตรงกันว่า ตั้งแต่เริ่มรอบเดือนจนถึงส่งข้อมูลให้ HR มีขั้นตอนอะไร ใครรับผิดชอบ และจุดควบคุมสำคัญอยู่ตรงไหน

---

## 1. วัตถุประสงค์ของ Business Flow

Business Flow นี้มีเป้าหมายเพื่อเปลี่ยนงานคำนวณ Incentive ที่เดิมทำบน Excel ให้เป็นกระบวนการที่:

1. ควบคุมได้
2. ตรวจสอบย้อนหลังได้
3. ลดความผิดพลาดจากงาน manual
4. รองรับทั้ง MT (Modern Trade) และ TT (Traditional Trade)
5. สร้างผลลัพธ์พร้อมส่งให้ HR ตามรอบจ่ายได้ถูกต้อง

---

## 2. ภาพรวมรอบการทำงาน

กระบวนการทำงานแบ่งเป็น 3 กลุ่มใหญ่

| รอบการทำงาน | คำอธิบาย | ตัวอย่างงาน |
|---|---|---|
| ประจำปี (Annually) | ตั้งค่าที่ใช้ทั้งปี | ตั้ง M_Month สำหรับ mapping เดือนขายกับเดือนจ่าย |
| ประจำเดือน (Monthly) | ทำซ้ำทุกเดือน | ตั้ง Period, นำเข้า Actual, อัปเดต ASTBase, อัปเดต HR Rep, คำนวณ, อนุมัติ, ส่ง HR |
| ปรับเมื่อจำเป็น (As-needed) | ปรับค่าพารามิเตอร์ตามสถานการณ์ | ปรับ T_SectAbove, Table, Target, Shortage, Fix Rate |

---

## 3. Business Flow End-to-End

ลำดับธุรกิจหลักของระบบมีดังนี้

1. ตั้งค่า **Period** ของเดือนที่ต้องการคำนวณ
2. นำเข้ายอดขายจริง (**Actual**) จาก BI / DWC (Data Warehouse Cloud)
3. อัปเดต **ASTBase** เพื่อให้โครงสร้างสายบังคับบัญชาเป็นปัจจุบัน
4. นำเข้าข้อมูลพนักงานจาก **HCM** (Human Capital Management) ลงใน **HR Rep**
5. ตรวจข้อมูลทั้งหมดผ่าน **Validation Gate**
6. แยกการคำนวณตามช่องทางขาย **MT** หรือ **TT**
7. คำนวณส่วนเสริม เช่น **GD (Growth Driver)** และ **Fix Rate**
8. สร้างผลลัพธ์ **For HR Variable** และ **For HR Fixed**
9. ส่งให้ **Business Owner** ตรวจสอบและอนุมัติ
10. Export ผลลัพธ์ผ่าน **SSRS** (SQL Server Reporting Services)
11. ส่งต่อให้ **HR** เพื่อดำเนินการจ่ายจริง
12. บันทึก **Audit Trail** และปิดรอบ

---

## 4. รายละเอียดขั้นตอนรายเดือน

| Step | ชื่อขั้นตอน | รายละเอียดธุรกิจ | Output หลัก | Owner |
|---|---|---|---|---|
| M1 | Set Period | ระบุว่างวดนี้คำนวณของเดือนไหน | Period ของรอบ | Sales Operations |
| M2 | Import Actual | ดึงและนำเข้ายอดขายจาก BI/DWC | Actual data พร้อมใช้ | Sales Operations |
| M3 | Update ASTBase | อัปเดตโครงสร้างองค์กร Salesman -> Sup -> Dept -> Div/AD | Hierarchy ล่าสุด | Sales Operations |
| M4 | Update HR Rep | นำเข้าข้อมูลพนักงาน active จาก HCM | Employee snapshot | Sales Operations |
| M5 | Calculation | ระบบคำนวณ achievement, GOAL, Incentive, GD, Fixed | Calculation result | System |
| M6 | Review & Approval | ตรวจสอบ trace และอนุมัติผล | Approved result | Business Owner |
| M7 | Export to HR | สร้างไฟล์ผลลัพธ์ส่งให้ HR | For HR output / SSRS file | System |
| M8 | Audit & Close | เก็บ log และปิดรอบ | Audit trail + period close | System |

---

## 5. ความต่างของ MT และ TT

| ประเด็น | MT | TT |
|---|---|---|
| วิธีรับข้อมูลขาย | รับ BI SalesCode + Product Group | รับ Salesman Code + SKU |
| Mapping | ต้อง map BI -> Salesman ก่อน | ไม่ต้อง map แบบ MT |
| หน่วยคำนวณหลัก | Product Group | SKU (Stock Keeping Unit) |
| วิธี cascade | SUMIFS รวม Target + Actual แล้วคำนวณใหม่ | Single-sheet logic แต่ผลคำนวณจริงมี 5 ระดับ |
| จำนวนระดับ hierarchy | 4 ระดับ: Staff -> Sect -> Dept -> AD | 5 ระดับ: Staff -> Sect -> Dept -> Div -> AD |
| Output พิเศษ | For HR Variable / Fixed | For HR Variable / Fixed และมี incentive_div |

**หมายเหตุสำคัญ:**
TT ไม่ใช่ “single-sheet แบบไม่มี cascade” แต่เป็น single-sheet ในเชิง worksheet structure ขณะที่ผลคำนวณจริงมี hierarchy 5 ระดับครบ

---

## 6. Special Logic ที่แทรกใน Flow

### 6.1 GD Special Incentive

GD = Growth Driver คือสินค้ากลุ่มพิเศษ เช่น Aji Plus, RDQ, RDM, RDNS

ลำดับโดยย่อ:
1. รับ Target และ Actual ของสินค้า GD
2. คำนวณ achievement รายสินค้า
3. Lookup payout ตามขั้น
4. รวมผลเพื่อเตรียมส่งออก

### 6.2 Fix Rate

Fix Rate คือค่าตอบแทนคงที่ตาม Job Function หรือ policy ที่กำหนด โดยไม่ขึ้นกับ achievement และอ้างอิงเดือนจ่ายจาก M_Month

---

## 7. จุดควบคุมสำคัญ (Control Points)

| รหัส | จุดควบคุม | ความหมาย |
|---|---|---|
| CP-1 | Period Alignment | ยอดขายและข้อมูลพนักงานต้องเป็นเดือนเดียวกับ Period |
| CP-2 | Data Completeness | Required fields ต้องครบ |
| CP-3 | Hierarchy Consistency | โครงสร้าง Salesman -> Supervisor ต้องสมบูรณ์ |
| CP-4 | Approval Before Export | ต้องอนุมัติก่อนส่งให้ HR |
| CP-5 | Audit Completeness | การแก้ parameter ต้องมีผู้แก้ เวลา และเหตุผล |
| CP-6 | Interface Completeness | ต้องมี batch summary ของการ import ครบ |
| CP-7 | Data Reconciliation | ยอด Actual หลัง mapping ต้อง reconcile กับต้นทาง |
| CP-8 | Output Integrity | จำนวนคนและยอดรวมใน output ต้องตรงกับรอบที่อนุมัติ |
| CP-9 | Period Close Governance | ปิดรอบได้เมื่อ export และ audit ครบ |

---

## 8. การจัดการข้อผิดพลาด (Exception Handling)

ถ้า Validation ไม่ผ่าน ระบบต้องไม่คำนวณต่อ แต่ต้องให้กลับไปแก้ที่ต้นทางก่อน เช่น:

1. Period mismatch
2. Required field ขาด
3. Mapping ไม่ครบ
4. Hierarchy gap
5. ไม่มีผู้อนุมัติแต่พยายาม export

หลักการคือ **แก้ที่ต้นทาง แล้ว validate ใหม่** ไม่ข้ามขั้นตอน

---

## 9. บทบาทของแต่ละฝ่าย

| บทบาท | หน้าที่หลัก |
|---|---|
| Sales Operations | ตั้ง Period, import ข้อมูล, update ASTBase/HR Rep, ปรับ parameter |
| Business Owner | ตรวจ trace และอนุมัติผลคำนวณ |
| HR / Compensation | รับ output ที่อนุมัติแล้วและนำไปจ่าย |
| Data Team | ดูแล feed ยอดขายจาก BI/DWC |
| HCM Owner | ดูแล feed ข้อมูลพนักงาน |
| System | validate, calculate, generate output, export, audit |

---

## 10. Input / Output ของกระบวนการ

| ประเภท | รายการ |
|---|---|
| Input | BI/DWC Sales, HCM Employee, ASTBase, Target, Parameter Tables |
| Working Data | Validation Result, Mapping Result, Calculation Trace |
| Output | For HR Variable, For HR Fixed, SSRS Export, Audit Log |

---

## 11. Definition of Done ของรอบเดือน

จะถือว่ารอบเดือน “เสร็จสมบูรณ์” เมื่อครบทุกเงื่อนไขต่อไปนี้

1. Period ถูกต้อง
2. Actual, ASTBase, HR Rep อยู่ในเดือนเดียวกัน
3. Validation ผ่าน
4. Calculation result ตรวจสอบย้อนหลังได้
5. Business Owner อนุมัติแล้ว
6. Export ให้ HR สำเร็จ
7. Audit log ครบ
8. ปิดรอบเรียบร้อย

---

## 12. สรุปแบบสั้นที่สุด

Business Flow Process ของ AJT New Sale Incentive คือ:

**ตั้งงวด -> นำเข้ายอดขายและข้อมูลพนักงาน -> ตรวจข้อมูล -> คำนวณตามกติกา MT/TT -> รวม GD/Fix Rate -> สร้างผล For HR -> อนุมัติ -> ส่ง HR -> Audit และปิดรอบ**

---

## เอกสารอ้างอิงหลัก

1. [5.Docs/BRD-SRS_AJT-New-Sale-Incentive_Draft-v0.1_2026-06-12.md](../5.Docs/BRD-SRS_AJT-New-Sale-Incentive_Draft-v0.1_2026-06-12.md)
2. [5.Docs/Business-Process-Design_AJT-New-Sale-Incentive_v1.0_2026-06-13.md](../5.Docs/Business-Process-Design_AJT-New-Sale-Incentive_v1.0_2026-06-13.md)
3. [5.Docs/System-Flow-Design_AJT-New-Sale-Incentive_v1.0_2026-06-13.md](../5.Docs/System-Flow-Design_AJT-New-Sale-Incentive_v1.0_2026-06-13.md)
4. [5.Docs/Sales Incentive System for POC.md](../5.Docs/Sales%20Incentive%20System%20for%20POC.md)
5. [4.System Analyst and Design/06_Sales-Incentive-Guide-Explanation.md](../4.System%20Analyst%20and%20Design/06_Sales-Incentive-Guide-Explanation.md)
