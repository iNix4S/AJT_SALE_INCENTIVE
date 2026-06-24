# SP Usage Guide — LAOS Channel (Laos Market)
> หน้า http://localhost:5288/Calculation/LAOS

---

## Stored Procedures ที่ใช้ในหน้านี้

| SP | วัตถุประสงค์ | ปุ่มบนหน้าเว็บ |
|---|---|---|
| `dbo.usp_run_laos_incentive_calculation` | คำนวณ incentive LAOS บันทึกผลลง DB | **Run LAOS Calculation** |
| `dbo.usp_formula_expression_preview` | Preview ผลคำนวณโดยไม่บันทึก | **Preview** |
| `dbo.usp_formula_expression_evaluate` | ทดสอบสูตรรายตัว | (ไม่มีปุ่ม — ใช้ผ่าน SSMS) |

---

## 1. usp_run_laos_incentive_calculation

### Signature

```sql
CREATE PROCEDURE dbo.usp_run_laos_incentive_calculation
    @PeriodCode NVARCHAR(20),           -- required: period_code จาก mst_period เช่น 'FY2026-04'
    @WsType     NVARCHAR(50) = N'TOP_WS', -- ws_type: TOP_WS | WS_SF | WS_WH | SF_WH (default='TOP_WS')
    @ApprovedBy NVARCHAR(100) = NULL    -- ชื่อผู้อนุมัติ (optional)
```

> LAOS ใช้ **PeriodCode** (string) เหมือน TT ไม่ใช่ PeriodId (int)

### Output (1 แถว)

| Column | Type | คำอธิบาย |
|---|---|---|
| `calc_run_id` | INT | รหัสรอบคำนวณ |
| `channel_code` | NVARCHAR | `'LAOS'` |
| `period_code` | NVARCHAR | period ที่คำนวณ |
| `status` | NVARCHAR | `'SUCCESS'` |
| `detail_rows` | INT | จำนวนแถวใน `trn_incentive_detail` |
| `for_hr_rows` | INT | จำนวนแถวใน `out_for_hr_variable` |

### ws_type ที่รองรับ

| ws_type | รายละเอียด |
|---|---|
| `TOP_WS` | Wholesale type หลัก (default) |
| `WS_SF` | Wholesale SF |
| `WS_WH` | Warehouse |
| `SF_WH` | SF + Warehouse |

### ตัวอย่าง EXEC — รันจริง

```sql
-- ── ตรวจ period ที่พร้อมก่อน ──────────────────────────────────────────────
SELECT p.period_id, p.period_code,
       COUNT(t.salesman_code) AS target_rows,
       (SELECT COUNT(*) FROM dbo.trn_sales_actual a
        WHERE a.period_id = p.period_id AND a.channel_id = c.channel_id) AS actual_rows
FROM dbo.mst_period p
CROSS JOIN dbo.mst_channel c
LEFT JOIN dbo.trn_sales_target t ON t.period_id = p.period_id AND t.channel_id = c.channel_id
WHERE c.channel_code = N'LAOS'
GROUP BY p.period_id, p.period_code, c.channel_id
ORDER BY p.period_id;

-- ── Run LAOS: FY2026-04 + TOP_WS ──────────────────────────────────────────
EXEC dbo.usp_run_laos_incentive_calculation
    @PeriodCode = N'FY2026-04',
    @WsType     = N'TOP_WS',
    @ApprovedBy = N'system';

-- ── Run LAOS: FY2026-04 + WS_SF ───────────────────────────────────────────
EXEC dbo.usp_run_laos_incentive_calculation
    @PeriodCode = N'FY2026-04',
    @WsType     = N'WS_SF',
    @ApprovedBy = N'system';
```

### Period Reference (LAOS)

| period_id | period_code | target_rows | actual_rows | พร้อม run |
|---|---|---|---|---|
| 1 | FY2026-04 | 9 | 9 | ✅ |
| 2 | FY2026-05 | 0 | 0 | ❌ |

### Logic สำคัญที่ต่างจาก TT

1. **Product mapping**: LAOS ใช้ SKU format `SKU-{alias}-NNN` → map ไป base product
   - `SKU-A-*` → `AJ`
   - `SKU-B-*` → `BD`
   - `SKU-R-*` → `RD`
   - `SKU-Y-*` → `YY`
   - ชื่ออื่น → ใช้ตามเดิม
2. **ws_type จาก** `mst_org_hierarchy` ถ้าไม่มีจะใช้ `@WsType` (default=TOP_WS)
3. **Manager**: คำนวณจาก avg `goal_multiplier` ของ subordinates (เหมือน TT)
4. SP ใช้ MERGE → สามารถ run ซ้ำ period เดิมได้ (จะ overwrite ผลเดิม)

### ดูผลหลัง Run

```sql
-- ดูสรุป run ล่าสุดของ LAOS
SELECT r.calc_run_id, p.period_code, r.run_status, r.approved_by, r.updated_at,
       (SELECT COUNT(*) FROM dbo.trn_incentive_detail d WHERE d.calc_run_id = r.calc_run_id) AS detail_rows,
       (SELECT COUNT(*) FROM dbo.out_for_hr_variable h WHERE h.calc_run_id = r.calc_run_id)  AS for_hr_rows
FROM dbo.trn_calc_run r
JOIN dbo.mst_period p ON p.period_id = r.period_id
WHERE r.channel_id = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'LAOS')
ORDER BY r.calc_run_id DESC;

-- ดู detail incentive (top 50)
SELECT TOP 50
    d.salesman_code, d.position_level_code, d.product_code,
    d.target_amount, d.actual_amount,
    d.achievement, d.goal_multiplier,
    d.incentive_base, d.product_weight, d.incentive_amount
FROM dbo.trn_incentive_detail d
WHERE d.calc_run_id = (
    SELECT TOP 1 calc_run_id FROM dbo.trn_calc_run
    WHERE channel_id = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'LAOS')
    ORDER BY calc_run_id DESC
)
ORDER BY d.salesman_code, d.product_code;

-- ดู For HR
SELECT TOP 50
    h.employee_code, h.employee_name_th, h.position_level_code,
    h.incentive_staff, h.incentive_sect, h.incentive_dept,
    h.total_variable
FROM dbo.out_for_hr_variable h
WHERE h.calc_run_id = (
    SELECT TOP 1 calc_run_id FROM dbo.trn_calc_run
    WHERE channel_id = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'LAOS')
    ORDER BY calc_run_id DESC
)
ORDER BY h.employee_code;
```

---

## 2. usp_formula_expression_preview (LAOS)

### Signature

```sql
CREATE PROCEDURE dbo.usp_formula_expression_preview
    @PeriodId    INT,
    @ChannelCode NVARCHAR(20) = NULL    -- 'LAOS' หรือ NULL = ทุก channel
```

> Preview ใช้ `@PeriodId` (INT) ไม่ใช่ `@PeriodCode`

### ตัวอย่าง EXEC

```sql
-- Preview LAOS: FY2026-04 (period_id=1)
EXEC dbo.usp_formula_expression_preview
    @PeriodId    = 1,
    @ChannelCode = N'LAOS';
```

---

## 3. usp_formula_expression_evaluate — ทดสอบสูตร LAOS

### สูตรที่ใช้ใน LAOS

| formula_code | formula_step | formula_expr |
|---|---|---|
| `SHARED_PCT_ACHIEVEMENT` | PCT_ACHIEVEMENT | `ROUND([actual_amount] / [target_amount], 4)` |
| `LAOS_STAFF_INCENTIVE_PER_PRODUCT` | INCENTIVE_PER_PRODUCT | `ROUND([base_rate] * [weight_pct] * [goal_mult], 0)` |
| `LAOS_MGR_INCENTIVE_PER_PRODUCT` | INCENTIVE_PER_PRODUCT | `[base_rate] * [weight_pct] * [goal_mult]` |

> LAOS ไม่มี SPECIAL_KPI และไม่มี ROLLUP แยก

### ตัวอย่าง EXEC แยกสูตร

```sql
-- ── PCT_ACHIEVEMENT ─────────────────────────────────────────────────────────
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode   = N'SHARED_PCT_ACHIEVEMENT',
    @actual_amount = 680000,
    @target_amount = 800000;
-- result = ROUND(680000/800000, 4) = 0.8500

-- over-achievement
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode   = N'SHARED_PCT_ACHIEVEMENT',
    @actual_amount = 1100000,
    @target_amount = 1000000;
-- result = 1.1000

-- ── STAFF Incentive (LAOS) ───────────────────────────────────────────────────
-- base_rate=3,500 | weight_pct=0.30 | goal_mult=1.0
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode = N'LAOS_STAFF_INCENTIVE_PER_PRODUCT',
    @base_rate   = 3500,
    @weight_pct  = 0.30,
    @goal_mult   = 1.0;
-- result = ROUND(3500*0.30*1.0, 0) = 1,050

-- goal_mult=1.2 (over-achievement tier)
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode = N'LAOS_STAFF_INCENTIVE_PER_PRODUCT',
    @base_rate   = 3500,
    @weight_pct  = 0.30,
    @goal_mult   = 1.2;
-- result = 1,260

-- ── MANAGER Incentive LAOS (ไม่มี ROUND) ────────────────────────────────────
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode = N'LAOS_MGR_INCENTIVE_PER_PRODUCT',
    @base_rate   = 9000,
    @weight_pct  = 0.45,
    @goal_mult   = 1.0;
-- result = 4050.0000  (ไม่มี ROUND)

-- ── Edge case: goal_mult = 0 (ยอดต่ำกว่า threshold ขั้นต่ำ) ────────────────
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode = N'LAOS_STAFF_INCENTIVE_PER_PRODUCT',
    @base_rate   = 3500,
    @weight_pct  = 0.30,
    @goal_mult   = 0;
-- result = 0.0000
```

---

## 4. ตรวจ product mapping LAOS

LAOS ใช้ SKU format → ต้องตรวจก่อนว่า mapping ถูกต้อง

```sql
-- ดู product code ใน target ของ LAOS และ mapping ที่จะเกิดขึ้น
SELECT DISTINCT
    t.product_code AS laos_product_code,
    CASE
        WHEN t.product_code LIKE N'SKU-A-%' THEN N'AJ'
        WHEN t.product_code LIKE N'SKU-B-%' THEN N'BD'
        WHEN t.product_code LIKE N'SKU-R-%' THEN N'RD'
        WHEN t.product_code LIKE N'SKU-Y-%' THEN N'YY'
        ELSE t.product_code
    END AS mapped_product_code
FROM dbo.trn_sales_target t
JOIN dbo.mst_channel c ON c.channel_id = t.channel_id AND c.channel_code = N'LAOS'
ORDER BY t.product_code;

-- ตรวจว่า mapped product มีใน mst_product จริง
SELECT
    CASE
        WHEN t.product_code LIKE N'SKU-A-%' THEN N'AJ'
        WHEN t.product_code LIKE N'SKU-B-%' THEN N'BD'
        WHEN t.product_code LIKE N'SKU-R-%' THEN N'RD'
        WHEN t.product_code LIKE N'SKU-Y-%' THEN N'YY'
        ELSE t.product_code
    END AS mapped_code,
    p.product_id,
    p.product_name_th
FROM (SELECT DISTINCT product_code FROM dbo.trn_sales_target
      WHERE channel_id=(SELECT channel_id FROM dbo.mst_channel WHERE channel_code=N'LAOS')) t
LEFT JOIN dbo.mst_product p ON p.product_code =
    CASE
        WHEN t.product_code LIKE N'SKU-A-%' THEN N'AJ'
        WHEN t.product_code LIKE N'SKU-B-%' THEN N'BD'
        WHEN t.product_code LIKE N'SKU-R-%' THEN N'RD'
        WHEN t.product_code LIKE N'SKU-Y-%' THEN N'YY'
        ELSE t.product_code
    END
ORDER BY mapped_code;
```

---

## 5. ตรวจสอบก่อน/หลัง Run

```sql
-- ตรวจ readiness LAOS
SELECT
    p.period_id, p.period_code,
    COUNT(t.salesman_code) AS target_rows,
    COUNT(a.salesman_code) AS actual_rows,
    CASE WHEN COUNT(t.salesman_code)>0 AND COUNT(a.salesman_code)>0 THEN '✅ Ready' ELSE '❌ Not Ready' END AS status
FROM dbo.mst_period p
JOIN dbo.mst_channel c ON c.channel_code = N'LAOS'
LEFT JOIN dbo.trn_sales_target t ON t.period_id=p.period_id AND t.channel_id=c.channel_id
LEFT JOIN dbo.trn_sales_actual a ON a.period_id=p.period_id AND a.channel_id=c.channel_id
GROUP BY p.period_id, p.period_code
ORDER BY p.period_id;

-- ตรวจ org_hierarchy ของ LAOS (ws_type ของ salesman)
SELECT h.salesman_code, h.ws_type, h.effective_month, h.is_active
FROM dbo.mst_org_hierarchy h
WHERE h.channel_id = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code=N'LAOS')
  AND h.is_active = 1
ORDER BY h.salesman_code;
```

---

## 6. Troubleshooting

| Error | สาเหตุ | วิธีแก้ |
|---|---|---|
| `Laos channel not found` | `mst_channel` ไม่มี channel_code='LAOS' | ตรวจ `SELECT * FROM dbo.mst_channel WHERE channel_code=N'LAOS'` |
| `Period code not found` | `@PeriodCode` ไม่มีใน `mst_period` | ตรวจชื่อ period_code เช่น `'FY2026-04'` |
| `No Laos target rows for period` | `trn_sales_target` ไม่มีข้อมูล LAOS ของ period นั้น | Import target LAOS ก่อน run |
| ผล `incentive_amount = 0` ทุกแถว | Product mapping ไม่เจอใน `mst_product` หรือ `mst_product_weight` ว่าง | ตรวจ product mapping และ mst_product_weight ของ LAOS |
| `product_weight = 0` | `mst_product_weight` ไม่มีข้อมูล ws_type + product ที่ถูก map | เพิ่มข้อมูล `mst_product_weight` ของ LAOS + ws_type ที่ใช้ |
