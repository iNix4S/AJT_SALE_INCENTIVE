# Sheet: Top WS

- **ไฟล์ต้นทาง:** MT (มีทั้ง MT และ TT ชื่อเดียวกัน)
- **ประเภท:** Master Data / Parameter / Reference
- **จำนวนแถว x คอลัมน์:** ~25 แถว x 35+ คอลัมน์

## วัตถุประสงค์ของ sheet
เป็น "หน้าหลัก" ของไฟล์ — รวม parameter สำคัญทั้งหมดไว้ในที่เดียว:
1. **Incentive Base** ตามตำแหน่ง (Depot, Area Manager, CV, Driver, WSF, WH ฯลฯ)
2. **GOAL Table** — ตาราง achievement threshold → multiplier (0.90→0.90, 0.95→0.95, 1.00→1.00, 1.03→1.03, 1.06→1.06, 1.10→1.10, 1.15→1.15, 1.20→1.20, 1.30→1.30)
3. **Product weight** แต่ละ product ต่อ group (G1/G2/G3) คิดเป็น fraction ของ base
4. **Simulation panel** — ตัวอย่างคำนวณ incentive สำหรับ test

## Input (รับข้อมูลจากไหน)
- กำหนดโดยมนุษย์ (manual input) — ปรับเมื่อมีการเปลี่ยน policy

## Output (ส่งข้อมูลไปไหน)
- ถูกอ้างอิงโดย **2) หลักการคำนวน Table** sheet สำหรับ incentive base ($H$4)
- ถูก reference โดย Target & Cal sheets ผ่าน Table

## สูตร/ตรรกะสำคัญ
| เซลล์ | สูตร | ความหมาย |
|-------|------|----------|
| J1 | `=$H$4+($H$4*J3)` | GOAL value ที่ achievement level J = base × (1 + multiplier) |
| J6 | `=H6*$J$2` | incentive amount ที่ product H6 เมื่อถึง threshold J |

### Incentive Base ตามตำแหน่ง (MT)
| ตำแหน่ง | Now | New |
|---------|-----|-----|
| Area Manager | 5,000 | 5,000 |
| Depocho | 4,000 | 4,000 |
| D.Depocho | 4,000 | 4,000 |
| CV | 2,500 | 2,500 |
| Driver | 1,200 | 1,200 |
| CVFV | — | 2,500 |
| WSF | — | 3,500 |
| WH | — | 3,500 |

### GOAL Table (Achievement → Multiplier)
| Achievement | ≥0.90 | ≥0.95 | ≥1.00 | ≥1.03 | ≥1.06 | ≥1.10 | ≥1.15 | ≥1.20 | ≥1.30 |
|-------------|-------|-------|-------|-------|-------|-------|-------|-------|-------|
| Multiplier | 0.90 | 0.95 | 1.00 | 1.03 | 1.06 | 1.10 | 1.15 | 1.20 | 1.30 |

> **Note:** Row 2 บน Top WS ระบุ `1.08` แต่ Row 3 (ใน Table sheet) ระบุ `1.06` — ❓ ยังไม่ชัดว่า row ใดถูกต้อง

### Product Group (G1/G2/G3) ตัวอย่าง
| Group | ตัวอย่าง Products | Incentive weight |
|-------|-----------------|-----------------|
| G1 (CORE) | AJINOMOTO, ROSDEE, BIRDY | 0.05 / 0.10 / 0.20 |
| G2 (GD) | AJI-PLUS, ROSDEE CUBE, ROSDEE MENU, ROSDEE NOODLE | 0.05 / 0.10 / 0.05 / 0.10 |
| G3 (BB) | YUMYUM, POWDER COFFEE, Takumi-Aji, ROSDEE MENU KKR | 0.15 / 0.10 / 0.05 / 0.05 |

## ข้อสังเกต / คำถามค้างคา
- ❓ Row 2 ของ Top WS แสดง `1.08` แต่ใน Table sheet actual row 2 = `1.06` — ตัวไหนถูก? (ดูรายละเอียดใน 03.Calculation-Logic ❓ ข้อ 3)
- มี "Simulation" panel ฝั่งขวา — ใช้ทดสอบเท่านั้น ไม่ใช่ part of calculation จริง
- "Now" vs "New" column ใน incentive base — ❓ "New" มีผลเมื่อใด? (ดู ❓ ข้อ 7 ใน Calculation-Logic)
