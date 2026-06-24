# AJT System Flow Process Summary

วันที่: 2026-06-14  
เวอร์ชัน: v1.0  
ขอบเขต: สรุป System Flow Process ของ AJT New Sale Incentive สำหรับทีม Business, SA, Dev, QA และผู้เกี่ยวข้อง

---

## 1. วัตถุประสงค์

เอกสารนี้สรุปการไหลของระบบ (System Flow) ตั้งแต่รับข้อมูลเข้า ตรวจสอบความถูกต้อง คำนวณตามช่องทาง MT และ TT รวมถึงการจัดการ GD Special Incentive, Fixed Rate, Approval, Export และ Audit เพื่อให้เห็นภาพว่า logic ของระบบทำงานอย่างไรแบบ end-to-end

---

## 2. ภาพรวม End-to-End System Flow

System Flow ของระบบนี้เริ่มจากการรับข้อมูลต้นทาง แล้วผ่าน validation ก่อนแยก logic ตาม channel จากนั้นจึงรวมผลเพื่อสร้าง output และส่งออกให้ HR

ลำดับหลักคือ:

1. รับข้อมูล `BI Sales + HCM Employee`
2. ตรวจสอบ `Validation Gate`
3. แยกเส้นทาง `MT` หรือ `TT`
4. คำนวณผลหลักตาม channel
5. คำนวณ `GD Special Incentive` (ถ้ามี)
6. คำนวณ `Fixed Rate`
7. สร้าง `For HR Output`
8. เข้า `Approval Workflow`
9. `Export to HR`
10. `HR Payment Processing`
11. `Audit Trail + Period Close`

---

## 3. ลำดับการทำงานของระบบ

### 3.1 Input Stage

ระบบรับข้อมูลหลัก 2 กลุ่ม:

1. `BI / DWC Sales Data`
- ยอดขายจริงรายเดือน
- MT ใช้ Product Group + BI SalesCode
- TT ใช้ Salesman Code + SKU

2. `HCM Employee Data`
- ข้อมูลพนักงาน active
- Employee ID, Position, Job Function, โครงสร้างที่เกี่ยวข้อง

ข้อมูลทั้งสองชุดต้องสอดคล้องกับเดือนของ `Period`

### 3.2 Validation Gate

ก่อนคำนวณ ระบบต้องตรวจ:

1. `Period alignment`
2. `Required fields completeness`
3. `Hierarchy consistency`
4. `Mapping completeness` (สำคัญมากใน MT)

ถ้าไม่ผ่าน:

1. ระบบ block processing
2. แจ้งข้อผิดพลาด
3. ให้แก้ต้นทางและ retry ใหม่

---

## 4. MT Flow (Modern Trade)

### 4.1 หลักการ

MT ใช้ยอดขายในระดับ `Product Group` และต้องผ่าน mapping ก่อน เพราะข้อมูลต้นทางจาก BI ไม่ได้พร้อมใช้ตรงกับ salesman ในระบบคำนวณ

### 4.2 ลำดับการไหล

1. รับ `BI SalesCode + Product Group`
2. ทำ `Mapping` ไปเป็น `Salesman Code`
3. คำนวณระดับ `Staff`
4. Cascade ไป `Section`
5. Cascade ไป `Department`
6. Cascade ไป `AD`
7. รวมผล incentive ทุกระดับเพื่อส่งเข้า `For HR`

### 4.3 สูตรและ logic หลักของ MT

1. `achievement = ROUND(Actual / Target, 4)`
2. ถ้า shortage -> `achievement = 1.0`
3. `GOAL = XLOOKUP(achievement)` แบบ step-down
4. `incentive = base × GOAL × weight`
5. Cascade ใช้ `SUMIFS Target+Actual` แล้วคำนวณใหม่ทุกระดับ

### 4.4 จุดสำคัญของ MT

1. Mapping ผิด = คำนวณผิดทั้งสาย
2. Cascade เป็น 4 ระดับ: `Staff -> Sect -> Dept -> AD`
3. ผลรวมรายคนใช้หลัก `floor + sum of all applicable levels`

---

## 5. TT Flow (Traditional Trade)

### 5.1 หลักการ

TT ใช้ยอดขายตรงในระดับ `Salesman Code + SKU` และไม่ต้องทำ mapping แบบ MT

อย่างไรก็ตาม TT ไม่ได้เป็นแค่ single-sheet แบบไม่มี hierarchy แต่เป็น single-sheet ในเชิง worksheet structure ขณะที่ผลคำนวณจริงมี hierarchy ครบ 5 ระดับ

### 5.2 ลำดับการไหล

1. รับ `Salesman Code + SKU`
2. คำนวณที่ระดับ Sales/Staff
3. ส่งผลขึ้น `Section`
4. ส่งผลขึ้น `Department`
5. ส่งผลขึ้น `Division`
6. ส่งผลขึ้น `AD`
7. รวมผลใน `For HR`

### 5.3 สูตรและ logic หลักของ TT

1. `achievement = ROUND(Actual / Target, 4)` ต่อ SKU
2. ถ้า shortage -> `achievement = 1.0`
3. `GOAL = XLOOKUP / HLOOKUP` ตาม threshold
4. `incentive = base × GOAL × weight`
5. การส่งผลขึ้นระดับบนใช้ `AVERAGEIFS`

### 5.4 จุดสำคัญของ TT

1. ไม่ต้อง mapping แบบ MT
2. ใช้ `AVERAGEIFS` ต่างจาก MT ที่ใช้ `SUMIFS`
3. มี hierarchy 5 ระดับ:
- `STAFF -> SECT_MGR -> DEPT_MGR -> DIV_MGR -> AD`
4. Output Variable ของ TT ต้องรองรับ `incentive_div`

---

## 6. GD Special Incentive Flow

GD คือ incentive พิเศษสำหรับสินค้ากลุ่ม Growth Driver เช่น:

1. Aji Plus
2. RDQ (Rosdee Cube)
3. RDM (Rosdee Menu)
4. RDNS (Rosdee Noodle)

ลำดับการไหล:

1. รับ Target และ Actual รายสินค้า GD
2. คำนวณ achievement รายเดือน
3. Lookup payout จากตาราง GD payout
4. รวมผลเป็น incentive ของ GD
5. ส่งผลไปยัง output ตาม policy ที่ตกลง

หมายเหตุ:

1. GD ไม่ใช้สูตร `base × goal × weight` แบบสูตรหลัก
2. ใช้ payout table แบบรายสินค้า
3. วิธีนำไปจ่ายจริงยังต้องยึด policy ที่ยืนยันใน Decision Log

---

## 7. Fixed Rate Flow

Fixed Rate เป็นส่วนเสริมที่คำนวณแยกจาก Variable โดยอิง Job Function หรือสิทธิ์ที่กำหนดไว้

ลำดับการไหล:

1. รับข้อมูลพนักงาน/Job Function
2. Lookup อัตรา Fixed Rate
3. Lookup เดือนจ่ายจาก `M_Month`
4. สร้าง `For HR (Fixed)`

จุดสำคัญ:

1. Fixed จ่ายตามเดือนจ่ายที่กำหนดไว้
2. โดยหลัก Fixed จะจ่ายเร็วกว่า Variable 1 เดือน

---

## 8. Generate Output และ Approval

หลังจาก logic หลักของ MT/TT + GD + Fixed เสร็จ ระบบจะสร้างผลลัพธ์ปลายทาง:

1. `For HR Variable`
2. `For HR Fixed`

จากนั้นต้องผ่าน `Approval Workflow`:

1. Draft
2. Reviewed
3. Approved
4. Exported

หากไม่ผ่านการอนุมัติ ระบบต้องย้อนกลับไปแก้/คำนวณใหม่ตามสาเหตุที่พบ

---

## 9. Export, Payment และ Audit

เมื่อผลได้รับอนุมัติ:

1. ระบบ export ผลลัพธ์ให้ HR ผ่าน SSRS หรือรูปแบบที่ตกลง
2. HR นำผลไปดำเนินการจ่าย
3. ระบบบันทึก Audit Trail
4. ปิดรอบเมื่อ export สำเร็จและ log ครบ

---

## 10. Validation และ Exception Handling

ข้อผิดพลาดหลักที่ระบบต้องจับได้:

1. `Period mismatch`
2. `Missing required field`
3. `Hierarchy gap`
4. `MT mapping incomplete`

หลักการจัดการ:

1. ไม่ให้คำนวณต่อถ้า validation ไม่ผ่าน
2. แจ้ง error ให้ชัดว่าต้องแก้ที่จุดไหน
3. ให้แก้ข้อมูลต้นทางก่อนแล้วค่อยวนกลับมาคำนวณใหม่

---

## 11. ความต่างหลัก MT vs TT

| หัวข้อ | MT | TT |
|---|---|---|
| หน่วยข้อมูล | Product Group | SKU |
| Mapping | ต้องมี | ไม่ต้องมีแบบ MT |
| วิธี cascade | SUMIFS Target+Actual แล้วคำนวณใหม่ | AVERAGEIFS ดึงค่าจากระดับล่าง |
| จำนวน hierarchy | 4 ระดับ | 5 ระดับ |
| โครงสร้าง worksheet | แยกหลาย sheet | single-sheet |
| Output Variable | Staff/Sect/Dept/AD | Staff/Sect/Dept/Div/AD |

---

## 12. สรุปสั้นที่สุด

System Flow Process ของ AJT New Sale Incentive คือ:

`รับข้อมูล -> Validate -> แยก MT/TT -> คำนวณ -> รวม GD + Fixed -> Generate Output -> Approve -> Export -> Audit + Close`

ดังนั้น System Flow เอกสารนี้เน้นมุมมอง “ระบบทำงานอย่างไร” ในขณะที่ Business Flow จะเน้นมุมมอง “คนในกระบวนการทำอะไรและส่งต่องานกันอย่างไร”

---

## 13. เอกสารอ้างอิง

1. `System-Flow-Design_AJT-New-Sale-Incentive_v1.0_2026-06-13.md`
2. `Business-Process-Design_AJT-New-Sale-Incentive_v1.0_2026-06-13.md`
3. `BRD-SRS_AJT-New-Sale-Incentive_Draft-v0.1_2026-06-12.md`
4. `Sales Incentive System for POC.md`
5. `4.System Analyst and Design/03.Calculation-Logic/00_สรุปตรรกะการคำนวณ_ตั้งต้น.md`