# copilot_2026.06.22_002.md

## วัตถุประสงค์
ปรับหน้าจอใน src ให้สอดคล้อง test-scenarios และ UX/UI แบบ enterprise พร้อมดึง master data จาก DB ตาม process จริง

## สิ่งที่ทำ
1. ตรวจ README + chat-log ล่าสุดก่อนแก้หน้า
2. สำรองไฟล์ก่อนแก้ไว้ที่ `_backup_ui_20260622_01/`
3. ปรับ service/contract ให้ TT ใช้พารามิเตอร์จริง `@PeriodCode + @WsType`
4. เพิ่ม `PortalDataService` เพื่อดึง master/process data จาก DB
5. ปรับหน้าจอ Dashboard, Calculation, Periods, ForHR, Parameters, Approvals ให้เป็น data-driven
6. ปรับ CSS ให้รูปแบบ enterprise และใช้งานง่ายขึ้น
7. แก้ปัญหา build lock (process ค้าง) และย้าย backup ออกนอก web project

## ไฟล์หลักที่แก้
- src/AjtIncentive.Application/Interfaces/ICalculationService.cs
- src/AjtIncentive.Infrastructure/StoredProcedures/MtCalculationRunner.cs
- src/AjtIncentive.Web/Program.cs
- src/AjtIncentive.Web/Services/PortalDataService.cs (ใหม่)
- src/AjtIncentive.Web/Pages/Index.cshtml
- src/AjtIncentive.Web/Pages/Index.cshtml.cs
- src/AjtIncentive.Web/Pages/Calculation/Index.cshtml
- src/AjtIncentive.Web/Pages/Calculation/Index.cshtml.cs
- src/AjtIncentive.Web/Pages/ForHR/Index.cshtml
- src/AjtIncentive.Web/Pages/ForHR/Index.cshtml.cs (ใหม่)
- src/AjtIncentive.Web/Pages/Periods/Index.cshtml
- src/AjtIncentive.Web/Pages/Periods/Index.cshtml.cs (ใหม่)
- src/AjtIncentive.Web/Pages/Parameters/Index.cshtml
- src/AjtIncentive.Web/Pages/Parameters/Index.cshtml.cs (ใหม่)
- src/AjtIncentive.Web/Pages/Approvals/Index.cshtml
- src/AjtIncentive.Web/Pages/Approvals/Index.cshtml.cs (ใหม่)
- src/AjtIncentive.Web/wwwroot/css/site.css

## สถานะ
- `dotnet build src/AjtIncentive.slnx` ผ่าน
- `dev.ps1 -Mode run` จากผู้ใช้รันได้และเว็บ listen ที่ `http://localhost:5288`

## ประเด็นที่ยังต้องต่อยอด
- หน้า ForHR ยังเป็น preview table (ยังไม่มี export xlsx/csv)
- หน้า Parameters ยังเป็น read-only monitoring (ยังไม่มี CRUD)
- หน้า Approvals ยังเป็น run-trace (ยังไม่มี approve action)
