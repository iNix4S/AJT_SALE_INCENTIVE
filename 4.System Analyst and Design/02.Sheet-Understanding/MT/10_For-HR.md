# Sheet: 1) For HR

- **ไฟล์ต้นทาง:** MT และ TT
- **ประเภท:** Output
- **จำนวนแถว x คอลัมน์:** ตามจำนวนพนักงาน x 19 คอลัมน์

## วัตถุประสงค์ของ sheet
**Sheet Output หลัก** — รวม incentive ของพนักงาน 1 คน จากทุกระดับ (Staff + Sect + Dept + AD)  
เป็นผลลัพธ์สุดท้ายที่ส่งให้ HR สำหรับการจ่ายเงิน (Variable Incentive)

แต่ละแถว = 1 พนักงาน (Employee ID)

## Input (รับข้อมูลจากไหน)
- **A (Employee ID)**: กรอก manual ทุกเดือน (Guide: Monthly Step 5)
- **B (SalesmanCode)**: VLOOKUP จาก ASTBase ตาม EmpID
- **C–J (Employee details)**: VLOOKUP จาก HR Rep (ชื่อ, Grade, Position ฯลฯ)
- **O (Floor)**: คงที่หรือ lookup ตามตำแหน่ง (minimum incentive)
- **P (Staff incentive)**: SUMIFS จาก `3)Target & Cal_Staff` col BN, keyed by EmpID
- **Q (Sect incentive)**: SUMIFS จาก `3)Target & Cal_Sect` col BN
- **R (Dept incentive)**: SUMIFS จาก `3)Target & Cal_Dept` col BN
- **S (AD incentive)**: SUMIFS จาก `3)Target & Cal_AD` col BN

## Output (ส่งข้อมูลไปไหน)
- **ส่งให้ HR** สำหรับประมวลผลการจ่ายเงิน
- col K = Monthly Sales Compensation (ค่าตอบแทนจ่ายจริง)

## สูตร/ตรรกะสำคัญ

| เซลล์ | สูตร | ความหมาย |
|-------|------|----------|
| B2 | `=VLOOKUP(A2, ASTBase!F:P, 11, FALSE)` | ดึง Salesman Code จาก EmpID |
| C2–J2 | `=VLOOKUP($A2, 'HR Rep'!$A:$X, MATCH(header, 'HR Rep'!row1, 0), 0)` | ดึง employee attributes จาก HR Rep |
| **K2** | `=IF(ROUND(P2+Q2+R2+S2,2) < O2, O2, ROUND(P2+Q2+R2+S2,2))` | **ผลลัพธ์หลัก: MAX(floor, P+Q+R+S)** |
| P2 | `=SUMIFS('3)Target & Cal_Staff'!BN, EmpCode col, A2)` | incentive จาก Staff level |
| Q2 | `=SUMIFS('3)Target & Cal_Sect'!BN, EmpCode col, A2)` | incentive จาก Section level |
| R2 | `=SUMIFS('3)Target & Cal_Dept'!BN, EmpCode col, A2)` | incentive จาก Dept level |
| S2 | `=SUMIFS('3)Target & Cal_AD'!BN, EmpCode col, A2)` | incentive จาก AD level |

### Logic สรุป
```
incentive_total = ROUND(Staff + Sect + Dept + AD, 2)
K (จ่ายจริง) = MAX(floor O, incentive_total)
```

### โครงสร้างคอลัมน์

| คอลัมน์ | ชื่อ | ความหมาย |
|---------|-----|----------|
| A | User/Employee ID | รหัสพนักงาน (input manual) |
| B | SalesmanCode | lookup จาก ASTBase |
| C | Full Name Alt1 | lookup จาก HR Rep |
| D | Full Name | lookup จาก HR Rep |
| E | Job Grade | lookup จาก HR Rep |
| F | Position Name (TH) | lookup จาก HR Rep |
| G | Position Level | lookup จาก HR Rep |
| H | Job Function | lookup จาก HR Rep |
| I | Division Name | lookup จาก HR Rep |
| J | Department/Section | lookup จาก HR Rep |
| K | **Monthly Sales Compensation** | **ค่าตอบแทนที่จ่ายจริง (MAX floor)** |
| L | sales incentive ของเดือน | จาก Period sheet |
| M | รอบการจ่าย Incentive | จาก Period sheet |
| N | รูปแบบการจ่าย | Variable / Fixed |
| O | Fix rate (floor) | ค่าต่ำสุดที่รับประกัน |
| P | Staff incentive | จาก Target & Cal_Staff |
| Q | Section incentive | จาก Target & Cal_Sect |
| R | Dept incentive | จาก Target & Cal_Dept |
| S | AD incentive | จาก Target & Cal_AD |

## ข้อสังเกต / คำถามค้างคา
- ❓ "Floor" (col O) มาจากไหน — hardcode หรือ lookup ตาม Position?
- ❓ พนักงานที่รับผิดชอบหลายระดับ (เช่น Section Manager ที่ยังขายด้วย) — มีทั้ง Staff incentive และ Sect incentive หรือไม่? → ดูจากข้อมูล: **ใช่** (มีทั้ง P และ Q ไม่เป็น 0)
- MT มี sheet นี้ + **1) For HR (FIX)** แยกสำหรับ Fixed rate
- TT มี sheet นี้ + **1) For HR (AD)** สำหรับ AD level
