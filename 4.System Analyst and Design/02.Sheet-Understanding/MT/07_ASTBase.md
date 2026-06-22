# Sheet: ASTBase

- **ไฟล์ต้นทาง:** MT และ TT
- **ประเภท:** Master Data / Org Hierarchy
- **จำนวนแถว x คอลัมน์:** หลายร้อยแถว x 18 คอลัมน์

## วัตถุประสงค์ของ sheet
เก็บโครงสร้างองค์กรของฝ่ายขาย ทำหน้าที่เป็น "org chart" ในรูปแบบตาราง  
ระบุว่าแต่ละ Salesman สังกัดใคร (DirectSup) และ DirectSup สังกัด DeptMgr และ DivMgr

ใช้เป็น reference สำหรับ Cascade calculation (Staff → Sect → Dept → AD)

## Input (รับข้อมูลจากไหน)
- ข้อมูลหลัก: Update manual โดยผู้ดูแลระบบ (Guide: Monthly Step 3)
- คอลัมน์เหลือง = สูตรที่ต้อง copy เมื่อ update

## Output (ส่งข้อมูลไปไหน)
- ถูกอ้างอิงโดย **HR Rep** เพื่อดึง DirectSup (col P ของ ASTBase)
- ถูกอ้างอิงโดย **3) Target & Cal** ทุกระดับ (Staff/Sect/Dept/AD) เพื่อหา hierarchy

## สูตร/ตรรกะสำคัญ

### โครงสร้างข้อมูล

| คอลัมน์กลุ่ม | ตัวอย่าง | ความหมาย |
|-------------|---------|----------|
| A: เดือน | `December` | เดือนของข้อมูล |
| B: ปี | `2025` | ปีของข้อมูล |
| C: Area | - | พื้นที่/เขต |
| D: Depot | - | คลัง/สาขา |
| E: Salesman Code | `5490000718` | รหัส Salesman ใน BI |
| F: รหัสพนักงาน | `222209` | รหัสพนักงานใน HCM |
| G: ชื่อ-นามสกุล (Salesman) | - | ชื่อพนักงานขาย |
| H: รหัสพนักงาน (ผู้ช่วย) | - | (ถ้ามี Sales Assistant) |
| I: ชื่อ-นามสกุล (ผู้ช่วย) | - | |
| J: สถานะพนักงาน (ผู้ช่วย) | - | |
| K: ทีม | - | ชื่อทีม |
| L: ทะเบียนรถ | - | |
| M: ประเภทรถยนต์ | - | |
| N: หมายเหตุ | - | |
| O: ตรวจสอบ | - | |
| P: Salesman Code (repeat) | `5490000718` | |
| Q: DirectSupCode | `222208` | รหัส supervisor ตรง |
| R: DeptMgrCode | `222234` | รหัส Dept Manager |
| S: DivMgrCode | `0` | รหัส Division Manager (0 = ไม่มี) |

### ตัวอย่าง Hierarchy ที่เห็นในข้อมูล
```
DivMgr: 222222
  └── DeptMgr: 222234 (DivMgr=222222)
        └── DirectSup: 222208 (DeptMgr=222234)
              └── Salesman: 222209 (DirectSup=222208)
```

## ข้อสังเกต / คำถามค้างคา
- ข้อมูลบางแถว รหัสพนักงานเป็น 0 หรือ #N/A — คาดว่าเป็น placeholder/header row
- คอลัมน์ Q (DirectSupCode) คือ key ที่ใช้ใน SUMIFS ระดับ Sect
- ❓ "คอลัมน์เหลือง" หมายถึงคอลัมน์ใดบ้าง? (Q-S?) — ต้องดูไฟล์ต้นฉบับ
- ❓ กรณี Salesman ย้ายทีม กลางปี — ข้อมูลจะ reflect เดือนที่เปลี่ยนหรือเดือนปัจจุบันเท่านั้น?
