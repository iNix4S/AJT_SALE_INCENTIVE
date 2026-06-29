# AJT SI Flow Process Summary

วันที่: 2026-06-29
เวอร์ชัน: v1.0
ขอบเขต: เอกสารอธิบาย SI Flow (Sales & Import) สำหรับทีม Business, SA, Dev และ QA

---

## Changelog

| เวอร์ชัน | วันที่ | รายละเอียด |
|---|---|---|
| v1.0 | 2026-06-29 | Initial release — SI Flow ครบ 4 ระดับ, Goal Threshold 9 bands, Mock Data 11 คน (7 STAFF / 2 SECT_MGR / 1 DEPT_MGR / 1 AD) |
| v1.1 | 2026-06-29 | **Manager Cascade** implement แล้ว — SECT_MGR/DEPT_MGR/AD คำนวณจาก aggregate STAFF actuals ผ่าน hierarchy; สร้าง `vw_for_hr_si_sheet`; `payment_method = BANK_TRANSFER`; `run_status = COMPLETED`; ForHR page แสดง 11 rows + Ach% จริง |

---

## 1. วัตถุประสงค์

เอกสารนี้สรุปการไหลของ SI (Sales & Import) แบบครบลำดับ ตั้งแต่รับข้อมูลยอดขายโดยตรงจาก Salesman Code ผ่าน Validation คำนวณ incentive ระดับ STAFF ต่อ Product Group ไปจนถึงการสร้างผลลัพธ์ For HR เพื่อให้ทุกทีมใช้ความเข้าใจเดียวกัน

---

## 2. หลักการของ SI

1. SI รับข้อมูลยอดขายในรูปแบบ **Salesman Code + Product Code โดยตรง** — ไม่ต้องมี Mapping Layer เหมือน MT
2. SI ไม่มี Sub-channel (ไม่แบ่ง C&C / Non-C&C ต่างจาก MT)
3. โครงสร้าง Hierarchy มี **4 ระดับ** เหมือน MT (STAFF, SECT_MGR, DEPT_MGR, AD) — ไม่มีระดับ DIV_MGR
4. ไม่มี `ws_type` ต่อ Salesman — ทุกคนใช้ base_rate เดียวกันตาม position_level
5. สูตรระดับ STAFF คำนวณราย **Product**: `incentive_base × product_weight × goal_multiplier → ROUND(.,2)`
6. ระดับ Manager (**SECT_MGR, DEPT_MGR, AD**) คำนวณ incentive จาก **aggregate actual/target ของ STAFF ที่อยู่ใต้สังกัด** ผ่าน `mst_org_hierarchy` (Manager Cascade) — incentive_sect/dept/ad มีค่าจริงแล้ว
7. Goal Multiplier ใช้ Lookup ตาม **9-band threshold table** (`mst_goal_threshold`) ที่ shared ข้ามทุก channel

---

## 3. ลำดับการไหลของ SI

```
[Sales Data Source]
     ↓ Salesman Code + Product Code + Actual → trn_sales_actual (โดยตรง, ไม่มี Mapping)
[Validation Gate]
     ↓ ตรวจ Period / Required Fields / Hierarchy
[trn_sales_actual]
     ↓ คำนวณ Achievement ราย Salesman × Product
[Step 1: STAFF Incentive per Product]
     ↓ incentive_base × product_weight × goal_multiplier  → trn_incentive_detail (STAFF rows)
[Step 2: Manager Cascade (SECT_MGR / DEPT_MGR / AD)]
     ↓ aggregate STAFF actual/target ผ่าน mst_org_hierarchy
     ↓ achievement × goal_multiplier per product → trn_incentive_detail (Manager rows)
[Aggregate (All Levels)]
     ↓ SUM per employee × position_level → out_for_hr_variable (11 rows)
[trn_calc_run]
     ↓ run_status = COMPLETED
[For HR Output: vw_for_hr_si_sheet]
     ↓ Export / Approval
```

### 3.1 รายละเอียดแต่ละ Step

| Step | กิจกรรม | Input | Output |
|---|---|---|---|
| 0 | รับข้อมูลยอดขาย | trn_sales_actual (Salesman Code + Product Code + Actual) | records พร้อมคำนวณ |
| 1 | Validation | mst_period, mst_org_hierarchy, trn_sales_target | ผ่าน / Error log |
| 2 | PCT Achievement (STAFF) | trn_sales_actual / trn_sales_target | raw_achievement ราย salesman × product |
| 3 | Goal Multiplier Lookup | mst_goal_threshold (9 bands) | goal_multiplier |
| 4 | STAFF Incentive | incentive_base × product_weight × goal_mult | trn_incentive_detail (STAFF rows, 21 rows) |
| 5 | Manager Cascade | aggregate STAFF actual/target ผ่าน mst_org_hierarchy | trn_incentive_detail (Manager rows, 12 rows) |
| 6 | Rollup (All Levels) | ROUND(SUM per employee × position_level, 2) | out_for_hr_variable (11 rows) |
| 7 | Update Calc Run | trn_calc_run | run_status = **COMPLETED** |

### 3.2 คำสั่ง SP สำหรับ SI

```sql
-- รัน SI Incentive สำหรับ Period ที่ต้องการ
EXEC dbo.usp_run_si_incentive_calculation
    @PeriodId   = 1,         -- period_id จาก mst_period
    @ApprovedBy = N'system'; -- ผู้อนุมัติ (log ไว้ใน trn_calc_run)
```

---

## 4. สูตรหลักที่ใช้ใน SI

### 4.1 สูตรคำนวณ PCT Achievement

```
PCT_ACHIEVEMENT = ROUND(actual_amount / target_amount, 4)
```

จากนั้น Lookup `mst_goal_threshold` เพื่อได้ `goal_multiplier`

### 4.2 Goal Threshold Table (SI — ใช้ร่วมกันทุก Channel, 9 Bands)

| Seq | Achievement จาก | Achievement ถึง | Goal Multiplier |
|---|---|---|---|
| 1 | 0.00% | 90.01% | **0.90** |
| 2 | 90.01% | 95.01% | **0.95** |
| 3 | 95.01% | 100.01% | **1.00** |
| 4 | 100.01% | 103.01% | **1.03** |
| 5 | 103.01% | 106.01% | **1.08** |
| 6 | 106.01% | 110.01% | **1.10** |
| 7 | 110.01% | 115.01% | **1.15** |
| 8 | 115.01% | 120.01% | **1.20** |
| 9 | 120.01%+ | (ไม่มีเพดาน) | **1.30** |

> ⚠️ ไม่มี floor — ถ้า achievement < 90% → goal_multiplier = 0.90 (ขาดทุนจากฐาน)

### 4.3 สูตร Incentive

```
incentive_amount = ROUND(incentive_base × product_weight × goal_multiplier, 2)
total_variable   = ROUND(SUM(incentive_amount per product), 2)
```

ทุก position ใช้สูตรเดียวกัน — ความต่างอยู่ที่ `incentive_base` ตาม position_level

### 4.4 ค่า Base Rate ต่อ Position Level (SI)

| Position Code | ชื่อตำแหน่ง | Hierarchy Level | Base Rate (฿) | ws_type |
|---|---|---|---|---|
| STAFF | Salesman / Staff | 1 | **15,000** | OLD |
| SECT_MGR | Section Manager | 2 | **11,000** | OLD |
| DEPT_MGR | Department Manager | 3 | **8,500** | OLD |
| AD | Associate Director | 5 | **6,500** | OLD |

> Rate เก็บใน `mst_incentive_rate` โดยใช้ `COALESCE(rate_new, rate_old)` — ws_type='OLD' คือ rate ชุดปัจจุบัน

---

## 5. โครงสร้าง Hierarchy ของ SI

SI มี **4 ระดับ** เหมือน MT — ไม่มีระดับ DIV_MGR

```
Level 5 — AD (Associate Director)
           │
Level 3 — DEPT_MGR (Department Manager)
           │
Level 2 — SECT_MGR × หลาย section
           │
Level 1 — STAFF (Salesman)
```

### 5.1 Job Function ของ SI (4 ประเภท)

| Job Function Code | ชื่อภาษาอังกฤษ | ชื่อภาษาไทย |
|---|---|---|
| SI_AD | SI Associate Director | ผู้อำนวยการฝ่ายขาย SI |
| SI_DEPT_MGR | SI Department Manager | ผู้จัดการแผนก SI |
| SI_SECT_MGR | SI Section Manager | หัวหน้าส่วนขาย SI |
| SI_STAFF | SI Sales Staff | พนักงานขาย SI |

### 5.2 Org Units ของ SI

| unit_type | unit_code | unit_name | unit_name_th |
|---|---|---|---|
| DIVISION | AD001 | SI Sales Division | ฝ่ายขาย SI |
| DEPARTMENT | DM001 | SI Department | แผนก SI |
| SECTION | SIM01 | SI Section 1 | ส่วนขาย SI 1 |
| SECTION | SIM02 | SI Section 2 | ส่วนขาย SI 2 |

> unit_code ใช้ employee_code ของ manager เป็น key — ตามรูปแบบเดียวกับ MT

### 5.3 โครงสร้าง Mock Data (Period 1 — 11 คน)

| Employee Code | ชื่อ | ตำแหน่ง | Job Function | Section |
|---|---|---|---|---|
| AD001 | นายกมล อำนวยผล | AD | SI_AD | (Top Level) |
| DM001 | นายบุญชู ประดิษฐ์ดี | DEPT_MGR | SI_DEPT_MGR | แผนก SI |
| SIM01 | นาง ส. หัวหน้า | SECT_MGR | SI_SECT_MGR | ส่วนขาย SI 1 |
| SIM02 | นายสมศักดิ์ รุ่งโรจน์ | SECT_MGR | SI_SECT_MGR | ส่วนขาย SI 2 |
| SI001 | นาย ส. นำเข้า | STAFF | SI_STAFF | ส่วนขาย SI 1 |
| SI002 | นาง ศ. ส่งออก | STAFF | SI_STAFF | ส่วนขาย SI 1 |
| SI003 | นาย ษ. ขายดี | STAFF | SI_STAFF | ส่วนขาย SI 1 |
| SI004 | นางอรุณี ทองดี | STAFF | SI_STAFF | ส่วนขาย SI 1 |
| SI005 | นายปิยะ สุขใจดี | STAFF | SI_STAFF | ส่วนขาย SI 1 |
| SI006 | นางสาวรัตนา วงษ์สุวรรณ | STAFF | SI_STAFF | ส่วนขาย SI 2 |
| SI007 | นายวีระ บุญมาก | STAFF | SI_STAFF | ส่วนขาย SI 2 |

### 5.4 Hierarchy Structure (Period 1 — FY2026-04)

```
AD001 (Associate Director — ฝ่ายขาย SI)
└── DM001 (Dept Manager — แผนก SI)
    ├── SIM01 (Sect Manager — ส่วนขาย SI 1)
    │   ├── SI001  นาย ส. นำเข้า
    │   ├── SI002  นาง ศ. ส่งออก
    │   ├── SI003  นาย ษ. ขายดี
    │   ├── SI004  นางอรุณี ทองดี
    │   └── SI005  นายปิยะ สุขใจดี
    └── SIM02 (Sect Manager — ส่วนขาย SI 2)
        ├── SI006  นางสาวรัตนา วงษ์สุวรรณ
        └── SI007  นายวีระ บุญมาก
```

---

## 6. Products ที่ใช้ใน SI

### 6.1 Product Weight Table (SI — ws_type='OLD')

| Product Code | Product Name | Weight (%) |
|---|---|---|
| AJ | AJINOMOTO | **30%** |
| RD | ROSDEE | **20%** |
| BD | BIRDY | **15%** |
| YY | YUMYUM | **10%** |
| AJP | AJI-PLUS | **8%** |
| PDC | POWDER COFFEE | **7%** |

> Test data ปัจจุบัน (Period 1) มี targets/actuals เฉพาะ **AJ, RD, BD** เท่านั้น

### 6.2 ตัวอย่างการคำนวณ STAFF (SI001 — Period 1)

SI001 มี targets/actuals สำหรับ 3 products:

| Product | Target | Actual | Achievement | Band | Goal Mult | incentive_base | Weight | Incentive |
|---|---|---|---|---|---|---|---|---|
| AJ | 1,000,000 | 1,050,000 | **105%** | 5 | 1.08 | 15,000 | 30% | **4,860.00** |
| RD | 600,000 | 600,000 | **100%** | 3 | 1.00 | 15,000 | 20% | **3,000.00** |
| BD | 400,000 | 420,000 | **105%** | 5 | 1.08 | 15,000 | 15% | **2,430.00** |
| **รวม** | | | | | | | | **10,290.00** |

```
สูตร (ต่อ product row):
  incentive = ROUND(15,000 × 0.30 × 1.08, 2) = 4,860.00  (AJ)
  incentive = ROUND(15,000 × 0.20 × 1.00, 2) = 3,000.00  (RD)
  incentive = ROUND(15,000 × 0.15 × 1.08, 2) = 2,430.00  (BD)
  total_variable = ROUND(SUM, 2) = 10,290.00
```

---

## 7. Validation Gate ที่ต้องผ่านก่อนคำนวณ

### 7.1 รายการตรวจ

| # | Gate | รายการตรวจ | ตาราง / View |
|---|---|---|---|
| 1 | Period Alignment | เดือนข้อมูลขายต้องตรงกับ period ที่ระบบเปิดคำนวณ | mst_period |
| 2 | Required Fields | ต้องมี Salesman Code, Product Code, Actual, Target ครบ | trn_sales_actual, trn_sales_target |
| 3 | Hierarchy Consistency | โครงสร้างสายบังคับบัญชาครบ 4 ระดับ ไม่มีช่องว่าง | mst_org_hierarchy |
| 4 | Incentive Rate Readiness | ต้องมี rate สำหรับทุก position ที่ใช้ | mst_incentive_rate |
| 5 | Product Weight Readiness | ต้องมี weight_percent สำหรับทุก product ที่มี target | mst_product_weight |
| 6 | Goal Threshold | mst_goal_threshold ต้องมีครบ 9 bands และ is_active=1 | mst_goal_threshold |
| 7 | Duplicate Check | ไม่มี duplicate (period_id + salesman_code + product_code) ใน target/actual | trn_sales_target, trn_sales_actual |

### 7.2 Validation Queries

```sql
-- 1. Hierarchy Gap Check (SI — 4 ระดับ)
SELECT salesman_code, direct_sup_code, dept_mgr_code, ad_code,
       CASE WHEN direct_sup_code IS NULL THEN 'missing_sect'
            WHEN dept_mgr_code IS NULL   THEN 'missing_dept'
            WHEN ad_code IS NULL         THEN 'missing_ad'
            ELSE 'OK' END AS gap_type
FROM dbo.mst_org_hierarchy h
JOIN dbo.mst_channel c ON c.channel_id = h.channel_id
WHERE c.channel_code = N'SI'
  AND (direct_sup_code IS NULL OR dept_mgr_code IS NULL OR ad_code IS NULL);

-- 2. Product Weight Readiness
SELECT p.product_code, pw.weight_percent
FROM dbo.mst_product_weight pw
JOIN dbo.mst_product p ON p.product_id = pw.product_id
WHERE pw.channel_id = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'SI')
  AND pw.is_active = 1
ORDER BY p.product_code;

-- 3. ตรวจ Incentive Rate ของ SI
SELECT pl.position_code, pl.hierarchy_level, ir.rate_new, ir.effective_from
FROM dbo.mst_incentive_rate ir
JOIN dbo.mst_position_level pl ON pl.position_level_id = ir.position_level_id
WHERE ir.channel_id = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'SI')
  AND ir.is_active = 1
ORDER BY pl.hierarchy_level;

-- 4. ตรวจ Goal Threshold ว่าครบ 9 bands
SELECT COUNT(*) AS band_count FROM mst_goal_threshold WHERE is_active = 1;
-- ต้องได้ >= 9

-- 5. ตรวจ Calc Run Status ล่าสุดของ SI
SELECT TOP 5 calc_run_id, run_status, period_id, created_at
FROM dbo.trn_calc_run cr
JOIN dbo.mst_channel c ON c.channel_id = cr.channel_id
WHERE c.channel_code = N'SI'
ORDER BY created_at DESC;
```

---

## 8. Output ที่ต้องได้จาก SI

| # | Output | ตาราง / View | หมายเหตุ |
|---|---|---|---|
| 1 | ผลคำนวณ STAFF ราย Product | trn_incentive_detail | แยกตาม salesman_code + product_code (21 rows per period) |
| 2 | ผลคำนวณ Manager Cascade | trn_incentive_detail | SECT_MGR/DEPT_MGR/AD ราย product (12 rows per period) |
| 3 | For HR Variable (ทุก level) | out_for_hr_variable | 11 rows — payment_method = BANK_TRANSFER |
| 4 | For HR Sheet View | vw_for_hr_si_sheet | ใช้ใน Web Portal — รวม Ach%, manager incentive cross-reference |
| 5 | Calc Run Record | trn_calc_run | run_status = **COMPLETED**, approved_by |

```sql
-- ตรวจ Output For HR ของ SI (ทุก level)
SELECT
    o.employee_code,
    o.employee_name_th,
    o.position_level_code,
    o.payment_method,
    o.incentive_staff,
    o.incentive_sect,
    o.incentive_dept,
    o.incentive_ad,
    o.total_variable
FROM dbo.out_for_hr_variable o
JOIN dbo.trn_calc_run r ON r.calc_run_id = o.calc_run_id
JOIN dbo.mst_channel c ON c.channel_id = r.channel_id
WHERE c.channel_code = N'SI'
ORDER BY o.position_level_code DESC, o.employee_code;
-- คาดหวัง 11 rows: 7 STAFF + 2 SECT_MGR + 1 DEPT_MGR + 1 AD
-- payment_method = 'BANK_TRANSFER' ทุก row

-- ดู SI Sheet ผ่าน Web Portal (vw_for_hr_si_sheet)
SELECT * FROM dbo.vw_for_hr_si_sheet ORDER BY employee_code;
-- หรือ filter ตาม calc_run_id:
SELECT
    s.employee_name_th, s.position_level_code, s.division_name, s.department_name, s.section_name,
    s.total_variable, s.incentive_staff, s.incentive_sect, s.incentive_dept, s.incentive_ad,
    s.direct_sup_code, s.direct_sup_ach_pct, s.direct_sup_incentive,
    s.dept_mgr_code, s.dept_mgr_ach_pct, s.dept_mgr_incentive,
    s.div_mgr_code, s.div_mgr_ach_pct, s.div_mgr_incentive
FROM dbo.vw_for_hr_si_sheet s
WHERE s.calc_run_id = (SELECT MAX(cr.calc_run_id) FROM dbo.trn_calc_run cr
                       JOIN dbo.mst_channel c ON c.channel_id = cr.channel_id
                       WHERE c.channel_code = N'SI')
ORDER BY s.hierarchy_level, s.salesman_code;
```

---

## 9. จุดเสี่ยงสำคัญของ SI

| # | จุดเสี่ยง | ผลกระทบ | วิธีป้องกัน |
|---|---|---|---|
| 1 | **Product ไม่มี weight** | product นั้นถูกข้ามในการคำนวณ — ยอดขายหายหมด | ตรวจ mst_product_weight ครอบคลุมทุก product ที่มี target |
| 2 | **Hierarchy ไม่ครบ 4 ระดับ** | Section/Dept/Division แสดงเป็น employee_code แทนชื่อ | ตรวจ mst_org_hierarchy ทุก period ก่อน run |
| 3 | **Org Unit ไม่มีสำหรับ manager code** | Division/Department/Section แสดงเป็น code แทนชื่อ | ตรวจ mst_org_unit ให้มี unit_code ตรงกับ manager employee_code ของ SI |
| 4 | **Rate ไม่มีสำหรับ position** | incentive_base = 0 → incentive ทั้งหมด = 0 | ตรวจ mst_incentive_rate มี record สำหรับทุก position_level ของ SI |
| 5 | **Goal Threshold ไม่ครบ / ซ้อนทับ** | goal_multiplier ผิด ทุก employee | ตรวจ 9 bands ไม่ overlap และ achievement_to ต่อเนื่อง |
| 6 | **Duplicate target/actual** | PCT เพี้ยน | ตรวจ primary key (period_id + channel_id + salesman_code + product_code) |
| 7 | **Period mismatch** | จ่ายผิดรอบ | ตรวจ @PeriodId ก่อน EXEC SP เสมอ |
| 8 | **STAFF ไม่มีใน hierarchy** | manager ไม่ได้รับ cascade — incentive_sect/dept/ad ต่ำกว่าที่คาด | ตรวจ mst_org_hierarchy ให้ครอบคลุม STAFF ทุกคนก่อน EXEC SP |

---

## 10. เช็คลิสต์ QA สำหรับ SI

### 10.1 Pre-Calculation

- [ ] `mst_org_hierarchy` มีข้อมูลสำหรับ period นี้ ไม่มี NULL ที่ direct_sup_code / dept_mgr_code / ad_code
- [ ] `mst_product_weight` มี weight สำหรับทุก product ที่มี target (channel_id=3)
- [ ] `mst_incentive_rate` มี rate สำหรับทุก position_level ของ SI (STAFF, SECT_MGR, DEPT_MGR, AD)
- [ ] `mst_goal_threshold` มีครบ 9 bands ไม่ overlap
- [ ] ไม่มี duplicate ใน `trn_sales_target` (period_id + channel_id + salesman_code + product_code)
- [ ] `mst_org_unit` มี unit_code ตรงกับ manager employee_code ของทุก section/dept/division

### 10.2 Post-Calculation

- [ ] `trn_calc_run.run_status = COMPLETED` (ไม่ใช่ FAILED / IN_PROGRESS / CALCULATED)
- [ ] `trn_incentive_detail` มีข้อมูลครบทุก employee × product ที่มี target
- [ ] ตรวจ STAFF incentive ตัวอย่าง: `base_rate × product_weight × goal_mult = ค่าที่คาดหวัง`
- [ ] `out_for_hr_variable.total_variable` ตรงกับ expected sample (TC03)
- [ ] ไม่มี employee ที่อยู่ใน `trn_incentive_detail` แต่ไม่อยู่ใน `out_for_hr_variable`
- [ ] ForHR page แสดงชื่อ Division/Department/Section ถูกต้อง (ไม่ใช่ employee_code)

### 10.3 TC03 Expected Values (Period 1, calc_run_id = 1056)

**STAFF Level (7 rows)**

| Employee Code | Position | Section | Products ที่คำนวณ | Expected Total Variable (฿) |
|---|---|---|---|---|
| SI001 | STAFF | ส่วนขาย SI 1 | AJ(105%), RD(100%), BD(105%) | **10,290.00** |
| SI002 | STAFF | ส่วนขาย SI 1 | AJ(110%), RD(100%), BD(110%) | **10,425.00** |
| SI003 | STAFF | ส่วนขาย SI 1 | AJ(95%), RD(100%), BD(95%) | **9,412.50** |
| SI004 | STAFF | ส่วนขาย SI 1 | AJ(102%), RD(100%), BD(102%) | **9,952.50** |
| SI005 | STAFF | ส่วนขาย SI 1 | AJ(108%), RD(100%), BD(108%) | **10,425.00** |
| SI006 | STAFF | ส่วนขาย SI 2 | AJ(97%), RD(100%), BD(97%) | **9,750.00** |
| SI007 | STAFF | ส่วนขาย SI 2 | AJ(114%), RD(100%), BD(114%) | **10,762.50** |
| **รวม STAFF** | | | | **71,017.50** |

**Manager Level (4 rows) — cascade จาก aggregate STAFF actuals**

| Employee Code | Position | Subordinate STAFF | Avg Achievement* | Expected Total Variable (฿) |
|---|---|---|---|---|
| SIM01 | SECT_MGR | SI001–SI005 (Section 1) | ~104.69% → mult=1.08 | **7,722.00** |
| SIM02 | SECT_MGR | SI006–SI007 (Section 2) | ~106.35% → mult=1.10 | **7,865.00** |
| DM001 | DEPT_MGR | SI001–SI007 (all STAFF) | ~105.15% → mult=1.08 | **5,967.00** |
| AD001 | AD | SI001–SI007 (all STAFF) | ~105.15% → mult=1.08 | **4,563.00** |
| **รวม Manager** | | | | **26,117.00** |

> \* Achievement ของ manager = SUM(STAFF actual) / SUM(STAFF target) ต่อ product, แล้ว lookup goal_multiplier ตาม band

```sql
-- เปรียบเทียบผลจริงกับ TC03
SELECT
    o.employee_code,
    o.employee_name_th,
    o.position_level_code,
    o.incentive_staff,
    o.incentive_sect,
    o.incentive_dept,
    o.incentive_ad,
    o.total_variable
FROM dbo.out_for_hr_variable o
WHERE o.calc_run_id = 1056
ORDER BY o.position_level_code DESC, o.employee_code;
-- คาดหวัง: 11 rows, payment_method = 'BANK_TRANSFER'
```

---

## 11. Mapping Matrix — Sheets ที่เกี่ยวข้องกับ SI

### 11.1 กติกาการอ่าน Matrix

1. **Field Key** = ฟิลด์หลักที่ใช้ยืนยันความสอดคล้องของข้อมูล
2. **Table** = ตารางหลักที่เกี่ยวข้อง
3. **View** = มุมมองที่ใช้ตรวจเชิงธุรกิจ
4. **Validation Query** = SQL ตัวอย่างสั้นๆ

### 11.2 SI Mapping Matrix (9 Sheets)

| # | Sheet | Field Key | Table หลัก | View ที่ใช้ตรวจ | Validation Query (ตัวอย่าง) |
|---|---|---|---|---|---|
| 1 | Actual | salesman_code, product_code, actual_amount, period_id | trn_sales_actual | — | `SELECT COUNT(*) FROM trn_sales_actual a JOIN mst_channel c ON c.channel_id=a.channel_id WHERE c.channel_code=N'SI';` |
| 2 | ASTBase | salesman_code, direct_sup_code, dept_mgr_code, ad_code | mst_org_hierarchy | vw_si_salesman_hierarchy | `SELECT COUNT(*) FROM mst_org_hierarchy h JOIN mst_channel c ON c.channel_id=h.channel_id WHERE c.channel_code=N'SI';` |
| 3 | HR Rep | employee_code, employee_name_th, job_function_code, position_level_id | mst_employee | — | `SELECT COUNT(*) FROM mst_employee e JOIN mst_channel c ON c.channel_id=e.channel_id WHERE c.channel_code=N'SI';` |
| 4 | Org Unit | unit_type, unit_code, unit_name, unit_name_th | mst_org_unit | — | `SELECT COUNT(*) FROM mst_org_unit WHERE channel_id=(SELECT channel_id FROM mst_channel WHERE channel_code=N'SI');` |
| 5 | Target & Cal_Staff | salesman_code, product_code, target_amount, incentive_base, product_weight, goal_multiplier, incentive_amount | trn_sales_target, trn_incentive_detail, mst_incentive_rate, mst_product_weight | — | `SELECT COUNT(*) FROM trn_sales_target t JOIN mst_channel c ON c.channel_id=t.channel_id WHERE c.channel_code=N'SI';` |
| 6 | For HR (Variable) | employee_code, incentive_staff, incentive_sect, incentive_dept, incentive_ad, total_variable | out_for_hr_variable | vw_for_hr_si_sheet | `SELECT COUNT(*) FROM out_for_hr_variable v JOIN trn_calc_run r ON r.calc_run_id=v.calc_run_id JOIN mst_channel c ON c.channel_id=r.channel_id WHERE c.channel_code=N'SI';` |
| 7 | Product Weight | product_code, weight_percent | mst_product_weight, mst_product | — | `SELECT p.product_code, pw.weight_percent FROM mst_product_weight pw JOIN mst_product p ON p.product_id=pw.product_id WHERE pw.channel_id=(SELECT channel_id FROM mst_channel WHERE channel_code=N'SI');` |
| 8 | Rate Table | position_code, rate_new, effective_from | mst_incentive_rate, mst_position_level | — | `SELECT pl.position_code, ir.rate_new FROM mst_incentive_rate ir JOIN mst_position_level pl ON pl.position_level_id=ir.position_level_id WHERE ir.channel_id=(SELECT channel_id FROM mst_channel WHERE channel_code=N'SI');` |
| 9 | Period | period_code, sales_month | mst_period | — | `SELECT COUNT(*) FROM mst_period WHERE is_active=1;` |

### 11.3 Control Checks แนะนำหลังโหลดข้อมูล SI

**1. Hierarchy Coverage Check (SI — 4 ระดับ)**

```sql
SELECT
    h.salesman_code,
    h.direct_sup_code,
    h.dept_mgr_code,
    h.ad_code,
    CASE WHEN h.direct_sup_code IS NULL THEN 'missing_sect'
         WHEN h.dept_mgr_code IS NULL   THEN 'missing_dept'
         WHEN h.ad_code IS NULL         THEN 'missing_ad'
         ELSE 'OK' END AS gap_type
FROM dbo.mst_org_hierarchy h
JOIN dbo.mst_channel c ON c.channel_id = h.channel_id
WHERE c.channel_code = N'SI'
  AND (h.direct_sup_code IS NULL OR h.dept_mgr_code IS NULL OR h.ad_code IS NULL);
```

**2. SI Org Unit Completeness**

```sql
-- ตรวจว่า manager codes ใน hierarchy มี org unit รองรับ
SELECT DISTINCT sh.sect_mgr_code,
    (SELECT unit_name_th FROM dbo.mst_org_unit ou WHERE ou.channel_id = c.channel_id AND ou.unit_code = sh.sect_mgr_code) AS section_name,
    (SELECT unit_name_th FROM dbo.mst_org_unit ou WHERE ou.channel_id = c.channel_id AND ou.unit_code = sh.dept_mgr_code) AS dept_name,
    (SELECT unit_name_th FROM dbo.mst_org_unit ou WHERE ou.channel_id = c.channel_id AND ou.unit_code = sh.ad_code)       AS div_name
FROM dbo.vw_si_salesman_hierarchy sh
JOIN dbo.mst_channel c ON c.channel_code = N'SI'
WHERE sh.period_code = N'FY2026-04';
```

**3. SI Rate Coverage Check**

```sql
SELECT pl.position_code, pl.hierarchy_level, ir.rate_new, ir.effective_from
FROM dbo.mst_incentive_rate ir
JOIN dbo.mst_position_level pl ON pl.position_level_id = ir.position_level_id
WHERE ir.channel_id = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'SI')
  AND ir.is_active = 1
ORDER BY pl.hierarchy_level;
-- ต้องได้ 4 rows: STAFF, SECT_MGR, DEPT_MGR, AD
```

**4. SI Product Weight Coverage**

```sql
SELECT p.product_code, pw.weight_percent, pw.effective_from
FROM dbo.mst_product_weight pw
JOIN dbo.mst_product p ON p.product_id = pw.product_id
WHERE pw.channel_id = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'SI')
  AND pw.is_active = 1
ORDER BY pw.weight_percent DESC;
-- ต้องได้ 6 rows: AJ(30%), RD(20%), BD(15%), YY(10%), AJP(8%), PDC(7%)
```

**5. SI Incentive Matrix Completeness**

```sql
SELECT
    (SELECT COUNT(*) FROM dbo.trn_incentive_detail d
     JOIN dbo.trn_calc_run r ON r.calc_run_id = d.calc_run_id
     JOIN dbo.mst_channel c ON c.channel_id = r.channel_id
     WHERE c.channel_code = N'SI') AS incentive_detail_rows,
    (SELECT COUNT(*) FROM dbo.out_for_hr_variable v
     JOIN dbo.trn_calc_run r ON r.calc_run_id = v.calc_run_id
     JOIN dbo.mst_channel c ON c.channel_id = r.channel_id
     WHERE c.channel_code = N'SI') AS for_hr_rows;
-- Period 1: detail_rows=33 (21 STAFF + 6 SECT_MGR + 3 DEPT_MGR + 3 AD), for_hr_rows=11
```

---

## 12. ความแตกต่างหลักระหว่าง SI, MT และ TT

| ประเด็น | SI (Sales & Import) | MT (Modern Trade) | TT (Traditional Trade) |
|---|---|---|---|
| แหล่งข้อมูลยอดขาย | Salesman Code + Product Code (โดยตรง) | BI SalesCode + Product Group | Salesman Code + SKU (โดยตรง) |
| Mapping ก่อนคำนวณ | **ไม่ต้อง** | **ต้องทำเสมอ** (BI SalesCode → Salesman) | **ไม่ต้อง** |
| Product Unit | Product Code | Product Group | SKU |
| จำนวน Hierarchy Level | **4 ระดับ** (STAFF, SECT_MGR, DEPT_MGR, AD) | **4 ระดับ** (เหมือน SI) | **5 ระดับ** (เพิ่ม DIV_MGR) |
| Sub-channel | ไม่มี | C&C vs Non-C&C | ไม่มี |
| ws_type ต่อ Salesman | ไม่มี (ทุกคนใช้ rate เดียวกัน) | ไม่มี | มี (TOP_WS, WS_SF, WS_WH) |
| Manager Cascade | **มี (4 ระดับ)** — dynamic cascade จาก aggregate STAFF actuals via hierarchy | มี (4 ระดับ, preset values) | มี (5 ระดับ) |
| incentive_div field | ไม่มี (= 0) | ไม่มี (= 0) | มี |
| payment_method | **BANK_TRANSFER** | **BANK_TRANSFER** | BANK_TRANSFER |
| For HR View | `vw_for_hr_si_sheet` | `vw_for_hr_mt_sheet` | `vw_for_hr_tt_sheet` |
| Stored Procedure | `usp_run_si_incentive_calculation` | `usp_run_mt_incentive_calculation` | `usp_run_tt_incentive_calculation` |
| Goal Threshold | 9 bands (shared) | 9 bands (shared) | 9 bands (shared) |
| จำนวน Sheets (Matrix) | **9 Sheets** | **15 Sheets** | **26 Sheets** |
| Base Rate (STAFF) | **15,000 ฿** | 4,000–5,500 ฿ | แตกต่างตาม ws_type |

---

---

## 13. Cascade Formula Detail (v1.1)

### 13.1 วิธีคำนวณ Manager Achievement

สำหรับ manager แต่ละคน ต่อ product แต่ละตัว:

```
manager_target(product) = SUM(STAFF target ทุกคนใต้สังกัด)
manager_actual(product) = SUM(STAFF actual ทุกคนใต้สังกัด)
manager_achievement(product) = manager_actual / manager_target
manager_goal_multiplier = Lookup(mst_goal_threshold)
manager_incentive(product) = incentive_base(position_level) × product_weight × goal_multiplier
```

> ความสัมพันธ์สายบังคับบัญชาดึงจาก `mst_org_hierarchy` (effective_month ล่าสุด ≤ sales_month)

### 13.2 ตัวอย่าง SECT_MGR (SIM01 — Section 1)

SIM01 ดูแล SI001–SI005 (5 คน) ต่อ Product AJ:

| Employee | Target AJ | Actual AJ |
|---|---|---|
| SI001 | 1,000,000 | 1,050,000 |
| SI002 | 1,000,000 | 1,100,000 |
| SI003 | 800,000 | 760,000 |
| SI004 | 900,000 | 918,000 |
| SI005 | 1,000,000 | 1,080,000 |
| **รวม SIM01** | **4,700,000** | **4,908,000** |

```
Achievement AJ = 4,908,000 / 4,700,000 = 104.43% → Band 5 → mult = 1.08
Incentive AJ   = 11,000 × 0.30 × 1.08 = 3,564.00
```

ทำซ้ำต่อ product RD และ BD แล้ว `total_variable = SUM` ทุก product

### 13.3 Object ที่สร้างใหม่ใน v1.1

| Object | ประเภท | วัตถุประสงค์ |
|---|---|---|
| `dbo.usp_run_si_incentive_calculation` | Stored Procedure (updated) | เพิ่ม INSERT 2: Manager Cascade block |
| `dbo.vw_for_hr_si_sheet` | View | ForHR page query — เหมือน `vw_for_hr_mt_sheet` |
| `src/.../PortalDataService.cs` | C# Service (updated) | `GetForHrSiSheetAsync` ใช้ `vw_for_hr_si_sheet` แทน inline SQL |

---

*เอกสารนี้จัดทำโดย GitHub Copilot จากข้อมูลใน DB `AJT_SALE_INCENTIVE` และ codebase `src/AjtIncentive.Web`*
*อ้างอิง Template: `AJT_MT-Flow-Process_Summary.md` (v1.0)*
