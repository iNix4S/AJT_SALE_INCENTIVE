# copilot_2026.06.22_004.md

## วัตถุประสงค์
ทำให้หน้า Calculation รองรับครบ 4 Channel ตาม master data

## สิ่งที่ทำ
1. เพิ่ม service contract สำหรับรัน SI และ Laos
2. เพิ่ม implementation รัน SP แบบ period-based สำหรับ MT/SI/Laos พร้อมตรวจ SP exists
3. ปรับหน้า Calculation model เพิ่ม handler RunSi/RunLaos และ period bindings
4. ปรับหน้า Calculation UI เพิ่มการ์ด S&I และ Laos (รวมเป็น 4 Channel)
5. ปุ่ม S&I/Laos ถูก disable อัตโนมัติเมื่อ SP ยังไม่ deploy

## ไฟล์ที่แก้
- src/AjtIncentive.Application/Interfaces/ICalculationService.cs
- src/AjtIncentive.Infrastructure/StoredProcedures/MtCalculationRunner.cs
- src/AjtIncentive.Web/Pages/Calculation/Index.cshtml.cs
- src/AjtIncentive.Web/Pages/Calculation/Index.cshtml

## ผลการตรวจสอบ
- dotnet build src/AjtIncentive.slnx: ผ่าน
- dev.ps1 -Mode test-scenarios: PASS=6, WARN=0, FAIL=0

## หมายเหตุ
- ครบ 4 Channel ตาม master data แล้วในหน้า Calculation
- SI/Laos ยังรันไม่ได้ใน environment ปัจจุบันถ้า SP ไม่ deploy (UI แจ้งชัดเจน)
