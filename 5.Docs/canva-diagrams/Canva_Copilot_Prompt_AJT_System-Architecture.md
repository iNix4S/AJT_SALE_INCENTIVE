# Canva Copilot Prompt - System Architecture Design (AJT New Sale Incentive)

วันที่: 2026-06-13
วัตถุประสงค์: วางข้อความในไฟล์นี้ใน Canva Copilot (ผ่าน Microsoft Teams) เพื่อให้สร้างไดอะแกรม/สไลด์ System Architecture ต่ออัตโนมัติ
อ้างอิง: System-Architecture-Design_AJT-New-Sale-Incentive_v1.0_2026-06-13.md

---

## Prompt แบบละเอียด (Full Prompt)

ช่วยสร้างชุดสไลด์ภาษาไทยแบบมืออาชีพสำหรับ System Architecture ของโครงการ AJT New Sale Incentive เพื่อใช้นำเสนอกับทีม IT, Business Owner และ Sales Ops โดยให้ผลลัพธ์พร้อมใช้งานจริง

เป้าหมายงาน
1. แสดงภาพสถาปัตยกรรมระบบครบทุก layer
2. แสดงการเชื่อมต่อกับระบบภายนอกและ integration
3. แสดง deployment และ security ที่เข้าใจง่าย
4. โทนงาน corporate, clean, modern

รูปแบบงานที่ต้องสร้าง
1. Slide 1: Technology Stack
- Workflow/Orchestration: Nintex K2 Workflow + Smart Forms
- Service/Calculation: .NET Core 10 Service API
- Database: Microsoft SQL Server (AJT_SIS)
- Reporting/Print: SQL Server Reporting Services (SSRS)
- Dashboard: Chart.js
- Integration: BI/DWC Interface, HCM Interface

2. Slide 2: High-Level Context (C4 Context)
- External Systems: BI/DWC (ยอดขายรายเดือน), HCM (ข้อมูลพนักงาน), HR Payroll System
- Center: AJT Sale Incentive Platform (K2 + API + SQL + SSRS + Dashboard)
- Users: Sales Ops, Business Owner, HR
- เส้นเชื่อม: BI/HCM ส่งข้อมูลเข้า, Users ใช้งานผ่าน Smart Forms/Dashboard, ระบบส่ง Payout Output ให้ HR Payroll

3. Slide 3: Layered Architecture
- UI Layer: K2 Smart Forms (Parameter Entry, Data Review, Status Monitor), Dashboard (Chart.js)
- Core Layer: K2 Intelligent Workflow (Period Mgmt, Import & Validation, Approval), API Service .NET Core 10 (Achievement, Goal Lookup, Cascade MT, GD, Fixed Rate)
- Data Layer: SQL Server AJT_SIS (Master/Parameter, Calculation Results, Audit), SSRS (Print Forms, Formatted Output)
- เส้นเชื่อม: BI/HCM -> K2 -> API -> SQL -> SSRS -> HR

4. Slide 4: Integration Architecture
- Inbound: BI/DWC และ HCM -> Ingestion + Validation (K2) -> Calculation API -> SQL Server
- Outbound: SQL -> SSRS Report -> Payout file -> HR Payroll
- Dashboard อ่านข้อมูลจาก SQL
- ตาราง interface: IR-001 BI/DWC Inbound CSV/API รายเดือน, IR-002 HCM Inbound CSV/API รายเดือน, IR-003 System->HR Outbound SSRS รายรอบจ่าย

5. Slide 5: Deployment View
- Client Tier: Web Browser (K2 Smart Forms + Dashboard)
- Application Tier: K2 Server (Workflow + Forms), API Server (.NET Core 10)
- Data Tier: SQL Server (AJT_SIS), SSRS Server
- โปรโตคอล: Browser->K2 HTTPS, K2->API REST/HTTPS, API->SQL TDS, SSRS->SQL Query, K2->SSRS Render

6. Slide 6: Security Architecture
- Authentication ผ่าน identity องค์กร (NFR-001)
- Authorization RBAC แยกสิทธิ์ Sales Ops/Owner/HR (NFR-001)
- Audit การแก้พารามิเตอร์และอนุมัติ (NFR-004)
- Data in transit เข้ารหัส HTTPS/TDS (NFR-001)
- Least privilege จำกัดสิทธิ์แก้ไข (NFR-001)

สไตล์ภาพที่ต้องการ
1. Professional corporate, clean, modern
2. ภาษาไทยเป็นหลัก มีคำอังกฤษกำกับเฉพาะคำเทคนิค
3. สีแยก layer: External เทาอ่อน, UI ฟ้าอ่อนมาก, Core ฟ้า, Data น้ำตาลอ่อน, SQL ชมพูอ่อน, API เขียวอ่อน
4. ฟอนต์อ่านง่ายภาษาไทย เช่น Sarabun หรือ Tahoma
5. ใช้ไอคอนสื่อความหมาย Workflow, API, Database, Report, Dashboard, External

เงื่อนไขคุณภาพงาน
1. แต่ละสไลด์ไม่แน่นเกินไป อ่านจบใน 30-60 วินาที
2. กล่องข้อความสั้น กระชับ 2-3 บรรทัด
3. ลูกศรเชื่อมชัดเจน ทิศทางเดียวกัน
4. มี legend สำหรับสี layer
5. พร้อมนำเสนอทันทีโดยไม่ต้องแก้โครง

---

## Prompt แบบสั้น (Quick Prompt)

สร้างสไลด์ภาษาไทยมืออาชีพ 5-6 หน้าสำหรับ System Architecture ของ AJT New Sale Incentive ประกอบด้วย (1) Technology Stack: K2 Workflow+Smart Forms, .NET Core 10 API, SQL Server AJT_SIS, SSRS, Chart.js, BI/HCM Interface, (2) Context Diagram: External BI/DWC, HCM, HR Payroll เชื่อมกับ Incentive Platform และ Users Sales Ops/Owner/HR, (3) Layered Architecture: UI (Smart Forms+Dashboard) -> Core (K2 + .NET API คำนวณ Achievement/Goal/Cascade/GD/Fixed) -> Data (SQL Server + SSRS), (4) Integration: Inbound BI/HCM -> K2 Validation -> API -> SQL, Outbound SQL -> SSRS -> HR; IR-001/IR-002 inbound, IR-003 outbound, (5) Deployment: Client/App/Data tier พร้อมโปรโตคอล HTTPS/REST/TDS, (6) Security: RBAC, Audit, Encryption ตาม NFR-001/004. โทน corporate, แยกสี layer, พร้อมนำเสนอ.

---

## วิธีใช้งาน

1. เปิด Canva Copilot ใน Microsoft Teams
2. คัดลอก Prompt แบบละเอียดหรือแบบสั้นจากไฟล์นี้
3. วางและสั่งให้ Copilot สร้างงาน
4. ตรวจคำศัพท์เฉพาะองค์กรก่อนใช้งานจริง
