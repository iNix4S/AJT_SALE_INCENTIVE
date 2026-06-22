# Copilot Chat Log — 2026-06-16 (#003)

## 1) วัตถุประสงค์ของงานรอบนี้

ปิดงานสำหรับ session 2026-06-16 โดยสรุปงานทั้งหมดที่ดำเนินการตลอดวัน และบันทึก context ครบสำหรับ Agent คนถัดไป

---

## 2) สรุปงานทั้งหมดที่ทำในวันนี้ (2026-06-16)

| ลำดับ | งาน | ไฟล์ | สถานะ |
| --- | --- | --- | --- |
| 1 | อัปเดต Project Scope Summary ให้ครบ 12 sections (Prorate, Special Adjustment, 4 channels) | `final-docs/AJT_Project-Scope-Summary.md` (v1.1) | ✅ |
| 2 | สร้าง Manday Estimation Context (กติกาการนับ MD, Phase definitions, Buffer rules) | `3.Estimate Manday(s)/AJT_Manday_Estimation_Context.md` (v1.0) | ✅ |
| 3 | สร้าง Manday Estimate Template v1.0 (24 WPs, 8 roles, 5 phases, baseline 157 MD) | `3.Estimate Manday(s)/AJT_Manday_Estimate_Template.md` (v1.0) | ✅ |
| 4 | สร้าง Manday Estimate Template v2.0 (25 WPs, DEV รวม 3 คน, ทบทวน project ก่อนประเมิน, 224.5 MD) | `3.Estimate Manday(s)/AJT_Manday_Estimate_Template_v2.md` (v2.0) | ✅ |
| 5 | สร้าง chat-log #001 สรุปงาน scope summary update | `chat-log/copilot_2026.06.16_001.md` | ✅ |
| 6 | สร้าง chat-log #002 สรุปงาน Estimate v2.0 | `chat-log/copilot_2026.06.16_002.md` | ✅ |
| 7 | สร้าง chat-log #003 (ไฟล์นี้) — session close summary | `chat-log/copilot_2026.06.16_003.md` | ✅ |

---

## 3) สถานะเอกสาร PM/SA (ภาพรวมล่าสุด)

| ไฟล์ | เวอร์ชัน | สถานะ | ใช้งาน |
| --- | --- | --- | --- |
| `final-docs/AJT_Project-Scope-Summary.md` | v1.1 | ✅ Ready | Reference หลักสำหรับทุก role |
| `3.Estimate Manday(s)/AJT_Manday_Estimation_Context.md` | v1.0 | ✅ Ready | กติกาการประเมิน MD |
| `3.Estimate Manday(s)/AJT_Manday_Estimate_Template.md` | v1.0 | ✅ Archive | Baseline เก่า (157 MD) |
| `3.Estimate Manday(s)/AJT_Manday_Estimate_Template_v2.md` | v2.0 | ✅ Draft for Review | Estimate ใหม่ที่สมบูรณ์กว่า (224.5 MD) |

---

## 4) สถานะระบบ/เทคนิค (ภาพรวม ณ 2026-06-16)

| Component | สถานะ | หมายเหตุ |
| --- | --- | --- |
| DDL 01–39 | ✅ Deployed | ทุก schema พร้อม |
| TT SP v9 | ✅ Verified | FY2026-05, 160 rows, 22 persons |
| MT/SI Engine | ⏳ Pending | DEV-06 — ซับซ้อนที่สุด (13 MD) |
| LAOS Engine | ⏳ Pending | DEV-08 |
| K2 Workflow | ⏳ Pending | DEV-01/02/03 |
| Prorate Logic | ❓ Policy pending | OQ-01 ยังรอ Business |
| GD Integration | ❓ Method pending | OQ-02 ยังรอ confirm |

---

## 5) Open Questions สำคัญ (ต้องปิดก่อน Development เริ่ม)

| # | คำถาม | Priority | Owner |
| --- | --- | --- | --- |
| OQ-01 | Prorate: พนักงานเข้า/ออกกลางเดือน คิดอย่างไร? (Variable + Fixed แยกกัน?) | 🔴 สูง | BA + Business/HR |
| OQ-02 | GD Incentive: รวมใน For HR หลัก หรือ export แยก? | 🔴 สูง | BA + Business |
| OQ-03 | Product Code: AJA, AMV, FP, QM → MT หรือ TT? | 🟡 ปานกลาง | SA + Business |
| OQ-04 | GD payout table: RDM + RDNS rate ครบแล้วหรือยัง? | 🟡 ปานกลาง | BA |
| OQ-05 | SI channel: Dashboard แยก หรือรวมกับ MT? | 🟢 ต่ำ | PM + Business |

---

## 6) ขั้นตอนถัดไป (สำหรับ Agent คนต่อไป)

1. **[เร่งด่วน]** จัด workshop ปิด OQ-01 + OQ-02 กับ Business/HR ก่อน Development Phase เริ่ม
2. เมื่อ OQ-01/02 ปิด → ปรับตัวเลข DEV-11 และ DEV-09/DEV-13 ใน `AJT_Manday_Estimate_Template_v2.md`
3. นำ Estimate v2.0 (224.5 MD) เข้า review กับ PM + Business Owner เพื่อ sign-off baseline
4. แปลง phase breakdown ใน v2.0 → Delivery Calendar / Release Plan
5. เตรียม Test Strategy ครบ 4 channels (MT/TT/SI/LAOS) + GD + Prorate scenarios

---

## 7) Context สำคัญสำหรับ Agent ถัดไป

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

### DB Connection
`Server=localhost,1437;Database=AJT_SIS;User Id=sa;Password=P@ssw0rd;Encrypt=True;TrustServerCertificate=True`

### Team (7 คน)
PM(1) | BA(1) | SA(1) | K2 DEV(2) | API DEV(1) | QA/Doc(1)

### Estimate Summary
- **Total Project MD:** 224.5 MD
- **DEV รวม (3 คน):** 91.0 MD (40.5%)
- **Buffer:** 18.5 MD (8.2%)
- **Risk MD เพิ่มได้:** +12–21 MD (pessimistic)

---

*สร้างโดย: GitHub Copilot | วันที่: 2026-06-16 | Session close*
