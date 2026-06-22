# Sales Incentive Guide — คำอธิบายเชิงปฏิบัติ (MT/TT)

วันที่: 2026-06-12  
แหล่งอ้างอิง: Guide sheet จากไฟล์ Incentive (MT) และผลวิเคราะห์ในโฟลเดอร์ 01/02/03/05

---

## 1) วัตถุประสงค์
เอกสารนี้อธิบาย "วิธีใช้งาน Sale Incentive Guide" ให้ทีม Business, SA, และผู้ปฏิบัติการสามารถทำงานรายเดือนแบบมาตรฐานเดียวกัน โดยเน้น:
- ลำดับงานที่ต้องทำในแต่ละรอบ
- จุดควบคุมข้อมูล (Data Control Points)
- ความเสี่ยงที่พบบ่อยและวิธีป้องกัน
- เงื่อนไขจบงานของรอบ (Definition of Done)

---

## 2) โครงสร้าง Guide ในภาพรวม
Guide แบ่งงานเป็น 3 กลุ่มหลัก

1. Annually (ปีละครั้ง):
- กำหนดตาราง mapping ระหว่างเดือนยอดขายกับเดือนจ่าย Incentive ของ Variable และ Fixed ใน M_Month

2. Monthly (ทุกเดือน):
- กำหนดงวดคำนวณ
- นำเข้ายอดขายจริงจาก BI
- อัปเดตโครงสร้างองค์กร (AST_Base)
- อัปเดตข้อมูลพนักงานจาก HCM (HR Rep)
- สรุปผลจ่ายใน For HR

3. As needed (ทำเมื่อมีเหตุ):
- ปรับอัตราตามตำแหน่ง
- ปรับอัตราตาม Job Function
- ปรับ Target ตามสถานการณ์ธุรกิจ
- ระบุ Shortage รายสินค้า/เดือน
- ปรับ Fix Rate รายพนักงาน

---

## 3) คำอธิบายรายขั้นตอน

### 3.1 Annually

#### Step 1: M_Month
วัตถุประสงค์:
- กำหนดความสัมพันธ์ระหว่างเดือนยอดขายกับเดือนจ่าย Incentive แยก Variable และ Fixed

ผลกระทบ:
- ถ้าตั้ง mapping ผิด จะทำให้เดือนจ่ายของ payroll ผิดทั้งรอบและกระทบทั้ง Variable กับ Fixed

Control:
- ต้องมีผู้อนุมัติจาก Business Owner ก่อน lock ค่า

---

### 3.2 Monthly

#### Step 1: Period
วัตถุประสงค์:
- ระบุว่า "งวดนี้คำนวณของเดือนไหน"

Control:
- Period ต้องตรงกับชุดข้อมูล Actual และ HR snapshot เดือนเดียวกัน

#### Step 2: Actual
วัตถุประสงค์:
- นำเข้ายอดขายจริงจาก BI ลง Actual sheet

Control:
- ตรวจจำนวนแถวและ key หลัก (Salesman Code/Product) ก่อนคำนวณ
- ห้ามใช้ไฟล์ยอดขายคนละเดือนกับ Period

#### Step 3: AST_Base
วัตถุประสงค์:
- อัปเดตโครงสร้างผู้บังคับบัญชา (Salesman -> Direct Sup -> Dept -> Div)
- คัดลอกสูตรในคอลัมน์สีเหลือง

Control:
- ตรวจ hierarchy ว่าไม่ขาด chain และไม่มีรหัสซ้ำผิดโครงสร้าง

#### Step 4: HR Rep
วัตถุประสงค์:
- นำเข้าข้อมูลพนักงานจากรายงาน HCM (Personal Employment Main & Active)_AST
- คัดลอกสูตรในคอลัมน์สีเหลือง

Control:
- Employee ID ต้องตรงกับ AST_Base
- Job Function/Position ต้องครบเพื่อคำนวณอัตราได้ถูกต้อง

#### Step 5: For HR
วัตถุประสงค์:
- สร้างผลลัพธ์จ่ายรายคนสำหรับส่ง HR

วิธีทำตาม Guide:
- กรอก Employee ID
- คัดลอกสูตรทุกคอลัมน์ ยกเว้น Employee ID และ Payment Method

Control:
- ตรวจยอดรวมรายคน (Staff + Section + Dept + AD) และ floor/fix policy ก่อนอนุมัติ

---

### 3.3 As needed

#### Step 1: T_SectAbove
- ปรับอัตราค่าตอบแทนตามระดับตำแหน่ง
- ใช้เมื่อมีการเปลี่ยน policy ระดับตำแหน่ง

#### Step 2: Table
- ปรับอัตราตาม Job Function
- ใช้เมื่อมีการปรับสูตรจ่ายตามบทบาทงาน

#### Step 3: Target & Cal
- ปรับ Target ตามสภาพธุรกิจ
- ต้องบันทึกเหตุผลการเปลี่ยนค่าและวันที่มีผล

#### Step 4: Shortage
- ระบุกรณีสินค้าขาดตลาดเป็นรายสินค้า/รายเดือน
- กระทบ achievement/incentive โดยตรง

#### Step 5: Fix Rate
- ปรับอัตราคงที่รายพนักงาน
- ต้องมีหลักฐานอนุมัติ policy ทุกครั้ง

---

## 4) กฎทองของ Guide (ข้อความสีแดง)
"Please ensure that sales and employee data align with the Sales Incentive period for that month"

ความหมายเชิงปฏิบัติ:
- Period, Actual, AST_Base, HR Rep ต้องเป็น snapshot เดือนเดียวกัน
- หากเดือนข้อมูลไม่ตรงกัน จะทำให้:
  - สิทธิ์ผู้รับคลาดเคลื่อน
  - ยอดจ่ายผิดคน/ผิดจำนวน
  - ตรวจสอบย้อนหลังยาก

---

## 5) As-Is -> To-Be (ข้อเสนอปรับกระบวนการ)

As-Is:
- ทำงาน manual หลายจุด (copy/paste และ copy สูตร)
- เสี่ยง human error โดยเฉพาะเรื่องเดือนข้อมูลไม่ตรงกัน

To-Be (แนะนำ):
- เพิ่ม Pre-checklist ก่อนคำนวณทุกเดือน
- บังคับ validation key fields (EmpID, Salesman Code, Period)
- เก็บ audit log ทุกการปรับค่าใน As-needed sheets

Gap สำคัญ:
- ยังไม่มี gate ตรวจ period alignment แบบบังคับก่อนจบงวด

---

## 6) Checklist ก่อนปิดงวด (Operational)

1. Period ถูกต้องตามเดือนที่ต้องจ่าย
2. Actual มาจาก BI รอบเดียวกับ Period
3. AST_Base เป็นโครงสร้างล่าสุดของเดือนนั้น
4. HR Rep เป็น snapshot เดือนเดียวกันกับ Period
5. Employee ID ใน For HR ครบและไม่ซ้ำผิด
6. คอลัมน์สูตรที่กำหนดถูก copy ครบ (AST_Base/HR Rep/For HR)
7. As-needed changes (ถ้ามี) มีเอกสารอนุมัติ
8. Shortage/Fix Rate ตรง policy ล่าสุด
9. ตรวจยอดรวม For HR รายคนเทียบผลคาดการณ์
10. ได้รับ sign-off จาก Business Owner ก่อนส่ง HR จ่ายจริง

---

## 7) Definition of Done (รายเดือน)
จะถือว่า "จบรอบคำนวณเดือนนั้น" เมื่อครบเงื่อนไขทั้งหมด:
- ผ่าน Checklist 10 ข้อ
- ไม่มี error สำคัญในข้อมูล key
- Period alignment ถูกต้องทั้ง Sales และ Employee
- ผลลัพธ์ For HR พร้อมส่งจ่าย และได้รับอนุมัติ

---

## 8) ความเชื่อมโยงกับเอกสารอื่นในโครงการ
- 03.Calculation-Logic: อธิบายสูตรคำนวณเชิงลึก
- 02.Sheet-Understanding: อธิบายหน้าที่แต่ละชีต
- 05.Process-Flow: อธิบายการไหลของข้อมูลข้ามชีต
- 04.Data-Dictionary: นิยามฟิลด์และรหัสข้อมูล
