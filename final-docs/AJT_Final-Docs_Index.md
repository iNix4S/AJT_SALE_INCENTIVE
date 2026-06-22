# AJT Final Docs Index

วันที่: 2026-06-14  
เวอร์ชัน: v1.0  
วัตถุประสงค์: หน้า index สำหรับรวมเอกสารสรุปหลักในโฟลเดอร์ `final-docs`

---

## 1. ชุดเอกสารสรุปหลัก

| ลำดับ | เอกสาร | วัตถุประสงค์ | เหมาะกับผู้อ่าน |
|---|---|---|---|
| 1 | `AJT_Business-Flow-Process_Summary.md` | สรุป Business Flow Process ตั้งแต่ต้นจนจบ | Business Owner, Sales Ops, HR, SA |
| 2 | `AJT_System-Flow-Process_Summary.md` | สรุปการไหลของระบบ, logic MT/TT, validation, approval, export | SA, Dev, QA, Architect |
| 3 | `AJT_Solution-and-Technology-Stack_Summary.md` | สรุป solution landscape, component และ technology stack | Management, Architect, IT Lead |
| 4 | `AJT_Business-vs-System-Flow_Comparison.md` | ตารางเปรียบเทียบ Business Flow vs System Flow แบบ 1 หน้า | Review meeting, workshop, presentation |

---

## 2. แนะนำลำดับการอ่าน

### สำหรับผู้บริหาร / Business

1. `AJT_Business-Flow-Process_Summary.md`
2. `AJT_Business-vs-System-Flow_Comparison.md`
3. `AJT_Solution-and-Technology-Stack_Summary.md`

### สำหรับ SA / Dev / QA

1. `AJT_System-Flow-Process_Summary.md`
2. `AJT_Business-vs-System-Flow_Comparison.md`
3. `AJT_Business-Flow-Process_Summary.md`
4. `AJT_Solution-and-Technology-Stack_Summary.md`

---

## 3. ความสัมพันธ์ของเอกสาร

| เอกสาร | เน้นมุมมอง | คำถามที่ตอบ |
|---|---|---|
| Business Flow | กระบวนการธุรกิจ | ใครทำอะไร เมื่อไร และส่งต่องานอย่างไร |
| System Flow | การทำงานของระบบ | ระบบรับข้อมูล ตรวจ คำนวณ และส่งออกอย่างไร |
| Solution & Technology Stack | โครงสร้าง solution | ระบบนี้ประกอบด้วยอะไร และใช้เทคโนโลยีอะไร |
| Comparison | มุมมองเปรียบเทียบ | Business Flow กับ System Flow ต่างกันตรงไหน |

---

## 4. ข้อสรุปสำคัญของชุดเอกสารนี้

1. MT ใช้ Mapping และ Cascade 4 ระดับ
2. TT เป็น single-sheet ในเชิง worksheet แต่ผลคำนวณจริงเป็น 5-level hierarchy
3. M_Month เป็น payment calendar logic สำหรับ Variable และ Fixed
4. Validation, Approval และ Audit เป็น control points สำคัญของกระบวนการ
5. ระบบปลายทางของการคำนวณคือ For HR Variable / Fixed พร้อมส่งออกให้ HR

---

## 5. เอกสารต้นทางที่ใช้สรุป

1. `5.Docs/BRD-SRS_AJT-New-Sale-Incentive_Draft-v0.1_2026-06-12.md`
2. `5.Docs/Business-Process-Design_AJT-New-Sale-Incentive_v1.0_2026-06-13.md`
3. `5.Docs/System-Flow-Design_AJT-New-Sale-Incentive_v1.0_2026-06-13.md`
4. `5.Docs/Sales Incentive System for POC.md`
5. `4.System Analyst and Design/03.Calculation-Logic/00_สรุปตรรกะการคำนวณ_ตั้งต้น.md`
6. `4.System Analyst and Design/database design/DB-Design_AJT-New-Sale-Incentive_v1.0_2026-06-13.md`