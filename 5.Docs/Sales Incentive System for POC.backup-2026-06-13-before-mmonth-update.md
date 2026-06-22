# Sales Incentive System
# Requirement Preparation Document for POC

วันที่: 2026-06-13 | เวอร์ชัน: Draft v0.1

---

## Sale Incentive Guide — ขั้นตอนการทำงานหลัก (Operational Workflow)

### ภาษาไทย

#### รอบประจำปี (Annually)

| ขั้นที่ | Sheet | รายละเอียด |
|--------|-------|------------|
| 1 | M_Month | ตั้งรอบการจ่าย Sales Incentive ปีละ 1 ครั้ง |

#### รอบประจำเดือน (Monthly)

| ขั้นที่ | Sheet | รายละเอียด |
|--------|-------|------------|
| 1 | Period | กำหนดงวดที่ต้องการคำนวณ Sales Incentive |
| 2 | Actual | Download ข้อมูลยอดขายจาก BI แล้ว copy ลง Actual sheet |
| 3 | AST_Base | อัปเดตข้อมูล AST Base sheet และ copy สูตรในคอลัมน์ที่ไฮไลต์สีเหลือง |
| 4 | HR Rep | Download รายงาน Personal Employment (Main & Active)_AST จาก HCM, อัปเดตข้อมูลใน HR Rep และ copy สูตรในคอลัมน์ที่ไฮไลต์สีเหลือง |
| 5 | For HR | กรอก Employee ID จากนั้น copy สูตรทุกคอลัมน์ ยกเว้น Employee ID และ Payment Method |

#### ปรับเมื่อจำเป็น (As needed)

| ขั้นที่ | Sheet | รายละเอียด |
|--------|-------|------------|
| 1 | T_SectAbove | ปรับอัตราค่าตอบแทนตามระดับตำแหน่ง |
| 2 | Table | ปรับอัตราค่าตอบแทนตาม Job Function |
| 3 | Target & Cal | ปรับเป้าหมายการขายตามสภาพธุรกิจ |
| 4 | Shortage | ปรับกรณีสินค้าขาดแคลนรายสินค้า/เดือน |
| 5 | Fix Rate | ปรับอัตราคงที่รายพนักงาน |

> ⚠️ **หมายเหตุสำคัญ:** ต้องตรวจสอบให้แน่ใจว่าข้อมูลยอดขายและข้อมูลพนักงาน **สอดคล้องกับงวด Sales Incentive ของเดือนนั้น** เสมอ
> ⚠️ **Recheck Job Function** ก่อนปิดรอบทุกครั้ง

---

### English

#### Annually

| Step No. | Sheet | Step Detail |
|----------|-------|-------------|
| 1 | M_Month | Set the Sales Incentive payment cycle to once per year. |

#### Monthly

| Step No. | Sheet | Step Detail |
|----------|-------|-------------|
| 1 | Period | Define the Sales Incentive period. |
| 2 | Actual | Download data from BI and copy it into the Actual sheet. |
| 3 | AST_Base | Update the data in the AST Base sheet and copy the formulas in the yellow-highlighted columns. |
| 4 | HR Rep | Download Personal Employment (Main & Active)_AST report from HCM, update the data in the HR Rep and copy the formulas in the yellow-highlighted columns. |
| 5 | For HR | Enter the employee ID, then copy all formulas except the Employee ID and Payment Method columns. |

#### As needed

| Step No. | Sheet | Step Detail |
|----------|-------|-------------|
| 1 | T_SectAbove | Adjust the compensation rate based on position level. |
| 2 | Table | Adjust the compensation rate based on Job Function. |
| 3 | Target & Cal | Adjust sales targets based on business conditions. |
| 4 | Shortage | Adjust shortages by product and month. |
| 5 | Fix Rate | Adjust fixed rate based on employee. |

> ⚠️ **Important:** Please ensure that sales and employee data align with the Sales Incentive period for that month.
> ⚠️ **Recheck Job Function** before closing each period.

---

## System Architecture & Business Process Diagrams

### ภาษาไทย

#### 1. Business Process Diagram — ลำดับการทำงานรายเดือน

```mermaid
graph TD
    A["🔄 เริ่มต้น (Start)<br/>ประจำเดือน"] --> B["📋 Step 1: ตั้งเดือน<br/>Period Sheet"]
    B --> C["📥 Step 2: Download ยอดขาย<br/>จาก BI / DWC"]
    C --> D["📊 Step 2: Paste ยอดขาย<br/>ลง Actual Sheet"]
    D --> E{"MT Channel<br/>หรือ TT?"}
    
    E -->|"MT (Modern Trade)"| F["🔗 Step 2.5: Mapping<br/>BI SalesCode → Salesman"]
    F --> G["📈 Step 3: Update ASTBase<br/>(โครงสร้างองค์กร)<br/>Salesman→DirectSup→Dept→AD"]
    
    E -->|"TT (Traditional)<br/>ไม่ต้อง Mapping"| G
    
    G --> H["👥 Step 4: Download HR Data<br/>จาก HCM"]
    H --> I["📋 Step 4: Update HR Rep<br/>Employee ID, Position, Job Function"]
    I --> J["⚙️ Step 5: System Calculation<br/>(แบบ Automated)<br/>Achievement → GOAL → Incentive"]
    
    J --> K["✅ Step 5: Generate For HR<br/>Incentive Output"]
    K --> L["📤 Output: For HR<br/>(ส่งให้ HR สำหรับจ่าย)"]
    L --> M["💰 HR Payment Processing<br/>จ่าย Incentive ให้พนักงาน"]
    
    N["⚙️ As-needed Adjustments<br/>(ปรับเมื่อจำเป็น)"] -.->|"Target ปรับตามธุรกิจ"| J
    N -.->|"Shortage (สินค้าขาด)"| J
    N -.->|"Fix Rate (จ่ายเดือนนี้)<br/>จำนวนคงที่"| K
    
    M --> O["🎯 End<br/>ปิดเดือนนั้น"]
    
    style A fill:#90EE90
    style O fill:#FFB6C6
    style J fill:#FFE4B5
    style K fill:#FFE4B5
    style M fill:#B0E0E6
    style N fill:#FFD700
```

**ขั้นตอน:**
- **Monthly:** ทำซ้ำทุกเดือน — Period → Actual → ASTBase → HR Rep → For HR → Payment
- **As-needed:** ปรับพารามิเตอร์เมื่อจำเป็น (Target, Shortage, Fix Rate)

#### 2. System Architecture Diagram — โครงสร้างระบบ

```mermaid
graph TB
    subgraph EXT["📡 External Systems (ระบบภายนอก)"]
        BI["BI / DWC<br/>ยอดขายรายเดือน"]
        HCM["HCM System<br/>ข้อมูลพนักงาน"]
        HR_SYS["HR Payroll System<br/>จ่าย Incentive"]
    end
    
    subgraph CORE["🔧 Core Application Layer (ชั้น Application หลัก)"]
        K2["K2 Intelligent Workflow<br/>(Orchestration + Smart Forms)<br/>- Period Management<br/>- Data Import & Validation<br/>- Approval Workflow"]
        API["API Service Layer<br/>(.NET Core 10)<br/>- Achievement Calculation<br/>- Goal Lookup (XLOOKUP)<br/>- Cascade Logic (MT)<br/>- GD Special Incentive"]
    end
    
    subgraph DATA["💾 Data Layer (ชั้นข้อมูล)"]
        SSRS["SQL Server Reporting Svc<br/>(SSRS)<br/>- Print Forms<br/>- Formatted Output"]
        SQLDB["SQL Server Database<br/>- Period Master<br/>- Calculation Results<br/>- Audit Trail<br/>- Reference Data"]
        EXCEL["Excel (Transitional)<br/>- AST Base<br/>- Mapping (MT)<br/>- Rate Tables<br/>- Shortage Flags"]
    end
    
    subgraph UI["🖥️ User Interface Layer"]
        FORM_UI["K2 Smart Forms<br/>- Parameter Entry<br/>- Data Review<br/>- Status Monitor"]
        DASHBOARD["Dashboard (Chart.js)<br/>- Achievement Summary<br/>- By Channel / Dept<br/>- Trend Analysis"]
    end
    
    BI -->|"CSV/API<br/>Sales Data"| K2
    HCM -->|"CSV/API<br/>Employee Data"| K2
    
    K2 -->|"Orchestrate<br/>Validation Rules"| API
    
    API -->|"Query/Save"| SQLDB
    API -->|"Reference<br/>Rate Tables"| EXCEL
    
    SQLDB -->|"Data Source"| SSRS
    SQLDB -->|"Display"| FORM_UI
    SQLDB -->|"Display"| DASHBOARD
    
    FORM_UI -->|"User Actions"| K2
    DASHBOARD -->|"View Only"| K2
    
    K2 -->|"Generate<br/>For HR File"| SSRS
    
    SSRS -->|"Export<br/>Formatted Output"| HR_SYS
    
    style CORE fill:#87CEEB
    style DATA fill:#DEB887
    style EXT fill:#D3D3D3
    style UI fill:#F0F8FF
    style SQLDB fill:#FFB6C1
    style API fill:#98FB98
```

**Components:**
- **External:** BI, HCM ส่งข้อมูล
- **Core:** K2 Workflow (orchestration) + API (.NET calculation)
- **Data:** SQL Server (results) + Excel (transitional reference)
- **UI:** Smart Forms + Dashboard
- **Output:** SSRS → HR System

#### 3. System Flow Diagram — MT vs TT Channel Processing

```mermaid
flowchart TD
    START["🔄 Start Processing<br/>(Monthly Cycle)"]

    START --> INPUT["📥 Input Data<br/>BI Sales + HCM Employee"]

    INPUT --> VALIDATE["✓ Validation Gate<br/>- Period Alignment<br/>- Required Fields<br/>- Hierarchy Check"]

    VALIDATE -->|"Failed"| ERROR["⚠️ Error Notification<br/>Show Issue, Block Processing"]
    ERROR --> RETRY["🔄 Fix & Retry"]
    RETRY --> VALIDATE

    VALIDATE -->|"Passed"| CHANNEL{"Channel<br/>Decision?"}

    CHANNEL -->|"MT<br/>(Modern Trade)<br/>4-Level Cascade"| MT_PATH["🔗 MT Path:<br/>Mapping (BI → Salesman)"]

    MT_PATH --> MT_CALC["📊 Calculation (Staff Level):<br/>- BI SalesCode + ProductGroup<br/>- Lookup Mapping → Salesman<br/>- Achievement = Actual/Target<br/>- Check Shortage Flag<br/>- GOAL = XLOOKUP(achievement)<br/>- incentive = base × GOAL × weight"]

    MT_CALC --> MT_CASCADE["🔀 Cascade Upward:<br/>Staff → Sect → Dept → AD<br/>Each level: SUMIFS + Recalculate"]

    MT_CASCADE --> MT_GD["🎁 GD Special Incentive (Optional):<br/>- Aji Plus / RDQ / RDM / RDNS<br/>- Per-product VLOOKUP payout<br/>- Add to For HR"]

    CHANNEL -->|"TT<br/>(Traditional)<br/>No Cascade"| TT_PATH["📊 TT Path:<br/>Single-Sheet Calculation"]

    TT_PATH --> TT_CALC["📊 Calculation (All Levels):<br/>- Salesman Code direct<br/>- Achievement = Actual/Target per SKU<br/>- Check Shortage Flag<br/>- GOAL = XLOOKUP(achievement)<br/>- incentive = base × GOAL × weight"]

    TT_CALC --> TT_GD["🎁 GD Special Incentive (Optional):<br/>- Aji Plus / RDQ / RDM / RDNS<br/>- Per-product VLOOKUP payout"]

    MT_GD --> FIXRATE["💵 Fixed Rate Adjustment:<br/>- Job Function lookup<br/>- Fixed amount per month"]

    TT_GD --> FIXRATE

    FIXRATE --> OUTPUT["📋 Generate Output:<br/>1) For HR (Variable)<br/>2) For HR (Fixed)<br/>Combine all incentive types"]

    OUTPUT --> APPROVAL["🆗 Approval Workflow:<br/>- Draft → Reviewed → Approved<br/>Multi-level sign-off"]

    APPROVAL --> EXPORT["📤 Export to HR:<br/>SSRS Format<br/>Formatted Payout Report"]

    EXPORT --> PAYMENT["💰 HR Payment Processing<br/>Transfer to Payroll"]

    PAYMENT --> AUDIT["📝 Audit Trail:<br/>Log all changes<br/>Period Close"]

    AUDIT --> END["✅ End<br/>Period Complete"]

    style START fill:#90EE90
    style END fill:#FFB6C6
    style VALIDATE fill:#FFE4B5
    style ERROR fill:#FF6B6B
    style MT_CASCADE fill:#87CEEB
    style TT_CALC fill:#DDA0DD
    style APPROVAL fill:#F0E68C
    style PAYMENT fill:#B0E0E6
```

**Key Differences:**
- **MT:** Mapping + 4-level Cascade + Product Group basis
- **TT:** No Mapping + Single-sheet + SKU basis
- **GD:** Optional special incentive (both channels)
- **Fixed Rate:** Manual override per Job Function

---

### English

#### 1. Business Process Flow — Monthly Workflow

```mermaid
graph TD
    A["🔄 Start<br/>(Monthly)"] --> B["📋 Step 1: Set Period"]
    B --> C["📥 Step 2: Download Sales<br/>from BI / DWC"]
    C --> D["📊 Step 2: Paste Actual<br/>into Actual Sheet"]
    D --> E{"Channel?"}
    
    E -->|"MT"| F["🔗 Step 2.5: Mapping<br/>BI SalesCode → Salesman"]
    F --> G["📈 Step 3: Update ASTBase<br/>(Org Hierarchy)"]
    
    E -->|"TT"| G
    
    G --> H["👥 Step 4: Download HR<br/>from HCM"]
    H --> I["📋 Step 4: Update HR Rep"]
    I --> J["⚙️ Step 5: Auto Calc<br/>Achievement→GOAL→Incentive"]
    J --> K["✅ Step 5: Generate Output"]
    K --> L["📤 Output: For HR"]
    L --> M["💰 HR Payment"]
    
    M --> O["🎯 End<br/>Period Close"]
    
    style A fill:#90EE90
    style O fill:#FFB6C6
    style J fill:#FFE4B5
```

#### 2. System Architecture — Components

```mermaid
graph TB
    subgraph EXT["📡 External Systems"]
        BI["BI / DWC"]
        HCM["HCM System"]
        HR["HR Payroll"]
    end
    
    subgraph CORE["🔧 Core Layer"]
        K2["K2 Workflow<br/>(Orchestration)"]
        API["API Service<br/>(.NET Core)<br/>Calculation"]
    end
    
    subgraph DATA["💾 Data Layer"]
        SQL["SQL Server"]
        XL["Excel<br/>(Reference)"]
    end
    
    subgraph UI["🖥️ UI Layer"]
        FORM["Smart Forms<br/>(Input)"]
        DASH["Dashboard<br/>(View)"]
    end
    
    BI -->|"Sales Data"| K2
    HCM -->|"Employee Data"| K2
    K2 -->|"Validate & Orchestrate"| API
    API -->|"Query"| SQL
    API -->|"Reference"| XL
    FORM -->|"User Input"| K2
    DASH -->|"Display"| SQL
    SQL -->|"Export"| SSRS["SSRS<br/>(Print)"]
    SSRS -->|"Output"| HR
    
    style CORE fill:#87CEEB
    style DATA fill:#DEB887
```

#### 3. Processing Flow — MT vs TT

```mermaid
flowchart TD
    START["🔄 Start"]

    START --> INPUT["📥 Input: BI Sales + HCM Employee"]

    INPUT --> VALIDATE["✓ Validate<br/>Period, Fields, Hierarchy"]

    VALIDATE -->|"Fail"| ERROR["⚠️ Error"]

    VALIDATE -->|"Pass"| CHANNEL{"MT or TT?"}

    CHANNEL -->|"MT<br/>(4-Level Cascade)"| MT["🔗 Mapping<br/>Calculate Staff<br/>Cascade Sect→Dept→AD"]

    CHANNEL -->|"TT<br/>(Single-Sheet)"| TT["📊 Direct Calculate<br/>All Levels"]

    MT --> GD["🎁 GD Special<br/>Incentive"]
    TT --> GD

    GD --> FIX["💵 Fixed Rate<br/>Override"]

    FIX --> OUT["📋 Output:<br/>For HR (Variable)<br/>For HR (Fixed)"]

    OUT --> APP["🆗 Approval"]

    APP --> EXP["📤 Export"]

    EXP --> PAY["💰 HR Payment"]

    style START fill:#90EE90
    style CHANNEL fill:#FFE4B5
    style MT fill:#87CEEB
    style TT fill:#DDA0DD
    style PAY fill:#B0E0E6
```

---

## Function 1 — Sales Data Management

### ภาษาไทย

### 1.1 Datasource

| แหล่งข้อมูล | ระบบต้นทาง | ประเภทข้อมูล | ความถี่ |
|------------|-----------|------------|--------|
| ยอดขาย (Actual Sales) | BI / DWC (Data Warehouse Cloud) | ยอดขายรายเดือน ราย Salesman / Product Group / SKU | รายเดือน |
| ข้อมูลพนักงาน (Employee) | HCM (Human Capital Management) | Employee ID, ชื่อ, ตำแหน่ง, Job Function, Grade, Cost Center | รายเดือน |
| โครงสร้างองค์กร | ASTBase (ในไฟล์ Excel) | Salesman → DirectSup → DeptMgr → DivMgr | รายเดือน |

**หมายเหตุ:**
- MT: BI ส่งข้อมูล BI SalesCode + Product Group → ต้องผ่าน Mapping sheet ก่อน เพื่อแปลงเป็น Salesman Code
- TT: BI ส่ง Salesman Code ตรง → ไม่ต้องผ่าน Mapping
- ข้อมูลทั้งหมดต้องอยู่ใน period เดียวกัน (ตาม Period sheet)

### 1.2 Data Validation & Error Handling

| รายการตรวจ | เงื่อนไข | Action เมื่อพบปัญหา |
|-----------|---------|--------------------|
| Period alignment | Sales data และ HR data ต้องเป็นเดือนเดียวกับ Period | Reject และแจ้ง error |
| Required fields | Salesman Code, Product Code, Employee ID ต้องไม่ว่าง | Reject แถวที่ขาดข้อมูล |
| Key uniqueness | Salesman + Product ต้องไม่ซ้ำใน period เดียวกัน | Deduplicate หรือ alert |
| Hierarchy consistency | DirectSupCode ต้องมีอยู่จริงใน ASTBase | Alert และ block cascade |
| Job Function | ต้องตรงกับตารางอัตราที่กำหนด | Alert ให้ recheck |

### English

### 1.1 Datasource

| Source | System | Data Type | Frequency |
|--------|--------|-----------|----------|
| Sales Actual | BI / DWC | Monthly sales by Salesman / Product Group / SKU | Monthly |
| Employee Data | HCM | Employee ID, Name, Position, Job Function, Grade, Cost Center | Monthly |
| Org Hierarchy | ASTBase | Salesman → DirectSup → DeptMgr → DivMgr | Monthly |

### 1.2 Data Validation & Error Handling

| Check | Condition | Action on Failure |
|-------|-----------|------------------|
| Period alignment | Sales and HR data must match the incentive period | Reject and notify |
| Required fields | Salesman Code, Product Code, Employee ID must not be empty | Reject affected rows |
| Key uniqueness | Salesman + Product must be unique per period | Deduplicate or alert |
| Hierarchy consistency | DirectSupCode must exist in ASTBase | Alert and block cascade |
| Job Function | Must match the compensation rate table | Alert for recheck |
