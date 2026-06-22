# AJT Input Source to Sheet to DB Mapping (MT/TT)

วันที่: 2026-06-14  
เวอร์ชัน: v1.0  
ขอบเขต: สรุป mapping จากแหล่งข้อมูลต้นทาง -> Sheet -> Database (MT/TT)

---

## สรุปสั้นที่สุด

1. BI Sales / DWC Sales ลง sheet Actual
2. ASTBase ลง sheet ASTBase
3. HCM Employee ลง sheet HR Rep
4. จากนั้นระบบจะไหลเข้า table staging ก่อน แล้วค่อยเข้า master / transaction / output ตาม MT หรือ TT

---

## 1) Mapping ตามแหล่งข้อมูล

| แหล่งข้อมูลต้นทาง | Sheet ที่เกี่ยวข้อง | MT ใช้อย่างไร | TT ใช้อย่างไร | Table หลักใน AJT_SIS |
|---|---|---|---|---|
| BI Sales / DWC Sales | Actual | รับยอดขายระดับ BI SalesCode + Product Group | รับยอดขายระดับ Salesman Code + SKU | stg_bi_sales, trn_sales_actual |
| ASTBase / Hierarchy | ASTBase | ใช้ผูกสายบังคับบัญชา Staff -> Sect -> Dept -> AD | ใช้ผูกสายบังคับบัญชา Staff -> Sect -> Dept -> Div -> AD | mst_org_hierarchy |
| HCM Employee | HR Rep | ใช้ยืนยันพนักงาน active, position, job function, channel | ใช้ยืนยันพนักงาน active, position, job function, channel | stg_hcm_employee, mst_employee |

---

## 2) มุมมอง MT

MT ใช้ 3 ชุดข้อมูลนี้ร่วมกันแบบนี้

| ข้อมูล | Sheet ที่รับเข้า | Sheet ที่เอาไปใช้ต่อ | Table ที่เกี่ยวข้อง | บทบาท |
|---|---|---|---|---|
| BI Sales / DWC Sales | Actual | Mapping, Target & Cal_Staff, Target & Cal_Sect, Target & Cal_Dept, Target & Cal_AD, For HR | stg_bi_sales -> trn_sales_actual | รับยอดขายจริง แล้ว map จาก BI SalesCode ไปเป็น Salesman ก่อนคำนวณ |
| ASTBase | ASTBase | Target & Cal ทุกระดับ, For HR | mst_org_hierarchy | กำหนดโครงสร้าง cascade ของ MT แบบ 4 ระดับ |
| HCM Employee | HR Rep | For HR, For HR (FIX) | stg_hcm_employee -> mst_employee | ยืนยันตัวตนพนักงาน, channel, job function, position เพื่อใช้รวมผลและจ่าย |

### Flow MT แบบ end-to-end

1. BI/DWC ส่งยอดขายเข้า Actual
2. ระบบเก็บดิบใน stg_bi_sales
3. MT ต้องผ่าน Mapping ก่อน โดยอาศัย mst_salesman_mapping และบางกรณี mst_product_mapping
4. เมื่อ validate แล้ว ย้ายเป็นยอดพร้อมคำนวณใน trn_sales_actual
5. ใช้ ASTBase จาก mst_org_hierarchy เพื่อ cascade ขึ้น Sect, Dept, AD
6. ใช้ HR Rep จาก stg_hcm_employee และ mst_employee เพื่อระบุตัว employee ที่จะรับเงิน
7. เก็บผลคำนวณใน trn_incentive_detail
8. สรุปส่ง HR ที่ out_for_hr_variable และ out_for_hr_fixed

### Table สำคัญเฉพาะ MT เพิ่มเติม

| ประเภท | Table |
|---|---|
| Mapping สินค้า / รหัสขาย | mst_product_mapping, mst_salesman_mapping |
| คำนวณผล | trn_incentive_detail |
| ส่งออก HR | out_for_hr_variable, out_for_hr_fixed |

---

## 3) มุมมอง TT

TT ใช้ 3 ชุดข้อมูลเดียวกัน แต่ logic ต่างจาก MT

| ข้อมูล | Sheet ที่รับเข้า | Sheet ที่เอาไปใช้ต่อ | Table ที่เกี่ยวข้อง | บทบาท |
|---|---|---|---|---|
| BI Sales / DWC Sales | Actual | Target & Cal, For HR | stg_bi_sales -> trn_sales_actual | รับยอดขายตรงระดับ Salesman Code + SKU |
| ASTBase | ASTBase | Target & Cal, For HR | mst_org_hierarchy | กำหนด hierarchy 5 ระดับของ TT |
| HCM Employee | HR Rep | For HR, For HR (FIX) | stg_hcm_employee -> mst_employee | ยืนยันพนักงาน active และใช้สร้าง output ส่ง HR |

### Flow TT แบบ end-to-end

1. BI/DWC ส่งยอดขายเข้า Actual
2. ระบบเก็บดิบใน stg_bi_sales
3. TT โดยหลักไม่ต้อง map แบบ MT เพราะใช้ Salesman Code ตรง
4. เมื่อ validate แล้ว ย้ายเป็นยอดพร้อมคำนวณใน trn_sales_actual
5. ใช้ ASTBase จาก mst_org_hierarchy เพื่อคำนวณ hierarchy 5 ระดับ Staff -> Sect -> Dept -> Div -> AD
6. ใช้ HR Rep จาก stg_hcm_employee และ mst_employee เพื่อผูก employee ที่จะรับเงิน
7. เก็บผลคำนวณใน trn_incentive_detail
8. สรุปส่ง HR ที่ out_for_hr_variable และ out_for_hr_fixed โดย TT มี incentive_div เพิ่มเข้ามา

### Table สำคัญเฉพาะ TT เพิ่มเติม

| ประเภท | Table |
|---|---|
| Normalize code ภายใน ถ้ามี | mst_salesman_mapping |
| คำนวณผล | trn_incentive_detail |
| ส่งออก HR | out_for_hr_variable (มี incentive_div), out_for_hr_fixed |

---

## 4) เปรียบเทียบ MT กับ TT เฉพาะ 3 sheet นี้

| Sheet | MT | TT |
|---|---|---|
| Actual | รับ BI SalesCode + Product Group | รับ Salesman Code + SKU |
| ASTBase | ใช้ cascade 4 ระดับ Staff -> Sect -> Dept -> AD | ใช้ cascade 5 ระดับ Staff -> Sect -> Dept -> Div -> AD |
| HR Rep | ใช้ยืนยันพนักงานสำหรับ Variable และ Fixed | ใช้ยืนยันพนักงานสำหรับ Variable และ Fixed |

---

## 5) ถ้าถามว่า sheet ไหนผูกกับ table ไหน แบบตรงที่สุด

| Sheet | AJT_SIS Table |
|---|---|
| Actual | stg_bi_sales, trn_sales_actual |
| ASTBase | mst_org_hierarchy |
| HR Rep | stg_hcm_employee, mst_employee |

---

## 6) ถ้าถามว่า หลังจาก 3 sheet นี้แล้ว ระบบไปไหนต่อ

| ช่องทาง | คำนวณต่อที่ | เก็บผลที่ | ส่งออกที่ |
|---|---|---|---|
| MT | trn_incentive_detail | out_for_hr_variable, out_for_hr_fixed | out_export_batch / SSRS |
| TT | trn_incentive_detail | out_for_hr_variable, out_for_hr_fixed | out_export_batch / SSRS |

---

## 7) จุดต่างสำคัญที่ต้องจำ

1. MT ต้องมี Mapping ระหว่าง BI SalesCode กับ Salesman
2. TT ไม่ต้อง map แบบ MT แต่ยังอาจมีการ normalize code ภายใน
3. ASTBase สำคัญกับทั้งสองช่องทาง เพราะเป็นตัวกำหนดสายบังคับบัญชา
4. HR Rep สำคัญกับทั้งสองช่องทาง เพราะเป็นตัวกำหนดว่าใครคือ employee ตัวจริงที่จะรับ payment
5. TT output ต้องรองรับ incentive_div เพิ่มจาก MT

---

## Next Options

1. ทำตารางละเอียดระดับ column ว่าใน Actual, ASTBase, HR Rep แต่ละคอลัมน์ไปลง field ไหนใน database
2. แตกฉบับสำหรับเอกสารส่งงานเป็น 2 หน้าแยก MT และ TT ให้ review ง่ายขึ้น
