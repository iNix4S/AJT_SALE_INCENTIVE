# 01. Data Flow Diagram — AJT Sale Incentive (MT & TT)

**เวอร์ชัน:** Draft v0.1  
**วันที่:** 2026-06-12  
**อ้างอิงจาก:** Guide sheet (MT), Raw Extracts MT/TT, 03.Calculation-Logic v0.2

---

## 1. ภาพรวม Data Flow (MT)

```mermaid
flowchart TD
    subgraph EXT["ระบบภายนอก (External Sources)"]
        BI["BI / DWC\n(ยอดขายรายเดือน\nตาม SalesCode + ProductGroup)"]
        HCM["HCM System\nPersonal Employment Report\n(ข้อมูลพนักงาน)"]
    end

    subgraph MASTER["Master / Reference Sheets (ตั้งค่า)"]
        PERIOD["Period\n(กำหนดเดือนที่คำนวณ)"]
        MMONTH["M_Month\n(map เดือนยอดขาย\nไปเดือนจ่าย Incentive)"]
        TABLE["2) หลักการคำนวน Table\n(อัตรา incentive ตาม WS type\nและ Product weight)"]
        TSECT["T_SectAbove\n(อัตราค่าตอบแทนตาม\nตำแหน่ง/ระดับ)"]
        SHORTAGE["Shortage\n(ระบุ product+month\nที่ได้ achievement = 100%)"]
    end

    subgraph INPUT["Input Sheets (นำเข้าข้อมูลรายเดือน)"]
        ACTUAL["Actual\n(copy จาก BI\nSalesmanCode+ProductGroup\n+ยอดขายรายเดือน)"]
        ASTBASE["ASTBase\n(โครงสร้างองค์กร\nSalesman→DirectSup\n→DeptMgr→DivMgr)"]
        HRREP["HR Rep\n(ข้อมูลพนักงาน\nจาก HCM: EmpID, JobGrade,\nPosition, JobFunction)"]
        MAPPING["Mapping (MT เท่านั้น)\n(BI SalesCode + ProductGroup\n→ Salesman Code)"]
    end

    subgraph TARGET["Target & Calculation (Cascade 4 ระดับ)"]
        TSTAFF["3) Target & Cal_Staff\n(คำนวณ incentive\nระดับ Salesman / Staff)"]
        TSECT["3) Target & Cal_Sect\n(SUMIFS Target+Actual\nระดับ Section Manager)"]
        TDEPT["3) Target & Cal_Dept\n(SUMIFS Target+Actual\nระดับ Dept Manager)"]
        TAD["3) Target & Cal_AD\n(SUMIFS Target+Actual\nระดับ AD)"]
    end

    subgraph OUTPUT["Output Sheets (ส่งให้ HR)"]
        FORHR["1) For HR\n(Variable incentive\nรายพนักงาน ทุกระดับ)"]
        FORHRFIX["1) For HR (FIX)\n(Fixed rate incentive\nตาม Job Function)"]
    end

    subgraph HR_PROC["กระบวนการ HR"]
        HR_PAY["HR Payment Processing\n(นำข้อมูลไปจ่าย Incentive)"]
    end

    %% External → Input
    BI -->|"Download & paste\nรายเดือน"| ACTUAL
    HCM -->|"Download & paste\nรายเดือน"| HRREP

    %% Master feeds
    MMONTH -.->|"payment cycle\nทำปีละครั้ง"| PERIOD
    PERIOD -->|"กำหนดเดือนปัจจุบัน"| TSTAFF
    TABLE -->|"อัตรา incentive\nตาม Product+WS type"| TSTAFF
    TSECT -->|"อัตราค่าตอบแทน\nระดับสูง"| TSTAFF
    SHORTAGE -->|"VLOOKUP override\nachievement = 1.0"| TSTAFF

    %% Input → Calculation
    ACTUAL -->|"ยอดขาย Actual\nรายเดือน"| MAPPING
    MAPPING -->|"แปลง BI SalesCode\n→ Salesman Code"| TSTAFF
    ACTUAL -->|"ยอดขาย (ก่อน mapping)"| TSTAFF
    ASTBASE -->|"org hierarchy\nDirectSupCode, DeptMgrCode"| TSTAFF
    ASTBASE -->|"org hierarchy"| TSECT
    ASTBASE -->|"org hierarchy"| TDEPT
    ASTBASE -->|"org hierarchy"| TAD
    HRREP -->|"EmpID, Position,\nJobFunction"| FORHR

    %% Cascade
    TSTAFF -->|"SUMIFS Target+Actual\nจาก Staff ขึ้น Sect"| TSECT
    TSECT -->|"SUMIFS Target+Actual\nจาก Sect ขึ้น Dept"| TDEPT
    TDEPT -->|"SUMIFS Target+Actual\nจาก Dept ขึ้น AD"| TAD

    %% Output
    TSTAFF -->|"SUMIFS col BN\n(Incentive Staff)"| FORHR
    TSECT -->|"SUMIFS col BN\n(Incentive Sect)"| FORHR
    TDEPT -->|"SUMIFS col BN\n(Incentive Dept)"| FORHR
    TAD -->|"SUMIFS col BN\n(Incentive AD)"| FORHR
    FORHR -->|"Variable Incentive"| HR_PAY
    FORHRFIX -->|"Fixed Incentive"| HR_PAY
```

---

## 2. ภาพรวม Data Flow (TT)

```mermaid
flowchart TD
    subgraph EXT["ระบบภายนอก (External Sources)"]
        BI_TT["BI / DWC\n(ยอดขายรายเดือน\nตาม SalesmanCode + SKU)"]
        HCM_TT["HCM System\nPersonal Employment Report"]
    end

    subgraph MASTER_TT["Master / Reference Sheets"]
        PERIOD_TT["Period\n(กำหนดเดือนที่คำนวณ)"]
        TABLE_TT["2) หลักการคำนวน Table\n(อัตรา incentive)"]
        SHORTAGE_TT["Shortage\n(override achievement)"]
    end

    subgraph INPUT_TT["Input Sheets"]
        ACTUAL_TT["Actual\n(copy จาก BI\nSalesmanCode+SKU\n+ยอดขายรายเดือน)"]
        ASTBASE_TT["ASTBase\n(โครงสร้างองค์กร)"]
        HRREP_TT["HR Rep\n(ข้อมูลพนักงาน)"]
    end

    subgraph TARGET_TT["Target & Calculation (1 sheet รวม)"]
        TCAL_TT["3) Target & Cal\n(คำนวณ incentive ทุกระดับ\nในชีตเดียว — ไม่มี cascade แยก)"]
    end

    subgraph OUTPUT_TT["Output Sheets"]
        FORHR_TT["1) For HR\n(Variable incentive)"]
        FORHR_AD_TT["1) For HR (AD)\n(incentive ระดับ AD)"]
    end

    subgraph HR_PROC_TT["กระบวนการ HR"]
        HR_PAY_TT["HR Payment Processing"]
    end

    BI_TT -->|"Download & paste"| ACTUAL_TT
    HCM_TT -->|"Download & paste"| HRREP_TT

    PERIOD_TT -->|"กำหนดเดือน"| TCAL_TT
    TABLE_TT -->|"อัตรา incentive"| TCAL_TT
    SHORTAGE_TT -->|"override achievement"| TCAL_TT

    ACTUAL_TT -->|"ยอดขาย Actual\n(ตาม SKU ไม่ผ่าน Mapping)"| TCAL_TT
    ASTBASE_TT -->|"org hierarchy"| TCAL_TT
    HRREP_TT -->|"EmpID, Position"| FORHR_TT

    TCAL_TT -->|"Incentive"| FORHR_TT
    TCAL_TT -->|"Incentive ระดับ AD"| FORHR_AD_TT
    FORHR_TT -->|"Variable Incentive"| HR_PAY_TT
    FORHR_AD_TT -->|"AD Incentive"| HR_PAY_TT
```

---

## 3. ความต่างหลัก MT vs TT

| ด้าน | MT | TT |
|------|----|----|
| การ map ยอดขาย | BI SalesCode → Salesman ผ่าน **Mapping** sheet (1 บัญชีมีหลาย salesman ตาม product group) | BI SalesmanCode ตรงกับ Salesman Code ได้เลย **ไม่มี Mapping** |
| โครงสร้าง Target & Cal | **4 sheets แยก** Staff / Sect / Dept / AD (cascade) | **1 sheet รวม** ทุกระดับ |
| Output fixed rate | **1) For HR (FIX)** แยกต่างหาก + มี sheet `ค่าตอบแทนการขายในอัตราคงที่` | **1) For HR (AD)** รวมระดับ AD |
| หน่วยการวัด | **Product Group** (เช่น AJ, RD, BD...) | **SKU** (รหัสสินค้าเฉพาะ) |
| Guide sheet | มี (อธิบาย Step-by-Step) | ไม่มี |

---

## 4. ลำดับการทำงานรายเดือน (ตาม Guide MT)

```mermaid
sequenceDiagram
    actor User as ผู้ดูแลระบบ
    participant BI as BI / DWC
    participant HCM as HCM System
    participant XL as Excel File

    Note over User,XL: ทำปีละครั้ง
    User->>XL: กำหนด mapping เดือนยอดขาย → เดือนจ่าย Variable/Fixed ใน M_Month

    Note over User,XL: ทำทุกเดือน (Monthly)
    User->>XL: 1. กำหนดเดือนใน Period sheet
    BI-->>User: 2. Download ยอดขาย
    User->>XL: 2. Paste ข้อมูลลง Actual sheet
    User->>XL: 3. Update ASTBase (org hierarchy) + copy สูตรคอลัมน์เหลือง
    HCM-->>User: 4. Download Personal Employment (Main & Active)_AST
    User->>XL: 4. Update HR Rep sheet + copy สูตรคอลัมน์เหลือง
    User->>XL: 5. กรอก Employee ID ใน For HR + copy สูตรทุกคอลัมน์ (ยกเว้น EmpID และ Payment Method)

    Note over User,XL: ทำเมื่อจำเป็น (As needed)
    User->>XL: ปรับ T_SectAbove (อัตราตามตำแหน่ง)
    User->>XL: ปรับ Table (อัตราตาม Job Function)
    User->>XL: ปรับ Target & Cal (ปรับ target ตาม business)
    User->>XL: ปรับ Shortage (สินค้าขาดแคลน)
```

---

## 5. Sheet Dependency Chain (MT)

```mermaid
flowchart LR
    A[M_Month] --> B[Period]
    C[ASTBase] --> D[HR Rep]
    B --> E[3)Target & Cal_Staff]
    F[Actual + Mapping] --> E
    G[2)Table + T_SectAbove] --> E
    H[Shortage] --> E
    E -->|SUMIFS| I[3)Target & Cal_Sect]
    I -->|SUMIFS| J[3)Target & Cal_Dept]
    J -->|SUMIFS| K[3)Target & Cal_AD]
    D --> L[1) For HR]
    E -->|col BN| L
    I -->|col BN| L
    J -->|col BN| L
    K -->|col BN| L
    L --> M[HR Payment]
    N[ค่าตอบแทนคงที่] --> O[1) For HR FIX]
    O --> M
```

---

## 6. หมายเหตุและคำถามค้างคา

| # | ประเด็น | สถานะ |
|---|---------|-------|
| 1 | Aji Plus / RDQ / RDM / RDNS sheets — มี Actual_* sheets แยก, มี calculation sheets แยก — ยังไม่ชัดว่า flow ต่างจาก main products อย่างไร | ✅ วิเคราะห์แล้ว → [02.Sheet-Understanding/MT/11_Special-Product-Incentive](../02.Sheet-Understanding/MT/11_Special-Product-Incentive_AjiPlus-RDQ-RDM-RDNS.md) — เป็น scheme คำนวณแยกของสินค้า G2 (GD) แต่ **ยังไม่ wire เข้า For HR** (เหลือ Open Q SP-1…SP-6) |
| 2 | Sales Target sheet — บทบาทใน flow ยังไม่ชัด (อาจเป็น input ของ Target & Cal) | ❓ ต้องยืนยัน |
| 3 | T_SectAbove ใน TT — มีอยู่หรือไม่ / ชื่อ sheet ต่างไหม | ❓ ต้องตรวจ |
