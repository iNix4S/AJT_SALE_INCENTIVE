# AJT TT Flow Process Summary

วันที่: 2026-06-14  
เวอร์ชัน: v2.0  
ขอบเขต: เอกสารอธิบาย TT Flow (Traditional Trade) สำหรับทีม Business, SA, Dev และ QA

---

## Changelog

| เวอร์ชัน | วันที่ | รายละเอียด |
|---|---|---|
| v1.0 | 2026-06-14 | Initial release — TT Flow ครบ 5 ระดับ, 26 Sheet Matrix, Validation Gate |
| v2.0 | 2026-06-14 | เพิ่ม `pct_salesman` (column + data + SP thread); เพิ่ม per-salesman `ws_type` ใน `mst_org_hierarchy`; แก้ SP ให้ lookup ws_type รายคน; เพิ่ม views ใหม่ 2 รายการ; เพิ่ม DDL Script Index (32 scripts) |
| v3.0 | 2026-06-15 | แก้สูตรคำนวณ Manager Cascade ให้ถูกต้อง (6 จุด): product_code='*', direct AVG(goal_multiplier), ลบ floor-to-1.0, ใช้ STAFF rate, raw precision สำหรับ multiply; ผลตรงกับ sheet 5/6 sections (section ที่เหลือเป็น data issue) |
| v4.0 | 2026-06-15 | แก้ rate ใน `mst_incentive_rate` ให้ตรงกับ T_SectAbove (SECT_MGR=4,000 / DEPT_MGR=5,000 / DIV_MGR=5,000 / AD=6,000); แก้ SP v6 ให้ดึง rate ตาม position_level_code (ไม่ hardcode STAFF); เพิ่ม DDL 34 view `vw_tt_incentive_rate` |

---

## 1. วัตถุประสงค์

เอกสารนี้สรุปการไหลของ TT แบบครบลำดับ ตั้งแต่รับข้อมูล ตรวจ validation คำนวณ Staff และ Cascade ขึ้น 5 ระดับ ไปจนถึงการสร้างผลลัพธ์ For HR เพื่อให้ทุกทีมใช้ความเข้าใจเดียวกัน

---

## 2. หลักการของ TT

1. TT ใช้ข้อมูลยอดขายตรงระดับ Salesman Code + SKU
2. TT ไม่ต้องทำ mapping แบบ MT
3. โครงสร้าง worksheet ฝั่งต้นทางเป็น single-sheet แต่การคำนวณในระบบมี hierarchy ครบ 5 ระดับ
4. Logic ระดับบนใช้ AVERAGEIFS เพื่อดึงผลจากระดับล่างตามเงื่อนไข
5. แต่ละ Salesman มี **ws_type** (ประเภทตำแหน่ง) ที่กำหนด incentive_base และ formula matrix ของตัวเอง
6. `pct_salesman` ใน `trn_sales_target` เก็บ %Salesman (goal_multiplier) จากชีตโดยตรงแทนการ lookup table

---

## 3. ลำดับการไหลของ TT

1. รับข้อมูล Salesman Code + SKU จาก BI
2. ตรวจ Validation Gate (Period, required fields, hierarchy)
3. คำนวณระดับ Staff (ราย SKU)
4. ส่งผลขึ้น Section Manager
5. ส่งผลขึ้น Department Manager
6. ส่งผลขึ้น Division Manager
7. ส่งผลขึ้น AD
8. รวมผลเป็น For HR Variable
9. ส่งเข้า Approval และ Export

---

## 4. สูตรหลักที่ใช้ใน TT

1. achievement = ROUND(Actual / Target, 4)
2. ถ้าเข้าเงื่อนไข shortage ให้ override achievement = 1.0
3. GOAL ใช้ lookup ตาม threshold (XLOOKUP หรือ HLOOKUP ตามโครงสร้างตาราง)
4. incentive_staff = incentive_base × product_weight_percent × goal_multiplier
   - `incentive_base` และ `product_weight_percent` มาจาก `mst_tt_ws_formula_matrix` โดย filter ตาม `ws_type` ของ salesman คนนั้น
   - `goal_multiplier` = `COALESCE(pct_salesman, goal_from_threshold, 0)` — ถ้า pct_salesman มีค่าใน `trn_sales_target` จะใช้ค่านั้นก่อน
5. incentive_sect / incentive_dept / incentive_div / incentive_ad = position_rate × avg_pct_section
   - `position_rate` = `mst_incentive_rate.rate_new` WHERE position_code = level นั้น (ตาม **T_SectAbove** sheet):
     - SECT_MGR = **4,000** / DEPT_MGR = **5,000** / DIV_MGR = **5,000** / AD = **6,000**
   - `avg_pct_section` = AVG(goal_multiplier) ของ **ทุก product×staff row** ที่อยู่ใต้สังกัด (direct AVG ไม่ใช่ avg-of-avg)
   - Manager **ถูก penalized** ได้ถ้า avg < 1.0 (ไม่มี floor ที่ 1.0)
   - ตัวอย่าง SECT_MGR: 4,000 × 1.084242... = **4,336.97**
6. การส่งผลขึ้นระดับบนใช้ AVG(goal_multiplier) ของระดับล่าง (ไม่ใช่ threshold lookup)

---

## 5. โครงสร้าง Hierarchy ของ TT

1. STAFF
2. SECT_MGR
3. DEPT_MGR
4. DIV_MGR
5. AD

หมายเหตุ: TT ต่างจาก MT ที่มี 4 ระดับ เพราะ TT ต้องรองรับ Division layer และ output ต้องมี incentive_div

### 5.1 ws_type ต่อ Salesman (per-salesman ws_type)

แต่ละ salesman มี ws_type ตาม **Job Function** ใน sheet `1) For HR` คอลัมน์ `Job Function`:

| Job Function (suffix ในวงเล็บ) | ws_type | incentive_base (STAFF) |
|---|---|---|
| `(Top W)` | `TOP_WS` | 4,000 |
| `(Shop Front)` | `WS_SF` | 3,500 |
| `(Warehouse)` | `WS_WH` | 3,500 |
| ไม่มี qualifier / Supervisor ทั่วไป | `TOP_WS` | 4,000 |

หมายเหตุ: Manager rates (SECT_MGR, DEPT_MGR, DIV_MGR, AD) **เหมือนกันทุก ws_type** ไม่ต้องแยก

### 5.2 ws_type mapping สำหรับ TT FY2026-05

| salesman_code | Position Level | ws_type | Section (direct_sup) |
|---|---|---|---|
| 110001 | Supervisor | TOP_WS | 110000 (Bangpoo) |
| 110002 | Staff | WS_SF | 110000 |
| 110003 | Staff | WS_WH | 110000 |
| 120001 | Supervisor | TOP_WS | 120000 (Nonthaburi) |
| 120002 | Staff | WS_SF | 120000 |
| 130001 | Supervisor | TOP_WS | 130000 (Pathum Thani) |
| 130002 | Staff | WS_SF | 130000 |
| 130003 | Staff | WS_WH | 130000 |
| 140001 | Supervisor | TOP_WS | 140000 (Pattanakan) |
| 140002 | Staff | WS_SF | 140000 |
| 140003 | Supervisor | WS_WH | 140000 |
| 150001 | Supervisor | TOP_WS | 150000 (Ram Indra) |
| 160001 | Supervisor | TOP_WS | 160000 (Thonburi) |
| 160002 | Supervisor | TOP_WS | 160000 |

ข้อมูลนี้เก็บใน `mst_org_hierarchy` คอลัมน์ `ws_type` (เพิ่มโดย DDL script 30)

---

## 6. Validation Gate ที่ต้องผ่านก่อนคำนวณ

1. Period alignment
- เดือนข้อมูลขายต้องตรงกับ period ที่ระบบเปิดคำนวณ

2. Required fields completeness
- ต้องมี Salesman Code, SKU, Actual, Target และ key ฟิลด์ที่จำเป็น

3. Hierarchy consistency
- โครงสร้างสายบังคับบัญชาต้องต่อเนื่องครบตามระดับ
- ตรวจ `mst_org_hierarchy` ว่ามี rows สำหรับ period นั้น และ ws_type ไม่เป็น NULL

4. Calculation readiness
- ตาราง lookup threshold, weight และ policy ที่เกี่ยวข้องต้องพร้อมใช้งาน
- `mst_tt_ws_formula_matrix` ต้องมี rows สำหรับทุก ws_type ที่ salesman ใช้

5. ws_type readiness
- ทุก salesman code ใน `trn_sales_target` ต้องมี row ใน `mst_org_hierarchy` ที่มี ws_type ไม่เป็น NULL
- ตรวจด้วย: `SELECT * FROM dbo.vw_tt_salesman_ws_type WHERE period_code = N'FY2026-05'`

---

## 7. Output ที่ต้องได้จาก TT

1. ผลคำนวณรายระดับ STAFF
2. ผลรวมระดับ SECT_MGR
3. ผลรวมระดับ DEPT_MGR
4. ผลรวมระดับ DIV_MGR
5. ผลรวมระดับ AD
6. For HR Variable ที่มีองค์ประกอบ incentive_div

---

## 8. จุดเสี่ยงสำคัญของ TT

1. แม้ไม่ต้อง mapping แบบ MT แต่ถ้า hierarchy ไม่ครบ จะทำให้ cascade เพี้ยนทั้งสาย
2. ถ้า threshold table ผิด จะทำให้ GOAL ผิดทุกระดับ
3. ถ้า period mismatch จะทำให้จ่ายผิดรอบ
4. ถ้า data type ของ Actual/Target ไม่สะอาด จะทำให้ achievement คลาดเคลื่อน
5. **ws_type mismatch** — ถ้า `mst_org_hierarchy` ไม่มี ws_type สำหรับ salesman คนนั้น SP จะ fallback ไปใช้ `@WsType` parameter (TOP_WS) ทำให้ WS_SF / WS_WH ได้ incentive_base ผิด (4,000 แทน 3,500)
6. **pct_salesman NULL** — ถ้าไม่ได้ UPDATE pct_salesman ใน `trn_sales_target` SP จะ fallback ไปใช้ goal_from_threshold ซึ่งอาจไม่ตรงกับชีต

---

## 9. เช็คลิสต์ QA สำหรับ TT

1. ตรวจว่า achievement คำนวณถูกต้องตามสูตร
2. ตรวจว่า shortage override ทำงานถูก
3. ตรวจว่า GOAL lookup ตรง threshold จริง
4. ตรวจว่า AVERAGEIFS ของแต่ละระดับได้ค่าตามกลุ่ม hierarchy เดียวกัน
5. ตรวจว่ามีค่า incentive_div ใน output
6. ตรวจผลรวม For HR เทียบกับ expected sample
7. **ตรวจ ws_type ต่อ salesman** — `SELECT * FROM dbo.vw_tt_salesman_ws_type WHERE period_code=N'FY2026-05'` ต้องมีครบทุกคนและไม่มี ws_type NULL
8. **ตรวจ pct_salesman** — `SELECT * FROM trn_sales_target WHERE period_id=... AND pct_salesman IS NULL` ต้องไม่มี row ที่ควรมีค่าแต่ยังเป็น NULL
9. **เทียบ incentive_staff รายคน** ด้วย `EXEC dbo.usp_check_tt_sheet_employee_reference` ทุกครั้งหลัง re-run SP

---

## 10. Mapping Matrix ครบ 26 Sheets: Sheet -> Field Key -> Table -> View -> Validation Query (TT)

ส่วนนี้ทำเป็น matrix ให้ครบทุก sheet ตามไฟล์ต้นฉบับ TT เพื่อให้ trace ได้ตั้งแต่ต้นทางจนถึงฐานข้อมูลและจุดตรวจสอบ

### 10.1 กติกาการอ่าน Matrix

1. Field Key = คีย์หลักที่ใช้ยืนยันความสอดคล้องของข้อมูล
2. Table = ตารางหลักที่เกี่ยวข้อง (staging/master/transaction/output)
3. View = มุมมองที่ใช้ตรวจเชิงธุรกิจหรือเชิงโครงสร้าง
4. Validation Query = SQL ตัวอย่างแบบสั้นสำหรับเช็คความครบถ้วน/ความสัมพันธ์

### 10.2 Full Mapping Matrix (26 Sheets)

| # | Sheet | Field Key (ตัวอย่าง) | Table หลักที่เกี่ยวข้อง | View ที่ใช้ตรวจ | Validation Query (ตัวอย่าง) |
|---|---|---|---|---|---|
| 1 | Top WS | month, salesman_code, sku | trn_incentive_detail, out_for_hr_variable | vw_mst_channel_relations | `SELECT COUNT(*) FROM trn_incentive_detail d JOIN mst_channel c ON c.channel_id=d.channel_id WHERE c.channel_code='TT';` |
| 2 | WS SF | month, sect_code | trn_incentive_detail, mst_org_hierarchy | vw_mst_org_hierarchy_management_chain | `SELECT COUNT(*) FROM mst_org_hierarchy h JOIN mst_channel c ON c.channel_id=h.channel_id WHERE c.channel_code='TT' AND h.direct_sup_code IS NOT NULL;` |
| 3 | WS WH | month, dept_code | trn_incentive_detail, mst_org_hierarchy | vw_mst_org_hierarchy_management_chain | `SELECT COUNT(*) FROM mst_org_hierarchy h JOIN mst_channel c ON c.channel_id=h.channel_id WHERE c.channel_code='TT' AND h.dept_mgr_code IS NOT NULL;` |
| 4 | Test | test_case_id, expected, actual | trn_calc_run (ใช้เป็นหลักฐานรอบรัน) | vw_mst_channel_relations | `SELECT TOP 10 calc_run_id, run_status, created_at FROM trn_calc_run ORDER BY created_at DESC;` |
| 5 | SF WH | month, div_code | trn_incentive_detail, mst_org_hierarchy | vw_mst_org_hierarchy_management_chain | `SELECT COUNT(*) FROM mst_org_hierarchy h JOIN mst_channel c ON c.channel_id=h.channel_id WHERE c.channel_code='TT' AND h.div_mgr_code IS NOT NULL;` |
| 6 | M_Month | sales_month, pay_month_var, pay_month_fix | mst_payment_cycle, mst_period | vw_mst_channel_relations | `SELECT COUNT(*) FROM mst_payment_cycle;` |
| 7 | Product | product_code, product_name | mst_product, mst_product_weight | vw_mst_channel_relations | `SELECT COUNT(*) FROM mst_product WHERE is_active=1;` |
| 8 | T_SectAbove | position_level, ws_type | mst_position_level, mst_incentive_rate, mst_job_function | vw_mst_position_incentive_rate_detail | `SELECT COUNT(*) FROM vw_mst_position_incentive_rate_detail WHERE channel_code='TT';` |
| 9 | 2) หลักการคำนวน Table | achievement_band, goal, payout_rule | mst_goal_threshold, mst_policy_rule, mst_system_parameter | vw_mst_channel_relations | `SELECT COUNT(*) FROM mst_goal_threshold;` |
| 10 | Period | period_code, sales_month | mst_period | vw_mst_org_hierarchy_period_context | `SELECT COUNT(*) FROM mst_period WHERE is_active=1;` |
| 11 | 3)Target & Cal | salesman_code, sku, target, weight | trn_sales_target, mst_product_weight | vw_mst_channel_relations | `SELECT COUNT(*) FROM trn_sales_target t JOIN mst_channel c ON c.channel_id=t.channel_id WHERE c.channel_code='TT';` |
| 12 | Actual | salesman_code, sku, actual, sales_month | trn_sales_actual, stg_bi_sales | vw_mst_channel_relations | `SELECT COUNT(*) FROM trn_sales_actual a JOIN mst_channel c ON c.channel_id=a.channel_id WHERE c.channel_code='TT';` |
| 13 | ASTBase | salesman_code, direct_sup_code, dept_mgr_code, div_mgr_code, ad_code, **ws_type**, effective_month | mst_org_hierarchy | vw_mst_org_hierarchy_detail, vw_mst_org_hierarchy_data_quality, **vw_tt_salesman_ws_type** | `SELECT * FROM dbo.vw_tt_salesman_ws_type WHERE period_code='FY2026-05' ORDER BY ws_type,salesman_code;` |
| 14 | HR Rep | emp_code, position_level, job_function, effective_from | stg_hcm_employee, mst_employee | vw_mst_employee_detail | `SELECT COUNT(*) FROM vw_mst_employee_detail WHERE channel_code='TT';` |
| 15 | 1) For HR | employee_code, incentive_staff, incentive_sect, incentive_dept, incentive_div, incentive_ad | out_for_hr_variable | vw_mst_channel_relations | `SELECT COUNT(*) FROM out_for_hr_variable v JOIN mst_channel c ON c.channel_id=v.channel_id WHERE c.channel_code='TT';` |
| 16 | 1) For HR (AD) | ad_code, incentive_ad_total | out_for_hr_variable | vw_mst_channel_relations | `SELECT COUNT(*) FROM out_for_hr_variable WHERE incentive_ad IS NOT NULL;` |
| 17 | Shortage | sku, shortage_flag, effective_month | mst_shortage_policy, trn_sales_actual | vw_mst_channel_relations | `SELECT COUNT(*) FROM mst_shortage_policy;` |
| 18 | Aji Plus | product_code=AJP, target/actual, payout | mst_gd_product, mst_gd_payout, trn_gd_incentive_detail | vw_mst_channel_relations | `SELECT COUNT(*) FROM trn_gd_incentive_detail d JOIN mst_gd_product g ON g.gd_product_id=d.gd_product_id WHERE g.product_code='AJP';` |
| 19 | Actual_Aji Plus | salesman_code, actual_aji_plus | trn_gd_incentive_detail, trn_sales_actual | vw_mst_channel_relations | `SELECT COUNT(*) FROM trn_gd_incentive_detail d JOIN mst_gd_product g ON g.gd_product_id=d.gd_product_id WHERE g.product_code='AJP';` |
| 20 | RDQ | product_code=RDC/RDQ logic, payout | mst_gd_product, mst_gd_payout, trn_gd_incentive_detail | vw_mst_channel_relations | `SELECT COUNT(*) FROM trn_gd_incentive_detail d JOIN mst_gd_product g ON g.gd_product_id=d.gd_product_id WHERE g.product_code IN ('RDC','RDQ');` |
| 21 | Actual_RDQ | salesman_code, actual_rdq | trn_gd_incentive_detail, trn_sales_actual | vw_mst_channel_relations | `SELECT COUNT(*) FROM trn_gd_incentive_detail d JOIN mst_gd_product g ON g.gd_product_id=d.gd_product_id WHERE g.product_code IN ('RDC','RDQ');` |
| 22 | RDM | product_code=RM/RDM logic, payout | mst_gd_product, mst_gd_payout, trn_gd_incentive_detail | vw_mst_channel_relations | `SELECT COUNT(*) FROM trn_gd_incentive_detail d JOIN mst_gd_product g ON g.gd_product_id=d.gd_product_id WHERE g.product_code IN ('RM','RDM');` |
| 23 | Actual_RDM | salesman_code, actual_rdm | trn_gd_incentive_detail, trn_sales_actual | vw_mst_channel_relations | `SELECT COUNT(*) FROM trn_gd_incentive_detail d JOIN mst_gd_product g ON g.gd_product_id=d.gd_product_id WHERE g.product_code IN ('RM','RDM');` |
| 24 | RDNS | product_code=RDNS, payout | mst_gd_product, mst_gd_payout, trn_gd_incentive_detail | vw_mst_channel_relations | `SELECT COUNT(*) FROM trn_gd_incentive_detail d JOIN mst_gd_product g ON g.gd_product_id=d.gd_product_id WHERE g.product_code='RDNS';` |
| 25 | Actual_RDNS | salesman_code, actual_rdns | trn_gd_incentive_detail, trn_sales_actual | vw_mst_channel_relations | `SELECT COUNT(*) FROM trn_gd_incentive_detail d JOIN mst_gd_product g ON g.gd_product_id=d.gd_product_id WHERE g.product_code='RDNS';` |
| 26 | Sales Target | month, salesman_code, sku, target | trn_sales_target | vw_mst_channel_relations | `SELECT COUNT(*) FROM trn_sales_target t JOIN mst_channel c ON c.channel_id=t.channel_id WHERE c.channel_code='TT';` |

### 10.3 Control Checks แนะนำหลังโหลดข้อมูล TT

1. Completeness Check (Actual vs Target)

```sql
SELECT
		(SELECT COUNT(*) FROM trn_sales_actual a JOIN mst_channel c ON c.channel_id=a.channel_id WHERE c.channel_code='TT') AS actual_rows,
		(SELECT COUNT(*) FROM trn_sales_target t JOIN mst_channel c ON c.channel_id=t.channel_id WHERE c.channel_code='TT') AS target_rows;
```

2. Hierarchy Gap Check

```sql
SELECT *
FROM vw_mst_org_hierarchy_data_quality
WHERE channel_code = 'TT'
	AND (is_missing_direct_sup = 1 OR is_missing_dept_mgr = 1 OR is_missing_div_mgr = 1 OR is_missing_ad = 1);
```

3. Employee Reference Check

```sql
SELECT a.salesman_code
FROM trn_sales_actual a
JOIN mst_channel c ON c.channel_id = a.channel_id
LEFT JOIN mst_employee e ON e.employee_code = a.salesman_code AND e.channel_id = a.channel_id
WHERE c.channel_code = 'TT'
	AND e.employee_id IS NULL
GROUP BY a.salesman_code;
```

4. TT Rate Readiness Check

```sql
SELECT channel_code, position_code, ws_type, rate_old, rate_new, effective_from, effective_to
FROM vw_mst_position_incentive_rate_detail
WHERE channel_code='TT'
ORDER BY hierarchy_level, effective_from DESC;
```

### 10.4 Validation Query เพิ่มเติมสำหรับ 3 ฟีเจอร์ใหม่

1. WS Type Formula Matrix Coverage (Top WS, WS SF, WS WH, SF WH)

```sql
SELECT
		m.ws_type,
		COUNT(*) AS matrix_rows,
		SUM(m.product_weight_percent) AS sum_weight_percent,
		MIN(m.incentive_base) AS min_base,
		MAX(m.incentive_base) AS max_base
FROM dbo.mst_tt_ws_formula_matrix m
JOIN dbo.mst_channel c
	ON c.channel_id = m.channel_id
WHERE c.channel_code = 'TT'
	AND m.is_active = 1
GROUP BY m.ws_type
ORDER BY m.ws_type;
```

2. Option1 Band + Payout Matrix Coverage

```sql
SELECT
		b.band_code,
		b.achievement_from,
		b.achievement_to,
		p_g1.payout_amount AS payout_g1,
		p_g2.payout_amount AS payout_g2,
		p_g3.payout_amount AS payout_g3,
		p_ot.payout_amount AS payout_ot
FROM dbo.mst_tt_option1_band b
LEFT JOIN dbo.mst_tt_option1_payout p_g1
	ON p_g1.tt_option1_band_id = b.tt_option1_band_id
 AND p_g1.g_group_code = 'G1'
 AND p_g1.is_active = 1
LEFT JOIN dbo.mst_tt_option1_payout p_g2
	ON p_g2.tt_option1_band_id = b.tt_option1_band_id
 AND p_g2.g_group_code = 'G2'
 AND p_g2.is_active = 1
LEFT JOIN dbo.mst_tt_option1_payout p_g3
	ON p_g3.tt_option1_band_id = b.tt_option1_band_id
 AND p_g3.g_group_code = 'G3'
 AND p_g3.is_active = 1
LEFT JOIN dbo.mst_tt_option1_payout p_ot
	ON p_ot.tt_option1_band_id = b.tt_option1_band_id
 AND p_ot.g_group_code = 'OT'
 AND p_ot.is_active = 1
JOIN dbo.mst_channel c
	ON c.channel_id = b.channel_id
WHERE c.channel_code = 'TT'
	AND b.is_active = 1
ORDER BY b.sequence_no;
```

3. Special KPI Integration Check (run-level)

```sql
SELECT
		p.period_code,
		COUNT(*) AS special_kpi_rows,
		SUM(d.bonus_amount) AS special_kpi_bonus_total
FROM dbo.trn_tt_special_kpi_detail d
JOIN dbo.trn_calc_run r
	ON r.calc_run_id = d.calc_run_id
JOIN dbo.mst_period p
	ON p.period_id = r.period_id
JOIN dbo.mst_channel c
	ON c.channel_id = r.channel_id
WHERE c.channel_code = 'TT'
GROUP BY p.period_code
ORDER BY p.period_code;
```

4. Cross-check ว่าโบนัส Special KPI ถูกบวกเข้า total_variable แล้ว

```sql
SELECT
		p.period_code,
		SUM(o.gd_incentive_total) AS sum_special_kpi_in_hr,
		SUM(o.total_variable) AS sum_total_variable
FROM dbo.out_for_hr_variable o
JOIN dbo.trn_calc_run r
	ON r.calc_run_id = o.calc_run_id
JOIN dbo.mst_period p
	ON p.period_id = r.period_id
JOIN dbo.mst_channel c
	ON c.channel_id = r.channel_id
WHERE c.channel_code = 'TT'
GROUP BY p.period_code
ORDER BY p.period_code;
```

5. WS Type Month-by-Month Comparison Query (ใช้ทำรายงานแยกตาม ws_type)

```sql
SELECT
		p.period_code,
		o.channel_code,
		SUM(o.incentive_staff) AS incentive_staff,
		SUM(o.incentive_sect) AS incentive_sect,
		SUM(o.incentive_dept) AS incentive_dept,
		SUM(o.incentive_div) AS incentive_div,
		SUM(o.incentive_ad) AS incentive_ad,
		SUM(o.gd_incentive_total) AS special_kpi_bonus,
		SUM(o.total_variable) AS total_variable
FROM dbo.out_for_hr_variable o
JOIN dbo.trn_calc_run r
	ON r.calc_run_id = o.calc_run_id
JOIN dbo.mst_period p
	ON p.period_id = r.period_id
WHERE o.channel_code = 'TT'
GROUP BY p.period_code, o.channel_code
ORDER BY p.period_code;
```

---

## 11. Features ที่ Implement แล้ว (v2.0)

### 11.1 pct_salesman — goal_multiplier จากชีตโดยตรง

- เพิ่มคอลัมน์ `pct_salesman DECIMAL(9,4) NULL` ใน `trn_sales_target` (DDL 27)
- UPDATE data สำหรับ TT FY2026-05 product R/Y = 1.0000 (DDL 28)
- SP (`usp_run_tt_incentive_calculation`) thread `pct_salesman` ผ่าน CTEs ทั้งหมด และใช้ `COALESCE(pct_salesman, goal_from_threshold, 0)` ในการคำนวณ
- **ผลที่ verify แล้ว**: 110001 incentive_staff = 4,290 (ตรงกับชีต)

### 11.2 per-salesman ws_type — formula matrix รายคน

- เพิ่มคอลัมน์ `ws_type NVARCHAR(50) NULL` ใน `mst_org_hierarchy` (DDL 30)
- INSERT TT org hierarchy 22 rows พร้อม ws_type + sup codes สำหรับ FY2026-05 (DDL 31)
- แก้ SP เพิ่ม `hier_ws` CTE — lookup ws_type รายคนจาก `mst_org_hierarchy` fallback ไป `@LegacyWsType` ถ้าไม่พบ
- Thread `ws_type` ผ่าน staff_join → staff_map → staff_calc
- เปลี่ยน 3 OUTER APPLY (formula matrix, product weight, staff rate) ให้ใช้ `COALESCE(sm.ws_type, @LegacyWsType)` แทน `@LegacyWsType` คงที่
- Manager rates (SECT_MGR ขึ้นไป) ยังใช้ `@LegacyWsType` เพราะ rates เหมือนกันทุก ws_type
- **ผลที่ verify แล้ว (FY2026-05)**:

| ws_type | จำนวนคน | incentive_staff range |
|---|---|---|
| TOP_WS | 7 | 3,740 – 4,340 |
| WS_SF | 4 | 3,587 – 3,960 |
| WS_WH | 3 | 3,260 – 3,657 |

---

### 11.3 Manager Cascade Fix (v3.0) — สูตร incentive_sect/dept/div/ad ที่ถูกต้อง

- **ปัญหาเดิม**: SP group by `(manager_code, product_code)` → 11 rows × SECT_MGR rate (11,000) = สูงผิด
- **แก้ไข 6 จุด** ใน `mgr_raw`, `mgr_calc`, INSERT:

| จุด | ก่อน | หลัง |
|-----|------|------|
| group by | `(manager, product)` | `manager` เท่านั้น, `product_code = N'*'` |
| เมตริก avg | `AVG(final_achievement)` | `AVG(goal_multiplier)` โดยตรง |
| floor-to-1.0 | มีใน mgr_calc | ลบออก (managers ถูก penalize ได้) |
| goal_multiplier INSERT | threshold lookup | `raw_achievement` โดยตรง |
| incentive_base | SECT_MGR rate (11,000) | STAFF rate (4,000) |
| precision | ROUND ก่อนคูณ | เก็บ `raw_achievement` full precision สำหรับคูณ |

- **ผลที่ verify แล้ว (FY2026-05 Section Managers)**:

| Section | Manager | %Direct Sup | incentive_sect (SP) | Sheet | Match |
|---------|---------|------------|---------------------|-------|-------|
| 110000 | Bangpoo | 108.42% | 4,336.97 | 4,336.97 | ✓ |
| 120000 | Nonthaburi | 102.95% | 4,118.18 | 4,118.18 | ✓ |
| 130000 | Pathum Thani | 101.48% | 4,059.39 | 4,059.39 | ✓ |
| 140000 | Pattanakan | 102.38% | 4,095.00 | 4,095.00 | ✓ |
| 150000 | Ram Indra | 106.00% | 4,240.00 | 4,181.82 | ⚠ data issue |
| 160000 | Thonburi | 97.73% | 3,909.09 | 3,909.09 | ✓ |

> หมายเหตุ 150000: ต่าง 58 บาท เพราะ 150001 ไม่มี product Q (target=0) ใน trn_sales_target → SP exclude แต่ sheet รวม Q ด้วย

---

### 11.4 Manager Rate Fix (v4.0) — แก้ rate ให้ตรงกับ T_SectAbove

- **ปัญหาเดิม**: `mst_incentive_rate.rate_new` ใน DB ผิดทั้งหมด (SECT_MGR=11,000 / DEPT_MGR=8,500 / AD=6,500)
- **ที่มา**: T_SectAbove sheet ระบุ rate ต่อ position level ชัดเจนใน cell `$B$2`–`$B$5`
- **แก้ไข**: UPDATE `mst_incentive_rate.rate_new` ให้ตรงกับ T_SectAbove + แก้ SP v6 ดึง rate ตาม `mc.position_level_code`

| position_code | rate_old (เดิม) | rate_new (ใหม่) | T_SectAbove ref |
|---|---|---|---|
| SECT_MGR | 11,000 | **4,000** | $B$4 |
| DEPT_MGR | 8,500 | **5,000** | $B$3 |
| DIV_MGR | 8,500 | **5,000** | $B$2 |
| AD | 6,500 | **6,000** | $B$5 |

- **ผลลัพธ์ที่ verify แล้ว (FY2026-05)**:

| Level | Rate | ตัวอย่าง |
|---|---|---|
| SECT_MGR (110000) | 4,000 | 1.0842 × 4,000 = **4,336.97** ✓ |
| DEPT_MGR (000003) | 5,000 | 1.0314 × 5,000 = **5,157.24** |
| DIV_MGR (000002) | 5,000 | 1.0314 × 5,000 = **5,157.24** |

- **ตรวจสอบด้วย**: `SELECT * FROM dbo.vw_tt_incentive_rate WHERE is_active=1 ORDER BY hierarchy_level, ws_type`

---

## 12. Views ที่มีใน DB

| View | วัตถุประสงค์ | DDL Script |
|---|---|---|
| `vw_mst_channel_relations` | Channel master + relations | 09 |
| `vw_mst_org_hierarchy_detail` | Hierarchy detail ครบทุก level | 10 |
| `vw_mst_org_hierarchy_management_chain` | Management chain per salesman | 11 |
| `vw_mst_org_hierarchy_data_quality` | ตรวจ gap ใน hierarchy | 11 |
| `vw_mst_org_hierarchy_period_context` | Hierarchy + period context | 11 |
| `vw_mst_employee_detail` | Employee + position detail | 12 |
| `vw_mst_position_incentive_rate_detail` | Rate ต่อ position + ws_type | 13 |
| `vw_mst_mt_mapping_detail` | MT mapping detail | 14 |
| `vw_tt_incentive_formula_definition` | TT formula definition | 20 |
| `vw_trn_sales_actual_pivot_fiscal_month` | Pivot actual รายเดือน Apr→Mar | 29 |
| `vw_tt_salesman_ws_type` | ws_type + hierarchy ต่อ salesman รายเดือน | 32 |
| `vw_tt_incentive_rate` | TT incentive rate ทุก position × ws_type พร้อม rate_effective | 34 |

---

## 13. DDL Script Index (32 Scripts)

| # | Script | วัตถุประสงค์ |
|---|---|---|
| 00 | discovery_schema_check | Schema discovery |
| 01 | poc_master_tables | Master tables DDL |
| 02 | poc_seed_data | Seed data |
| 03 | transaction_tables | Transaction tables DDL (รวม pct_salesman) |
| 04 | sample_data_full | Sample data ครบ 5 ระดับ |
| 05 | verify_tt_calc_type | Verify calc type |
| 06 | fix_and_verify_tt_calc_type | Fix + verify calc type |
| 07 | upsert_trn_sales_actual_from_stg | Load actual จาก staging |
| 08 | reconciliation_actual_sheet_vs_stg | Reconciliation audit |
| 09 | create_view_vw_mst_channel_relations | View channel relations |
| 10 | create_view_vw_mst_org_hierarchy_detail | View hierarchy detail |
| 11 | create_subviews_vw_mst_org_hierarchy | Sub-views hierarchy |
| 12 | create_view_vw_mst_employee_detail | View employee detail |
| 13 | create_view_vw_mst_position_incentive_rate_detail | View rate detail |
| 14 | create_view_vw_mst_mt_mapping_detail | View MT mapping |
| 15 | create_proc_run_tt_incentive_calculation | SP คำนวณ TT incentive (v2.0: per-salesman ws_type + pct_salesman) |
| 16 | add_incentive_div_to_out_for_hr_variable | เพิ่ม incentive_div ใน output |
| 17 | create_proc_validate_tt_26_sheets | SP validate 26 sheets |
| 18 | upsert_tt_topws_product_mapping_and_weight | Upsert product mapping + weight |
| 19 | create_tt_formula_matrix_option_band_special_kpi | Formula matrix + option band + special KPI |
| 20 | create_view_vw_tt_incentive_formula_definition | View formula definition |
| 21 | create_proc_usp_get_tt_incentive_formula_template | SP formula template |
| 22 | upsert_tt_ws_type_completeness | Upsert ws_type completeness |
| 23 | create_proc_usp_validate_tt_database_test_suite | SP test suite |
| 24 | create_proc_usp_check_tt_sheet_employee_reference | SP check vs sheet |
| 25 | update_mst_goal_threshold_sheet_aligned | Update goal threshold |
| 26 | add_use_team_achievement_to_formula_matrix | เพิ่ม use_team_achievement |
| 27 | add_pct_salesman_to_trn_sales_target | **เพิ่ม pct_salesman column** |
| 28 | update_pct_salesman_fy2026_05_tt | **UPDATE pct_salesman data TT FY2026-05** |
| 29 | create_view_vw_trn_sales_actual_pivot_fiscal_month | **View pivot actual Apr→Mar** |
| 30 | add_ws_type_to_mst_org_hierarchy | **เพิ่ม ws_type column ใน mst_org_hierarchy** |
| 31 | insert_tt_org_hierarchy_fy2026_05 | **INSERT TT hierarchy 22 rows พร้อม ws_type** |
| 32 | create_view_vw_tt_salesman_ws_type | **View ws_type ต่อ salesman รายเดือน** |
| 33 | create_proc_usp_check_tt_incentive_result | **SP ตรวจ simplified (4 result sets, ไม่มี Sheet Reference/Lineage)** |
| 34 | create_view_vw_tt_incentive_rate | **View TT incentive rate ทุก position × ws_type พร้อม rate_effective (filter TT only)** |

---

## 14. สรุปสั้นที่สุด

TT Flow คือ:

รับยอดขายแบบตรง → validate → lookup ws_type รายคน → คำนวณ staff ราย SKU (incentive_base ตาม ws_type, COALESCE pct_salesman) → cascade 5 ระดับด้วย AVG(goal_multiplier) × STAFF_rate → สร้าง For HR Variable

TT เข้าใจง่ายกว่า MT ในมุม mapping แต่ต้องระวัง:
- hierarchy ต้องครบและมี ws_type ถูกต้องต่อคน
- threshold table และ formula matrix ต้องครบทุก ws_type
- pct_salesman ต้อง UPDATE ทุกรอบก่อนรัน SP
- **`mst_incentive_rate.rate_new` ต้องตรงกับ T_SectAbove sheet** — ตรวจด้วย `SELECT * FROM dbo.vw_tt_incentive_rate` ก่อน deploy ทุกรอบ
