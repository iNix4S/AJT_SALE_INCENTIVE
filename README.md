# AJT New Sale Incentive

เอกสารนี้ใช้กำหนดโครงสร้างโฟลเดอร์หลักของโปรเจกต์ เพื่อให้ทีมจัดเก็บไฟล์ได้ตรงตามวัตถุประสงค์เดียวกัน

> **อัปเดตล่าสุด:** 2026-06-22
> **สถานะ:** POC พัฒนาแล้ว — MT ผ่านการตรวจสอบผล For HR (FY2026-04), TT ผ่านแล้ว

---

## วัตถุประสงค์โครงการ

ลูกค้าต้องการให้ทีมพัฒนาระบบคำนวณ Incentive ของ Sales สำหรับ 2 ช่องทาง:

- **MT (Modern Trade)** — คำนวณ cascade 4 ระดับ: Staff → Sect → Dept → AD
- **TT (Traditional Trade)** — คำนวณจาก WS Type Matrix × Goal Threshold

ฐานข้อมูล: SQL Server `192.168.11.40`, DB `AJT_SALE_INCENTIVE`
Auth: `sa / P@ssw0rd` (dev environment)

---

## โครงสร้างโฟลเดอร์

```
28.AJT New Sale Incentive/
├── 1.General Documents/       เอกสารต้นฉบับจากผู้ใช้งาน (Source Documents)
├── 2.Planning/                Project Plan, Timeline, Milestone
├── 3.Estimate Manday(s)/      Effort Estimation, Role-based Manday
├── 4.System Analyst and Design/  SA งาน: BRD, Process Flow, DB Design, Raw Extracts
├── 5.Docs/                    เอกสารสรุปเชิงธุรกิจ, BRD-SRS, POC Scope
├── environment/               สคริปต์ฐานข้อมูล, DDL, Stored Procedures, Views
├── final-docs/                ไฟล์ SQL และเอกสารสรุปสำหรับใช้งานจริง
├── deliver-docs/              เอกสารส่งมอบลูกค้า (PPTX, DOCX)
└── chat-log/                  บันทึก session การทำงานของ AI Agent
```

### รายละเอียดแต่ละโฟลเดอร์

#### `1.General Documents`
เก็บเอกสารต้นฉบับจากผู้ใช้งาน ไม่แก้ไขโดยตรง

#### `2.Planning`
Project Plan, Timeline, Milestone, Risk Register, Action Plan

#### `3.Estimate Manday(s)`
ประเมิน Manday ของแต่ละ Role
- `AJT_Manday_Estimate_Template_v2.1.html` — ตาราง Manday ล่าสุด
- `AJT_Manday_Estimation_Context.md` — บริบทและ assumption

#### `4.System Analyst and Design`
- `01.Raw-Extracts/MT/` — CSV extracts จาก Excel workbook MT (formulas + values)
- `01.Raw-Extracts/TT/` — CSV extracts จาก Excel workbook TT
- `02.Sheet-Understanding/` — วิเคราะห์แต่ละ sheet
- `03.Calculation-Logic/` — สรุปตรรกะการคำนวณ
- `04.Data-Dictionary/` — Product Code Mapping
- `database design/` — DB Design document และ conceptual schema

#### `5.Docs`
- `Sales Incentive System for POC.md` — ขอบเขต POC
- `BRD-SRS_AJT-New-Sale-Incentive_Draft-v0.1_2026-06-12.md` — BRD-SRS
- `Business-Process-Design_AJT-New-Sale-Incentive_v1.0_2026-06-13.md` — Business Process
- `System-Architecture-Design_...md` — System Architecture
- `System-Flow-Design_...md` — System Flow

#### `environment`
สภาพแวดล้อมและสคริปต์ฐานข้อมูล:

```
environment/
├── database-dev.env               ค่าเชื่อมต่อ DB (dev)
├── database-dev - cds.env         ค่าเชื่อมต่อ DB (CDS network)
├── AJT_SIS_Database_Design_v1.0_2026-06-13.docx
├── generate_db_design_doc.ps1
├── ddl/                           DDL + Seed scripts
├── generated/                     Output ที่ generate อัตโนมัติ
└── scripts/                       Stored Procedures, Views, และ utility scripts
    ├── usp_run_mt_incentive_calculation.sql    ← SP หลัก MT (deployed)
    ├── create_mt_views.sql                     ← 6 MT views (deployed 2026-06-22)
    ├── reimport_mt_actuals_period1_from_staff.sql
    ├── setup_mt_product_weight_incentive_rate.sql
    ├── load_mt_target_from_target_cal_sheets.ps1
    ├── load_tt_target_from_target_cal_sheet.ps1
    ├── load_mst_employee_from_hr_sheet.ps1
    ├── load_mst_org_hierarchy_from_astbase.ps1
    └── run_tt_incentive_calculation.ps1
```

#### `final-docs`
ไฟล์ SQL และเอกสารอ้างอิงสำหรับใช้งานจริงและตรวจสอบ:

| ไฟล์ | ใช้สำหรับ |
|---|---|
| `AJT_MT_Quick_Run_And_Check.sql` | รัน + ตรวจผล MT incentive (12 steps) |
| `AJT_TT_Quick_Run_And_Check.sql` | รัน + ตรวจผล TT incentive (multi steps) |
| `AJT_TT_Incentive_Formula_Query_Template.sql` | Query template สำหรับ TT formula |
| `AJT_TT_SP_Run_And_Check_Reference.md` | Reference guide การรัน TT SP |
| `AJT_TT_Database_Test_Guide.md` | คู่มือ test TT |
| `AJT_Final-Docs_Index.md` | Index ไฟล์ทั้งหมดใน final-docs |
| `AJT_Input-Source-to-Sheet-to-DB-Mapping_MT-TT.md` | Mapping source → sheet → DB |
| `AJT_Project-Scope-Summary.md` | สรุป scope โครงการ |
| `AJT_Validation-Gate_Detailed.md` | Validation gate รายละเอียด |

#### `deliver-docs`
เอกสารส่งมอบลูกค้า:
- `1.AJT-Sale Incentive Solution.pptx`
- `AJT_Monthly_Workflow_2.pptx`
- `AJT_Sale_Incentive_Project-Scope-Summary-final.docx`

#### `chat-log`
บันทึก session การทำงานของ AI Agent รูปแบบ `{agent}_{YYYY.MM.DD}_{ลำดับ}.md`
อ่าน log ล่าสุดก่อนเริ่มงานทุกครั้ง: `chat-log/copilot_2026.06.22_001.md`

---

## Database Views ที่ deploy แล้ว

### MT Views (สร้าง 2026-06-22)
| View | ใช้สำหรับ |
|---|---|
| `vw_mt_formula_goal_threshold` | 9 goal bands |
| `vw_mt_incentive_rate` | Rate ต่อ salesman × position |
| `vw_mt_formula_product_weight` | Weight % + base rate ต่อ route × product |
| `vw_mt_formula_incentive_matrix` | Full matrix × 9 bands (long format) |
| `vw_mt_formula_catalog` | Unified formula catalog |
| `vw_mt_salesman_hierarchy` | Org hierarchy ต่อ period (range-based) |

### TT Views (มีอยู่ก่อนหน้า)
`vw_tt_formula_catalog`, `vw_tt_formula_goal_threshold`, `vw_tt_formula_incentive_matrix`,
`vw_tt_formula_ws_matrix`, `vw_tt_incentive_rate`, `vw_tt_salesman_ws_type` และอื่น ๆ

### Views อื่น (shared)
`vw_mst_mt_mapping_detail`, `vw_mt_mst_position_incentive_rate_detail`,
`vw_mst_org_hierarchy_detail`, `vw_trn_sales_actual_pivot_fiscal_month`

---

## Stored Procedures หลัก

| SP | Channel | Parameter |
|---|---|---|
| `usp_run_mt_incentive_calculation` | MT | `@PeriodId INT`, `@ApprovedBy` |
| `usp_run_tt_incentive_calculation` | TT | `@PeriodCode NVARCHAR`, `@WsType`, `@ApprovedBy` |
| `usp_check_tt_incentive_result` | TT | `@PeriodCode`, `@EmployeeListCsv`, `@ChannelCode` |
| `usp_validate_tt_26_sheets_pass_fail` | TT | — |

---

## สถานะปัจจุบัน (2026-06-22)

| Channel | Period | สถานะ | calc_run_id ล่าสุด |
|---|---|---|---|
| MT | FY2026-04 | ✅ ผ่าน — ผล For HR ตรงกับ sheet ทุก employee (±1–3 rounding) | 1019 |
| TT | FY2026-04 | ✅ ผ่าน | — |

**Periods ที่มีใน DB:** FY2026-04 ถึง FY2027-03 (period_id 1–12)

---

## การเชื่อมโยงไฟล์สำคัญ

### Database Design
- `4.System Analyst and Design/database design/DB-Design_AJT-New-Sale-Incentive_v1.0_2026-06-13.md`
- `environment/AJT_SIS_Database_Design_v1.0_2026-06-13.docx`

### ขอบเขตและ Requirement
- `5.Docs/Sales Incentive System for POC.md`
- `5.Docs/BRD-SRS_AJT-New-Sale-Incentive_Draft-v0.1_2026-06-12.md`
- `final-docs/AJT_Project-Scope-Summary.md`

### SP หลัก
- `environment/scripts/usp_run_mt_incentive_calculation.sql`
- `final-docs/AJT_MT_Quick_Run_And_Check.sql`
- `final-docs/AJT_TT_Quick_Run_And_Check.sql`

### Raw Data (อ้างอิง)
- `4.System Analyst and Design/01.Raw-Extracts/MT/` — extracts จาก Excel MT
- `4.System Analyst and Design/01.Raw-Extracts/TT/` — extracts จาก Excel TT

---

## แนวทางการใช้งาน

1. **อ่าน chat-log ล่าสุดก่อนเริ่มงานทุกครั้ง** — `chat-log/copilot_2026.06.22_001.md`
2. เก็บไฟล์ให้ตรงโฟลเดอร์ตามประเภทงาน
3. ตั้งชื่อไฟล์ให้สื่อความหมายและมีวันที่กำกับเมื่อจำเป็น
4. หากเอกสารมีหลายเวอร์ชัน ให้เพิ่มเวอร์ชันในชื่อไฟล์ เช่น `v1`, `v2`
5. ไม่ควรแก้ไขไฟล์ต้นฉบับจากผู้ใช้โดยตรง ให้ทำสำเนาก่อนใช้งาน
6. สร้าง chat-log ใหม่ทุกครั้งที่ทำงานเสร็จ session
