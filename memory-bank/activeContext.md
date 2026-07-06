# Active Context — AJT New Sale Incentive

> **ไฟล์นี้สำคัญที่สุด** — อัปเดตทุกครั้งที่จบงาน ให้สะท้อนสถานะล่าสุดเสมอ
> อ่านไฟล์นี้ก่อนเป็นอันดับแรกเมื่อเริ่มงานใหม่ (รองจาก projectbrief.md)

## สถานะล่าสุด (Last updated: 2026-07-06)

โปรเจกต์อยู่ในสถานะ **"production-ready foundation"** — Demo POC เสร็จสมบูรณ์,
Calculation engine ครบ 3-engine architecture (validated สำหรับ LAOS/SI), REST API platform
พร้อม auth/rate-limit/audit, UI เริ่ม migrate เป็น Fluent Design แล้วบางหน้า, เอกสารประกอบ
implementation ครบสำหรับทีมที่จะเริ่มงาน 1-Aug-2026

## งานที่ทำล่าสุด (2026-06-29 → 2026-07-03)

ลำดับเหตุการณ์โดยสรุป (รายละเอียดเต็มอยู่ใน `../chat-log/copilot_2026.06.29_*.md` ถึง
`copilot_2026.07.03_004.md`):

1. **06-29**: Fix ForHR TT view join, เพิ่ม calc flags (is_std_formula/has_prorate/has_special_adj),
   เพิ่ม Prorate drill-down modal + seed 4 prorate types, ต่อยอด SI channel ให้มี ForHR layout
   เต็มรูปแบบ + master data ครบ + คำนวณสำเร็จ, อัปเดต SI Flow doc v1.1
2. **06-30**: LAOS channel ยกระดับเป็น TT-style layout + Special Adjustment modal, สร้าง
   `vw_for_hr_laos_sheet`, แก้ label/description mapping ให้ตรง business rule, สร้าง LAOS Flow doc v1.0
3. **07-01**: เอกสาร System Config Master ครบ 100% จาก DB จริง, ออกแบบ Data Archive strategy
   (3-tier hot/warm/cold), สร้าง Implementation Plan v2.2 (10 คน, 62 วัน, TT→MT ก่อน),
   ลบ stored procedure/view เก่าที่ไม่ใช้แล้ว 6 ตัว (POC testing artifacts)
4. **07-02**: Dashboard redesign ครั้งใหญ่ (3 tabs: System Ops/Executive View/Staff Lookup,
   Chart.js), สร้าง `mst_position_job_function_mapping`, เอกสาร DB Relations 4 channel,
   **เริ่ม 3-engine architecture** (StoredProcedure/SqlFunction/NCalc) — LAOS ✅ parity validated,
   SI ✅ parity validated, MT foundation พร้อม (ยังไม่ implement SqlFunction/NCalc),
   **สร้าง REST API platform เต็มรูปแบบ** (`AjtIncentive.Api`) ครบ 6/6 Definition of Done
   (calculation/formula/master CRUD, sandbox, generic channel engine, integration tests 9/9 passed)
5. **07-03**: สร้าง API_REFERENCE.md, **centralize ทุก write path เป็น stored procedure**
   (28 SPs รวม: 14 master CRUD + 14 extended data mgmt สำหรับ period/formula/target/prorate/
   special-adjust/sandbox), Fluent Design refresh ที่ Dashboard + Data Interface page,
   แก้ pre-push policy ให้ allow `database/` folder, push สำเร็จ 5 commits จบที่ `5ed97ab`

## งานล่าสุดในเซสชันปัจจุบัน (2026-07-06)

- สร้าง `memory-bank/` folder นี้ขึ้นเพื่อเป็น universal context handoff สำหรับ AI agent
  (ก่อนหน้านี้มีแต่ `chat-log/` ซึ่งเป็น per-session log ไม่ใช่ living summary)
- สร้าง instruction file [.github/instructions/memory-bank.instructions.md](../.github/instructions/memory-bank.instructions.md)
  (`applyTo: "**"`) บังคับให้ agent อ่าน memory-bank ก่อนเริ่มงาน และอัปเดต
  `activeContext.md`/`progress.md` ทุกครั้งที่จบงาน
- ตรวจสอบ query `vw_formula_expression_active` ของ TT ตามคำขอ user พบว่า:
  1. View เวอร์ชันจริงใน DB มี column เพิ่ม `job_function_code`/`job_function_name_th`
     (join ผ่าน `mst_position_job_function_mapping`) ที่ **ไม่เคยถูกบันทึกเป็น DDL script** —
     มีแต่ note ใน progress.md ว่า "View Enhanced" จากเซสชัน 07-02 แต่ไม่มีไฟล์ `.sql` จริง
     (ยังไม่ได้แก้ — ดู Next Steps)
  2. `mst_formula_expression` ของ TT **มี seed data ไม่ครบ** — ขาด `WS_WH` (Warehouse),
     ขาด position `SUPERVISOR` ทุก ws_type, และไม่มี Management Cascade formula เลย
     (SECT_MGR/DEPT_MGR/DIV_MGR) ทั้งที่ SP จริงคำนวณ cascade ด้วย team-avg achievement
  3. **แก้แล้ว**: สร้าง [database/ddl/55_add_missing_tt_formula_expressions.sql](../database/ddl/55_add_missing_tt_formula_expressions.sql)
     เพิ่ม 6 rows (WS_WH ×1, SUPERVISOR ×2, MANAGER_CASCADE ×3 พร้อม formula_step ใหม่
     `MANAGER_CASCADE`) — deploy เข้า DB จริงแล้ว, verify แล้วว่า catalog TT ครบ 10 rows
     (ไม่กระทบ production calculation เพราะ `TtNCalcEngine.cs` มี fallback รองรับอยู่แล้ว)
  4. **พบ mojibake ใน column `description`** — Thai text ที่ INSERT ผ่าน `sqlcmd` (แม้ใช้ `N'...'`)
     อ่านไม่ออก (encoding ขึ้นกับ codepage ของ terminal session) — **แก้แล้ว** ด้วยการ UPDATE
     description ของ 10 formula_code (TT + SHARED) ให้เป็น English-only โดยตรงใน DB —
     **ยังไม่ได้อัปเดต description ในไฟล์ script 55 ให้ตรงกัน DB** (ดู Next Steps)

### เซสชันที่ 2 (ต่อเนื่องในวันเดียวกัน — รายละเอียดใน `../chat-log/copilot_2026.07.06_002.md`)

- **Commit + Push 2 รอบ**: (1) `f7280cb` — script 55 + README (2) `297132b` — `memory-bank/`
  ทั้งโฟลเดอร์ หลังเพิ่ม `memory-bank/` เข้า pre-push allowlist ตามคำขอ user (ดู Decision log)
- **พบ local git quirk**: เครื่องนี้มี `.git/info/exclude` (local-only, ไม่ถูก commit) block
  `database/`, `.github/`, `chat-log/` อยู่ แม้ pre-push hook จะอนุญาต `database/` แล้วก็ตาม
  — ต้องใช้ `git add -f` เสมอเมื่อจะ commit ไฟล์ใน `database/` จนกว่าจะมีการแก้ exclude นี้
  (ยังไม่ได้แก้ — เสนอ user ไว้แล้วแต่ยังไม่ได้รับคำตอบ)
- **เพิ่ม memory-bank/ เข้า push policy**: user เลือก "เพิ่ม memory-bank/ เข้า allowlist แล้ว push
  ขึ้น GitHub" — แก้ `src/.githooks/pre-push` + `README.md` แล้ว push สำเร็จ (`297132b`)
  ตรวจสอบแล้วว่าไม่มี credential หลุดใน `memory-bank/**` ก่อน push
- **เพิ่ม DB Profile ที่ 3**: สร้าง [database/database-dev - cds.37.env](../database/database-dev%20-%20cds.37.env)
  สำหรับ server `192.168.11.37` (server name จริงคือ `AJTSERVER`, database `AJT_SALE_INCENTIVE`)
  ทดสอบเชื่อมต่อสำเร็จ — ตอนนี้มี 3 DB profile local-only ใน `database/*.env` (ดู techContext.md)
- **สร้างเอกสาร Concept Presentation**: [docs/06-presenatation/AJT_Concept_Presentation_Excel_vs_DB_Calculation_TT_MT.md](../docs/06-presenatation/AJT_Concept_Presentation_Excel_vs_DB_Calculation_TT_MT.md)
  — เปรียบเทียบ Excel vs DB (พบว่า MT ตรงกับ Excel 100% ในระดับ product/พนักงาน เป็นหลักฐาน
  reconciliation), SP→Formula Expression→Master Data, หลักการ Prorate (JOIN) และ Adjust Shortage
  พร้อมตัวอย่างจริงจาก DB `192.168.11.37` — **ยังเป็น draft** รอทีม Business/Finance review
  ก่อนใช้นำเสนอจริง (เฉพาะส่วน TT ที่อ้างอิง Validation Gate/Test Scenario แทนการเทียบ Excel ตรง)

## งานถัดไป (Next Steps — เรียงตามลำดับความสำคัญที่เคยระบุไว้)

1. **แก้ไฟล์ `.git/info/exclude` (local-only) ให้ตรงกับ push policy จริง** — ตอนนี้ยัง block
   `database/`, `.github/`, `chat-log/` อยู่ ทำให้ต้อง `git add -f` ทุกครั้งที่ commit ไฟล์ใน `database/`
   (user เคยถูกถามแล้วแต่ยังไม่ได้ตอบรับ)
2. **บันทึก `vw_formula_expression_active` v2 (job_function_code) เป็น DDL script** — ตอนนี้มีแค่ใน
   DB จริง (deploy ผ่าน terminal ตรง ๆ) ไม่มีไฟล์ `.sql` ใน `database/ddl/` เสี่ยงหายถ้า deploy DB ใหม่
   ต้องรัน `sp_helptext` ดึง definition จริงมาทำเป็นสคริปต์ (ถามผู้ใช้ยืนยันก่อนว่าต้องการหรือไม่)
3. **อัปเดต `description` ในไฟล์ script 55 ให้ตรงกับ DB จริง** — เพราะเคย UPDATE ตรงที่
   DB เพื่อแก้ mojibake (10 formula_code) โดยไม่ได้แก้ในไฟล์ .sql เดิม หาก deploy DB ใหม่
   จะได้ description ที่อ่านไม่ออกอีกครั้ง
4. **ให้ Business/Finance review เอกสาร Concept Presentation** ([docs/06-presenatation/AJT_Concept_Presentation_Excel_vs_DB_Calculation_TT_MT.md](../docs/06-presenatation/AJT_Concept_Presentation_Excel_vs_DB_Calculation_TT_MT.md))
   ก่อนนำเสนอจริง — เน้นตรวจสอบส่วน TT เป็นพิเศษ เพราะยังไม่มี exact reconciliation เทียบ Excel
   เหมือน MT (ใช้ Validation Gate/Test Scenario อ้างอิงแทน)
5. **MT Engine SqlFunction/NCalc implementation + parity testing** — foundation พร้อมแล้ว
   (interface/factory/DI เหมือน LAOS/SI) แต่ยังไม่ implement ตัว engine จริงและยังไม่ parity test
6. **ตรวจสอบ `usp_run_mt_incentive_calculation` ที่ reference `trn_tt_special_kpi_detail`** —
   ยังไม่ยืนยันว่าตั้งใจหรือเป็นโค้ดตกค้าง (orphaned reference)
7. **TT Fixed Rate master data ไม่ครบ** — ยังขาด record ใน `mst_fix_rate` สำหรับตำแหน่ง
   Area Manager, Depocho variants, WSF, WH — รอ SA ยืนยัน rate จริง
8. **SI Prorate data** — ยังว่างเปล่า ต้อง verify ว่าครบถ้วนหรือไม่
9. **ขยาย Fluent Design ไปหน้าอื่น** — ตอนนี้ทำแค่ Dashboard + Data Interface, ยังเหลือ
   Calculation, ForHR, Periods, Parameters, Formula ฯลฯ
10. **Mobile responsiveness testing** — Dashboard/DataInterface ยังไม่ได้ทดสอบบน viewport เล็ก
11. **ปิด Open Business Decisions** (ดู productContext.md): DL-001 (108%→1.06 หรือ 1.08),
    DL-002 (Laos scope), DL-003 (GD payout route) — เป็น blocker ระดับ P0 ก่อนเข้า Implementation
12. **ยืนยันว่า TT Manager Cascade ไม่มีระดับ AD** — สูตรที่เพิ่งเพิ่ม (script 55) ครอบคลุมถึง
    SECT_MGR/DEPT_MGR/DIV_MGR เท่านั้น เพราะ SP ไม่พบ cascade ไปถึง AD จริง — ควรให้ SA ยืนยันอีกครั้ง

## Decision ล่าสุดที่ต้องจำ (Recent Key Decisions)

- **Push policy**: อนุญาต `database/` และ `memory-bank/` ให้ push ขึ้น GitHub ได้แล้ว (2026-07-03,
  2026-07-06 ตามลำดับ) — allowlist ปัจจุบันคือ `src/`, `test-scenarios/`, `database/`,
  `memory-bank/`, `README.md` (ดู `src/.githooks/pre-push`)
- **memory-bank/ ต้องไม่มี credential จริง** — เพราะ push ขึ้น GitHub แล้ว อ้างอิงตำแหน่ง
  ไฟล์ env แทนเสมอ 3 จำครอกจนกว่าจะเขียน/แก้ไฟล์นี้
- **Default calculation engine ต้องเป็น `StoredProcedure` เสมอ** สำหรับทุก channel แม้ว่า
  SqlFunction/NCalc จะ parity validated แล้วก็ตาม (เป็น safe fallback)
- **DB writes ทั้งหมดต้องผ่าน stored procedure** ห้ามเขียน dynamic SQL/MERGE ตรงจาก C# อีก
  (refactor เสร็จสมบูรณ์แล้ว 2026-07-03 ครอบคลุมทุกหน้า/service)
- **ชื่อ database ที่ถูกต้องคือ `AJT_SALE_INCENTIVE`** (ไม่ใช่ `AJT_SIS` ที่เคยใช้ผิดในบาง script เก่า)
- **มี 3 DB Server profiles**: `localhost,1437` (dev local, DB=`AJT_SIS`), `192.168.11.40` (CDS
  หลักที่ใช้ตลอดโปรเจกต์, DB=`AJT_SALE_INCENTIVE`), `192.168.11.37` (เพิ่ม 2026-07-06,
  server name=`AJTSERVER`, DB=`AJT_SALE_INCENTIVE`) — ไฟล์ env อยู่ที่ `database/*.env` (local-only)

## ไฟล์/พื้นที่ที่กำลังแก้ไข ณ ตอนนี้ (Active Files)

ไม่มีไฟล์ค้างแก้ไข (uncommitted) ที่จุด commit ล่าสุด — git status สะอาด (clean working tree)
ที่ commit `297132b` (`f7280cb` → `297132b`: memory-bank/ + pre-push hook + README push policy)
ตาม chat-log 07.06_002

ไฟล์ใหม่ที่ยังไม่ commit (ตั้งใจ — local-only): `database/database-dev - cds.37.env` (gitignored),
`docs/06-presenatation/AJT_Concept_Presentation_Excel_vs_DB_Calculation_TT_MT.md` (docs/ ไม่ push),
`chat-log/copilot_2026.07.06_002.md`

## ปัญหาที่เจอบ่อย (สำหรับ Agent ใหม่ — ป้องกันเสียเวลาซ้ำ)

- ต่อ SQL Server ด้วย Windows Auth (`-E`) จะ fail เสมอที่ server นี้ → ใช้ SQL Login
- ชื่อ DB บางที่เขียนผิดเป็น `AJT_SIS` ในเอกสาร/สคริปต์เก่า → DB จริงคือ `AJT_SALE_INCENTIVE`
- `employee_code` กับ `salesman_code` เป็นคนละ ID ชุด ต้อง join ผ่าน `mst_employee.salesman_code`
  ไม่ใช่ `employee_code` ตรง ๆ (ดู systemPatterns.md)
- NCalc function name ต้องเป็น PascalCase (`Round` ไม่ใช่ `ROUND`)
- **ระวัง: หลาย view/table เคยถูกแก้ตรง DB ผ่าน terminal โดยไม่บันทึกเป็น DDL script**
  (เช่น `vw_formula_expression_active` v2) — ก่อนเชื่อ column/logic จาก DDL file ให้ตรวจสอบด้วย
  `EXEC sp_helptext '<object_name>'` กับ DB จริงเสมอเมื่อสงสัยว่าไฟล์อาจไม่ sync กับของจริง
- `mst_formula_expression` เดิม seed ไม่ครบทุก channel/position/ws_type — ก่อนสรุปว่า "ไม่มีสูตร"
  ให้เช็คว่าเป็น gap ของ seed data (แก้ด้วย INSERT เพิ่ม) หรือ engine มี fallback รองรับอยู่แล้ว
  (ดู `systemPatterns.md` และ `database/ddl/55_add_missing_tt_formula_expressions.sql` เป็นตัวอย่าง)
- **`sqlcmd` บน Windows ทำ Thai text ใน column NVARCHAR เพี้ยน (mojibake) ได้ แม้จะใช้ `N'...'` prefix แล้วก็ตาม**
  — ขึ้นกับ codepage ของ terminal session ตอนนั้น แนะนำให้เก็บ description/name ที่เป็นภาษาไทยเป็น
  English แทน หรือใช้ SSMS/GUI tool แทน sqlcmd เมื่อต้อง insert ภาษาไทยจริง ๆ
