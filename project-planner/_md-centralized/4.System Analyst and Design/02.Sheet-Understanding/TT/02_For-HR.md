# Sheet: 1) For HR (TT)

- **ไฟล์ต้นทาง:** TT
- **ประเภท:** Output
- **จำนวนแถว x คอลัมน์:** ตามจำนวนพนักงาน x 24 คอลัมน์

## วัตถุประสงค์ของ sheet
**Sheet Output หลัก สำหรับ TT** — รวม incentive ของพนักงานทุกระดับในชีตเดียว  
ต่างจาก MT ที่แสดงเฉพาะ Staff–AD สรุปรวม  
TT For HR แสดงทุกระดับ: Salesman, Direct Superior, Dept Manager, Div Manager ในคอลัมน์แยก

## Input (รับข้อมูลจากไหน)
- **A (Employee ID)**: input manual
- **B (SalesmanCode)**: lookup จาก ASTBase
- **C–J (Employee details)**: VLOOKUP จาก HR Rep
- **P (Salesman incentive)**: SUMIFS จาก `3) Target & Cal` col Incentive, keyed by SalesmanCode
- **Q (%Direct superior)**: คำนวณ percentage ของ Direct Sup
- **R (Direct superior amount)**: SUMIFS ตาม DirectSupCode
- **S (Dept Mgr Code)**: lookup hierarchy
- **T (%Dept Mgr)** / **U (Dept Mgr amount)**: incentive ระดับ Dept Mgr
- **V (Div Mgr Code)** / **W (%Div Mgr)** / **X (Div Mgr amount)**: incentive ระดับ Div Mgr

## Output (ส่งข้อมูลไปไหน)
- **col K (Monthly Sales Compensation)**: ส่งให้ HR จ่าย incentive
- **1) For HR (AD)**: อ้างอิง Div Mgr หรือ AD level แยกต่างหาก

## สูตร/ตรรกะสำคัญ

### โครงสร้างคอลัมน์ TT For HR (ละเอียดกว่า MT)

| คอลัมน์ | ชื่อ | ความหมาย |
|---------|-----|----------|
| A | User/Employee ID | รหัสพนักงาน |
| B | SalesmanCode | lookup จาก ASTBase |
| C–J | Employee details | VLOOKUP จาก HR Rep |
| K | **Monthly Sales Compensation** | ค่าตอบแทนที่จ่ายจริง |
| L | sales incentive ของเดือน | |
| M | รอบการจ่าย Incentive | |
| N | รูปแบบการจ่าย | Variable/Fixed |
| O | Fix rate | ค่าตอบแทนคงที่ (ถ้ามี) |
| P | Salesman incentive | SUMIFS จาก Target & Cal ตาม SalesmanCode |
| Q | %Direct superior | อัตราส่วน Sup incentive |
| R | Direct superior amount | incentive ระดับ Direct Sup |
| S | Dept Mgr Code | รหัส Dept Manager |
| T | %Dept Mgr | |
| U | Dept Mgr amount | |
| V | Div Mgr Code | |
| W | %Div Mgr | |
| X | Div Mgr amount | |

### ตัวอย่างข้อมูล
| EmpID | Position | Salesman | %Sup | Sup Incentive | Dept | Div Mgr |
|-------|----------|----------|------|---------------|------|---------|
| 000004 | Section Mgr (Depocho) | 0 | 108.4% | 4,337 | 000003 | 0 |
| 000005 | Supervisor (Deputy) | **4,290** | 0 | 0 | 0 | 0 |
| 000006 | Staff (Shop Front) | **3,960** | 0 | 0 | 0 | 0 |

→ Staff/Supervisor รับ incentive จาก `Salesman` column (col P)  
→ Section Manager รับจาก `Direct Superior` column (col R) = % × SUMIFS ของทีม

## ข้อสังเกต / คำถามค้างคา
- **TT For HR มีคอลัมน์มากกว่า MT** — แสดง breakdown ทุกระดับในชีตเดียว
- col Q `%Direct Superior` = multiplier ที่ section manager ได้รับ → ❓ มาจากไหน? (หรือ = achievement รวม?)
- ❓ "Fix rate" ใน TT For HR = col O เสมอหรือไม่? เทียบกับ MT ที่มี sheet แยก (FIX)
- พนักงานระดับ Salesman/Staff → col P ≠ 0, col R = 0
- พนักงานระดับ Section Mgr → col P = 0, col R ≠ 0
