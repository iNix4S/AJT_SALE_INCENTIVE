# copilot_2026.06.22_003.md

## วัตถุประสงค์
ปรับหน้า For HR ให้เลือก Channel + Period และส่งออกรายงานได้

## สิ่งที่ทำ
1. เพิ่มการหา calc_run ล่าสุดตาม Channel + Period
2. ปรับหน้า For HR ให้เลือก Channel และ Period แทนการกรอก Calc Run ID ด้วยมือ
3. เพิ่มปุ่ม Export CSV Report
4. เพิ่ม handler ส่งออกไฟล์ CSV จากข้อมูลที่โหลด
5. รัน build และ regression test-scenarios

## ไฟล์ที่แก้
- src/AjtIncentive.Web/Services/PortalDataService.cs
- src/AjtIncentive.Web/Pages/ForHR/Index.cshtml.cs
- src/AjtIncentive.Web/Pages/ForHR/Index.cshtml

## ผลการตรวจสอบ
- dotnet build src/AjtIncentive.slnx: ผ่าน
- dev.ps1 -Mode test-scenarios: PASS=6, WARN=0, FAIL=0

## หมายเหตุ
- รายงานปัจจุบันเป็น CSV (พร้อมใช้งาน)
- ถ้าต้องการ xlsx/PDF สามารถต่อยอดในรอบถัดไป
