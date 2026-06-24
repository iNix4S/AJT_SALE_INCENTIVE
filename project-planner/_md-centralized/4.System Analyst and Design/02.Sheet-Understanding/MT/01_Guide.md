# Sheet: Guide

- **ไฟล์ต้นทาง:** MT เท่านั้น (TT ไม่มี sheet นี้)
- **ประเภท:** Reference / Documentation
- **จำนวนแถว x คอลัมน์:** ~20 แถว x 3 คอลัมน์

## วัตถุประสงค์ของ sheet
อธิบายขั้นตอนการใช้งานไฟล์ Excel ทั้งหมด แบ่งเป็น 3 ช่วง: Annually / Monthly / As-needed  
ใช้เป็น "คู่มือ" สำหรับผู้ดูแลระบบในการรู้ว่าต้อง update sheet ใด เมื่อใด

## Input (รับข้อมูลจากไหน)
- ไม่มี input — เป็น static documentation

## Output (ส่งข้อมูลไปไหน)
- ไม่มี reference จาก sheet อื่น — ใช้อ่านเป็น reference เท่านั้น

## สูตร/ตรรกะสำคัญ
ไม่มีสูตร — เป็น text ล้วน

### เนื้อหาหลักของ Guide

| ช่วง | Step | Sheet | รายละเอียด |
|------|------|-------|-----------|
| Annually | 1 | M_Month | กำหนดตาราง mapping ระหว่างเดือนยอดขายกับเดือนจ่าย Incentive แยก Variable และ Fixed |
| Monthly | 1 | Period | กำหนดเดือนที่คำนวณ incentive |
| Monthly | 2 | Actual | Download data จาก BI แล้ว copy ลง sheet |
| Monthly | 3 | ASTBase | Update org hierarchy + copy สูตร (คอลัมน์เหลือง) |
| Monthly | 4 | HR Rep | Download Personal Employment จาก HCM + copy สูตร (คอลัมน์เหลือง) |
| Monthly | 5 | For HR | กรอก Employee ID แล้ว copy สูตรทุกคอลัมน์ (ยกเว้น EmpID, Payment Method) |
| As needed | 1 | T_SectAbove | ปรับอัตราตาม Position level |
| As needed | 2 | Table | ปรับอัตราตาม Job Function |
| As needed | 3 | Target & Cal | ปรับ Sales Target ตาม business |
| As needed | 4 | Shortage | ระบุ product+month ที่มีปัญหาสินค้าขาดแคลน |
| As needed | 5 | Fix Rate | ปรับอัตราคงที่รายพนักงาน |

## ข้อสังเกต / คำถามค้างคา
- Guide นี้ระบุ "HCM" เป็นแหล่งข้อมูล HR Rep อย่างชัดเจน → ระบบปลายทางต้องรองรับการ export จาก HCM
- คำว่า "คอลัมน์เหลือง" ในไฟล์ Excel = คอลัมน์ที่มีสูตร (ไม่ใช่ค่า manual) — สำคัญสำหรับ implementation
