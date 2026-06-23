# Target Management — UX/UI Design v1.0

**วันที่:** 2026-06-23  
**เวอร์ชัน:** v1.0 — Design Proposal  
**สถานะ:** Draft — Ready for Review  
**หน้าปัจจุบัน:** `/Target`

---

## 1. ปัญหาและเป้าหมาย

### ปัญหาเดิม
- ตรวจแก้ Target **ทีละแถว** เท่านั้น (edit single row UI)
- ไม่มีวิธี **import file target** จำนวนมากพร้อมกัน
- ต้องกรอกข้อมูลด้วยมือ → ช้า, เสี่ยง input error

### เป้าหมายใหม่
1. ✅ **Import file** (CSV/Excel) — upload target data ได้อย่างรวดเร็ว
2. ✅ **Preview & Validate** — แสดงข้อมูล import ก่อนบันทึก, เช็ก error
3. ✅ **Adjust/Edit** — สามารถแก้ไข field ได้ก่อนหรือหลัง import
4. ✅ **Bulk action** — edit หลายแถวพร้อมกัน (optional future)

---

## 2. Workflow & Screen Design

### 2.1 Overall Flow

```
┌─────────────────────────────────────────────────────────┐
│  Target Management (Landing)                             │
│  ─────────────────────────────────────────────────────  │
│  [ Tab 1: Import ]  [ Tab 2: Manage ]                   │
│  ─────────────────────────────────────────────────────  │
│                                                          │
│  TAB 1: IMPORT                                           │
│  ┌──────────────────────────────────────────────────┐   │
│  │ 1. Select Channel & Period (dropdown filter)     │   │
│  │    [Channel ▼]  [Period ▼]                       │   │
│  │                                                  │   │
│  │ 2. Upload File                                   │   │
│  │    ┌────────────────────────────────┐            │   │
│  │    │ 📎 Drag file or Click to Upload │            │   │
│  │    │ (CSV, XLSX, TXT — max 5MB)     │            │   │
│  │    └────────────────────────────────┘            │   │
│  │                                                  │   │
│  │ 3. Preview & Validate                            │   │
│  │    ┌──────────────────────────────┐              │   │
│  │    │ Row │ Salesman │ Product │ ... │ Status      │   │
│  │    ├──────────────────────────────┤              │   │
│  │    │  1  │ SM0001   │ PRD001  │ ... │ ✅ Valid    │   │
│  │    │  2  │ SM0002   │ PRD002  │ ... │ ❌ Error    │   │
│  │    │  3  │ SM0003   │ PRD003  │ ... │ ✅ Valid    │   │
│  │    └──────────────────────────────┘              │   │
│  │                                                  │   │
│  │ 4. Action Buttons                                │   │
│  │    [❌ Cancel]  [↻ Adjust/Edit]  [✅ Import]     │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  TAB 2: MANAGE                                           │
│  (existing: filter + table + edit/delete per row)       │
│  └─────────────────────────────────────────────────────┘
└─────────────────────────────────────────────────────────┘
```

---

### 2.2 Screen 1 — Import Tab (Default View)

#### Section 1A: File Selection
```
╔════════════════════════════════════════════════════════╗
║  Choose Channel & Period                               ║
╠════════════════════════════════════════════════════════╣
║                                                        ║
║  Channel:  [  MT ▼  ]    Period: [  FY2026-05 ▼ ]    ║
║                                                        ║
║  📝 Target file จะ import ลงใน MT / FY2026-05          ║
╚════════════════════════════════════════════════════════╝
```

#### Section 1B: File Upload
```
╔════════════════════════════════════════════════════════╗
║  Upload Target File                                    ║
╠════════════════════════════════════════════════════════╣
║                                                        ║
║      ┌──────────────────────────────────┐             ║
║      │                                  │             ║
║      │   📁 Drag & drop file here       │             ║
║      │   หรือคลิกเพื่อเลือกไฟล์          │             ║
║      │   (CSV, XLSX — max 5MB)          │             ║
║      │                                  │             ║
║      └──────────────────────────────────┘             ║
║                                                        ║
║  💡 Template: Download sample file [ดาวน์โหลด]        ║
║     [ช่วยเหลือ] CSV format ต้องมี columns ไหนบ้าง   ║
║                                                        ║
╚════════════════════════════════════════════════════════╝
```

#### Section 1C: Preview & Validation
```
╔════════════════════════════════════════════════════════╗
║  Preview & Validation Results                          ║
╠════════════════════════════════════════════════════════╣
║                                                        ║
║  📊 ไฟล์ที่อัปโหลด: target_FY2026_05_MT.csv           ║
║  📈 จำนวนแถว: 45 rows (header 1 row + data 44 rows)  ║
║                                                        ║
║  ✅ Valid rows:  43 ✓                                  ║
║  ❌ Error rows:   2 ✗  (see below)                     ║
║  ⏳ Duplicate:    0                                     ║
║                                                        ║
║  ┌─────────────────────────────────────────────────┐  ║
║  │ Row │ Salesman │ Product  │ Target    │ Status   │  ║
║  ├─────────────────────────────────────────────────┤  ║
║  │  1  │ SM0001   │ PRD-MT01 │ 100,000   │ ✅       │  ║
║  │  2  │ SM0002   │ PRD-MT02 │ 150,000   │ ✅       │  ║
║  │  3  │ [empty]  │ PRD-MT03 │ 200,000   │ ❌       │  ║
║  │     │          │          │           │ (salesman empty)
║  │  4  │ SM0004   │ PRD-XX99 │ 80,000    │ ❌       │  ║
║  │     │          │          │           │ (product not found)
║  │  5  │ SM0005   │ PRD-MT05 │ 120,000   │ ✅       │  ║
║  │ ... │ ...      │ ...      │ ...       │ ...      │  ║
║  └─────────────────────────────────────────────────┘  ║
║  [Show all errors]  [Fix & Re-upload]                 ║
║                                                        ║
╚════════════════════════════════════════════════════════╝
```

#### Section 1D: Action Buttons
```
╔════════════════════════════════════════════════════════╗
║  Adjust (Optional) & Import                            ║
╠════════════════════════════════════════════════════════╣
║                                                        ║
║  [ ↻ Adjust/Edit before Import ]                      ║
║     ↓ (opens inline edit grid)                        ║
║  [ ✅ Confirm & Import ]  [ ❌ Cancel ]                ║
║                                                        ║
╚════════════════════════════════════════════════════════╝
```

---

### 2.3 Screen 2 — Preview + Adjust (On "Adjust" Button Click)

เปิด inline edit grid ให้ผู้ใช้แก้ไข error rows หรือปรับค่า ก่อนยืนยัน import

```
╔════════════════════════════════════════════════════════╗
║  Adjust Target Data before Import                      ║
╠════════════════════════════════════════════════════════╣
║                                                        ║
║  ⚠️  คุณมี 2 error rows — กรุณาแก้ไขก่อนกด Import    ║
║                                                        ║
║  ┌─────────────────────────────────────────────────┐  ║
║  │ Row │ Salesman   │ Product   │ Target   │ Action  │  ║
║  ├─────────────────────────────────────────────────┤  ║
║  │  3  │ [textbox]  │ PRD-MT03  │ 200,000  │  ✎     │  ║
║  │     │ (error: empty) → type: SM0003             │  ║
║  │     │ Or skip/delete this row [🗑️]              │  ║
║  │  4  │ SM0004     │ [dropdown] │ 80,000  │  ✎     │  ║
║  │     │            │ (product not found)            │  ║
║  │     │            │ Select from list or skip       │  ║
║  │     │            │ [PRD-MT04] [PRD-MT05] [Skip]  │  ║
║  └─────────────────────────────────────────────────┘  ║
║                                                        ║
║  [ ✅ Confirm & Import ]  [ ❌ Cancel ]                ║
║                                                        ║
╚════════════════════════════════════════════════════════╝
```

---

### 2.4 Screen 3 — Manage Tab (Existing + Enhanced)

ยังคงใช้ layout เดิม แต่เพิ่ม feature:
- **Bulk edit** checkbox (optional)
- **Edit inline** ในตาราห เพื่อ quick adjust ต่อเลยหลัง import

```
╔════════════════════════════════════════════════════════╗
║  Manage Existing Targets                               ║
╠════════════════════════════════════════════════════════╣
║                                                        ║
║  Filter:  [Channel ▼] [Period ▼] [Keyword ___]       ║
║           [Load] [Clear]                              ║
║                                                        ║
║  ┌─────────────────────────────────────────────────┐  ║
║  │ ID  │ Salesman    │ Product  │ Target  │ Pct │ ...│
║  ├─────────────────────────────────────────────────┤  ║
║  │1001 │ SM0001      │ PRD-MT01 │ 100,000 │ 1.0 │ ✎ │
║  │1002 │ SM0002      │ PRD-MT02 │ 150,000 │ 0.5 │ ✎ │
║  │1003 │ SM0003      │ PRD-MT03 │ 200,000 │ 1.0 │ ✎ │
║  │ ... │ ...         │ ...      │ ...     │ ... │ ..│
║  └─────────────────────────────────────────────────┘  ║
║                                                        ║
║  Per-row action:                                       ║
║    ✎ = Edit (inline or modal)                         ║
║    🗑️ = Delete                                         ║
║    + = Add new row (optional)                          ║
║                                                        ║
╚════════════════════════════════════════════════════════╝
```

---

## 3. Technical Implementation Notes

### 3.1 Backend (PageModel)

```csharp
// OnGetAsync — Load channels, periods
// OnPostUploadAsync — Handle file upload
// OnPostValidateAsync — Validate uploaded data
// OnPostImportAsync — Bulk insert validated rows
// OnPostAdjustAsync — Save adjusted rows before import

public IActionResult OnPostUpload(IFormFile file, int channelId, int periodId)
{
    // 1. Parse CSV/Excel
    // 2. Validate each row (salesman exists? product exists?)
    // 3. Return preview + error list
}

public IActionResult OnPostAdjust(List<TargetAdjustRow> rows)
{
    // 1. Validate adjusted rows
    // 2. Save adjusted data to temp session or DB staging table
    // 3. Redirect to import confirmation
}

public IActionResult OnPostImport(int channelId, int periodId, bool fromUpload)
{
    // 1. Bulk insert validated rows into trn_sales_target
    // 2. Set imported_at timestamp
    // 3. Redirect with success message
}
```

### 3.2 Frontend (Razor View)

**Tab structure:**
```html
<ul class="nav nav-tabs" role="tablist">
    <li class="nav-item">
        <button class="nav-link active" data-bs-toggle="tab" href="#tab-import">
            📁 Import File
        </button>
    </li>
    <li class="nav-item">
        <button class="nav-link" data-bs-toggle="tab" href="#tab-manage">
            ⚙️ Manage
        </button>
    </li>
</ul>

<div class="tab-content">
    <div id="tab-import" class="tab-pane fade show active">
        <!-- Section 1A, 1B, 1C, 1D -->
    </div>
    <div id="tab-manage" class="tab-pane fade">
        <!-- Existing manage screen -->
    </div>
</div>
```

**File upload component:**
```html
<div class="dropzone" id="target-dropzone">
    <input type="file" name="TargetFile" accept=".csv,.xlsx" />
    <p>Drag & drop or click to select</p>
</div>

<script>
// Handle file drag-drop + validation
// Show preview after upload
// Bind adjust/import buttons
</script>
```

---

## 4. CSV Template Format

| Salesman Code | Product Code | Target Amount | Pct Salesman | Approved By | Approved At      |
|---|---|---|---|---|---|
| SM0001 | PRD-MT01 | 100000 | 1.0 | ADMIN | 2026-06-23 |
| SM0002 | PRD-MT02 | 150000 | 0.5 | ADMIN | 2026-06-23 |
| SM0003 | PRD-MT03 | 200000 | 1.0 |  |  |

**Download link:** `/Target/download-template` → serves CSV template file

---

## 5. Success Criteria

✅ **Phase 1 (MVP)**
- [ ] Upload CSV file + preview rows
- [ ] Validate salesman & product exist
- [ ] Bulk import to DB (40+ rows in ~2 sec)
- [ ] Show import summary (success count, error count)

✅ **Phase 2 (Enhancement)**
- [ ] Inline adjust before import (fix salesman/product fields)
- [ ] Drag-select multiple rows for bulk edit
- [ ] Export current targets to CSV
- [ ] Duplicate detection (same salesman+product+period)

---

## 6. File Structure (Proposed)

```
Pages/Target/
├── Index.cshtml        (tabs + import + manage)
├── Index.cshtml.cs     (existing + new handlers)
├── _UploadPartial.cshtml  (file upload section — optional)
├── _PreviewPartial.cshtml (preview + adjust — optional)
└── _ManagePartial.cshtml  (manage section)
```

---

*เอกสารนี้ใช้เป็น spec สำหรับการ implement Target Management v2*  
*Ready for discussion & refinement ก่อน dev*
