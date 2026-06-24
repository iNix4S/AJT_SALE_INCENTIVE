# Sheet: Mapping (MT เท่านั้น)

- **ไฟล์ต้นทาง:** MT เท่านั้น (TT ไม่มี sheet นี้)
- **ประเภท:** Reference / Mapping
- **จำนวนแถว x คอลัมน์:** หลายร้อยแถว x 4 คอลัมน์

## วัตถุประสงค์ของ sheet
แก้ปัญหาที่ MT มีการแบ่ง 1 บัญชีลูกค้า (BI SalesCode) ให้ Salesman หลายคนดูแล ตาม Product Group  
Sheet นี้เก็บ mapping ว่า:  
**"BI SalesCode + Product Group" → Salesman Code ที่รับผิดชอบ**

## Input (รับข้อมูลจากไหน)
- กำหนดโดยมนุษย์ (manual) ตามการจัดสรร territory ของฝ่ายขาย
- ปรับเมื่อมีการเปลี่ยน territory assignment

## Output (ส่งข้อมูลไปไหน)
- ถูกอ้างอิงโดย **3) Target & Cal_Staff** เพื่อ map ยอดขาย Actual จาก BI เข้าหา Salesman ที่ถูกต้อง

## สูตร/ตรรกะสำคัญ
| เซลล์ | สูตร | ความหมาย |
|-------|------|----------|
| C (col 3) | `=A2&B2` | สร้าง composite key = SalesCode_BI + "_" + ProductGroup |

### โครงสร้างข้อมูล

| คอลัมน์ | ตัวอย่างค่า | ความหมาย |
|---------|-----------|----------|
| A: SalesCode_BI | `1190064712` | รหัสบัญชีลูกค้าใน BI |
| B: Product Group | `AJ` | รหัส product group |
| C: Merge | `1190064712AJ` | composite key (SalesCode_BI + ProductGroup) |
| D: Salesman Code | `5490000711` | รหัส Salesman ที่รับผิดชอบ product นี้ในบัญชีนี้ |

### ตัวอย่าง: บัญชี 1190064712
| Product Group | Salesman ที่รับผิดชอบ |
|---------------|----------------------|
| AJ | 5490000711 |
| AJP | 5490000711 |
| YY | 5490000711 |
| RKR | 5490000711 |
| RDC | 5490000705 |
| RM | 5490000705 |
| ND | 5490000705 |
| RD | 5490000705 |
| BD | 5490000714 |

→ บัญชีเดียวกัน แบ่งให้ 3 Salesman ดูแล ตาม product group

## ข้อสังเกต / คำถามค้างคา
- Sheet นี้คือหัวใจสำคัญของ MT ที่ทำให้ต่างจาก TT อย่างสิ้นเชิง
- TT ไม่มี sheet นี้ เพราะ BI report ของ TT ระบุ Salesman Code ตรงอยู่แล้ว
- ❓ เมื่อมีการ reassign territory ในระหว่างปี ข้อมูลเก่าจะถูกเก็บไว้อย่างไร? (ประวัติ vs ปัจจุบัน)
- ❓ ถ้า Salesman code เปลี่ยน (ลาออก/โอน) กระทบ Mapping อย่างไร?
