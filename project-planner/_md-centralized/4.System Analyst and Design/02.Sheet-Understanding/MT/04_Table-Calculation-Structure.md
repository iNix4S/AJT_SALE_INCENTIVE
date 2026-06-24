# Sheet: 2) หลักการคำนวน Table

- **ไฟล์ต้นทาง:** MT และ TT
- **ประเภท:** Master Data / Calculation Parameter
- **จำนวนแถว x คอลัมน์:** ~25+ แถว x 25+ คอลัมน์

## วัตถุประสงค์ของ sheet
เป็นตารางอัตรา incentive รายพนักงาน (Salesman Code / Team) ที่ระบุ:
1. **Incentive Base** ของแต่ละคน (บาท/เดือน)
2. **GOAL bracket values** ที่คำนวณจาก Base × Multiplier (ทุก threshold)
3. **Product Weight** ของแต่ละ Product Group สำหรับ Salesman นั้น ๆ (fraction ของ Base)

ทุก row = 1 Salesman/Team  
สูตรคำนวณ incentive ใน Target & Cal จะ VLOOKUP/XLOOKUP หา Team Code ใน sheet นี้

## Input (รับข้อมูลจากไหน)
- **Incentive Base ($B)**: อ้างอิงจาก **Top WS** (col H — Incentive base ตามตำแหน่ง)
- **GOAL multipliers (row 2)**: อ้างอิงจาก **Top WS** GOAL table (hardcoded ใน row)
- **Product weights**: คำนวณจาก Base หาร product count ในกลุ่ม (หรือกำหนด manual)
- ปรับแก้ไขได้ตาม business conditions (As-needed ตาม Guide)

## Output (ส่งข้อมูลไปไหน)
- ถูก lookup โดย **3) Target & Cal_Staff** (และระดับอื่น) เพื่อดึง incentive amount per product

## สูตร/ตรรกะสำคัญ

| เซลล์ | สูตร | ความหมาย |
|-------|------|----------|
| C4 | `=($B4*C$2)` | incentive ที่ product C (row 2 = weight) × Base ($B4) |
| E4 | `=($B4*E$2)` | เช่นเดียวกันสำหรับ product E |

### โครงสร้าง Columns

| คอลัมน์กลุ่ม | รายละเอียด |
|-------------|-----------|
| A | Team Code (Salesman Code) |
| B | Incentive Base (บาท) |
| C–K | GOAL bracket: incentive amount ที่ achievement ≥0.90 / ≥0.95 / ≥1.00 / ≥1.03 / ≥1.06 / ≥1.10 / ≥1.15 / ≥1.20 / ≥1.30 |
| L–Z+ | Product Weight per product (AJ, RD, BD, AJP, RDC, RM, ND, YY, PDC, TKM, RKR, AMV, AJA, FP, QM) |

### ตัวอย่างข้อมูล (Team 222208)
- Base = 5,000 บาท
- GOAL brackets: 4,500 / 4,750 / 5,000 / 5,150 / 5,400 / 5,500 / 5,750 / 6,000 / 6,500
- Product weights: AJ=3%, RD=5%, BD=10%, AJP=5%, RDC=10%, RM=10%, ND=10%, YY=10%, PDC=15%, TKM=4%, RKR=4%, AMV=2%, AJA=1%, FP=10%, QM=1%

## ข้อสังเกต / คำถามค้างคา
- Row 2 ของ sheet นี้ใช้ `1.08` ใน Top WS แต่ใช้ `1.06` ใน Table — ❓ ยืนยันจาก formulas ว่า Table ใช้ 1.06 จริง (ดู 03.Calculation-Logic ❓ ข้อ 3)
- Product ที่มี weight = blank (ว่าง) = Salesman นั้นไม่ได้รับผิดชอบ product นั้น
- Product weights ไม่จำเป็นต้องรวมกันได้ 100% — เป็น weight ต่อ product แยกกัน
