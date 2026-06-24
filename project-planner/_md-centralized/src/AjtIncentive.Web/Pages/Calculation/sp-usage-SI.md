# SP Usage Guide — SI Channel (Sales Incentive)
> หน้า http://localhost:5288/Calculation/SI

---

## Stored Procedures ที่ใช้ในหน้านี้

| SP | วัตถุประสงค์ | ปุ่มบนหน้าเว็บ |
|---|---|---|
| `dbo.usp_run_si_incentive_calculation` | คำนวณ incentive SI และบันทึกผลลง DB | **Run SI Calculation** |
| `dbo.usp_formula_expression_preview` | Preview ผลคำนวณโดยไม่บันทึก | **Preview** |
| `dbo.usp_formula_expression_evaluate` | ทดสอบสูตรรายตัว | (ไม่มีปุ่ม — ใช้ผ่าน SSMS) |

---

## 1. usp_run_si_incentive_calculation

### Signature

```sql
CREATE PROCEDURE dbo.usp_run_si_incentive_calculation
    @PeriodId   INT,                    -- required: period_id จาก mst_period
    @ApprovedBy NVARCHAR(200) = NULL    -- ชื่อผู้อนุมัติ (optional)
```

### Output (1 แถว)

| Column | Type | คำอธิบาย |
|---|---|---|
| `calc_run_id` | INT | รหัสรอบคำนวณ |
| `channel_code` | NVARCHAR | `'SI'` |
| `period_id` | INT | period ที่คำนวณ |
| `status` | NVARCHAR | `'SUCCESS'` |
| `detail_rows` | INT | จำนวนแถวใน `trn_incentive_detail` |
| `for_hr_rows` | INT | จำนวนแถวใน `out_for_hr_variable` |

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
WHERE c.channel_code = N'SI'
GROUP BY p.period_id, p.period_code, c.channel_id
ORDER BY p.period_id;

-- ── Run SI: FY2026-04 (period_id=1) — มีข้อมูลทั้ง target และ actual ────
EXEC dbo.usp_run_si_incentive_calculation
    @PeriodId   = 1,
    @ApprovedBy = N'system';
```

### Period Reference (SI)

| period_id | period_code | target_rows | actual_rows | พร้อม run |
|---|---|---|---|---|
| 1 | FY2026-04 | 9 | 9 | ✅ |
| 2 | FY2026-05 | 0 | 0 | ❌ |

### Logic ที่ SP ทำ

1. ใช้ `ws_type = 'OLD'` แบบ fixed (ไม่มี ws_type concept แบบ TT)
2. Lookup position จาก `mst_employee`
3. `base_rate` จาก `mst_incentive_rate` โดย filter `ws_type = 'OLD'` + `position_level_id`
4. `weight_pct` จาก `mst_product_weight` โดย filter `ws_type = 'OLD'`
5. คำนวณ STAFF → SECT_MGR/DEPT_MGR
6. INSERT → `trn_incentive_detail` และ `out_for_hr_variable`

### ดูผลหลัง Run

```sql
-- ดูสรุป run ล่าสุดของ SI
SELECT r.calc_run_id, p.period_code, r.run_status, r.approved_by, r.updated_at,
       (SELECT COUNT(*) FROM dbo.trn_incentive_detail d WHERE d.calc_run_id = r.calc_run_id) AS detail_rows,
       (SELECT COUNT(*) FROM dbo.out_for_hr_variable h WHERE h.calc_run_id = r.calc_run_id)  AS for_hr_rows
FROM dbo.trn_calc_run r
JOIN dbo.mst_period p ON p.period_id = r.period_id
WHERE r.channel_id = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'SI')
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
    WHERE channel_id = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'SI')
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
    WHERE channel_id = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'SI')
    ORDER BY calc_run_id DESC
)
ORDER BY h.employee_code;
```

---

## 2. usp_formula_expression_preview (SI)

### Signature

```sql
CREATE PROCEDURE dbo.usp_formula_expression_preview
    @PeriodId    INT,
    @ChannelCode NVARCHAR(20) = NULL    -- 'SI' หรือ NULL = ทุก channel
```

### ตัวอย่าง EXEC

```sql
-- Preview SI: FY2026-04 (period_id=1)
EXEC dbo.usp_formula_expression_preview
    @PeriodId    = 1,
    @ChannelCode = N'SI';
```

---

## 3. usp_formula_expression_evaluate — ทดสอบสูตร SI

### สูตรที่ใช้ใน SI

| formula_code | formula_step | formula_expr |
|---|---|---|
| `SHARED_PCT_ACHIEVEMENT` | PCT_ACHIEVEMENT | `ROUND([actual_amount] / [target_amount], 4)` |
| `SI_STAFF_INCENTIVE_PER_PRODUCT` | INCENTIVE_PER_PRODUCT | `ROUND([base_rate] * [weight_pct] * [goal_mult], 0)` |
| `SI_MGR_INCENTIVE_PER_PRODUCT` | INCENTIVE_PER_PRODUCT | `[base_rate] * [weight_pct] * [goal_mult]` |

> SI ไม่มีสูตร ROLLUP แยกต่างหาก — ผลรวมคำนวณใน SP โดยตรง  
> SI ไม่มี SPECIAL_KPI

### ตัวอย่าง EXEC แยกสูตร

```sql
-- ── PCT_ACHIEVEMENT ─────────────────────────────────────────────────────────
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode   = N'SHARED_PCT_ACHIEVEMENT',
    @actual_amount = 720000,
    @target_amount = 800000;
-- result = ROUND(720000/800000, 4) = 0.9000

-- ── STAFF Incentive ──────────────────────────────────────────────────────────
-- ws_type='OLD' | base_rate=4,000 | weight_pct=0.40 | goal_mult=1.0
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode = N'SI_STAFF_INCENTIVE_PER_PRODUCT',
    @base_rate   = 4000,
    @weight_pct  = 0.40,
    @goal_mult   = 1.0;
-- result = ROUND(4000*0.40*1.0, 0) = 1,600

-- goal_mult=1.2
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode = N'SI_STAFF_INCENTIVE_PER_PRODUCT',
    @base_rate   = 4000,
    @weight_pct  = 0.40,
    @goal_mult   = 1.2;
-- result = 1,920

-- ── MANAGER Incentive (ไม่มี ROUND) ─────────────────────────────────────────
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode = N'SI_MGR_INCENTIVE_PER_PRODUCT',
    @base_rate   = 10000,
    @weight_pct  = 0.50,
    @goal_mult   = 1.0;
-- result = 5000.0000  (ไม่มี ROUND)

-- ── Edge case: target = 0 → ควรได้ error ─────────────────────────────────────
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode   = N'SHARED_PCT_ACHIEVEMENT',
    @actual_amount = 500000,
    @target_amount = 0;
-- ERROR 50003: division by zero — ตรวจสอบ target ก่อน Run จริง
```

---

## 4. ตรวจสอบก่อน/หลัง Run

```sql
-- ตรวจ master data SI (ws_type='OLD')
SELECT ir.position_level_id, pl.position_code, ir.ws_type,
       ir.rate_old, ir.rate_new, ir.effective_from, ir.effective_to
FROM dbo.mst_incentive_rate ir
JOIN dbo.mst_position_level pl ON pl.position_level_id = ir.position_level_id
WHERE ir.channel_id = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code=N'SI')
  AND ir.ws_type = N'OLD'
  AND ir.is_active = 1
ORDER BY pl.hierarchy_level;

-- ตรวจ product weight SI (ws_type='OLD')
SELECT p.product_code, pw.weight_percent, pw.ws_type, pw.effective_from
FROM dbo.mst_product_weight pw
JOIN dbo.mst_product p ON p.product_id = pw.product_id
WHERE pw.channel_id = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code=N'SI')
  AND pw.ws_type = N'OLD'
  AND pw.is_active = 1;

-- ตรวจ readiness SI
SELECT
    p.period_id, p.period_code,
    COUNT(t.salesman_code)  AS target_rows,
    COUNT(a.salesman_code)  AS actual_rows,
    CASE WHEN COUNT(t.salesman_code)>0 AND COUNT(a.salesman_code)>0 THEN '✅ Ready' ELSE '❌ Not Ready' END AS status
FROM dbo.mst_period p
JOIN dbo.mst_channel c ON c.channel_code = N'SI'
LEFT JOIN dbo.trn_sales_target t ON t.period_id=p.period_id AND t.channel_id=c.channel_id
LEFT JOIN dbo.trn_sales_actual a ON a.period_id=p.period_id AND a.channel_id=c.channel_id
GROUP BY p.period_id, p.period_code
ORDER BY p.period_id;
```

---

## 5. Troubleshooting

| Error | สาเหตุ | วิธีแก้ |
|---|---|---|
| `No target rows found for period` | `trn_sales_target` ไม่มีข้อมูล SI ของ period นั้น | Import target SI ก่อน |
| ผล `incentive_amount = 0` ทุกแถว | `mst_incentive_rate` หรือ `mst_product_weight` ไม่มีข้อมูล ws_type='OLD' | ตรวจ master data ของ SI |
| ไม่มีผลออกมาเลย | `mst_employee` ไม่มีข้อมูล SI หรือ `is_active = 0` | ตรวจ `mst_employee` ว่า channel_id ตรง SI และ is_active=1 |
