# SP Usage Guide — MT Channel (Modern Trade)
> หน้า http://localhost:5288/Calculation/MT

---

## Stored Procedures ที่ใช้ในหน้านี้

| SP | วัตถุประสงค์ | ปุ่มบนหน้าเว็บ |
|---|---|---|
| `dbo.usp_run_mt_incentive_calculation` | คำนวณ incentive MT และบันทึกผลลง DB | **Run MT Calculation** |
| `dbo.usp_formula_expression_preview` | Preview ผลคำนวณโดยไม่บันทึก | **Preview** |
| `dbo.usp_formula_expression_evaluate` | ทดสอบสูตรรายตัว | (ไม่มีปุ่ม — ใช้ผ่าน SSMS) |

---

## 1. usp_run_mt_incentive_calculation

### Signature

```sql
CREATE PROCEDURE dbo.usp_run_mt_incentive_calculation
    @PeriodId   INT,                    -- required: period_id จาก mst_period
    @ApprovedBy NVARCHAR(200) = NULL    -- ชื่อผู้อนุมัติ (optional)
```

### Output (1 แถว)

| Column | Type | คำอธิบาย |
|---|---|---|
| `calc_run_id` | INT | รหัสรอบคำนวณที่สร้างใหม่/อัปเดต |
| `channel_code` | NVARCHAR | `'MT'` |
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
WHERE c.channel_code = N'MT'
GROUP BY p.period_id, p.period_code, c.channel_id
ORDER BY p.period_id;

-- ── Run MT: FY2026-04 (period_id=1) ────────────────────────────────────────
EXEC dbo.usp_run_mt_incentive_calculation
    @PeriodId   = 1,
    @ApprovedBy = N'system';

-- ── Run MT: FY2026-05 (period_id=2) ────────────────────────────────────────
EXEC dbo.usp_run_mt_incentive_calculation
    @PeriodId   = 2,
    @ApprovedBy = N'system';
```

### Logic ที่ SP ทำ

1. สร้างหรืออัปเดต `trn_calc_run` (status → RUNNING)
2. ลบผลเก่าออกจาก `trn_incentive_detail` และ `out_for_hr_variable`
3. คำนวณ STAFF: `base_rate × weight_pct × goal_multiplier` ต่อ product
4. คำนวณ MANAGER (SECT_MGR, DEPT_MGR, AD): ใช้ avg `goal_multiplier` ของ subordinates
5. INSERT ผลเข้า `trn_incentive_detail`
6. Aggregate ต่อ employee → INSERT เข้า `out_for_hr_variable`
7. อัปเดต `trn_calc_run` → status = CALCULATED

### ดูผลหลัง Run

```sql
-- ดูสรุป run ล่าสุดของ MT
SELECT r.calc_run_id, p.period_code, r.run_status, r.approved_by, r.updated_at,
       (SELECT COUNT(*) FROM dbo.trn_incentive_detail d WHERE d.calc_run_id = r.calc_run_id) AS detail_rows,
       (SELECT COUNT(*) FROM dbo.out_for_hr_variable h WHERE h.calc_run_id = r.calc_run_id)  AS for_hr_rows
FROM dbo.trn_calc_run r
JOIN dbo.mst_period p ON p.period_id = r.period_id
WHERE r.channel_id = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'MT')
ORDER BY r.calc_run_id DESC;

-- ดู detail incentive ของ run ล่าสุด (top 50)
SELECT TOP 50
    d.salesman_code, d.position_level_code, d.product_code,
    d.target_amount, d.actual_amount,
    d.achievement, d.goal_multiplier,
    d.incentive_base, d.product_weight, d.incentive_amount
FROM dbo.trn_incentive_detail d
WHERE d.calc_run_id = (
    SELECT TOP 1 calc_run_id FROM dbo.trn_calc_run
    WHERE channel_id = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'MT')
    ORDER BY calc_run_id DESC
)
ORDER BY d.salesman_code, d.product_code;

-- ดู For HR ของ run ล่าสุด
SELECT TOP 50
    h.employee_code, h.employee_name_th, h.position_level_code,
    h.incentive_staff, h.incentive_sect, h.incentive_dept, h.incentive_ad,
    h.total_variable
FROM dbo.out_for_hr_variable h
WHERE h.calc_run_id = (
    SELECT TOP 1 calc_run_id FROM dbo.trn_calc_run
    WHERE channel_id = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'MT')
    ORDER BY calc_run_id DESC
)
ORDER BY h.employee_code;
```

---

## 2. usp_formula_expression_preview (MT)

### Signature

```sql
CREATE PROCEDURE dbo.usp_formula_expression_preview
    @PeriodId    INT,
    @ChannelCode NVARCHAR(20) = NULL    -- 'MT' หรือ NULL = ทุก channel
```

### ตัวอย่าง EXEC

```sql
-- Preview MT: FY2026-04
EXEC dbo.usp_formula_expression_preview
    @PeriodId    = 1,
    @ChannelCode = N'MT';
```

### Output columns

`channel_code`, `salesman_code`, `position_code`, `ws_type_salesman`,
`product_code`, `target_amount`, `actual_amount`, `pct_achievement`,
`goal_mult`, `base_rate`, `weight_pct`,
`formula_code_pct`, `formula_expr_pct`,
`formula_code_incent`, `formula_expr_incent`,
`incentive_amount`

---

## 3. usp_formula_expression_evaluate — ทดสอบสูตร MT

### สูตรที่ใช้ใน MT

| formula_code | formula_step | formula_expr |
|---|---|---|
| `SHARED_PCT_ACHIEVEMENT` | PCT_ACHIEVEMENT | `ROUND([actual_amount] / [target_amount], 4)` |
| `MT_STAFF_INCENTIVE_PER_PRODUCT` | INCENTIVE_PER_PRODUCT | `ROUND([base_rate] * [weight_pct] * [goal_mult], 0)` |
| `MT_DEPT_MGR_INCENTIVE_PER_PRODUCT` | INCENTIVE_PER_PRODUCT | `ROUND([base_rate] * [weight_pct] * [goal_mult], 0)` |
| `MT_SECT_MGR_INCENTIVE_PER_PRODUCT` | INCENTIVE_PER_PRODUCT | `[base_rate] * [weight_pct] * [goal_mult]` |
| `MT_AD_INCENTIVE_PER_PRODUCT` | INCENTIVE_PER_PRODUCT | `[base_rate] * [weight_pct] * [goal_mult]` |
| `MT_ROLLUP_INCENTIVE` | ROLLUP | `ROUND([sum_incentive_per_product], 2)` |

### ตัวอย่าง EXEC แยกสูตร

```sql
-- ── PCT_ACHIEVEMENT ─────────────────────────────────────────────────────────
-- ยอดจริง 850,000 / เป้า 1,000,000 → 0.8500
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode   = N'SHARED_PCT_ACHIEVEMENT',
    @actual_amount = 850000,
    @target_amount = 1000000;

-- ── STAFF Incentive ──────────────────────────────────────────────────────────
-- base_rate=5,000, weight_pct=0.35, goal_mult=1.0 → ROUND(5000*0.35*1.0,0) = 1,750
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode = N'MT_STAFF_INCENTIVE_PER_PRODUCT',
    @base_rate   = 5000,
    @weight_pct  = 0.35,
    @goal_mult   = 1.0;

-- goal_mult=1.2 (over-achievement) → 2,100
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode = N'MT_STAFF_INCENTIVE_PER_PRODUCT',
    @base_rate   = 5000,
    @weight_pct  = 0.35,
    @goal_mult   = 1.2;

-- ── DEPT_MGR Incentive ───────────────────────────────────────────────────────
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode = N'MT_DEPT_MGR_INCENTIVE_PER_PRODUCT',
    @base_rate   = 8000,
    @weight_pct  = 0.40,
    @goal_mult   = 1.2;
-- result = ROUND(8000*0.40*1.2, 0) = 3,840

-- ── SECT_MGR Incentive (ไม่มี ROUND) ─────────────────────────────────────────
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode = N'MT_SECT_MGR_INCENTIVE_PER_PRODUCT',
    @base_rate   = 12000,
    @weight_pct  = 0.50,
    @goal_mult   = 1.0;
-- result = 6000.0000  (ไม่มี ROUND — อาจมีทศนิยม)

-- ── AD Incentive (ไม่มี ROUND) ───────────────────────────────────────────────
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode = N'MT_AD_INCENTIVE_PER_PRODUCT',
    @base_rate   = 20000,
    @weight_pct  = 0.60,
    @goal_mult   = 1.5;
-- result = 18000.0000

-- ── ROLLUP (รวม incentive ทุก product ของ salesman คนหนึ่ง) ─────────────────
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode               = N'MT_ROLLUP_INCENTIVE',
    @sum_incentive_per_product = 4900;
-- result = 4900.00
```

---

## 4. ตรวจสอบก่อน/หลัง Run

```sql
-- ตรวจ readiness
SELECT
    p.period_id, p.period_code,
    COUNT(t.salesman_code)  AS target_rows,
    COUNT(a.salesman_code)  AS actual_rows,
    CASE WHEN COUNT(t.salesman_code)>0 AND COUNT(a.salesman_code)>0 THEN '✅ Ready' ELSE '❌ Not Ready' END AS status
FROM dbo.mst_period p
JOIN dbo.mst_channel c ON c.channel_code = N'MT'
LEFT JOIN dbo.trn_sales_target t ON t.period_id=p.period_id AND t.channel_id=c.channel_id
LEFT JOIN dbo.trn_sales_actual a ON a.period_id=p.period_id AND a.channel_id=c.channel_id
GROUP BY p.period_id, p.period_code
ORDER BY p.period_id;

-- ตรวจผลคำนวณ (หลัง run)
SELECT r.calc_run_id, p.period_code, r.run_status, r.updated_at
FROM dbo.trn_calc_run r
JOIN dbo.mst_period p ON p.period_id = r.period_id
WHERE r.channel_id = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code=N'MT')
ORDER BY r.calc_run_id DESC;
```

---

## 5. Troubleshooting

| Error | สาเหตุ | วิธีแก้ |
|---|---|---|
| `No target rows found for period` | `trn_sales_target` ไม่มีข้อมูล MT ของ period นั้น | Import target ก่อน run |
| ผล `incentive_amount = 0` ทุกแถว | `base_rate = 0` หรือ `weight_pct = 0` ใน master | ตรวจ `mst_incentive_rate` และ `mst_product_weight` |
| `division by zero` ใน preview | มีแถวที่ `target_amount = 0` | กรอง target = 0 ออก หรือตรวจ import data |
| Error: ROLLBACK | ข้อมูลผิดพลาดระหว่าง transaction | ดู error message แล้วตรวจ master data |
