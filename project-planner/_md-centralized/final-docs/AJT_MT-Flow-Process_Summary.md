# AJT MT Flow Process Summary

วันที่: 2026-06-29
เวอร์ชัน: v1.0
ขอบเขต: เอกสารอธิบาย MT Flow (Modern Trade) สำหรับทีม Business, SA, Dev และ QA

---

## Changelog

| เวอร์ชัน | วันที่ | รายละเอียด |
|---|---|---|
| v1.0 | 2026-06-29 | Initial release — MT Flow ครบ 4 ระดับ, Goal Threshold 9 bands, Mapping BI SalesCode, C&C vs Non-C&C, Mapping Matrix 15 Sheets |

---

## 1. วัตถุประสงค์

เอกสารนี้สรุปการไหลของ MT (Modern Trade) แบบครบลำดับ ตั้งแต่รับข้อมูลยอดขายจาก BI ผ่าน Mapping BI SalesCode ไปยัง Salesman Code ตรวจ Validation คำนวณ Staff และ Cascade ขึ้น 4 ระดับ ไปจนถึงการสร้างผลลัพธ์ For HR เพื่อให้ทุกทีมใช้ความเข้าใจเดียวกัน

---

## 2. หลักการของ MT

1. MT รับข้อมูลยอดขายจาก BI ในรูปแบบ **BI SalesCode + Product Group** (ไม่ใช่ SKU)
2. MT ต้องทำ **Mapping** ก่อนเสมอ — แปลง BI SalesCode → Salesman Code ผ่าน `mst_salesman_mapping` และ Product Group → Product Code ผ่าน `mst_product_mapping`
3. MT แบ่ง Sub-channel เป็น **C&C (Cash & Carry)** และ **Non-C&C** โดยมี Job Function แยกกัน (`MT_SECT_MGR_CC`, `MT_SUPERVISOR_CC`) สำหรับ C&C
4. โครงสร้าง Hierarchy มี **4 ระดับ** (ไม่มี DIV_MGR ต่างจาก TT ที่มี 5 ระดับ)
5. สูตรระดับ STAFF คำนวณราย **Product Group**: `base_rate × weight_pct × goal_multiplier`
6. สูตรระดับ Manager (SECT_MGR, DEPT_MGR, AD) ใช้ AVG(goal_multiplier) ของลูกน้องโดยตรงคูณกับ `base_rate` ของตำแหน่งนั้น
7. Goal Multiplier ใช้ Lookup ตาม **9-band threshold table** (`mst_goal_threshold`)
8. ไม่มี ws_type ต่อ Salesman — ทุกคนใช้ base_rate เดียวกันตาม position_level_code

---

## 3. ลำดับการไหลของ MT

```
[BI / DWC]
     ↓ BI SalesCode + Product Group → stg_bi_sales
[Mapping Layer]
     ↓ mst_salesman_mapping → Salesman Code
     ↓ mst_product_mapping  → Product Code (MT product group)
[Validation Gate]
     ↓ ตรวจ Period / Required Fields / Hierarchy / Mapping coverage
[trn_sales_actual]
     ↓ คำนวณ PCT_ACHIEVEMENT ราย Salesman × Product
[Step 1: STAFF Incentive per Product]
     ↓ base_rate × weight_pct × goal_multiplier  → trn_incentive_detail
[Step 2: SECT_MGR Rollup]
     ↓ AVG(goal_multiplier) ของ Staff ใต้สังกัด × SECT_MGR base_rate
[Step 3: DEPT_MGR Rollup]
     ↓ AVG(goal_multiplier) ของ SECT_MGR ใต้สังกัด × DEPT_MGR base_rate
[Step 4: AD Rollup]
     ↓ AVG(goal_multiplier) ของ DEPT_MGR ใต้สังกัด × AD base_rate
[Aggregate]
     ↓ ROUND(SUM(incentive_per_product), 2) → out_for_hr_variable
[trn_calc_run]
     ↓ run_status = CALCULATED
[For HR Output]
     ↓ Export / Approval
```

### 3.1 รายละเอียดแต่ละ Step

| Step | กิจกรรม | Input | Output |
|---|---|---|---|
| 0 | รับ BI Data | stg_bi_sales (BI SalesCode + Product Group + Actual) | staging records |
| 1 | Mapping BI → Salesman | mst_salesman_mapping, mst_product_mapping | trn_sales_actual (Salesman Code + Product Code) |
| 2 | Validation | mst_period, mst_org_hierarchy, trn_sales_target | ผ่าน / Error log |
| 3 | PCT Achievement | trn_sales_actual / trn_sales_target | actual/target ratio → goal_multiplier lookup |
| 4 | STAFF Incentive | base_rate × weight_pct × goal_mult | trn_incentive_detail (STAFF level) |
| 5 | SECT_MGR Incentive | AVG(goal_mult_staff) × SECT_MGR rate | trn_incentive_detail (SECT_MGR level) |
| 6 | DEPT_MGR Incentive | AVG(goal_mult_sect) × DEPT_MGR rate | trn_incentive_detail (DEPT_MGR level) |
| 7 | AD Incentive | AVG(goal_mult_dept) × AD rate | trn_incentive_detail (AD level) |
| 8 | Rollup | ROUND(SUM per employee, 2) | out_for_hr_variable |
| 9 | Update Calc Run | trn_calc_run | run_status = CALCULATED |

### 3.2 คำสั่ง SP สำหรับ MT

```sql
-- รัน MT Incentive สำหรับ Period ที่ต้องการ
EXEC dbo.usp_run_mt_incentive_calculation
    @PeriodId   = 1,         -- period_id จาก mst_period
    @ApprovedBy = N'system'; -- ผู้อนุมัติ (log ไว้ใน trn_calc_run)
```

---

## 4. สูตรหลักที่ใช้ใน MT

### 4.1 สูตรคำนวณ PCT Achievement

```
PCT_ACHIEVEMENT = ROUND(actual_amount / target_amount, 4)
```

จากนั้น Lookup `mst_goal_threshold` เพื่อได้ `goal_multiplier`

### 4.2 Goal Threshold Table (MT — 9 Bands)

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

> ⚠️ Manager จะได้รับผลกระทบ (penalized) ถ้า AVG < 1.00 — **ไม่มี floor**

### 4.3 สูตร Incentive ต่อ Position

| Position | สูตร | หมายเหตุ |
|---|---|---|
| STAFF | `ROUND(base_rate × weight_pct × goal_mult, 0)` | คำนวณราย Product Group |
| SECT_MGR | `base_rate × weight_pct × goal_mult` | ไม่ ROUND ระหว่างคำนวณ |
| DEPT_MGR | `ROUND(base_rate × weight_pct × goal_mult, 0)` | ROUND ทุก product row |
| AD | `base_rate × weight_pct × goal_mult` | ไม่ ROUND ระหว่างคำนวณ |
| Rollup (ทุก Level) | `ROUND(SUM(incentive_per_product), 2)` | Aggregate สุดท้ายก่อน insert out_for_hr_variable |

> **goal_mult** สำหรับ Manager = AVG(goal_multiplier) ของ Direct Reports ทั้งหมด (ทุก product row, ไม่ใช่ avg-of-avg)

### 4.4 ค่า Base Rate ต่อ Position Level (MT)

| Position Code | ชื่อตำแหน่ง | Hierarchy Level | Base Rate (฿) |
|---|---|---|---|
| STAFF | Salesman / Staff | 1 | 4,000 – 5,500 (ขึ้นกับ Product Group) |
| SECT_MGR | Section Manager | 2 | 5,000 – 6,000 |
| DEPT_MGR | Department Manager | 3 | 6,000 |
| AD | Associate Director | 5 | 6,000 |

> **หมายเหตุ**: Rate ต่อ Position + Product Group เก็บใน `mst_incentive_rate` และดึงผ่าน view `vw_mt_mst_position_incentive_rate_detail`

---

## 5. โครงสร้าง Hierarchy ของ MT

MT มี **4 ระดับ** (ต่างจาก TT ที่มี 5 ระดับ — MT ไม่มีระดับ DIV_MGR)

```
Level 5 — AD (Associate Director)
              │
Level 3 — DEPT_MGR (Department Manager)
         ┌───┴────────────────────────┐
         │ C&C Dept                 Non-C&C Dept
Level 2 — SECT_MGR_CC             SECT_MGR (×หลาย section)
         │                         │
Level 1 — SUPERVISOR_CC / STAFF   SUPERVISOR / STAFF
```

### 5.1 Job Function ของ MT (7 ประเภท)

| Job Function Code | ชื่อภาษาอังกฤษ | ชื่อภาษาไทย | Sub-channel |
|---|---|---|---|
| MT_AD | MT Associate Director | ผู้อำนวยการฝ่ายขาย MT | ทั้งหมด |
| MT_DEPT_MGR | MT Department Manager | ผู้จัดการแผนก MT | ทั้งหมด |
| MT_SECT_MGR_CC | MT Section Manager (Cash & Carry) | ผู้จัดการส่วนขาย MT (Cash & Carry) | C&C |
| MT_SECT_MGR | MT Section Manager | ผู้จัดการส่วนขาย MT | Non-C&C |
| MT_SUPERVISOR_CC | MT Supervisor (Cash & Carry) | หัวหน้าขาย MT (Cash & Carry) | C&C |
| MT_SUPERVISOR | MT Supervisor | หัวหน้าขาย MT | Non-C&C |
| MT_STAFF | MT Staff | พนักงานขาย MT | ทั้งหมด |

### 5.2 โครงสร้าง Mock Data (Period 1 — 27 คน)

| Employee Code | ตำแหน่ง | ระดับ | หมายเหตุ |
|---|---|---|---|
| 222222 | AD | MT_AD | MT Sales Division (Top) |
| 222223 | Dept Mgr | MT_DEPT_MGR | C&C Department |
| 222234 | Dept Mgr | MT_DEPT_MGR | Non-C&C Department |
| 222235 | Sect Mgr | MT_SECT_MGR_CC | C&C Section |
| 222208 | Sect Mgr | MT_SECT_MGR | Non-C&C Section |
| 222236 | Sect Mgr | MT_SECT_MGR | Non-C&C Section |
| 222237 | Sect Mgr | MT_SECT_MGR | Non-C&C Section |
| 222238 | Sect Mgr | MT_SECT_MGR | Non-C&C Section |
| (19 คน) | Supervisor / Staff | MT_SUPERVISOR_CC, MT_SUPERVISOR, MT_STAFF | salesman_code: 5490000xxx |

### 5.3 Salesman Code ต่อ BI SalesCode (Mapping)

Salesman จะมี `salesman_code` (รูปแบบ `5490000xxx`) ซึ่งต่างจาก `employee_code` ที่เป็น `22xxxx`

ตัวอย่าง:
- Supervisor C&C: 222206, 222207, 222215, 222216 → salesman_code: 5490000711, 5490000703, 5490000714, 5490000705
- BI จะส่งข้อมูลมาในรูป BI SalesCode ก่อน → ต้อง Map ก่อนทุกครั้ง

---

## 6. Prorate ใน MT

เมื่อพนักงานเข้า/ออก/ย้าย กลางงวดคำนวณ ระบบจะปรับ incentive ตาม ratio วันทำงาน

### 6.1 ประเภท Prorate (4 ประเภท)

| Prorate Type | เงื่อนไข | ตัวอย่าง |
|---|---|---|
| `JOIN` | พนักงานเข้างานกลางเดือน | เข้างานวันที่ 16 ทำงาน 16/31 วัน |
| `RESIGN` | พนักงานลาออกกลางเดือน | ลาออกวันที่ 20 ทำงาน 20/31 วัน |
| `TRANSFER` | Transfer ข้าม Region กลางงวด | ย้ายไปช่วง 12 วัน → prorate 12/31 |
| `POSITION_CHANGE` | เปลี่ยนตำแหน่งกลางงวด | เปลี่ยน position ช่วง 21 วัน → prorate 21/31 |

### 6.2 สูตร Prorate

```
prorate_ratio  = ROUND(actual_days / total_days, 4)
incentive_final = ROUND(incentive_calculated × prorate_ratio, 2)
```

ข้อมูล Prorate เก็บใน `dbo.trn_prorate_adjustment` (period_id, channel_id, employee_code, prorate_type, actual_days, total_days)

---

## 7. Validation Gate ที่ต้องผ่านก่อนคำนวณ

### 7.1 รายการตรวจ

| # | Gate | รายการตรวจ | ตาราง / View |
|---|---|---|---|
| 1 | Period Alignment | เดือนข้อมูลขายต้องตรงกับ period ที่ระบบเปิดคำนวณ | mst_period |
| 2 | BI SalesCode Mapping | BI SalesCode ทุก code ต้องมี mapping ไปยัง salesman_code | mst_salesman_mapping |
| 3 | Product Group Mapping | Product Group ทุก group ต้องมี mapping ไปยัง product_code | mst_product_mapping |
| 4 | Required Fields | ต้องมี Salesman Code, Product Group, Actual, Target ครบ | trn_sales_actual, trn_sales_target |
| 5 | Hierarchy Consistency | โครงสร้างสายบังคับบัญชาครบ 4 ระดับ ไม่มีช่องว่าง | mst_org_hierarchy |
| 6 | Incentive Rate Readiness | ต้องมี rate สำหรับทุก position + product ที่ใช้ | mst_incentive_rate |
| 7 | Goal Threshold | mst_goal_threshold ต้องมีครบ 9 bands และ is_active=1 | mst_goal_threshold |
| 8 | Duplicate Check | ไม่มี duplicate (period_id + employee_code + product_code) ใน target/actual | trn_sales_target, trn_sales_actual |

### 7.2 Validation Queries

```sql
-- 1. BI SalesCode ที่ยังไม่มี Mapping
SELECT DISTINCT bi_sales_code
FROM stg_bi_sales s
WHERE NOT EXISTS (
    SELECT 1 FROM mst_salesman_mapping m
    WHERE m.bi_sales_code = s.bi_sales_code AND m.is_active = 1
);

-- 2. Hierarchy Gap Check (MT — 4 ระดับ)
SELECT employee_code, direct_sup_code, dept_mgr_code, ad_code
FROM mst_org_hierarchy h
JOIN mst_channel c ON c.channel_id = h.channel_id
WHERE c.channel_code = N'MT'
  AND (direct_sup_code IS NULL OR dept_mgr_code IS NULL OR ad_code IS NULL);

-- 3. ตรวจ Goal Threshold ว่าครบ 9 bands
SELECT COUNT(*) AS band_count FROM mst_goal_threshold WHERE is_active = 1;
-- ต้องได้ 9

-- 4. ตรวจ Calc Run Status ล่าสุด
SELECT TOP 5 calc_run_id, run_status, period_id, created_at
FROM trn_calc_run cr
JOIN mst_channel c ON c.channel_id = cr.channel_id
WHERE c.channel_code = N'MT'
ORDER BY created_at DESC;
```

---

## 8. Output ที่ต้องได้จาก MT

| # | Output | ตาราง / View | หมายเหตุ |
|---|---|---|---|
| 1 | ผลคำนวณ STAFF ราย Product Group | trn_incentive_detail | แยกตาม employee_code + product_code |
| 2 | ผลรวม SECT_MGR | trn_incentive_detail | Rollup จาก Staff ที่อยู่ใต้สังกัด |
| 3 | ผลรวม DEPT_MGR | trn_incentive_detail | Rollup จาก Sect Mgr |
| 4 | ผลรวม AD | trn_incentive_detail | Rollup จาก Dept Mgr |
| 5 | For HR Variable | out_for_hr_variable | total_variable = SUM ทุกระดับ |
| 6 | For HR Variable (Prorate applied) | out_for_hr_variable | เฉพาะพนักงานที่มี trn_prorate_adjustment |
| 7 | Calc Run Record | trn_calc_run | run_status = CALCULATED, approved_by |

```sql
-- ตรวจ Output For HR ของ MT
SELECT
    o.employee_code,
    o.incentive_staff,
    o.incentive_sect,
    o.incentive_dept,
    o.incentive_ad,
    o.prorate_ratio,
    o.total_variable
FROM out_for_hr_variable o
JOIN trn_calc_run r ON r.calc_run_id = o.calc_run_id
JOIN mst_channel c ON c.channel_id = r.channel_id
WHERE c.channel_code = N'MT'
ORDER BY o.employee_code;

-- ดู MT Sheet Output ผ่าน View
SELECT * FROM dbo.vw_for_hr_mt_sheet ORDER BY employee_code;
```

---

## 9. จุดเสี่ยงสำคัญของ MT

| # | จุดเสี่ยง | ผลกระทบ | วิธีป้องกัน |
|---|---|---|---|
| 1 | **BI SalesCode ไม่มี Mapping** | ยอดขายหายจากการคำนวณ | ตรวจ stg_bi_sales vs mst_salesman_mapping ก่อน run SP |
| 2 | **Product Group ไม่มี Mapping** | product_code = NULL → ไม่เข้าสูตร | ตรวจ mst_product_mapping ครอบคลุม product group ทั้งหมด |
| 3 | **Hierarchy ไม่ครบ 4 ระดับ** | Cascade ขึ้น Manager ผิดพลาด หรือ manager ไม่ได้ incentive | ตรวจ mst_org_hierarchy ทุก period ก่อน run |
| 4 | **Rate ไม่มีสำหรับ product + position บางคู่** | incentive_per_product = 0 หรือ NULL | ตรวจ mst_incentive_rate ให้ครบคู่ product × position |
| 5 | **Goal Threshold ไม่ครบ / ซ้อนทับ** | goal_multiplier ผิด ทุก employee | ตรวจ 9 bands ไม่ overlap และ achievement_to ต่อเนื่อง |
| 6 | **C&C vs Non-C&C ปะปน** | Sect Mgr C&C ได้ลูกน้อง Non-C&C หรือกลับกัน | ตรวจ job_function_code ให้ตรงกับ org_unit |
| 7 | **Prorate ไม่ถูก Apply** | พนักงานย้ายได้ incentive เต็มทั้งๆ ที่ทำงานไม่ครบเดือน | ตรวจ trn_prorate_adjustment มีครบก่อน run |
| 8 | **Period mismatch** | จ่ายผิดรอบ | ตรวจ @PeriodId ก่อน EXEC SP เสมอ |

---

## 10. เช็คลิสต์ QA สำหรับ MT

### 10.1 Pre-Calculation

- [ ] BI SalesCode ทุก code มี mapping ใน `mst_salesman_mapping` (is_active=1)
- [ ] Product Group ทุก group มี mapping ใน `mst_product_mapping` (is_active=1)
- [ ] `mst_org_hierarchy` มีข้อมูลสำหรับ period นี้ ไม่มี NULL ที่ direct_sup_code / dept_mgr_code / ad_code
- [ ] `mst_goal_threshold` มีครบ 9 bands ไม่ overlap
- [ ] `mst_incentive_rate` มี rate สำหรับทุก position + product ที่ใช้
- [ ] ไม่มี duplicate ใน `trn_sales_target` (period_id + salesman_code + product_code)

### 10.2 Post-Calculation

- [ ] `trn_calc_run.run_status = CALCULATED` (ไม่ใช่ FAILED / IN_PROGRESS)
- [ ] `trn_incentive_detail` มีข้อมูลครบทุก employee × product
- [ ] ตรวจ STAFF incentive ตัวอย่าง: `base_rate × weight_pct × goal_mult = ค่าที่คาดหวัง`
- [ ] ตรวจ SECT_MGR: `AVG(goal_mult ลูกน้อง) × rate = ค่าที่คาดหวัง`
- [ ] ตรวจ DEPT_MGR และ AD ด้วยวิธีเดียวกัน
- [ ] `out_for_hr_variable.total_variable` ตรงกับ expected sample (TC02)
- [ ] Prorate employees: `incentive_final = incentive_calculated × prorate_ratio`
- [ ] ไม่มี employee ที่อยู่ใน `trn_incentive_detail` แต่ไม่อยู่ใน `out_for_hr_variable`

### 10.3 TC02 Expected Values (Period 1, calc_run_id = 1052)

| Employee Code | Position | Expected Total Variable (฿) |
|---|---|---|
| 222208 | SECT_MGR | 5,765.00 |
| 222222 | AD | 6,732.00 |
| 222223 | DEPT_MGR | 5,959.00 |
| 222234 | DEPT_MGR | 5,964.00 |
| 222235 | SECT_MGR_CC | 6,233.68 |
| 222236 | SECT_MGR | 5,900.00 |
| 222237 | SECT_MGR | 6,058.59 |
| 222238 | SECT_MGR | 5,113.13 |

```sql
-- เปรียบเทียบผลจริงกับ TC02
SELECT
    o.employee_code,
    e.full_name_th,
    pl.position_code,
    o.total_variable
FROM out_for_hr_variable o
JOIN trn_calc_run r ON r.calc_run_id = o.calc_run_id
JOIN mst_channel c ON c.channel_id = r.channel_id
LEFT JOIN mst_employee e ON e.employee_code = o.employee_code
LEFT JOIN mst_org_hierarchy h ON h.employee_code = o.employee_code AND h.channel_id = r.channel_id
LEFT JOIN mst_position_level pl ON pl.position_level_id = h.position_level_id
WHERE c.channel_code = N'MT'
  AND r.calc_run_id = 1052
ORDER BY o.employee_code;
```

---

## 11. Mapping Matrix — 15 Sheets: Sheet → Field Key → Table → View → Validation Query (MT)

### 11.1 กติกาการอ่าน Matrix

1. **Field Key** = ฟิลด์หลักที่ใช้ยืนยันความสอดคล้องของข้อมูล
2. **Table** = ตารางหลักที่เกี่ยวข้อง (staging / master / transaction / output)
3. **View** = มุมมองที่ใช้ตรวจเชิงธุรกิจหรือเชิงโครงสร้าง
4. **Validation Query** = SQL ตัวอย่างสั้นๆ สำหรับเช็คความครบถ้วน/ความสัมพันธ์

### 11.2 Full Mapping Matrix (15 Sheets)

| # | Sheet | Field Key | Table หลัก | View ที่ใช้ตรวจ | Validation Query (ตัวอย่าง) |
|---|---|---|---|---|---|
| 1 | Actual | bi_sales_code, product_group, actual_amount, sales_month | stg_bi_sales, trn_sales_actual | vw_mst_channel_relations | `SELECT COUNT(*) FROM trn_sales_actual a JOIN mst_channel c ON c.channel_id=a.channel_id WHERE c.channel_code=N'MT';` |
| 2 | ASTBase | employee_code, direct_sup_code, dept_mgr_code, ad_code, position_level_id | mst_org_hierarchy | vw_mst_org_hierarchy_management_chain, vw_mst_org_hierarchy_detail | `SELECT COUNT(*) FROM mst_org_hierarchy h JOIN mst_channel c ON c.channel_id=h.channel_id WHERE c.channel_code=N'MT';` |
| 3 | HR Rep | employee_code, full_name_th, job_function_code, position_level_id | mst_employee, stg_hcm_employee | vw_employee_org_profile | `SELECT COUNT(*) FROM mst_employee e JOIN mst_channel c ON c.channel_id=e.channel_id WHERE c.channel_code=N'MT';` |
| 4 | Mapping (BI→Salesman) | bi_sales_code, salesman_code, effective_from | mst_salesman_mapping | vw_mst_channel_relations | `SELECT COUNT(*) FROM mst_salesman_mapping WHERE is_active=1 AND channel_id=(SELECT channel_id FROM mst_channel WHERE channel_code=N'MT');` |
| 5 | Mapping (Product Group) | bi_product_group, product_code, product_name | mst_product_mapping, mst_product | vw_mst_channel_relations | `SELECT COUNT(*) FROM mst_product_mapping WHERE is_active=1 AND channel_id=(SELECT channel_id FROM mst_channel WHERE channel_code=N'MT');` |
| 6 | Target & Cal_Staff | salesman_code, product_code, target_amount, base_rate, weight_pct, goal_multiplier, incentive_staff | trn_sales_target, trn_incentive_detail, mst_incentive_rate | vw_mt_formula_incentive_matrix | `SELECT COUNT(*) FROM trn_sales_target t JOIN mst_channel c ON c.channel_id=t.channel_id WHERE c.channel_code=N'MT';` |
| 7 | Target & Cal_Sect (C&C) | sect_code, avg_goal_mult, base_rate, incentive_sect | trn_incentive_detail, mst_org_hierarchy | vw_mst_org_hierarchy_management_chain | `SELECT COUNT(*) FROM trn_incentive_detail d JOIN mst_position_level pl ON pl.position_level_id=d.position_level_id WHERE pl.position_code=N'SECT_MGR';` |
| 8 | Target & Cal_Sect (Non-C&C) | sect_code, avg_goal_mult, base_rate, incentive_sect | trn_incentive_detail, mst_org_hierarchy | vw_mst_org_hierarchy_management_chain | `SELECT COUNT(*) FROM trn_incentive_detail d JOIN mst_position_level pl ON pl.position_level_id=d.position_level_id WHERE pl.position_code=N'SECT_MGR';` |
| 9 | Target & Cal_Dept | dept_code, avg_goal_mult_from_sect, base_rate, incentive_dept | trn_incentive_detail, mst_org_hierarchy | vw_mst_org_hierarchy_management_chain | `SELECT COUNT(*) FROM trn_incentive_detail d JOIN mst_position_level pl ON pl.position_level_id=d.position_level_id WHERE pl.position_code=N'DEPT_MGR';` |
| 10 | Target & Cal_AD | ad_code, avg_goal_mult_from_dept, base_rate, incentive_ad | trn_incentive_detail, mst_org_hierarchy | vw_mst_org_hierarchy_management_chain | `SELECT COUNT(*) FROM trn_incentive_detail d JOIN mst_position_level pl ON pl.position_level_id=d.position_level_id WHERE pl.position_code=N'AD';` |
| 11 | For HR (Variable) | employee_code, incentive_staff, incentive_sect, incentive_dept, incentive_ad, prorate_ratio, total_variable | out_for_hr_variable | vw_for_hr_mt_sheet | `SELECT COUNT(*) FROM out_for_hr_variable v JOIN trn_calc_run r ON r.calc_run_id=v.calc_run_id JOIN mst_channel c ON c.channel_id=r.channel_id WHERE c.channel_code=N'MT';` |
| 12 | For HR (FIX) | employee_code, fix_pay_amount | out_for_hr_fix (ถ้ามี) | vw_mst_channel_relations | `SELECT COUNT(*) FROM out_for_hr_fix f JOIN trn_calc_run r ON r.calc_run_id=f.calc_run_id JOIN mst_channel c ON c.channel_id=r.channel_id WHERE c.channel_code=N'MT';` |
| 13 | Product | product_code, product_name_th, product_group, weight_pct | mst_product, mst_product_weight (via view) | vw_mt_formula_product_weight | `SELECT COUNT(*) FROM vw_mt_formula_product_weight;` |
| 14 | Rate Table | position_code, product_code, rate_new, effective_from | mst_incentive_rate, mst_position_level | vw_mt_incentive_rate, vw_mt_mst_position_incentive_rate_detail | `SELECT * FROM vw_mt_mst_position_incentive_rate_detail ORDER BY hierarchy_level;` |
| 15 | Period | period_code, sales_month, pay_month_var, pay_month_fix | mst_period, mst_payment_cycle | vw_mst_org_hierarchy_period_context | `SELECT COUNT(*) FROM mst_period WHERE is_active=1;` |

### 11.3 Control Checks แนะนำหลังโหลดข้อมูล MT

**1. BI Mapping Coverage Check**

```sql
-- BI SalesCode ที่ยังขาด Mapping
SELECT DISTINCT s.bi_sales_code
FROM stg_bi_sales s
LEFT JOIN mst_salesman_mapping m
    ON m.bi_sales_code = s.bi_sales_code AND m.is_active = 1
WHERE m.salesman_code IS NULL;
```

**2. Hierarchy Coverage Check (MT — 4 ระดับ)**

```sql
SELECT
    h.employee_code,
    h.direct_sup_code,
    h.dept_mgr_code,
    h.ad_code,
    CASE WHEN h.direct_sup_code IS NULL THEN 'missing_sect'
         WHEN h.dept_mgr_code IS NULL THEN 'missing_dept'
         WHEN h.ad_code IS NULL THEN 'missing_ad'
         ELSE 'OK' END AS gap_type
FROM mst_org_hierarchy h
JOIN mst_channel c ON c.channel_id = h.channel_id
WHERE c.channel_code = N'MT'
  AND (h.direct_sup_code IS NULL OR h.dept_mgr_code IS NULL OR h.ad_code IS NULL);
```

**3. MT Rate Coverage Check**

```sql
-- ตรวจ Rate ครบทุก position + product
SELECT position_code, position_name_en, hierarchy_level, rate_new
FROM dbo.vw_mt_mst_position_incentive_rate_detail
ORDER BY hierarchy_level;
```

**4. Goal Threshold Continuity Check**

```sql
SELECT sequence_no, achievement_from, achievement_to, multiplier
FROM dbo.vw_mt_formula_goal_threshold
ORDER BY sequence_no;
-- ต้องได้ 9 rows และ achievement_to ของ row n ต้องต่อเนื่องกับ achievement_from ของ row n+1
```

**5. MT Incentive Matrix Completeness**

```sql
SELECT
    (SELECT COUNT(*) FROM trn_incentive_detail d
     JOIN trn_calc_run r ON r.calc_run_id = d.calc_run_id
     JOIN mst_channel c ON c.channel_id = r.channel_id
     WHERE c.channel_code = N'MT') AS incentive_detail_rows,
    (SELECT COUNT(*) FROM out_for_hr_variable v
     JOIN trn_calc_run r ON r.calc_run_id = v.calc_run_id
     JOIN mst_channel c ON c.channel_id = r.channel_id
     WHERE c.channel_code = N'MT') AS for_hr_rows;
```

**6. Prorate Adjustment Check**

```sql
SELECT
    pa.employee_code,
    pa.prorate_type,
    pa.actual_days,
    pa.total_days,
    ROUND(CAST(pa.actual_days AS DECIMAL(10,4)) / pa.total_days, 4) AS prorate_ratio,
    pa.remarks
FROM trn_prorate_adjustment pa
JOIN mst_channel c ON c.channel_id = pa.channel_id
WHERE c.channel_code = N'MT'
  AND pa.is_active = 1
ORDER BY pa.prorate_type, pa.employee_code;
```

---

## 12. ความแตกต่างหลักระหว่าง MT และ TT

| ประเด็น | MT (Modern Trade) | TT (Traditional Trade) |
|---|---|---|
| แหล่งข้อมูลยอดขาย | BI SalesCode + Product Group | Salesman Code + SKU (โดยตรง) |
| Mapping ก่อนคำนวณ | **ต้องทำเสมอ** (BI SalesCode → Salesman) | **ไม่ต้อง** |
| Product Unit | Product Group | SKU |
| จำนวน Hierarchy Level | **4 ระดับ** (STAFF, SECT_MGR, DEPT_MGR, AD) | **5 ระดับ** (เพิ่ม DIV_MGR) |
| Sub-channel | C&C vs Non-C&C | ไม่มี Sub-channel |
| ws_type ต่อ Salesman | ไม่มี (ทุกคนใช้ rate เดียวกันตาม position) | มี (TOP_WS, WS_SF, WS_WH) |
| incentive_div field | ไม่มี | มี (ระดับ DIV_MGR) |
| Stored Procedure | `usp_run_mt_incentive_calculation` | `usp_run_tt_incentive_calculation` |
| จำนวน Sheets (Matrix) | **15 Sheets** | **26 Sheets** |
| Goal Threshold | 9 bands (0.90 → 1.30) | เหมือนกัน (shared) |

---

*เอกสารนี้จัดทำโดย GitHub Copilot จากข้อมูลใน DB `AJT_SALE_INCENTIVE` และ codebase `src/AjtIncentive.Web`*
*อ้างอิง Template: `AJT_TT-Flow-Process_Summary.md` (v4.0)*
