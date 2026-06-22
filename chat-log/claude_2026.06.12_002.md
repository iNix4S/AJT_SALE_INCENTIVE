# Chat Log

Date: 2026-06-12
File: claude_2026.06.12_002.md
Session: ต่อจาก claude_2026.06.12_001.md

---

## บริบทเริ่มต้น (Context Handoff)

Session นี้เริ่มต้นจาก conversation summary ของ session ก่อนหน้า ซึ่งสรุปสิ่งที่ทำเสร็จแล้ว:
- ✅ Extract-Xlsx.ps1 (PowerShell script อ่าน xlsx)
- ✅ Raw extracts: MT 32 sheets / TT 26 sheets
- ✅ 04.Data-Dictionary/01_Product-Code-Mapping.md
- ✅ 03.Calculation-Logic/00_สรุปตรรกะการคำนวณ_ตั้งต้น.md (Draft v0.2)
- 🟡 02.Sheet-Understanding: ยังไม่ได้เริ่ม (~5%)
- 🔴 05.Process-Flow: มีแค่ README.md ว่างเปล่า

AI ได้รับ session summary และยืนยัน todos ที่เสร็จในรอบก่อนทันที

---

## Turn 1 — ตรวจสอบสถานะ 02.Sheet-Understanding

**User:** ถามว่า 02.Sheet-Understanding ยังทำไม่เสร็จหรือไม่

**AI Actions:**
1. `list_dir` → `4.System Analyst and Design/02.Sheet-Understanding/`
   - พบ: MT/ (ว่าง), TT/ (ว่าง), _TEMPLATE.md เท่านั้น
2. ยืนยันกลับว่า **ยังไม่ได้เริ่มเลย** (0%) — มีแค่ template

**ผลลัพธ์:**  
AI เสนอ 3 ตัวเลือก:
1. ทำครบทุก sheet (58 sheets)
2. ทำเฉพาะ sheet สำคัญ (~10 sheets)
3. ทำ 05.Process-Flow ก่อน

---

## Turn 2 — User เลือก option 2+3 พร้อมกัน

**User:** เลือกทั้งสองข้อ — ทำ 05.Process-Flow ก่อน แล้วค่อยทำ 02.Sheet-Understanding sheet สำคัญ

**AI Planning:**
- สร้าง todo list: (1) Process-Flow, (2) Sheet-Understanding MT, (3) Sheet-Understanding TT
- อ่าน template, README, raw extracts ก่อนเริ่มสร้าง

---

## Turn 3 — สร้าง 05.Process-Flow

**AI Actions:**

1. อ่านไฟล์หลายไฟล์พร้อมกัน (parallel):
   - `05.Process-Flow/README.md` — เข้าใจ scope
   - `01.Raw-Extracts/MT/_INDEX.md` — ดู list ทุก sheet
   - `02.Sheet-Understanding/_TEMPLATE.md` — ดู format
   - `MT/11_ASTBase.values.csv` — org hierarchy columns
   - `MT/18_Actual.values.csv` — actual data columns
   - `MT/17_HR Rep.values.csv` — HR data columns

2. อ่านเพิ่มเติม:
   - `MT/19_Mapping.values.csv` — mapping structure
   - `MT/10_Period.values.csv` — period columns
   - `MT/20_1) For HR.values.csv` — output columns
   - `MT/06_Guide.values.csv` — step-by-step workflow
   - `MT/13_3)Target & Cal_Staff.values.csv` — main calc columns

3. **สร้างไฟล์:** `05.Process-Flow/01_Data-Flow-Diagram.md`

**เนื้อหาไฟล์ที่สร้าง:**

| Section | รายละเอียด |
|---------|-----------|
| §1 MT Data Flow | Mermaid flowchart TD — External → Master → Input → Target & Cal (cascade 4 ระดับ) → Output → HR Payment |
| §2 TT Data Flow | Mermaid flowchart TD — เหมือน MT แต่ไม่มี Mapping, Target & Cal เป็น 1 sheet |
| §3 ตาราง MT vs TT | เปรียบเทียบ 5 ด้าน: mapping, structure, output, unit, Guide |
| §4 Sequence Diagram | Annually / Monthly / As-needed workflow ตาม Guide sheet |
| §5 Dependency Chain | Mermaid LR — sheet-to-sheet dependency สรุปสั้น |
| §6 หมายเหตุ | 3 ❓ ค้างคา: Aji Plus flow, Sales Target role, T_SectAbove ใน TT |

**Key insights ที่บันทึกใน diagram:**
- MT: BI SalesCode → Mapping → Salesman Code (1 account หลาย salesman)
- TT: BI SalesmanCode ตรงกับ Salesman Code เลย (ไม่มี Mapping)
- Cascade MT: Staff → SUMIFS → Sect → SUMIFS → Dept → SUMIFS → AD (แยก 4 sheets)
- TT: Target & Cal 1 sheet — For HR ดึงทุกระดับเอง

---

## Turn 4 — สร้าง 02.Sheet-Understanding MT (10 sheets)

**AI Actions:**  
อ่านข้อมูลเพิ่มเติมก่อนเขียน:
- `MT/01_Top WS.values.csv` + `.formulas.csv` — incentive base + GOAL table
- `MT/12_2) หลักการคำนวน Table.values.csv` + `.formulas.csv` — product weights
- `MT/13_3)Target & Cal_Staff.formulas.csv` (rows 4+) — สูตร achievement + shortage
- `MT/20_1) For HR.formulas.csv` — สูตร K2 (MAX floor)
- `MT/19_Mapping.formulas.csv` — สูตร composite key

**สร้างไฟล์ MT 10 ไฟล์:**

### 02.Sheet-Understanding/MT/01_Guide.md
- ประเภท: Reference/Documentation
- สรุปตาราง workflow 3 ช่วง (Annually/Monthly/As-needed) จาก Guide sheet จริง
- หมายเหตุ: "คอลัมน์เหลือง" = คอลัมน์ที่มีสูตร (ต้อง copy)

### 02.Sheet-Understanding/MT/02_Top-WS.md
- ประเภท: Master Data / Parameter
- เก็บ: Incentive Base ตามตำแหน่ง, GOAL bracket table, Product weights (G1/G2/G3)
- สูตร: `J1 = $H$4+($H$4*J3)` — GOAL value = base × (1 + multiplier)
- ❓ Row 2 Top WS ระบุ 1.08 แต่ Table sheet ระบุ 1.06 — ยังไม่ชัด

### 02.Sheet-Understanding/MT/03_Period.md
- ประเภท: Parameter / Input
- เล็กมาก (2 แถว x 4 คอลัมน์) แต่สำคัญมาก
- คอลัมน์: sales incentive ของเดือน (date serial), รอบ Variable, รอบ Fixed, Default column
- ตัวอย่าง: 46113 = Dec 2025, 46174 = Feb 2026, 46143 = Jan 2026
- ❓ "Default column = 1" หมายความว่าอะไร?

### 02.Sheet-Understanding/MT/04_Table-หลักการคำนวน.md
- ประเภท: Master Data / Calculation Parameter
- 1 row = 1 Salesman
- คอลัมน์: Team Code, Base, GOAL brackets (9 ระดับ), Product weights (15 products)
- สูตร: `C4 = ($B4 * C$2)` — incentive amount = Base × weight
- ตัวอย่าง Team 222208: Base 5,000, products AJ=3%, RD=5%, BD=10%...
- ❓ 1.08 vs 1.06 ยังค้างคา

### 02.Sheet-Understanding/MT/05_Actual.md
- ประเภท: Input (จาก BI/DWC)
- ไม่มีสูตร — raw data ล้วน
- โครงสร้าง: SalesmanCode, Merge (code+product), Salesman BI, Product Group, Apr–Mar (ยอดขาย)
- ปีงบประมาณ = Apr–Mar
- ❓ BI export format? / ❓ floating point เช่น 54158.999... (ควร ROUND ใน import)

### 02.Sheet-Understanding/MT/06_Mapping.md
- ประเภท: Reference / Mapping (MT เท่านั้น)
- สูตร: `C2 = A2 & B2` — composite key = BI SalesCode + ProductGroup
- ตัวอย่าง: บัญชี 1190064712 → 3 Salesman ดูแล (AJ/AJP/YY/RKR=711, RDC/RM/ND/RD=705, BD=714)
- ❓ ถ้า Salesman ลาออก/โอน กระทบ Mapping อย่างไร?

### 02.Sheet-Understanding/MT/07_ASTBase.md
- ประเภท: Master Data / Org Hierarchy
- 18 คอลัมน์: Month, Year, Area, Depot, Salesman Code, รหัสพนักงาน, ชื่อ, ..., DirectSupCode (Q), DeptMgrCode (R), DivMgrCode (S)
- ตัวอย่าง hierarchy: 222222 (Div) → 222234 (Dept) → 222208 (Sup) → 222209 (Staff)
- ❓ คอลัมน์เหลือง = Q-S หรือไม่?

### 02.Sheet-Understanding/MT/08_HR-Rep.md
- ประเภท: Master Data / HR Input (จาก HCM)
- 28 คอลัมน์ — ข้อมูลพนักงาน: EmpID, JobTitle, Position, JobGrade, CostCentre, JobFunction, DirectSup
- **Job Function** = ตัวกำหนด Fixed Rate incentive
- ❓ พนักงานลาออกกลางปี — ยังอยู่ใน HR Rep ไหม?

### 02.Sheet-Understanding/MT/09_Target-Cal-Staff.md
- ประเภท: Calculation (หลัก) — 65+ คอลัมน์
- 1 row = 1 Salesman × 1 Product Group
- กลุ่มคอลัมน์: A=DirectSupCode, B=Product, C=Team, D–O=Target, P–AA=Actual, AB–AM=%raw, AN–AY=%ROUND+Shortage, AZ–BM=Incentive brackets, BN=**Incentive เดือนปัจจุบัน**, BO=EmpCode, BP=Incentive repeat
- สูตร achievement: `IFERROR(IF(VLOOKUP($B4,Shortage!$A:$M,col,FALSE)="Shortage",1, IFERROR(ROUND(Q4/E4,4),0)),IFERROR(ROUND(Q4/E4,4),0))`
- สูตร incentive: XLOOKUP(achievement, GOAL thresholds, amounts, mode=step-down)
- ❓ Target D–O มาจาก manual หรือ Sales Target sheet?

### 02.Sheet-Understanding/MT/10_For-HR.md
- ประเภท: Output (ส่งให้ HR)
- 1 row = 1 พนักงาน
- สูตรหลัก: `K2 = IF(ROUND(P2+Q2+R2+S2,2)<O2, O2, ROUND(P2+Q2+R2+S2,2))`
- P=Staff incentive, Q=Sect, R=Dept, S=AD (ทั้งหมด SUMIFS จาก Target & Cal col BN)
- ❓ Floor (col O) มาจากไหน?

---

## Turn 5 — สร้าง 02.Sheet-Understanding TT (3 sheets)

**AI Actions:**  
อ่านข้อมูล TT:
- `TT/11_3)Target & Cal.values.csv` — โครงสร้างเหมือน MT Staff แต่ DirectSupCode อยู่ท้าย
- `TT/15_1) For HR.values.csv` — แสดง % และ amount แยกทุกระดับ
- `TT/16_1) For HR (AD).values.csv` — แสดง AD + Laos Dept column พิเศษ

**สร้างไฟล์ TT 3 ไฟล์:**

### 02.Sheet-Understanding/TT/01_Target-Cal.md
- ประเภท: Calculation (หลัก) — 1 sheet รวมทุกระดับ (ต่างจาก MT 4 sheets)
- 1 row = 1 SalesmanCode × 1 Product (TT codes: A/R/B/AP/M/Q/NS/Y/P/T/RK)
- col C "Team" = "Top WS" ทุกแถว — ❓ หมายความว่าอะไร?
- ตาราง mapping TT code ↔ MT code ↔ ชื่อสินค้า (11 products)
- ❓ TT incentive ราคาต่ำกว่า MT — ตั้งใจหรือ test data?

### 02.Sheet-Understanding/TT/02_For-HR.md
- ประเภท: Output (24 คอลัมน์ — มากกว่า MT)
- แสดง breakdown ทุกระดับในชีตเดียว: Salesman(P), %DirectSup(Q), DirectSup(R), DeptMgr(S/T/U), DivMgr(V/W/X)
- Pattern การรับ incentive:
  - Staff/Supervisor → col P ≠ 0, col R = 0
  - Section Manager → col P = 0, col R ≠ 0 (incentive เป็น % ของทีม)
- ❓ col Q %Direct Superior = achievement รวมของทีมหรือ? ต้องยืนยัน

### 02.Sheet-Understanding/TT/03_For-HR-AD.md
- ประเภท: Output (ระดับ AD แยกต่างหาก)
- มีคอลัมน์พิเศษ: %AD, AD amount, **Laos Dept** amount
- มีเพียง 1 แถวข้อมูล (EmpID 000001, TT AD inc. Laos, 6,447.56 บาท)
- ❓ "Laos Dept" = territory ลาวแยกต่างหาก — ต้องยืนยัน scope
- ❓ ทำไม TT แยก AD ออกมา sheet ต่างหาก?

---

## สรุปไฟล์ที่สร้างในครั้งนี้

| ไฟล์ | ประเภท | สถานะ |
|------|-------|-------|
| `05.Process-Flow/01_Data-Flow-Diagram.md` | Mermaid diagram 5 sections | ✅ Draft v0.1 |
| `02.Sheet-Understanding/MT/01_Guide.md` | Sheet analysis | ✅ |
| `02.Sheet-Understanding/MT/02_Top-WS.md` | Sheet analysis | ✅ |
| `02.Sheet-Understanding/MT/03_Period.md` | Sheet analysis | ✅ |
| `02.Sheet-Understanding/MT/04_Table-หลักการคำนวน.md` | Sheet analysis | ✅ |
| `02.Sheet-Understanding/MT/05_Actual.md` | Sheet analysis | ✅ |
| `02.Sheet-Understanding/MT/06_Mapping.md` | Sheet analysis | ✅ |
| `02.Sheet-Understanding/MT/07_ASTBase.md` | Sheet analysis | ✅ |
| `02.Sheet-Understanding/MT/08_HR-Rep.md` | Sheet analysis | ✅ |
| `02.Sheet-Understanding/MT/09_Target-Cal-Staff.md` | Sheet analysis | ✅ |
| `02.Sheet-Understanding/MT/10_For-HR.md` | Sheet analysis | ✅ |
| `02.Sheet-Understanding/TT/01_Target-Cal.md` | Sheet analysis | ✅ |
| `02.Sheet-Understanding/TT/02_For-HR.md` | Sheet analysis | ✅ |
| `02.Sheet-Understanding/TT/03_For-HR-AD.md` | Sheet analysis | ✅ |

---

## คำถามค้างคา (❓) จาก Session นี้

| # | ประเด็น | Sheet ที่เกี่ยวข้อง |
|---|---------|------------------|
| 1 | "คอลัมน์เหลือง" ใน ASTBase และ HR Rep คือคอลัมน์ใดบ้าง? | ASTBase, HR Rep |
| 2 | "Default column = 1" ใน Period หมายความว่าอะไร? | Period |
| 3 | Target (col D–O) ใน Target & Cal มาจาก manual หรือ Sales Target sheet? | Target & Cal_Staff |
| 4 | col Q "%Direct Superior" ใน TT For HR = achievement รวม หรือ multiplier? | TT 1) For HR |
| 5 | "Top WS" ใน col C ของ TT Target & Cal หมายความว่าอะไร? | TT 3)Target & Cal |
| 6 | TT incentive ต่ำกว่า MT — ตั้งใจหรือ test data? | TT 3)Target & Cal |
| 7 | Laos Dept ใน TT For HR (AD) = territory ลาวจริงหรือ? | TT 1) For HR (AD) |
| 8 | ทำไม TT แยก AD ออกมาเป็น sheet ต่างหาก? | TT structure |
| 9 | Aji Plus/RDQ/RDM/RDNS sheets — flow ต่างจาก main products อย่างไร? | MT special products |
| 10 | Sales Target sheet — บทบาทใน flow ยังไม่ชัด | MT/TT |
| (ค้างจาก session ก่อน) 1.08 vs 1.06 ใน GOAL table | Top WS, Table |
| (ค้างจาก session ก่อน) EXTRA/Special KPI ใช้เมื่อใด | Top WS, Table |
| (ค้างจาก session ก่อน) Old vs New base เลือกอย่างไร | Top WS |
| (ค้างจาก session ก่อน) 4 MT codes: AJA, AMV, FP, QM = product อะไร | Product mapping |

---

## สถานะโครงการ ณ สิ้น Session นี้

| ส่วนงาน | % สมบูรณ์ | หมายเหตุ |
|---------|----------|----------|
| 01.Raw-Extracts | ✅ 100% | MT 32 + TT 26 sheets |
| 02.Sheet-Understanding | 🟡 ~40% | MT 10 sheets + TT 3 sheets ที่สำคัญ; ยังขาด Shortage, AjiPlus/RDQ/RDM/RDNS, Sales Target, WS SF/WH |
| 03.Calculation-Logic | ✅ ~85% | Draft v0.2; ค้าง 3 ❓ business |
| 04.Data-Dictionary | 🟡 ~40% | Product codes done; ขาด field dictionary |
| 05.Process-Flow | ✅ ~80% | Draft v0.1; ขาด Aji Plus flow + Sales Target role |

---

## Next Steps แนะนำ

1. **ถามลูกค้า/Business** เพื่อปิด ❓ ค้างคา (ข้อ 1.08 vs 1.06, EXTRA/Special KPI, Old vs New base, Laos Dept)
2. **วิเคราะห์ Aji Plus/RDQ/RDM/RDNS sheets** — เข้าใจ flow พิเศษ แล้ว update Process-Flow
3. **ขยาย 04.Data-Dictionary** — เพิ่ม field dictionary ของ Target & Cal, For HR
4. **สร้าง BRD / Scope Statement** — นำข้อมูลที่รวบรวมมาทั้งหมดสรุปเป็นเอกสาร SA พร้อมนำเสนอ
