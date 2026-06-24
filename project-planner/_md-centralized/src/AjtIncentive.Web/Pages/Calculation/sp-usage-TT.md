# SP Usage Guide — TT Channel (Trade Traditional)
> หน้า http://localhost:5288/Calculation/TT

---

## Stored Procedures ที่ใช้ในหน้านี้

| SP | วัตถุประสงค์ | ปุ่มบนหน้าเว็บ |
|---|---|---|
| `dbo.usp_run_tt_incentive_calculation` | คำนวณ incentive TT ทีละ ws_type บันทึกผลลง DB | **Run TT Calculation** (รันทุก ws_type อัตโนมัติ) |
| `dbo.usp_formula_expression_preview` | Preview ผลคำนวณโดยไม่บันทึก | **Preview** |
| `dbo.usp_formula_expression_evaluate` | ทดสอบสูตรรายตัว | (ไม่มีปุ่ม — ใช้ผ่าน SSMS) |

> หน้าเว็บจะรัน `usp_run_tt_incentive_calculation` ครบทุก ws_type (`TOP_WS`, `WS_SF`, `WS_WH`) ในคราวเดียวอัตโนมัติ  
> หากต้องการรันทีละ ws_type ให้ใช้ SSMS โดยตรงตามตัวอย่างด้านล่าง

---

## 1. usp_run_tt_incentive_calculation

### Signature

```sql
CREATE PROCEDURE dbo.usp_run_tt_incentive_calculation
    @PeriodCode NVARCHAR(40),           -- required: period_code จาก mst_period เช่น 'FY2026-04'
    @WsType     NVARCHAR(40),           -- required: 'TOP_WS' | 'WS_SF' | 'WS_WH'
    @ApprovedBy NVARCHAR(200) = NULL    -- ชื่อผู้อนุมัติ (optional)
```

### Output (1 แถว)

| Column | Type | คำอธิบาย |
|---|---|---|
| `calc_run_id` | INT | รหัสรอบคำนวณ |
| `channel_code` | NVARCHAR | `'TT'` |
| `period_code` | NVARCHAR | period ที่คำนวณ |
| `ws_type` | NVARCHAR | ws_type ที่รันในครั้งนี้ |
| `status` | NVARCHAR | `'SUCCESS'` |
| `detail_rows` | INT | จำนวนแถวใน `trn_incentive_detail` |
| `for_hr_rows` | INT | จำนวนแถวใน `out_for_hr_variable` |

### ตรวจ ws_type ที่มีในระบบ

```sql
-- ws_type ที่มีอยู่จริงในระบบ TT
SELECT DISTINCT ws_type
FROM dbo.vw_tt_salesman_ws_type
WHERE ws_type IS NOT NULL
ORDER BY ws_type;
-- ผล: TOP_WS, WS_SF, WS_WH
```

### ตัวอย่าง EXEC — รันจริง (ทีละ ws_type)

```sql
-- ── ตรวจ period ที่พร้อมก่อน ──────────────────────────────────────────────
SELECT p.period_id, p.period_code,
       COUNT(t.salesman_code) AS target_rows,
       (SELECT COUNT(*) FROM dbo.trn_sales_actual a
        WHERE a.period_id = p.period_id AND a.channel_id = c.channel_id) AS actual_rows
FROM dbo.mst_period p
CROSS JOIN dbo.mst_channel c
LEFT JOIN dbo.trn_sales_target t ON t.period_id = p.period_id AND t.channel_id = c.channel_id
WHERE c.channel_code = N'TT'
GROUP BY p.period_id, p.period_code, c.channel_id
ORDER BY p.period_id;

-- ── FY2026-04: รัน TOP_WS ─────────────────────────────────────────────────
EXEC dbo.usp_run_tt_incentive_calculation
    @PeriodCode = N'FY2026-04',
    @WsType     = N'TOP_WS',
    @ApprovedBy = N'system';

-- ── FY2026-04: รัน WS_SF ──────────────────────────────────────────────────
EXEC dbo.usp_run_tt_incentive_calculation
    @PeriodCode = N'FY2026-04',
    @WsType     = N'WS_SF',
    @ApprovedBy = N'system';

-- ── FY2026-04: รัน WS_WH ──────────────────────────────────────────────────
EXEC dbo.usp_run_tt_incentive_calculation
    @PeriodCode = N'FY2026-04',
    @WsType     = N'WS_WH',
    @ApprovedBy = N'system';

-- ── FY2026-05: รันทุก ws_type (สั่งต่อกัน) ──────────────────────────────
EXEC dbo.usp_run_tt_incentive_calculation @PeriodCode=N'FY2026-05', @WsType=N'TOP_WS', @ApprovedBy=N'system';
EXEC dbo.usp_run_tt_incentive_calculation @PeriodCode=N'FY2026-05', @WsType=N'WS_SF',  @ApprovedBy=N'system';
EXEC dbo.usp_run_tt_incentive_calculation @PeriodCode=N'FY2026-05', @WsType=N'WS_WH',  @ApprovedBy=N'system';
```

### Logic ที่ SP ทำ

1. สร้างหรืออัปเดต `trn_calc_run` (MERGE — เพื่อให้ calc_run_id เดิมถูกอัปเดตซ้ำได้)
2. ลบผลเก่าตาม `calc_run_id` นั้น
3. คำนวณ STAFF: ใช้ `mst_tt_ws_formula_matrix` สำหรับ `base_rate` + `weight_pct` ตาม ws_type
4. TT ใช้ **team achievement** สำหรับ WS_SF (ค่าเฉลี่ยทีม)
5. คำนวณ SECT_MGR/DEPT_MGR: avg `goal_multiplier` ของ subordinates
6. INSERT → `trn_incentive_detail` และ `out_for_hr_variable`

### ดูผลหลัง Run

```sql
-- ดูสรุป run ล่าสุดของ TT
SELECT r.calc_run_id, p.period_code, r.run_status, r.approved_by, r.updated_at,
       (SELECT COUNT(*) FROM dbo.trn_incentive_detail d WHERE d.calc_run_id = r.calc_run_id) AS detail_rows,
       (SELECT COUNT(*) FROM dbo.out_for_hr_variable h WHERE h.calc_run_id = r.calc_run_id)  AS for_hr_rows
FROM dbo.trn_calc_run r
JOIN dbo.mst_period p ON p.period_id = r.period_id
WHERE r.channel_id = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'TT')
ORDER BY r.calc_run_id DESC;

-- ดู detail incentive ของ run ล่าสุด TT (top 50)
SELECT TOP 50
    d.salesman_code, d.position_level_code, d.product_code,
    d.target_amount, d.actual_amount,
    d.achievement, d.goal_multiplier,
    d.incentive_base, d.product_weight, d.incentive_amount
FROM dbo.trn_incentive_detail d
WHERE d.calc_run_id = (
    SELECT TOP 1 calc_run_id FROM dbo.trn_calc_run
    WHERE channel_id = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'TT')
    ORDER BY calc_run_id DESC
)
ORDER BY d.salesman_code, d.product_code;
```

---

## 2. usp_formula_expression_preview (TT)

### Signature

```sql
CREATE PROCEDURE dbo.usp_formula_expression_preview
    @PeriodId    INT,
    @ChannelCode NVARCHAR(20) = NULL    -- 'TT' หรือ NULL = ทุก channel
```

> Preview ใช้ `@PeriodId` (INT) ไม่ใช่ `@PeriodCode`

### ตัวอย่าง EXEC

```sql
-- Preview TT: FY2026-04 (period_id=1)
EXEC dbo.usp_formula_expression_preview
    @PeriodId    = 1,
    @ChannelCode = N'TT';

-- Preview TT: FY2026-05 (period_id=2)
EXEC dbo.usp_formula_expression_preview
    @PeriodId    = 2,
    @ChannelCode = N'TT';
```

### Period Reference

| period_id | period_code | TT target_rows | TT actual_rows |
|---|---|---|---|
| 1 | FY2026-04 | 159 | 147 |
| 2 | FY2026-05 | 152 | 138 |

---

## 3. usp_formula_expression_evaluate — ทดสอบสูตร TT

### สูตรที่ใช้ใน TT

| formula_code | formula_step | ws_type | formula_expr |
|---|---|---|---|
| `SHARED_PCT_ACHIEVEMENT` | PCT_ACHIEVEMENT | — | `ROUND([actual_amount] / [target_amount], 4)` |
| `TT_TOPWS_INCENTIVE_PER_PRODUCT` | INCENTIVE_PER_PRODUCT | TOP_WS | `ROUND([base_rate] * [weight_pct] * [goal_mult], 0)` |
| `TT_WSSF_INCENTIVE_PER_PRODUCT` | INCENTIVE_PER_PRODUCT | WS_SF | `ROUND([base_rate] * [weight_pct] * [goal_mult], 0)` |
| `TT_SPECIAL_KPI_BONUS` | SPECIAL_KPI | — | `IIF([pct_achievement] >= [kpi_threshold], [bonus_amount], 0)` |

### ตัวอย่าง EXEC แยกสูตร

```sql
-- ── PCT_ACHIEVEMENT (ใช้ร่วมทุก channel) ───────────────────────────────────
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode   = N'SHARED_PCT_ACHIEVEMENT',
    @actual_amount = 950000,
    @target_amount = 1000000;
-- result = 0.9500

-- ── TOP_WS Incentive ─────────────────────────────────────────────────────────
-- base_rate=3,000 | weight_pct=0.25 | goal_mult=1.0
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode = N'TT_TOPWS_INCENTIVE_PER_PRODUCT',
    @base_rate   = 3000,
    @weight_pct  = 0.25,
    @goal_mult   = 1.0;
-- result = ROUND(3000*0.25*1.0, 0) = 750

-- goal_mult=1.3 (over-achievement)
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode = N'TT_TOPWS_INCENTIVE_PER_PRODUCT',
    @base_rate   = 3000,
    @weight_pct  = 0.25,
    @goal_mult   = 1.3;
-- result = 975

-- ── WS_SF Incentive (ใช้ team achievement) ──────────────────────────────────
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode = N'TT_WSSF_INCENTIVE_PER_PRODUCT',
    @base_rate   = 2500,
    @weight_pct  = 0.30,
    @goal_mult   = 0.8;
-- result = ROUND(2500*0.30*0.8, 0) = 600

-- ── SPECIAL_KPI_BONUS: ผ่าน threshold → ได้ bonus ──────────────────────────
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode     = N'TT_SPECIAL_KPI_BONUS',
    @pct_achievement = 0.95,
    @kpi_threshold   = 0.80,
    @bonus_amount    = 3000;
-- result = 3000.0000  (0.95 >= 0.80)

-- ── SPECIAL_KPI_BONUS: ไม่ผ่าน threshold → ไม่ได้ bonus ───────────────────
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode     = N'TT_SPECIAL_KPI_BONUS',
    @pct_achievement = 0.75,
    @kpi_threshold   = 0.80,
    @bonus_amount    = 3000;
-- result = 0.0000  (0.75 < 0.80)

-- ── SPECIAL_KPI_BONUS: พอดี threshold (boundary) ───────────────────────────
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode     = N'TT_SPECIAL_KPI_BONUS',
    @pct_achievement = 0.80,
    @kpi_threshold   = 0.80,
    @bonus_amount    = 3000;
-- result = 3000.0000  (IIF ใช้ >= ดังนั้นพอดีก็ได้ bonus)
```

---

## 4. ตรวจสอบก่อน/หลัง Run

```sql
-- ตรวจ readiness ของ TT
SELECT
    p.period_id, p.period_code,
    COUNT(DISTINCT t.salesman_code) AS target_salesman,
    COUNT(DISTINCT a.salesman_code) AS actual_salesman,
    CASE WHEN COUNT(t.salesman_code)>0 AND COUNT(a.salesman_code)>0 THEN '✅ Ready' ELSE '❌ Not Ready' END AS status
FROM dbo.mst_period p
JOIN dbo.mst_channel c ON c.channel_code = N'TT'
LEFT JOIN dbo.trn_sales_target t ON t.period_id=p.period_id AND t.channel_id=c.channel_id
LEFT JOIN dbo.trn_sales_actual a ON a.period_id=p.period_id AND a.channel_id=c.channel_id
GROUP BY p.period_id, p.period_code
ORDER BY p.period_id;

-- ตรวจ ws_type ของ salesman ใน TT
SELECT ws_type, COUNT(*) AS salesman_count
FROM dbo.vw_tt_salesman_ws_type
GROUP BY ws_type
ORDER BY ws_type;
```

---

## 5. Troubleshooting

| Error | สาเหตุ | วิธีแก้ |
|---|---|---|
| `Period code not found` | `@PeriodCode` ไม่มีใน `mst_period` | ตรวจชื่อ period_code ให้ตรง เช่น `'FY2026-04'` |
| `No TT target rows for period+ws_type` | ไม่มีข้อมูล target ของ ws_type นั้น | ตรวจ `trn_sales_target` และ org_hierarchy ของ salesman |
| ผล `incentive_amount = 0` ทั้งหมด | `mst_tt_ws_formula_matrix` ไม่มีข้อมูลของ ws_type นั้น | ตรวจ `mst_tt_ws_formula_matrix` ว่ามีข้อมูล ws_type + period |
| WS_SF ผล = 0 ทั้งหมด | ใช้ team achievement แต่ไม่มีข้อมูลทีม | ตรวจ org_hierarchy ว่ามี team mapping ครบ |
