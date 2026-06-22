# Learning Notes — 5.Docs

วันที่: 2026-06-13  
โฟลเดอร์: `5.Docs`

## 1) เป้าหมายของโฟลเดอร์นี้

`5.Docs` ใช้เก็บเอกสารระดับสรุปและเอกสารสำหรับรีวิวร่วมกับ Business / HR / Sales Ops / IT โดยเน้นการนำข้อมูลที่ถอดจาก Excel และ SA analysis มาแปลงเป็นเอกสารที่ใช้ตัดสินใจและเซ็นอนุมัติได้

## 2) เอกสารที่มีอยู่ในโฟลเดอร์นี้

- `BRD-SRS_AJT-New-Sale-Incentive_Draft-v0.1_2026-06-12.md`
  - ร่างเอกสาร BRD + SRS หลักของโครงการ (Draft v0.2)
  - ครอบคลุม Objective, Scope, FR, NFR, Business Rules, Risks, Open Questions, Project Estimate Manday(s)

- `Checklist_BRD-SRS-Review-and-Signoff_2026-06-13.md`
  - Checklist สำหรับตรวจความครบของ BRD/SRS ก่อนนำไป review/sign-off

- `Sales Incentive System for POC.md`
  - เอกสาร Requirement สำหรับ POC ครบทั้งไทย/อังกฤษ
  - ครอบคลุม Sale Incentive Guide workflow, Function 1-4, Test Cases

- `Learning.md` (ไฟล์นี้)
  - บันทึกความเข้าใจและแนวทางใช้งานโฟลเดอร์ 5.Docs

- `Cline VS Code (claude).md`
  - ⚠️ ไฟล์ข้อมูลเครื่องมือ/คีย์ที่ไม่ควรเผยแพร่ต่อ — ควรจัดการข้อมูลลับอย่างระมัดระวัง

## 3) สิ่งที่เรียนรู้จากโครงสร้างเอกสาร

1. BRD ต้องตอบว่า "ทำไมต้องทำ" และ "ขอบเขตคืออะไร"
2. SRS ต้องตอบว่า "ระบบต้องทำอะไร" และ "ต้องทำอย่างไรในเชิงฟังก์ชัน"
3. Checklist ต้องใช้ตรวจว่าเอกสารพร้อม review หรือยัง ไม่ใช่แค่สรุปความคืบหน้า
4. เอกสารใน 5.Docs ควรอ้างอิงตรงกับข้อมูลจาก 4.System Analyst and Design เพื่อให้ trace ได้

## 4) ประเด็นสำคัญที่ต้องใช้ต่อในงานจริง

- MT และ TT มีวิธีคิด incentive ต่างกัน จึงต้องระบุ scope ให้ชัดใน BRD/SRS
- ข้อมูลจาก BI/DWC และ HCM เป็น input หลักที่ต้องระบุใน requirement และ integration
- Open Questions ที่ยังไม่ปิดต้องถูกบันทึกไว้ในเอกสารระดับ Business ไม่ควรกระจายไว้เฉพาะในโน้ตการวิเคราะห์
- หากมี functional area ใหม่ เช่น GD / Special Product Incentive ต้องเพิ่มเข้า BRD/SRS อย่างชัดเจน และระบุผลกระทบต่อ business rule

## 5) แนวทางใช้งานโฟลเดอร์นี้

- ใช้เอกสาร BRD/SRS เป็น baseline สำหรับ review กับ stakeholders
- ใช้ checklist เป็นตัวควบคุมความพร้อมก่อน sign-off
- เมื่อมีการอัปเดตผลวิเคราะห์จาก 4.System Analyst and Design ให้สะท้อนกลับมาที่ไฟล์ในโฟลเดอร์นี้เสมอ
- เก็บเวอร์ชันให้ชัดเจน และอัปเดตวันที่ทุกครั้งที่มีการเปลี่ยนเนื้อหา

## 6) สรุปการเรียนรู้สั้น ๆ

`5.Docs` คือพื้นที่รวมเอกสารตัดสินใจของโครงการ ไม่ใช่พื้นที่เก็บ analysis เชิงลึก ดังนั้นเนื้อหาทุกไฟล์ควรอ่านง่าย กระชับ และพร้อมใช้ประชุม/อนุมัติได้ทันที

---

## 7) Sale Incentive Guide — ขั้นตอนการทำงานหลัก (ภาษาไทย / English)

> ที่มา: Guide sheet จาก Excel ต้นฉบับ MT และ TT | อัปเดต: 2026-06-13

### ขั้นตอนรายปี (Annually) / Annually

| ขั้นที่ | Sheet | ภาษาไทย | English |
|--------|-------|---------|---------|
| 1 | M_Month | กำหนดตาราง mapping ระหว่างเดือนยอดขายกับเดือนจ่าย Incentive แยก Variable และ Fixed ตลอดรอบปี | Define the payment calendar mapping between sales month and payout month for both Variable and Fixed Incentive across the year. |

### ขั้นตอนรายเดือน (Monthly) / Monthly

| ขั้นที่ | Sheet | ภาษาไทย | English |
|--------|-------|---------|---------|
| 1 | Period | กำหนดงวด (period) ของรอบ Incentive | Define the Sales Incentive period. |
| 2 | Actual | Download ข้อมูลจาก BI แล้ว copy ลง Actual sheet | Download data from BI and copy it into the Actual sheet. |
| 3 | AST_Base | อัปเดตข้อมูล AST Base + copy สูตรคอลัมน์สีเหลือง | Update the data in the AST Base sheet and copy the formulas in the yellow-highlighted columns. |
| 4 | HR Rep | Download รายงาน HCM + อัปเดต HR Rep + copy สูตรคอลัมน์สีเหลือง | Download Personal Employment (Main & Active)_AST report from HCM, update HR Rep and copy the formulas in the yellow-highlighted columns. |
| 5 | For HR | กรอก Employee ID แล้ว copy สูตรทุกคอลัมน์ ยกเว้น EmpID และ Payment Method | Enter the employee ID, then copy all formulas except the Employee ID and Payment Method columns. |

### ปรับเมื่อจำเป็น (As needed) / As needed

| ขั้นที่ | Sheet | ภาษาไทย | English |
|--------|-------|---------|---------|
| 1 | T_SectAbove | ปรับอัตราค่าตอบแทนตามระดับตำแหน่ง | Adjust the compensation rate based on position level. |
| 2 | Table | ปรับอัตราค่าตอบแทนตาม Job Function | Adjust the compensation rate based on Job Function. |
| 3 | Target & Cal | ปรับเป้าหมายการขายตามสภาพธุรกิจ | Adjust sales targets based on business conditions. |
| 4 | Shortage | ปรับกรณีสินค้าขาดแคลนรายสินค้า/เดือน | Adjust shortages by product and month. |
| 5 | Fix Rate | ปรับอัตราคงที่รายพนักงาน | Adjust fixed rate based on employee. |

> ⚠️ **ภาษาไทย:** ต้องตรวจสอบว่าข้อมูลยอดขายและพนักงานสอดคล้องกับ period ของเดือนนั้นเสมอ และ Recheck Job Function ก่อนปิดรอบ
>
> ⚠️ **English:** Please ensure that sales and employee data align with the Sales Incentive period for that month. Recheck Job Function before closing each period.
