# AJT New Sale Incentive — Manday Estimate Template v2.1

เวอร์ชัน: v2.1  
วันที่: 2026-06-17  
สถานะ: Draft for Review  
จัดทำโดย: AI (GitHub Copilot) — ทบทวนจาก BRD, SRS, SA Design, POC Status + ปรับ Junior DEV Factor (×1.4) + Buffer ~30%

---

## Revision Notes (v1.0 → v2.0 → v2.1)

| รายการ | v1.0 | v2.0 | v2.1 (ฉบับนี้) |
| --- | --- | --- | --- |
| DEV Columns | K2 DEV #1 / K2 DEV #2 / API DEV (แยก 3 column) | DEV รวม (K2×2 + API×1) — column เดียว | เหมือน v2.0 |
| DEV Skill Level | ไม่ระบุ | ไม่ระบุ | **Junior Developer (K2 DEV ×2 + API DEV ×1) — ใช้ factor ×1.4** |
| WP ทั้งหมด | 24 WPs | 25 WPs | **25 WPs** (เท่าเดิม) |
| ฐานข้อมูลที่ใช้ประเมิน | Template skeleton | ทบทวน BRD + SRS + SA Design + POC Status | เหมือน v2.0 + junior factor |
| Buffer Policy | ~12% | 8.2% (18.5 MD) | **~30% ของ base effort (70.5 MD)** |
| Total MD (baseline) | 157.0 MD | 224.5 MD | **304.5 MD** |
| เหตุผลที่ปรับขึ้น | — | ครอบคลุม 4 channels + Prorate + GD | **Junior DEV ×1.4 + SA mentoring +15% + QA +10% + Buffer 30% + DEV ไม่เข้า Design Phase + Architecture: Calc ผ่าน SmartObject/SP, .NET API เฉพาะ Interface** |

---

## Context สำคัญที่ใช้ประเมิน

### POC Status (สถานะที่ทำไปแล้ว)

| งาน | สถานะ | ผลต่อ DEV MD |
| --- | --- | --- |
| DDL 01–39 (ทุก schema) | ✅ Deploy แล้ว | SA/DB design MD ลด |
| TT Calculation SP v9 | ✅ Verified FY2026-05 | DEV-07 (TT engine) MD ลดกว่า channel อื่น |
| MT/SI calculation engine | ⏳ ยังไม่ implement | DEV-06 ต้องทำเต็ม |
| LAOS engine | ⏳ ยังไม่ implement | DEV-08 ต้องทำเต็ม |
| K2 Workflow ทั้งหมด | ⏳ ยังไม่ implement | DEV-01/02/03 ทำเต็ม |
| Prorate policy | ❓ ยังรอ 3+ scenarios | Buffer เพิ่ม DEV-11 |
| GD integration method | ❓ ยังไม่ confirm | Buffer เพิ่ม DEV-09 |

### Assumption หลัก

- 1 Manday = 8 working hours
- DEV (3 คน) = K2 DEV #1 + K2 DEV #2 + API DEV → นับ total MD รวม (pool), max parallel = 3 MD/วัน
- **DEV ทั้ง 3 คนเป็น Junior Developer** → ใช้ factor ×1.4 เทียบกับ mid-level baseline
  - Junior ใช้เวลามากขึ้นใน: learning curve, code review cycles, debugging, rework
  - K2 platform มี complexity สูงสำหรับ junior (Smart Forms + Workflow engine)
- **Calculation Engine ทำผ่าน K2 SmartObject → SQL Server SP/Functions** (ไม่ใช่ .NET Core API)
- **.NET Core API ใช้เฉพาะ Interface External System (BI/DWH/HR)** เท่านั้น
- **SA ต้อง mentor junior DEV** → เพิ่ม SA MD ~15% สำหรับ code review, pair programming, design walkthrough
- **QA ต้อง test มากขึ้น** → เพิ่ม QA MD ~10% เพราะ defect rate สูงกว่า mid-level
- PM participate ทุก WP แต่ intensity ต่างกัน
- SA เสร็จ SA Analysis แล้ว (ลด MD ใน Planning + Design บางส่วน)
- **DEV ไม่มีส่วนร่วมใน Design Phase** → งาน Design เป็นของ PM, BA, SA, QA/Doc เป็นหลัก (ตาม Estimation Context Phase definition)
- **Buffer ~30% ของ base effort** ครอบคลุม: junior rework, policy change, integration glitch, UAT defect, K2 learning curve
- Prorate: กัน buffer พิเศษเพราะ policy ยังไม่ครบ

---

## Work Package Table

> **DEV รวม** = รวม K2 DEV #1 + K2 DEV #2 + API DEV เป็น total MD ของกลุ่ม DEV (3 คน)

### Phase 1: Planning

| WP ID | Work Package | Channel | Complexity | PM | BA | SA | DEV รวม | QA/Doc | Buffer | Total MD |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| P-01 | Project Kickoff, Charter, RAID Log | All | L | 1.5 | 0.5 | 0.5 | 0.0 | 0.0 | 0.5 | 3.0 |
| P-02 | Scope Freeze + Estimation Sign-off | All | L | 1.0 | 1.0 | 0.5 | 0.0 | 0.0 | 1.0 | 3.5 |
| P-03 | Project Schedule + Team Onboarding | All | L | 1.0 | 0.5 | 0.0 | 0.0 | 0.0 | 0.5 | 2.0 |
| **รวม Planning** | | | | **3.5** | **2.0** | **1.0** | **0.0** | **0.0** | **2.0** | **8.5** |

### Phase 2: Design Phase

| WP ID | Work Package | Channel | Complexity | PM | BA | SA | DEV รวม | QA/Doc | Buffer | Total MD |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| D-01 | Requirement Workshop + Policy Clarification (Prorate, GD, Channels) | All | H | 0.5 | 4.0 | 2.5 | 0.0 | 1.0 | 2.5 | 10.5 |
| D-02 | Solution Architecture + Interface Contract (K2/SmartObject/SP/SSRS) | All | H | 0.5 | 1.0 | 3.5 | 0.0 | 0.5 | 1.5 | 7.0 |
| D-03 | K2 Workflow + Smart Form Design (ทุก flow) | All | H | 0.5 | 1.5 | 1.0 | 0.0 | 0.5 | 1.0 | 4.5 |
| D-04 | SP Calculation Engine + .NET API Interface Design Spec | All | H | 0.5 | 1.0 | 2.5 | 0.0 | 0.5 | 1.5 | 6.0 |
| D-05 | DB Model Finalization + Stored Procedure Design | All | M | 0.0 | 0.5 | 2.5 | 0.0 | 0.0 | 1.0 | 4.0 |
| D-06 | SSRS Report Format Design (For HR, Trace Report) | All | M | 0.0 | 1.0 | 0.5 | 0.0 | 1.0 | 1.0 | 3.5 |
| D-07 | SIT/UAT Test Strategy + Test Case Design | All | M | 0.5 | 1.0 | 0.5 | 0.0 | 3.5 | 1.5 | 7.0 |
| **รวม Design** | | | | **2.5** | **10.0** | **13.0** | **0.0** | **7.0** | **10.0** | **42.5** |

### Phase 3: Development Phase

| WP ID | Work Package | Channel | Complexity | PM | BA | SA | DEV รวม | QA/Doc | Buffer | Total MD |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DEV-01 | K2 Master Data Forms (Period, M_Month, Parameters, Rate Tables) | All | M | 0.5 | 0.0 | 0.5 | 7.0 | 0.5 | 2.5 | 11.0 |
| DEV-02 | K2 Import Workflow (BI/HCM upload + Validation Gate trigger) | All | H | 0.5 | 0.5 | 1.0 | 8.5 | 1.0 | 3.5 | 15.0 |
| DEV-03 | K2 Approval Workflow (Draft→Review→Approve→Export) | All | H | 0.5 | 1.0 | 0.5 | 7.0 | 1.0 | 3.0 | 13.0 |
| DEV-04 | SmartObject + SP Common Infrastructure (Auth, DB Layer, Error Handling, Logging) | All | M | 0.5 | 0.0 | 1.0 | 5.5 | 0.5 | 2.5 | 10.0 |
| DEV-05 | SP Validation Gate Engine (Period/Hierarchy/Mapping checks) | All | M | 0.5 | 0.5 | 1.0 | 5.5 | 1.0 | 2.5 | 11.0 |
| DEV-06 | SP MT/SI Calculation Engine (Mapping + Cascade 4 ระดับ) | MT, SI | H | 0.5 | 1.0 | 2.0 | 11.0 | 1.5 | 5.0 | 21.0 |
| DEV-07 | SP TT Calculation Engine (Single-sheet, Refactor จาก SP v9) | TT | M | 0.5 | 0.5 | 1.0 | 5.5 | 0.5 | 2.5 | 10.5 |
| DEV-08 | SP LAOS Calculation Engine (Single-sheet, simpler scope) | LAOS | M | 0.5 | 0.5 | 1.0 | 5.5 | 0.5 | 2.5 | 10.5 |
| DEV-09 | SP GD Special Incentive Engine (4 products × step payout) | MT, TT | M | 0.5 | 0.5 | 1.0 | 5.5 | 1.0 | 2.5 | 11.0 |
| DEV-10 | SP Fixed Rate Engine (Job Function lookup → fixed amount) | MT, TT | L | 0.0 | 0.5 | 0.5 | 3.0 | 0.5 | 1.5 | 6.0 |
| DEV-11 | SP Prorate Logic Engine (≥4 scenarios + policy edge cases) | All | H | 0.5 | 1.0 | 1.0 | 5.5 | 1.0 | 3.0 | 12.0 |
| DEV-12 | Special Adjustment Config + Before/After Audit (Shortage, T_SectAbove, Table) | All | M | 0.5 | 0.5 | 1.0 | 4.0 | 1.0 | 2.0 | 9.0 |
| DEV-13 | For HR Output Generation (Variable + Fixed, M_Month mapping) | All | M | 0.5 | 0.5 | 0.5 | 4.0 | 1.0 | 2.0 | 8.5 |
| DEV-14 | SSRS Reports (For HR print form + Calculation Trace Report) | All | M | 0.0 | 0.5 | 0.5 | 4.0 | 1.0 | 2.0 | 8.0 |
| DEV-15 | Chart.js Dashboard (Achievement summary, by channel/dept/period) | All | M | 0.0 | 0.5 | 0.0 | 4.0 | 0.5 | 1.5 | 6.5 |
| DEV-16 | Audit Trail + Parameter Change Logging (ทุก event, ทุก parameter) | All | M | 0.0 | 0.0 | 0.5 | 3.0 | 0.5 | 1.0 | 5.0 |
| **รวม Development** | | | | **6.0** | **8.0** | **13.0** | **88.5** | **13.0** | **39.5** | **168.0** |

### Phase 4: Stabilizing Phase

| WP ID | Work Package | Channel | Complexity | PM | BA | SA | DEV รวม | QA/Doc | Buffer | Total MD |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| STB-01 | SIT — Common Platform (K2 forms, workflow, import, auth) | All | M | 0.5 | 0.5 | 1.0 | 4.0 | 4.5 | 3.0 | 13.5 |
| STB-02 | SIT — Channel Calculation Engines (MT/TT/SI/LAOS + GD + Fixed) | MT, TT, SI, LAOS | H | 0.5 | 1.0 | 1.0 | 5.5 | 4.5 | 3.5 | 16.0 |
| STB-03 | UAT Support + Defect Fix (Business-driven test round) | All | H | 1.0 | 2.0 | 1.0 | 5.5 | 4.5 | 4.0 | 18.0 |
| STB-04 | Regression Test + Performance Check | All | M | 0.5 | 0.5 | 0.5 | 3.0 | 2.5 | 2.0 | 9.0 |
| **รวม Stabilizing** | | | | **2.5** | **4.0** | **3.5** | **18.0** | **16.0** | **12.5** | **56.5** |

### Phase 5: Go-live Phase

| WP ID | Work Package | Channel | Complexity | PM | BA | SA | DEV รวม | QA/Doc | Buffer | Total MD |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| GL-01 | Cutover Plan + Release Checklist + Go/No-Go Sign-off | All | M | 1.5 | 0.5 | 0.5 | 1.0 | 1.0 | 1.5 | 6.0 |
| GL-02 | Production Deployment + Smoke Test | All | M | 1.0 | 0.0 | 0.5 | 3.0 | 1.0 | 1.5 | 7.0 |
| GL-03 | Hypercare Support (2 สัปดาห์หลัง Go-live) | All | M | 1.5 | 0.5 | 0.5 | 3.0 | 1.0 | 2.0 | 8.5 |
| GL-04 | Handover + Runbook + User Guide Finalization | All | M | 1.0 | 0.5 | 0.5 | 1.0 | 3.0 | 1.5 | 7.5 |
| **รวม Go-live** | | | | **5.0** | **1.5** | **2.0** | **8.0** | **6.0** | **6.5** | **29.0** |

---

## Project Summary Matrix — Role × Phase

| Role | Planning | Design | Development | Stabilizing | Go-live | **Total MD** | **%** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| PM | 3.5 | 2.5 | 6.0 | 2.5 | 5.0 | **19.5** | 6.4% |
| BA | 2.0 | 10.0 | 8.0 | 4.0 | 1.5 | **25.5** | 8.4% |
| SA | 1.0 | 13.0 | 13.0 | 3.5 | 2.0 | **32.5** | 10.7% |
| DEV รวม (K2×2+API×1, **Junior ×1.4**) | 0.0 | 0.0 | 88.5 | 18.0 | 8.0 | **114.5** | 37.6% |
| QA/Doc | 0.0 | 7.0 | 13.0 | 16.0 | 6.0 | **42.0** | 13.8% |
| Buffer (~30%) | 2.0 | 10.0 | 39.5 | 12.5 | 6.5 | **70.5** | 23.2% |
| **รวม** | **8.5** | **42.5** | **168.0** | **56.5** | **29.0** | **304.5** | 100% |

---

## Phase Breakdown Summary

| Phase | MD | % ของโครงการ | หมายเหตุ |
| --- | --- | --- | --- |
| Planning | 8.5 | 2.8% | ลดได้เพราะ SA Analysis + BRD ทำไปแล้ว |
| Design Phase | 42.5 | 14.0% | DEV ไม่เกี่ยวข้อง — เน้น PM/BA/SA/QA เป็นหลัก |
| Development Phase | 168.0 | 55.2% | Heavy DEV — 4 channels + 6 special logic + junior ×1.4 factor |
| Stabilizing Phase | 56.5 | 18.6% | Channel engine test ซับซ้อน + junior defect rate สูงกว่า mid-level |
| Go-live Phase | 29.0 | 9.5% | รวม Hypercare 2 สัปดาห์ + junior handover support |
| **Total** | **304.5** | 100% | |

---

## DEV Breakdown Insight — Pool Analysis

> DEV รวม 114.5 MD จาก pool 3 คน (**Junior Developer** ทั้งหมด, K2 DEV ×2 + API DEV ×1)
> ใช้ factor ×1.4 เทียบกับ mid-level baseline เพื่อรองรับ learning curve, code review cycles, rework
> DEV ไม่มีส่วนร่วมใน Design Phase — เริ่มงานตั้งแต่ Development Phase เป็นต้นไป

| DEV Sub-role | สัดส่วนงาน (ประเมิน) | MD (ประมาณ) |
| --- | --- | --- |
| K2 DEV #1 (Smart Forms + Workflow orchestration) | ~35% | ~40 MD |
| K2 DEV #2 (SmartObject + SP Calculation Engine) | ~35% | ~40 MD |
| API DEV (.NET Core Interface External System BI/DWH/HR) | ~30% | ~34 MD |
| **รวม** | 100% | **~114 MD** |

**หมายเหตุ Parallel:**
- K2 DEV ทั้ง 2 คนสามารถ parallel ได้ในช่วง Development เมื่อ WP แยกกัน (DEV-01/03 vs DEV-02)
- API DEV ร่วมกับ K2 DEV ในช่วงสร้าง SP engine (DEV-04 ถึง DEV-12) และรับผิดชอบ .NET Core API Interface (BI/DWH/HR)
- Peak parallel: Development Phase → 3 คน parallel = สูงสุด 3 MD/วัน → ใช้เวลา ~30 วันทำการสำหรับ Dev Phase (ถ้า full parallel)
- ⚠️ Junior DEV อาจ parallel ได้ไม่เต็มที่เพราะต้องรอ SA review/support

---

## Complexity Legend

| ระดับ | คำอธิบาย | ตัวอย่าง |
| --- | --- | --- |
| **H** (High) | Logic ซับซ้อน, หลาย business rule, integration สูง | MT Cascade Engine, Prorate, Approval Workflow |
| **M** (Medium) | Logic ปานกลาง, business rule ชัดเจน | TT Engine (refactor), SSRS, Dashboard, Validation |
| **L** (Low) | Logic ตรงไปตรงมา, CRUD หรือ simple lookup | Fixed Rate, Period Setup, Kickoff |

---

## Channel Complexity Comparison

| Channel | Calc Type | Complexity | TT SP POC | ผลต่อ DEV |
| --- | --- | --- | --- | --- |
| MT | CASCADE_4_LEVEL + Mapping | H | ❌ ยังไม่ทำ | DEV สูงสุด (13 MD) |
| SI | CASCADE_4_LEVEL (เหมือน MT) | H | ❌ ยังไม่ทำ | ต่ำกว่า MT เพราะ reuse (~50%) |
| TT | SINGLE_SHEET_5_LEVEL_AVG | M | ✅ SP v9 done | DEV ต่ำสุด (4 MD เพราะ refactor จาก SP) |
| LAOS | SINGLE_SHEET (simpler) | M | ❌ ยังไม่ทำ | ต่ำ เพราะ simpler than TT cascade |

> ⚠️ Note: SI share logic กับ MT แต่ไม่ได้แยก WP ออก — DEV-06 ครอบคลุม MT+SI ในคราวเดียว

---

## Risk Register (การประเมินผลกระทบต่อ MD)

| ความเสี่ยง | ความน่าจะเป็น | ผลกระทบ | MD เพิ่มที่คาดการณ์ | Owner |
| --- | --- | --- | --- | --- |
| **Junior DEV learning curve (K2 platform)** | **สูง** | **DEV ช้ากว่าแผน, rework สูง** | **+5–10 MD** | **SA + PM** |
| **Junior DEV code quality issues** | **สูง** | **QA defect rate สูง, re-test cycles เพิ่ม** | **+3–5 MD** | **QA + SA** |
| Prorate policy ยังไม่ครบ (3+ scenarios ❓) | สูง | Rework DEV-11 + retest | +3–5 MD | BA + Business |
| GD integration method ยังไม่ confirm (additive vs separate) | สูง | Rework DEV-09 + DEV-13 | +2–4 MD | BA + Business |
| MT Product Code mapping ยังไม่ครบ (AJA/AMV/FP/QM) | ปานกลาง | Block DEV-06 | +1–2 MD | SA + Business |
| Policy ambiguity (108% → 1.06 vs 1.08) | ต่ำ | Calc error ใน UAT | +1 MD | BA |
| Data quality จาก BI/HCM (period mismatch) | ปานกลาง | SIT blocker | +2–3 MD | DEV |
| K2 platform complexity / learning curve | **สูง** | K2 DEV ช้ากว่าแผน | +5–10 MD | K2 DEV |
| **รวม Risk MD (pessimistic)** | | | **+22–40 MD** | |

> ⚠️ หมายเหตุ: Buffer 70.5 MD (~30%) ครอบคลุม risk บางส่วนแล้ว (junior factor, normal rework) แต่ถ้า risk แบบ pessimistic เกิดทั้งหมด อาจเพิ่มอีก +22–40 MD

---

## Comparison: BRD Estimate vs v1.0 vs v2.0 vs v2.1

| มุมมอง | BRD (original) | v1.0 Template | v2.0 | v2.1 (ฉบับนี้) |
| --- | --- | --- | --- | --- |
| PM | 15 MD | ระบุในตาราง | 21.0 MD* | **19.5 MD** |
| BA | 12 MD | ระบุในตาราง | 26.0 MD* | **25.5 MD** |
| SA | 10 MD | ระบุในตาราง | 30.0 MD | **32.5 MD** |
| DEV รวม (3 คน) | 52 MD (18+18+16) | ระบุแยกคน | **91.0 MD** | **114.5 MD** |
| QA/Doc | 20 MD | ระบุในตาราง | 38.0 MD | **42.0 MD** |
| Buffer | — | ~12% | 18.5 MD (8.2%) | **70.5 MD (~30%)** |
| **Total** | **109 MD** | **157.0 MD** | **224.5 MD** | **304.5 MD** |
| เหตุผลที่ต่าง | BRD = optimistic baseline 2 channels | v1.0 มี 5 phases แต่ไม่ได้ review SA งานจริง | v2.0 ครอบคลุม 4 channels + Prorate + GD + K2 | **v2.1 ปรับ Junior DEV ×1.4 + SA mentor + QA defect + Buffer 30%** |

> *v2.0 มี arithmetic error ใน Summary Matrix (PM/BA) — v2.1 แก้ไขแล้ว

---

## Open Questions (ที่ยังต้องปิดก่อน Baseline Freeze)

| # | คำถาม | ผลกระทบ | Priority |
| --- | --- | --- | --- |
| OQ-01 | Prorate: พนักงานเข้า/ออกกลางเดือน คิดอย่างไร? (Variable + Fixed แยกกัน?) | DEV-11 MD อาจเพิ่ม 3–5 MD | 🔴 สูง |
| OQ-02 | GD Incentive: รวมใน For HR หลัก หรือ export แยก? | DEV-09 + DEV-13 design เปลี่ยน | 🔴 สูง |
| OQ-03 | Product Code: AJA, AMV, FP, QM → MT หรือ TT? | DEV-06 mapping completeness | 🟡 ปานกลาง |
| OQ-04 | GD payout table: RDM + RDNS rate ครบแล้วหรือยัง? | DEV-09 accuracy | 🟡 ปานกลาง |
| OQ-05 | SI channel: ต้องการ dashboard แยก หรือรวมกับ MT? | DEV-15 scope | 🟢 ต่ำ |

---

## Definition of Done (ระดับ Project)

- [ ] ทุก Work Package ผ่าน code review
- [ ] ทุก channel (MT/TT/SI/LAOS) ผ่าน SIT (DEV test cases ตาม BRD TC-001 ถึง TC-008)
- [ ] UAT ผ่าน Business Owner sign-off
- [ ] For HR output ตรงกับ expected ราย period ที่ตกลงไว้
- [ ] Audit Trail บันทึกทุก parameter change ครบ
- [ ] Runbook + User Guide ครบก่อน Go-live
- [ ] Open Questions OQ-01 และ OQ-02 ปิดแล้วก่อน Development Phase เริ่ม

---

*อ้างอิง:*  
- [BRD-SRS_AJT-New-Sale-Incentive_Draft-v0.1_2026-06-12.md](../5.Docs/BRD-SRS_AJT-New-Sale-Incentive_Draft-v0.1_2026-06-12.md)  
- [Sales Incentive System for POC.md](../5.Docs/Sales%20Incentive%20System%20for%20POC.md)  
- [System-Architecture-Design_AJT-New-Sale-Incentive_v1.0_2026-06-13.md](../5.Docs/System-Architecture-Design_AJT-New-Sale-Incentive_v1.0_2026-06-13.md)  
- [AJT_Manday_Estimation_Context.md](AJT_Manday_Estimation_Context.md) — กติกา + Phase definitions  
- [AJT_Manday_Estimate_Template.md](AJT_Manday_Estimate_Template.md) — v1.0 baseline  
- final-docs/AJT_Project-Scope-Summary.md — Scope summary v1.1