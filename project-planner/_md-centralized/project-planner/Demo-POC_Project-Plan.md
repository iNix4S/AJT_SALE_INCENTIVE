# Demo POC — Project Plan
# AJT New Sale Incentive System (.NET Core 10 + MS SQL Server)

**วันที่จัดทำ:** 2026-06-22
**เวอร์ชัน:** v1.0
**สถานะ:** Draft
**อ้างอิง Scope:** `Demo-POC_Scope.md`

---

## 1. ภาพรวม Timeline

```
Phase 0   Phase 1   Phase 2    Phase 3    Phase 4    Phase 5
Setup     Core API  UI Modules Param Mgmt Approval   Demo Polish
Week 1    Week 2    Week 3-4   Week 5     Week 6     Week 7
```

**รวมระยะเวลา:** ~7 สัปดาห์ (ปรับได้ตาม resource)
**Demo Day Target:** หลังสิ้นสุด Phase 5

---

## 2. Phases และ Tasks

### Phase 0: Project Setup (Week 1)

| Task | รายละเอียด | Effort | Priority |
|---|---|---|---|
| P0-1 | สร้าง .NET Core 10 Solution Structure (WebAPI + Razor/Blazor) | 0.5 MD | P1 |
| P0-2 | ตั้งค่า Database Connection (EF Core + Dapper) | 0.5 MD | P1 |
| P0-3 | สร้าง ASP.NET Core Identity (User + Role seed) | 1 MD | P1 |
| P0-4 | ตั้งค่า Logging (Serilog) + Error Handling Middleware | 0.5 MD | P1 |
| P0-5 | ตั้งค่า Swagger/Scalar (API Docs) | 0.25 MD | P2 |
| P0-6 | CI/CD พื้นฐาน (local build script) | 0.25 MD | P3 |

**Phase 0 Total: ~3 MD**

---

### Phase 1: Core API — Period + Calculation (Week 2)

| Task | รายละเอียด | Effort | Priority |
|---|---|---|---|
| P1-1 | Period API: GET list, SET active period | 0.5 MD | P1 |
| P1-2 | Calculation API: POST run MT (`usp_run_mt_incentive_calculation`) | 0.5 MD | P1 |
| P1-3 | Calculation API: POST run TT (`usp_run_tt_incentive_calculation`) | 0.5 MD | P1 |
| P1-4 | Calculation Run History API: GET calc_run list | 0.5 MD | P1 |
| P1-5 | For HR Output API: GET summary + GET detail by calc_run_id | 1 MD | P1 |
| P1-6 | Export For HR: CSV download endpoint | 0.5 MD | P1 |

**Phase 1 Total: ~3.5 MD**

---

### Phase 2: UI Modules — Period + Calculation + For HR (Week 3–4)

| Task | รายละเอียด | Effort | Priority |
|---|---|---|---|
| P2-1 | Layout + Navigation menu (Dashboard, Periods, Calc, Parameters, Approvals) | 1 MD | P1 |
| P2-2 | Period List page (table + set active + close) | 1 MD | P1 |
| P2-3 | Calculation page: Run MT / Run TT + Run History table | 1.5 MD | P1 |
| P2-4 | For HR Output page: summary table + export button | 1.5 MD | P1 |
| P2-5 | Incentive Detail modal (breakdown รายสินค้า) | 1 MD | P2 |
| P2-6 | CSV Import page (Actuals + Employee) + validation result display | 2 MD | P1 |
| P2-7 | Dashboard page (summary cards + basic stats) | 1 MD | P1 |

**Phase 2 Total: ~9 MD**

---

### Phase 3: Parameter Management UI (Week 5)

| Task | รายละเอียด | Effort | Priority |
|---|---|---|---|
| P3-1 | Goal Threshold CRUD page | 1 MD | P1 |
| P3-2 | Incentive Rate CRUD page | 1 MD | P1 |
| P3-3 | Shortage Policy CRUD page | 1 MD | P2 |
| P3-4 | Product Weight CRUD page (MT) | 1 MD | P2 |
| P3-5 | M_Month management page | 0.5 MD | P2 |
| P3-6 | Audit Trail page (parameter change log) | 1 MD | P2 |

**Phase 3 Total: ~5.5 MD**

---

### Phase 4: Approval Workflow (Week 6)

| Task | รายละเอียด | Effort | Priority |
|---|---|---|---|
| P4-1 | Approval workflow DB tables (`trn_calc_approval`) | 0.5 MD | P1 |
| P4-2 | Submit for Approval API + UI button | 0.5 MD | P1 |
| P4-3 | Approve / Reject API + UI (Approver role) | 1 MD | P1 |
| P4-4 | Approval History page | 0.5 MD | P2 |
| P4-5 | Email notification (optional — mock SMTP) | 1 MD | P3 |

**Phase 4 Total: ~3.5 MD**

---

### Phase 5: Demo Polish + Testing (Week 7)

| Task | รายละเอียด | Effort | Priority |
|---|---|---|---|
| P5-1 | End-to-End walkthrough test (Happy Path) | 1 MD | P1 |
| P5-2 | UI polish + responsive layout | 1 MD | P2 |
| P5-3 | Seed data script สำหรับ Demo Day reset | 0.5 MD | P1 |
| P5-4 | Demo script + slide สรุป | 1 MD | P1 |
| P5-5 | Bug fixing | 1 MD | P1 |
| P5-6 | Deployment ไป Demo server | 0.5 MD | P1 |

**Phase 5 Total: ~5 MD**

---

## 3. สรุป Effort ทั้งหมด

| Phase | MD |
|---|---|
| Phase 0: Setup | 3 |
| Phase 1: Core API | 3.5 |
| Phase 2: UI Modules | 9 |
| Phase 3: Parameter Management | 5.5 |
| Phase 4: Approval Workflow | 3.5 |
| Phase 5: Demo Polish | 5 |
| **รวม** | **~29.5 MD** |

> หมายเหตุ: P3 (Priority 3) tasks สามารถตัดออกได้ถ้า timeline ตึง

**Estimate ถ้าตัด P3 tasks ออก:** ~26 MD

---

## 4. Milestones

| Milestone | เงื่อนไข Done | Target |
|---|---|---|
| M0: Environment Ready | Build ผ่าน, DB connect ได้, Login ใช้ได้ | End of Week 1 |
| M1: Calculation Works | กด Run MT/TT แล้วได้ผล + Export CSV ได้ | End of Week 2 |
| M2: Core UI Complete | Period, Calc, For HR, Import pages ใช้งานได้ | End of Week 4 |
| M3: Full Feature | Parameter + Approval + Dashboard ใช้งานได้ | End of Week 6 |
| M4: Demo Ready | E2E test ผ่าน, Seed data พร้อม, Deploy เสร็จ | End of Week 7 |

---

## 5. Solution Structure (.NET Core 10)

```
AjtIncentive.sln
├── src/
│   ├── AjtIncentive.Web/              Razor Pages / Blazor Server UI
│   │   ├── Pages/
│   │   │   ├── Dashboard/
│   │   │   ├── Periods/
│   │   │   ├── Calculation/
│   │   │   ├── ForHR/
│   │   │   ├── Parameters/
│   │   │   └── Approvals/
│   │   └── wwwroot/
│   │
│   ├── AjtIncentive.Api/              Web API (optional — if separate API)
│   │   └── Controllers/
│   │
│   ├── AjtIncentive.Application/      Use Cases / Services
│   │   ├── Calculation/
│   │   ├── Import/
│   │   ├── Parameters/
│   │   └── Approvals/
│   │
│   ├── AjtIncentive.Domain/           Entities, Enums, Domain Models
│   │
│   └── AjtIncentive.Infrastructure/   EF Core DbContext, Dapper SP Caller, Repos
│       ├── Data/
│       │   ├── AjtIncentiveDbContext.cs
│       │   └── Configurations/
│       └── StoredProcedures/
│           ├── MtCalculationRunner.cs
│           └── TtCalculationRunner.cs
│
├── tests/
│   ├── AjtIncentive.UnitTests/
│   └── AjtIncentive.IntegrationTests/
│
└── scripts/
    ├── seed-demo-data.sql             Reset script สำหรับ Demo Day
    └── deploy.ps1
```

---

## 6. Database: Stored Procedures ที่ใช้

| SP | ใช้ใน Phase | Call จาก |
|---|---|---|
| `usp_run_mt_incentive_calculation` | P1 | `MtCalculationRunner.cs` |
| `usp_run_tt_incentive_calculation` | P1 | `TtCalculationRunner.cs` |
| `usp_check_tt_incentive_result` | P2 (verify) | Integration Test |

---

## 7. Risks และ Mitigation

| Risk | ระดับ | Mitigation |
|---|---|---|
| .NET Core 10 breaking changes จาก 8/9 | Low | ใช้ LTS release, test early |
| EF Core scaffold กับ DB schema ปัจจุบัน | Medium | Scaffold แล้วตรวจสอบ entity ก่อน P1 |
| Approval table ยังไม่มีใน DB | Medium | สร้าง DDL ใน P4-1 ก่อน implement |
| Demo server ติดตั้งไม่ทัน | Low | เตรียม localhost fallback |
| Scope creep จาก stakeholder | Medium | ยึด `Demo-POC_Scope.md` เป็น baseline |

---

## 8. Definition of Done (DoD)

- [ ] Code build ผ่านโดยไม่มี error/warning ร้ายแรง
- [ ] Happy Path E2E ทำงานได้ครบ: Import → Validate → Calculate → View → Approve → Export
- [ ] ผล For HR ตรงกับ SP output ที่ verified แล้ว (MT FY2026-04, TT FY2026-05)
- [ ] Demo script ทดสอบแล้ว ≥ 2 รอบ
- [ ] Seed data script reset ระบบกลับ baseline ได้
