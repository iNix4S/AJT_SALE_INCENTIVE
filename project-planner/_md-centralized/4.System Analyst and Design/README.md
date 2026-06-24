# 4. System Analyst and Design — คู่มือโครงสร้างและตรรกะการอ่าน (สำหรับมนุษย์และ AI Agent)

> เวอร์ชัน: v1.0 — 2026-06-13
> เอกสารนี้คือ **จุดเริ่มต้น (entry point)** สำหรับใครก็ตาม (รวมถึง AI agent ตัวอื่น) ที่จะเข้ามาอ่านงานวิเคราะห์ระบบ AJT New Sale Incentive ทั้งหมด
> อ่านไฟล์นี้ให้จบก่อนเปิดไฟล์อื่น แล้วคุณจะรู้ว่า "ข้อมูลอะไรอยู่ที่ไหน อ่านอย่างไร และเชื่อถือได้แค่ไหน"

---

## 0. TL;DR สำหรับ AI Agent (อ่าน 30 วินาที)

- โปรเจกต์นี้ถอดตรรกะการคำนวณ **Sales Incentive** จากไฟล์ Excel 2 ไฟล์ (MT, TT) ออกมาเป็นเอกสาร เพื่อนำไปออกแบบ/พัฒนาระบบใหม่
- **ข้อมูลดิบ extract ครบ 100% แล้ว** → อยู่ใน `01.Raw-Extracts/{MT,TT}/` เป็น CSV (ไม่ต้องเปิด .xlsx เอง)
- ทุก sheet มี 2 ไฟล์: `*.values.csv` (ค่าที่เห็นในเซลล์) และ `*.formulas.csv` (สูตรดิบ — มีเฉพาะ sheet ที่มีสูตร)
- **ลำดับการอ่านที่แนะนำ:** README นี้ → `03.Calculation-Logic/00_*.md` (ตรรกะหลัก) → `05.Process-Flow/01_*.md` (ภาพไหลข้อมูล) → เจาะ raw CSV เฉพาะจุดที่ต้องยืนยัน
- เอกสารใช้งานจริงที่มีแล้วเพิ่มเติม: `06_Sales-Incentive-Guide-Explanation.md` และ `Checklist_SA-Analysis-Completion_*.md`
- ⚠️ **อย่าเชื่อ 100% โดยไม่ตรวจสอบ:** เอกสารวิเคราะห์บางส่วนยังไม่เสร็จ และมีคำถามค้างกับ Business — ดู §6 "สถานะความน่าเชื่อถือ"
- ⚠️ ไฟล์ Excel ต้นฉบับเป็น **ไฟล์ทดสอบ ("For Test")** มีข้อมูลจริงเพียง ~6 เดือน (Apr–Sep) และมี sheet sandbox (`Test`) ที่มี `#REF!` — อย่าใช้เป็นความจริงเชิง production

---

## 1. ไฟล์ต้นฉบับที่วิเคราะห์

| ช่องทาง | ไฟล์ต้นฉบับ (ใน `1.General Documents`) | หลักการคิด Incentive |
|---------|------------------------------------------|----------------------|
| **MT** (Modern Trade) | `For Test_New Sales Incentive Scheme All Product_New formula_MT.xlsx` | คิดแบบ **Product Group** — salesman 1 คนดูแลหลาย product group; มี Cascade 4 ระดับ |
| **TT** (Traditional Trade) | `For Test_Pain_New Sales Incentive Scheme All Product_New formula_TT.xlsx` | คิดแบบ **SKU/สินค้า** ตามยอด salesman เอง; รวมคำนวณใน sheet เดียว |

> ⚠️ ไม่แก้ไขไฟล์ต้นฉบับ — งานทั้งหมดทำบนข้อมูลที่ extract แล้วใน `01.Raw-Extracts`

---

## 2. โครงสร้างโฟลเดอร์ (อ่านตามลำดับเลข)

| โฟลเดอร์ | คือ | สถานะ | ใช้เมื่อ |
|----------|-----|-------|---------|
| `00.Extraction-Tools/` | สคริปต์ `Extract-Xlsx.ps1` แตก .xlsx → CSV (ใช้แค่ .NET ใน PowerShell ไม่ต้องมี Excel/Python) | ✅ 100% | ต้องการ extract ซ้ำ/ไฟล์ใหม่ |
| `01.Raw-Extracts/{MT,TT}/` | **ข้อมูลดิบ** ราย sheet เป็น CSV + `_INDEX.md` | ✅ 100% | ต้องการความจริงระดับเซลล์/สูตร |
| `02.Sheet-Understanding/{MT,TT}/` | บันทึกความเข้าใจราย sheet (sheet นี้ทำอะไร input/output สูตร) | 🟡 ~30% | อยากเข้าใจ sheet ทีละตัว |
| `03.Calculation-Logic/` | **สรุปตรรกะการคำนวณทั้ง flow** (achievement, GOAL, cascade, shortage, fix rate, output) | 🟢 ~85% | **อ่านที่นี่ก่อนเพื่อเข้าใจภาพรวมสูตร** |
| `04.Data-Dictionary/` | นิยาม field, mapping รหัสสินค้า MT↔TT↔master | 🟡 ~40% | ต้องการความหมายของรหัส/field |
| `05.Process-Flow/` | Data Flow Diagram (Mermaid) + dependency ข้าม sheet | 🟢 ~80% | อยากเห็นภาพการไหลข้อมูล |
| `database design/` | โฟลเดอร์รวมงานออกแบบฐานข้อมูล (logical/physical model, mapping, review notes) | 🟢 100% (โครงสร้างพร้อมใช้งาน) | ต้องการดู/ส่งมอบงานออกแบบฐานข้อมูล |
| `06_Sales-Incentive-Guide-Explanation.md` | คำอธิบายเชิงปฏิบัติของ Guide รายเดือน (control point, checklist) | 🟢 100% | อยากเข้าใจ workflow ผู้ปฏิบัติงาน |
| `Checklist_SA-Analysis-Completion_*.md` | เช็กลิสต์ + % ความคืบหน้างาน SA | 🟢 100% | อยากรู้ว่าอะไรเสร็จ/ค้าง |

> เอกสารผลลัพธ์ขั้นถัดไป (BRD/SRS) อยู่นอกโฟลเดอร์นี้ที่ `5.Docs/BRD-SRS_*.md`

### 2.1 ความเชื่อมโยงกับงาน Database Design

โฟลเดอร์หลัก:

- `database design/`

ไฟล์ที่เกี่ยวข้อง (อยู่โฟลเดอร์ข้างเคียง `environment/`):

- `../environment/AJT_SIS_Database_Design_v1.0_2026-06-13.docx` (เอกสารออกแบบฐานข้อมูลที่สร้างแล้ว)
- `../environment/generate_db_design_doc.ps1` (สคริปต์สร้างเอกสาร)
- `../environment/ddl/01_ajt_sis_poc_master_tables.sql` (DDL master tables)
- `../environment/ddl/02_ajt_sis_poc_seed_data.sql` (seed data)
- `../environment/ddl/00_discovery_schema_check.sql` (schema discovery/check)
- `../environment/database-dev.env` (ค่าการเชื่อมต่อ dev)

แนวทางจัดเก็บ:

- เอกสารวิเคราะห์/ตัดสินใจ/สรุปแบบจำลอง ให้เก็บใน `database design/`
- สคริปต์ที่รันจริงและ artifact ที่ generate ให้คงไว้ใน `environment/` แล้วอ้างอิงข้ามกัน

---

## 3. ตรรกะการอ่าน Raw Extracts (สำคัญที่สุดสำหรับ AI Agent)

### 3.1 convention ของไฟล์ CSV
- **`NN_<ชื่อ sheet>.values.csv`** — ค่าที่แสดงผล (resolve shared string เป็นข้อความแล้ว); แถวแรกมักเป็น header แต่ **ไม่เสมอไป** (บาง sheet มีหัวตารางหลายชั้น/แถวว่างคั่น)
- **`NN_<ชื่อ sheet>.formulas.csv`** — รูปแบบ 2 คอลัมน์: `Cell, Formula` (เช่น `BN2,"=SUMIFS(...)"`); มีเฉพาะเซลล์ที่มีสูตร เซลล์ที่เป็นค่าคงที่จะไม่ปรากฏ
- เซลล์สูตรที่ขึ้นต้น `_xlfn.` คือฟังก์ชันใหม่ของ Excel (เช่น `_xlfn.XLOOKUP`) — อ่านเป็น `XLOOKUP` ปกติ
- encoding = **UTF-8** (มีภาษาไทย); `NN` คือลำดับ sheet ตรงกับ `_INDEX.md`

### 3.2 วิธีอ่านคู่ values + formulas (กฎทอง)
> **สูตรอยู่ใน `.formulas.csv` / ผลลัพธ์อยู่ใน `.values.csv` ที่ตำแหน่งเซลล์เดียวกัน**
> เช่น อยากรู้ว่า `BN2` คำนวณอะไรและได้เท่าไร → เปิด `formulas.csv` หา `BN2,` (ดูสูตร) แล้วเปิด `values.csv` ไปที่คอลัมน์ BN แถว 2 (ดูค่า)

### 3.3 รูปแบบ layout ที่พบซ้ำในทุก sheet คำนวณ (calc sheets)
sheet คำนวณ (`Target & Cal*`, `Aji Plus`, `RDQ`, `RDM`, `RDNS`) ใช้โครงสร้าง **"บล็อก 12 เดือน คั่นด้วยคอลัมน์ว่าง"** เรียงซ้าย→ขวา:

```
[A–D: keys]  [Target ×12 เดือน]  ▯  [Actual ×12]  ▯  [achievement ดิบ ×12]  ▯  [ROUND(ach,4) ×12]  ▯  [payout ×12]  [SUM]
```
- เดือนเรียง **Apr → Mar** (ปีงบเริ่มเมษายน)
- คอลัมน์ว่าง (▯) ใช้คั่นบล็อก — อย่าตีความว่าข้อมูลขาด
- คอลัมน์ payout/incentive รวมมักอยู่ท้าย (เช่น `col BN` ใน Target & Cal, `col BQ` = SUM ใน sheet GD)
- key ของแต่ละแถว = Salesman/Product/Team (ดูรายละเอียดใน `03.Calculation-Logic`)

### 3.4 สูตรแกนหลักที่ต้องจำ (ยืนยันแล้ว)
```
achievement = ROUND(Actual / Target, 4)                         ราย product
ถ้า Shortage flag → achievement = 1.0 (บังคับ)
GOAL  = XLOOKUP(achievement, threshold_row, goal_row, mode 1)   step-down (floor 0.90, cap 1.30)
incentive_product = base × GOAL × weight   (หรือ VLOOKUP payout table)
Cascade (MT) = SUMIFS Target+Actual จากระดับล่าง แล้ว "คำนวณใหม่" ทุกระดับ (ไม่ใช่บวก incentive)
For HR payout = MAX(floor, Σ incentive ทุกระดับ P+Q+R+S)
```
รายละเอียดเต็ม + เลขเซลล์อ้างอิง: [03.Calculation-Logic/00_สรุปตรรกะการคำนวณ_ตั้งต้น.md](03.Calculation-Logic/00_%E0%B8%AA%E0%B8%A3%E0%B8%B8%E0%B8%9B%E0%B8%95%E0%B8%A3%E0%B8%A3%E0%B8%81%E0%B8%B0%E0%B8%81%E0%B8%B2%E0%B8%A3%E0%B8%84%E0%B8%B3%E0%B8%99%E0%B8%A7%E0%B8%93_%E0%B8%95%E0%B8%B1%E0%B9%89%E0%B8%87%E0%B8%95%E0%B9%89%E0%B8%99.md)

---

## 4. แผนที่ sheet → ความหมาย (ทางลัดก่อนเปิด CSV)

| sheet | บทบาท | MT | TT |
|-------|-------|----|----|
| `Guide` | คู่มือ workflow รายปี/เดือน/as-needed | ✅ | ไม่มี (ใช้ logic เดียวกัน) |
| `M_Month`, `Period` | M_Month ใช้ map เดือนยอดขายไปเดือนจ่าย, Period ใช้กำหนดเดือนที่คำนวณ | ✅ | ✅ |
| `Top WS`, ` WS SF`, `WS WH`, `SF WH` | **ตารางพารามิเตอร์ตัวจริง** — incentive base ตามตำแหน่ง + น้ำหนักสินค้า + ตาราง payout | ✅ | ✅ |
| `2) หลักการคำนวน Table` | มุมมองสรุป (ดึงค่าจาก WS sheets) + ตาราง GOAL/threshold | ✅ | ✅ |
| `T_SectAbove` | อัตราตามระดับตำแหน่ง | ✅ | ✅ |
| `Product` | master สินค้า 11 ตัว | ✅ | ✅ |
| `Mapping` | แตกบัญชี BI → product group → salesman | ✅ | **ไม่มี** |
| `Actual` | ยอดขายจริงจาก BI | ✅ | ✅ |
| `ASTBase` | โครงสร้างองค์กร (สายบังคับบัญชา) | ✅ | ✅ |
| `HR Rep` | ข้อมูลพนักงานจาก HCM | ✅ | ✅ |
| `3)Target & Cal*` | **หัวใจการคำนวณ** | แยก 4 ระดับ `_Staff/_Sect/_Dept/_AD` | รวม 1 sheet |
| `Shortage` | ธงสินค้าขาด → บังคับ achievement=1.0 | ✅ | ✅ |
| `ค่าตอบแทนการขายในอัตราคงที่` | Fix Rate ราย Job Function | ✅ | (ใช้ For HR (AD)) |
| `Aji Plus / RDQ / RDM / RDNS` (+`Actual_*`) | **Special Product Incentive (GD)** — scheme คำนวณแยกของสินค้า G2 | ✅ | ✅ |
| `1) For HR` (+`(FIX)` / `(AD)`) | **ผลลัพธ์จ่ายรายคน** ส่ง HR | ✅ | ✅ |
| `Test` | sandbox ทดสอบสูตร (มี `#REF!`, "MR.X") — **ไม่ใช่ข้อมูลจริง** | ⚠️ | ⚠️ |
| `Sales Target` | **ว่างเปล่า (0×0)** ในไฟล์ทดสอบ — บทบาทยังไม่ทราบ | ⚠️ ว่าง | ⚠️ ว่าง |

---

## 5. วิธี extract ซ้ำ (ถ้าได้ไฟล์ .xlsx ใหม่)

เปิด PowerShell ที่ `00.Extraction-Tools/` แล้วรัน (ทำทั้ง MT และ TT):
```powershell
.\Extract-Xlsx.ps1 `
  -XlsxPath "..\..\1.General Documents\For Test_New Sales Incentive Scheme All Product_New formula_MT.xlsx" `
  -OutDir   "..\01.Raw-Extracts\MT"
```
ผลลัพธ์ต่อ sheet: `NN_<sheet>.values.csv`, `NN_<sheet>.formulas.csv` (ถ้ามีสูตร), และ `_INDEX.md`
> สคริปต์อ่าน .xlsx เป็น zip → parse `sharedStrings.xml` + worksheet XML โดยตรง จึง **reproducible** ไม่ต้องมี Excel ติดตั้ง

---

## 6. สถานะความน่าเชื่อถือ & สิ่งที่ยังไม่ปิด (ต้องอ่านก่อนนำไปใช้)

**ยืนยันจากสูตรจริงแล้ว ✅:** achievement, GOAL lookup, Cascade (SUMIFS), Shortage override, Fix Rate, For HR output, GD calculation, product mapping 11 ตัว
**เอกสารประกอบ workflow ที่ใช้งานได้แล้ว:** `06_Sales-Incentive-Guide-Explanation.md`, `Checklist_SA-Analysis-Completion_2026-06-13.md`

**ยังเป็นคำถามค้าง ❓ (ต้องยืนยันกับ Business — อย่าเดา):**
1. policy จุด achievement 108% → ตัวคูณ 1.06 (ไม่ใช่ 1.08)
2. เงื่อนไขใช้ EXTRA / Special KPI / Option1 (พบตารางแต่ยังไม่พบสูตรใช้งานจริง)
3. เงื่อนไขเลือก Incentive Base **Old vs New**
4. รหัส MT 4 ตัวที่ยังไม่ map: `AJA, AMV, FP, QM` (+ เหตุผลตัด 7 รหัส BI ออก)
5. บทบาท `Sales Target` (sheet ว่างในไฟล์ทดสอบ)
6. scope/policy ของ Laos Dept ใน TT `For HR (AD)`
7. **Special Product Incentive (GD):** จ่ายอย่างไร (รวม For HR หรือแยก), คิดซ้ำซ้อนกับ weight G2 หรือไม่, ทำไมยังไม่ wire เข้า For HR — ดู [02.Sheet-Understanding/MT/11_Special-Product-Incentive](02.Sheet-Understanding/MT/11_Special-Product-Incentive_AjiPlus-RDQ-RDM-RDNS.md)

> รายการเต็ม + สถานะ: ดู `03.Calculation-Logic/00_*.md §5` และ `5.Docs/BRD-SRS_*.md §16`

---

## 7. ลำดับการทำงานเดิมของทีม SA (อ้างอิง)
1. รัน `Extract-Xlsx.ps1` ทั้ง MT/TT → `01.Raw-Extracts`
2. ไล่อ่าน `_INDEX.md` เห็นภาพรวมทุก sheet
3. บันทึกความเข้าใจราย sheet → `02.Sheet-Understanding`
4. รวบยอดตรรกะ → `03.Calculation-Logic`, field/รหัส → `04.Data-Dictionary`
5. วาด flow → `05.Process-Flow`
6. สังเคราะห์เป็น BRD/SRS → `5.Docs`
