# chat-log: copilot_2026.06.22_007

**วันที่:** 2026-06-22  
**Agent:** GitHub Copilot (Claude Sonnet 4.6)  
**Session Focus:** อัปเดต test scenarios ให้ตรงกับระบบจริง + push to GitHub

---

## 1. วัตถุประสงค์ของงานรอบนี้

1. ต่อจาก session 006 — Prorate + SpecialAdjust pages สร้างแล้ว, nav + CSS อัปเดตแล้ว, build ผ่านแล้ว
2. **อัปเดต test-scenarios TC01–TC06** ให้ตรงกับสถานะระบบจริง ไม่มี "skip by capability" อีกต่อไป
3. **Push ขึ้น GitHub** (commit edc4776 → branch main)

---

## 2. สรุปสิ่งที่ดำเนินการแล้ว

### Test Scenarios ที่อัปเดต

| ไฟล์ | การเปลี่ยนแปลง |
|------|----------------|
| `test-scenarios/TC03_SI_Channel_Normal.md` | Rewrite ทั้งหมด — full test พร้อม expected amounts, Web UI steps + SQL steps |
| `test-scenarios/TC04_Laos_Channel_Normal.md` | Rewrite ทั้งหมด — full test, ระบุชัดว่า SP ใช้ `@PeriodCode` ไม่ใช่ `@PeriodId` |
| `test-scenarios/TC05_Prorate_MidMonth.md` | Rewrite ทั้งหมด — Web UI steps (`/Prorate/Index`), SQL CRUD, prorate_type rules |
| `test-scenarios/TC06_Special_Adjustment.md` | Rewrite ทั้งหมด — 2 tab scenarios (SHORTAGE + SPECIAL_SITUATION), CRUD cycle |
| `test-scenarios/README.md` | System Overview สำหรับ AI Agent, Channel mapping table, Execution Evidence รวม |
| `test-scenarios/run-test-scenarios.ps1` | เพิ่ม params + `Invoke-LaosProc`, TC03/TC04 ตรวจ amounts, TC05/TC06 CRUD test |

### ผลการรัน Test Runner

```
PASS=6, WARN=0, FAIL=0
TC01 PASS  TT, calc_run_id=2, rows=24, STAFF-only
TC02 PASS  MT, calc_run_id=1034, rows=27, 4 levels, presetMismatch=0
TC03 PASS  SI, calc_run_id=1035, rows=3, amtMismatch=0
TC04 PASS  Laos, calc_run_id=1033, rows=5, amtMismatch=0
TC05 PASS  trn_prorate_adjustment CRUD OK (factor=0.5)
TC06 PASS  trn_special_adjustment CRUD OK (shortage+special inserted+deleted)
```

### GitHub Push

- **commit:** `edc4776`
- **branch:** `main`
- **repo:** `iNix4S/AJT_SALE_INCENTIVE`

---

## 3. ไฟล์ที่เกี่ยวข้องหรือถูกแก้ไข

```
test-scenarios/
  README.md                          ← อัปเดต system overview + status table
  TC03_SI_Channel_Normal.md          ← rewrite
  TC04_Laos_Channel_Normal.md        ← rewrite
  TC05_Prorate_MidMonth.md           ← rewrite
  TC06_Special_Adjustment.md         ← rewrite
  run-test-scenarios.ps1             ← อัปเดต TC03-TC06 logic

(ไฟล์ที่ commit ใน session 006 ด้วย)
src/AjtIncentive.Web/Pages/Prorate/Index.cshtml
src/AjtIncentive.Web/Pages/Prorate/Index.cshtml.cs
src/AjtIncentive.Web/Pages/SpecialAdjust/Index.cshtml
src/AjtIncentive.Web/Pages/SpecialAdjust/Index.cshtml.cs
src/AjtIncentive.Web/Pages/Shared/_Layout.cshtml     ← Adjustments dropdown
src/AjtIncentive.Web/wwwroot/css/site.css            ← adj-* CSS classes
environment/scripts/usp_run_si_incentive_calculation.sql
environment/scripts/usp_run_laos_incentive_calculation.sql
environment/scripts/setup_si_channel_full.sql
environment/scripts/setup_laos_channel_full.sql
environment/ddl/40_create_prorate_and_special_adjustment_tables.sql
```

---

## 4. ปัญหาที่พบและวิธีแก้

| ปัญหา | วิธีแก้ |
|-------|---------|
| TC03 เดิมใช้ `Invoke-IncentiveProcedure` กับ S&I แต่ duplicate code หลัง replace | ใช้ `replace_string_in_file` แบบ big block แทน TC03–TC06 ทั้งหมดพร้อมกัน |
| TC04 เดิม runner ส่ง `@PeriodId` ให้ Laos SP แต่ SP รับ `@PeriodCode` (string) | เพิ่ม `Invoke-LaosProc` function แยก (เหมือน `Invoke-TtProcedureByCode`) |
| โค้ดเก่า TC06 (`dbo.incentive_adjustments`) ค้างอยู่หลัง replace | ลบ orphan block ด้วย replace ครั้งเพิ่มเติม |

---

## 5. สถานะปัจจุบัน (ณ สิ้นสุด session นี้)

| Component | สถานะ |
|-----------|-------|
| Web App (build) | ✅ build success |
| Nav Adjustments dropdown | ✅ มี Prorate Logic + Special Adjustment |
| `/Prorate/Index` | ✅ สร้างแล้ว — MERGE upsert, DELETE, Filter |
| `/SpecialAdjust/Index` | ✅ สร้างแล้ว — 2 tabs (SHORTAGE + SPECIAL_SITUATION) |
| `trn_prorate_adjustment` | ✅ deploy แล้วใน DB |
| `trn_special_adjustment` | ✅ deploy แล้วใน DB |
| `usp_run_si_incentive_calculation` | ✅ deploy แล้ว (SI001=10,290 / SI002=10,425 / SI003=9,412.50) |
| `usp_run_laos_incentive_calculation` | ✅ deploy แล้ว (LA001=7,680 / LA002=7,920 / LA003=6,058.80 / LAM01=9,560 / LAD01=8,497.78) |
| Test scenarios TC01–TC06 | ✅ PASS=6 (full execution, ไม่มี skip) |
| GitHub | ✅ commit edc4776 → main |

---

## 6. Database Quick Reference

- **Server:** 192.168.11.40
- **DB:** AJT_SALE_INCENTIVE
- **User/Pass:** sa / P@ssw0rd

| channel_id | channel_code | SP | Parameters |
|---|---|---|---|
| 1 | MT | `usp_run_mt_incentive_calculation` | `@PeriodId INT, @ApprovedBy` |
| 2 | TT | `usp_run_tt_incentive_calculation` | `@PeriodCode NVARCHAR(20), @WsType, @ApprovedBy` |
| 3 | SI | `usp_run_si_incentive_calculation` | `@PeriodId INT, @ApprovedBy` |
| 4 | LAOS | `usp_run_laos_incentive_calculation` | `@PeriodCode NVARCHAR(20), @WsType, @ApprovedBy` |

**Period ทดสอบ:** period_id=1, period_code='FY2026-04', sales_month=2026-04-01

---

## 7. งานที่ยังค้าง / สิ่งที่ Agent คนต่อไปควรรู้

### ยังไม่ได้ทำ

1. **Prorate factor ยังไม่ส่งผลต่อการคำนวณ SP** — ปัจจุบัน `trn_prorate_adjustment` บันทึก factor ได้แต่ SP ยังไม่ JOIN ตารางนี้ เมื่อต้องการให้ prorate กระทบผล incentive ต้องแก้ SP แต่ละ channel
2. **Special Adjustment ยังไม่ส่งผลต่อการคำนวณ SP** — `trn_special_adjustment` บันทึกได้แต่ SP ยังไม่ LEFT JOIN ตารางนี้ใน CTE
3. **Web App ยังไม่ได้รัน** (dev.ps1 exit code 1 จาก terminal ก่อน) — ควร run และทดสอบ UI จริงด้วยมือ
4. **Approvals page** — ยังไม่มีเนื้อหาจริง
5. **For HR page** — export to Excel ยังไม่ได้ทำ

### ข้อควรระวังสำหรับ Agent คนต่อไป

- Laos SP ใช้ `@PeriodCode` (string) ไม่ใช่ `@PeriodId` — ต่างจาก MT/SI ที่ใช้ `@PeriodId`
- Prorate Web UI ใช้ MERGE upsert — unique on `(period_id, channel_id, employee_code)` 
- SpecialAdjust ไม่มี unique constraint — INSERT ซ้ำได้
- `mst_position_level` ใช้ column `position_code` ไม่ใช่ `position_level_code`
- `mst_product_weight` ไม่มี column `product_code` ตรง — ต้อง JOIN กับ `mst_product`

---

## 8. ขั้นตอนถัดไป (สำหรับ Agent คนต่อไป)

1. รัน `.\dev.ps1 -Mode run` และทดสอบหน้า `/Prorate/Index` + `/SpecialAdjust/Index` จริง
2. แก้ SP (MT/TT/SI/Laos) ให้ JOIN `trn_prorate_adjustment` เพื่อปรับ total_variable ตาม factor
3. แก้ SP ให้ LEFT JOIN `trn_special_adjustment` เพื่อ override achievement/target/weight
4. ทำ export For HR (Excel) จากหน้า `/ForHR/Index`
5. ทำหน้า Approvals ให้สมบูรณ์
