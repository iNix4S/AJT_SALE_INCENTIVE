# AJT TT Stored Procedures: usp_run_tt_incentive_calculation และ usp_check_tt_sheet_employee_reference

วันที่: 2026-06-15 (อัพเดท v3.0)  
ขอบเขต: อธิบายการทำงาน, parameters, flow, และความสัมพันธ์ระหว่าง SP ทั้งสอง

---

## ความสัมพันธ์ระหว่าง SP ทั้งสอง

```
[trn_sales_target]  [trn_sales_actual]  [mst_org_hierarchy]  [mst_*]
        │                   │                   │                │
        └───────────────────┴───────────────────┴────────────────┘
                                    │
                         usp_run_tt_incentive_calculation
                                    │ writes
                    ┌───────────────┴────────────────┐
                    ▼                                ▼
          trn_incentive_detail            out_for_hr_variable
          trn_tt_special_kpi_detail
                    │
                    └──────────────────────┐
                                           ▼
                         usp_check_tt_sheet_employee_reference
                                           │ returns
                              ┌────────────┼────────────┐
                              ▼            ▼            ▼
                          Context       For HR      PASS/FAIL
                          Coverage      Values      Lineage
```

**กฎ**: ต้องรัน `usp_run` ก่อนเสมอ ผล `usp_check` ขึ้นอยู่กับข้อมูลที่ `usp_run` เขียนไว้

---

## 1. `dbo.usp_run_tt_incentive_calculation`

### 1.1 Parameters

| Parameter | Type | Default | คำอธิบาย |
|---|---|---|---|
| `@PeriodCode` | NVARCHAR(20) | *(required)* | เช่น `N'FY2026-05'` |
| `@WsType` | NVARCHAR(50) | `N'TOP_WS'` | **fallback ws_type** ใช้เฉพาะตอน salesman ไม่มี row ใน `mst_org_hierarchy` |
| `@ApprovedBy` | NVARCHAR(100) | `N'system'` | บันทึกใน `trn_calc_run.approved_by` |

> **หมายเหตุ `@WsType`**: ตั้งแต่ v2.0 SP ทำ per-salesman ws_type lookup จาก `mst_org_hierarchy` ก่อน  
> `@WsType` จะมีผลเฉพาะตอน salesman ไม่มี row hierarchy เท่านั้น (fallback)  
> ถ้า hierarchy ครบทุกคน ใส่ค่าอะไรก็ได้ที่ valid: `TOP_WS`, `WS_SF`, `WS_WH`, `SF_WH`

---

### 1.2 ลำดับการทำงาน (Execution Flow)

#### Phase 0: Initialization & Validation
1. Lookup `channel_id` จาก `mst_channel` (channel_code = 'TT')
2. Lookup `period_id`, `sales_month` จาก `mst_period` ตาม `@PeriodCode`
3. Normalize `@LegacyWsType` จาก `@WsType` (แปลง 'OLD' → 'TOP_WS')
4. Guard: throw error ถ้าไม่มี rows ใน `trn_sales_target` สำหรับ period นี้
5. MERGE `trn_calc_run` — สร้างหรืออัปเดต run record, ดึง `@RunId`
6. Lookup `variable_pay_month` จาก `mst_payment_cycle`
7. **DELETE** ผลเก่า: `out_for_hr_variable`, `trn_incentive_detail`, `trn_tt_special_kpi_detail` ตาม `@RunId`

---

#### Phase 1: STAFF Calculation (CTE chain)

```
trn_sales_target        → target_src     (SUM target, MAX pct_salesman per salesman+product)
mst_org_hierarchy       → hier_ws        (lookup ws_type รายคน, fallback @LegacyWsType)
trn_sales_actual        → actual_src     (SUM actual per salesman+product)
target_src + actual_src + hier_ws → staff_join  (combine + extract base_product_code)
staff_join              → staff_map      (map product code: A→AJ, R→RD, Y→YY ฯลฯ)
trn_sales_target        → team_ach       (team achievement สำหรับ product ที่ใช้ร่วมกัน เช่น R, Y)
staff_map + wm + w + rs → staff_calc     (คำนวณ achievement, final_achievement, incentive_base, weight)
```

**formula matrix lookup** (OUTER APPLY `wm`):
```sql
mst_tt_ws_formula_matrix
WHERE ws_type = COALESCE(sm.ws_type, @LegacyWsType)  -- per-salesman ws_type
  AND product_id = p.product_id
  AND effective_from <= @SalesMonth
```

**incentive_staff formula**:
```
incentive_amount = incentive_base
                 × COALESCE(pct_salesman, goal_multiplier_from_threshold, 0)
                 × product_weight_percent
```

**INSERT** → `trn_incentive_detail` (position_level_code = 'STAFF')

---

#### Phase 2: Manager Cascade (SECT_MGR / DEPT_MGR / DIV_MGR / AD)

1. Snapshot ผล STAFF ลง `#staff_rows` (temp table) — รวม `goal_multiplier` column
2. Lookup sup codes ลง `#hier_pick` จาก `mst_org_hierarchy` (nearest effective_month)
3. CTE `mgr_raw` — UNION ALL 4 ระดับ: **GROUP BY manager_code** (ไม่แยก product), `product_code = N'*'`:
   - `achievement` = `AVG(CAST(s.goal_multiplier AS DECIMAL(18,6)))` ของ **ทุก product×staff row** ในสังกัด
   - ไม่มี floor-to-1.0 — manager ถูก penalized ได้ถ้า avg < 1.0
4. CTE `mgr_calc` — round เป็น DECIMAL(9,4) สำหรับแสดง + เก็บ `raw_achievement` (full precision) สำหรับคูณ
5. **INSERT** → `trn_incentive_detail` (position_level_code = SECT_MGR/DEPT_MGR/DIV_MGR/AD)

**manager rate lookup** (OUTER APPLY `rate_data`):
```sql
mst_incentive_rate
WHERE position_code = mc.position_level_code   -- แต่ละ level ได้ rate ของตัวเอง
  AND ws_type = @LegacyWsType                  -- (rate เหมือนกันทุก ws_type)
-- DIV_MGR fallback ไป DEPT_MGR rate ถ้าไม่พบ
```

**manager incentive formula** (v4.0 — ตาม T_SectAbove sheet):
```
incentive_amount = position_rate × AVG(goal_multiplier ของทุก product×staff row ในสังกัด)

position_rate (mst_incentive_rate.rate_new):
  SECT_MGR = 4,000  →  4,000 × 1.0842424... = 4,336.97
  DEPT_MGR = 5,000
  DIV_MGR  = 5,000  (fallback DEPT_MGR rate ถ้าไม่มี DIV_MGR row)
  AD       = 6,000

-- product_code = N'*' (one row per manager, ไม่แยก product)
-- ไม่มี threshold lookup — ใช้ raw avg โดยตรง
-- Manager ถูก penalized ได้ถ้า section avg < 1.0
```

> ตรวจ rate ปัจจุบัน: `SELECT * FROM dbo.vw_tt_incentive_rate WHERE is_active=1 ORDER BY hierarchy_level`

---

#### Phase 3: Special KPI Bonus

- นับ `avg_final_achievement` ต่อ salesman ต่อ g_group_code จาก #staff_rows
- Match กับ `mst_tt_special_kpi_rule` ที่ `kpi_threshold` ≤ avg_final_achievement
- **INSERT** → `trn_tt_special_kpi_detail`

> Special KPI ใช้ `@LegacyWsType` (ไม่แยกตาม per-salesman ws_type)

---

#### Phase 4: Aggregate → out_for_hr_variable

- CTE `agg` — SUM incentive ทุกระดับต่อ employee_code
- **INSERT** → `out_for_hr_variable`:

| คอลัมน์ | คำนวณจาก |
|---|---|
| `incentive_staff` | SUM จาก STAFF |
| `incentive_sect` | SUM จาก SECT_MGR |
| `incentive_dept` | SUM จาก DEPT_MGR |
| `incentive_div` | SUM จาก DIV_MGR |
| `incentive_ad` | SUM จาก AD |
| `gd_incentive_total` | SUM special_kpi_bonus |
| `total_variable` | staff + sect + dept + div + ad + special_kpi_bonus |

---

### 1.3 ตารางที่อ่าน / เขียน

| ตาราง | อ่าน | เขียน |
|---|---|---|
| `mst_channel` | ✓ | |
| `mst_period` | ✓ | |
| `mst_payment_cycle` | ✓ | |
| `mst_org_hierarchy` | ✓ (2 ครั้ง) | |
| `mst_tt_ws_formula_matrix` | ✓ | |
| `mst_product_weight` | ✓ | |
| `mst_incentive_rate` | ✓ (4 ครั้ง) | |
| `mst_goal_threshold` | ✓ (2 ครั้ง) | |
| `mst_product` | ✓ | |
| `mst_shortage_policy` | ✓ | |
| `mst_employee` | ✓ | |
| `mst_position_level` | ✓ | |
| `mst_tt_special_kpi_rule` | ✓ | |
| `trn_sales_target` | ✓ | |
| `trn_sales_actual` | ✓ | |
| `trn_calc_run` | ✓ | ✓ (MERGE) |
| `trn_incentive_detail` | | ✓ (DELETE + INSERT) |
| `trn_tt_special_kpi_detail` | | ✓ (DELETE + INSERT) |
| `out_for_hr_variable` | | ✓ (DELETE + INSERT) |

---

### 1.4 Error Codes

| Code | เงื่อนไข |
|---|---|
| 50001 | TT channel ไม่พบ |
| 50002 | period_code ไม่พบ |
| 50003 | ไม่มี target rows สำหรับ period นี้ |

---

## 2. `dbo.usp_check_tt_sheet_employee_reference`

### 2.1 Parameters

| Parameter | Type | Default | คำอธิบาย |
|---|---|---|---|
| `@PeriodCode` | NVARCHAR(20) | `N'FY2026-05'` | period ที่ต้องการตรวจ |
| `@EmployeeListCsv` | NVARCHAR(MAX) | *(required)* | salesman codes คั่นด้วย `,` `;` `\|` หรือ newline |
| `@ChannelCode` | NVARCHAR(20) | `N'TT'` | channel code |
| `@InputSheetName` | NVARCHAR(200) | `N'1) For HR'` | ชื่อ sheet ต้นทางสำหรับแสดงใน lineage |
| `@InputSheetFile` | NVARCHAR(260) | `N'15_1) For HR.values.csv'` | ชื่อไฟล์ต้นทางสำหรับแสดงใน lineage |

---

### 2.2 ลำดับการทำงาน

#### Initialization
1. Lookup `channel_id`, `period_id` จาก master tables
2. Lookup `calc_run_id` ล่าสุดสำหรับ channel+period จาก `trn_calc_run`
3. Guard: throw error ถ้า channel/period ไม่พบ หรือยังไม่เคยรัน calculation
4. Normalize CSV: แทน `\r`, `\n`, `;`, `|` ด้วย `,`
5. Parse → table variable `@sample` (DISTINCT salesman_codes)

#### Check Coverage per employee
สร้าง `@checks` table variable โดย check 5 ตาราง:

| Flag | ตาราง | เงื่อนไข |
|---|---|---|
| `in_target` | `trn_sales_target` | channel_id + period_id + salesman_code |
| `in_actual` | `trn_sales_actual` | channel_id + period_id + salesman_code |
| `in_hierarchy` | `mst_org_hierarchy` | channel_id + salesman_code |
| `in_employee` | `mst_employee` | channel_id + employee_code |
| `in_for_hr` | `out_for_hr_variable` | calc_run_id (ล่าสุด) + employee_code |

---

### 2.3 Result Sets (5 ชุด)

#### Result Set 1: Context
```
period_code | period_id | channel_id | channel_code | calc_run_id
input_employee_count | input_sheet_name | input_sheet_file | input_sheet_key_column
```
ใช้ยืนยันว่า SP อ่านถูก run และ period

---

#### Result Set 2: Coverage per employee
```
calc_run_id | sheet_salesman_code
in_target  | target_sheet_name  | target_sheet_file
in_actual  | actual_sheet_name  | actual_sheet_file
in_hierarchy | hierarchy_sheet_name | hierarchy_sheet_file
in_employee  | employee_sheet_name  | employee_sheet_file
in_for_hr    | for_hr_sheet_name    | for_hr_sheet_file
```
1 row ต่อ salesman — ดูว่าแต่ละคนมีข้อมูลครบใน pipeline ไหนบ้าง

---

#### Result Set 3: For HR Values
```
employee_code | incentive_staff | incentive_sect | incentive_dept
incentive_div | incentive_ad | gd_incentive_total | total_variable
```
ผลคำนวณจริงจาก `out_for_hr_variable` สำหรับ employees ที่ระบุ

---

#### Result Set 4: Summary (PASS / FAIL)
```
total_employees | pass_target | pass_actual | pass_hierarchy | pass_employee | pass_for_hr
e2e_status_without_employee_master   -- PASS ถ้า target + actual + hierarchy + for_hr ครบ
e2e_status_with_employee_master      -- PASS ถ้าทั้ง 5 อย่างครบ
```

> `e2e_status_without_employee_master` คือ status หลักที่ใช้ตัดสิน  
> เพราะ TT ปัจจุบัน `mst_employee` ยังไม่มีข้อมูล TT salesman ครบ

---

#### Result Set 5: Lineage Map
trace กลับจาก check → sheet/file/column → db target:
```
check_name | sheet_name | sheet_file | sheet_key_column | internal_target | note
```

---

### 2.4 Error Codes

| Code | เงื่อนไข |
|---|---|
| 58001 | channel_code ไม่พบ |
| 58002 | period_code ไม่พบ |
| 58003 | @EmployeeListCsv ว่าง |
| 58004 | ยังไม่มี calc_run สำหรับ period นี้ (ต้องรัน usp_run ก่อน) |
| 58005 | ไม่พบ employee code ที่ valid หลัง parse CSV |

---

## 3. Quick Reference

### รันปกติ (run แล้ว check)
```sql
-- Step 1: คำนวณ
EXEC dbo.usp_run_tt_incentive_calculation
    @PeriodCode = N'FY2026-05',
    @WsType     = N'TOP_WS',     -- fallback เท่านั้น ถ้า hierarchy ครบไม่มีผล
    @ApprovedBy = N'system';

-- Step 2: ตรวจ
EXEC dbo.usp_check_tt_sheet_employee_reference
    @PeriodCode      = N'FY2026-05',
    @EmployeeListCsv = N'110001,110002,110003,120001,120002,130001,130002,130003,140001,140002,140003,150001,160001,160002',
    @ChannelCode     = N'TT',
    @InputSheetName  = N'1) For HR',
    @InputSheetFile  = N'15_1) For HR.values.csv';
```

### ตรวจ ws_type ก่อนรัน (prerequisite check)
```sql
-- ทุกคนต้องมี ws_type ไม่เป็น NULL
SELECT * FROM dbo.vw_tt_salesman_ws_type
WHERE period_code = N'FY2026-05'
ORDER BY ws_type, salesman_code;

-- ตรวจ pct_salesman
SELECT salesman_code, product_code, pct_salesman
FROM dbo.trn_sales_target t
JOIN dbo.mst_period p ON p.period_id=t.period_id AND p.period_code='FY2026-05'
JOIN dbo.mst_channel c ON c.channel_id=t.channel_id AND c.channel_code='TT'
WHERE pct_salesman IS NULL;
```

### ดูผลสรุปรายคน
```sql
SELECT h.ws_type, o.employee_code, o.incentive_staff, o.gd_incentive_total, o.total_variable
FROM dbo.out_for_hr_variable o
JOIN dbo.trn_calc_run r ON r.calc_run_id=o.calc_run_id
JOIN dbo.mst_period p ON p.period_id=r.period_id AND p.period_code='FY2026-05'
JOIN dbo.mst_channel c ON c.channel_id=r.channel_id AND c.channel_code='TT'
LEFT JOIN dbo.mst_org_hierarchy h
    ON h.channel_id=r.channel_id AND h.salesman_code=o.employee_code
   AND h.effective_month=(SELECT sales_month FROM dbo.mst_period WHERE period_code='FY2026-05')
ORDER BY h.ws_type, o.employee_code;
```

---

## 4. สิ่งที่ต้องเตรียมก่อนรัน usp_run

| รายการ | ตรวจด้วย |
|---|---|
| `trn_sales_target` มีข้อมูล period นี้ | `SELECT COUNT(*) FROM trn_sales_target WHERE period_id=...` |
| `trn_sales_actual` มีข้อมูล period นี้ | `SELECT COUNT(*) FROM trn_sales_actual WHERE period_id=...` |
| `mst_org_hierarchy` มี ws_type ครบทุกคน | `SELECT * FROM vw_tt_salesman_ws_type WHERE period_code='...'` |
| `pct_salesman` ใน `trn_sales_target` ไม่เป็น NULL (สำหรับ product ที่ต้องการ) | ดู prerequisite check ด้านบน |
| `mst_tt_ws_formula_matrix` มีครบทุก ws_type | `SELECT * FROM vw_tt_formula_ws_matrix ORDER BY ws_type, product_code` |
| `mst_goal_threshold` มีข้อมูล | `SELECT * FROM vw_tt_formula_goal_threshold ORDER BY achievement_from` |
