# AJT HR Rep -> mst_employee Before/After Report

วันที่: 2026-06-14
สภาพแวดล้อม: DEV (`AJT_SIS`)

## วัตถุประสงค์
1. โหลดข้อมูลจาก HR Rep sheet (MT/TT) เข้า `stg_hcm_employee`
2. Merge เข้า `mst_employee`
3. ยืนยันผลจน `Missing = 0` เทียบกับ sheet

## สคริปต์ที่ใช้
- Loader + Merge: `environment/scripts/load_mst_employee_from_hr_sheet.ps1`
- Completeness Check: `environment/scripts/check_mst_employee_vs_hr_sheet.ps1`

## แหล่งข้อมูลที่ใช้
- MT: `4.System Analyst and Design/01.Raw-Extracts/MT/17_HR Rep.values.csv`
- TT: `4.System Analyst and Design/01.Raw-Extracts/TT/14_HR Rep.values.csv`

## ผลก่อนโหลด (Before)
| Channel | Sheet EmpCode | DB EmpCode | Missing | Extra |
|---|---:|---:|---:|---:|
| MT | 28 | 3 | 28 | 3 |
| TT | 90 | 2 | 90 | 2 |

ตัวอย่าง Missing ก่อนโหลด:
- MT: `066048`, `222201`, `222202`, `222203`, `222204`
- TT: `000001`, `000002`, `000003`, `000004`, `000005`

## ผลหลังโหลด (After)
จากการรัน `load_mst_employee_from_hr_sheet.ps1`
- `BATCH_ID=HR_REP_20260614_174849`
- `DATA_MONTH=2027-03-01`
- `STG_LOADED_ROWS=118`

ผลเช็คหลังโหลด:
| Channel | Sheet EmpCode | DB EmpCode | Missing | Extra |
|---|---:|---:|---:|---:|
| MT | 28 | 31 | 0 | 3 |
| TT | 90 | 92 | 0 | 2 |

ตัวอย่าง Extra หลังโหลด:
- MT: `SM001`, `SP001`, `SP002`
- TT: `TT001`, `TT002`

## สรุป
- เงื่อนไขเป้าหมายสำเร็จครบ: `MISSING_MT=0` และ `MISSING_TT=0`
- ข้อมูลใน `mst_employee` ครบตาม HR Rep sheet สำหรับรหัสพนักงานแล้ว
- Extra ที่ยังอยู่เป็นข้อมูล baseline เดิมในระบบ ไม่กระทบเงื่อนไข Missing

## หมายเหตุเชิงใช้งาน
หากต้องการ strict 100% (ไม่ให้มี Extra) ต้องกำหนดนโยบายเพิ่มว่า
1. จะลบ/ปิดการใช้งาน (`is_active = 0`) รายการ Extra หรือไม่
2. จะจำกัด scope ตาม batch/data_month ใดในการ reconcile
