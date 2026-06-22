# Copilot Chat Log — 2026-06-16 (#002)

## 1) วัตถุประสงค์ของงานรอบนี้

สร้างไฟล์ Manday Estimate Template v2.0 โดย:

1. ทบทวนข้อมูล project ทั้งหมดก่อนประเมิน (BRD, SRS, SA Design, POC Status)
2. รวม K2 DEV #1 + K2 DEV #2 + API DEV เป็น **"DEV รวม (3 คน)"** column เดียว
3. ปรับตัวเลขให้สะท้อนขอบเขต 4 channels + special logic ครบ

---

## 2) สรุปสิ่งที่ดำเนินการแล้ว

### 2.1 ทบทวนแหล่งข้อมูลก่อนประเมิน

อ่านเอกสารหลักดังนี้:
- `5.Docs/Sales Incentive System for POC.md` — Development Scope 26 items, Manday BRD baseline
- `5.Docs/BRD-SRS_AJT-New-Sale-Incentive_Draft-v0.1_2026-06-12.md` — In/Out scope, Business Drivers
- `5.Docs/System-Architecture-Design_AJT-New-Sale-Incentive_v1.0_2026-06-13.md` — Tech stack, Component architecture

### 2.2 สร้าง AJT_Manday_Estimate_Template_v2.md (สำเร็จ)

**Path:** `3.Estimate Manday(s)/AJT_Manday_Estimate_Template_v2.md`

**โครงสร้างตาราง:** WP ID | Work Package | Channel | Complexity | PM | BA | SA | DEV รวม | QA/Doc | Buffer | Total MD

**WPs ทั้งหมด:** 25 WPs แบ่ง 5 phases:
- Planning: P-01 ถึง P-03 (3 WPs)
- Design: D-01 ถึง D-07 (7 WPs)
- Development: DEV-01 ถึง DEV-16 (16 WPs)
- Stabilizing: STB-01 ถึง STB-04 (4 WPs)
- Go-live: GL-01 ถึง GL-04 (4 WPs)

---

## 3) ผลลัพธ์หลักของไฟล์ v2.0

### Project Summary Matrix

| Role | Planning | Design | Development | Stabilizing | Go-live | **Total MD** | **%** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| PM | 3.5 | 3.0 | 7.0 | 2.5 | 5.0 | **21.0** | 9.4% |
| BA | 2.0 | 10.0 | 8.5 | 4.0 | 1.5 | **26.0** | 11.6% |
| SA | 1.0 | 11.0 | 12.5 | 3.5 | 2.0 | **30.0** | 13.4% |
| DEV รวม (K2×2+API×1) | 0.0 | 9.0 | 64.0 | 13.0 | 5.0 | **91.0** | 40.5% |
| QA/Doc | 0.0 | 6.5 | 11.5 | 14.0 | 6.0 | **38.0** | 16.9% |
| Buffer | 0.0 | 3.5 | 9.5 | 3.5 | 2.0 | **18.5** | 8.2% |
| **รวม** | **6.5** | **43.0** | **113.0** | **40.5** | **21.5** | **224.5** | 100% |

### Comparison: BRD vs v1.0 vs v2.0

| เอกสาร | Total MD | DEV | หมายเหตุ |
| --- | --- | --- | --- |
| BRD (original) | 109 MD | 52 MD | Optimistic, 2 channels |
| v1.0 Template | 157 MD | แยก 3 คน | 5 phases แต่ไม่ได้ review SA จริง |
| **v2.0 (ใหม่)** | **224.5 MD** | **91 MD รวม** | 4 channels + Prorate + GD + K2 full build |

---

## 4) ไฟล์ที่เกี่ยวข้อง/ถูกแก้ไข

- **สร้างใหม่:** `3.Estimate Manday(s)/AJT_Manday_Estimate_Template_v2.md`
- **อ้างอิง:** `3.Estimate Manday(s)/AJT_Manday_Estimation_Context.md` (กติกา v1.0)
- **อ้างอิง:** `3.Estimate Manday(s)/AJT_Manday_Estimate_Template.md` (v1.0 baseline)
- **อ้างอิง:** `final-docs/AJT_Project-Scope-Summary.md` (Scope v1.1)

---

## 5) สถานะปัจจุบัน

### สถานะเอกสาร PM/SA
| ไฟล์ | สถานะ | เวอร์ชัน |
| --- | --- | --- |
| `final-docs/AJT_Project-Scope-Summary.md` | ✅ Ready | v1.1 |
| `3.Estimate Manday(s)/AJT_Manday_Estimation_Context.md` | ✅ Ready | v1.0 |
| `3.Estimate Manday(s)/AJT_Manday_Estimate_Template.md` | ✅ Archive | v1.0 |
| `3.Estimate Manday(s)/AJT_Manday_Estimate_Template_v2.md` | ✅ Draft for Review | v2.0 |

### สถานะระบบ/เทคนิค (ภาพรวม)
- **DDL 01–39:** ✅ Deploy แล้วทั้งหมด
- **TT Calculation SP v9:** ✅ Verified FY2026-05 (160 rows, 22 persons)
- **MT/SI engine:** ⏳ ยังไม่ implement (DEV-06 สูงสุดใน list — 13 MD)
- **LAOS engine:** ⏳ ยังไม่ implement
- **K2 Workflow:** ⏳ ยังไม่ implement (DEV-01/02/03)
- **Prorate policy:** ❓ ยังรอยืนยัน 3+ scenarios
- **GD integration method:** ❓ ยังไม่ confirm (additive vs separate)

---

## 6) Open Questions ที่ต้องปิดก่อน Baseline Freeze

| # | คำถาม | ผลกระทบ | Priority |
| --- | --- | --- | --- |
| OQ-01 | Prorate: พนักงานเข้า/ออกกลางเดือน — Variable + Fixed แยกกัน? | DEV-11 +3–5 MD ถ้า rework | 🔴 สูง |
| OQ-02 | GD Incentive: รวมใน For HR หลัก หรือ export แยก? | DEV-09 + DEV-13 design เปลี่ยน | 🔴 สูง |
| OQ-03 | Product Code: AJA, AMV, FP, QM → MT หรือ TT? | DEV-06 mapping completeness | 🟡 ปานกลาง |
| OQ-04 | GD payout table: RDM + RDNS rate ครบแล้วหรือยัง? | DEV-09 accuracy | 🟡 ปานกลาง |
| OQ-05 | SI channel: dashboard แยก หรือรวมกับ MT? | DEV-15 scope | 🟢 ต่ำ |

---

## 7) ความเสี่ยงหลัก (Risk Register Summary)

| ความเสี่ยง | ผลกระทบ MD |
| --- | --- |
| Prorate policy ยังไม่ครบ | +3–5 MD |
| GD integration ยังไม่ confirm | +2–4 MD |
| MT Product Code ยังไม่ครบ | +1–2 MD |
| K2 platform complexity / learning curve | +3–6 MD |
| **รวม Pessimistic Risk** | **+12–21 MD** |

---

## 8) ขั้นตอนถัดไป (สำหรับ Agent คนต่อไป)

1. **[เร่งด่วน]** ปิด OQ-01 (Prorate) และ OQ-02 (GD method) กับ Business/HR ก่อน Development Phase เริ่ม
2. เมื่อ Business ตอบ OQ-01/02 → ปรับตัวเลข DEV-11 และ DEV-09/DEV-13 ใน v2.0
3. Review v2.0 กับ PM + Business Owner เพื่อ sign-off Estimate Baseline
4. นำ Total MD 224.5 ไป map กับ calendar จริง (เริ่มกี่วัน, ส่งมอบเมื่อไหร่)
5. เตรียม Release Plan / Delivery Timeline จาก phase breakdown ใน v2.0

---

## 9) ภาพรวมโปรเจกต์ (Context สำหรับ Agent ถัดไป)

### Tech Stack
- Nintex K2 Workflow + Smart Forms — Orchestration + UI
- .NET Core 10 API — Calculation Engine
- SQL Server (AJT_SIS) — Data, Master, Audit
- SSRS — Print output
- Chart.js — Dashboard

### 4 Channels
| Channel | calc_type | Status |
| --- | --- | --- |
| MT | CASCADE_4_LEVEL | ⏳ ยังไม่ implement |
| TT | SINGLE_SHEET_5_LEVEL_AVG | ✅ SP v9 done |
| SI | CASCADE_4_LEVEL | ⏳ ยังไม่ implement |
| LAOS | SINGLE_SHEET | ⏳ ยังไม่ implement |

### Team (7 คน)
PM(1) | BA(1) | SA(1) | K2 DEV(2) | API DEV(1) | QA/Doc(1)

### DB Connection
`Server=localhost,1437;Database=AJT_SIS;User Id=sa;Password=P@ssw0rd;Encrypt=True;TrustServerCertificate=True`

---

*สร้างโดย: GitHub Copilot | วันที่: 2026-06-16*
