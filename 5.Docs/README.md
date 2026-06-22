# 5.Docs — AJT New Sale Incentive (Business-Ready Documents)

เวอร์ชัน: Draft v0.2  
วันที่: 2026-06-13  
สถานะ: สำหรับ Review และ Approval

---

## 📋 เนื้อหา (Contents)

โฟลเดอร์นี้เก็บเอกสารระดับ Business ที่ใช้เพื่อการตัดสินใจ อนุมัติ และวางแผนโครงการ ทั้งในรูปแบบภาษาไทยและอังกฤษ

### ไฟล์หลัก (Main Documents)

| ไฟล์ | วัตถุประสงค์ | สถานะ | ผู้มีส่วนได้ส่วนเสีย |
| --- | --- | --- | --- |
| **BRD-SRS_AJT-New-Sale-Incentive_Draft-v0.2** | เอกสารข้อมูลธุรกิจและข้อกำหนดระบบ — เป้าหมาย, ขอบเขต, Requirement ครบ 29 FR, ความเสี่ยง, Open Questions | Draft v0.2 (2026-06-13) | Business Owner, HR, Sales Ops, IT |
| **Checklist_BRD-SRS-Review-and-Signoff** | เช็กลิสต์ตรวจสอบความครบถ้วนของ BRD/SRS ก่อน Sign-off | ✅ Complete | Project Manager, QA |
| **Sales Incentive System for POC.md** | เอกสาร POC requirement พร้อมโครงสร้าง Function, Test Case, Project Scope, Manday Estimation, Implementation Roadmap | ✅ Complete (v0.1, updated 2026-06-13) | Project Manager, SA, Dev Lead |
| **Learning.md** | บันทึกความเข้าใจสั้น ๆ เกี่ยวกับ 5.Docs + Sale Incentive Guide bilingual | ✅ Complete | SA, Dev Team |

### ไฟล์อ้างอิง (Reference Files)

| ไฟล์ | หมายเหตุ |
| --- | --- |
| **Cline VS Code (claude).md** | ⚠️ มี API Key/Token — เก็บอย่างระมัดระวัง, หมุนคีย์เป็นระยะ |

---

## 🎯 คู่มือการใช้ (Usage Guide)

### สำหรับผู้บริหาร (Executives)

1. เปิด **BRD-SRS** § 1–3 → เข้าใจเป้าหมายโครงการและขอบเขต
2. ดู **BRD-SRS** § 3.2 (Success Criteria) → วัดผลโครงการ
3. ตรวจสอบ § 16 (Open Questions) → มี 12 ข้อที่ต้องปิดกับ Business
4. ดู **Sales Incentive System for POC** — Manday Estimation → ~109 Manday, Duration ~6–8 weeks

### สำหรับ Project Manager

1. เปิด **Sales Incentive System for POC** → เห็น Development Scope (26 items), Manday by Role, Roadmap
2. ตรวจสอบ **Checklist_BRD-SRS-Review-and-Signoff** → ส่วน E (Governance) → Assign Owner/Due Date
3. จากนั้นไปยัง `4.System Analyst and Design/` → Reference การออกแบบเชิงลึก

### สำหรับ BA / Business Analyst

1. ตรวจสอบ **BRD-SRS** ครบทั้งเอกสาร
2. ส่วน § 16 (Open Questions) → ปิดกับ Business ภายใน Week 1
3. ความเสี่ยงสำคัญ 3 ข้อ: Product code mapping ❌, GD scheme integration ❓, Prorate logic ❓
4. ยืนยัน Scope/Manday กับ IT/Dev ก่อน sign-off

### สำหรับนักพัฒนา (Developers)

1. เปิด **Sales Incentive System for POC** — Function 1–4 + Test Cases → เข้าใจ requirement
2. จากนั้นไปยัง `4.System Analyst and Design/`
   - 📖 **README** → จุดเริ่มต้น (entry point)
   - 📊 **03.Calculation-Logic/00_*.md** → Core logic (achievement, GOAL, cascade, GD scheme)
   - 🔄 **05.Process-Flow/01_*.md** → Data flow diagram
   - 📋 **02.Sheet-Understanding/** → ความเข้าใจรายละเอียด sheet ต่างๆ (MT/TT)

### สำหรับ QA / Tester

1. เปิด **Sales Incentive System for POC** — Test Cases (8 test cases)
2. เปิด **BRD-SRS** § 6 (Functional Requirements) → ทรัพยากร requirement
3. สร้าง UAT test cases จากไฟล์นี้ + baseline Excel
4. Accuracy target: **99.5%** (ยืนยันจาก § 3.2)

---

## 📍 ความสัมพันธ์ระหว่างไฟล์ (Document Relationships)

```text
┌─ BRD-SRS_AJT-New-Sale-Incentive (Business Blueprint)
│  ├─ เป้าหมาย / Objective
│  ├─ ขอบเขต / Scope (In/Out)
│  ├─ Requirement (FR-001 to FR-029, NFR-001 to NFR-006)
│  ├─ Business Rules (BR-001 to BR-009)
│  └─ Open Questions (12 ข้อ)
│
├─ Checklist_BRD-SRS-Review-and-Signoff
│  └─ ตรวจสอบความครบ + governance
│
├─ Sales Incentive System for POC (Implementation Plan)
│  ├─ Sale Incentive Guide (Operational Workflow)
│  ├─ Function 1–4 (Detailed requirements)
│  ├─ Project Scope Assessment
│  ├─ Manday Estimation (109 MD)
│  ├─ Implementation Roadmap (5 phases)
│  └─ Test Cases (8 TC)
│
├─ Learning.md (Quick Reference)
│  └─ Sale Incentive Guide bilingual
│
└─ 4.System Analyst and Design/ (Technical Details)
   ├─ README (Entry point)
   ├─ 03.Calculation-Logic (Core formula)
   ├─ 05.Process-Flow (Data flow diagram)
   └─ 02.Sheet-Understanding (Sheet-by-sheet analysis)
```

---

## 🎪 Key Insights

### What's Confirmed ✅

- **Architecture**: 2 channels (MT Cascade 4-level, TT Single-sheet)
- **Calculation logic**: Achievement, GOAL lookup, Cascade, Shortage override, Fix Rate, GD scheme
- **M_Month**: payment calendar mapping ระหว่างเดือนยอดขาย กับเดือนจ่าย Incentive แยก Variable และ Fixed
- **Data sources**: BI/DWC (sales), HCM (employee), ASTBase (org hierarchy)
- **Output**: For HR (variable incentive), For HR FIX (fixed rate), Audit trail
- **Requirement**: 29 FR, 6 NFR, 9 BR, fully traced

### What's Pending ❓

| ประเด็น | อ้างอิง | Due Date |
| --- | --- | --- |
| Product code mapping (AJA, AMV, FP, QM) | BRD §16 OQ-4 | Week 1 |
| Policy: 108% → 1.06 (not 1.08) | BRD §16 OQ-1 | Week 1 |
| GD scheme: additive vs replace | BRD §16 OQ-8 | Week 1 |
| Prorate logic (mid-month join/leave) | BRD §16 OQ-? | Week 1 |
| GD Target source + approval | BRD §16 OQ-10 | Week 1 |

### Risks ⚠️

| ความเสี่ยง | ระดับ | ผลกระทบ |
| --- | --- | --- |
| Open Questions ยังไม่ปิด | สูง | Requirement rework, UAT delay |
| GD scheme unclear | สูง | Double-count risk, incorrect payout |
| Product mapping ยังไม่ชัด | ปานกลาง | Wrong incentive calculation |
| BI/HCM data misaligned | ปานกลาง | Cascade accuracy error |
| Prorate undefined | ปานกลาง | Mid-month employee issue |

---

## 🚀 Next Steps

### Phase 1: Review & Approval (Week 1)

- [ ] Business Owner review BRD/SRS Objective + Scope + Success Criteria
- [ ] HR review Data Requirements + Output format
- [ ] Sales Ops review Parameter management + Workflow
- [ ] IT review Integration Requirements + Technology stack
- [ ] BA close 12 Open Questions with Business
- [ ] Sign-off BRD/SRS v0.2 (ถ้าพร้อม)

### Phase 2: Design (Week 2)

- [ ] Solution design workshop (SA + BA + PM + IT)
- [ ] Data model finalization
- [ ] Integration spec (BI → System, System → HR)
- [ ] Rule engine specification (K2 + API)
- [ ] Output: Design spec document

### Phase 3: Build (Weeks 3–6)

- [ ] API layer: Calculation engine
- [ ] K2 Workflow: Orchestration + Smart Forms
- [ ] Output export: Variable + Fixed Incentive + SSRS print
- [ ] Audit trail logging

### Phase 4: SIT & UAT (Weeks 7–8)

- [ ] Test case execution (8 TC + scenario)
- [ ] UAT vs baseline Excel (99.5% accuracy)
- [ ] Defect fixing
- [ ] Documentation finalization

### Phase 5: Go-Live (Week 9+)

- [ ] Production deployment
- [ ] User training
- [ ] Support for 2 production rounds

---

## 📞 Contact & Ownership

| บทบาท | ผู้รับผิดชอบ | Contact |
| --- | --- | --- |
| Project Manager | [TBD] | [TBD] |
| Business Analyst | [TBD] | [TBD] |
| System Analyst | [Claude / SA Team] | [TBD] |
| Dev Lead (K2) | [TBD] | [TBD] |
| Dev Lead (API) | [TBD] | [TBD] |
| QA Lead | [TBD] | [TBD] |

---

## 📚 References

- **ที่มา Analysis:** `4.System Analyst and Design/` (โฟลเดอร์ neighbor)
- **ไฟล์ต้นฉบับ:** `1.General Documents/` (MT & TT Excel files)
- **Extraction Tool:** `4.System Analyst and Design/00.Extraction-Tools/Extract-Xlsx.ps1`

---

## 🏷️ Tags

`#AJT` `#SalesIncentive` `#BRD` `#SRS` `#POC` `#ProjectScope` `#Manday` `#MT` `#TT` `#GrowthDriver` `#Cascade` `#Excel-to-System`

---

**Last Updated:** 2026-06-13  
**Version:** v0.2 (Bilingual TH/EN, with POC scope & manday)  
**Status:** Ready for Review & Approval
