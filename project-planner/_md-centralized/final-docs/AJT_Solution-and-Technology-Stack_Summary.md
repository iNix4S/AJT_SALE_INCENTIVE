# AJT New Sale Incentive — Solution and Technology Stack Summary

**วันที่:** 2026-06-14
**เวอร์ชัน:** v1.0
**สถานะ:** Complete (Baseline)
**จัดทำโดย:** สรุปรวมจากเอกสาร System Architecture Design และ BRD/SRS ฉบับล่าสุด

---

## บทนำ

เอกสารนี้สรุปส่วนประกอบของระบบและเทคโนโลยีที่ใช้ในโครงการ **AJT (Ajinomoto Thailand) New Sale Incentive** แบบอ่านง่าย เพื่อใช้เป็นข้อมูลอ้างอิงสำหรับทีม SA (System Analyst / นักวิเคราะห์ระบบ), Developer (นักพัฒนา), และ IT Reviewer

---

## 1. Solution Components — ภาพรวมองค์ประกอบระบบ

| # | Solution Component | คำอธิบาย |
|---|---|---|
| 1 | **Incentive Platform หลัก** (ศูนย์กลางระบบ) | ระบบหลักที่รวมงานคำนวณ ข้อมูล และรายงานไว้ในที่เดียว |
| 2 | **Workflow / Orchestration** (การประสานงานและการอนุมัติ) | ตัวคุมลำดับงานของแต่ละเดือน ตั้งแต่รับข้อมูล ตรวจสอบ ไปจนถึงอนุมัติ |
| 3 | **Calculation Engine** (เครื่องคำนวณ) สำหรับ MT / TT / GD / Fixed | ส่วนที่ใช้คำนวณค่าตอบแทนการขายตามกติกาของแต่ละช่องทาง |
| 4 | **Data Layer** (ชั้นข้อมูล) สำหรับ Master / Transaction / Output / Audit | ที่เก็บข้อมูลหลัก ผลคำนวณ ข้อมูลส่งออก และประวัติการแก้ไข |
| 5 | **Reporting / Export** (การรายงานและส่งออก) | ส่วนที่จัดผลลัพธ์ให้อ่านง่ายและส่งต่อให้ HR |
| 6 | **Dashboard** (แดชบอร์ดสรุปผล) | หน้าสรุปภาพรวมผลคำนวณและสถานะงานแบบดูอย่างเดียว |
| 7 | **Integration Layer** (ชั้นเชื่อมต่อระบบ) | ส่วนที่รับและส่งข้อมูลกับระบบอื่น เช่น BI/DWC และ HR Payroll |

---

## 2. Technology Stack — เทคโนโลยีที่ใช้ในโครงการ

| # | เทคโนโลยี | คำย่อ / ชื่อเต็ม | บทบาทในระบบ |
|---|---|---|---|
| 1 | **Nintex K2 Workflow** | K2 = ชื่อผลิตภัณฑ์ Workflow ของ Nintex | ใช้จัดลำดับงานรายเดือนและขั้นตอนอนุมัติ |
| 2 | **K2 Smart Forms** | Smart Forms = ฟอร์มอัจฉริยะบนเว็บ | หน้าจอให้ผู้ใช้กรอกข้อมูลและตรวจสอบผล |
| 3 | **.NET Core 10 Service API** | .NET = Microsoft .NET Framework / API = Application Programming Interface (ส่วนต่อประสานโปรแกรม) | ส่วนที่ใช้คำนวณสูตรหลักของระบบ |
| 4 | **Microsoft SQL Server** (Database: AJT_SIS, Schema: dbo) | SQL = Structured Query Language (ภาษาจัดการฐานข้อมูล) / AJT_SIS = AJT Sales Incentive System | ฐานข้อมูลกลางสำหรับเก็บข้อมูลและผลคำนวณ |
| 5 | **SQL Server Reporting Services (SSRS)** | SSRS = SQL Server Reporting Services (บริการรายงานของ SQL Server) | ใช้ทำรายงานและไฟล์ส่งออกให้ HR |
| 6 | **Chart.js** | Chart.js = JavaScript Library สำหรับสร้างกราฟ | ใช้แสดงผลข้อมูลแบบกราฟบน dashboard |
| 7 | **BI/DWC Interface** (Inbound) | BI = Business Intelligence (ระบบวิเคราะห์ข้อมูล) / DWC = Data Warehouse Cloud (คลังข้อมูลบนคลาวด์) | รับข้อมูลยอดขายเข้าระบบ |
| 8 | **HCM Interface** (Inbound) | HCM = Human Capital Management (ระบบบริหารทรัพยากรบุคคล) | รับข้อมูลพนักงานเข้าระบบ |
| 9 | **HR Payroll Interface/Export** (Outbound ผ่าน SSRS file) | HR = Human Resources (ฝ่ายทรัพยากรบุคคล) / Payroll = ระบบจ่ายเงินเดือน | ส่งผลลัพธ์ไปให้ HR ใช้จ่ายเงินจริง |

---

## 3. External Systems / Data Sources — ระบบภายนอกและแหล่งข้อมูล

| # | ระบบ | คำย่อ / ชื่อเต็ม | บทบาท | ทิศทางข้อมูล |
|---|---|---|---|---|
| 1 | **BI / DWC** | BI = Business Intelligence / DWC = Data Warehouse Cloud | แหล่งข้อมูลยอดขายรายเดือน | Inbound (ขาเข้า) |
| 2 | **HCM System** | HCM = Human Capital Management | แหล่งข้อมูลพนักงานและโครงสร้างองค์กร | Inbound (ขาเข้า) |
| 3 | **HR Payroll System** | HR = Human Resources / Payroll = ระบบจ่ายเงินเดือน | ระบบปลายทางที่รับผลลัพธ์ไปจ่ายเงินจริง | Outbound (ขาออก) |

### Interface Reference (อ้างอิง Interface)

| Interface ID | เส้นทาง | รูปแบบ | ความถี่ |
|---|---|---|---|
| IR-001 | BI/DWC → Incentive System | CSV (Comma-Separated Values) / API | รายเดือน |
| IR-002 | HCM → Incentive System | CSV / API | รายเดือน |
| IR-003 | Incentive System → HR Payroll | SSRS Output File (ไฟล์รายงาน) | รายรอบจ่าย |

---

## 4. Data & Integration Format / Protocol — รูปแบบและโปรโตคอลการเชื่อมต่อ

| # | Format / Protocol | ชื่อเต็ม | ใช้งาน |
|---|---|---|---|
| 1 | **CSV** | Comma-Separated Values (ไฟล์ข้อมูลคั่นด้วยจุลภาค) | ใช้รับข้อมูลเข้า |
| 2 | **API** | Application Programming Interface (ส่วนต่อประสานโปรแกรม) | ใช้ส่งข้อมูลระหว่างระบบ |
| 3 | **SSRS Output File** | SQL Server Reporting Services Output | ใช้ส่งผลลัพธ์ออกเป็นไฟล์รายงาน |
| 4 | **HTTPS** | HyperText Transfer Protocol Secure (โปรโตคอลสื่อสารเว็บแบบเข้ารหัส) | ใช้สื่อสารจากผู้ใช้ไป K2 อย่างปลอดภัย |
| 5 | **REST / HTTPS** | Representational State Transfer / HyperText Transfer Protocol Secure | ใช้เชื่อม K2 กับ API Server |
| 6 | **TDS** | Tabular Data Stream (โปรโตคอลรับ-ส่งข้อมูลตาราง ของ Microsoft SQL Server) | ใช้เชื่อม API Server กับ SQL Server |

---

## 5. Deployment View — โครงสร้าง Tier การ Deploy

| Tier (ชั้น) | องค์ประกอบ | คำอธิบาย |
|---|---|---|
| **Client Tier** (ชั้น Client / ผู้ใช้) | Web Browser (เบราว์เซอร์) | ฝั่งผู้ใช้เข้าใช้งานฟอร์มและ dashboard |
| **Application Tier** (ชั้น Application / แอปพลิเคชัน) | K2 Server + API Server (.NET Core 10) | ฝั่งที่รับงาน ตรวจสอบข้อมูล และคำนวณผล |
| **Data Tier** (ชั้นข้อมูล) | SQL Server (AJT_SIS) + SSRS Server | ฝั่งเก็บข้อมูลและสร้างรายงาน |

---

## 6. Security Architecture — สถาปัตยกรรมความปลอดภัย

| ด้าน | แนวทาง | อ้างอิง NFR |
|---|---|---|
| Authentication (การพิสูจน์ตัวตน) | ใช้ระบบล็อกอินขององค์กร | NFR-001 |
| Authorization / RBAC | RBAC = Role-Based Access Control (ควบคุมสิทธิ์ตามบทบาท) แยก Sales Ops / Business Owner / HR | NFR-001 |
| Audit Trail (บันทึกการเปลี่ยนแปลง) | เก็บร่องรอยการแก้ไขและการอนุมัติทุกครั้ง | NFR-004 |
| Data in Transit (ข้อมูลระหว่างส่ง) | เข้ารหัสข้อมูลระหว่างทางด้วย HTTPS / TDS Encryption | NFR-001 |
| Least Privilege (สิทธิ์น้อยที่สุด) | ให้สิทธิ์เท่าที่จำเป็นต่อหน้าที่เท่านั้น | NFR-001 |

---

## 7. Transitional / Supporting Tools — เครื่องมือช่วยงานและ Transitional (ระยะ POC)

| # | เครื่องมือ | คำอธิบาย | บทบาท |
|---|---|---|---|
| 1 | **Excel (Transitional)** | Microsoft Excel ที่ใช้ชั่วคราวในช่วงเตรียมระบบ | เก็บข้อมูลเสริม เช่น AST Base, MT Mapping, Rate Tables, และ Shortage Flags |
| 2 | **PowerShell Extraction Tool** (`Extract-Xlsx.ps1`) | PowerShell Script สำหรับดึงข้อมูลจากไฟล์ Excel (.xlsx) ออกมาเป็น CSV | ใช้ช่วยอ่านข้อมูลดิบจากไฟล์ต้นฉบับ |

---

## 8. คำย่อที่ใช้ในโครงการ (Glossary)

| คำย่อ | ชื่อเต็ม / ความหมาย |
|---|---|
| AJT | Ajinomoto Thailand (อายิโนะโมะโต๊ะ ประเทศไทย) |
| AJT_SIS | AJT Sales Incentive System (ระบบฐานข้อมูล Incentive ของ AJT) |
| API | Application Programming Interface (ส่วนต่อประสานโปรแกรม) |
| BI | Business Intelligence (ระบบวิเคราะห์ข้อมูลธุรกิจ) |
| BRD | Business Requirements Document (เอกสารความต้องการทางธุรกิจ) |
| CSV | Comma-Separated Values (ไฟล์ข้อมูลคั่นด้วยจุลภาค) |
| DWC | Data Warehouse Cloud (คลังข้อมูลบนคลาวด์) |
| GD | Growth Driver (สินค้ากลุ่มพิเศษที่บริษัทต้องการผลักดันยอดขาย) |
| HCM | Human Capital Management (ระบบบริหารทรัพยากรบุคคล) |
| HR | Human Resources (ฝ่ายทรัพยากรบุคคล) |
| HTTPS | HyperText Transfer Protocol Secure (โปรโตคอลสื่อสารเว็บแบบเข้ารหัส) |
| MT | Modern Trade (ช่องทางค้าปลีกสมัยใหม่ เช่น Supermarket, Hypermarket) |
| NFR | Non-Functional Requirements (ข้อกำหนดด้านคุณภาพระบบ เช่น Security, Performance) |
| POC | Proof of Concept (การทดสอบแนวคิดเบื้องต้น) |
| RBAC | Role-Based Access Control (การควบคุมการเข้าถึงตามบทบาท) |
| REST | Representational State Transfer (รูปแบบการออกแบบ API บน HTTP) |
| SA | System Analyst (นักวิเคราะห์ระบบ) |
| SKU | Stock Keeping Unit (รหัสสินค้าเฉพาะแต่ละรายการ) |
| SRS | Software Requirements Specification (เอกสารกำหนดความต้องการซอฟต์แวร์) |
| SQL | Structured Query Language (ภาษาจัดการฐานข้อมูล) |
| SSRS | SQL Server Reporting Services (บริการรายงานของ Microsoft SQL Server) |
| TDS | Tabular Data Stream (โปรโตคอลรับ-ส่งข้อมูลตารางของ SQL Server) |
| TT | Traditional Trade (ช่องทางค้าปลีกดั้งเดิม เช่น ร้านค้าทั่วไป) |
| UI | User Interface (ส่วนต่อประสานผู้ใช้ / หน้าจอ) |

---

## แหล่งอ้างอิงหลัก

1. [5.Docs/System-Architecture-Design_AJT-New-Sale-Incentive_v1.0_2026-06-13.md](../5.Docs/System-Architecture-Design_AJT-New-Sale-Incentive_v1.0_2026-06-13.md)
2. [5.Docs/Sales Incentive System for POC.md](../5.Docs/Sales%20Incentive%20System%20for%20POC.md)
3. [5.Docs/BRD-SRS_AJT-New-Sale-Incentive_Draft-v0.1_2026-06-12.md](../5.Docs/BRD-SRS_AJT-New-Sale-Incentive_Draft-v0.1_2026-06-12.md)
