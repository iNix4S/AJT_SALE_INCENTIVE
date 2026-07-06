# Progress — AJT New Sale Incentive

## ภาพรวมสถานะ (ณ 2026-07-06, อ้างอิง chat-log ถึง 2026.07.03_004)

| หมวด | สถานะ |
|---|---|
| Demo POC | ✅ เสร็จสมบูรณ์ |
| Calculation Engine (StoredProcedure) | ✅ ทุก channel (MT/TT/SI/LAOS) |
| Calculation Engine (SqlFunction) | ✅ LAOS, ✅ SI, ⏳ MT (foundation พร้อม ยังไม่ implement) |
| Calculation Engine (NCalc) | ✅ LAOS, ✅ SI, ⏳ MT (foundation พร้อม ยังไม่ implement) |
| Generic Channel Engine (Channel 5+) | ✅ ทดสอบผ่านด้วย CH5TEST |
| REST API Platform | ✅ 6/6 Definition of Done (calc/formula/master/sandbox + auth + tests) |
| Centralize DB writes → Stored Procedures | ✅ ครบทุกหน้า/service (28 SPs) |
| Web UI — Dashboard | ✅ Redesign 3 tabs + Fluent Design |
| Web UI — Data Interface (Validation Gate) | ✅ Fluent Design refresh |
| Web UI — Calculation/ForHR/Periods/Parameters/Formula | ⏳ ยังเป็น theme เดิม (ก่อน Fluent refresh) |
| ForHR Export (MT/TT/SI/LAOS) | ✅ ครบ 4 channel, 27-column sheet layout, calc flags, drill-down modal |
| Documentation (Flow Process, DB Relations, API Ref) | ✅ ครบทุก channel |
| Implementation Plan (Aug-Oct 2026) | ✅ v2.2 พร้อมทีม 10 คน, milestone ชัดเจน |
| Data Archive Strategy | 🟡 ออกแบบเสร็จ (doc) ยังไม่ implement จริง |
| Mobile Responsiveness | ⏳ ยังไม่ทดสอบ |
| Approval Workflow | 🔴 ยังไม่ implement (มีแค่ nav placeholder) |
| GD (Growth Driver) Payout | 🔴 บล็อกโดย DL-003 (ยังไม่ตัดสินใจ route) |

Legend: ✅ เสร็จ | 🟡 บางส่วน | ⏳ รอคิว (ไม่ใช่ blocker) | 🔴 บล็อก/ยังไม่เริ่ม

## สิ่งที่ใช้งานได้แล้ว (What Works)

- คำนวณ incentive ครบ 4 channel (MT/TT/SI/LAOS) ผ่าน StoredProcedure engine (default)
- Prorate (4 types: JOIN/RESIGN/TRANSFER/POSITION_CHANGE) + Special Adjustment
  (SHORTAGE/SPECIAL_SITUATION) — บันทึก + คำนวณ + แสดงผลผ่าน drill-down modal ครบทั้ง 4 channel
- Employee org profile view (`vw_employee_org_profile`) แสดง Division/Department/Section name
  ถูกต้องตาม hierarchy จริง (แก้บั๊ก employee_code vs salesman_code แล้ว)
- REST API เรียกคำนวณ/แก้ formula/master data/sandbox ได้ครบผ่าน API key + role-based auth
- Dashboard 3 มุมมอง: System Operations, Executive View (KPI/trend/top performer), Staff Lookup
- Data Interface (Validation Gate) ตรวจสอบความครบถ้วนข้อมูลก่อนอนุมัติ
- TT Formula Expression Catalog (`vw_formula_expression_active`) ครบทุก ws_type (TOP_WS/WS_SF/WS_WH)
  ทั้ง STAFF และ SUPERVISOR + เพิ่ม step ใหม่ `MANAGER_CASCADE` สำหรับ SECT_MGR/DEPT_MGR/DIV_MGR
  (แก้ผ่าน `database/ddl/55_add_missing_tt_formula_expressions.sql`, 2026-07-06)

## Known Issues / ค้างอยู่ (Outstanding Items)

| # | รายการ | ผลกระทบ | Priority |
|---|---|---|---|
| 1 | MT SqlFunction/NCalc engine ยังไม่ implement (foundation พร้อมแล้ว) | ไม่มี parity option สำหรับ MT เหมือน LAOS/SI | P2 |
| 2 | `usp_run_mt_incentive_calculation` reference `trn_tt_special_kpi_detail` ที่ยังไม่ยืนยันว่าตั้งใจ | เสี่ยง logic ผิด/orphaned code | P1 |
| 3 | `mst_fix_rate` ไม่ครบสำหรับ TT (Area Mgr, Depocho variants, WSF, WH) | คำนวณ fixed-rate position เหล่านี้อาจผิด/ไม่มี rate | P1 |
| 4 | SI Prorate data ว่างเปล่า | ยังไม่ verify ว่า SI ต้องการ prorate จริงหรือไม่ | P2 |
| 5 | หน้าอื่นนอกจาก Dashboard/DataInterface ยังไม่ได้ Fluent Design refresh | UI ไม่สม่ำเสมอ (cosmetic) | P3 |
| 6 | Mobile responsiveness ยังไม่ทดสอบ | ใช้งานบนมือถืออาจมีปัญหา | P3 |
| 7 | Approval workflow ยังไม่ implement state machine | อนุมัติจริงยังทำผ่าน manual process | P1 (ก่อน UAT) |
| 8 | Data Archive (hot/warm/cold) ออกแบบแล้วแต่ยังไม่สร้างจริง (`aud_archive_log`, SPs, SQL Agent Job) | ยังไม่มีการ archive ข้อมูลเก่าจริง — ไม่เร่งด่วนตอนข้อมูลยังน้อย | P3 |
| 9 | `vw_formula_expression_active` v2 (เพิ่ม job_function_code, 07-02) แก้ผ่าน terminal ตรง ไม่มี DDL script เก็บไว้ | เสี่ยงหายถ้า deploy DB ใหม่ / ต้อง `sp_helptext` ทุกครั้งเพื่อยืนยัน definition จริง | P2 |
| 10 | TT Manager Cascade formula (script 55) ไม่มีระดับ AD — ยังไม่ยืนยันจาก SA ว่า SP ควรมี cascade ถึง AD หรือไม่ | เอกสาร formula อาจไม่ครบถ้ามี AD cascade จริงในอนาคต | P3 |
| 11 | ไฟล์ `database/ddl/55_add_missing_tt_formula_expressions.sql` มี description ภาษาไทยที่ไม่ตรงกับ DB จริง (DB ถูก UPDATE เป็น English แล้วเพื่อแก้ mojibake) | หาก re-deploy script จากไฟล์จะได้ description ภาษาไทยที่อ่านไม่ออกอีก | P3 |

## Open Business Decisions (บล็อก Sign-off ระดับ P0)

| ID | คำถาม | บล็อกอะไร |
|---|---|---|
| DL-001 | Policy 108% ควรใช้ multiplier 1.06 (ปัจจุบัน) หรือ 1.08? | BR-003, Rule Engine tuning |
| DL-002 | Laos ถือเป็น scope ของ TT department หรือแยก out-of-scope? | Data model, output template |
| DL-003 | GD payout รวมกับ For HR (additive) หรือแยก (replace)? | BR-009 anti-double-count rule |

## Decision Log (การตัดสินใจสำคัญที่ผ่านมา เรียงเวลา)

- **2026-06-26**: เพิ่ม `mst_org_unit` table + `vw_employee_org_profile` view สำหรับแสดง
  Division/Department/Section name — พบและแก้บั๊ก employee_code ≠ salesman_code
- **2026-07-01**: ลบ SP/View เก่าที่เป็น POC testing artifacts (6 objects) — ไม่มี dependency เหลือ
- **2026-07-02**: ตัดสินใจใช้ 3-engine architecture (ไม่ replace SP เดิม แต่เพิ่มทางเลือก) โดย
  StoredProcedure ยังเป็น default เสมอเพื่อความปลอดภัย
- **2026-07-02**: ตัดสินใจสร้าง Generic Channel Engine แทนการ hardcode ทุก channel ใหม่
  (รองรับการขยายในอนาคตโดยไม่ต้องแก้โค้ด engine)
- **2026-07-03**: ตัดสินใจ centralize การเขียนข้อมูลทั้งหมดผ่าน stored procedure (ไม่ใช้ raw SQL
  จาก C#) — เพื่อรวม business rule validation ไว้ที่เดียว
- **2026-07-03**: ปรับ pre-push policy ให้ allow `database/` folder (คำขอ user โดยตรง)
- **2026-07-06**: สร้าง `memory-bank/` (universal AI context) + instruction file บังคับอัปเดตทุกจบงาน
- **2026-07-06**: พบว่า `mst_formula_expression` ของ TT ขาด seed data (WS_WH, SUPERVISOR ทุก ws_type,
  Management Cascade ทั้งกลุ่ม) — เพิ่มด้วย `database/ddl/55_add_missing_tt_formula_expressions.sql`
  พร้อม formula_step ใหม่ `MANAGER_CASCADE`; ไม่กระทบ production calculation (มี fallback ใน
  `TtNCalcEngine.cs` อยู่แล้ว) เป็นการเติม catalog ให้ใช้อ้างอิง/CRUD UI ได้ครบ
- **2026-07-06**: แก้ mojibake (ภาษาไทยอ่านไม่ออก) ใน column `description` ของ 10 formula_code
  (TT + SHARED) โดย UPDATE เป็น English-only text โดยตรงใน DB — สาเหตุคือ sqlcmd/codepage
  ของ terminal session ไม่รองรับ Thai text แม้ใช้ `N'...'` prefix

## Test Coverage Summary

- Integration tests (API): 9/9 passed (authentication, authorization, DB operations, calculation flow)
- Regression/Parity tests: LAOS (SqlFunction diff=0, NCalc diff=0 หลังแก้ rounding), SI (SqlFunction
  diff=0, NCalc diff=0)
- Test scenarios (`test-scenarios/`): TC01–TC06 PASS (TT, MT, SI, LAOS, Prorate CRUD, SpecialAdjust CRUD)
  — อ้างอิงจากช่วงก่อนหน้า (2026-06-22), ยังไม่มี TC ใหม่ครอบคลุม engine ทางเลือก/API
