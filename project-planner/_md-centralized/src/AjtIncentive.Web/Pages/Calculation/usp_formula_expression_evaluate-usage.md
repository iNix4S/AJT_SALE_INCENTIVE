# วิธีใช้งาน dbo.usp_formula_expression_evaluate สำหรับหน้า Calculation/MT และ Calculation/TT

เอกสารนี้ใช้สำหรับทดสอบสูตรรายตัว (formula-level) ก่อนกด Run จริงบนหน้า:

- http://localhost:5288/Calculation/MT
- http://localhost:5288/Calculation/TT

---

## 1) บทบาทของ evaluate เทียบกับ preview/run

| คำสั่ง | เรียกอะไร | ทำอะไร |
|---|---|---|
| ปุ่ม **Preview** บนหน้า MT/TT | `dbo.usp_formula_expression_preview` | จำลองผลคำนวณทั้งชุด (ทุก salesman × product ของ period นั้น) |
| ปุ่ม **Run** บนหน้า MT/TT | `dbo.usp_run_mt_incentive_calculation` / `usp_run_tt_incentive_calculation` | คำนวณจริงและบันทึกผลลง DB |
| **evaluate** (เอกสารนี้) | `dbo.usp_formula_expression_evaluate` | ทดสอบสูตรเดี่ยวรายตัวด้วยค่าตัวแปรที่กำหนดเอง ไม่บันทึกผล |

---

## 2) Signature จริงของ SP

```sql
CREATE PROCEDURE dbo.usp_formula_expression_evaluate
    @FormulaCode               NVARCHAR(100),          -- required: ชื่อ formula_code ใน mst_formula_expression
    @actual_amount             DECIMAL(18,4) = 0,
    @target_amount             DECIMAL(18,4) = 1,       -- default = 1 เพื่อป้องกัน ÷ 0
    @base_rate                 DECIMAL(18,4) = 0,
    @weight_pct                DECIMAL(18,10) = 0,
    @goal_mult                 DECIMAL(9,4)   = 0,
    @pct_achievement           DECIMAL(9,4)   = 0,
    @kpi_threshold             DECIMAL(9,4)   = 0,
    @bonus_amount              DECIMAL(18,4)  = 0,
    @sum_incentive_per_product DECIMAL(18,4)  = 0
```

SP จะ:
1. Lookup สูตรจาก `dbo.vw_formula_expression_active` ตาม `@FormulaCode`
2. แทนค่า `[variable_name]` ด้วยตัวเลขที่ส่งเข้ามา
3. Execute ด้วย `sp_executesql` (dynamic SQL)
4. คืน result set **1 แถว** ดังนี้:

| Column | คำอธิบาย |
|---|---|
| `formula_code` | ชื่อ formula ที่ทดสอบ |
| `formula_name` | ชื่อเต็มภาษาไทย |
| `formula_step` | PCT_ACHIEVEMENT / INCENTIVE_PER_PRODUCT / ROLLUP / SPECIAL_KPI |
| `formula_expr` | สูตรต้นฉบับ (มี `[variable]`) |
| `sql_expr_evaluated` | สูตรหลังแทนค่าตัวแปรแล้ว (ใช้ debug) |
| `var_actual_amount` … `var_sum_incentive` | ค่าตัวแปรที่ส่งเข้า |
| `result` | ผลลัพธ์ `DECIMAL(18,4)` |

---

## 3) สูตรที่ใช้งานจริงในหน้า MT และ TT

ดึงจาก `dbo.vw_formula_expression_active` ณ วันที่ตรวจสอบ:

| formula_code | formula_name | formula_step | channel | ws_type | formula_expr |
|---|---|---|---|---|---|
| `SHARED_PCT_ACHIEVEMENT` | % Achievement (ทุก Channel) | PCT_ACHIEVEMENT | SHARED | — | `ROUND([actual_amount] / [target_amount], 4)` |
| `MT_STAFF_INCENTIVE_PER_PRODUCT` | MT Staff: Incentive ต่อ Product | INCENTIVE_PER_PRODUCT | MT | — | `ROUND([base_rate] * [weight_pct] * [goal_mult], 0)` |
| `MT_DEPT_MGR_INCENTIVE_PER_PRODUCT` | MT Dept Mgr: Incentive ต่อ Product | INCENTIVE_PER_PRODUCT | MT | — | `ROUND([base_rate] * [weight_pct] * [goal_mult], 0)` |
| `MT_SECT_MGR_INCENTIVE_PER_PRODUCT` | MT Sect Mgr: Incentive ต่อ Product | INCENTIVE_PER_PRODUCT | MT | — | `[base_rate] * [weight_pct] * [goal_mult]` |
| `MT_AD_INCENTIVE_PER_PRODUCT` | MT AD: Incentive ต่อ Product | INCENTIVE_PER_PRODUCT | MT | — | `[base_rate] * [weight_pct] * [goal_mult]` |
| `MT_ROLLUP_INCENTIVE` | MT: รวม Incentive ทุก Product | ROLLUP | MT | — | `ROUND([sum_incentive_per_product], 2)` |
| `TT_TOPWS_INCENTIVE_PER_PRODUCT` | TT TopWS: Incentive ต่อ Product | INCENTIVE_PER_PRODUCT | TT | TOP_WS | `ROUND([base_rate] * [weight_pct] * [goal_mult], 0)` |
| `TT_WSSF_INCENTIVE_PER_PRODUCT` | TT WS-SF: Incentive ต่อ Product (Team) | INCENTIVE_PER_PRODUCT | TT | WS_SF | `ROUND([base_rate] * [weight_pct] * [goal_mult], 0)` |
| `TT_SPECIAL_KPI_BONUS` | TT: Special KPI Bonus | SPECIAL_KPI | TT | — | `IIF([pct_achievement] >= [kpi_threshold], [bonus_amount], 0)` |

---

## 4) ตัวอย่างการเรียก SP แยกรายสูตร — หน้า MT

### 4.1 SHARED_PCT_ACHIEVEMENT — คำนวณ % ยอดขาย

```sql
-- ยอดจริง 850,000 / เป้า 1,000,000 = 0.8500
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode   = N'SHARED_PCT_ACHIEVEMENT',
    @actual_amount = 850000,
    @target_amount = 1000000;
-- result = 0.8500
-- sql_expr_evaluated = ROUND(850000 / 1000000, 4)
```

### 4.2 MT_STAFF_INCENTIVE_PER_PRODUCT — Incentive พนักงาน Staff

```sql
-- base_rate=5000, weight_pct=0.35, goal_mult=1.0 (บรรลุเป้า 80-99%)
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode = N'MT_STAFF_INCENTIVE_PER_PRODUCT',
    @base_rate   = 5000,
    @weight_pct  = 0.35,
    @goal_mult   = 1.0;
-- result = 1750.0000
-- sql_expr_evaluated = ROUND(5000 * 0.35 * 1.0, 0)
```

```sql
-- goal_mult=1.2 (บรรลุเป้า ≥ 100%)
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode = N'MT_STAFF_INCENTIVE_PER_PRODUCT',
    @base_rate   = 5000,
    @weight_pct  = 0.35,
    @goal_mult   = 1.2;
-- result = 2100.0000
```

### 4.3 MT_DEPT_MGR_INCENTIVE_PER_PRODUCT — Incentive Dept Manager

```sql
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode = N'MT_DEPT_MGR_INCENTIVE_PER_PRODUCT',
    @base_rate   = 8000,
    @weight_pct  = 0.40,
    @goal_mult   = 1.2;
-- result = 3840.0000
```

### 4.4 MT_SECT_MGR_INCENTIVE_PER_PRODUCT — Incentive Section Manager (ไม่มี ROUND)

```sql
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode = N'MT_SECT_MGR_INCENTIVE_PER_PRODUCT',
    @base_rate   = 12000,
    @weight_pct  = 0.50,
    @goal_mult   = 1.0;
-- result = 6000.0000
-- sql_expr_evaluated = 12000 * 0.50 * 1.0  (ไม่มี ROUND)
```

### 4.5 MT_AD_INCENTIVE_PER_PRODUCT — Incentive Area Director

```sql
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode = N'MT_AD_INCENTIVE_PER_PRODUCT',
    @base_rate   = 20000,
    @weight_pct  = 0.60,
    @goal_mult   = 1.5;
-- result = 18000.0000
```

### 4.6 MT_ROLLUP_INCENTIVE — รวม Incentive ทุก Product ของ Salesman คนหนึ่ง

```sql
-- ตัวอย่าง: Salesman มี incentive รวม 3 product = 1750 + 2100 + 1050
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode               = N'MT_ROLLUP_INCENTIVE',
    @sum_incentive_per_product = 4900;
-- result = 4900.00
-- sql_expr_evaluated = ROUND(4900, 2)
```

---

## 5) ตัวอย่างการเรียก SP แยกรายสูตร — หน้า TT

### 5.1 TT_TOPWS_INCENTIVE_PER_PRODUCT — Incentive สำหรับ ws_type = TOP_WS

```sql
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode = N'TT_TOPWS_INCENTIVE_PER_PRODUCT',
    @base_rate   = 3000,
    @weight_pct  = 0.25,
    @goal_mult   = 1.0;
-- result = 750.0000
-- sql_expr_evaluated = ROUND(3000 * 0.25 * 1.0, 0)
```

```sql
-- goal_mult=1.3 (bonus tier)
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode = N'TT_TOPWS_INCENTIVE_PER_PRODUCT',
    @base_rate   = 3000,
    @weight_pct  = 0.25,
    @goal_mult   = 1.3;
-- result = 975.0000
```

### 5.2 TT_WSSF_INCENTIVE_PER_PRODUCT — Incentive สำหรับ ws_type = WS_SF (ใช้ team achievement)

```sql
-- WS_SF ใช้ค่าเฉลี่ย team pct_achievement แทน individual
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode = N'TT_WSSF_INCENTIVE_PER_PRODUCT',
    @base_rate   = 2500,
    @weight_pct  = 0.30,
    @goal_mult   = 0.8;
-- result = 600.0000
-- sql_expr_evaluated = ROUND(2500 * 0.30 * 0.8, 0)
```

### 5.3 TT_SPECIAL_KPI_BONUS — bonus พิเศษเมื่อ % achievement ผ่าน threshold

```sql
-- กรณีผ่าน KPI threshold → ได้ bonus
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode     = N'TT_SPECIAL_KPI_BONUS',
    @pct_achievement = 0.95,
    @kpi_threshold   = 0.80,
    @bonus_amount    = 3000;
-- result = 3000.0000  (เพราะ 0.95 >= 0.80)
-- sql_expr_evaluated = IIF(0.95 >= 0.80, 3000, 0)
```

```sql
-- กรณีไม่ผ่าน KPI threshold → ไม่ได้ bonus
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode     = N'TT_SPECIAL_KPI_BONUS',
    @pct_achievement = 0.75,
    @kpi_threshold   = 0.80,
    @bonus_amount    = 3000;
-- result = 0.0000  (เพราะ 0.75 < 0.80)
```

---

## 6) Workflow แนะนำก่อนกด Run จริงบนหน้า MT/TT

```
หน้า MT                              หน้า TT
──────────────────────               ──────────────────────────────────
1. เลือก Period                       1. เลือก Period
2. evaluate SHARED_PCT_ACHIEVEMENT   2. evaluate SHARED_PCT_ACHIEVEMENT
3. evaluate MT_STAFF_INCENTIVE_PER_PRODUCT  3. evaluate TT_TOPWS_INCENTIVE_PER_PRODUCT
   evaluate MT_DEPT_MGR_INCENTIVE_PER_PRODUCT  evaluate TT_WSSF_INCENTIVE_PER_PRODUCT
   evaluate MT_SECT_MGR_INCENTIVE_PER_PRODUCT  evaluate TT_SPECIAL_KPI_BONUS
   evaluate MT_AD_INCENTIVE_PER_PRODUCT
4. evaluate MT_ROLLUP_INCENTIVE
5. กด Preview → ตรวจผลรวม            4. กด Preview → ตรวจผลรวม
6. กด Run MT Calculation              5. กด Run TT Calculation (ทุก ws_type)
```

---

## 7) ชุดทดสอบ edge cases สำคัญ

```sql
-- [MT/TT] กรณี target = 0 → SP ใช้ default 1 หาก target_amount ส่งมาเป็น 0
-- ควรระวัง: ถ้าส่ง target_amount=0 เข้าจริง ผลจะ error เนื่องจาก ÷ 0
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode   = N'SHARED_PCT_ACHIEVEMENT',
    @actual_amount = 500000,
    @target_amount = 0;
-- ERROR 50003: division by zero — ต้องแน่ใจว่า target ไม่เป็น 0 ก่อน Run จริง

-- [MT/TT] กรณี over-achievement (actual > target)
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode   = N'SHARED_PCT_ACHIEVEMENT',
    @actual_amount = 1200000,
    @target_amount = 1000000;
-- result = 1.2000

-- [TT] กรณี KPI พอดี threshold (boundary)
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode     = N'TT_SPECIAL_KPI_BONUS',
    @pct_achievement = 0.80,
    @kpi_threshold   = 0.80,
    @bonus_amount    = 3000;
-- result = 3000.0000  (IIF ใช้ >=, ดังนั้น พอดีก็ได้ bonus)

-- [MT] กรณีตัวแปรที่ไม่เกี่ยวถูกปล่อยเป็น default 0 — ไม่เป็นปัญหา
EXEC dbo.usp_formula_expression_evaluate
    @FormulaCode = N'MT_ROLLUP_INCENTIVE',
    @sum_incentive_per_product = 0;
-- result = 0.00  (valid)
```

---

## 8) ตรวจสูตร active ก่อนใช้งาน

```sql
-- ดูสูตรทั้งหมดที่ active สำหรับ MT และ TT
SELECT formula_code, formula_name, formula_step, channel_code, ws_type, formula_expr
FROM dbo.vw_formula_expression_active
WHERE channel_code IN (N'MT', N'TT', N'SHARED')
ORDER BY channel_code, formula_step, sort_order;

-- ตรวจ signature SP ล่าสุดจากฐานข้อมูล
SELECT p.parameter_id, p.name AS parameter_name,
       TYPE_NAME(p.user_type_id) AS data_type,
       p.max_length, p.precision, p.scale, p.is_output
FROM sys.parameters p
WHERE p.object_id = OBJECT_ID(N'dbo.usp_formula_expression_evaluate')
ORDER BY p.parameter_id;
```

---

## 9) Troubleshooting เร็ว

| Error | สาเหตุ | วิธีแก้ |
|---|---|---|
| `Error 50001` — Formula code ไม่พบ | `@FormulaCode` ไม่มีใน `vw_formula_expression_active` หรือ effective date หมดอายุ | ตรวจ formula_code และ effective_from/effective_to |
| `Error 50002` — มีตัวแปรที่ไม่ถูกแทนค่า | สูตรมี `[variable]` ที่ไม่ใช่ 9 ตัวที่รู้จัก | ดู `formula_expr` แล้วตรวจชื่อตัวแปรให้ตรง |
| `Error 50003` — division by zero | ส่ง `@target_amount = 0` เข้าสูตร `SHARED_PCT_ACHIEVEMENT` | ตรวจสอบว่า target ≥ 1 ก่อนเรียก |
| ผล evaluate ≠ ผล preview | ตัวแปรที่ส่งเข้า evaluate ไม่ตรงกับข้อมูลจริงของ period/channel | เปรียบเทียบค่าจาก `trn_sales_target`, `mst_incentive_rate`, `mst_goal_threshold` ของ period เดียวกัน |

---

## 10) ข้อควรระวังในทีม

- ใช้ evaluate ทุกครั้งที่แก้ `formula_expr` ใน `mst_formula_expression` ก่อน commit
- `@target_amount` มี default = 1 (ไม่ใช่ 0) เพื่อป้องกัน division by zero — ถ้าจะทดสอบ target จริงต้องส่งค่าเข้ามาเสมอ
- `IIF` ใน SP ถูก normalize เป็น `if()` ของ NCalc ก่อนรัน — ถ้าดู `sql_expr_evaluated` จาก SP จะยังเห็น `IIF` เพราะ SP รัน dynamic SQL ตรง ไม่ผ่าน NCalc
- สูตร MT_SECT_MGR และ MT_AD **ไม่มี ROUND** — ผลอาจมีทศนิยมหลายตำแหน่ง ถ้าธุรกิจต้องการปัดเศษให้แจ้ง DBA แก้ `formula_expr`
