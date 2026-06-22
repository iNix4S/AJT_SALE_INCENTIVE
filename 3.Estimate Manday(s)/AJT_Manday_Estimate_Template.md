# AJT Manday Estimate Template

วันที่: 2026-06-16
เวอร์ชัน: v1.0
วัตถุประสงค์: เทมเพลตสำหรับกรอกตัวเลข Manday จริง แยกตาม Work Package, Role, และ Phase

---

## 1) กติกาการกรอกตัวเลข

- หน่วยทุกช่องเป็น MD (1 MD = 8 ชั่วโมง)
- กรอกตัวเลขเป็นทศนิยมได้ เช่น 0.5, 1.25, 3.0
- K2 DEV มี 2 คน ให้กรอกแยกคอลัมน์ K2 DEV #1 และ K2 DEV #2
- ช่อง Total MD ต่อแถว = PM + BA + SA + K2#1 + K2#2 + API + QA/Doc + Buffer
- ห้ามใส่ MD ติดลบ

---

## 2) Input Assumptions (กรอกก่อนเริ่ม Estimate)

| รายการ | ค่า | หมายเหตุ |
|---|---:|---|
| Working Hour ต่อ 1 MD | 8 | ค่ามาตรฐาน |
| Risk Multiplier (Default) | 1.00 | ปรับตามความเสี่ยง |
| Rework Multiplier (Default) | 1.00 | ปรับเมื่อ policy ยังไม่นิ่ง |
| Integration Buffer % | 0 | กรอกเป็น % เพิ่มจาก Base MD |
| QA Regression Buffer % | 0 | กรอกเป็น % เพิ่มจาก Base MD |
| Go-live Buffer % | 0 | กรอกเป็น % เพิ่มจาก Base MD |

---

## 3) Detailed Estimate by Work Package

| WP ID | Work Package | Phase | Channel Impact | Complexity | PM | BA | SA | K2 DEV #1 | K2 DEV #2 | API DEV | QA/Doc | Buffer | Total MD |
|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| P-01 | Project kickoff and baseline planning | Planning | Common | M | 1.0 | 0.5 | 0.5 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 2.0 |
| P-02 | Scope confirmation and RAID setup | Planning | Common | M | 1.0 | 1.0 | 0.5 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 2.5 |
| P-03 | Resource and phase plan freeze | Planning | Common | M | 1.0 | 0.5 | 0.5 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 2.0 |
| D-01 | Requirement workshop (4 channels) | Design Phase | MT/TT/SI/LAOS | L | 0.5 | 3.0 | 2.0 | 0.0 | 0.0 | 0.0 | 0.5 | 0.5 | 6.5 |
| D-02 | Prorate policy definition (4 scenarios) | Design Phase | Common | L | 0.5 | 2.0 | 2.0 | 0.0 | 0.0 | 0.0 | 0.5 | 0.5 | 5.5 |
| D-03 | Special Adjustment rule design | Design Phase | Common | L | 0.5 | 1.5 | 2.0 | 0.0 | 0.0 | 0.0 | 0.5 | 0.5 | 5.0 |
| D-04 | K2 workflow and approval design | Design Phase | Common | M | 0.5 | 1.0 | 1.0 | 1.0 | 1.0 | 0.0 | 0.5 | 0.5 | 5.5 |
| D-05 | API and integration contract design | Design Phase | Common | M | 0.5 | 0.5 | 1.5 | 0.0 | 0.0 | 1.5 | 0.5 | 0.5 | 5.0 |
| D-06 | SIT/UAT strategy and test coverage matrix | Design Phase | Common | M | 0.5 | 0.5 | 0.5 | 0.0 | 0.0 | 0.0 | 2.0 | 0.5 | 4.0 |
| DEV-01 | K2 forms and workflow build (common flow) | Development Phase | Common | L | 0.5 | 0.0 | 1.0 | 4.0 | 4.0 | 0.0 | 0.5 | 1.0 | 11.0 |
| DEV-02 | API core service and auth/integration | Development Phase | Common | L | 0.5 | 0.0 | 1.0 | 0.0 | 0.0 | 4.0 | 0.5 | 1.0 | 7.0 |
| DEV-03 | MT engine implementation | Development Phase | MT | XL | 0.5 | 0.5 | 1.0 | 1.5 | 1.5 | 4.0 | 1.0 | 1.0 | 11.0 |
| DEV-04 | TT engine hardening and refactor to scope | Development Phase | TT | M | 0.5 | 0.5 | 1.0 | 1.0 | 1.0 | 2.0 | 0.5 | 0.5 | 7.0 |
| DEV-05 | SI engine implementation | Development Phase | SI | L | 0.5 | 0.5 | 1.0 | 1.0 | 1.0 | 2.5 | 0.5 | 0.5 | 7.5 |
| DEV-06 | LAOS engine implementation | Development Phase | LAOS | M | 0.5 | 0.5 | 1.0 | 0.5 | 0.5 | 2.0 | 0.5 | 0.5 | 6.0 |
| DEV-07 | Prorate logic implementation | Development Phase | Common | L | 0.5 | 0.5 | 1.0 | 1.0 | 1.0 | 2.0 | 0.5 | 1.0 | 7.5 |
| DEV-08 | Special Adjustment implementation | Development Phase | Common | L | 0.5 | 0.5 | 1.0 | 1.0 | 1.0 | 2.0 | 0.5 | 1.0 | 7.5 |
| DEV-09 | Reports and export package (For HR) | Development Phase | Common | M | 0.5 | 0.0 | 0.5 | 0.5 | 0.5 | 1.5 | 1.0 | 0.5 | 5.0 |
| STB-01 | SIT execution and defect triage | Stabilizing Phase | Common | L | 0.5 | 0.5 | 1.0 | 2.0 | 2.0 | 2.0 | 2.5 | 1.0 | 11.5 |
| STB-02 | UAT support and fix/retest | Stabilizing Phase | Common | L | 0.5 | 1.0 | 1.0 | 2.0 | 2.0 | 2.0 | 2.0 | 1.0 | 11.5 |
| STB-03 | Performance and data reconciliation | Stabilizing Phase | Common | M | 0.5 | 0.5 | 1.0 | 0.5 | 0.5 | 1.5 | 1.0 | 0.5 | 6.0 |
| GL-01 | Cutover planning and release checklist | Go-live Phase | Common | M | 1.0 | 0.5 | 0.5 | 0.5 | 0.5 | 0.5 | 1.0 | 0.5 | 5.0 |
| GL-02 | Go-live deployment and smoke test | Go-live Phase | Common | M | 0.5 | 0.0 | 0.5 | 1.0 | 1.0 | 1.0 | 1.0 | 0.5 | 5.5 |
| GL-03 | Hypercare, handover, closeout docs | Go-live Phase | Common | M | 1.0 | 0.5 | 0.5 | 0.5 | 0.5 | 0.5 | 2.0 | 0.5 | 6.0 |

> หมายเหตุ: ตัวเลขที่ใส่ไว้เป็น baseline ตั้งต้น ทีมสามารถแก้เป็นค่าจริงได้ทันที

---

## 4) Summary MD by Role x Phase

### 4.1 Role x Phase Matrix (กรอก/คำนวณจากตารางข้อ 3)

| Role | Planning | Design Phase | Development Phase | Stabilizing Phase | Go-live Phase | Total MD |
|---|---:|---:|---:|---:|---:|---:|
| PM | 3.0 | 3.0 | 4.5 | 1.5 | 2.5 | 14.5 |
| BA | 2.0 | 8.5 | 3.0 | 2.0 | 1.0 | 16.5 |
| SA | 1.5 | 9.0 | 8.5 | 3.0 | 1.5 | 23.5 |
| K2 DEV #1 | 0.0 | 2.0 | 11.5 | 4.5 | 2.0 | 20.0 |
| K2 DEV #2 | 0.0 | 2.0 | 11.5 | 4.5 | 2.0 | 20.0 |
| API DEV | 0.0 | 1.5 | 20.0 | 5.5 | 2.0 | 29.0 |
| QA and Documenter | 0.0 | 4.5 | 5.5 | 5.5 | 4.0 | 19.5 |
| Buffer | 0.0 | 3.0 | 7.0 | 2.5 | 1.5 | 14.0 |
| Total MD per Phase | 6.5 | 33.5 | 71.5 | 29.0 | 16.5 | 157.0 |

### 4.2 Team Capacity Check (สำหรับแปลง MD เป็น Duration)

| รายการ | ค่า |
|---|---:|
| Total Project MD | 157.0 |
| จำนวนคนในทีม | 7 |
| Capacity ต่อวัน (ทีมเต็ม) | 7.0 MD/day |
| Duration เชิงทฤษฎี (157/7) | 22.4 วันทำงาน |

> Duration จริงจะมากกว่าค่าเชิงทฤษฎี เนื่องจาก dependency, review gate, UAT window และรอบแก้ defect

---

## 5) Phase Summary (ใช้รายงานผู้บริหาร)

| Phase | Total MD | MD % | Key Output |
|---|---:|---:|---|
| Planning | 6.5 | 4.1% | baseline plan, scope confirmation |
| Design Phase | 33.5 | 21.3% | approved design and test strategy |
| Development Phase | 71.5 | 45.5% | build complete and unit tested |
| Stabilizing Phase | 29.0 | 18.5% | SIT/UAT passed and critical defects closed |
| Go-live Phase | 16.5 | 10.5% | deployment, hypercare, handover |
| Total | 157.0 | 100.0% | project complete |

---

## 6) ช่องสำหรับ Assumption และ Open Questions

### 6.1 Assumptions

- [ ] Policy Prorate 4 scenarios ได้รับอนุมัติจาก HR/Finance
- [ ] GD payout integration rule ชัดเจน (รวม For HR หรือแยก output)
- [ ] BI/HCM feed พร้อมตาม SLA
- [ ] UAT participant พร้อมตามแผน

### 6.2 Open Questions

1. LAOS production logic ใช้ flow ใดเทียบเท่าใน For HR output
2. Special Situation อนุมัติโดย role ใดและ SLA เท่าใด
3. หาก policy เปลี่ยนหลัง Development จะเปิด CR รอบใด

---

## 7) วิธีใช้งานไฟล์นี้

1. แก้ตัวเลข MD ราย Work Package ในตารางข้อ 3 ให้เป็นค่าจริง
2. ปรับตาราง Role x Phase ในข้อ 4 ให้ตรงกับผลรวมจริง
3. ตรวจความสมดุลของ MD ต่อ Phase ในข้อ 5
4. freeze พร้อม Assumptions/Open Questions ก่อนส่งอนุมัติ
