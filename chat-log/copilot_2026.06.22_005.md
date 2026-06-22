# copilot_2026.06.22_005.md

## วัตถุประสงค์
แก้หน้า Calculation ที่ไม่สวย/ไม่เป็นระเบียบ ให้เป็น enterprise layout ที่อ่านง่าย

## สิ่งที่ทำ
1. เขียนหน้า `Calculation/Index.cshtml` ใหม่ทั้งไฟล์เพื่อล้าง markup ที่ซ้อน/พัง
2. จัดโครงสร้างใหม่เป็น header + 4 cards + recent runs table
3. เพิ่ม CSS เฉพาะหน้า calculation สำหรับ spacing, hierarchy, card consistency
4. build ยืนยันผลหลังหยุด process ที่ lock ไฟล์

## ไฟล์ที่แก้
- src/AjtIncentive.Web/Pages/Calculation/Index.cshtml
- src/AjtIncentive.Web/wwwroot/css/site.css

## ผลลัพธ์
- `dotnet build src/AjtIncentive.slnx` ผ่าน
- หน้า Calculation แยกส่วนชัดเจนและใช้งานง่ายขึ้น
