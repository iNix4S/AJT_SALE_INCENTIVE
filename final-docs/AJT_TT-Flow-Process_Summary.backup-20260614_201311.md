# AJT TT Flow Process Summary

วันที่: 2026-06-14  
เวอร์ชัน: v1.0  
ขอบเขต: เอกสารอธิบาย TT Flow (Traditional Trade) สำหรับทีม Business, SA, Dev และ QA

---

## 1. วัตถุประสงค์

เอกสารนี้สรุปการไหลของ TT แบบครบลำดับ ตั้งแต่รับข้อมูล ตรวจ validation คำนวณ Staff และ Cascade ขึ้น 5 ระดับ ไปจนถึงการสร้างผลลัพธ์ For HR เพื่อให้ทุกทีมใช้ความเข้าใจเดียวกัน

---

## 2. หลักการของ TT

1. TT ใช้ข้อมูลยอดขายตรงระดับ Salesman Code + SKU
2. TT ไม่ต้องทำ mapping แบบ MT
3. โครงสร้าง worksheet ฝั่งต้นทางเป็น single-sheet แต่การคำนวณในระบบมี hierarchy ครบ 5 ระดับ
4. Logic ระดับบนใช้ AVERAGEIFS เพื่อดึงผลจากระดับล่างตามเงื่อนไข

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
4. incentive = base x GOAL x weight
5. การส่งผลขึ้นระดับบนใช้ AVERAGEIFS จากข้อมูลระดับล่าง

---

## 5. โครงสร้าง Hierarchy ของ TT

1. STAFF
2. SECT_MGR
3. DEPT_MGR
4. DIV_MGR
5. AD

หมายเหตุ: TT ต่างจาก MT ที่มี 4 ระดับ เพราะ TT ต้องรองรับ Division layer และ output ต้องมี incentive_div

---

## 6. Validation Gate ที่ต้องผ่านก่อนคำนวณ

1. Period alignment
- เดือนข้อมูลขายต้องตรงกับ period ที่ระบบเปิดคำนวณ

2. Required fields completeness
- ต้องมี Salesman Code, SKU, Actual, Target และ key ฟิลด์ที่จำเป็น

3. Hierarchy consistency
- โครงสร้างสายบังคับบัญชาต้องต่อเนื่องครบตามระดับ

4. Calculation readiness
- ตาราง lookup threshold, weight และ policy ที่เกี่ยวข้องต้องพร้อมใช้งาน

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

---

## 9. เช็คลิสต์ QA สำหรับ TT

1. ตรวจว่า achievement คำนวณถูกต้องตามสูตร
2. ตรวจว่า shortage override ทำงานถูก
3. ตรวจว่า GOAL lookup ตรง threshold จริง
4. ตรวจว่า AVERAGEIFS ของแต่ละระดับได้ค่าตามกลุ่ม hierarchy เดียวกัน
5. ตรวจว่ามีค่า incentive_div ใน output
6. ตรวจผลรวม For HR เทียบกับ expected sample

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
| 13 | ASTBase | salesman_code, direct_sup_code, dept_mgr_code, div_mgr_code, ad_code, effective_month | mst_org_hierarchy | vw_mst_org_hierarchy_detail, vw_mst_org_hierarchy_data_quality | `SELECT COUNT(*) FROM vw_mst_org_hierarchy_data_quality WHERE channel_code='TT';` |
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

---

## 11. สรุปสั้นที่สุด

TT Flow คือ:

รับยอดขายแบบตรง -> validate -> คำนวณ staff ราย SKU -> cascade 5 ระดับด้วย AVERAGEIFS -> สร้าง For HR Variable

TT เข้าใจง่ายกว่า MT ในมุม mapping แต่ต้องระวังความถูกต้องของ hierarchy และ threshold table เป็นพิเศษ
