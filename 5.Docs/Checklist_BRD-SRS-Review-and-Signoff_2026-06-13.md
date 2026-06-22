# Checklist: BRD/SRS Review and Sign-off

วันที่: 2026-06-13  
เอกสารอ้างอิงหลัก: BRD-SRS_AJT-New-Sale-Incentive_Draft-v0.1_2026-06-12.md

## A) Objective และ Scope

- [ ] Objective ระบุชัดว่า MT และ TT ครอบคลุมอะไรบ้าง
- [ ] In-Scope / Out-of-Scope ไม่ซ้อนทับกัน
- [ ] Success Criteria วัดผลได้จริง (Accuracy, Timeliness, Data Integrity, Auditability)

## B) Requirement Coverage

- [ ] FR ครอบคลุม Import, Validation, Calculation, Approval, Export ครบ
- [ ] NFR ครอบคลุม Security, Performance, Reliability, Audit, Maintainability
- [ ] Business Rules ตรงกับผลวิเคราะห์จากไฟล์สูตรจริง
- [ ] User Stories มี Acceptance Criteria ที่ทดสอบได้

## C) Data และ Integration

- [ ] ระบุแหล่งข้อมูล BI/DWC, HCM, ASTBase ชัดเจน
- [ ] นิยาม key หลักครบ (Employee ID, Salesman Code, Product Code, Period)
- [ ] มีกฎ period alignment ระหว่าง Sales และ HR
- [ ] รูปแบบไฟล์ Export สำหรับ HR ตกลงร่วมกันแล้ว

## D) Open Questions ต้องปิดก่อน Sign-off

- [ ] 108% -> 1.06 เป็น policy ที่ตั้งใจ
- [ ] เงื่อนไขใช้งาน EXTRA / Special KPI / Option1
- [ ] หลักเกณฑ์เลือก Incentive Base แบบ Old vs New
- [ ] Mapping รหัส MT: AJA, AMV, FP, QM
- [ ] บทบาทของ Sales Target sheet ใน flow หลัก
- [ ] Scope ของ Laos Dept ใน TT For HR (AD)

## E) Governance และการอนุมัติ

- [ ] กำหนด Owner ต่อหมวด FR/NFR/Rule ชัดเจน
- [ ] กำหนด Due Date ของ Open Questions ทุกข้อ
- [ ] มีลำดับผู้อนุมัติ (Business, HR, Sales Ops, IT)
- [ ] Sign-off ได้ครบตามลำดับ

## F) ความพร้อมก่อนส่งเข้า Solution Design

- [ ] Baseline เอกสาร BRD/SRS ถูกล็อกเวอร์ชัน
- [ ] Change log ถูกสร้างและใช้งาน
- [ ] Risk ที่เป็น High มี mitigation และ owner ชัดเจน
- [ ] ไม่มี blocker ที่กระทบ Milestone ถัดไป

## สถานะการตรวจ

- ผู้ตรวจ: ____________________
- วันที่ตรวจ: __________________
- ผลการตรวจ: [ ] ผ่าน  [ ] ผ่านแบบมีเงื่อนไข  [ ] ไม่ผ่าน
- หมายเหตุ: ____________________________________________________
