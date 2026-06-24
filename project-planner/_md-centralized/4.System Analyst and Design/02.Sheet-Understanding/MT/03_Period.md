# Sheet: Period

- **ไฟล์ต้นทาง:** MT และ TT (มีทั้งสองไฟล์)
- **ประเภท:** Parameter / Input
- **จำนวนแถว x คอลัมน์:** 2 แถว x 4 คอลัมน์

## วัตถุประสงค์ของ sheet
กำหนดเดือนปัจจุบันที่ต้องการคำนวณ incentive  
ทุก sheet ที่ต้องการรู้ว่า "เดือนนี้คือเดือนอะไร" จะอ้างอิงมาที่ sheet นี้

## Input (รับข้อมูลจากไหน)
- Manual input โดยผู้ดูแลระบบ ทำทุกเดือน (ตาม Guide: Monthly Step 1)

## Output (ส่งข้อมูลไปไหน)
- ถูกอ้างอิงโดย **3) Target & Cal_Staff** (และ Sect/Dept/AD) เพื่อเลือกคอลัมน์เดือนที่ถูกต้อง
- ถูกอ้างอิงโดย **1) For HR** สำหรับ column header เดือน

## สูตร/ตรรกะสำคัญ

### โครงสร้างข้อมูล

| คอลัมน์ | ค่าตัวอย่าง | ความหมาย |
|---------|-----------|----------|
| sales incentive ของเดือน | `46113` (Excel date serial = Dec 2025) | เดือนที่คำนวณ incentive |
| รอบการจ่าย Incentive (Variable) | `46174` (Excel date serial = Feb 2026) | วันจ่าย Variable incentive |
| รอบการจ่าย Incentive (Fixed) | `46143` (Excel date serial = Jan 2026) | วันจ่าย Fixed incentive |
| Default column | `1` | คอลัมน์ default ที่ใช้ใน XLOOKUP/INDEX |

> Excel date serial: 46113 = 1 Dec 2025, 46143 = 1 Jan 2026, 46174 = 1 Feb 2026

## ข้อสังเกต / คำถามค้างคา
- Sheet นี้เล็กมาก (1 แถวข้อมูล) แต่สำคัญมาก — เป็น single source of truth ของเดือน
- การเปลี่ยนเดือนทำโดย manual เปลี่ยนค่า date serial → ต้องระวัง human error
- ❓ "Default column" = `1` หมายความว่าอะไร? — คาดว่าใช้ใน INDEX/MATCH เพื่อเลือก column offset แต่ยังต้องยืนยัน
