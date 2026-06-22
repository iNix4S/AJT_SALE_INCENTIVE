# Demo POC — Project Scope Definition
# AJT New Sale Incentive System (.NET Core 10 + MS SQL Server)

**วันที่จัดทำ:** 2026-06-22
**เวอร์ชัน:** v1.0
**สถานะ:** Draft
**จัดทำโดย:** ทีม CDS Solution

---

## 1. ชื่อโครงการ

**AJT New Sale Incentive — Demo POC**
ระบบ Web Application สำหรับการคำนวณและบริหารจัดการ Sales Incentive
แทนการทำงานบน Excel

---

## 2. วัตถุประสงค์ Demo POC

| # | วัตถุประสงค์ |
|---|---|
| 1 | แสดง End-to-End Monthly Workflow บน Web Application จริง |
| 2 | ยืนยันความถูกต้องของ Calculation Engine (MT + TT) |
| 3 | แสดง Parameter Management ที่ผู้ใช้งานจัดการเองได้ |
| 4 | แสดง Approval Flow ก่อนส่ง HR |
| 5 | แสดง For HR Export Output |

---

## 3. Technology Stack

| Component | Technology | หมายเหตุ |
|---|---|---|
| **Backend API** | .NET Core 10 Web API (C#) | RESTful API, Minimal API หรือ Controller-based |
| **Database** | Microsoft SQL Server | DB: `AJT_SALE_INCENTIVE` (dev: 192.168.11.40) |
| **ORM / Data Access** | Entity Framework Core 10 + Dapper | EF Core สำหรับ CRUD, Dapper สำหรับ SP call |
| **Frontend** | Razor Pages หรือ Blazor Server | ไม่ต้องใช้ React/Angular ใน POC |
| **Auth** | ASP.NET Core Identity (Cookie Auth) | Simple username/password สำหรับ POC |
| **API Docs** | Scalar / Swagger (OpenAPI) | สำหรับ demo และ dev testing |
| **Deployment** | IIS หรือ Docker (Windows Container) | Dev: localhost, Demo: internal server |

---

## 4. ขอบเขต Features (In-Scope)

### 4.1 Module: Period Management
| Feature | รายละเอียด | Priority |
|---|---|---|
| ดู Period List | แสดง FY2026-04 → FY2027-03 พร้อมสถานะ | P1 |
| Set Active Period | กำหนด period ที่ใช้คำนวณ | P1 |
| Close Period | ปิด period เมื่อ approve แล้ว | P2 |

### 4.2 Module: Data Import
| Feature | รายละเอียด | Priority |
|---|---|---|
| Import Sales Actual (CSV) | Upload CSV จาก BI/DWC → `trn_sales_actual` | P1 |
| Import Employee (CSV) | Upload CSV จาก HCM → `mst_employee` | P1 |
| Validation Gate | ตรวจสอบ completeness + hierarchy + mapping ก่อนคำนวณ | P1 |
| ดู Import History | แสดง batch ที่ import แล้ว + สถานะ | P2 |

### 4.3 Module: Calculation Engine
| Feature | รายละเอียด | Priority |
|---|---|---|
| Run MT Calculation | เรียก `usp_run_mt_incentive_calculation @PeriodId` | P1 |
| Run TT Calculation | เรียก `usp_run_tt_incentive_calculation @PeriodCode` | P1 |
| ดู Calculation Run History | แสดง calc_run list + timestamp + rows | P1 |
| ดู Incentive Detail | Breakdown รายสินค้าต่อพนักงาน | P2 |

### 4.4 Module: For HR Output
| Feature | รายละเอียด | Priority |
|---|---|---|
| ดู For HR Summary | ตารางผลลัพธ์ total_variable ต่อพนักงาน | P1 |
| Export For HR (CSV/Excel) | ดาวน์โหลด output ส่ง HR | P1 |
| Compare กับ Previous Run | เปรียบเทียบผลระหว่าง calc_run 2 รอบ | P3 |

### 4.5 Module: Parameter Management
| Feature | รายละเอียด | Priority |
|---|---|---|
| Manage Goal Threshold | CRUD step table (achievement → multiplier) | P1 |
| Manage Incentive Rate | CRUD rate ต่อ position/ws_type | P1 |
| Manage Product Weight | CRUD weight % ต่อ salesman × product (MT) | P2 |
| Manage Shortage Policy | Override achievement กรณีสินค้าขาดแคลน | P2 |
| Manage M_Month | Payment calendar mapping | P2 |
| Manage Fix Rate | Fixed incentive rate ต่อ Job Function | P3 |
| Audit Trail | บันทึกการแก้ไข parameter ทุกรายการ | P2 |

### 4.6 Module: Approval Workflow
| Feature | รายละเอียด | Priority |
|---|---|---|
| Submit for Approval | ส่งผลคำนวณเพื่อขออนุมัติ | P1 |
| Approve / Reject | Manager อนุมัติหรือส่งกลับ | P1 |
| ดู Approval History | Log การอนุมัติ + เหตุผล | P2 |

### 4.7 Module: Dashboard
| Feature | รายละเอียด | Priority |
|---|---|---|
| Summary Card | รอบปัจจุบัน, จำนวนพนักงาน, ยอดรวม incentive | P1 |
| Incentive by Channel | เปรียบเทียบ MT vs TT | P2 |
| Achievement Distribution | กราฟ histogram achievement ของ Staff | P3 |

---

## 5. ขอบเขตที่ไม่รวม (Out-of-Scope สำหรับ Demo POC)

| รายการ | เหตุผล |
|---|---|
| Nintex K2 Workflow | ใช้ custom workflow ใน .NET แทนสำหรับ POC |
| SSRS Reports | ใช้ CSV Export แทนสำหรับ POC |
| SI Channel (S&I) | ยังไม่มี SP + data — ข้าม POC เฟสนี้ |
| LAOS Channel | ยังไม่มี SP — ข้าม POC เฟสนี้ |
| GD Special Incentive | DB schema พร้อม แต่ calculation engine ยังไม่ implement |
| Real-time BI/HCM API integration | POC ใช้ CSV upload แทน API |
| Production Deployment / Security Hardening | POC = demo เท่านั้น |
| Multi-tenant / Role-based Access Control ซับซ้อน | Simple roles สำหรับ POC |

---

## 6. Users และ Roles (POC)

| Role | สิทธิ์หลัก |
|---|---|
| **Admin** | CRUD parameter, manage periods, view all |
| **Analyst** | Run calculation, view results, export |
| **Approver** | Approve/reject calculation results |
| **Viewer** | ดูผลคำนวณ + dashboard เท่านั้น |

---

## 7. Data ที่ใช้ใน POC

| ข้อมูล | แหล่งที่มา | หมายเหตุ |
|---|---|---|
| DB Schema + Stored Procedures | DB ปัจจุบัน `AJT_SALE_INCENTIVE` | deploy แล้ว ใช้ได้ทันที |
| MT Period FY2026-04 data | ใน DB แล้ว (calc_run_id=1019) | ใช้ verify output |
| TT Period FY2026-05 data | ใน DB แล้ว | ใช้ verify output |
| Sample CSV สำหรับ Import | สร้างจาก `stg_bi_sales` schema | ทำ mock data |

---

## 8. Acceptance Criteria (POC Done When)

| # | เงื่อนไข |
|---|---|
| AC-1 | สามารถ Upload CSV actuals และ import เข้า DB ได้ |
| AC-2 | กด "Run MT Calculation" แล้วได้ผลลัพธ์ตรงกับ SP ที่ทดสอบแล้ว |
| AC-3 | กด "Run TT Calculation" แล้วได้ผลลัพธ์ถูกต้อง |
| AC-4 | แสดง For HR Output table และ Export CSV ได้ |
| AC-5 | แก้ Goal Threshold ใน UI แล้วผลคำนวณเปลี่ยนตาม |
| AC-6 | Approval flow: Submit → Approve → Status เปลี่ยนเป็น Approved |
| AC-7 | Dashboard แสดง summary card ของ period ปัจจุบัน |

---

## 9. Constraints และ Assumptions

| # | ประเด็น | รายละเอียด |
|---|---|---|
| C-1 | DB ที่ใช้ | Dev: `192.168.11.40 / AJT_SALE_INCENTIVE` — ใช้ SP และ Views ที่มีอยู่ |
| C-2 | .NET Version | .NET Core 10 (LTS) |
| C-3 | UI Framework | ไม่ใช้ SPA framework ใน POC — Razor Pages หรือ Blazor |
| C-4 | Calculation Logic | ใช้ Stored Procedures ที่มีอยู่ — ไม่ rewrite logic ใน C# |
| C-5 | Approval | Simple DB-based workflow — ไม่ใช้ K2 ใน POC |
| A-1 | SP ทำงานถูกต้อง | MT FY2026-04 (✅) และ TT FY2026-05 (✅) verified แล้ว |
| A-2 | Mock Data | ใช้ข้อมูลจริงจาก Dev DB สำหรับ demo |
