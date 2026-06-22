# Product Code Mapping (MT ↔ TT ↔ Product Master)

> เวอร์ชัน: Draft v0.1 — 2026-06-12
> ที่มา: `Top WS` (MT/TT), `2) หลักการคำนวน Table`, `Mapping` (MT), `Actual` (MT), `Product` master
> วัตถุประสงค์: ปิดคำถาม ❓ "รหัส MT 15 ตัว สัมพันธ์กับสินค้า 11 ตัวอย่างไร"

## ข้อสรุปหลัก
- **`Product` master เหมือนกันทั้ง MT และ TT = 11 สินค้า**
- **`Top WS` ของ MT และ TT ใช้ชื่อสินค้า 11 ตัวเดียวกัน** จัดกลุ่ม G1/G2/G3/Others + น้ำหนักเหมือนกัน (ยืนยัน cross-check แล้ว ✅)
- ความต่างอยู่ที่ **รหัสที่ใช้ในชั้นปฏิบัติการ (Target & Cal / Actual / Mapping)**:
  - **TT** ใช้รหัสสั้น 11 ตัว = **1:1 กับสินค้า** (ระดับสินค้า/SKU)
  - **MT** ใช้รหัส **"Product Group" 15 ตัว** ที่ดึงจาก BI โดย 11 ตัว map 1:1 กับสินค้า และมีอีก **4 ตัวที่เป็นสินค้าย่อย/variant** นอกเหนือ 11 master

## การจัดกลุ่ม Mapping ตาม Sheet (ให้สอดคล้องกับ 4.System Analyst and Design)

| Sheet | สิ่งที่ต้อง map | ตารางฐานข้อมูลที่รองรับ | หมายเหตุการใช้งาน |
|---|---|---|---|
| Product | Product master code/name | `mst_product` | master กลางที่ใช้ร่วม MT/TT |
| Top WS | กลุ่มสินค้า + weight | `mst_product_weight` | ใช้กำหนดน้ำหนักคำนวณ incentive |
| T_SectAbove / Table | Rate ตามระดับ/บทบาท | `mst_incentive_rate`, `mst_position_level`, `mst_job_function` | รองรับ policy ที่กระทบ mapping อัตราจ่าย |
| Mapping (MT) | BI SalesCode/Product Group -> Salesman/Internal Product | `mst_product_mapping`, `mst_salesman_mapping` | จุดหลักของ mapping ฝั่ง MT |
| Actual (MT/TT) | รหัสสินค้า/กลุ่มจากข้อมูลยอดขายจริง | `stg_bi_sales`, `trn_sales_actual` | ใช้ตรวจว่ารหัสที่เข้ามา map ได้จริง |
| Target & Cal (ทุกระดับ) | รหัสที่นำไปคำนวณเป้าและผลงาน | `trn_sales_target`, `trn_incentive_detail` | ค่าที่ map ผิดจะกระทบผลคำนวณทุกระดับ |
| HR Rep / ASTBase | map คนกับโครงสร้างองค์กร | `stg_hcm_employee`, `mst_employee`, `mst_org_hierarchy` | รองรับการรวมผลตามสายบังคับบัญชา |
| For HR | map ผลลัพธ์เป็นข้อมูลจ่ายจริง | `out_for_hr_variable`, `out_for_hr_fixed` | ปลายทางที่รับผลจาก mapping ทั้งสาย |

> หมายเหตุคำสะกด: ในคำขอใช้คำว่า "mappong" ซึ่งตีความเป็น "mapping"

## ตาราง mapping ที่ยืนยันแล้ว (11 ตัว 1:1) ✅
cross-check จาก 3 แหล่ง: ชื่อใน Top WS (MT) ↔ รหัส MT ↔ รหัส TT

| กลุ่ม (Top WS) | สินค้า (Product master) | รหัส MT | รหัส TT | น้ำหนัก (Top WS) |
|----------------|--------------------------|---------|---------|------------------|
| **G1 (CORE)** | AJINOMOTO | `AJ` | `A` | 0.05 |
| | ROSDEE | `RD` | `R` | 0.10 |
| | BIRDY | `BD` | `B` | 0.20 |
| **G2 (GD)** | AJI-PLUS | `AJP` | `AP` | 0.05 |
| | ROSDEE CUBE | `RDC` | `Q` | 0.10 |
| | ROSDEE MENU | `RM` | `M` | 0.05 |
| | ROSDEE NOODLE | `ND` | `NS` | 0.10 |
| **G3 (BB)** | YUMYUM | `YY` | `Y` | 0.15 |
| | POWDER COFFEE | `PDC` | `P` | 0.10 |
| **Others** | Takumi-Aji | `TKM` | `T` | 0.05 |
| | ROSDEE MENU KKR | `RKR` | `RK` | 0.05 |
| | **รวม** | | | **1.00** ✅ |

> หมายเหตุ: TT `Q` = ROSDEE CUBE และ TT `NS` / MT `ND` = ROSDEE NOODLE (ระวังสับสน — รหัสไม่ตรงตัวอักษรแรกเป๊ะ)

## รหัส MT เพิ่มเติม 4 ตัว (ไม่อยู่ใน 11 master) — ต้องยืนยัน ❓
ปรากฏใน MT `Target & Cal` + `Actual` และได้รับ incentive รายแถวจริง แต่ **ไม่มีชื่อใน `Product` master** และ **ไม่มีน้ำหนักแยกใน Top WS** → น่าจะเป็น sub-brand/variant ที่ม้วนรวมเข้าสินค้าหลักตัวใดตัวหนึ่ง

| รหัส MT | สมมติฐาน parent (ยังไม่ยืนยัน) | เหตุผล |
|---------|-------------------------------|--------|
| `AJA` | ตระกูล AJINOMOTO (?) | ขึ้นต้น "AJ" |
| `AMV` | ตระกูล AJINOMOTO (?) | ขึ้นต้น "A" |
| `FP` | ❓ | ไม่ทราบ |
| `QM` | ตระกูล ROSDEE CUBE (?) | ขึ้นต้น "Q" คล้าย TT `Q` |

> ⚠️ ต้องให้ Business ยืนยันว่า 4 รหัสนี้คือสินค้าอะไร และ map เข้ากลุ่ม/สินค้าหลักใด (หรือคิด incentive แยกอิสระ)

## รหัส BI ที่ถูกตัดออกจากการคิด Incentive (7 ตัว)
`Actual` (BI) ของ MT มีรหัส Product Group ทั้งหมด **22 ตัว** แต่ `Target & Cal` ใช้เพียง 15 ตัว → ตัดออก 7 ตัว:

`HDSH`, `LPD`, `LQSS`, `SBU`, `STICK`, `SUP`, `SWEET`

> ⚠️ ต้องยืนยันเหตุผลการตัด (ไม่อยู่ในเงื่อนไข incentive / เป็นสินค้านอก scope) — และ TT มีการตัดแบบนี้หรือไม่

## สรุปความสัมพันธ์เชิงตัวเลข
```
BI source (MT Actual)         22 รหัส
   └─ ใช้คิด incentive (MT)    15 รหัส   (ตัด 7)
        ├─ map 1:1 กับสินค้า    11 รหัส   ✅ = Product master
        └─ sub-variant          4 รหัส   ❓ (AJA, AMV, FP, QM)

TT Actual / Target & Cal      11 รหัส = 1:1 กับสินค้า (SKU) ✅
```

## สรุปการจัดกลุ่มที่ต้องใช้ต่อในงานออกแบบฐานข้อมูล
1. กลุ่ม Master Mapping: `mst_product`, `mst_product_mapping`, `mst_salesman_mapping`
2. กลุ่ม Calculation Mapping: `trn_sales_target`, `trn_sales_actual`, `trn_incentive_detail`
3. กลุ่ม Org/People Mapping: `mst_employee`, `mst_org_hierarchy`, `stg_hcm_employee`
4. กลุ่ม Output Mapping: `out_for_hr_variable`, `out_for_hr_fixed`

ผลลัพธ์คือเอกสาร mapping จะอ่านคู่กับ DB design ได้ตรงตามลำดับ Sheet ในงาน SA โดยไม่ต้องแปลโครงใหม่ระหว่างเอกสาร
