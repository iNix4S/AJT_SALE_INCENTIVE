# AJT TT — View: `dbo.vw_tt_formula_incentive_matrix`

วันที่: 2026-06-15  
DDL File: `environment/ddl/35_create_view_vw_tt_formula_incentive_matrix.sql`  
วัตถุประสงค์: อ้างอิงสูตรคำนวณ incentive TT แบบ dynamic สำหรับ cross-check กับ Excel sheet "2) หลักการคำนวน Table"

---

## 1. ภาพรวม

View นี้ CROSS JOIN ระหว่าง:
- **`mst_tt_ws_formula_matrix`** — WS Matrix (ws_type × product × weight × incentive_base)
- **`mst_goal_threshold`** — Goal Threshold 9 bands (achievement → multiplier)

ผลลัพธ์: **Long format** — 1 row ต่อ (ws_type × product × band) ≈ 4 × 11 × 9 = **396 rows**

ไม่ hardcode ค่า multiplier ใดๆ — ดึงจาก DB ทั้งหมด

---

## 2. Source Tables

| Table | บทบาทใน View | View ที่ wrap |
|---|---|---|
| `mst_tt_ws_formula_matrix` | product_weight_percent, incentive_base, g_group_code | `vw_tt_formula_ws_matrix` (is_active=1) |
| `mst_goal_threshold` | achievement_from/to, multiplier | `vw_tt_formula_goal_threshold` (is_active=1) |

---

## 3. คำอธิบาย Column

### 3.1 Identity / Key

| Column | Type | ความหมาย | ตัวอย่าง |
|---|---|---|---|
| `ws_type` | NVARCHAR | ประเภท WS ของพนักงาน | `TOP_WS`, `WS_SF`, `WS_WH`, `SF_WH` |
| `g_group_code` | NVARCHAR | กลุ่มสินค้า | `G1` (CORE), `G2` (GD), `G3` (BB), `OT` |
| `product_code` | NVARCHAR | รหัสสินค้าใน DB | `AJ`, `RD`, `BD`, `AJP`, `RDC`, ... |
| `product_name_th` | NVARCHAR | ชื่อสินค้าภาษาไทย | อายิโนะโมะโต๊ะ |

> การ map ชื่อย่อชีต → DB product_code:  
> A=AJ / R=RD / B=BD / AP=AJP / Q=RDC / M=RM / NS=RDNS / Y=YY / P=PDC / T=TKM / RK=RKR

### 3.2 WS Matrix (จาก `mst_tt_ws_formula_matrix`)

| Column | Type | ความหมาย | ตัวอย่าง |
|---|---|---|---|
| `weight_pct` | DECIMAL(5,2) | น้ำหนักสินค้าเป็น % | `5.00` (= 5%) |
| `incentive_base` | DECIMAL(18,2) | เงิน base ต่อ ws_type (บาท) | `4000.00` (TOP_WS) |
| `effective_from` | DATE | วันเริ่ม config นี้ | `2026-04-01` |
| `effective_to` | DATE | วันสิ้นสุด config (NULL = ยังใช้งาน) | `NULL` |

### 3.3 Threshold Band (จาก `mst_goal_threshold`)

| Column | Type | ความหมาย | ตัวอย่าง (band 3) |
|---|---|---|---|
| `band_seq` | INT | ลำดับ band (1–9) | `3` |
| `ach_from_pct` | DECIMAL(6,2) | % achievement เริ่มต้น band (display) | `95.01` |
| `ach_to_pct` | DECIMAL(6,2) | % achievement สิ้นสุด band (NULL → แสดง 999.99) | `100.01` |
| `achievement_from` | DECIMAL | raw ratio เริ่มต้น (ตรงกับ DB) | `0.9501` |
| `achievement_to` | DECIMAL | raw ratio สิ้นสุด (NULL = ไม่มี cap) | `1.0001` |
| `goal_multiplier_pct` | DECIMAL(6,2) | ตัวคูณ goal เป็น % (display) | `100.00` |
| `goal_multiplier` | DECIMAL | raw multiplier ที่ใช้คูณใน SP จริง | `1.0000` |

> **Boundary rule**: `achievement_from` เก็บ inclusive lower bound  
> เช่น band 2 จาก 90.01% ขึ้นไป หมายถึงต้อง **เกิน** 90.00% พอดีเล็กน้อย

### 3.4 Computed Payout

| Column | Type | ความหมาย | สูตร |
|---|---|---|---|
| **`incentive_per_product`** | DECIMAL(9,2) | เงิน incentive ต่อสินค้า 1 ตัวสำหรับ band นี้ | `incentive_base × (weight_pct/100) × goal_multiplier` |

> ตรงกับสูตรใน SP:  
> `incentive_amount = incentive_base × goal_multiplier × product_weight`

---

## 4. ตัวอย่างผล (TOP_WS, product AJ)

| band_seq | ach_from% | ach_to% | multiplier% | incentive_per_product |
|---|---|---|---|---|
| 1 | 0.00 | 90.01 | 90% | **180.00** |
| 2 | 90.01 | 95.01 | 95% | **190.00** |
| 3 | 95.01 | 100.01 | 100% | **200.00** ← ตรงชีต cell D6 |
| 4 | 100.01 | 103.01 | 103% | **206.00** |
| 5 | 103.01 | 106.01 | 106% | **212.00** |
| 6 | 106.01 | 110.01 | 110% | **220.00** |
| 7 | 110.01 | 115.01 | 115% | **230.00** |
| 8 | 115.01 | 120.01 | 120% | **240.00** |
| 9 | 120.01 | (no cap) | 130% | **260.00** |

---

## 5. Query ใช้งาน

```sql
-- ดูทั้งหมด (long format)
SELECT *
FROM dbo.vw_tt_formula_incentive_matrix
ORDER BY
    CASE ws_type WHEN 'TOP_WS' THEN 1 WHEN 'WS_SF' THEN 2 WHEN 'WS_WH' THEN 3 ELSE 4 END,
    CASE g_group_code WHEN 'G1' THEN 1 WHEN 'G2' THEN 2 WHEN 'G3' THEN 3 ELSE 4 END,
    product_code, band_seq;

-- filter เฉพาะ ws_type + band ที่ต้องการ
SELECT *
FROM dbo.vw_tt_formula_incentive_matrix
WHERE ws_type = N'TOP_WS'
  AND band_seq = 3;    -- band 100% ทุก product

-- cross-check ค่าชีต: sum ทุก product ใน band 100% ของ TOP_WS
SELECT
    ws_type,
    band_seq,
    goal_multiplier_pct,
    SUM(incentive_per_product) AS total_incentive_at_100pct
FROM dbo.vw_tt_formula_incentive_matrix
WHERE ws_type = N'TOP_WS'
  AND band_seq = 3
GROUP BY ws_type, band_seq, goal_multiplier_pct;

-- หา band ที่ achievement จริงตกอยู่
SELECT *
FROM dbo.vw_tt_formula_incentive_matrix
WHERE ws_type    = N'TOP_WS'
  AND product_code = N'AJ'
  AND 1.0842 >= achievement_from
  AND (achievement_to IS NULL OR 1.0842 <= achievement_to);
```

---

## 6. ความสัมพันธ์กับ SP และ Views อื่น

```
mst_tt_ws_formula_matrix ──→ vw_tt_formula_ws_matrix ──→ vw_tt_formula_incentive_matrix (CROSS JOIN)
mst_goal_threshold       ──→ vw_tt_formula_goal_threshold ─┘

                                                            ↕ ใช้ verify
usp_run_tt_incentive_calculation (SP จริง)
  ├─ OUTER APPLY mst_tt_ws_formula_matrix  (ดึง incentive_base, weight)
  └─ OUTER APPLY mst_goal_threshold        (lookup multiplier จาก achievement)
```

**View นี้ไม่ได้อยู่ใน SP จริง** — ใช้สำหรับ cross-check/verify เท่านั้น  
SP คำนวณด้วย OUTER APPLY แยกต่างหาก ไม่ได้ JOIN ทั้งสองตารางพร้อมกัน

---

## 7. Views ที่เกี่ยวข้อง

| View | วัตถุประสงค์ |
|---|---|
| `vw_tt_formula_catalog` | รวมทุก formula (threshold + rate + matrix) ใน 1 view |
| `vw_tt_formula_ws_matrix` | WS Matrix เฉพาะ (weight + base ต่อ product) |
| `vw_tt_formula_goal_threshold` | Threshold 9 bands เฉพาะ |
| **`vw_tt_formula_incentive_matrix`** | **CROSS JOIN แบบ long format ← view นี้** |
| `vw_tt_incentive_formula_definition` | ครบทุก component (rate + threshold + option1 + KPI) รวมกัน |
| `vw_tt_incentive_rate` | rate ต่อ position × ws_type (T_SectAbove reference) |
