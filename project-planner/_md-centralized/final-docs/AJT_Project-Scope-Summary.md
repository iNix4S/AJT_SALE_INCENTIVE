# AJT New Sale Incentive System — Project Scope Summary

**วันที่จัดทำ:** 2026-06-16  
**เวอร์ชัน:** v1.1  
**สถานะ:** Baseline (ทบทวนครั้งที่ 1 — เพิ่มข้อมูลจาก SA Analysis + DB Design)  
**เหมาะกับผู้อ่าน:** Business Owner, Project Manager, SA, Dev, HR, Sales Operations

---

## 1. ชื่อโครงการ

**AJT (Ajinomoto Thailand) New Sale Incentive System**  
ระบบคำนวณ Sales Incentive แบบรวมศูนย์แทนการทำงานบน Excel

---

## 2. เป้าหมายของโครงการ

ย้ายกระบวนการคำนวณ Sales Incentive จาก Excel ไปสู่ระบบที่:

- **ควบคุมได้** — มีขั้นตอน Import → Validate → Calculate → Approve → Export ชัดเจน
- **ตรวจสอบย้อนหลังได้** — ทุกการเปลี่ยนพารามิเตอร์มี Audit Trail
- **ลดความเสี่ยง manual** — ไม่ต้อง copy/paste สูตรรายเดือน
- **รองรับ 2 ช่องทางขาย** — MT (Modern Trade) และ TT (Traditional Trade) ในระบบเดียว

---

## 2b. สถานะ POC ปัจจุบัน (ณ 2026-06-16)

| หมวด | สถานะ |
|---|---|
| DDL 01–39 (ฐานข้อมูล AJT_SIS) | ✅ deployed และ verified ทั้งหมด |
| TT Calculation Engine (SP v9) | ✅ ทำงานถูกต้อง — ยืนยัน FY2026-05: 160 rows, 22 คน |
| MT Calculation Engine | ⏳ ออกแบบครบ รอ implement |
| GD Special Incentive | ⏳ DB schema พร้อม รอ implement |
| Fixed Rate Incentive | ⏳ DB schema พร้อม รอ implement |
| Approval Workflow (K2) | ⏳ รอ implement |
| API Layer (.NET Core 10) | ⏳ รอ implement |
| SSRS Reports | ⏳ รอ implement |
| Dashboard (Chart.js) | ⏳ รอ implement |

---

## 3. ขอบเขตงาน (In-Scope)

### 3.1 กระบวนการหลัก

| ลำดับ | กระบวนการ | รายละเอียด |
|---|---|---|
| 1 | **นำเข้าข้อมูลยอดขาย** | จาก BI/DWC รายเดือน |
| 2 | **นำเข้าข้อมูลพนักงาน** | จาก HCM (Personal Employment Main & Active) |
| 3 | **จัดการโครงสร้างองค์กร** | ASTBase — สายบังคับบัญชา, Job Function |
| 4 | **จัดการพารามิเตอร์** | Period, M_Month, Table, T_SectAbove, Shortage, Fix Rate |
| 5 | **Validation Gate** | ตรวจ Period alignment, Data completeness, Hierarchy, Mapping |
| 6 | **คำนวณ Incentive MT** | Mapping + Cascade 4 ระดับ (Staff → Section → Department → AD) |
| 7 | **คำนวณ Incentive TT** | Single-sheet 5 ระดับ (Staff → Section → Dept → Division → AD) |
| 8 | **GD Special Incentive** | Growth Driver (G1–G4) สำหรับสินค้า Aji Plus / RDQ / RDM / RDNS |
| 9 | **Fixed Rate Incentive** | คำนวณค่าคงที่ตาม Job Function รายพนักงาน |
| 10 | **สร้าง Output สำหรับ HR** | Variable Incentive + Fixed Incentive (For HR) |
| 11 | **Approval Workflow** | อนุมัติก่อนส่ง HR |
| 12 | **Export / Reporting** | ส่งออกไฟล์ให้ HR, พิมพ์รายงาน |
| 13 | **Audit Trail** | ติดตามการเปลี่ยนพารามิเตอร์ทุกรายการ |
| 14 | **Dashboard** | ภาพรวมผลคำนวณรายรอบ |
| 15 | **Interface BI/DWC** | รับยอดขายผ่าน CSV/API |

### 3.2 ช่องทางขายที่รองรับ (ยึดตาม `mst_channel`)

| channel_id | channel_code | channel_name_th | calc_type | หมายเหตุ |
|---|---|---|---|---|
| 1 | **MT** | Modern Trade | `CASCADE_4_LEVEL` | Cascade 4 ระดับ (Staff→Section→Dept→AD) |
| 2 | **TT** | Traditional Trade | `SINGLE_SHEET_5_LEVEL_AVG` | Cascade 5 ระดับ (รวม Division), AVG goal_multiplier |
| 3 | **SI** | S&I (Specialty & Institutional) | `CASCADE_4_LEVEL` | ใช้ logic เดียวกับ MT |
| 4 | **LAOS** | Laos | `SINGLE_SHEET` | Single-sheet baseline (simpler) |

> **GD Special Incentive** และ **Fixed Rate Incentive** เป็น sub-calculation ข้ามช่องทาง ไม่ใช่ channel แยก

---

## 3b. โครงสร้างฐานข้อมูล (Database: AJT_SIS)

**SQL Server 2022 — Schema: dbo — รวม 32 ตาราง**

| กลุ่ม | Prefix | จำนวน | วัตถุประสงค์ |
|---|---|---|---|
| **Master / Parameter / Config** | `mst_` | 19 | ข้อมูลหลัก, policy, เงื่อนไข |
| **Interface / Staging** | `stg_` / `int_` | 3 | รับข้อมูล inbound จาก BI/DWC + HCM |
| **Transaction** | `trn_` | 5 | เป้าขาย, ยอดขายจริง, ผลคำนวณ |
| **Output (For HR)** | `out_` | 3 | ผลลัพธ์ส่ง HR (Variable + Fixed) |
| **Audit** | `aud_` | 2 | บันทึกการเปลี่ยน parameter + approval |

### ตาราง Master หลักที่สำคัญ

| ตาราง | บทบาท |
|---|---|
| `mst_channel` | ช่องทางขาย MT/TT/S&I/Laos (รวม `calc_type`) |
| `mst_employee` | ข้อมูลพนักงาน (sync จาก HCM) |
| `mst_org_hierarchy` | โครงสร้างองค์กร (parent-child, `ws_type`) |
| `mst_product` | Product master (11 สินค้า) |
| `mst_product_weight` | น้ำหนักสินค้าต่อ ws_type (Top WS / WS SF / WS WH / SF WH) |
| `mst_incentive_rate` | Incentive Base Rate ต่อตำแหน่ง/channel |
| `mst_goal_threshold` | เกณฑ์ achievement → GOAL multiplier (step-down) |
| `mst_period` | ปฏิทินรอบ FY2026-04 → FY2027-03 |
| `mst_tt_product` | Product master สำหรับ TT (product_code = short alias) |
| `mst_shortage_policy` | Override achievement กรณีสินค้าขาดแคลน |
| `mst_fix_rate` | อัตรา Fixed Incentive ต่อ Job Function |
| `out_for_hr_variable` | ผลรวม Variable pay ส่ง HR |
| `out_for_hr_fixed` | ผลรวม Fixed pay ส่ง HR |
| `aud_parameter_change` | Audit log การแก้ไข parameter |

---

## 4. ขอบเขตที่ไม่รวม (Out-of-Scope)

| รายการ | เหตุผล |
|---|---|
| การจ่ายเงินจริงผ่าน Payroll/Banking | ระบบนี้สร้าง Output ส่งให้ HR เท่านั้น — การจ่ายจริงเป็นความรับผิดชอบของ HR |
| การปรับโครงสร้าง Job Function นอก HCM | Job Function คือข้อมูลตั้งต้นจาก HCM ไม่ใช่เป้าหมายปรับใน project นี้ |
| Redesign กระบวนการ BI/HCM ต้นทาง | BI/DWC และ HCM เป็น upstream system ที่ต้องรับข้อมูลผ่าน interface ที่ตกลงแล้ว |
| ออกแบบ Incentive Policy ใหม่ทั้งหมด | โครงการนี้แปลง policy ที่ยืนยันแล้วให้เป็นระบบ ไม่ใช่ออกแบบ policy ใหม่ |
| LAOS Channel (POC ระยะนี้) | LAOS มีใน `mst_channel` และใช้ `SINGLE_SHEET` — calculation engine ยังไม่ implement ใน POC เฟสนี้ |

---

## 5. กระบวนการทำงานหลัก (Operational Workflow)

### รอบประจำปี (Annually)
- ตั้งค่า `M_Month` — กำหนด payment calendar ระหว่างเดือนยอดขายกับเดือนจ่าย (Variable/Fixed)

### รอบประจำเดือน (Monthly)

```
[Set Period] → [Import BI Sales] → [Update ASTBase] → [Import HCM Data]
     ↓
[Validation Gate]  ←── บล็อกถ้าไม่ผ่าน
     ↓
[MT Path]        [TT Path]        [GD Special]      [Fixed Rate]
     ↓                ↓                ↓                 ↓
              [Generate For HR Output — Variable + Fixed]
                         ↓
              [Approval] → [Export to HR] → [HR Payment]
                         ↓
                 [Audit + Period Close]
```

### ปรับเมื่อจำเป็น (As-needed)
- ปรับ T_SectAbove (rate ตาม position level)
- ปรับ Table (rate ตาม Job Function)
- ปรับ Target & Cal (เป้าหมายยอดขาย)
- ปรับ Shortage (สินค้าขาดแคลน)
- ปรับ Fix Rate (อัตราคงที่รายพนักงาน)

---

## 5b. สูตรคำนวณหลัก (Core Calculation Formula)

### สูตรพื้นฐาน
```
incentive_รายสินค้า = Incentive_Base × GOAL(achievement) × Weight_สินค้า
incentive_รวม       = Σ (ทุกสินค้า)
```

### สูตรคำนวณแยกตาม 4 Channel

ทั้ง 4 channel ใช้ **แกนสูตรเดียวกัน** (achievement → GOAL → base × GOAL × weight) แต่ต่างกันที่ **ระดับฐานข้อมูล (product group vs SKU)** และ **วิธีรวมขึ้นระดับบน (cascade vs single-sheet)**:

#### กลุ่ม A — MT & S&I (`CASCADE_4_LEVEL`)

**หลักการ:** คิดราย Product Group — 1 BI account กระจายให้หลาย Salesman ผ่าน Mapping → Cascade 4 ระดับ

| ขั้น | สูตร / การทำงาน |
|---|---|
| 1 | **Mapping:** BI SalesCode + Product Group → Salesman Code |
| 2 | `achievement = ROUND(Actual ÷ Target, 4)` ราย product group |
| 3 | ถ้า Shortage flag → `achievement = 1.0` |
| 4 | `GOAL = XLOOKUP(achievement, threshold, goal_table, step-down)` |
| 5 | `incentive_ราย product group = Base × GOAL × Weight` |
| 6 | **Cascade:** `SUMIFS` Target+Actual จาก Staff → Sect → Dept → AD แล้ว**คำนวณ achievement + incentive ใหม่** ที่แต่ละระดับ |
| 7 | `For HR = MAX(floor, Σ incentive ทุกระดับ Staff+Sect+Dept+AD)` |

#### กลุ่ม B — TT & LAOS (`SINGLE_SHEET` / `SINGLE_SHEET_5_LEVEL_AVG`)

**หลักการ:** คิดราย SKU/Product ต่อ Salesman — Target & Cal sheet เดียวครอบทุกระดับ (ไม่ต้อง Mapping)

| ขั้น | สูตร / การทำงาน |
|---|---|
| 1 | `achievement = ROUND(Actual ÷ Target, 4)` ราย product ราย salesman ราย เดือน |
| 2 | ถ้า Shortage flag → `achievement = 1.0` |
| 3 | `GOAL = XLOOKUP(achievement, threshold, goal_table, step-down)` |
| 4 | `incentive_ราย product = Base × GOAL × Weight` |
| 5 | **For HR** รวม incentive ทุก product ต่อ salesman และทุกระดับสายบังคับบัญชา (Direct Sup → Dept Mgr → Div Mgr → AD) |
| 6 | **TT (5-level):** ระดับบนใช้ **AVG goal_multiplier** ของทีม → คูณ base ของตำแหน่งนั้น |
| 7 | **LAOS:** Dept คำนวณแยกใน special column ของ For HR (AD), ไม่มี Division layer |

#### ตารางเปรียบเทียบสูตร 4 Channel

| หัวข้อ | MT | S&I | TT | LAOS |
|---|---|---|---|---|
| calc_type | `CASCADE_4_LEVEL` | `CASCADE_4_LEVEL` | `SINGLE_SHEET_5_LEVEL_AVG` | `SINGLE_SHEET` |
| ฐานคำนวณ | Product Group | Product Group | SKU/Product | SKU/Product |
| ต้อง Mapping | ✅ | ✅ | ❌ | ❌ |
| ระดับ Hierarchy | 4 (Staff→Sect→Dept→AD) | 4 | 5 (+ Division) | 3–4 (Dept แยก) |
| วิธีรวมขึ้นระดับบน | SUMIFS + recalc | SUMIFS + recalc | AVG goal_multiplier | Single-sheet |
| achievement formula | `ROUND(Actual÷Target,4)` | เดียวกัน | เดียวกัน | เดียวกัน |
| Shortage override | achievement=1.0 | achievement=1.0 | achievement=1.0 | achievement=1.0 |
| For HR aggregation | `MAX(floor, Σ ทุกระดับ)` | เดียวกัน | Σ ทุกระดับ | Σ + Dept special column |
| สถานะ POC | ⏳ รอ implement | ⏳ รอ implement | ✅ SP v9 | ⏳ รอ implement |

### ตาราง Achievement → GOAL Multiplier (Step-down lookup)

| Achievement % | 90% | 95% | 100% | 103% | 108% | 110% | 115% | 120% | 130% |
|---|---|---|---|---|---|---|---|---|---|
| **GOAL multiplier** | 0.90 | 0.95 | 1.00 | 1.03 | 1.06 | 1.10 | 1.15 | 1.20 | 1.30 |

> หาก achievement < 90% → ไม่ได้ incentive (0) | ช่วงระหว่าง threshold ใช้ค่าขั้นบันไดที่ต่ำกว่า

### Incentive Base Rate ตามตำแหน่ง (TT)

| ตำแหน่ง | Base Rate (บาท/เดือน) |
|---|---|
| Area Manager (AD) | 5,000 |
| Depocho / D.Depocho | 4,000 |
| CV / CVFV | 2,500 |
| WSF | 3,500 |
| WH | 3,500 |
| Driver | 1,200 |

### น้ำหนักสินค้าต่อ ws_type (Product Weight)

| กลุ่ม | รหัส TT | Top WS | WS SF | WS WH | SF WH |
|---|---|---|---|---|---|
| **G1 CORE** | A (Ajinomoto) | 0.05 | 0.05 | 0.10 | 0.08 |
| | R (Rosdee) | 0.10 | 0.10 | 0.15 | 0.13 |
| | B (Birdy) | 0.20 | 0.10 | 0.25 | 0.18 |
| **G2 GD** | AP (Aji-Plus) | 0.05 | 0.05 | 0.05 | 0.05 |
| | Q (Rosdee Cube) | 0.10 | 0.10 | 0.05 | 0.06 |
| | M (Rosdee Menu) | 0.05 | 0.10 | 0.05 | 0.07 |
| | NS (Rosdee Noodle) | 0.10 | 0.10 | 0.05 | 0.07 |
| **G3 BB** | Y (Yumyum) | 0.15 | 0.15 | 0.10 | 0.13 |
| | P (Powder Coffee) | 0.10 | 0.15 | 0.10 | 0.13 |
| **Others** | T (Takumi-Aji) | 0.05 | 0.05 | 0.05 | 0.05 |
| | RK (Rosdee KKR) | 0.05 | 0.05 | 0.05 | 0.05 |
| | **รวม** | **1.00** | **1.00** | **1.00** | **1.00** |

---

## 5c. Prorate Logic (การคำนวณสัดส่วน กรณีพิเศษรายบุคคล)

> **สถานะ:** บางกรณียืนยันแล้ว (✅) บางกรณีรอ policy จาก Business/HR (❓) — ระบบต้อง **รองรับทุก scenario** และ block ถ้ายังไม่มี policy

| กรณี | Logic ที่คาดการณ์ | ตัวแปรที่ต้องการ | สถานะ |
|---|---|---|---|
| **พนักงานเข้างานกลางเดือน** | Prorate = (วันทำงานจริง ÷ วันทำงานในเดือน) × Incentive เต็ม | `hire_date`, `working_days_in_month` | ❓ รอ Business ยืนยัน |
| **พนักงานลาออกกลางเดือน** | Policy decision: จ่ายตามสัดส่วนวัน หรือไม่จ่ายเลย | `termination_date` | ❓ ต้องได้รับการยืนยันจาก HR |
| **Transfer ข้าม Region/Channel กลางงวด** | แยกคำนวณ Incentive แต่ละ Region ตามสัดส่วนวัน แล้วรวมผล | `effective_from`, `channel_code`, สัดส่วนวัน | ✅ หลักการยืนยัน — รอ implement |
| **เปลี่ยน Position กลางงวด** | ระบุว่าใช้ Position เดิม หรือ Position ใหม่ หรือแยกคำนวณ | `position_level_id`, `effective_from` | ❓ ต้องได้รับการยืนยันจาก HR/Finance |
| **Shortage Override** | บังคับ achievement = 1.0 (by brand) ไม่คำนึงสัดส่วนเวลา | `mst_shortage_policy` | ✅ ยืนยันแล้ว |
| **Fix Rate** | จ่ายเต็มจำนวนตาม Job Function — ไม่มี prorate | `mst_fix_rate` | ✅ ยืนยันแล้ว |

### สูตร Prorate (กรณีทั่วไป — pending confirmation)
```
Incentive_จ่ายจริง = Incentive_Base × GOAL × Weight × (วันทำงานจริง ÷ วันทำงานรวมในเดือน)
```

> ⚠️ **Open Question (OQ):** Policy การ prorate กรณีพนักงานเข้า/ออก/โอนย้ายกลางเดือน — ต้องปิดก่อน UAT  
> ระบบจะ **lock ผลคำนวณ** สำหรับ employee ที่มี mid-month event จนกว่า HR จะยืนยัน

---

## 5d. Special Adjustment (การปรับพิเศษนอกรอบปกติ)

> วัตถุประสงค์: ระบบสามารถปรับ Incentive ในกรณีพิเศษได้โดย Config ไม่ต้อง hardcode — ทุกการปรับต้องผ่าน Audit Trail

### 5d.1 ประเภทของ Special Adjustment

| ประเภท | เงื่อนไขที่ใช้ | Logic | ตาราง DB | สถานะ |
|---|---|---|---|---|
| **Shortage** | สินค้าขาดตลาด — ไม่ใช่ Performance ต่ำ (เช่น น้ำท่วม, ภัยพิบัติ) | ปรับ Actual = Standard 100% by brand | `mst_shortage_policy` | ✅ |
| **Special Situation** | พนักงานขายรับมือสถานการณ์พิเศษและสินค้าเพิ่มชั่วคราวเฉพาะเดือน | ปรับทั้ง sales target **และ** % allocation weight | `trn_sales_target` + `mst_product_weight` | ❓ รอ confirm scope |
| **T_SectAbove** | ปรับอัตราตามระดับตำแหน่ง | เปลี่ยน incentive base ของตำแหน่งนั้น | `mst_incentive_rate` | ✅ |
| **Table (Job Function Rate)** | ปรับอัตราตาม Job Function | เปลี่ยน weight/base ราย salesman | `mst_incentive_rate` | ✅ |
| **Target Adjustment** | ปรับเป้าขายตามสถานการณ์ธุรกิจ | เปลี่ยน achievement โดยตรง | `trn_sales_target` | ✅ |
| **Fix Rate** | ตาม Job Function ที่กำหนด | จ่ายจำนวนเงินคงที่ไม่ขึ้นกับ achievement | `mst_fix_rate` | ✅ |
| **GD Special Incentive** | สินค้ากลุ่ม G2 Growth Driver | คำนวณ incentive แยก scheme ราย product (step payout) | `mst_gd_product`, `mst_gd_payout` | ⏳ schema พร้อม รอ implement |

### 5d.2 Fix Rate ที่ยืนยันแล้ว

| Job Function | อัตราคงที่ (บาท/เดือน) |
|---|---|
| TT Senior Cash Van Sales | 3,000 |
| TT Senior Cash Van Food Vendor | 3,000 |
| TT Cash Van Sales | 2,500 |
| TT Cash Van Food Vendor | 2,500 |
| Shop Front | 1,500 |
| Sales Assistant | 1,200 |

### 5d.3 Control Gate ของ Special Adjustment

- ทุกการปรับต้องมี **เหตุผล** บันทึกไว้ใน `aud_parameter_change`
- กรณี **Special Situation** (ปรับ target + weight) — ต้องผ่าน **Approval** จาก Business Owner ก่อน
- ระบบต้องแสดง **Before/After** ของค่าที่ถูกปรับ เพื่อ Audit Trail

---

## 6. เทคโนโลยีที่ใช้

| ชั้น | เทคโนโลยี | บทบาท |
|---|---|---|
| Workflow / Approval | Nintex K2 Workflow + Smart Forms | ควบคุมรอบงาน, อนุมัติ, ฟอร์มกรอกข้อมูล |
| Calculation Engine | .NET Core 10 Service API | คำนวณ achievement, GOAL, cascade, GD, fixed |
| Database | Microsoft SQL Server (DB: AJT_SIS) | เก็บ master data, ผลคำนวณ, audit trail |
| Reporting | SQL Server Reporting Services (SSRS) | รายงานและไฟล์ส่ง HR |
| Dashboard | Chart.js | ภาพรวมผลคำนวณแบบ read-only |
| Integration (Inbound) | BI/DWC Interface, HCM Interface | รับยอดขายและข้อมูลพนักงาน (CSV/API) |
| Integration (Outbound) | SSRS Output File | ส่งผลให้ HR Payroll |

---

## 7. ระบบที่เชื่อมต่อ (External Systems)

| ระบบ | ทิศทาง | รูปแบบ | ความถี่ |
|---|---|---|---|
| **BI / DWC** (ยอดขาย) | Inbound | CSV / API | รายเดือน |
| **HCM** (ข้อมูลพนักงาน) | Inbound | CSV / API | รายเดือน |
| **HR Payroll System** | Outbound | SSRS File | รายรอบจ่าย |

---

## 8. Stakeholders

| กลุ่ม | บทบาท |
|---|---|
| Business Owner (Sales/Commercial) | อนุมัติ policy และผลคำนวณ |
| Sales Operations | ดูแลข้อมูล Target / Shortage / Fix Rate และรอบเดือน |
| HR / Compensation | รับผลลัพธ์เพื่อจ่าย Incentive |
| IT / SA / Dev | ออกแบบและพัฒนาระบบ |
| Data Team (BI/DWC) | ดูแล feed ยอดขาย |
| HCM Owner | ดูแล feed ข้อมูลพนักงาน |

---

## 9. เกณฑ์วัดความสำเร็จ (Success Criteria)

| หัวข้อ | เกณฑ์ |
|---|---|
| **Accuracy** | ผลคำนวณตรงกับ baseline Excel ≥ 99.5% ในชุด UAT ที่ตกลงร่วมกัน |
| **Timeliness** | รอบคำนวณรายเดือนเสร็จภายใน 1 วันทำการหลังข้อมูลครบ |
| **Data Integrity** | ไม่พบ period mismatch ระหว่าง Sales และ HR ในรอบที่อนุมัติจ่าย |
| **Auditability** | ทุกการปรับพารามิเตอร์ต้องมีผู้แก้ไข, เวลา และเหตุผลบันทึกไว้ |

---

## 9b. Product Code Standard

ระบบใช้รหัสสินค้า 2 ระบบ — แยกตามช่องทาง:

| กลุ่ม | ชื่อสินค้า | รหัส MT (BI) | รหัส TT (short alias) |
|---|---|---|---|
| G1 CORE | Ajinomoto | `AJ` | `A` |
| G1 CORE | Rosdee | `RD` | `R` |
| G1 CORE | Birdy | `BD` | `B` |
| G2 GD | Aji-Plus | `AJP` | `AP` |
| G2 GD | Rosdee Cube | `RDC` | `Q` |
| G2 GD | Rosdee Menu | `RM` | `M` |
| G2 GD | Rosdee Noodle | `ND` | `NS` |
| G3 BB | Yumyum | `YY` | `Y` |
| G3 BB | Powder Coffee | `PDC` | `P` |
| Others | Takumi-Aji | `TKM` | `T` |
| Others | Rosdee KKR | `RKR` | `RK` |

> **MT**: BI ส่ง 22 product group codes → ใช้คิด incentive 15 ตัว → master 11 ตัว (+ sub-variant 4 ตัว ❓ ยังรอ Business ยืนยัน: AJA, AMV, FP, QM)  
> **TT**: `product_code` ใน DB = short alias โดยตรง (A/R/B/…) — ไม่ต้อง map เพิ่ม

---

## 10. สรุปความแตกต่างหลักของแต่ละช่องทาง

| หัวข้อ | MT | TT |
|---|---|---|
| ฐานคำนวณ | Product Group (15 รหัส BI) | Product/SKU (11 short alias: A/R/B/AP...) |
| ต้องทำ Mapping | ✅ BI SalesCode → Salesman | ❌ ใช้ Salesman Code ตรง |
| จำนวน Hierarchy | 4 ระดับ (Staff→Section→Dept→AD) | 5 ระดับ (รวม Division) |
| calc_type | `CASCADE_4_LEVEL` | `SINGLE_SHEET_5_LEVEL_AVG` |
| วิธี Cascade | SUMIFS (รวม Target/Actual ทุกระดับ) | AVG goal_multiplier ทุก SKU → cascade ขึ้น |
| ws_type | ไม่ใช้ | TOP_WS / WS_SF / WS_WH / SF_WH |
| Source ยอดขาย | `stg_bi_sales` + Mapping table | `stg_bi_sales` (SKU + non-SKU) |
| Stored Procedure | ยังไม่มี | `usp_run_tt_incentive_calculation` v9 ✅ |
| Sheet ต้นทาง (Excel) | Top WS, WS SF, WS WH, SF WH (4 ชุด) | Top WS (TT), 26 product/SKU sheets |
| ผลลัพธ์ For HR | incentive_staff + sect + dept + ad | incentive_staff + sect + dept + div + ad |

---

## 11. Sheet-to-Database Alignment (สรุป)

| Excel Sheet | ตาราง DB หลัก | ทิศทาง |
|---|---|---|
| M_Month | `mst_payment_cycle` | Parameter |
| Period | `mst_period`, `trn_calc_run` | Parameter / Transaction |
| Actual (BI) | `stg_bi_sales` → `trn_sales_actual` | Inbound staging |
| ASTBase | `mst_org_hierarchy` | Master |
| HR Rep (HCM) | `stg_hcm_employee` → `mst_employee` | Inbound staging |
| Mapping (MT) | `mst_product_mapping`, `mst_salesman_mapping` | Master |
| Top WS / Table | `mst_product_weight`, `mst_incentive_rate` | Parameter |
| T_SectAbove | `mst_incentive_rate` | Parameter |
| Target & Cal | `trn_sales_target`, `trn_incentive_detail` | Transaction |
| Shortage | `mst_shortage_policy` | Parameter |
| Fix Rate | `mst_fix_rate` | Parameter |
| For HR | `out_for_hr_variable` | Output |
| For HR (FIX) | `out_for_hr_fixed` | Output |

---

## 12. เอกสารอ้างอิงหลัก

| เอกสาร | ที่อยู่ |
|---|---|
| BRD/SRS | `5.Docs/BRD-SRS_AJT-New-Sale-Incentive_Draft-v0.1_2026-06-12.md` |
| Business Process Design | `5.Docs/Business-Process-Design_AJT-New-Sale-Incentive_v1.0_2026-06-13.md` |
| System Architecture Design | `5.Docs/System-Architecture-Design_AJT-New-Sale-Incentive_v1.0_2026-06-13.md` |
| Sales Incentive Guide (POC) | `5.Docs/Sales Incentive System for POC.md` |
| TT Flow Process Summary | `final-docs/AJT_TT-Flow-Process_Summary.md` |
| Business Flow Summary | `final-docs/AJT_Business-Flow-Process_Summary.md` |
| Solution & Tech Stack | `final-docs/AJT_Solution-and-Technology-Stack_Summary.md` |
| Final Docs Index | `final-docs/AJT_Final-Docs_Index.md` |
| **SA Analysis — Calculation Logic** | `4.System Analyst and Design/03.Calculation-Logic/00_สรุปตรรกะการคำนวณ_ตั้งต้น.md` |
| **SA Analysis — Product Code Mapping** | `4.System Analyst and Design/04.Data-Dictionary/01_Product-Code-Mapping.md` |
| **SA Analysis — Data Flow Diagram** | `4.System Analyst and Design/05.Process-Flow/01_Data-Flow-Diagram.md` |
| **Database Design** | `4.System Analyst and Design/database design/DB-Design_AJT-New-Sale-Incentive_v1.0_2026-06-13.md` |
| **DDL Scripts (01–39)** | `environment/ddl/` |
