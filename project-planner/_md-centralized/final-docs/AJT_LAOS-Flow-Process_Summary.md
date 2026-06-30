# AJT LAOS Flow Process Summary

วันที่: 2026-06-30
เวอร์ชัน: v1.0
ขอบเขต: เอกสารอธิบาย LAOS Flow สำหรับทีม Business, SA, Dev และ QA

---

## Changelog

| เวอร์ชัน | วันที่ | รายละเอียด |
|---|---|---|
| v1.0 | 2026-06-30 | Initial release - LAOS Flow แบบ SINGLE_SHEET, Hierarchy 3 ระดับ, ws_type 4 แบบ, SKU Alias Mapping (A/R/B/Y -> AJ/RD/BD/YY), TC04 baseline |

---

## 1. วัตถุประสงค์

เอกสารนี้สรุปการไหลของ LAOS Channel แบบครบลำดับ ตั้งแต่รับข้อมูลยอดขายรูปแบบ SKU, ทำ Product Mapping แบบ inline ภายใน Stored Procedure, คำนวณ incentive ระดับ STAFF และ cascade ไปยังผู้จัดการ จนได้ผลลัพธ์ For HR เพื่อให้ทุกทีมใช้อ้างอิงเดียวกัน

---

## 2. หลักการของ LAOS

1. LAOS ใช้แนวคิด policy แบบ `SINGLE_SHEET` (baseline เรียบง่ายกว่า TT)
2. LAOS ใช้ Stored Procedure หลัก `usp_run_laos_incentive_calculation` โดยรับ `@PeriodCode` (string) และ `@WsType`
3. Product Mapping ทำแบบ inline ใน SP จาก SKU Alias ไปยัง base product
4. โครงสร้าง hierarchy ปัจจุบันเป็น 3 ระดับ: STAFF -> SECT_MGR -> DEPT_MGR
5. ไม่มีระดับ DIV_MGR และไม่มีระดับ AD ใน baseline ชุดข้อมูลทดสอบปัจจุบัน
6. Manager incentive คำนวณจากค่าเฉลี่ย `goal_multiplier` ของลูกน้องตามสายบังคับบัญชา
7. Goal Threshold ใช้ตารางร่วม `mst_goal_threshold` (9 bands)
8. LAOS รองรับ ws_type หลายแบบ (`TOP_WS`, `WS_SF`, `WS_WH`, `SF_WH`)

---

## 3. ลำดับการไหลของ LAOS

```
[Sales Input]
     ↓ Salesman Code + SKU Product + Actual/Target
[Validation Gate]
     ↓ ตรวจ Period / Required Fields / Hierarchy / Rate / Weight
[SP: usp_run_laos_incentive_calculation]
     ↓ Inline SKU Mapping (A/R/B/Y aliases)
     ↓ Achievement -> Goal Multiplier
[Step 1: STAFF Incentive per Product]
     ↓ base_rate × weight_pct × goal_mult
[Step 2: SECT_MGR Cascade]
     ↓ AVG(goal_mult ของ STAFF ใต้สังกัด) × base_rate
[Step 3: DEPT_MGR Cascade]
     ↓ AVG(goal_mult ของ SECT_MGR ใต้สังกัด) × base_rate
[Aggregate]
     ↓ SUM per employee -> out_for_hr_variable
[trn_calc_run]
     ↓ run_status = CALCULATED
[For HR Output]
     ↓ Export / Approval
```

### 3.1 รายละเอียดแต่ละ Step

| Step | กิจกรรม | Input | Output |
|---|---|---|---|
| 0 | รับข้อมูลยอดขาย | trn_sales_target, trn_sales_actual | records พร้อมคำนวณ |
| 1 | Validation | mst_period, mst_org_hierarchy, mst_incentive_rate, mst_product_weight | ผ่าน / Error log |
| 2 | Product Mapping | SKU alias (A/R/B/Y) | mapped product code (AJ/RD/BD/YY) |
| 3 | PCT Achievement | actual_amount / target_amount | achievement + goal_multiplier |
| 4 | STAFF Incentive | base_rate x weight_pct x goal_mult | trn_incentive_detail (STAFF) |
| 5 | SECT_MGR Incentive | AVG(goal_mult_staff) x rate | trn_incentive_detail (SECT_MGR) |
| 6 | DEPT_MGR Incentive | AVG(goal_mult_sect) x rate | trn_incentive_detail (DEPT_MGR) |
| 7 | Rollup | SUM ต่อ employee | out_for_hr_variable |
| 8 | Update Calc Run | trn_calc_run | run_status = CALCULATED |

### 3.2 คำสั่ง SP สำหรับ LAOS

```sql
-- รัน LAOS Incentive สำหรับ Period ที่ต้องการ
EXEC dbo.usp_run_laos_incentive_calculation
    @PeriodCode = N'FY2026-04',
    @WsType     = N'TOP_WS',
    @ApprovedBy = N'system';
```

---

## 4. สูตรหลักที่ใช้ใน LAOS

### 4.1 สูตรคำนวณ PCT Achievement

```
PCT_ACHIEVEMENT = ROUND(actual_amount / target_amount, 4)
```

### 4.2 Goal Threshold Table (LAOS - Shared 9 Bands)

| Seq | Achievement จาก | Achievement ถึง | Goal Multiplier |
|---|---|---|---|
| 1 | 0.00% | 90.01% | 0.90 |
| 2 | 90.01% | 95.01% | 0.95 |
| 3 | 95.01% | 100.01% | 1.00 |
| 4 | 100.01% | 103.01% | 1.03 |
| 5 | 103.01% | 106.01% | 1.08 |
| 6 | 106.01% | 110.01% | 1.10 |
| 7 | 110.01% | 115.01% | 1.15 |
| 8 | 115.01% | 120.01% | 1.20 |
| 9 | 120.01%+ | (ไม่มีเพดาน) | 1.30 |

### 4.3 สูตร Incentive

| Position | สูตร | หมายเหตุ |
|---|---|---|
| STAFF | `ROUND(base_rate * weight_pct * goal_mult, 0)` | ตามสูตร `LAOS_STAFF_INCENTIVE_PER_PRODUCT` |
| Manager (SECT_MGR, DEPT_MGR) | `base_rate * weight_pct * goal_mult` | ตามสูตร `LAOS_MGR_INCENTIVE_PER_PRODUCT` |
| Rollup | `ROUND(SUM(incentive_per_product), 2)` | ใช้ตอนรวมออก For HR |

---

## 5. โครงสร้าง Hierarchy ของ LAOS

LAOS baseline ปัจจุบันใช้ 3 ระดับ

```
Level 3 - DEPT_MGR
          |
Level 2 - SECT_MGR
          |
Level 1 - STAFF
```

### 5.1 โครงสร้าง Mock Data (Period 1)

| Employee Code | ชื่อ | ตำแหน่ง |
|---|---|---|
| LA001 | นาย ล. ขายลาว | STAFF |
| LA002 | นาง อ. ส่งออก | STAFF |
| LA003 | นาย ว. นำเข้า | STAFF |
| LAM01 | นาง ล. หัวหน้า | SECT_MGR |
| LAD01 | นาย อ. ผู้จัดการ | DEPT_MGR |

---

## 6. ws_type และ Product Mapping ของ LAOS

### 6.1 ws_type ที่รองรับ

| ws_type | รายละเอียด |
|---|---|
| TOP_WS | Wholesale type หลัก (default) |
| WS_SF | Wholesale SF |
| WS_WH | Warehouse |
| SF_WH | SF + Warehouse |

### 6.2 Product Mapping (Inline ใน SP)

| SKU Alias | Mapped Product |
|---|---|
| SKU-A-* | AJ |
| SKU-R-* | RD |
| SKU-B-* | BD |
| SKU-Y-* | YY |
| อื่นๆ | ใช้ product_code เดิม |

```sql
-- ตรวจ mapping SKU alias สำหรับ LAOS
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
JOIN dbo.mst_channel c ON c.channel_id = t.channel_id
WHERE c.channel_code = N'LAOS'
ORDER BY t.product_code;
```

---

## 7. Validation Gate ที่ต้องผ่านก่อนคำนวณ

| # | Gate | รายการตรวจ | ตาราง / View |
|---|---|---|---|
| 1 | Period Alignment | period_code ต้องมีใน mst_period | mst_period |
| 2 | Required Fields | salesman_code, product_code, target, actual ต้องครบ | trn_sales_target, trn_sales_actual |
| 3 | Hierarchy Consistency | direct_sup และ dept_mgr ครบตามโครงสร้าง LAOS | mst_org_hierarchy |
| 4 | Rate Readiness | มี incentive rate ครบตาม position/ws_type ที่ใช้ | mst_incentive_rate |
| 5 | Product Weight Readiness | มี product weight สำหรับ mapped products | mst_product_weight |
| 6 | Goal Threshold Readiness | goal threshold active ครบ 9 bands | mst_goal_threshold |
| 7 | Duplicate Check | ไม่มี duplicate คีย์ใน target/actual | trn_sales_target, trn_sales_actual |

```sql
-- ตรวจ run ล่าสุดของ LAOS
SELECT TOP 5 calc_run_id, run_status, period_id, created_at
FROM dbo.trn_calc_run r
JOIN dbo.mst_channel c ON c.channel_id = r.channel_id
WHERE c.channel_code = N'LAOS'
ORDER BY calc_run_id DESC;
```

---

## 8. Output ที่ต้องได้จาก LAOS

| # | Output | ตาราง / View | หมายเหตุ |
|---|---|---|---|
| 1 | Incentive detail ราย product | trn_incentive_detail | STAFF และ Manager rows |
| 2 | For HR Variable | out_for_hr_variable | 1 แถวต่อ employee |
| 3 | Calc Run Record | trn_calc_run | run_status = CALCULATED |

```sql
-- ตรวจ For HR ล่าสุดของ LAOS
SELECT
    h.employee_code,
    h.position_level_code,
    CAST(h.total_variable AS DECIMAL(18,2)) AS total_variable
FROM dbo.out_for_hr_variable h
WHERE h.calc_run_id = (
    SELECT TOP 1 calc_run_id
    FROM dbo.trn_calc_run
    WHERE channel_id = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'LAOS')
    ORDER BY calc_run_id DESC
)
ORDER BY h.employee_code;
```

---

## 9. จุดเสี่ยงสำคัญของ LAOS

| # | จุดเสี่ยง | ผลกระทบ | วิธีป้องกัน |
|---|---|---|---|
| 1 | SKU alias mapping ผิด | product_code map ผิดทำให้ incentive ผิด | ตรวจ mapping query ก่อน run |
| 2 | ws_type ไม่สอดคล้องกับ hierarchy | base rate ที่ใช้ผิด | ตรวจ ws_type ใน mst_org_hierarchy |
| 3 | Hierarchy ไม่ครบ | Manager incentive เพี้ยนหรือหาย | ตรวจ direct_sup/dept_mgr ก่อนคำนวณ |
| 4 | Rate หรือ Weight ไม่ครบ | incentive = 0 หรือ NULL บาง product | ตรวจ coverage ของ mst_incentive_rate และ mst_product_weight |
| 5 | Goal Threshold ไม่ครบหรือซ้อนทับ | goal_multiplier ผิดทั้งระบบ | ตรวจ continuity ของ 9 bands |
| 6 | Period mismatch | จ่ายผิดงวด | lock period ก่อน run |

---

## 10. เช็คลิสต์ QA สำหรับ LAOS

### 10.1 Pre-Calculation

- [ ] period_code ที่จะรันมีข้อมูล target/actual พร้อม
- [ ] SKU alias ใน target map ได้ครบ (A/R/B/Y และอื่นๆ)
- [ ] `mst_org_hierarchy` ของ LAOS ไม่มีช่องว่างสำคัญในสายบังคับบัญชา
- [ ] มี rate ตาม ws_type/position ที่ใช้งานจริง
- [ ] `mst_goal_threshold` active ครบ 9 bands

### 10.2 Post-Calculation

- [ ] `trn_calc_run.run_status = CALCULATED`
- [ ] `out_for_hr_variable` มีจำนวนแถวตามจำนวนพนักงานที่คาดหวัง
- [ ] ไม่มี employee_code ซ้ำใน output
- [ ] ไม่มีตำแหน่ง DIV ใน output baseline LAOS
- [ ] ตรวจ sample expected values ตาม TC04 ผ่าน tolerance

### 10.3 TC04 Expected Values (Period FY2026-04, calc_run_id อ้างอิง 1033)

| employee_code | position_level_code | expected_total_variable | tolerance |
|---|---|---|---|
| LA001 | STAFF | 7,680.00 | ±0.05 |
| LA002 | STAFF | 7,920.00 | ±0.05 |
| LA003 | STAFF | 6,058.80 | ±0.05 |
| LAM01 | SECT_MGR | 9,560.00 | ±0.05 |
| LAD01 | DEPT_MGR | 8,497.78 | ±0.05 |

---

## 11. ความแตกต่างหลักระหว่าง LAOS และ TT

| ประเด็น | LAOS | TT |
|---|---|---|
| calc_type policy | SINGLE_SHEET | SINGLE_SHEET_5_LEVEL_AVG |
| Period parameter | PeriodCode (string) | PeriodCode (string) |
| ws_type | รองรับ 4 แบบ | ใช้ตามชุดข้อมูล TT |
| Product Input | SKU alias + inline mapping | SKU/โครง TT เดิม |
| Hierarchy baseline ปัจจุบัน | 3 ระดับ (STAFF/SECT/DEPT) | 5 ระดับ (มี DIV และ AD) |
| ความซับซ้อน flow | ต่ำกว่า | สูงกว่า |

---

## 12. อ้างอิง

1. `src/AjtIncentive.Web/Pages/Calculation/sp-usage-LAOS.md`
2. `test-scenarios/TC04_Laos_Channel_Normal.md`
3. `final-docs/AJT_Policy-Diff_TT-vs-LAOS_One-Page.md`
4. `1.General Documents/SI_LAOS_SETUP_README.md`

---

*เอกสารนี้จัดทำเพื่อใช้สื่อสาร baseline flow ของ LAOS และควรทบทวนทุกครั้งเมื่อมีการเปลี่ยน SP signature, hierarchy policy หรือ ws_type policy*