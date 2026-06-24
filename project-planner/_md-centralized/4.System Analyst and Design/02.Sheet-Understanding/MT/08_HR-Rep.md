# Sheet: HR Rep

- **ไฟล์ต้นทาง:** MT และ TT
- **ประเภท:** Master Data / HR Input
- **จำนวนแถว x คอลัมน์:** หลายร้อยแถว x 28 คอลัมน์

## วัตถุประสงค์ของ sheet
เก็บข้อมูล HR ของพนักงานทุกคนที่เกี่ยวข้องกับ incentive  
download มาจาก HCM (Human Capital Management System) รายงาน "Personal Employment (Main & Active)_AST"  
เป็น source ของ employee attributes ที่แสดงใน 1) For HR

## Input (รับข้อมูลจากไหน)
- **HCM System** — ผู้ดูแลระบบ download + paste ทุกเดือน (Guide: Monthly Step 4)
- บางคอลัมน์เป็น "คอลัมน์เหลือง" = สูตร ต้อง copy หลังจาก paste ข้อมูลใหม่

## Output (ส่งข้อมูลไปไหน)
- ถูก VLOOKUP โดย **1) For HR** เพื่อดึงชื่อ, ตำแหน่ง, Job Grade, Cost Centre ฯลฯ

## สูตร/ตรรกะสำคัญ
| เซลล์ | สูตร (ตัวอย่าง) | ความหมาย |
|-------|----------------|----------|
| Direct Sup (col AB) | `=VLOOKUP(A, ASTBase, col, FALSE)` | ดึง DirectSup จาก ASTBase ตาม EmpID |
| EmpCode (col AC) | ซ้ำ EmpID | EmpID แบบ normalized |

### คอลัมน์หลักที่ถูกใช้ใน 1) For HR

| คอลัมน์ | ตัวอย่าง | ความหมาย |
|---------|---------|----------|
| A: User/Employee ID | `222208` | รหัสพนักงาน (key) |
| L: Job Title | - | ตำแหน่งงาน |
| M: Position Name (TH) | - | ชื่อตำแหน่งภาษาไทย |
| N: Position Level | - | ระดับตำแหน่ง |
| P: Job Grade | - | Job Grade |
| R: Cost Centre | - | รหัสศูนย์ต้นทุน |
| X: Job Function | - | Job Function (ใช้เลือก incentive category) |
| AB: Direct Sup | `222234` | รหัส supervisor ตรง (lookup จาก ASTBase) |
| AC: EmpCode | `222208` | รหัสพนักงาน (normalized) |

> หมายเหตุ: ชื่อ/รายละเอียดพนักงานถูก mask ออกในตัวอย่าง (privacy)

## ข้อสังเกต / คำถามค้างคา
- ❓ "คอลัมน์เหลือง" ใน HR Rep คือคอลัมน์ใดบ้าง? — สูตร lookup จาก ASTBase หรือ calculated field?
- ❓ เมื่อพนักงานลาออกกลางปี ยังคงอยู่ใน HR Rep ไหม? จะมีผลต่อ incentive งวดก่อนหน้าอย่างไร?
- Job Function = ตัวกำหนดสำคัญสำหรับ "Fixed Rate" incentive — ต้องตรงกับตารางใน ค่าตอบแทนคงที่ sheet
