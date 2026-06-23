# Implementation Plan — Data Interface & Validation Gate
# หน้าตรวจสอบคุณภาพข้อมูลก่อนคำนวณ (BI/DWH + HR)

**วันที่จัดทำ:** 2026-06-23  
**เวอร์ชัน:** v1.0  
**สถานะ:** Draft — Ready for Review  
**อ้างอิง:** AJT_Validation-Gate_Detailed.md, stg_bi_sales, stg_hcm_employee

---

## 1. บริบทและที่มา

Validation Gate คือด่านคุณภาพข้อมูลบังคับ **ก่อน** คำนวณ Incentive ทุกช่อง  
ระบบรับข้อมูลจาก 2 ต้นทาง:

| แหล่งข้อมูล | Staging Table | ปลายทาง | ใครรับผิดชอบ |
|---|---|---|---|
| BI / DWH Sales | `stg_bi_sales` | `trn_sales_actual` | Data Admin |
| HR / HCM Employee | `stg_hcm_employee` | `mst_employee` | HR Team / Data Admin |

**ปัญหาเดิม:** ปัจจุบันยังไม่มีหน้าจอ UI ให้ Admin ตรวจสอบสถานะข้อมูลก่อนกด Calculate  
Admin ต้องดูผ่าน SQL โดยตรง → เสี่ยงคำนวณผิดโดยไม่รู้ตัว

---

## 2. เป้าหมายหน้าจอ (Objective)

1. แสดงสถานะข้อมูลล่าสุดใน staging tables ต่อ period
2. รัน Validation Gate 4 checks และแสดงผล pass/fail พร้อม detail
3. แสดง error รายแถวที่แก้ไขได้ (row-level actionable errors)
4. เปิดใช้งาน "Proceed to Calculation" ก็ต่อเมื่อ **ผ่านครบทุก check**

---

## 3. Page Structure

```
/DataInterface/Index    ← หน้าหลัก (single page, period-scoped)
```

> **ทำไมไม่แยกหน้า BI / HR:**
> POC ใช้หน้าเดียวเพียงพอ เพราะ workflow คือ import → validate → proceed ไปในทิศทางเดียว

---

## 4. UI Screen Design (Wireframe)

### 4.1 Hero Section

```
╔══════════════════════════════════════════════════════════════════════╗
║  Data Interface & Validation Gate                                    ║
║  Verify imported data quality before running incentive calculations  ║
║                                                                      ║
║  [BI Sales: 1,234 rows]  [HR Employees: 89 rows]  [Last Run: Today] ║
╚══════════════════════════════════════════════════════════════════════╝
```

KPI Chips (3 ชิ้น):
- `BI Sales` → COUNT(*) FROM stg_bi_sales WHERE data_month = period.sales_month  
- `HR Employees` → COUNT(*) FROM stg_hcm_employee WHERE data_month = period.sales_month  
- `Last Validation Run` → เวลา validation ล่าสุดของ period นี้

---

### 4.2 Main Two-Column Layout

```
┌────────────────────────────┐  ┌─────────────────────────────────────┐
│  LEFT CARD (col-xl-5)      │  │  RIGHT CARD (col-xl-7)              │
│  Controls                  │  │  Validation Status Guide             │
│  ─────────────────────     │  │                                     │
│  Period:                   │  │  ┌─────────────────────────────┐    │
│  [FY2026-05 ▼]             │  │  │ ① Period Alignment   [PASS] │    │
│                             │  │  │   Sales & HR data match     │    │
│  ─────────────────────     │  │  │   period: FY2026-05         │    │
│  [🔍 Run Validation Gate]  │  │  └─────────────────────────────┘    │
│  [👁 Preview Staging Data] │  │                                     │
│                             │  │  ┌─────────────────────────────┐    │
│  ─────────────────────     │  │  │ ② Required Fields   [FAIL]  │    │
│  Overall Status:            │  │  │   12 rows missing fields     │    │
│  ┌───────────────────┐     │  │  │   in stg_bi_sales            │    │
│  │ ❌  1 CHECK FAILED │     │  │  └─────────────────────────────┘    │
│  └───────────────────┘     │  │                                     │
│                             │  │  ┌─────────────────────────────┐    │
│  (หลังผ่านทุก check):      │  │  │ ③ Hierarchy Consistency[PASS]│    │
│  [▶ Proceed to Calculation] │  │  │   89 employees mapped OK    │    │
│  (disabled เมื่อมี FAIL)   │  │  └─────────────────────────────┘    │
│                             │  │                                     │
│                             │  │  ┌─────────────────────────────┐    │
│                             │  │  │ ④ Mapping (MT)      [PASS] │    │
│                             │  │  │   All BI codes resolved     │    │
│                             │  │  └─────────────────────────────┘    │
└────────────────────────────┘  └─────────────────────────────────────┘
```

---

### 4.3 Data Status Sections (ด้านล่าง)

#### Section A: BI Sales Import Status

```
╔══════════════════════════════════════════════════════════════════════╗
║  BI Sales Import Status  │  Period: FY2026-05  │  Batch: 20260623   ║
╟──────────────────────────────────────────────────────────────────────╢
║  Total: 1,234 rows  │  ✅ Valid: 1,222  │  ❌ Invalid: 12  │  ⏳ 0   ║
╟──────────────────────────────────────────────────────────────────────╢
║  Error Details (12 rows):                                            ║
║  ┌──────┬──────────┬───────────────┬────────────────────────────┐   ║
║  │ Row# │ Channel  │ BI Sales Code │ Error                      │   ║
║  ├──────┼──────────┼───────────────┼────────────────────────────┤   ║
║  │  42  │ MT       │ BSMT0042      │ product_code is NULL       │   ║
║  │  87  │ TT       │               │ bi_sales_code is empty     │   ║
║  │ ...  │ ...      │ ...           │ ...                        │   ║
║  └──────┴──────────┴───────────────┴────────────────────────────┘   ║
╚══════════════════════════════════════════════════════════════════════╝
```

#### Section B: HR Employee Import Status

```
╔══════════════════════════════════════════════════════════════════════╗
║  HR Employee Import Status  │  Period: FY2026-05  │  Batch: 20260623║
╟──────────────────────────────────────────────────────────────────────╢
║  Total: 89 rows  │  ✅ Valid: 89  │  ❌ Invalid: 0  (All Clear)     ║
╚══════════════════════════════════════════════════════════════════════╝
```

---

### 4.4 Check Status Card — 3 States

| State | Icon | Background | Border | ใช้เมื่อ |
|---|---|---|---|---|
| **PASS** | ✅ | `#f0fdf4` (green-50) | `#16a34a` | ผ่านทุกรายการ |
| **FAIL** | ❌ | `#fef2f2` (red-50) | `#dc2626` | มีรายการไม่ผ่านอย่างน้อย 1 |
| **PENDING** | ⏳ | `#f8fafc` (slate-50) | `#94a3b8` | ยังไม่ได้รัน validation |

---

### 4.5 Action Buttons

| Button | Style | เงื่อนไข |
|---|---|---|
| **Run Validation Gate** | `btn-primary` หรือ `btn-danger` + icon 🔍 | เปิดเสมอ |
| **Preview Staging Data** | `btn-outline-secondary` | เปิดเสมอ (แสดง raw stg rows) |
| **Proceed to Calculation** | `btn-success` (disabled เป็น default) | เปิดเฉพาะเมื่อผ่าน **ทุก check** |

"Proceed to Calculation" → redirect ไปหน้า `/Calculation` Overview  
(ไม่ redirect ตรงไป channel ใดช่อง เพราะ validation ครอบคลุมทุก channel)

---

## 5. Validation Checks รายละเอียด (4 Groups)

### Check 1: Period Alignment

**คำถาม:** ข้อมูลที่ import เข้ามาตรงกับ period ที่เลือกไหม?

| Sub-check | SQL Logic | Error Code |
|---|---|---|
| stg_bi_sales.data_month = period.sales_month | COUNT rows for period | `PERIOD_MISMATCH_BI` |
| stg_hcm_employee.data_month = period.sales_month | COUNT rows for period | `PERIOD_MISMATCH_HR` |
| มี rows อยู่ใน stg สำหรับ period นี้ | COUNT > 0 | `NO_DATA_FOR_PERIOD` |

**Pass condition:** มีข้อมูลของ period นี้ทั้ง BI และ HR

---

### Check 2: Required Fields Completeness

**คำถาม:** ฟิลด์สำคัญของทุก row ไม่เป็น NULL/Empty?

| Source | ฟิลด์ที่ตรวจ | Error Code |
|---|---|---|
| stg_bi_sales | channel_code, bi_sales_code OR salesman_code, product_code, actual_amount | `MISSING_REQUIRED_FIELD_BI` |
| stg_hcm_employee | employee_code, channel_code, job_function_code, employment_status | `MISSING_REQUIRED_FIELD_HR` |

**Pass condition:** ไม่มี row ใดใน stg ที่มี status = 'ERROR' เนื่องจาก required fields

---

### Check 3: Hierarchy Consistency

**คำถาม:** employee ใน stg_hcm_employee สามารถ resolve ไปหา record ใน mst_org_hierarchy สำหรับ period นี้ได้ไหม?

| Sub-check | ตรวจอะไร | Error Code |
|---|---|---|
| Employee-Hierarchy link | employee_code ใน stg_hcm มี row ใน mst_org_hierarchy ของ period นี้ | `HIERARCHY_GAP` |
| Manager chain | ไม่มี salesman_code ที่ขาด direct_sup_code | `HIERARCHY_CHAIN_BROKEN` |
| Duplicate key | ไม่มี (channel + period + salesman_code) ซ้ำกัน | `DUPLICATE_BUSINESS_KEY` |

**Pass condition:** ทุก employee active ใน stg มี hierarchy row และ chain ไม่ขาดตอน

---

### Check 4: Mapping Completeness (MT-Critical)

**คำถาม:** แถว MT ใน stg_bi_sales สามารถ resolve bi_sales_code ไปหา salesman_code ผ่าน mst_salesman_mapping ได้ครบไหม?

| Sub-check | ตรวจอะไร | Error Code |
|---|---|---|
| MT Salesman Mapping | bi_sales_code + product_group ใน stg_bi_sales (channel=MT) ต้องมี mapping | `MAPPING_INCOMPLETE_MT` |
| Mapping effective_month | mapping ต้องตรงกับ period.sales_month | `MAPPING_EXPIRED` |

**Pass condition:** ทุกแถว MT resolve ได้ (TT/SI/LAOS ผ่าน check นี้ auto เพราะไม่ใช้ bi_sales_code mapping)

---

## 6. Component Architecture

### 6.1 Layer Overview

```
Web (Razor Pages)
    └── /DataInterface/Index.cshtml + .cs
         └── IDataInterfaceService
              └── DataInterfaceService  (Dapper)
                   └── SQL SPs + Views
```

---

### 6.2 Database Layer (สิ่งที่ต้องสร้างใหม่)

#### Table: `trn_validation_run`

```sql
CREATE TABLE dbo.trn_validation_run (
    validation_run_id   INT IDENTITY(1,1) NOT NULL,
    period_id           INT NOT NULL,
    run_at              DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    run_by              NVARCHAR(100) NOT NULL,
    overall_status      NVARCHAR(20) NOT NULL,  -- PASS | FAIL | PENDING
    check1_status       NVARCHAR(20) NOT NULL,  -- PASS | FAIL
    check1_detail       NVARCHAR(MAX) NULL,
    check2_status       NVARCHAR(20) NOT NULL,
    check2_detail       NVARCHAR(MAX) NULL,
    check3_status       NVARCHAR(20) NOT NULL,
    check3_detail       NVARCHAR(MAX) NULL,
    check4_status       NVARCHAR(20) NOT NULL,
    check4_detail       NVARCHAR(MAX) NULL,
    bi_total_rows       INT NULL,
    bi_valid_rows       INT NULL,
    bi_invalid_rows     INT NULL,
    hr_total_rows       INT NULL,
    hr_valid_rows       INT NULL,
    hr_invalid_rows     INT NULL,
    CONSTRAINT PK_trn_validation_run PRIMARY KEY (validation_run_id),
    CONSTRAINT FK_valrun_period FOREIGN KEY (period_id) REFERENCES dbo.mst_period(period_id)
);
```

#### SP: `usp_run_validation_gate`

```sql
-- Input:  @PeriodCode NVARCHAR(20), @RunBy NVARCHAR(100)
-- Output: Result Set 1 — overall summary (1 row)
--         Result Set 2 — BI Sales error rows
--         Result Set 3 — HR Employee error rows
--         Result Set 4 — Hierarchy gap rows
--         Result Set 5 — MT Mapping gaps
```

ตัว SP จะ:
1. ดึง period_id จาก @PeriodCode
2. รัน 4 checks ทีละตัว
3. INSERT ผลลัพธ์ลง trn_validation_run
4. Return ชุด result sets สำหรับ UI แสดงผล

---

### 6.3 Application Layer (สิ่งที่ต้องสร้างใหม่)

#### Models

```csharp
// src/AjtIncentive.Application/Models/DataInterface/
public record ValidationCheckResult(
    int CheckNo,
    string CheckName,
    string Status,          // PASS | FAIL | PENDING
    int TotalRows,
    int FailedRows,
    string? ErrorSummary
);

public record StagingDataStatus(
    string Source,          // BI | HR
    int TotalRows,
    int ValidRows,
    int InvalidRows,
    DateTime? LastImportDate,
    string? LatestBatchId
);

public record ValidationRunResult(
    int? ValidationRunId,
    string OverallStatus,
    List<ValidationCheckResult> Checks,
    StagingDataStatus BiStatus,
    StagingDataStatus HrStatus,
    List<StagingErrorRow> BiErrors,
    List<StagingErrorRow> HrErrors
);

public record StagingErrorRow(
    int RawRowNo,
    string ChannelCode,
    string? BusinessKey,
    string ErrorCode,
    string ErrorMessage
);
```

#### Interface

```csharp
// src/AjtIncentive.Application/Interfaces/IDataInterfaceService.cs
public interface IDataInterfaceService
{
    Task<ValidationRunResult> GetCurrentStatusAsync(int periodId);
    Task<ValidationRunResult> RunValidationGateAsync(int periodId, string runBy);
    Task<IReadOnlyList<ValidationRun>> GetRecentValidationRunsAsync(int periodId, int top = 5);
}
```

#### Implementation

```csharp
// src/AjtIncentive.Infrastructure/Services/DataInterfaceService.cs
public class DataInterfaceService : IDataInterfaceService
{
    // ใช้ Dapper เรียก usp_run_validation_gate
    // Multi-result-set pattern (GridReader) เหมือนที่ใช้ใน PortalDataService
}
```

---

### 6.4 Web Layer (สิ่งที่ต้องสร้างใหม่)

#### Page

```
src/AjtIncentive.Web/Pages/DataInterface/Index.cshtml
src/AjtIncentive.Web/Pages/DataInterface/Index.cshtml.cs
```

#### PageModel Key Properties

```csharp
public class IndexModel : PageModel
{
    [BindProperty(SupportsGet = true)]
    public int PeriodId { get; set; }
    
    public bool ShowValidation { get; set; }
    
    public IReadOnlyList<PeriodOption> Periods { get; set; }
    public ValidationRunResult? ValidationResult { get; set; }
    public IReadOnlyList<ValidationRun> RecentRuns { get; set; }
    
    public async Task OnGetAsync() { ... }
    public async Task<IActionResult> OnPostRunValidationAsync() { ... }
    public IActionResult OnPostProceedAsync() { ... }
}
```

#### Navigation (ใน `_Layout.cshtml`)

เพิ่ม menu item ใหม่:

```html
<li class="nav-item">
    <a class="nav-link" asp-page="/DataInterface/Index">
        <i class="bi bi-shield-check"></i> Validation Gate
    </a>
</li>
```

หรือเพิ่มเป็น sub-menu ถ้า navbar มี dropdown

---

## 7. Implementation Phases

### Phase 1: Database (1 วัน)
- [ ] DDL: `trn_validation_run` table (file: `38_create_trn_validation_run.sql`)
- [ ] SP: `usp_run_validation_gate` — orchestrator 4 checks (file: `39_create_proc_usp_run_validation_gate.sql`)
- [ ] SP: `usp_get_validation_gate_status` — ดึงสถานะล่าสุดโดยไม่รัน (file: `40_create_proc_usp_get_validation_gate_status.sql`)
- [ ] Test: รัน SP ผ่าน SSMS กับ FY2026-05

### Phase 2: Application Layer (0.5 วัน)
- [ ] Models: `ValidationCheckResult`, `StagingDataStatus`, `ValidationRunResult`, `StagingErrorRow`
- [ ] Interface: `IDataInterfaceService`
- [ ] Implementation: `DataInterfaceService` (Dapper, GridReader pattern)
- [ ] Register DI ใน `Program.cs`

### Phase 3: Web — UI (1 วัน)
- [ ] Page: `DataInterface/Index.cshtml` + `.cs`
- [ ] Hero section + KPI chips
- [ ] Two-column layout (Controls + Validation Status Guide)
- [ ] BI Sales error table section
- [ ] HR Employee status section
- [ ] "Proceed to Calculation" button (disabled logic)
- [ ] Recent validation runs section

### Phase 4: Navigation & Integration (0.5 วัน)
- [ ] เพิ่ม "Validation Gate" ใน navbar (`_Layout.cshtml`)
- [ ] Calculation pages: เพิ่ม warning badge ถ้า latest validation ของ period นั้น FAIL
  - ดึง `latest_validation_status` ใน `LoadAsync()` ผ่าน `IDataInterfaceService`
  - แสดง `<div class="alert alert-warning">Validation Gate not passed for this period</div>`

---

## 8. CSS/Styling — Design System Reference

ใช้ pattern เดียวกับ MT/TT/SI/LAOS Calculation pages:

```css
/* ใช้ class ที่มีอยู่แล้วใน site.css */
.mt-modern-hero      /* Hero section */
.mt-modern-card      /* Cards */
.mt-fade-in          /* Fade animation */
.mt-controls-shell   /* Controls container */
.mt-control-block    /* Each control group */
.mt-actions-row      /* Button row */
.mt-btn-preview      /* Secondary action */
.mt-btn-run          /* Primary action (btn-danger) */

/* เพิ่มใหม่เฉพาะ Validation Gate */
.vg-check-card       /* Check status card */
.vg-check-card--pass /* Green border */
.vg-check-card--fail /* Red border */
.vg-check-card--pending /* Gray border */
.vg-status-badge     /* PASS/FAIL/PENDING badge */
.vg-error-table      /* Compact error rows table */
```

---

## 9. ตัวอย่าง Check Card HTML

```html
<!-- Check 1: PASS -->
<div class="vg-check-card vg-check-card--pass">
    <div class="vg-check-card__header">
        <span class="vg-check-number">①</span>
        <span class="vg-check-name">Period Alignment</span>
        <span class="vg-status-badge vg-status-badge--pass">✅ PASS</span>
    </div>
    <div class="vg-check-card__body">
        <small class="text-muted">Sales & HR data match FY2026-05</small>
        <div class="mt-1">
            <span class="badge bg-success">BI 1,234 rows</span>
            <span class="badge bg-success">HR 89 rows</span>
        </div>
    </div>
</div>

<!-- Check 2: FAIL -->
<div class="vg-check-card vg-check-card--fail">
    <div class="vg-check-card__header">
        <span class="vg-check-number">②</span>
        <span class="vg-check-name">Required Fields Completeness</span>
        <span class="vg-status-badge vg-status-badge--fail">❌ FAIL</span>
    </div>
    <div class="vg-check-card__body">
        <small class="text-danger fw-bold">12 rows missing required fields in stg_bi_sales</small>
        <div class="mt-1">
            <a href="#bi-errors-section" class="small">View error details ↓</a>
        </div>
    </div>
</div>

<!-- Check: PENDING (ยังไม่รัน) -->
<div class="vg-check-card vg-check-card--pending">
    <div class="vg-check-card__header">
        <span class="vg-check-number">④</span>
        <span class="vg-check-name">Mapping Completeness (MT)</span>
        <span class="vg-status-badge vg-status-badge--pending">⏳ PENDING</span>
    </div>
    <div class="vg-check-card__body">
        <small class="text-muted">Run Validation Gate to check MT mapping</small>
    </div>
</div>
```

---

## 10. Open Questions / Decisions Needed

| # | คำถาม | ตัวเลือก | แนะนำ |
|---|---|---|---|
| 1 | ข้อมูล stg_bi_sales import มาอย่างไร? (ตอนนี้) | A) Manual SQL INSERT, B) CSV upload หน้าเว็บ, C) ETL อัตโนมัติ | POC: A (ดูข้อมูล stg ที่ import มาแล้ว) |
| 2 | ต้องการปุ่ม "Import" บนหน้า UI ด้วยไหม? | A) ไม่ต้อง (แค่ validate stg ที่มีอยู่), B) มีปุ่ม upload CSV | POC: A ก่อน → เพิ่ม B ภายหลัง |
| 3 | Proceed to Calculation ไปหน้าไหน? | A) /Calculation (overview), B) แยก MT/TT/SI/LAOS | A — ให้ user เลือกเอง |
| 4 | ต้อง block Calculation ถ้า validation ไม่ผ่านไหม? | A) เพียง warning, B) hard block | POC: A (warning) → B ใน production |
| 5 | Channel scope: validate ทุก channel หรือเลือก channel? | A) ทุก channel ในรอบเดียว, B) เลือก channel | A — simple ดีกว่าสำหรับ POC |

---

## 11. Dependency & Risk

| ความเสี่ยง | ระดับ | Mitigation |
|---|---|---|
| stg_bi_sales / stg_hcm_employee อาจไม่มีข้อมูล period ปัจจุบัน | Medium | Page แสดง "No data imported for this period" แทน error |
| SP usp_run_validation_gate อาจซับซ้อน (multi-RS + Dapper) | Medium | ใช้ GridReader pattern เหมือน PortalDataService เดิม |
| Check 3 (Hierarchy) ต้องการ mst_org_hierarchy สำหรับ period นั้นๆ | High | ถ้าไม่มี hierarchy data → แสดง WARNING ไม่ใช่ block FAIL |

---

## 12. Effort Estimate

| Phase | งาน | Effort |
|---|---|---|
| Phase 1 | DB: 2 tables + 2 SPs | 1.0 วัน |
| Phase 2 | Application: models + service | 0.5 วัน |
| Phase 3 | Web UI: page + layout + JS | 1.0 วัน |
| Phase 4 | Navigation + calc integration | 0.5 วัน |
| **รวม** | | **~3 วัน** |

---

*เอกสารนี้ใช้เป็น reference สำหรับ Copilot implement ต่อ*  
*อ้างอิงจาก: AJT_Validation-Gate_Detailed.md | stg_bi_sales | stg_hcm_employee | site.css MT-modern classes*
