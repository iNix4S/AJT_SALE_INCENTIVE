# Project Brief — AJT New Sale Incentive

> เอกสารรากฐาน (foundation document) — ไฟล์อื่นทั้งหมดใน memory-bank ต่อยอดจากไฟล์นี้
> ถ้าข้อมูลในไฟล์อื่นขัดแย้งกับที่นี่ ให้ถือไฟล์นี้เป็นหลัก

## โปรเจกต์คืออะไร

**AJT Sale Incentive System** — ระบบคำนวณ incentive (ค่าคอมมิชชั่น/เงินจูงใจการขาย) ให้พนักงานขาย
ของบริษัท AJT (อายิโนะโมะโต๊ะ) ครอบคลุม 4 ช่องทางขาย (channel):

| Channel | ชื่อเต็ม | Calc Type |
|---|---|---|
| **MT** | Modern Trade | CASCADE_4_LEVEL |
| **TT** | Traditional Trade | SINGLE_SHEET_5_LEVEL_AVG |
| **SI** | Specialty & Institutional | CASCADE_4_LEVEL |
| **LAOS** | Laos | SINGLE_SHEET |

## ขอบเขตงาน (Scope)

โปรเจกต์นี้เป็น **Demo POC → กำลังเข้าสู่ Implementation Phase**:
- Project Start (Implementation): **1-Aug-2026**
- Target Go-Live: **Oct-2026** (ประมาณ 28-Oct-2026 ตาม Implementation Plan v2.2)
- ทีมพัฒนา Implementation: 10 คน (PM 1, SA 2, BA+Doc 2, QA+Doc 1, K2+.NET+PBI Dev 1, K2 Dev 3)
- Baseline effort: ~930 Manday, 62 working days (13 สัปดาห์)
- กลยุทธ์: TT → MT ก่อน (MVP), SI/LAOS สามารถเลื่อนได้ (deferrable)

## เป้าหมายหลักของระบบ

1. คำนวณ incentive ให้พนักงานขายทุก channel ตามสูตรที่ต่างกันต่อ channel
2. รองรับการปรับปรุงกรณีพิเศษ: Prorate (พนักงานเข้า/ออก/ย้ายกลางเดือน), Special Adjustment (สินค้าขาด/สถานการณ์พิเศษ)
3. ส่งออกผลลัพธ์ให้ฝ่าย HR (For HR export) เพื่อจ่ายเงินจริง
4. รองรับการตรวจสอบ/ตรวจทาน (audit trail) และ validation gate ก่อนปิดรอบคำนวณ
5. เปิดให้ปรับ formula/master data ได้เองผ่าน UI และ REST API โดยไม่ต้องแก้โค้ด (สำหรับ channel ใหม่ในอนาคต)

## Non-Goals (สิ่งที่ไม่อยู่ในขอบเขต ณ ตอนนี้)

- ไม่ใช่ระบบจ่ายเงินจริง (payroll) — ส่งออกไฟล์ให้ HR ไปประมวลผลต่อ
- GD (Growth Driver) payout ยังไม่ตัดสินใจ route (merged หรือ separate) — บล็อกโดย DL-003
- Approval workflow ยังไม่ implement เต็มรูปแบบ (มี nav item แต่ยังไม่มี state machine)

## เอกสารอ้างอิงหลัก (แหล่งความจริง)

| เอกสาร | ตำแหน่ง |
|---|---|
| README หลักของ repo | `../README.md` |
| BRD-SRS | `../docs/00-requirements/` |
| SA Design / Calculation Logic | `../docs/01-sa-design/` |
| Implementation Plan v2.2 | `../docs/03-planning/AJT_Implementation_Plan_Aug-Oct_2026.md` |
| DB Relations (per channel) | `../docs/` (DB_Relations_MT.md, _TT.md, _SI.md, _LAOS.md) |
| API Reference | `../docs/` (API_REFERENCE.md) |
| Chat log ละเอียดรายเซสชัน | `../chat-log/` |
