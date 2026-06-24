# Sheet: Actual

- **ไฟล์ต้นทาง:** MT และ TT
- **ประเภท:** Input (นำเข้าจากภายนอก)
- **จำนวนแถว x คอลัมน์:** หลายร้อยแถว (ตามจำนวน Salesman × Product Group) x 16 คอลัมน์

## วัตถุประสงค์ของ sheet
เก็บยอดขาย Actual รายเดือน ที่ download จาก BI/DWC มา paste ทุกเดือน  
เป็น source ของค่า Actual ทั้งหมดที่ใช้ใน Target & Cal

## Input (รับข้อมูลจากไหน)
- **BI / DWC (Data Warehouse Cloud)** — download report รายเดือน
- ผู้ดูแล copy-paste ข้อมูลลงมาทุกเดือน (Guide: Monthly Step 2)

## Output (ส่งข้อมูลไปไหน)
- ถูก SUMIFS/VLOOKUP โดย **Mapping** (MT) หรือ **Target & Cal** โดยตรง (TT)
- ข้อมูลไหลเข้า Target & Cal ผ่าน Mapping (MT) หรือโดยตรง (TT)

## สูตร/ตรรกะสำคัญ
ไม่มีสูตร — เป็น raw data ล้วน

### โครงสร้างข้อมูล (MT)

| คอลัมน์ | ตัวอย่างค่า | ความหมาย |
|---------|-----------|----------|
| Salesman Code | `5490000725` | รหัส Salesman จาก BI |
| Merge | `5490000725BD` | Salesman Code + Product Group (key สำหรับ lookup) |
| Salesman BI | `5490000725` | รหัส Salesman ใน BI (อาจต่างจาก Salesman Code เมื่อผ่าน Mapping) |
| Product Group | `BD` | รหัส product group (AJ, RD, BD, AJP ฯลฯ) |
| Apr–Mar | ตัวเลขยอดขาย | ยอดขายรายเดือน (April ถึง March = ปีงบประมาณ) |

> ปีงบประมาณ = April ถึง March ของปีถัดไป

### หมายเหตุความแตกต่าง MT vs TT
- **MT**: key = `Salesman Code + Product Group` (1 บัญชีมีหลาย Salesman ตาม product)
- **TT**: key = `Salesman Code + SKU` (Salesman Code ตรงกับ BI โดยตรง ไม่ต้อง Mapping)

## ข้อสังเกต / คำถามค้างคา
- ยอดขายที่ paste มาอาจมี floating point (เช่น `54158.999...`) — ปัญหานี้อาจเกิดจาก BI export format → ควรพิจารณา ROUND ใน import logic ของระบบใหม่
- ❓ BI export format เป็นอย่างไร? CSV / Excel? มี header ตรงกับที่ต้องการหรือต้องแปลงก่อน?
- ❓ ปีงบประมาณ = Apr–Mar เสมอหรือไม่? หรือปรับได้ผ่าน Period sheet?
