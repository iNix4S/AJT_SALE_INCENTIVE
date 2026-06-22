# AJT Validation Gate (Detailed)

วันที่: 2026-06-14  
เวอร์ชัน: v1.0  
ขอบเขต: อธิบายขั้นตอน Validation Gate ก่อนคำนวณ Incentive (MT/TT)

---

## สรุปสั้นที่สุด

Validation Gate คือด่านตรวจคุณภาพข้อมูลก่อนเข้าขั้นตอนคำนวณจริง

ระบบต้องผ่าน 4 เงื่อนไขหลัก:

1. Period alignment
2. Required fields completeness
3. Hierarchy consistency
4. Mapping completeness (สำคัญมากใน MT)

ถ้าไม่ผ่าน ระบบต้อง block processing และให้แก้ต้นทางก่อน retry

---

## 1) วัตถุประสงค์ของ Validation Gate

1. ป้องกันการคำนวณผิดตั้งแต่ต้นทาง
2. ลดความเสี่ยงจ่ายผิดคน/ผิดจำนวน
3. ทำให้ผลลัพธ์ตรวจสอบย้อนกลับได้ (audit-ready)
4. แยกปัญหาเป็นหมวดชัดเจนเพื่อแก้ไขเร็ว

---

## 2) Validation Gate อยู่ตรงไหนใน System Flow

ลำดับโดยย่อ:

1. รับข้อมูล BI/DWC Sales และ HCM Employee
2. เข้า Validation Gate
3. ถ้าผ่าน: ไปคำนวณ MT หรือ TT
4. ถ้าไม่ผ่าน: หยุด, แจ้ง error, กลับไปแก้ต้นทาง

ดังนั้น Validation Gate เป็นเงื่อนไขบังคับก่อนการคำนวณทุกครั้ง

---

## 3) รายการตรวจ 4 กลุ่มหลัก

## 3.1 Period Alignment

ความหมาย:
- ข้อมูลจากทุกแหล่งต้องอ้างอิง period เดียวกันตามรอบที่กำลังประมวลผล

สิ่งที่ตรวจ:
1. เดือนของข้อมูล Sales ตรงกับ period ที่เลือก
2. เดือนของข้อมูล HR ตรงกับ period ที่เลือก
3. เดือนของ hierarchy/mapping ที่ใช้คำนวณตรงกัน

ถ้าไม่ผ่าน:
- `Period mismatch`

ผลกระทบ:
- ยอดขายและโครงสร้างคนละเดือน ทำให้คำนวณ incentive ผิดทันที

---

## 3.2 Required Fields Completeness

ความหมาย:
- ฟิลด์จำเป็นต้องไม่ว่างและอยู่ในรูปแบบที่ใช้งานได้

ตัวอย่างฟิลด์จำเป็น:
1. Sales: channel_code, salesman_code (หรือ BI SalesCode ที่ map ได้), product_code/product_group, amount/qty, period
2. HR: employee_code, channel, job_function/position, employment status
3. Hierarchy: effective_month, salesman_code, manager chain ที่จำเป็นต่อระดับคำนวณ

ถ้าไม่ผ่าน:
- `Missing required field`

ผลกระทบ:
- ไม่สามารถจัดกลุ่ม/คำนวณ/ผูกคนได้ครบ

---

## 3.3 Hierarchy Consistency

ความหมาย:
- โครงสร้างสายบังคับบัญชาต้องเชื่อมกันถูกต้องตาม channel และเดือน

สิ่งที่ตรวจ:
1. มี row ของ salesman ครบตามเดือน
2. manager chain ไม่ขาดตอนในระดับที่ policy กำหนด
3. ไม่มี key ซ้ำที่ผิด business key ต่อเดือน (เช่น channel + month + salesman)
4. manager code สามารถอ้างอิงไป master พนักงานได้

ถ้าไม่ผ่าน:
- `Hierarchy gap`

ผลกระทบ:
- cascade คำนวณระดับบนผิด หรือหายทั้งสาย

---

## 3.4 Mapping Completeness (MT-Critical)

ความหมาย:
- MT ต้อง map จาก BI SalesCode + Product Group ไป Salesman Code ได้ครบ

สิ่งที่ตรวจ:
1. แถว MT ที่เข้ามาต้อง resolve mapping ได้
2. mapping ต้องสอดคล้องเดือนที่ประมวลผล
3. แถวที่ resolve ไม่ได้ต้องถูกแยกรายงานชัดเจน

ถ้าไม่ผ่าน:
- `MT mapping incomplete`

ผลกระทบ:
- ยอดขาย MT ไม่สามารถเข้าคำนวณ trn_sales_actual ได้ครบ

---

## 4) กติกา Pass/Fail

Pass เมื่อ:
1. ผ่านครบทั้ง 4 กลุ่ม
2. ไม่มี unresolved critical error

Fail เมื่อ:
1. มี fail อย่างน้อย 1 กลุ่ม
2. หรือมี critical gap แม้เพียงรายการเดียวในจุดที่ block policy

Action เมื่อ Fail:
1. Block processing
2. แสดงรายการ error ที่แก้ได้ (row-level และ summary)
3. ให้แก้ต้นทางแล้วรันใหม่

---

## 5) Error Taxonomy ที่ควรใช้ร่วมกัน

1. `PERIOD_MISMATCH`
2. `MISSING_REQUIRED_FIELD`
3. `HIERARCHY_GAP`
4. `MAPPING_INCOMPLETE_MT`
5. `MASTER_NOT_FOUND`
6. `DUPLICATE_BUSINESS_KEY`

แนวทางแสดงผล:
- Summary: นับจำนวนต่อหมวด error
- Detail: ระบุ key ที่ผิด, source row, ค่าที่พบ, ค่าที่คาดหวัง

---

## 6) ตัวอย่างสิ่งที่ระบบควรรายงานในรอบประมวลผล

1. Validation run metadata
- run_id, period, started_at, completed_at, status

2. Summary ต่อกลุ่มตรวจ
- total_rows, passed_rows, failed_rows, failure_rate

3. Detail ต่อรายการผิด
- source_system, source_file, raw_row_no, business_key, error_code, error_message

4. คำแนะนำการแก้
- owner_team, fix_hint, retry_condition

---

## 7) Mapping กับข้อมูล/ตารางที่ใช้งานจริงในโครงการนี้

เวอร์ชันเข้มขึ้นสำหรับ Validation Gate (ใช้ก่อนคำนวณจริง)

| แหล่งข้อมูลต้นทาง | Sheet ที่เกี่ยวข้อง | MT Pull Data | TT Pull Data | Table ที่ตรวจ |
|---|---|---|---|---|
| BI Sales / DWC Sales | Actual | ดึงยอดขายระดับ BI SalesCode + Product Group | ดึงยอดขายระดับ Salesman Code + SKU | stg_bi_sales, trn_sales_actual |
| HCM Employee | HR Rep | ใช้ยืนยันพนักงาน active, position, job function, channel | ใช้ยืนยันพนักงาน active, position, job function, channel | stg_hcm_employee, mst_employee |
| ASTBase / Hierarchy | ASTBase | ใช้โครงสร้างสายบังคับบัญชา Staff -> Sect -> Dept -> AD | ใช้โครงสร้างสายบังคับบัญชา Staff -> Sect -> Dept -> Div -> AD | mst_org_hierarchy, vw_mst_org_hierarchy_detail |
| Mapping Master (เพิ่ม) | Mapping / Actual (MT) | ต้อง resolve BI SalesCode + Product Group ไป Salesman ให้ครบ | ใช้เฉพาะกรณี normalize code ภายใน (ถ้ามี policy) | mst_salesman_mapping, mst_product_mapping |
| Period Master (เพิ่ม) | Period | ต้องตรงเดือนรันของ Sales, HR, Hierarchy และ Mapping | ต้องตรงเดือนรันของ Sales, HR, Hierarchy | mst_period |

หมายเหตุใช้งาน:
1. แถว Mapping Master และ Period Master เป็นเงื่อนไขบังคับใน Validation Gate แบบเข้ม
2. หาก Mapping Master หรือ Period Master ไม่ผ่าน ให้ถือว่า Fail ทันทีและ block processing

---

## 7.1 อธิบายให้เข้าใจง่ายแบบใช้งานจริง

Validation Gate แบบเข้มให้คิดเป็น 3 คำถามก่อนคำนวณ:

1. ข้อมูลตรงเดือนเดียวกันไหม (Period)
2. ข้อมูลที่ต้องใช้คำนวณครบไหม (Completeness)
3. ความสัมพันธ์กันถูกไหม (Hierarchy + Mapping)

ถ้าตอบว่า "ไม่" เพียงข้อเดียว ให้หยุดคำนวณทันที

ตัวอย่างการตีความแบบปฏิบัติ:

1. Period ไม่ตรง
- Sales เป็นเดือน 2026-05 แต่ Hierarchy เป็น 2026-04
- ผลลัพธ์ที่คำนวณจะผิดเดือน ต้อง block

2. HR ไม่ครบ
- มี employee_code ใน HR Rep แต่ยังไม่อยู่ใน `mst_employee`
- ระบบผูกคนรับเงินไม่ได้ ต้อง block

3. MT Mapping ไม่ครบ
- BI SalesCode + Product Group บางรายการ resolve ไป Salesman ไม่ได้
- ยอดส่วนนั้นเข้าคำนวณไม่ได้ ต้อง block

4. Hierarchy ขาดตอน
- มี salesman แต่ไม่มี chain ไป manager ตามระดับที่ policy กำหนด
- cascade ระดับบนจะผิด ต้อง block

---

## 7.2 ตัวอย่างข้อมูลจริงจาก View บน Database (DEV)

หมายเหตุ: ตัวอย่างด้านล่างเป็น snapshot จาก DEV ในวันที่จัดทำเอกสาร

### A) ดูภาพรวม Channel และความพร้อมของข้อมูล

View: `vw_mst_channel_relations`

ตัวอย่างผล:

| channel_code | calc_type | org_hierarchy_count | salesman_mapping_count |
|---|---|---:|---:|
| MT | CASCADE_4_LEVEL | 23 | 2053 |
| TT | SINGLE_SHEET_5_LEVEL_AVG | 20 | 0 |

การใช้งานใน Validation Gate:
1. เช็กว่าช่องทางที่กำลังรันมีข้อมูล master ที่ต้องใช้จริง
2. เช็กแนวโน้มว่าจำนวนข้อมูลผิดปกติหรือไม่ (น้อย/มากผิดเดือน)

### B) ดูโครงสร้าง hierarchy รายแถว (ใช้เช็ก Hierarchy consistency)

View: `vw_mst_org_hierarchy_detail`

ตัวอย่างผล:

| hierarchy_id | channel_code | period_code | salesman_code | direct_sup_code |
|---:|---|---|---|---|
| 1040 | TT | FY2026-05 | 160002 | 000021 |
| 1039 | TT | FY2026-05 | 160001 | 000021 |
| 1038 | TT | FY2026-05 | 160000 | 000003 |

การใช้งานใน Validation Gate:
1. เช็กว่ารหัส salesman มีสายบังคับบัญชาครบ
2. เช็กว่า period_code ตรงกับรอบที่กำลังรัน

### C) ดูความพร้อม master พนักงาน (ใช้เช็ก Required fields + Master reference)

View: `vw_mst_employee_detail`

ตัวอย่างผล:

| employee_code | channel_code | job_function_code | position_code | is_currently_effective |
|---|---|---|---|---|
| SP001 | MT | SALESMAN | STAFF | True |
| SP002 | MT | SALESMAN | STAFF | True |
| TT001 | TT | SALESMAN | STAFF | True |

การใช้งานใน Validation Gate:
1. เช็กว่า employee_code มีอยู่จริงและใช้งานได้
2. เช็กความสอดคล้องของ job function/position ก่อนคำนวณ

### D) ดู data quality ของ hierarchy แบบ aggregate

View: `vw_mst_org_hierarchy_data_quality`

ตัวอย่างผล (aggregate):

| channel_code | effective_month | missing_salesman_master | total_rows |
|---|---|---:|---:|
| MT | 2025-12-01 | 19 | 19 |
| TT | 2026-05-01 | 20 | 20 |

การใช้งานใน Validation Gate:
1. ถ้า missing_master > 0 ให้ถือว่า fail ในมุม hierarchy/master reference
2. ใช้เป็นหลักฐานประกอบ summary report ก่อนอนุมัติคำนวณ

---

## 8) Checklist ก่อนกดคำนวณจริง (Operational)

1. Period
- [ ] period ที่จะรันอยู่สถานะเปิดและทุก input ตรงเดือน

2. HR
- [ ] `mst_employee` ครบตาม HR Rep ของเดือนนั้น

3. Hierarchy
- [ ] `mst_org_hierarchy` ครบตาม ASTBase ของเดือนนั้น

4. MT Mapping
- [ ] แถว MT resolve mapping ได้ครบตาม policy strict

5. Reconciliation
- [ ] รายงาน summary/detail อยู่ในสถานะ PASS สำหรับเดือนที่อยู่ใน scope

---

## 9) สรุปเชิงปฏิบัติ

Validation Gate ไม่ใช่แค่การเช็คข้อมูลครบหรือไม่ แต่เป็น control point ที่ปกป้องความถูกต้องของการจ่าย incentive ทั้งระบบ

หลักการใช้งานที่ควรยึด:
1. Fail fast
2. Explain clearly
3. Retry safely

เมื่อออกแบบ Validation Gate ตามเอกสารนี้ จะช่วยให้ MT/TT คำนวณได้เสถียร ตรวจสอบได้ และลด defect ตอนส่ง HR อย่างมีนัยสำคัญ
