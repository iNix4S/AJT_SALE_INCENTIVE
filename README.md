# AJT New Sale Incentive

Repository นี้ใช้เก็บเฉพาะส่วนที่จำเป็นสำหรับการพัฒนา Demo POC บน GitHub ได้แก่ source code, project planning และ test scenarios ของระบบ AJT Sale Incentive

> อัปเดตล่าสุด: 2026-07-01
> สถานะ: **Demo POC เสร็จสมบูรณ์** — กำลังเตรียมเข้า Implementation Phase (Project Start: 1-Aug-2026, Target Go-Live: Oct 2026)

---

## ภาพรวมระบบ

AJT Sale Incentive เป็น Web Application สำหรับคำนวณ incentive ของฝ่ายขายบน SQL Server โดยรองรับงานหลักดังนี้

1. Dashboard สำหรับติดตามสถานะรอบคำนวณ
2. Calculation สำหรับ MT, TT, SI และ Laos
3. Period master management
4. For HR export preparation
5. Prorate และ Special Adjustment

เทคโนโลยีหลัก

1. .NET 10
2. ASP.NET Core Razor Pages
3. EF Core 10
4. Dapper
5. SQL Server

---

## โครงสร้าง Workspace

```text
.
├── README.md
├── docs/                      ← เอกสารทุกประเภท (AI-readable)
│   ├── 00-requirements/       ← BRD, SRS, RFP, Proposal
│   ├── 01-sa-design/          ← SA Design, Calculation Logic, Data Dictionary
│   ├── 02-technical/          ← Technical Guide, Data Archive Design
│   ├── 03-planning/           ← Implementation Plan, Estimate Manday(s)
│   │   └── estimate/
│   ├── 04-testing/            ← Test Plan, Test Results
│   └── 05-reference/          ← Notes, Diagrams, Reference Materials
├── database/                  ← DB Schema & Scripts
│   ├── ddl/                   ← DDL SQL files
│   ├── scripts/               ← Migration & utility scripts
│   └── generated/             ← Auto-generated DB docs
├── assets/                    ← ไฟล์ต้นฉบับจาก AJT (Excel, PPTX, DOCX)
│   ├── owner-documents/       ← เอกสารจาก AJT
│   ├── high-level-design/     ← HLD drafts
│   └── deliverables/          ← ไฟล์ส่งมอบ
├── memory-bank/                ← 🧠 AI Agent context (อ่านก่อนเริ่มงานทุกครั้ง)
├── chat-log/                  ← Copilot session logs (ละเอียดรายเซสชัน)
├── _archive/                  ← Backup snapshots (UI backups, old docs)
├── src/                       ← Source code (ASP.NET Core 10)
├── src_antigravity/           ← Reference / spike code
├── test-scenarios/            ← Test cases & scripts
└── dev.ps1                    ← Development helper script
```

> **GitHub Push Policy**: ปัจจุบัน push ได้เฉพาะ `src/`, `test-scenarios/`, `database/`, `README.md` — เอกสาร workspace อื่นๆ เก็บในเครื่องและ OneDrive เท่านั้น

---

## สำหรับ AI Agent: เริ่มงานที่ไหน

ก่อนเริ่มงานทุกครั้ง ให้อ่าน **[`memory-bank/`](./memory-bank/)** ก่อนเสมอ (โดยเฉพาะ
`activeContext.md` และ `progress.md`) เพื่อทราบสถานะล่าสุดของโปรเจกต์แบบสรุป
ถ้าต้องการรายละเอียดเชิงลึกของแต่ละเซสชัน ให้ดูต่อที่ [`chat-log/`](./chat-log/)

---

## โฟลเดอร์สำคัญ

### `docs/`

เอกสารทุกประเภทจัดเก็บแบบ AI-friendly ใน sub-folders ตาม lifecycle

| Folder | เนื้อหา |
|---|---|
| `docs/00-requirements/` | BRD, SRS, RFP, Proposal, System Design |
| `docs/01-sa-design/` | SA Design, Calculation Logic, Data Dictionary, Process Flow |
| `docs/02-technical/` | Technical Guide, Data Archive Design |
| `docs/03-planning/` | Implementation Plan v2.0, Estimate Manday(s) |
| `docs/04-testing/` | Test Plan, Test Results, SQL test scripts |
| `docs/05-reference/` | Notes, Canva Diagrams, Reference Materials |

### `database/`

| Folder | เนื้อหา |
|---|---|
| `database/ddl/` | DDL SQL files (48+ files) |
| `database/scripts/` | Migration & utility scripts |
| `database/generated/` | Auto-generated DB design documents |
| `database/` root | `.env` connection configs, `AJT_SIS_Database_Design_v1.0.docx` |

### `assets/`

ไฟล์ต้นฉบับจาก AJT (Excel, PPTX, PNG, DOCX) ไม่ได้แก้ไขโดย dev team

### `src/`

ดูรายละเอียดเพิ่มได้ที่ `src/README.md`

| Project | หน้าที่ |
|---|---|
| `AjtIncentive.Domain/` | Entities และ Enums |
| `AjtIncentive.Application/` | Interfaces และ Use Case contracts |
| `AjtIncentive.Infrastructure/` | EF Core, Dapper, Stored Procedure runners |
| `AjtIncentive.Web/` | Razor Pages Web Application |
| `.githooks/pre-push` | Guard สำหรับตรวจไฟล์ที่อนุญาตให้ push |

### `test-scenarios/`

ดูรายละเอียดเพิ่มได้ที่ `test-scenarios/README.md`

| TC | กรณีทดสอบ |
|---|---|
| TC01 | TT normal |
| TC02 | MT normal |
| TC03 | SI normal |
| TC04 | Laos normal |
| TC05 | Prorate mid-month |
| TC06 | Special adjustment |

---

## การตั้งค่าและการรัน

### Prerequisites

1. .NET SDK 10
2. SQL Server access ไปยังฐานข้อมูล `AJT_SALE_INCENTIVE`
3. ค่า connection string ที่ถูกต้อง

### Database connection — เลือก Server ที่ต้องการ

> **ดูรายละเอียดสมบูรณ์ได้ที่:** [`database/README.md`](database/README.md)

แอปอ่าน connection string จากลำดับนี้

1. Environment variable `DB_CONNECTION_STRING` (highest priority)
2. User secrets (`dotnet user-secrets`)
3. `src/AjtIncentive.Web/appsettings.json` (default)

#### ตัวเลือก 1️⃣ : Local Development (localhost,1437 / AJT_SIS)

```powershell
# ใช้ environment variable
$env:DB_CONNECTION_STRING = "Server=localhost,1437;Database=AJT_SIS;User Id=sa;Password=P@ssw0rd;Encrypt=True;TrustServerCertificate=True;"

# แล้วรัน
.\dev.ps1 -Mode run
```

ไฟล์ reference: [`database/database-dev.env`](database/database-dev.env)

#### ตัวเลือก 2️⃣ : CDS Dev Server (192.168.11.40 / AJT_SALE_INCENTIVE)

```powershell
# ใช้ environment variable
$env:DB_CONNECTION_STRING = "Server=192.168.11.40;Database=AJT_SALE_INCENTIVE;User Id=sa;Password=P@ssw0rd;Encrypt=True;TrustServerCertificate=True;"

# แล้วรัน
.\dev.ps1 -Mode run
```

ไฟล์ reference: [`database/database-dev - cds.env`](database/database-dev%20-%20cds.env)

### Build

```powershell
dotnet build .\src\AjtIncentive.slnx
```

### Run Web App

```powershell
dotnet run --project .\src\AjtIncentive.Web\AjtIncentive.Web.csproj
```

### Run Test Scenarios

```powershell
.\test-scenarios\run-test-scenarios.ps1
```

---

## Authentication

Web app รองรับ Microsoft Entra ID แบบ optional ที่ navbar

ถ้าต้องการเปิดใช้งาน ให้ตั้งค่า `AzureAd` ใน `src/AjtIncentive.Web/appsettings.json` หรือผ่าน secrets/environment variables ดังนี้

1. `Instance`
2. `TenantId`
3. `ClientId`
4. `ClientSecret`
5. `CallbackPath`
6. `SignedOutCallbackPath`

หากยังไม่ตั้งค่าครบ ระบบจะยังรันได้ และจะแสดงสถานะ Entra ID แบบ disabled ใน navbar

---

## สถานะฟีเจอร์สำคัญ (ณ วันที่ 2026-07-01)

### ✅ POC Complete

1. Calculation page รองรับ MT, TT, SI และ Laos
2. TT คำนวณทุก WS Type ในครั้งเดียว (SP v9 complete)
3. Dashboard แสดงภาพรวมแบบ control tower
4. Periods page รองรับ CRUD บน master data
5. Prorate และ Special Adjustment pages
6. Readiness indicator ต่อ period บนหน้า Calculation
7. For HR export (Variable + Fixed) — output พร้อมส่ง HR
8. LAOS Flow Process — เอกสารและ calculation flow เสร็จแล้ว

### ⏳ Implementation Phase (Aug–Oct 2026)

1. K2 Workflow + Smart Forms (ยังไม่ implement)
2. .NET Core API Interface สำหรับ BI/HCM integration
3. Power BI Dashboard (MVP)
4. MT Calculation Engine บน K2 SmartObject/SP (POC ใช้ Razor Pages)
5. SI Channel engine (reuse MT ~50%)
6. Production environment + Approval workflow

### 📋 เอกสารแผนโครงการ (Workspace-only ไม่ push GitHub)

| เอกสาร | สถานะ |
|---|---|
| `docs/03-planning/AJT_Implementation_Plan_Aug-Oct_2026.md` | ✅ v2.2 ready for PM review (Project Start 3-Aug, 12hr Workday, 62 วันทำการ) |
| `docs/03-planning/AJT_Implementation_Plan_Presentation.prompt.md` | ✅ อัปเดทตรงกับ v2.2 แล้ว |
| `docs/02-technical/AJT_Data_Archive_Design_And_Plan.md` | ✅ Draft for sign-off |
| `docs/03-planning/estimate/AJT_Manday_Estimate_Template_v2.1.html` | ✅ 330.5 MD baseline |
| `docs/04-testing/AJT_System_Config_Master_And_Formula.md` | ✅ 100% complete |

### 🧹 Database Cleanup (2026-07-01)

ตรวจสอบ Table/View/Stored Procedure/Function ทั้งหมดใน `AJT_SALE_INCENTIVE` (46 tables, 49 views, 17 stored procedures) และลบ POC testing artifact ที่ obsolete แล้ว:

- ลบ Stored Procedure 5 ตัว: `SP_4001_Check_TT_incentive_result`, `usp_run_adjustment_test`, `usp_update_test_result`, `usp_validate_tt_26_sheets_pass_fail`, `usp_validate_tt_database_test_suite`
- ลบ View 1 ตัว: `vw_adjustment_test_summary`
- ยืนยัน dependency ก่อนลบด้วย `sys.sql_expression_dependencies` — ไม่มี object อื่น reference มา
- ยังเหลือกลุ่ม 🟡 Possibly Obsolete ที่รอ SA ยืนยัน (GD channel tables, `out_for_hr_fixed`, `out_export_batch`) ดูรายละเอียดใน `chat-log/copilot_2026.07.01_005.md`

---

## กติกาการ Push

repo นี้มี pre-push hook ที่ `src/.githooks/pre-push` เพื่อจำกัดไฟล์ที่ push ขึ้น GitHub ได้

ปัจจุบันอนุญาต

1. `README.md`
2. ไฟล์ภายใต้ `src/`
3. ไฟล์ภายใต้ `test-scenarios/`
4. ไฟล์ภายใต้ `database/`

หาก clone repo ไปเครื่องใหม่ ให้ตั้งค่า hook path อีกครั้ง

```powershell
git config core.hooksPath src/.githooks
```

---

## เอกสารอ้างอิงใน Repo

1. `src/README.md`
2. `test-scenarios/README.md`

เอกสารเชิงวิเคราะห์และไฟล์ workspace อื่นๆ อยู่ใน `docs/`, `database/`, `assets/` — เก็บในเครื่องและ OneDrive เท่านั้น ไม่ push GitHub

---

## Project Roadmap

| Phase | ช่วงเวลา | สถานะ |
|---|---|---|
| Demo POC | May–Jun 2026 | ✅ Complete |
| SA Analysis + Documentation | Jun 2026 | ✅ Complete |
| Implementation Planning | Jul 2026 | ✅ Complete (Plan v2.0 ready) |
| **Implementation** | **Aug–Oct 2026** | ⏳ Starting 1-Aug-2026 |
| Go-Live | Oct 2026 | 🎯 Target 28-Oct-2026 |
