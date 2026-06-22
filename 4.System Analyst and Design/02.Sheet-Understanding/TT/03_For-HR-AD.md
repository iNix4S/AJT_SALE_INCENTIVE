# Sheet: 1) For HR (AD) (TT เท่านั้น)

- **ไฟล์ต้นทาง:** TT เท่านั้น (MT ใช้ `1) For HR (FIX)` แทน)
- **ประเภท:** Output (ระดับ AD)
- **จำนวนแถว x คอลัมน์:** น้อยมาก (~5 แถว) x 28 คอลัมน์

## วัตถุประสงค์ของ sheet
Output สำหรับพนักงานระดับ **Associate Director (AD)** ของ TT  
แยกออกจาก 1) For HR ปกติ เนื่องจาก AD มีโครงสร้างการคำนวณที่ซับซ้อนกว่า  
รวม incentive จาก Salesman ทุกคนในสายงาน + Laos Dept

## Input (รับข้อมูลจากไหน)
- คอลัมน์ employee details: lookup จาก HR Rep
- **%AD** / **AD amount**: SUMIFS + คำนวณจาก 3) Target & Cal ระดับ AD
- **Laos Dept**: incentive จากทีม Laos แยกต่างหาก

## Output (ส่งข้อมูลไปไหน)
- ส่งให้ HR สำหรับจ่าย AD incentive

## สูตร/ตรรกะสำคัญ

### โครงสร้างคอลัมน์ (ขยายจาก For HR ปกติ)

| คอลัมน์ | ความหมาย |
|---------|----------|
| A–N | เหมือน 1) For HR ปกติ (EmpID, details, Fix rate) |
| O–X | Salesman, Direct Sup, Dept Mgr, Div Mgr (เหมือน For HR ปกติ) |
| Y | %AD (อัตราส่วน AD incentive) |
| Z | AD amount |
| AA | Laos Dept amount |

### ตัวอย่างข้อมูล
| EmpID | Position | Monthly Compensation | %AD | AD | Laos |
|-------|----------|---------------------|-----|----|------|
| 000001 | TT AD (inc. Laos) | **6,447.56** | 107.5% | 6,447.56 | 1.12 |

## ข้อสังเกต / คำถามค้างคา
- ❓ "Laos Dept" = incentive จาก Laos territory แยกต่างหากหรือ? ต้องยืนยัน scope
- AD ใน TT คนเดียว (row เดียว) — บ่งบอกว่ามี AD เพียงคนเดียวใน TT division
- MT ไม่มี sheet นี้ — ระดับ AD ของ MT รวมใน `1) For HR` ปกติ (col S)
- ❓ ทำไม TT แยก AD ออกมา sheet ต่างหาก?
