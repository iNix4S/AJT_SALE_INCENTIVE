# Chat Log: copilot_2026.06.15_003

วันที่: 2026-06-15  
เครื่องมือ: GitHub Copilot (Claude Sonnet 4.6)  
หัวข้อหลัก: DDL 37–39 — สร้าง mst_tt_product + ปรับ product_code ทั้งระบบ TT ให้ใช้ TT short alias

---

## 1. สิ่งที่ทำในเซสชันนี้

### 1.1 ปัญหาที่แก้ต่อจาก session ก่อน

- DDL 37 (Step 6) deploy ไม่ผ่าน — SP มี `MERGE` ที่อ้าง `incentive_total` และ `approved_by` ซึ่งไม่มีใน `out_for_hr_variable`
- แก้โดยเปลี่ยน MERGE → INSERT ให้ตรงกับ schema จริง (เหมือน DDL 15 v6)
- Deploy DDL 37 สำเร็จ — SP v7 ใช้ `mst_tt_product.tt_sheet_code` lookup แทน hardcoded CASE

### 1.2 เปลี่ยนทิศทาง — ใช้ TT short alias เป็น product_code มาตรฐาน

ผู้ใช้ต้องการให้ `mst_tt_product.product_code` ใช้ TT short alias (A/R/B/AP/Q/M/NS/P/Y/RK/T)  
แทน canonical code (AJ/RD/BD/AJP/RDC/RM/RDNS/PDC/YY/RKR/TKM)  
และ tables ที่เกี่ยวข้องกับ TT ทั้งหมดต้องใช้ short alias ด้วย

---

## 2. DDL ที่สร้างในเซสชันนี้

### DDL 37 (อัพเดต): `environment/ddl/37_create_mst_tt_product_and_refactor_tt_objects.sql`

- แก้ Step 6 (SP): เปลี่ยน MERGE → INSERT ที่ถูกต้อง
- อัพเดต SP v7: ใช้ `mst_org_hierarchy` (ไม่ใช่ `mst_tt_ws_hierarchy` ที่ไม่มีจริง)
- อัพเดต `staff_calc` ให้ JOIN จาก `staff_join` (sj) โดยตรงแทน `staff_map` (ที่ถูกลบออก)
- อัพเดต Seed: ใช้ `p.tt_sheet_code` เป็น `product_code` ใน `mst_tt_product`
- Idempotent: DROP FK `FK_mst_tt_ws_formula_matrix_tt_product` ก่อน DROP TABLE

### DDL 38 (สร้างใหม่): `environment/ddl/38_migrate_tt_product_code_and_remove_sheet_code.sql`

**วัตถุประสงค์**: Migrate product_code ใน TT tables จาก canonical → short alias + ลบ `tt_sheet_code` column ออกจาก `mst_tt_product`

| Step | รายการ | ผล |
|---|---|---|
| 1 | Migrate `trn_sales_target` (TT) | 1,831 rows → A/R/B/... |
| 2 | Migrate `trn_sales_actual` (TT) | 277 rows → A/R/B/... |
| 3 | DROP `UQ_mst_tt_product_sheet_code` + column `tt_sheet_code` | ✅ |
| 4 | Rebuild `vw_tt_formula_ws_matrix` (ลบ tt_sheet_code) | ✅ |
| 5 | SP v8: JOIN `mst_tt_product` บน `product_code` โดยตรง | ✅ |

หมายเหตุ: Step 1-2 ใช้ `sp_executesql` เพื่อหลีกเลี่ยง compile-time error (idempotent)

### DDL 39 (สร้างใหม่): `environment/ddl/39_use_tt_short_alias_as_product_code.sql`

**วัตถุประสงค์**: เปลี่ยน `mst_tt_product.product_code` → TT short alias และ migrate ทุก TT table

| Step | รายการ | ผล |
|---|---|---|
| 1 | `mst_tt_product.product_code`: AJ→A, RD→R, BD→B ... (11 rows) | ✅ |
| 2 | `trn_sales_target` (TT, non-SKU): 1,831 rows | ✅ |
| 3 | `trn_sales_actual` (TT, non-SKU): 277 rows | ✅ |
| 4 | `trn_incentive_detail` (TT runs, non-SKU, non-*): 152 rows | ✅ |
| 5 | Rebuild `vw_tt_formula_ws_matrix` | ✅ |
| 6 | SP v9: base_product_code = short alias; SKU rows → resolve ผ่าน `mst_product.tt_sheet_code` | ✅ |

---

## 3. Product Code Mapping (สรุปสำหรับ Agent ถัดไป)

| TT short alias (product_code) | Canonical code | g_group_code | mst_product_id |
|---|---|---|---|
| A | AJ | G1 | 1 |
| R | RD | G1 | 2 |
| B | BD | G1 | 3 |
| Y | YY | G3 | 4 |
| P | PDC | G3 | 5 |
| AP | AJP | G2 | 6 |
| M | RM | G2 | 7 |
| T | TKM | OT | 8 |
| Q | RDC | G2 | 9 |
| RK | RKR | OT | 10 |
| NS | RDNS | G2 | 11 |

**SKU mapping**: SKU-AJ-350 → strip → "AJ" → lookup `mst_product.tt_sheet_code` → "A" → JOIN `mst_tt_product.product_code='A'`

---

## 4. โครงสร้าง Tables ที่เกี่ยวข้อง

### mst_tt_product (ปัจจุบัน)

```
tt_product_id (PK)
product_code       ← TT short alias: A/R/B/AP/Q/M/NS/P/Y/RK/T
product_name_th
product_name_en
product_group_id   ← FK → mst_product_group
g_group_code       ← G1/G2/G3/OT (denormalized)
mst_product_id     ← FK ref → mst_product.product_id (สำหรับ legacy lookup)
is_active
created_at
updated_at
```

**หมายเหตุ**: `tt_sheet_code` column ถูกลบออกแล้ว (DDL 38 Step 3) — ไม่มีใน mst_tt_product อีกต่อไป

### mst_tt_ws_formula_matrix (เพิ่ม column)

```
... (ของเดิม)
product_id     ← legacy FK → mst_product.product_id (ยังคงอยู่)
tt_product_id  ← FK → mst_tt_product.tt_product_id (เพิ่มใน DDL 37)
```

---

## 5. สถานะ SP usp_run_tt_incentive_calculation

**Version**: v9 (DDL 39 — ล่าสุด)  
**ไฟล์**: `environment/ddl/39_use_tt_short_alias_as_product_code.sql` (Step 6)

**Logic หลัก**:
- `staff_join.base_product_code` = TT short alias เสมอ
  - non-SKU: `ts.product_code` (เป็น short alias อยู่แล้ว)
  - SKU: `LEFT(SKU-AJ-350, ...) = 'AJ'` → lookup `mst_product.tt_sheet_code` → `'A'`
- `staff_calc`: JOIN `mst_tt_product` บน `p.product_code = sj.base_product_code`
- `mst_tt_ws_formula_matrix`: JOIN บน `m.tt_product_id = p.tt_product_id`
- Legacy lookups: `mst_product_weight` / `mst_shortage_policy` → ผ่าน `p.mst_product_id`
- Manager cascade: `mst_org_hierarchy` (ไม่ใช่ `mst_tt_ws_hierarchy`)
- Rate lookup: `mst_incentive_rate` JOIN `mst_position_level` บน `position_code`

---

## 6. ผลลัพธ์การคำนวณ FY2026-05 (Verify)

| salesman_code | position | total_incentive |
|---|---|---|
| 000002 | DIV_MGR | 5,157.24 |
| 000003 | DEPT_MGR | 5,157.24 |
| 110000 | SECT_MGR | **4,336.97** ✓ |
| 110001 | STAFF | 4,290.00 |
| 110002 | STAFF | 3,960.25 |
| ... | ... | ... |

Total: 160 rows ใน trn_incentive_detail, 22 rows ใน out_for_hr_variable

---

## 7. ปัญหาที่พบและวิธีแก้

| ปัญหา | วิธีแก้ |
|---|---|
| DDL 37 SP MERGE อ้าง `incentive_total`, `approved_by` ไม่มีใน `out_for_hr_variable` | เปลี่ยน MERGE → INSERT pattern เหมือน DDL 15 |
| DDL 37 DROP TABLE ล้มเหลว — FK ยังอยู่ | DROP FK `FK_mst_tt_ws_formula_matrix_tt_product` ก่อน |
| DDL 38 Step 1-2 compile error เมื่อ column หาย | ใช้ `sp_executesql` ใน `IF EXISTS` block |
| SP ใช้ `mst_tt_ws_hierarchy` ที่ไม่มีใน DB | แก้เป็น `mst_org_hierarchy` (ตาม DDL 15 v6) |
| SP `staff_calc` FROM `staff_map sm` แต่ CTE ถูกลบ | แก้เป็น FROM `staff_join sj` |

---

## 8. ไฟล์ DDL ทั้งหมดในโปรเจกต์ (สำหรับ TT)

| DDL | ไฟล์ | สถานะ |
|---|---|---|
| 15 | `15_create_proc_run_tt_incentive_calculation.sql` | v6 (ไม่ใช่ latest แล้ว — superseded by 37-39) |
| 34 | `34_create_view_vw_tt_incentive_rate.sql` | ✅ deployed |
| 35 | `35_create_view_vw_tt_formula_incentive_matrix.sql` | ✅ deployed |
| 36 | `36_create_mst_product_group_and_migrate.sql` | ✅ deployed |
| 37 | `37_create_mst_tt_product_and_refactor_tt_objects.sql` | ✅ deployed (idempotent) |
| 38 | `38_migrate_tt_product_code_and_remove_sheet_code.sql` | ✅ deployed (idempotent) |
| 39 | `39_use_tt_short_alias_as_product_code.sql` | ✅ deployed (idempotent) |

**ลำดับ deploy ที่ถูกต้อง**: 36 → 37 → 38 → 39 (ต้องรันตามลำดับบน DB ใหม่)

---

## 9. สิ่งที่ยังค้าง / ต้องทำต่อ

- [ ] อัพเดต `final-docs/AJT_TT-Flow-Process_Summary.md` ให้สะท้อน DDL 37-39
- [ ] อัพเดต `final-docs/AJT_TT_SP_Run_And_Check_Reference.md` สำหรับ SP v9
- [ ] พิจารณาลบ `mst_product.tt_sheet_code` column (ถ้าไม่ใช้งานอื่นอีก) — ปัจจุบันยังคงไว้ใช้สำหรับ SKU resolution ใน SP
- [ ] ตรวจว่า `mst_product.gd_product_code` ยังใช้งานอยู่ไหม (DDL 36 ลบออกแล้วหรือยัง)

---

## 10. ข้อสรุปสำคัญสำหรับ Agent ถัดไป

1. **TT product_code = short alias เสมอ** (A/R/B/AP/Q/M/NS/P/Y/RK/T) — ทั้งใน mst_tt_product, trn_sales_target, trn_sales_actual, trn_incentive_detail
2. **SKU rows** (SKU-AJ-350) ยังเก็บ format เดิม — SP resolve ผ่าน `mst_product.tt_sheet_code`
3. **mst_tt_product.mst_product_id** คือ bridge ไปยัง canonical code ใน mst_product สำหรับ legacy lookups
4. **SP version ล่าสุด**: deploy จาก DDL 39 Step 6 (`CREATE OR ALTER PROCEDURE`)
5. **Connection**: `Server=localhost,1437;Database=AJT_SIS;User Id=sa;Password=P@ssw0rd`
6. **CWD**: `D:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive`
