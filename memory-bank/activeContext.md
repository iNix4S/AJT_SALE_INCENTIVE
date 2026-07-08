# Active Context — AJT New Sale Incentive

> **ไฟล์นี้สำคัญที่สุด** — อัปเดตทุกครั้งที่จบงาน ให้สะท้อนสถานะล่าสุดเสมอ
> อ่านไฟล์นี้ก่อนเป็นอันดับแรกเมื่อเริ่มงานใหม่ (รองจาก projectbrief.md)

## สถานะล่าสุด (Last updated: 2026-07-07)

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

### เซสชันวันที่ 2026-07-07 — ปรับโครงสร้างเอกสาร Concept Presentation รอบใหญ่ + ตรวจสอบที่มา Excel

- **ปรับโครงสร้างเอกสารตาม agenda 6 หัวข้อที่ user กำหนด** (ดูภาพ screenshot ที่ user แนบ) จนได้เป็น
  9 sections สุดท้าย: (1) วัตถุประสงค์/agenda, (2) เปรียบเทียบ Excel vs DB (MT+TT), (3) **ผลลัพธ์หลัง
  เปลี่ยนตาม Job Function (section ใหม่)**, (4) SP→Formula→Master Data, (5) Prorate (TT-scoped),
  (6) Special Adjust/Shortage (TT-scoped), (7) Master Data ↔ Excel Sheet Mapping, (8) Executive
  Summary, (9) ภาคผนวก Query — ทำ 4+ รอบตามที่ user ปรับ requirement ต่อเนื่อง
- **แก้ไฟล์คู่กัน** `docs/06-presenatation/AJT_Concept_Presentation_Excel_vs_DB_Calculation_TT_MT.prompt.md`
  (สำหรับป้อน AI ทำสไลด์จริง) ให้ตรงกับโครงสร้าง .md ใหม่ทั้งหมด → 18 slides
- **พบความเชื่อมโยง TT-Shortage ของจริง**: TT product `R` (Rosdee) ↔ `mst_tt_product.mst_product_id=2`
  ↔ record จริงใน `mst_shortage_policy` (SUPPLY_SHORTAGE) — ใช้เป็นตัวอย่างจริงใน section 6 แทนการ
  fabricate ข้อมูล (ส่วน Prorate section 5 ยังไม่มี TT transaction จริง ต้องใช้ MT data + disclaimer)
- **ตรวจสอบที่มา Excel ของตาราง reconciliation MT (section 2.2, salesman 5490000718) แบบ cell-level**:
  พบว่าไฟล์ `docs/01-sa-design/raw-extracts/01.Raw-Extracts/MT/13_3)Target & Cal_Staff.values.csv`
  (คู่กับ `.formulas.csv`) มีข้อมูลตรงกับตารางในเอกสารทุกค่า — AJ=แถว4, AJP=แถว5, AMV=แถว6, AJA=แถว17
  (column D=Target, P=Actual, AZ=Incentive เดือน Apr) และสูตรจริงยืนยันว่า mechanism ที่เอกสารอธิบาย
  (Shortage override, Goal Threshold, 3-layer formula) **มีอยู่ในสูตร Excel จริง** ไม่ใช่แค่ผลลัพธ์บังเอิญตรง:
  - `A4 = VLOOKUP(C4, ASTBase!E:S, 13, FALSE)` → ตรงกับ `mst_ast_base`
  - `AB4` (%Achievement) เช็ค `Shortage!$A:$M` ก่อนเสมอ → ตรงกับ `mst_shortage_policy` override เป๊ะ
  - `AN4` ใช้ `XLOOKUP` กับ sheet **`2) หลักการคำนวน Table`** (ชื่อ sheet MT จริง ไม่ใช่ `Top WS` ของ TT)
    → column `C:K` = Goal Threshold, column `L:Z` = Product Weight (key ด้วย Team ที่ column `A`)
- **อัปเดตเอกสารตาม finding ข้างต้น**: เพิ่ม sheet name `2) หลักการคำนวน Table` เข้า section 7.1
  (goal threshold, TT/MT คนละชื่อ sheet) และเพิ่มแถวใหม่ใน 7.3 สำหรับ `mst_product_weight`
  พร้อม query ตัวอย่าง #11 (ตรวจ column จริงจาก DB แล้วว่าใช้ `ws_type`+`product_id`+`weight_percent`
  ไม่ใช่ต่อ salesman รายคน)

- **อัปเดตเอกสารตาม finding ข้างต้น**: เพิ่ม sheet name `2) หลักการคำนวน Table` เข้า section 7.1
  (goal threshold, TT/MT คนละชื่อ sheet) และเพิ่มแถวใหม่ใน 7.3 สำหรับ `mst_product_weight`
  พร้อม query ตัวอย่าง #11 (ตรวจ column จริงจาก DB แล้วว่าใช้ `ws_type`+`product_id`+`weight_percent`
  ไม่ใช่ต่อ salesman รายคน)
- **เพิ่ม Sheet Traceability เต็มรูปแบบ (section 2.2.1 ใหม่)**: ไล่ห่วงโซ่ที่มาจาก `1) For HR`
  (sheet สรุปยอดจ่ายจริงที่ HR ใช้) ย้อนกลับไปถึง `3)Target & Cal_Staff` (SUMIFS ตาม Emp Code)
  → `ASTBase`/`Shortage`/`2) หลักการคำนวน Table` — **ยืนยันตัวเลขจริงครบทั้ง 15 product** ของ
  พนักงาน 222209 (SalesmanCode 5490000718) รวม Incentive = 4,071 บาท ตรงกับคอลัมน์ `Staff`
  ใน sheet `1) For HR` เป๊ะ (พิสูจน์ด้วย `read_file` ตรงจากไฟล์ raw extract ไม่ใช่คำนวณสมมติ)
  พบด้วยว่า `1) For HR` มีกลไก `MAX(Fix Rate, SUM(Variable))` ที่ column K (การันตีขั้นต่ำ)
  ซึ่งเอกสารยังไม่เคยพูดถึงมาก่อน — บันทึกไว้ใน section 2.2.1 แล้ว
- **เพิ่ม section 2.1.1 เปรียบเทียบ Sheet Chain ระหว่าง MT vs TT**: ตรวจ TT raw extract
  (`docs/01-sa-design/raw-extracts/01.Raw-Extracts/TT/15_1) For HR.formulas.csv` และ
  `11_3)Target & Cal.formulas.csv`) พบว่า TT ใช้ **sheet เดียว** (`3)Target & Cal`, column `Team`
  ระบุ WS Type) ต่างจาก MT ที่แยก 4 sheet ตามระดับตำแหน่ง — และพบว่า **Manager Cascade ของ TT
  คำนวณอยู่ใน `1) For HR` เอง** ผ่าน `AVERAGEIFS` (ตรงกับสูตร MANAGER_CASCADE ในหัวข้อ 4.3 เป๊ะ)
  ยืนยันตัวเลข TT จริงจากไฟล์: salesman `110001`/product `A` → Target=103,090, Actual=97,380.6
  (ตรงกับตาราง section 2.3 ที่มีอยู่แล้ว) — มี 11 product ต่อ salesman คนนี้ (A,R,B,P,Y,AP,M,Q,RK,NS,T)
- **เพิ่ม section 2.1.2/2.1.3 (Sheet ↔ Table/View/SP Cross-Check)**: สำรวจ DB จริงพบ view ที่เป็น
  1:1 กับ Excel sheet `1) For HR` โดยตรง: **`vw_for_hr_mt_sheet`** และ **`vw_for_hr_tt_sheet`**
  (36 columns เหมือนกันทั้งคู่ รวม `incentive_staff`/`total_variable` ฯลฯ) — verify แล้วว่า
  `vw_for_hr_mt_sheet WHERE user_employee_id='222209' AND calc_run_id=1084` ให้ `incentive_staff
  = 4,071.00` ตรงกับ Excel เป๊ะ, และ `vw_for_hr_tt_sheet WHERE salesman_code='110001' AND
  calc_run_id=2` ให้ `incentive_staff = 3,700.00` — เพิ่มตาราง mapping ครบทุก sheet สำคัญ
  (Table/View/SP) พร้อม engine ทางเลือก (`usp_run_*_incentive_calculation_via_function`)
  **แก้ bug จากงานก่อนหน้า**: header `### 2.2 ตัวอย่างจริง — Channel MT...` หายไปจากการ
  replace_string_in_file ครั้งก่อน (ลบ header ทิ้งโดยไม่ตั้งใจ) — แก้กลับคืนแล้ว
- **แก้ข้อมูลเข้าใจผิดสำคัญ: "MT ใช้ Product Group vs TT ใช้ Product Code"** — user ตั้งข้อสังเกตว่า
  อาจเข้าใจคลาดเคลื่อน จึงตรวจสอบ `trn_sales_target.product_code` จริงในทั้ง 2 channel พบว่า:
  1. **ทั้ง MT และ TT คำนวณ Incentive หลักที่ grain `product_code` เหมือนกัน** — MT เก็บรหัสเต็มตรง
     (`AJ`,`AJP`,`BD`...) ส่วน TT เก็บเป็น short alias (`A`,`AP`,`B`...) แล้ว join ผ่าน
     `mst_tt_product.mst_product_id` กลับไปยัง `mst_product` ตัวเดียวกัน — **ไม่ใช่คนละ grain กัน**
  2. **"Product Group" ใช้เฉพาะโบนัส Growth/Special เท่านั้น** ไม่ใช่การคำนวณหลัก — MT ใช้
     `mst_gd_product` (key `product_group_code`), TT ใช้ `mst_tt_special_kpi_rule` (key
     `g_group_code` ซึ่งอยู่ใน `mst_tt_product.g_group_code` โดยตรง เช่น A→G1, AP→G2)
  3. **แก้ข้อความเดิมในเอกสาร section 2.4** ที่เขียนผิดว่า "MT=Product Group, TT=SKU(Product Code)"
     — เพิ่ม subsection ใหม่ 2.1.4 อธิบายเรื่องนี้ให้ชัดเจน พร้อมตารางเปรียบเทียบและคำเตือนเรื่อง
     cross-check query (ต้อง join ผ่าน `mst_tt_product` ก่อนเทียบกับ MT เสมอ)
- **ตรวจสอบและแก้ Job Function TT/MT (cross-check กับ Excel raw extract จริง)**:
  1. **MT `mst_job_function` name_en ไม่ตรงกับ Excel** — **แก้แล้วใน DB**: `MT_AD` (แก้จาก
     "MT Associate Director" → "MT AD"), `MT_SECT_MGR` (แก้จาก "MT Section Manager" →
     "MT Section Manager (All sections excluded Cash & Carry)"), `MT_SUPERVISOR` (แก้จาก
     "MT Supervisor" → "MT Supervisor (All sections excluded Cash & Carry)")
  2. **TT Double-Prefix Issue**: Excel `1) For HR` column G แสดง "TT Deputy TT Deputy Depot Cho
     (Top W)" (คำว่า "TT Deputy" ซ้ำ 2 ครั้ง) — ประเมินว่า data entry error ในไฟล์ Excel ต้นฉบับ
     ไม่ใช่สิ่งที่ควร mirror ใน DB — DB ถูกต้องแล้ว, ควรแจ้งทีม HR Data ให้แก้ข้อมูลพนักงาน
  3. **MT Fixed Rate = N/A**: MT ทุกคนได้ Variable เท่านั้น, `mst_fix_rate` สำหรับ MT = 0 rows
  4. **TT `mst_position_job_function_mapping` แก้ 3 issues แล้ว** (2026-07-07):
     - **P1 (Duplicate)**: ลบ 2 แถวที่ซ้ำ (SUPERVISOR/TOP_WS มี 2 mapping, STAFF/WS_SF มี 2 mapping) → เหลือ TT_DEPUTY_TOP_W และ TT_DEPUTY_SHOP_FRONT เป็น canonical
     - **P2 (Missing)**: เพิ่ม `SUPERVISOR/NULL → TT_DEPUTY` ที่ขาดหายไป
     - **P3 (Wrong)**: แก้ `STAFF/NULL` จาก `SALESMAN` → `TT_DEPUTY` ให้ตรงกับ Excel `1) For HR`
     - สุดท้าย: 9 rows, ไม่มี duplicate, ตรงกับ Excel ground truth
  5. **อัปเดต section 3 ของเอกสาร** ให้สะท้อน: MT job function table (7 rows), TT job function
     table (7 rows, ✅/⚠️), TT mapping table ใหม่ (9 rows, post-fix), note ว่า MT Fixed Rate = N/A
  6. **`mst_incentive_rate` ยังมีปัญหาเหลือ (ยังไม่แก้)**: DEPT_MGR rate_new=5,000 แต่รูปแสดง
     4,000, OLD ws_type มี rate ผิด (12,000/9,000/7,000), SUPERVISOR ไม่มีใน mst_incentive_rate
     — **รอ SA ยืนยัน rate ที่ถูกต้องก่อน**

  6. **`mst_incentive_rate` ยืนยันกับ T_SectAbove Excel แล้ว (2026-07-07)**:
     - **TT**: `ws_type`=WS Type (TOP_WS/WS_SF/WS_WH), rates ตรงกับ T_SectAbove Excel 100%
       (DIV_MGR=5,000, DEPT_MGR=5,000, SECT_MGR=4,000, AD=6,000, STAFF/TOP_WS=4,000, WS_SF/WH=3,500)
     - **MT**: `ws_type`=**salesman_code หรือ employee_code รายบุคคล** — โครงสร้างต่างจาก TT โดยสิ้นเชิง
       T_SectAbove MT เป็นเพียง reference rate ระดับตำแหน่ง ส่วน DB เก็บ rate จริงรายคน
     - DEPT_MGR rate_new=5,000 ในเอกสาร **ถูกต้อง** (ยืนยันจาก T_SectAbove image และ DB)

- **สร้าง cat-log ตามคำขอผู้ใช้แล้ว**: เพิ่มไฟล์ [chat-log/cat-log_2026.07.07_001.md](../chat-log/cat-log_2026.07.07_001.md)
  เพื่อบันทึก session traceability สำหรับคำสั่งล่าสุด "create cat-log"
- **สร้าง chat-log ของวันนี้เพิ่มแล้ว**: เพิ่มไฟล์ [chat-log/copilot_2026.07.07_001.md](../chat-log/copilot_2026.07.07_001.md)
  ตามคำขอผู้ใช้ล่าสุด "สร้าง chat-log ของวันนี้เพิ่มด้วย"
- **อัปเดต prompt file ให้ตรงกับ concept doc ล่าสุด (2026-07-07)**: แก้
  [AJT_Concept_Presentation_Excel_vs_DB_Calculation_TT_MT.prompt.md](../docs/06-presenatation/AJT_Concept_Presentation_Excel_vs_DB_Calculation_TT_MT.prompt.md)
  ให้ตรงกับ grain การคำนวณ MT/TT ที่แก้ไว้ใน .md (`product_code` เหมือนกันทั้ง 2 channel) และปรับ
  mapping slide 16-17 ให้สอดคล้องกัน
- **commit + push สำเร็จ**: `5ab1c43` (memory-bank updates เท่านั้น — chat-log ถูก pre-push policy
  บล็อกเพราะยังไม่อยู่ใน allowlist ต้องแยก commit)

### เซสชันวันที่ 2026-07-08 — สร้าง Demo Story Channel MT

- **สร้างไฟล์ใหม่** [docs/06-presenatation/AJT_MT_Demo_Story_Actual_to_ForHR.md](../docs/06-presenatation/AJT_MT_Demo_Story_Actual_to_ForHR.md)
  ตามคำขอ user ให้ทำ story demo Channel MT ตั้งแต่ Actual Data จนถึงผลคำนวณ Incentive และรายงาน
  For HR พร้อมสาธิต 2 กรณี: (1) เปลี่ยนข้อมูล Actual แล้วคำนวณใหม่ (2) เปลี่ยนตัวแปรใน Master Data/
  Formula Expression (`mst_goal_threshold.multiplier`) แล้วคำนวณใหม่ — ทั้งหมดไม่ต้องแก้โค้ด
- ใช้ baseline จริงจาก DB (`calc_run_id=1084`, พนักงาน 222209/5490000718, ผลรวม 4,071.00 ตรงกับ
  concept presentation doc เดิม) และ query จริงยืนยัน `mst_incentive_rate` (base_rate=4,000),
  `mst_product_weight` (product BD weight=0.1111), `mst_goal_threshold` (10 bands) ก่อนสร้าง
  What-if walkthrough สำหรับ Demo #1/#2 (ระบุชัดว่าเป็นตัวเลขคำนวณด้วยมือตามสูตรจริง ไม่ได้รันจริง
  ใน DB dev เพื่อความปลอดภัย — ไม่ mutate ข้อมูล dev)
- อ้างอิง REST API endpoints จริงจาก `src/AjtIncentive.Api/API_REFERENCE.md`
  (`POST /api/v1/calculation/{channel}/run`, `PUT /api/v1/masters/{table}/{id}`) เพื่อให้ script
  ใช้ demo จริงต่อหน้าทีมได้ทันที
- **เปลี่ยนแนว Demo เป็น direct DB operations ตามคำขอผู้ใช้**: แก้
  [docs/06-presenatation/AJT_MT_Demo_Story_Actual_to_ForHR.md](../docs/06-presenatation/AJT_MT_Demo_Story_Actual_to_ForHR.md)
  ให้ทุกขั้นตอนอ้างอิง SQL UPDATE + EXEC stored procedure ตรงบน database แทนการอ้างอิง API
  (ตรวจสอบ schema จริงเพิ่ม: `trn_sales_actual`, `mst_formula_expression`, `trn_calc_run`,
  signature ของ `usp_run_mt_incentive_calculation`)
- **สร้างเอกสารใหม่เฉพาะ Demo #2 แบบละเอียดมาก**:
  [docs/06-presenatation/AJT_MT_Demo2_FormulaChange_StepByStep.md](../docs/06-presenatation/AJT_MT_Demo2_FormulaChange_StepByStep.md)
  ครอบคลุม end-to-end ตั้งแต่ Formula Catalog → baseline → SQL UPDATE สูตร → re-run SP →
  compare result → ForHR output พร้อม mapping Excel sheet ↔ table/view/SP และ query ครบทุกขั้นตอน
- **สร้าง chat-log วันนี้แล้ว**: เพิ่มไฟล์ [chat-log/copilot_2026.07.08_001.md](../chat-log/copilot_2026.07.08_001.md)
  ตามคำขอล่าสุด "create chat-log"

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
   ก่อนนำเสนอจริง — ตอนนี้มี cell-level citation ของ Excel ต้นฉบับครบแล้วสำหรับ MT (section 2.2/7)
   เน้นตรวจสอบส่วน TT เป็นพิเศษ เพราะยังไม่มี exact reconciliation เทียบ Excel
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
