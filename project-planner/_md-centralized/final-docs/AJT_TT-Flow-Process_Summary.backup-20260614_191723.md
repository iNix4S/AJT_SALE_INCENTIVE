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

## 10. Mapping: Sheet -> Table -> View (TT)

ส่วนนี้สรุป mapping ของฝั่ง TT ตั้งแต่ข้อมูลในไฟล์ต้นทาง (sheet) ลงตารางหลักในฐานข้อมูล และ view ที่ใช้ตรวจสอบ/รายงาน

### 10.1 ภาพรวมการแมปข้อมูล TT

| ลำดับ | Sheet (TT) | จุดประสงค์ | Table ปลายทางหลัก | View สำหรับตรวจสอบ |
|---|---|---|---|---|
| 1 | Actual | ยอดขายจริงรายเดือนราย Salesman + SKU | trn_sales_actual | vw_mst_channel_relations (เช็ค latest month/period) |
| 2 | ASTBase | โครงสร้างสายบังคับบัญชา (Sales/Section/Dept/Div/AD) | mst_org_hierarchy | vw_mst_org_hierarchy_detail, vw_mst_org_hierarchy_data_quality |
| 3 | HR Rep | ข้อมูลพนักงาน active และโครงสร้างตำแหน่ง | stg_hcm_employee -> mst_employee | vw_mst_employee_detail |
| 4 | Period | ปฏิทินรอบคำนวณ/ปิดงวด | mst_period | vw_mst_org_hierarchy_period_context |
| 5 | T_SectAbove / Table | กติกาอัตรา incentive ตามระดับ | mst_position_level, mst_incentive_rate, mst_job_function | vw_mst_position_incentive_rate_detail |

หมายเหตุ:
1. TT ไม่ใช้ mapping แบบ MT (BI SalesCode -> Salesman Code)
2. TT ใช้คีย์ตรงจาก Salesman Code + SKU เป็นแกนคำนวณ

### 10.2 Mapping รายฟิลด์ (TT Actual -> DB)

| Sheet Field (TT) | ความหมาย | Table.Column (หลัก) | หมายเหตุ |
|---|---|---|---|
| Salesman Code | รหัสพนักงานขาย | trn_sales_actual.salesman_code | ต้องสอดคล้องกับ mst_employee.employee_code |
| SKU / Product Code | รหัสสินค้า | trn_sales_actual.product_code หรือ product_id | ใช้โยงกับ mst_product |
| Month/Year | เดือนยอดขาย | trn_sales_actual.sales_month | ต้องตรง period ที่เปิดคำนวณ |
| Actual Qty/Value | ยอดขายจริง | trn_sales_actual.actual_qty / actual_amount | ใช้คำนวณ achievement |
| Channel | ช่องทางข้อมูล | trn_sales_actual.channel_id | TT ต้อง map เป็น channel_code = TT |

### 10.3 Mapping รายฟิลด์ (TT ASTBase/HR -> DB)

| Sheet Field | Table.Column | ใช้ในขั้นตอน | ตรวจด้วย View |
|---|---|---|---|
| Salesman Code | mst_org_hierarchy.salesman_code | ระดับ STAFF | vw_mst_org_hierarchy_detail |
| DirectSupCode | mst_org_hierarchy.direct_sup_code | ระดับ SECT_MGR | vw_mst_org_hierarchy_management_chain |
| DeptMgrCode | mst_org_hierarchy.dept_mgr_code | ระดับ DEPT_MGR | vw_mst_org_hierarchy_management_chain |
| DivMgrCode | mst_org_hierarchy.div_mgr_code | ระดับ DIV_MGR | vw_mst_org_hierarchy_management_chain |
| AD Code | mst_org_hierarchy.ad_code | ระดับ AD | vw_mst_org_hierarchy_management_chain |
| EmpCode | mst_employee.employee_code | การระบุตัวตนพนักงาน | vw_mst_employee_detail |
| Position Level | mst_employee.position_level_id | ผูก policy อัตราจ่าย | vw_mst_employee_detail |

### 10.4 Mapping เชิงคำนวณ (TT Formula Inputs -> Tables)

| Logic | ข้อมูลนำเข้า | ตารางอ้างอิง |
|---|---|---|
| achievement = ROUND(Actual/Target, 4) | Actual + Target | trn_sales_actual, trn_sales_target |
| shortage override | shortage flag/เงื่อนไข | trn_sales_actual, policy table |
| GOAL lookup | achievement threshold | master policy/goal tables |
| incentive = base x GOAL x weight | base, goal, weight | incentive rule tables |
| cascade ระดับบน (AVERAGEIFS) | incentive ระดับล่าง + hierarchy | trn_incentive_detail + mst_org_hierarchy |

### 10.5 View ที่ควรใช้ในการตรวจความครบถ้วน TT

1. vw_mst_employee_detail
- ตรวจว่าพนักงาน TT active ครบและมี position/job function พร้อม

2. vw_mst_org_hierarchy_detail
- ตรวจ chain ของ TT ว่าครบตั้งแต่ STAFF ถึง AD

3. vw_mst_org_hierarchy_data_quality
- ตรวจช่องโหว่ hierarchy เช่น missing manager code

4. vw_mst_channel_relations
- ตรวจภาพรวม relation count ของ channel TT และ latest period

5. vw_mst_position_incentive_rate_detail
- ตรวจอัตรา incentive ตามระดับตำแหน่งที่ใช้ใน policy

### 10.6 Validation Query ตัวอย่าง (TT)

ตัวอย่าง 1: เช็คว่าพนักงาน TT มีใน employee master ครบ

```sql
SELECT sa.salesman_code
FROM trn_sales_actual sa
LEFT JOIN mst_employee e
	ON e.employee_code = sa.salesman_code
 AND e.channel_id = sa.channel_id
WHERE sa.channel_id = (SELECT channel_id FROM mst_channel WHERE channel_code = 'TT')
	AND e.employee_id IS NULL
GROUP BY sa.salesman_code;
```

ตัวอย่าง 2: เช็ค hierarchy gap ของ TT

```sql
SELECT *
FROM vw_mst_org_hierarchy_data_quality
WHERE channel_code = 'TT'
	AND (is_missing_direct_sup = 1 OR is_missing_dept_mgr = 1 OR is_missing_div_mgr = 1 OR is_missing_ad = 1);
```

ตัวอย่าง 3: เช็ค rate ตามระดับตำแหน่ง

```sql
SELECT channel_code, position_code, ws_type, rate_old, rate_new, effective_from, effective_to
FROM vw_mst_position_incentive_rate_detail
WHERE channel_code = 'TT'
ORDER BY hierarchy_level, effective_from DESC;
```

---

## 11. สรุปสั้นที่สุด

TT Flow คือ:

รับยอดขายแบบตรง -> validate -> คำนวณ staff ราย SKU -> cascade 5 ระดับด้วย AVERAGEIFS -> สร้าง For HR Variable

TT เข้าใจง่ายกว่า MT ในมุม mapping แต่ต้องระวังความถูกต้องของ hierarchy และ threshold table เป็นพิเศษ
