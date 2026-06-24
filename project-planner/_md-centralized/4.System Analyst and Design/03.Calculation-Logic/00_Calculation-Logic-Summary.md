# สรุปตรรกะการคำนวณ Sales Incentive (เอกสารตั้งต้น)

> เวอร์ชัน: Draft v0.2 — 2026-06-12 (ยืนยันสูตรจริงจาก formulas.csv ครบแล้ว)
> ที่มา: ถอดจาก sheet **`Guide`** และ **`2) หลักการคำนวน Table`** (อ้างอิงต่อเนื่องไปยัง `Top WS` / WS sheets)
> ครอบคลุม: ช่องทาง **MT** และ **TT**
> สถานะ: เอกสารตั้งต้นเพื่อตั้งหลักความเข้าใจ — ส่วนที่ยังไม่ยืนยันถูกทำเครื่องหมาย ❓ ไว้ที่ท้ายเอกสาร

---

## 1. ภาพรวมกระบวนการ (จาก sheet `Guide`)

`Guide` กำหนด "วิธีใช้งานไฟล์" ไว้ 3 ระดับความถี่:

### 1.1 รายปี (Annually)

| ขั้น | Sheet | รายละเอียด |
| --- | --- | --- |
| 1 | `M_Month` | กำหนด payment calendar mapping ระหว่างเดือนยอดขายกับเดือนจ่าย Incentive ของ Variable และ Fixed |

### 1.2 รายเดือน (Monthly) — กระบวนการหลักที่ทำซ้ำทุกเดือน

| ขั้น | Sheet | รายละเอียด |
| --- | --- | --- |
| 1 | `Period` | กำหนดช่วงเวลา (period) ของรอบ Incentive |
| 2 | `Actual` | ดาวน์โหลดข้อมูลยอดขายจาก **BI** แล้ว copy ลง sheet `Actual` |
| 3 | `ASTBase` | อัปเดตข้อมูล AST Base + copy สูตรในคอลัมน์ที่ไฮไลต์สีเหลือง |
| 4 | `HR Rep` | ดาวน์โหลดรายงาน *Personal Employment (Main & Active)_AST* จาก **HCM** → อัปเดต `HR Rep` + copy สูตรคอลัมน์สีเหลือง |
| 5 | `For HR` | กรอก Employee ID แล้ว copy สูตรทุกคอลัมน์ ยกเว้น Employee ID และ Payment Method |

### 1.3 ปรับเมื่อจำเป็น (As needed)

| ขั้น | Sheet | รายละเอียด |
| --- | --- | --- |
| 1 | `T_SectAbove` | ปรับอัตราค่าตอบแทนตาม **ระดับตำแหน่ง** (position level) |
| 2 | `Table` | ปรับอัตราค่าตอบแทนตาม **Job Function** |
| 3 | `Target & Cal` | ปรับ **เป้าขาย (sales target)** ตามเงื่อนไขธุรกิจ |
| 4 | `Shortage` | ปรับ shortage ราย product/เดือน |
| 5 | `Fix Rate` | ปรับอัตราคงที่รายพนักงาน (sheet `ค่าตอบแทนการขายในอัตราคงที่`) |

> ⚠️ หมายเหตุจาก Guide: ต้องตรวจสอบว่าข้อมูลยอดขายและพนักงาน **สอดคล้องกับ period ของเดือนนั้น** เสมอ และให้ recheck Job Function

**ลำดับการไหลของข้อมูล (ภาพรวม):**

```text
Period (ตั้งรอบ)
   └─> Actual (ยอดขายจริงจาก BI) ─┐
   └─> ASTBase (ฐานข้อมูล AST) ────┤
   └─> HR Rep (ข้อมูลพนักงานจาก HCM)┤
                                    ▼
                          Target & Cal (คำนวณ achievement + incentive)
                                    ▼
                          For HR (ผลลัพธ์จ่ายรายคน) ──> ส่ง HR
```

---

## 2. โครงสร้างตารางอัตรา (จาก `2) หลักการคำนวน Table` + `Top WS`)

> สำคัญ: sheet `2) หลักการคำนวน Table` ส่วนใหญ่ **ดึงค่ามาจาก `Top WS`** (เช่น `='Top WS'!H6`) ดังนั้น **พารามิเตอร์ตัวจริงอยู่ในชุด WS sheets** ได้แก่ `Top WS`, `WS SF`, `WS WH`, `SF WH` — ตารางนี้เป็นเพียงมุมมองสรุป/นำเสนอ

### 2.1 Incentive Base ตามตำแหน่ง (Top WS, คอลัมน์ Depot Old/New)
ค่าฐาน incentive ต่อเดือน แยกตามตำแหน่ง (มีคอลัมน์ Old vs New):

| ตำแหน่ง (Depot) | Old | New |
|------------------|-----|-----|
| Area Manager | 5,000 | 5,000 |
| Depocho | 4,000 | 4,000 |
| D.Depocho | 4,000 | 4,000 |
| CV | 2,500 | 2,500 |
| Driver | 1,200 | 1,200 |
| CVFV | – | 2,500 |
| WSF | – | 3,500 |
| WH | – | 3,500 |

### 2.2 ตาราง Achievement → Payout Multiplier (GOAL)
หัวใจของการคำนวณคือการแปลง **% บรรลุเป้า (achievement)** เป็น **ตัวคูณจ่าย (GOAL multiplier)**:

| Money (ผลต่างจากเป้า) | -0.10 | -0.05 | 0 | +0.03 | +0.08 | +0.10 | +0.15 | +0.20 | +0.30 |
|---|---|---|---|---|---|---|---|---|---|
| **Achievement %** | 90% | 95% | 100% | 103% | 108% | 110% | 115% | 120% | 130% |
| **GOAL (ตัวคูณจ่าย)** | 0.90 | 0.95 | 1.00 | 1.03 | 1.06 | 1.10 | 1.15 | 1.20 | 1.30 |
| **Threshold (≥)** | 0.9001 | 0.9501 | 1.0001 | 1.0301 | 1.0601 | 1.1001 | 1.1501 | 1.2001 | 1.3001 |

- **Payout รวม = Incentive Base × GOAL** เช่น ฐาน 4,000:
  90% → 3,600 | 100% → 4,000 | 130% → 5,200
- ใช้ **lookup แบบขั้นบันได** (step): นำ achievement จริงไปเทียบ threshold เพื่อหา GOAL
- จุดสังเกต: ความสัมพันธ์ **ไม่เชิงเส้นช่วงบน** — achievement 108% ได้ตัวคูณ 1.06 (ไม่ใช่ 1.08), 110%→1.10, 130%→1.30
- หาก achievement < 90% (Money < -0.1) → ดู §2.5 (Extreme/Special) และ ❓

### 2.3 น้ำหนักรายกลุ่มสินค้า (Product Weight) — รวม = 100%
Incentive ฐานถูกกระจายตามกลุ่มสินค้า/รหัสสินค้า โดยน้ำหนัก **ต่างกันตามชุด WS** (ตำแหน่ง/Job Function):

| กลุ่ม | รหัส | Top WS | WS SF | WS WH | SF WH |
|-------|------|--------|-------|-------|-------|
| **G1 (CORE)** | A | 0.05 | 0.05 | 0.10 | 0.08 |
| | R | 0.10 | 0.10 | 0.15 | 0.13 |
| | B | 0.20 | 0.10 | 0.25 | 0.18 |
| **G2 (GD)** | AP | 0.05 | 0.05 | 0.05 | 0.05 |
| | Q | 0.10 | 0.10 | 0.05 | 0.06 |
| | M | 0.05 | 0.10 | 0.05 | 0.07 |
| | NS | 0.10 | 0.10 | 0.05 | 0.07 |
| **G3 (BB)** | Y | 0.15 | 0.15 | 0.10 | 0.13 |
| | P | 0.10 | 0.15 | 0.10 | 0.13 |
| **Others** | T | 0.05 | 0.05 | 0.05 | 0.05 |
| | RK | 0.05 | 0.05 | 0.05 | 0.05 |
| **รวม** | | **1.00** | **1.00** | **1.00** | **1.00** |

> Top WS มี cell ตรวจสอบ `SUM(weight)=1` (เซลล์ C2/C30 ตรวจผลรวม)

### 2.4 สูตรคำนวณ incentive รายสินค้า
```
incentive_รายสินค้า = Incentive_Base × GOAL(achievement) × Weight_สินค้า
incentive_รวม       = Σ (ทุกสินค้า)
```
ตัวอย่างจาก Top WS (ฐาน 4,000, สินค้า A weight 0.05):
- ที่ 100% → 4,000 × 1.00 × 0.05 = **200**
- ที่ 90%  → 4,000 × 0.90 × 0.05 = **180**
- ที่ 130% → 4,000 × 1.30 × 0.05 = **260**

ตาราง lookup รายสินค้า (Top WS rows 19–28) เก็บค่าสำเร็จรูปไว้ตาม threshold แล้ว (A,R,B,AP,…) เพื่อให้ sheet คำนวณดึงไปใช้ตรง ๆ

### 2.5 EXTRA / Special KPI และเกณฑ์ Extreme (Top WS rows 33–48)
นอกเหนือจาก incentive ปกติ มีโครงสร้างโบนัส/พิเศษเพิ่ม:
- **Special KPI** แยกราย G1/G2/G3/Ot (เช่น G1=220, G2=180 … รวมตัวอย่าง = 1,224)
- **เกณฑ์ Extreme** เป็นขั้นบันไดละเอียดกว่า: `<80% / 80–<90% / 90–<95% / 95–<100% / 100–<105% / 105–<110% / 110–<115% / 115–<120% / 120–<130% / >130%`
  - ตัวอย่าง mapping เป็นจำนวนเงิน: 0 / 1,200 / 1,350 / 1,425 / 1,500 / 1,575 / 1,725 / 1,875 / 1,950 / 2,100
  - Money เทียบเท่า: -0.2 / -0.1 / -0.05 / – / 0.05 / 0.15 / 0.25 / 0.3 / 0.4
- มี **Option1** เป็นอีกชุดเกณฑ์ขั้นบันได (ราย G1–G4) — ❓ ใช้กรณีใด

### 2.6 Cascade Concept (โครงสร้างไหลขึ้นตามสายงาน)
Top WS ระบุแนวคิด incentive แบบ cascade ขึ้นตามลำดับชั้น:
```
Salesman ──> Depocho ──> Area Manager ──> Division Manager
(ผลรวม/ผลเฉลี่ยของระดับล่าง กลายเป็นฐานคำนวณของระดับบน)
```
- ฝั่ง **MT**: แยกเป็น 4 sheet (`_Staff / _Sect / _Dept / _AD`) ใช้ **SUMIFS** รวม Target+Actual แล้วคำนวณใหม่ทุกระดับ
- ฝั่ง **TT**: รวมทุกระดับใน `3)Target & Cal` sheet เดียว แต่**มี hierarchy cascade ครบ 5 ระดับ** ใช้ **AVERAGEIFS** (ไม่ใช่ SUMIFS) ดึงค่าจากระดับล่างขึ้นบน — ยืนยันจาก `16_1) For HR (AD).formulas.csv` ✅

> ⚠️ **แก้ไขจากเดิม:** TT ไม่ใช่ "single-sheet ไม่มี cascade" — TT คำนวณใน sheet เดียว **แต่มี hierarchy 5 ระดับ** (Sales, Section, Department, Division, AD) โดยใช้ AVERAGEIFS แทน SUMIFS

---

## 3. ความต่างระหว่าง MT และ TT

### 3.1 หลักการคิดเชิงธุรกิจ (ตามที่ Business ระบุ)
> ข้อมูลจากผู้ใช้ (ถือเป็น requirement ตั้งต้น):

| ไฟล์ | หลักการคิด Incentive |
|------|----------------------|
| **MT** (`..._formula_MT.xlsx`) | คิดแบบ **Product Group** — salesman 1 คนดูแล **หลาย product group** |
| **TT** (`..._Pain_..._TT.xlsx`) | คิดแบบ **standard ทั่วไป** — ตามยอดขายของ salesman ราย **SKU/สินค้า** |

### 3.2 หลักฐานจากข้อมูลที่ตรวจสอบ (ยืนยันแล้ว ✅)
ตรวจสอบจาก `3)Target & Cal`, `Mapping`, `Product` ของทั้ง 2 ไฟล์ — **สอดคล้องกับหลักการข้างต้น**:

**MT — Product-Group-centric (แบ่งลูกค้า/บัญชีตาม product group ให้หลาย salesman)**
- sheet `Mapping` มีคอลัมน์ชื่อ **"Product Group"** ตรง ๆ และ map: `SalesCode_BI → Product Group → Salesman Code`
- บัญชี BI **เดียวกัน** ถูกแตกตาม product group แล้วจ่ายให้ salesman **คนละคน** เช่น
  BI `1190064712`: AJ/AJP/YY/RKR → salesman `5490000711`, RDC/RM/ND/RD → `5490000705`, BD/PDC/TKM → `5490000714`
- `3)Target & Cal_Staff` คีย์ = (DirectSupCode, **Product**, Team) → salesman 1 คน (Team) มีหลายแถวตาม product group
- ใช้รหัส **product group 15 ตัว**: AJ, AJP, AMV, AJA, BD, FP, PDC, RD, RDC, RM, RKR, TKM, YY, ND, QM (ละเอียดกว่าระดับสินค้า — บางสินค้าถูกซอยเป็นหลายกลุ่ม)

**TT — Salesman-centric ราย product/SKU**
- คีย์ = (**SalesmanCode**, Product, Team) — วัดยอดของ salesman เองเป็นราย product
- ใช้รหัส **11 ตัว = ตรง 1:1 กับ `Product` master** (A=AJINOMOTO, R=ROSDEE, B=BIRDY, Y=YUMYUM, P=POWDER COFFEE, AP=AJI-PLUS, M=ROSDEE MENU, T=Takumi-Aji, Q=ROSDEE CUBE, RK=ROSDEE MENU KKR, NS=ROSDEE NOODLE)
- **ไม่มี sheet `Mapping`** (ไม่ต้องแตกบัญชีข้าม salesman) — ต่างจาก MT ที่มี

> 🔑 จุดที่ทำให้ "MT=group vs TT=SKU" สมเหตุสมผล ทั้งที่ MT มีรหัสมากกว่า:
> ความต่างไม่ได้อยู่ที่ "จำนวนรหัส" แต่อยู่ที่ **หน่วยความรับผิดชอบ (ownership)** —
> MT: ลูกค้า/บัญชีถูกแบ่งตาม **product group** กระจายให้หลาย salesman (1 salesman ถือหลายกลุ่ม)
> TT: salesman เป็นเจ้าของยอดขายตัวเอง วัดราย **สินค้า/SKU** ตรง ๆ (ไม่แบ่งบัญชีข้ามคน)

### 3.3 ความต่างเชิงโครงสร้างไฟล์
| ประเด็น | MT | TT |
|---------|-----|-----|
| sheet `Target & Cal` | แยก 4 sheet: `_Staff`, `_Sect`, `_Dept`, `_AD` | รวมเป็น sheet เดียว `3)Target & Cal` แต่**มี hierarchy 5 ระดับ** |
| วิธี cascade | **SUMIFS** รวม Target+Actual แล้วคำนวณ achievement ใหม่ | **AVERAGEIFS** ดึงค่า incentive จากระดับล่างขึ้นบน ✅ ยืนยันจาก formulas.csv |
| จำนวน hierarchy | 4 ระดับ (Staff / Sect / Dept / AD) | 5 ระดับ (Sales / Section / Department / Division / AD) ✅ |
| sheet `For HR` | `1) For HR` + `1) For HR (FIX)` | `1) For HR` + `1) For HR (AD)` |
| sheet `Mapping` | **มี** (แบ่งบัญชีตาม product group → salesman) | **ไม่มี** |
| sheet `Guide` | มี | ไม่มี (ใช้ logic เดียวกัน) |
| sheet `ค่าตอบแทนการขายในอัตราคงที่` (Fix Rate) | มี | ไม่มีแยก (ใช้ For HR (AD)) |
| รหัสสินค้า | 15 product group (AJ/RD/BD/…) | 11 product = SKU (A/R/B/…) |

> ⚠️ ยังต้องยืนยัน: ความสัมพันธ์/mapping ระหว่างรหัส MT 15 ตัว กับสินค้า 11 ตัว (สินค้าใดถูกซอยเป็นหลาย product group ในฝั่ง MT) — ดู ❓ ข้อ 6

---

## 4. สูตรหลัก — ยืนยันจากสูตรจริงแล้ว ✅

> ยืนยันจาก `13_3)Target & Cal_Staff.formulas.csv`, `14_3)Target & Cal_Sect.formulas.csv`, `20_1) For HR.formulas.csv`

### 4.1 สูตรคำนวณ Achievement รายสินค้า (ยืนยัน ✅)
```
achievement[product] = ROUND(actual[product] / target[product], 4)

# กรณีพิเศษ — Shortage override:
IF VLOOKUP(TeamCode, Shortage!$A:$M, col_product) = "Shortage"
   THEN achievement[product] = 1.0   ← บังคับให้ถือว่าบรรลุ 100%
   ELSE achievement[product] = ROUND(actual / target, 4)
```
- คิด **ราย product** (ไม่ใช่รวมยอด) — ทุกสินค้ามี achievement แยกกัน ✅ ปิด ❓ ข้อ 1

### 4.2 สูตรหา GOAL Multiplier (ยืนยัน ✅)
```
goal[product] = XLOOKUP(achievement[product],
                         '2) หลักการคำนวน Table'!$C$3:$K$3,   ← threshold row
                         '2) หลักการคำนวน Table'!$C$3:$K$3,   ← goal value row
                         match_mode = 1)   ← exact or next smaller (step-down lookup)

# Edge case:
IF achievement < MIN(threshold) → goal = MIN(goal_table)   ← floor ที่ 0.90
IF achievement > MAX(threshold) → goal = MAX(goal_table)   ← cap ที่ 1.30
```
- ใช้ `XLOOKUP` mode 1 = ขั้นบันไดลง (match ≤) คิดราย product ✅

### 4.3 สูตรคำนวณ Incentive (ยืนยัน ✅)
```
incentive[product] = VLOOKUP(goal[product],
                              payout_table_for_product,
                              col_match)
# หรือ
incentive[product] = base × goal[product] × weight[product]

incentive_total    = Σ incentive[product]   ← รวมทุกสินค้าของ salesman คนนั้น
```

### 4.4 Cascade — สูตรจริง ✅ ปิด ❓ ข้อ 5
```
# ระดับ Sect: รวม Target+Actual จากระดับ Staff ด้วย SUMIFS
target_sect[product] = SUMIFS(Staff.target[product],
                              Staff.DirectSupCode = Sect.DirectSupCode,
                              Staff.SectionCode   = Sect.SectionCode)
actual_sect[product] = SUMIFS(Staff.actual[product], ... เงื่อนไขเดียวกัน ...)

# จากนั้นคำนวณ achievement และ incentive ใหม่ที่ระดับ Sect
achievement_sect[product] = ROUND(actual_sect / target_sect, 4)
incentive_sect = คำนวณด้วยสูตรเดิม (XLOOKUP → payout table)
```
- **ไม่ใช่ "บวก incentive" จากระดับล่าง** แต่เป็น **SUMIFS ยอด Target/Actual แล้วคำนวณใหม่** ✅
- Dept และ AD ทำแบบเดียวกัน (SUMIFS จาก Sect ขึ้นไป)

### 4.5 Shortage — กลไกจริง ✅ ปิด ❓ ข้อ 8 (บางส่วน)
```
IF Shortage!product[month] = "Shortage"
   THEN achievement = 1.0   ← บังคับ 100% (ไม่ถูกหักเพราะขาดสินค้า)
```
- ข้อมูลจาก `Shortage` sheet: AJ, RD, YY ถูกตั้งเป็น Shortage ใน Apr (เดือน 1 ของไฟล์ทดสอบ)
- ผล: salesman ที่ขาย AJ/RD/YY ใน Apr จะได้ achievement = 1.0 โดยอัตโนมัติ ไม่ขึ้นกับยอดจริง

### 4.6 Fix Rate — กลไกจริง ✅ ปิด ❓ ข้อ 8 (ส่วนที่สอง)
```
Fix Rate = จำนวนเงินคงที่ต่อเดือน ตาม Job Function (ไม่ผันแปรตาม achievement)

Job Function                              Fix Rate (บาท/เดือน)
─────────────────────────────────────────────────────────────
TT Senior Cash Van Sales                  3,000
TT Senior Cash Van Food Vender            3,000
TT Cash Van Sales                         2,500
TT Cash Van Food Vender                   2,500
Shop Front                                1,500
Sales Assistant                           1,200
```
- ใช้สำหรับ Job Function ที่ไม่ได้คิดแบบ variable (achievement-based)
- ใน MT ถูกแยกไว้ที่ sheet `ค่าตอบแทนการขายในอัตราคงที่`

### 4.7 Output: For HR — กลไกจริง ✅
```
# For HR คีย์ด้วย Employee ID → ดึงข้อมูลพนักงานจาก HR Rep + ASTBase
# คำนวณ incentive รวม:
incentive_K = MAX(
  MIN_floor,                                           ← ฐาน (col O)
  ROUND(P + Q + R + S, 2)                             ← sum ทุกระดับ
)
โดย:
  P = SUMIFS(Target_Cal_Staff.col_BN, key = EmployeeID)   ← incentive ระดับ Staff
  Q = SUMIFS(Target_Cal_Sect.col_BN,  key = EmployeeID)   ← incentive ระดับ Section
  R = SUMIFS(Target_Cal_Dept.col_BN,  key = EmployeeID)   ← incentive ระดับ Dept
  S = SUMIFS(Target_Cal_AD.col_BN,    key = EmployeeID)   ← incentive ระดับ AD

# พนักงานแต่ละคนได้ incentive ของระดับที่ตัวเองอยู่เท่านั้น (P, Q, R หรือ S อย่างใดอย่างหนึ่ง ≠ 0)
```
- `รอบการจ่าย Incentive` = ดึงจาก `Period` sheet
- `รูปแบบการจ่าย` = Variable (ผันแปร) หรือ Fixed
- คอลัมน์ Staff/Section/Dept Mgr/AD แสดง incentive แยกระดับ (ใช้ตรวจสอบ)

---

## 5. คำถามค้างคา — อัปเดตสถานะ

| # | คำถาม | สถานะ |
|---|-------|-------|
| 1 | Achievement คิดราย product หรือยอดรวม | ✅ **รายสินค้า** (ROUND(actual/target, 4) ต่อ product) |
| 2 | achievement < 90% จ่ายอย่างไร | ✅ **Floor ที่ MIN threshold = 0.90** (XLOOKUP mode 1 return min) |
| 3 | ทำไม 108%→1.06 ไม่ใช่ 1.08 | ❓ ยังต้องยืนยัน (ตาราง test หรือ business rule จงใจ) |
| 4 | EXTRA/Special KPI/Option1 ใช้กรณีใด | ❓ ยังไม่พบสูตรที่ใช้งานจริง — อาจเป็น scenario สำรอง |
| 5 | สูตร Cascade | ✅ **SUMIFS Target+Actual แล้วคำนวณ achievement+incentive ใหม่** ทุกระดับ |
| 6 | Mapping MT 15 รหัส ↔ TT 11 รหัส | ✅ ดู [04.Data-Dictionary/01_Product-Code-Mapping.md](../04.Data-Dictionary/01_Product-Code-Mapping.md) |
| 7 | Old vs New base เลือกอย่างไร | ❓ ยังต้องยืนยัน (ไฟล์ทดสอบใช้ New ทั้งหมด แต่ไม่ทราบเงื่อนไขเลือก) |
| 8 | Shortage & Fix Rate ทำงานอย่างไร | ✅ **Shortage → บังคับ achievement=1.0** / **Fix Rate → จ่ายคงที่ตาม Job Function** |

**คงเหลือ ❓ ที่ต้องยืนยันกับ Business: ข้อ 3, 4, 7 และ 4 รหัส MT เพิ่ม (AJA/AMV/FP/QM)**

---

## 6. สถานะ 03.Calculation-Logic

| หัวข้อ | สถานะ |
|--------|-------|
| Flow การทำงาน (Guide) | ✅ สมบูรณ์ |
| ตารางอัตรา + GOAL lookup | ✅ สมบูรณ์ |
| สูตร achievement ราย product | ✅ ยืนยันจาก formulas |
| สูตร Cascade (SUMIFS ทุกระดับ) | ✅ ยืนยันจาก formulas |
| Shortage override | ✅ ยืนยันจาก formulas |
| Fix Rate (Job Function-based) | ✅ ยืนยันจาก formulas |
| Output For HR (รวม P+Q+R+S) | ✅ ยืนยันจาก formulas |
| EXTRA/Special KPI/Option1 | ❓ ยังไม่ยืนยัน |
| Old vs New base condition | ❓ ยังไม่ยืนยัน |
| ขั้นตอนถัดไป | → สร้าง 05.Process-Flow (Mermaid diagram) |
