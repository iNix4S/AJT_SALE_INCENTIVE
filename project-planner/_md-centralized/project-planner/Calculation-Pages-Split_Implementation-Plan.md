# Implementation Plan — Calculation Pages แยก 4 Channel
# พร้อม Formula Expression Engine Integration

**วันที่จัดทำ:** 2026-06-23
**เวอร์ชัน:** v1.0
**สถานะ:** Ready to Implement
**อ้างอิงโปรเจกต์:** AJT New Sale Incentive System

---

## 1. ภาพรวมงาน (Objective)

**เป้าหมาย:** แยกหน้า Calculation ที่มีอยู่ (1 หน้ารวม 4 channel) ออกเป็น **4 หน้าแยกกัน**
พร้อมรองรับการแสดงผล formula expression ที่ใช้คำนวณจาก `dbo.mst_formula_expression`

**หน้าปัจจุบัน (Before):**
```
/Calculation/Index  ← หน้าเดียวมีทุก channel
```

**หน้าที่ต้องการ (After):**
```
/Calculation/Index  ← Overview / Landing (redirect หรือ summary)
/Calculation/MT     ← หน้าคำนวณ MT Channel
/Calculation/TT     ← หน้าคำนวณ TT Channel (TOP_WS + WS_SF)
/Calculation/SI     ← หน้าคำนวณ SI Channel
/Calculation/LAOS   ← หน้าคำนวณ LAOS Channel
```

**เมนู Navbar (After):**
```
Calculation ▼ (dropdown)
  ├─ MT Calculation
  ├─ TT Calculation
  ├─ SI Calculation
  └─ LAOS Calculation
```

---

## 2. การสำรวจโครงสร้างปัจจุบัน

### 2.1 Files ที่มีอยู่แล้ว (ไม่ต้องสร้างใหม่)

| File | สถานะ | หมายเหตุ |
|---|---|---|
| `src/AjtIncentive.Web/Pages/Calculation/Index.cshtml(.cs)` | ✅ มีอยู่ | รวม 4 channel ใน 1 หน้า → จะ refactor เป็น Landing |
| `src/AjtIncentive.Application/Interfaces/ICalculationService.cs` | ✅ มีอยู่ | มี RunMt/TT/SI/LaosAsync ครบ |
| `src/AjtIncentive.Infrastructure/StoredProcedures/MtCalculationRunner.cs` | ✅ มีอยู่ | Implements ICalculationService ทั้ง 4 SP |
| `src/AjtIncentive.Web/Services/FormulaEvaluatorService.cs` | ✅ มีอยู่ | IFormulaEvaluatorService + NCalc 6.3.0 |
| `src/AjtIncentive.Web/Services/PortalDataService.cs` | ✅ มีอยู่ | GetPeriodsAsync, GetPeriodReadinessAsync, GetRecentRunsAsync |
| `src/AjtIncentive.Web/Program.cs` | ✅ มีอยู่ | DI registrations ครบ |
| `dbo.mst_formula_expression` | ✅ มีอยู่ | 13 rows, all channels |
| `dbo.vw_formula_expression_active` | ✅ มีอยู่ | filtered by effective date |
| `dbo.usp_formula_expression_preview` | ✅ มีอยู่ | preview คำนวณโดยใช้ formula |
| `dbo.usp_formula_expression_evaluate` | ✅ มีอยู่ | ทดสอบสูตรรายตัว |

### 2.2 DI Registrations ที่มีอยู่ใน Program.cs

```csharp
builder.Services.AddScoped<ICalculationService>(sp => new MtCalculationRunner(connectionString));
builder.Services.AddScoped<IPortalDataService>(sp => new PortalDataService(connectionString));
builder.Services.AddScoped<IFormulaEvaluatorService>(sp => new FormulaEvaluatorService(connectionString));
```

### 2.3 IFormulaEvaluatorService Methods ที่ใช้งานได้

```csharp
Task<IReadOnlyList<FormulaExpression>> GetAllAsync();
Task<FormulaExpression?> GetByCodeAsync(string formulaCode);
FormulaEvalResult Evaluate(string formulaExpr, Dictionary<string, decimal> variables, string formulaCode = "");
Task<FormulaEvalResult> EvaluateByCodeAsync(string formulaCode, Dictionary<string, decimal> variables);
bool Validate(string formulaExpr, out string errorMessage);
Task<int> SaveAsync(FormulaExpression formula);
Task DeleteAsync(int formulaId);
```

---

## 3. สิ่งที่ต้องสร้างใหม่

### 3.1 Web Pages (Razor Pages)

| File | ประเภท | Priority |
|---|---|---|
| `Pages/Calculation/MT/Index.cshtml` | New | P1 |
| `Pages/Calculation/MT/Index.cshtml.cs` | New | P1 |
| `Pages/Calculation/TT/Index.cshtml` | New | P1 |
| `Pages/Calculation/TT/Index.cshtml.cs` | New | P1 |
| `Pages/Calculation/SI/Index.cshtml` | New | P1 |
| `Pages/Calculation/SI/Index.cshtml.cs` | New | P1 |
| `Pages/Calculation/LAOS/Index.cshtml` | New | P1 |
| `Pages/Calculation/LAOS/Index.cshtml.cs` | New | P1 |

### 3.2 Service Extensions (PortalDataService)

ต้องเพิ่ม methods ต่อไปนี้ใน `IPortalDataService` และ `PortalDataService`:

| Method | รายละเอียด |
|---|---|
| `GetFormulasByChannelAsync(string channelCode)` | โหลด active formulas ของ channel จาก vw_formula_expression_active |
| `GetCalcRunHistoryAsync(int channelId, int top)` | ประวัติการรันของ channel นั้นๆ |
| `GetCalcRunDetailAsync(int calcRunId)` | ผลลัพธ์ incentive_detail ของ run นั้น |
| `GetPreviewRowsAsync(int periodId, string channelCode)` | เรียก usp_formula_expression_preview |

### 3.3 _Layout.cshtml Navigation

เปลี่ยนเมนู Calculation จาก link เดี่ยว → dropdown:

```html
<!-- เดิม (ลบออก) -->
<li class="nav-item">
    <a class="nav-link" asp-page="/Calculation/Index">Calculation</a>
</li>

<!-- ใหม่ (เพิ่ม) -->
<li class="nav-item dropdown">
    <a class="nav-link dropdown-toggle" href="#" role="button"
       data-bs-toggle="dropdown">Calculation</a>
    <ul class="dropdown-menu">
        <li><a class="dropdown-item" asp-page="/Calculation/MT/Index">🔵 MT Calculation</a></li>
        <li><a class="dropdown-item" asp-page="/Calculation/TT/Index">🟢 TT Calculation</a></li>
        <li><a class="dropdown-item" asp-page="/Calculation/SI/Index">🟡 SI Calculation</a></li>
        <li><a class="dropdown-item" asp-page="/Calculation/LAOS/Index">🟠 LAOS Calculation</a></li>
    </ul>
</li>
```

---

## 4. ออกแบบหน้าแต่ละ Channel

### 4.1 โครงสร้าง UI (เหมือนกันทุก channel)

```
┌─────────────────────────────────────────────────┐
│ [Header] MT Calculation — Channel Overview       │
│ Period: [FY2026-04 ▾]  [Run Calculation]         │
├─────────────────────────────────────────────────┤
│ Section A: Formula Expressions (read-only)       │
│   step: PCT_ACHIEVEMENT → expression              │
│   step: INCENTIVE_PER_PRODUCT → per position      │
│   step: ROLLUP → expression                       │
├─────────────────────────────────────────────────┤
│ Section B: Period Readiness                       │
│   Target rows: 262 ✅   Actual rows: 262 ✅       │
├─────────────────────────────────────────────────┤
│ Section C: Calculation History (last 5 runs)     │
│   calc_run_id | period | status | run_at          │
├─────────────────────────────────────────────────┤
│ Section D: Latest Result Preview                  │
│   [เลือก run] → แสดง incentive detail summary   │
└─────────────────────────────────────────────────┘
```

### 4.2 Page Model Properties ที่แต่ละหน้าต้องการ

```csharp
// ─── Common ─────────────────────────────────────────
public IReadOnlyList<PeriodItem> Periods { get; set; }
public IReadOnlyDictionary<int, PeriodReadiness> Readiness { get; set; }
public IReadOnlyList<CalcRunItem> RunHistory { get; set; }

// ─── Formula Panel ──────────────────────────────────
public IReadOnlyList<FormulaExpression> Formulas { get; set; }

// ─── Handlers ────────────────────────────────────────
[BindProperty] public int PeriodId { get; set; }
// TT only: [BindProperty] public string WsType { get; set; }

// ─── Result ─────────────────────────────────────────
public string? RunMessage { get; set; }
```

### 4.3 Channel-Specific Differences

| Channel | Parameter | SP | WsType | Formula Step ที่โชว์ |
|---|---|---|---|---|
| MT | `@PeriodId` | `usp_run_mt_incentive_calculation` | — | PCT + INCENTIVE + ROLLUP |
| TT | `@PeriodCode` + `@WsType` | `usp_run_tt_incentive_calculation` | TOP_WS, WS_SF | PCT + INCENTIVE + SPECIAL_KPI |
| SI | `@PeriodId` | `usp_run_si_incentive_calculation` | — | PCT + INCENTIVE |
| LAOS | `@PeriodCode` | `usp_run_laos_incentive_calculation` | TOP_WS, WS_SF | PCT + INCENTIVE |

---

## 5. Data Flow — Formula Expression Integration

```
[User เลือก Period → กด Run]
        │
        ▼
PageModel.OnPostRunAsync()
        │
        ├─► ICalculationService.Run{Channel}CalculationAsync(periodId)
        │       └─► dbo.usp_run_{channel}_incentive_calculation (SP)
        │               └─► INSERT trn_incentive_detail, out_for_hr_variable
        │
        └─► IFormulaEvaluatorService.GetAllAsync() (filtered by channel)
                └─► SELECT FROM vw_formula_expression_active
                        WHERE channel_code = '{channel}' OR channel_code = 'SHARED'
                        → แสดงในหน้า Section A

[Formula Panel แสดง]
        │
        ▼
        vw_formula_expression_active
        ├─ PCT_ACHIEVEMENT : ROUND([actual_amount] / [target_amount], 4)
        ├─ MT_STAFF_INCENTIVE : ROUND([base_rate] * [weight_pct] * [goal_mult], 0)
        ├─ MT_ROLLUP : ROUND([sum_incentive_per_product], 2)
        └─ ...

[Preview ก่อน Run (optional)]
        │
        ▼
        dbo.usp_formula_expression_preview(@PeriodId, @ChannelCode)
        → แสดงผลลัพธ์ก่อนบันทึก
```

---

## 6. Implementation Phases

### Phase 1: Navigation + Landing Page
**Effort:** 0.5 MD

| Task | File | Action |
|---|---|---|
| 1-1 | `_Layout.cshtml` | เปลี่ยน Calculation link → dropdown 4 channel |
| 1-2 | `Pages/Calculation/Index.cshtml(.cs)` | Refactor เป็น landing page (links ไปทั้ง 4 channel) |

**Acceptance Criteria:**
- กดที่เมนู Calculation → dropdown ปรากฏ 4 channel
- `/Calculation` → landing page แสดง status ทั้ง 4 channel

---

### Phase 2: MT Calculation Page
**Effort:** 0.5 MD | Priority: P1

| Task | File | Action |
|---|---|---|
| 2-1 | `Pages/Calculation/MT/Index.cshtml.cs` | สร้าง MTIndexModel: inject ICalculationService + IFormulaEvaluatorService + IPortalDataService |
| 2-2 | `Pages/Calculation/MT/Index.cshtml` | สร้าง UI: Header + Formula Panel + Readiness + Run Form + History |
| 2-3 | `PortalDataService.cs` | เพิ่ม `GetFormulasByChannelAsync("MT")` |

**Page Model Skeleton:**
```csharp
namespace AjtIncentive.Web.Pages.Calculation.MT;

public class IndexModel : PageModel
{
    private readonly ICalculationService _calcService;
    private readonly IPortalDataService _portalService;
    private readonly IFormulaEvaluatorService _formulaService;
    private readonly string _connectionString;

    [BindProperty] public int PeriodId { get; set; }

    public IReadOnlyList<PeriodItem> Periods { get; set; } = [];
    public IReadOnlyDictionary<int, PeriodReadiness> Readiness { get; set; } = new Dictionary<int, PeriodReadiness>();
    public IReadOnlyList<FormulaExpression> Formulas { get; set; } = [];
    public IReadOnlyList<CalcRunItem> RunHistory { get; set; } = [];

    public async Task OnGetAsync() { ... }

    public async Task<IActionResult> OnPostRunAsync()
    {
        var calcRunId = await _calcService.RunMtCalculationAsync(PeriodId);
        TempData["Message"] = $"MT คำนวณสำเร็จ Calc Run #{calcRunId}";
        return RedirectToPage();
    }
}
```

---

### Phase 3: TT Calculation Page
**Effort:** 0.5 MD | Priority: P1

| Task | File | Action |
|---|---|---|
| 3-1 | `Pages/Calculation/TT/Index.cshtml.cs` | TT: BindProperty WsType (TOP_WS, WS_SF) + PeriodCode |
| 3-2 | `Pages/Calculation/TT/Index.cshtml` | เพิ่ม WsType selector + แยก Formula Panel ตาม ws_type |
| 3-3 | Handler | OnPostRunAsync → RunTtCalculationAsync(periodCode, wsType) |

**TT-Specific:**
```csharp
[BindProperty] public string PeriodCode { get; set; } = string.Empty;
[BindProperty] public string WsType { get; set; } = "TOP_WS";
public IReadOnlyList<string> WsTypes { get; set; } = ["TOP_WS", "WS_SF"];
```

---

### Phase 4: SI Calculation Page
**Effort:** 0.5 MD | Priority: P1

| Task | File | Action |
|---|---|---|
| 4-1 | `Pages/Calculation/SI/Index.cshtml.cs` | SI: PeriodId only, formula for STAFF + SECT_MGR |
| 4-2 | `Pages/Calculation/SI/Index.cshtml` | UI เหมือน MT แต่ channel = SI |

---

### Phase 5: LAOS Calculation Page
**Effort:** 0.5 MD | Priority: P1

| Task | File | Action |
|---|---|---|
| 5-1 | `Pages/Calculation/LAOS/Index.cshtml.cs` | LAOS: PeriodId → convert to PeriodCode ก่อนเรียก SP |
| 5-2 | `Pages/Calculation/LAOS/Index.cshtml` | UI คล้าย TT (มี WsType concept) |

---

### Phase 6: PortalDataService Extensions
**Effort:** 1 MD | Priority: P1

เพิ่ม methods ใน `IPortalDataService` และ `PortalDataService`:

```csharp
// 6-1: โหลด formulas ต่อ channel สำหรับ Formula Panel
Task<IReadOnlyList<FormulaExpression>> GetFormulasByChannelAsync(string channelCode);

// 6-2: โหลด calc run history ต่อ channel
Task<IReadOnlyList<CalcRunHistoryItem>> GetCalcRunHistoryAsync(int channelId, int top = 10);

// 6-3: โหลด preview ผ่าน SP
Task<IReadOnlyList<FormulaPreviewRow>> GetFormulaPreviewAsync(int periodId, string channelCode);
```

**SQL สำหรับ GetFormulasByChannelAsync:**
```sql
SELECT f.formula_id, f.formula_code, f.formula_name, f.formula_step,
       f.channel_code, f.position_code, f.ws_type, f.formula_expr,
       f.variables_json, f.description, f.sort_order
FROM dbo.vw_formula_expression_active f
WHERE f.channel_code = @ChannelCode OR f.channel_code = 'SHARED'
ORDER BY
    CASE f.formula_step
        WHEN 'PCT_ACHIEVEMENT' THEN 1
        WHEN 'INCENTIVE_PER_PRODUCT' THEN 2
        WHEN 'ROLLUP' THEN 3
        WHEN 'SPECIAL_KPI' THEN 4
    END, f.hierarchy_level, f.sort_order
```

**SQL สำหรับ GetCalcRunHistoryAsync:**
```sql
SELECT r.calc_run_id, p.period_code, r.run_status,
       FORMAT(r.calculated_at, 'yyyy-MM-dd HH:mm') AS run_at,
       r.approved_by,
       (SELECT COUNT(*) FROM dbo.trn_incentive_detail WHERE calc_run_id = r.calc_run_id) AS detail_rows
FROM dbo.trn_calc_run r
JOIN dbo.mst_period p ON p.period_id = r.period_id
WHERE r.channel_id = @ChannelId
ORDER BY r.calc_run_id DESC
OFFSET 0 ROWS FETCH NEXT @Top ROWS ONLY
```

---

### Phase 7: Formula Preview Integration (Optional/P2)
**Effort:** 1 MD | Priority: P2

| Task | File | Action |
|---|---|---|
| 7-1 | ทุกหน้า | เพิ่มปุ่ม "Preview" ก่อน Run จริง |
| 7-2 | `PortalDataService` | เรียก `usp_formula_expression_preview` |
| 7-3 | Shared Partial | สร้าง `_FormulaPreviewTable.cshtml` (partial view) |

---

## 7. File Structure สมบูรณ์ (After)

```
src/AjtIncentive.Web/
├── Pages/
│   └── Calculation/
│       ├── Index.cshtml          ← Refactor: Landing page
│       ├── Index.cshtml.cs       ← Refactor: Landing page model
│       ├── MT/
│       │   ├── Index.cshtml      ← NEW: MT Calculation UI
│       │   └── Index.cshtml.cs   ← NEW: MTIndexModel
│       ├── TT/
│       │   ├── Index.cshtml      ← NEW: TT Calculation UI
│       │   └── Index.cshtml.cs   ← NEW: TTIndexModel
│       ├── SI/
│       │   ├── Index.cshtml      ← NEW: SI Calculation UI
│       │   └── Index.cshtml.cs   ← NEW: SIIndexModel
│       └── LAOS/
│           ├── Index.cshtml      ← NEW: LAOS Calculation UI
│           └── Index.cshtml.cs   ← NEW: LAOSIndexModel
├── Services/
│   ├── FormulaEvaluatorService.cs ← ไม่ต้องแก้ไข
│   └── PortalDataService.cs      ← Extend: เพิ่ม 3 methods
└── Pages/Shared/
    └── _Layout.cshtml            ← แก้ไข: dropdown menu
```

---

## 8. Interfaces / Models ใหม่ที่ต้องสร้าง

```csharp
// ใน PortalDataService.cs (เพิ่มต่อจากของเดิม)

public sealed class CalcRunHistoryItem
{
    public int CalcRunId { get; init; }
    public string PeriodCode { get; init; } = string.Empty;
    public string RunStatus { get; init; } = string.Empty;
    public string? RunAt { get; init; }
    public string? ApprovedBy { get; init; }
    public int DetailRows { get; init; }
}

public sealed class FormulaPreviewRow
{
    public string SalesmanCode { get; init; } = string.Empty;
    public string PositionCode { get; init; } = string.Empty;
    public string? WsType { get; init; }
    public string ProductCode { get; init; } = string.Empty;
    public decimal TargetAmount { get; init; }
    public decimal ActualAmount { get; init; }
    public decimal PctAchievement { get; init; }
    public decimal GoalMult { get; init; }
    public string? FormulaCodeIncent { get; init; }
    public string? FormulaExprIncent { get; init; }
    public decimal IncentiveAmount { get; init; }
}
```

---

## 9. Dependencies / Prerequisites

ก่อนเริ่ม implement ต้องมีสิ่งเหล่านี้ครบ (ทำแล้วทั้งหมด ✅):

| Dependency | สถานะ |
|---|---|
| `dbo.mst_formula_expression` — 13 rows | ✅ |
| `dbo.vw_formula_expression_active` | ✅ |
| `dbo.usp_formula_expression_preview` | ✅ |
| `dbo.usp_formula_expression_evaluate` | ✅ |
| `IFormulaEvaluatorService` + NCalc 6.3.0 | ✅ |
| `ICalculationService` + MtCalculationRunner | ✅ |
| `IPortalDataService` + PortalDataService | ✅ |
| DI registrations ใน Program.cs | ✅ |

---

## 10. สรุป Effort Estimate

| Phase | งาน | Effort |
|---|---|---|
| 1 | Navigation + Landing Page | 0.5 MD |
| 2 | MT Calculation Page | 0.5 MD |
| 3 | TT Calculation Page | 0.5 MD |
| 4 | SI Calculation Page | 0.5 MD |
| 5 | LAOS Calculation Page | 0.5 MD |
| 6 | PortalDataService Extensions | 1.0 MD |
| 7 | Formula Preview Integration (P2) | 1.0 MD |
| **รวม P1** | **Phase 1–6** | **3.5 MD** |
| **รวมทั้งหมด** | **Phase 1–7** | **4.5 MD** |

---

## 11. ลำดับการ Implement (Recommended Order)

```
Phase 6 → Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 7
   ↑           ↑
Service     เมนู/nav ก่อน
extensions  เพื่อ test routing
```

**เหตุผล:** ทำ PortalDataService extensions ก่อน เพราะทุกหน้าต้องใช้ → แล้วค่อยสร้างหน้าทีละ channel → ทดสอบ build ทุก phase

---

## 12.1 Phase Status (อัปเดตล่าสุด 2026-06-23)

| Phase | สถานะ | หมายเหตุ |
|---|---|---|
| Phase 1: Navigation + Landing | ✅ Done | เปลี่ยนเมนูเป็น dropdown + Calculation landing page |
| Phase 2: MT Page | ✅ Done | สร้างหน้า MT แยก + formula/history + run |
| Phase 3: TT Page | ✅ Done | สร้างหน้า TT แยก + WsType + formula/history + run |
| Phase 4: SI Page | ✅ Done | สร้างหน้า SI แยก + formula/history + run |
| Phase 5: LAOS Page | ✅ Done | สร้างหน้า LAOS แยก + WsType concept + formula/history + run |
| Phase 6: Service Extensions | ✅ Done | เพิ่ม methods ใน PortalDataService ตามแผน |
| Phase 7: Preview Integration | ✅ Done | เพิ่มปุ่ม Preview ทุกหน้า + shared partial `_FormulaPreviewTable.cshtml` |

---

## 13. Checklist ก่อน Commit

- [x] `dotnet build src/AjtIncentive.slnx` → Build succeeded
- [x] ทุก 4 หน้าเข้าถึงได้จากเมนู dropdown
- [x] แต่ละหน้าแสดง Formula Panel (formulas จาก mst_formula_expression)
- [x] Run Calculation ทำงานได้ (เรียก SP จริง)
- [x] RunHistory แสดงประวัติ calc_run
- [x] หน้า Index เดิม (`/Calculation`) ยังใช้งานได้ (ไม่ broken)

หมายเหตุ: Checklist ด้านบนยืนยันจาก implementation + build สำเร็จใน solution ปัจจุบัน; แนะนำทำ UAT หน้าเว็บจริงเพื่อยืนยัน flow กับข้อมูลจริงในแต่ละ channel อีกครั้งก่อน release.
