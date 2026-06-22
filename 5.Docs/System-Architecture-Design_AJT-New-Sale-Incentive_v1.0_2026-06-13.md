# System Architecture Design — AJT New Sale Incentive

เวอร์ชัน: v1.0
วันที่: 2026-06-13
สถานะ: Complete (Design Baseline)
ขอบเขต: สถาปัตยกรรมระบบคำนวณและส่งออก Sales Incentive (MT/TT) ตาม technology stack ที่กำหนดใน BRD/SRS

อ้างอิงต้นทาง:

- [Sales Incentive System for POC.md](Sales%20Incentive%20System%20for%20POC.md)
- [BRD-SRS_AJT-New-Sale-Incentive_Draft-v0.1_2026-06-12.md](BRD-SRS_AJT-New-Sale-Incentive_Draft-v0.1_2026-06-12.md)
- [environment/AJT_SIS_Database_Design_v1.0_2026-06-13.docx](../environment/AJT_SIS_Database_Design_v1.0_2026-06-13.docx)

---

## 1. วัตถุประสงค์ของเอกสาร

อธิบายสถาปัตยกรรมระบบอย่างสมบูรณ์ ครอบคลุม layer ของระบบ องค์ประกอบหลัก เทคโนโลยีที่ใช้ การเชื่อมต่อกับระบบภายนอก รูปแบบการ deploy ความปลอดภัย และการรองรับ Non-Functional Requirements เพื่อใช้เป็น baseline สำหรับการออกแบบเชิงลึกและการพัฒนา

---

## 2. Technology Stack (ตาม BRD/SRS)

| ชั้น | เทคโนโลยี | บทบาท |
| --- | --- | --- |
| Workflow / Orchestration | Nintex K2 Workflow + Smart Forms | คุมรอบงาน, ฟอร์มกรอกข้อมูล, approval |
| Service / Calculation | .NET Core 10 Service API | เครื่องคำนวณ achievement, GOAL, cascade, GD, fixed |
| Database | Microsoft SQL Server (AJT_SIS) | เก็บ master, ผลคำนวณ, audit trail |
| Reporting / Print | SQL Server Reporting Services (SSRS) | จัดรูปแบบและพิมพ์เอกสารส่ง HR |
| Dashboard | Chart.js | แสดงภาพรวมผลคำนวณรายรอบ |
| Integration | BI/DWC Interface, HCM Interface | นำเข้ายอดขายและข้อมูลพนักงาน |

---

## 3. High-Level Architecture (C4 — Context)

```mermaid
graph TB
    subgraph EXT["External Systems"]
        BI["BI / DWC<br/>ยอดขายรายเดือน"]
        HCM["HCM System<br/>ข้อมูลพนักงาน"]
        HRPAY["HR Payroll System<br/>จ่าย Incentive"]
    end

    subgraph SYS["AJT Sale Incentive System"]
        APP["Incentive Platform<br/>(K2 + API + SQL + SSRS + Dashboard)"]
    end

    USERS["Users<br/>Sales Ops / Business Owner / HR"]

    BI -->|"Sales Data (CSV/API)"| APP
    HCM -->|"Employee Data (CSV/API)"| APP
    USERS -->|"ใช้งานผ่าน Smart Forms / Dashboard"| APP
    APP -->|"Formatted Payout Output"| HRPAY

    style SYS fill:#87CEEB
    style EXT fill:#D3D3D3
```

---

## 4. Layered Architecture (Components)

```mermaid
graph TB
    subgraph EXT["External Systems"]
        BI["BI / DWC<br/>ยอดขายรายเดือน"]
        HCM["HCM System<br/>ข้อมูลพนักงาน"]
        HR_SYS["HR Payroll System"]
    end

    subgraph UI["User Interface Layer"]
        FORM_UI["K2 Smart Forms<br/>- Parameter Entry<br/>- Data Review<br/>- Status Monitor"]
        DASHBOARD["Dashboard (Chart.js)<br/>- Achievement Summary<br/>- By Channel / Dept<br/>- Trend Analysis"]
    end

    subgraph CORE["Core Application Layer"]
        K2["K2 Intelligent Workflow<br/>- Period Management<br/>- Data Import & Validation<br/>- Approval Workflow"]
        API["API Service (.NET Core 10)<br/>- Achievement Calculation<br/>- Goal Lookup (XLOOKUP)<br/>- Cascade Logic (MT)<br/>- GD Special Incentive<br/>- Fixed Rate"]
    end

    subgraph DATA["Data Layer"]
        SQLDB["SQL Server (AJT_SIS)<br/>- Master / Parameter<br/>- Calculation Results<br/>- Audit Trail"]
        SSRS["SSRS<br/>- Print Forms<br/>- Formatted Output"]
    end

    BI -->|"Sales Data"| K2
    HCM -->|"Employee Data"| K2

    FORM_UI -->|"User Actions"| K2
    DASHBOARD -->|"Read-only"| SQLDB

    K2 -->|"Orchestrate + Validate"| API
    API -->|"Query / Save"| SQLDB

    SQLDB -->|"Data Source"| SSRS
    SQLDB -->|"Display"| FORM_UI

    K2 -->|"Generate For HR"| SSRS
    SSRS -->|"Export Output"| HR_SYS

    style UI fill:#F0F8FF
    style CORE fill:#87CEEB
    style DATA fill:#DEB887
    style EXT fill:#D3D3D3
    style SQLDB fill:#FFB6C1
    style API fill:#98FB98
```

---

## 5. องค์ประกอบและความรับผิดชอบ (Component Responsibilities)

| องค์ประกอบ | ความรับผิดชอบหลัก | หมายเหตุ |
| --- | --- | --- |
| K2 Workflow | คุมสถานะรอบงาน, import, validation, approval | เป็น orchestrator หลัก |
| K2 Smart Forms | จุดกรอกพารามิเตอร์และตรวจข้อมูล | UI ฝั่งผู้ปฏิบัติงาน |
| .NET Core API | เครื่องคำนวณ incentive ทุกชนิด | แยก rule config ออกจาก core |
| SQL Server | source of truth ของ master/result/audit | ฐานข้อมูล AJT_SIS |
| SSRS | จัดรูปแบบและส่งออกผลให้ HR | output formatting |
| Chart.js Dashboard | แสดงภาพรวมเชิงวิเคราะห์ | read-only |

---

## 6. Integration Architecture

```mermaid
flowchart LR
    subgraph IN["Inbound"]
        BI["BI / DWC"] -->|"Sales feed"| ING["Ingestion + Validation (K2)"]
        HCM["HCM"] -->|"Employee feed"| ING
    end

    ING --> CALC["Calculation API (.NET Core)"]
    CALC --> DB["SQL Server (AJT_SIS)"]

    subgraph OUT["Outbound"]
        DB --> RPT["SSRS Report"]
        RPT -->|"Payout file"| HR["HR Payroll"]
    end

    DB --> DASH["Dashboard (Chart.js)"]

    style IN fill:#E6F3FF
    style OUT fill:#E6FFF0
```

| Interface | ทิศทาง | รูปแบบ | ความถี่ |
| --- | --- | --- | --- |
| IR-001 BI/DWC → System | Inbound | CSV/API | รายเดือน |
| IR-002 HCM → System | Inbound | CSV/API | รายเดือน |
| IR-003 System → HR | Outbound | ไฟล์ผลลัพธ์ (SSRS) | รายรอบจ่าย |

---

## 7. Deployment View

```mermaid
graph TB
    subgraph CLIENT["Client Tier"]
        BROWSER["Web Browser<br/>K2 Smart Forms + Dashboard"]
    end

    subgraph APPTIER["Application Tier"]
        K2SRV["K2 Server<br/>Workflow + Forms"]
        APISRV["API Server<br/>.NET Core 10"]
    end

    subgraph DBTIER["Data Tier"]
        SQLSRV["SQL Server<br/>AJT_SIS"]
        SSRSSRV["SSRS Server"]
    end

    BROWSER -->|"HTTPS"| K2SRV
    K2SRV -->|"REST/HTTPS"| APISRV
    APISRV -->|"TDS"| SQLSRV
    SSRSSRV -->|"Query"| SQLSRV
    K2SRV -->|"Render"| SSRSSRV

    style CLIENT fill:#F0F8FF
    style APPTIER fill:#87CEEB
    style DBTIER fill:#DEB887
```

---

## 8. Security Architecture

| ด้าน | แนวทาง | อ้างอิง NFR |
| --- | --- | --- |
| Authentication | ผ่านระบบ identity ขององค์กร | NFR-001 |
| Authorization | RBAC แยกสิทธิ์ตามบทบาท (Sales Ops/Owner/HR) | NFR-001 |
| Audit | บันทึกการแก้ไขพารามิเตอร์และการอนุมัติ | NFR-004 |
| Data in transit | เข้ารหัสการสื่อสาร (HTTPS/TDS encryption) | NFR-001 |
| Least privilege | จำกัดสิทธิ์แก้ไขเฉพาะผู้มีอำนาจ | NFR-001 |

---

## 9. การรองรับ Non-Functional Requirements

| NFR | สถาปัตยกรรมรองรับอย่างไร |
| --- | --- |
| NFR-001 Security | RBAC ที่ K2 + encryption ระหว่าง tier |
| NFR-002 Performance | แยก calculation ออกเป็น API ที่ scale ได้ |
| NFR-003 Reliability | validation gate + error notification |
| NFR-004 Auditability | audit table ใน SQL Server |
| NFR-005 Maintainability | แยก rule configuration ออกจาก core |
| NFR-006 Data Quality | pre-check ก่อนคำนวณและก่อนอนุมัติ |

---

## 10. ข้อมูลหลักในฐานข้อมูล (Data Architecture สรุป)

ฐานข้อมูล AJT_SIS (schema dbo) เก็บกลุ่มข้อมูลหลัก:

- Master/Parameter: channel, position level, goal threshold, payment cycle, job function, fix rate, product, GD product/payout, policy rule
- Transaction: sales actual, target, calculation result
- Output: For HR (variable/fixed)
- Audit: parameter change log, approval log

> รายละเอียดโครงสร้างตารางและความสัมพันธ์: ดูเอกสาร [AJT_SIS_Database_Design_v1.0_2026-06-13.docx](../environment/AJT_SIS_Database_Design_v1.0_2026-06-13.docx) และสคริปต์ใน [environment/ddl](../environment/ddl/01_ajt_sis_poc_master_tables.sql)

---

## 11. ความเชื่อมโยงกับเอกสารอื่น

| ต้องการดู | ไปที่ |
| --- | --- |
| กระบวนการธุรกิจ | [Business-Process-Design](Business-Process-Design_AJT-New-Sale-Incentive_v1.0_2026-06-13.md) |
| System Flow MT/TT | [System-Flow-Design](System-Flow-Design_AJT-New-Sale-Incentive_v1.0_2026-06-13.md) |
| Database Design | [environment/ddl](../environment/ddl/01_ajt_sis_poc_master_tables.sql) |

---

## 12. ประเด็นค้างที่กระทบสถาปัตยกรรม (ต้องยืนยัน)

1. แนวทางจ่าย GD (รวม For HR หรือแยกชุด) กระทบ output component และ table posting
2. ขอบเขต Laos Dept (TT AD) กระทบ data model และ export template
3. ระดับการลด Excel transitional ออกจาก data layer ในเฟสถัดไป

> การปิดมติใช้ [Decision-Log_Template_Open-Questions](Decision-Log_Template_Open-Questions_2026-06-13.md)
