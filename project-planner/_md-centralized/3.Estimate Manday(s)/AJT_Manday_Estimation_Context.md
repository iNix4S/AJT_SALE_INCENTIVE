# AJT Sale Incentive - Manday Estimation Context

วันที่: 2026-06-16
เวอร์ชัน: v1.0
วัตถุประสงค์: กำหนดเงื่อนไขมาตรฐานในการคำนวณ Manday ของโครงการ AJT New Sale Incentive System เพื่อใช้ประเมินแผนงานและกำลังคนอย่างสอดคล้องกัน

---

## 1) Team Composition (Fixed Roles)

ทีมที่ใช้ประเมินตามขอบเขตนี้:

- PM: 1 คน
- BA: 1 คน
- SA: 1 คน
- K2 DEV: 2 คน
- API DEV: 1 คน
- QA and Documenter: 1 คน

รวม 7 คน

---

## 2) นิยามหน่วยและเวลาทำงาน

- 1 Manday (MD) = 8 ชั่วโมงทำงานจริง
- 1 คนทำงานเต็มเวลา 1 วัน = 1 MD
- วันทำงานมาตรฐาน: จันทร์-ศุกร์ (ไม่รวมวันหยุดนักขัตฤกษ์)

สูตรพื้นฐาน:

- Role MD = ชั่วโมงงานของ Role / 8
- Project MD (รวม) = ผลรวม MD ของทุก Role
- Project Duration (วันทำงาน) = Project MD / จานวน FTE ที่ลงงานพร้อมกัน (ตาม dependency จริง)

หมายเหตุ:
- Project MD ไม่เท่ากับ Duration โดยตรง เพราะมีงานที่ขนานกันและงานที่ต้องรออนุมัติ

---

## 3) ขอบเขตงานที่ใช้ในการประเมิน MD

ให้ประเมินบนขอบเขตตาม Project Scope ล่าสุด โดยแยกงานเป็น 3 กลุ่ม:

1. Common Platform
- Period/M_Month, Validation Gate, Audit Trail, Approval, Export, Reporting, Dashboard

2. Channel Engine
- MT (CASCADE_4_LEVEL)
- TT (SINGLE_SHEET_5_LEVEL_AVG)
- SI (CASCADE_4_LEVEL)
- LAOS (SINGLE_SHEET)

3. Special Logic
- Prorate Logic
- Special Adjustment (Shortage, Target Adjustment, Fix Rate, GD, Special Situation)

---

## 4) Work Breakdown สำหรับการคิด Manday

ให้แตกงานอย่างน้อยตามหมวดต่อไปนี้ (ทุกหมวดต้องมีเจ้าภาพ Role):

1. Requirement and Policy Clarification
2. Functional and Non-Functional Analysis
3. Solution Design and Data Mapping
4. K2 Workflow and Form Development
5. API and Calculation Service Development
6. Integration and Data Import/Export
7. Test Planning and Test Execution
8. UAT Support and Defect Management
9. Deployment and Hypercare
10. Documentation and Handover

---

## 4b) เงื่อนไขการ Estimate ตาม Phase

การประมาณ MD ต้องระบุ Phase ให้ชัดเจนทุก Work Package โดยใช้ 5 Phase มาตรฐานดังนี้:

1. Planning
2. Design Phase
3. Development Phase
4. Stabilizing Phase
5. Go-live Phase

### 4b.1 นิยามและขอบเขตของแต่ละ Phase

| Phase | วัตถุประสงค์ | ตัวอย่างงานหลัก | Role หลัก |
|---|---|---|---|
| Planning | ตั้งเป้าหมาย แผนงาน ขอบเขต และความเสี่ยง | kickoff, roadmap, baseline plan, RAID, resource plan | PM, BA |
| Design Phase | แปลง requirement เป็น solution design ที่ implement ได้ | process design, data mapping, API/K2 spec, test strategy | BA, SA, PM |
| Development Phase | พัฒนาและ unit test ตาม design ที่อนุมัติแล้ว | K2 workflow/form, API/calc logic, integration build, UT | K2 DEV, API DEV, SA |
| Stabilizing Phase | ลด defect และยกระดับความพร้อมก่อนขึ้นระบบจริง | SIT/UAT support, defect fix/retest, regression, performance tune | QA/Doc, K2 DEV, API DEV, BA |
| Go-live Phase | เตรียม cutover และดูแลช่วงเปลี่ยนผ่าน | deployment, smoke test, hypercare, handover, release document | PM, QA/Doc, K2 DEV, API DEV |

### 4b.2 กติกาการนับ MD ตาม Phase

- ทุก Work Package ต้องมีค่าเดียวในฟิลด์ Phase
- ห้ามกระจาย MD ของงานเดียวข้าม Phase โดยไม่แยกเป็น sub-task
- งานที่ข้ามเฟสต้องแตกเป็นอย่างน้อย 2 แถว เช่น Design และ Development
- PM ต้องมี MD ในทุก Phase
- QA/Doc ต้องมี MD อย่างน้อยใน Design (test planning), Stabilizing, และ Go-live
- ถ้า policy ยังไม่ finalize ใน Planning/Design ให้กัน Rework MD ใน Development และ Stabilizing

### 4b.3 Entry/Exit Criteria สำหรับปิด Phase

| Phase | Entry Criteria | Exit Criteria |
|---|---|---|
| Planning | scope เริ่มต้นและรายชื่อ stakeholder พร้อม | baseline plan + risk list + estimation assumptions อนุมัติ |
| Design Phase | requirement baseline พร้อม | solution spec, mapping, interface contract ผ่าน review |
| Development Phase | design sign-off แล้ว | code complete + unit test pass + build package พร้อม SIT |
| Stabilizing Phase | SIT/UAT plan พร้อมและ environment พร้อม | defect ระดับวิกฤตปิดครบ + UAT sign-off |
| Go-live Phase | release readiness checklist ผ่าน | production deploy สำเร็จ + hypercare close + handover complete |

### 4b.4 แนวทางกระจายสัดส่วน MD (ใช้เป็น baseline ตั้งต้น)

สัดส่วนนี้เป็นแนวทางเริ่มต้นเพื่อกัน estimate กระจุกในเฟสเดียว ทีมปรับได้ตามความซับซ้อนจริง:

- Planning: 10-15%
- Design Phase: 20-25%
- Development Phase: 35-45%
- Stabilizing Phase: 15-20%
- Go-live Phase: 5-10%

---

## 5) กติกาการนับ Manday ต่อ Role

## 5.1 PM (1 คน)

นับ MD เมื่อมีงาน:
- Project planning, timeline, dependency management
- Status/review meeting, risk/issues management
- Stakeholder alignment และ sign-off orchestration

ไม่นับซ้า:
- เวลา meeting ที่ถูกนับซ้าใน role อื่นแบบ double-count โดยไม่มี output งาน

เงื่อนไขแนะนำ:
- PM ต้องมี MD ในทุก Phase
- เพิ่ม PM coordination buffer ในช่วง UAT/Go-live

## 5.2 BA (1 คน)

นับ MD เมื่อมีงาน:
- Requirement workshop, process clarification
- Policy definition (โดยเฉพาะ Prorate/Special Adjustment)
- User story, acceptance criteria, backlog grooming

เงื่อนไขสำคัญ:
- ถ้า policy ยังไม่ปิด ให้กัน BA rework MD เพิ่ม
- งานที่มีหลาย channel ให้คิด BA impact ตามความต่างของ logic ต่อ channel

## 5.3 SA (1 คน)

นับ MD เมื่อมีงาน:
- Solution design, schema/interface design
- Rule formalization (formula to system logic)
- Impact analysis, dependency analysis, technical spec

เงื่อนไขสำคัญ:
- งานที่ผูกกับ data source หลายระบบ (BI/HCM/K2/API) ให้บวก integration complexity

## 5.4 K2 DEV (2 คน)

นับ MD เมื่อมีงาน:
- K2 workflow design/build
- Smart Form development
- Approval, exception path, task routing

เงื่อนไขการใช้ 2 คน:
- ถ้า task แบ่ง module อิสระได้ ให้คิด parallel capacity ได้สูงสุด 2 MD/วัน
- ถ้า task เดียวกันและมี dependency สูง ห้ามคูณ 2 ตรงๆ ให้คิด pair efficiency factor แทน

## 5.5 API DEV (1 คน)

นับ MD เมื่อมีงาน:
- API/Service implementation
- Calculation engine implementation
- Data import/export endpoints
- Integration with DB/K2/report output

เงื่อนไขสำคัญ:
- สูตรคำนวณที่เปลี่ยนตาม policy ต้องเผื่อ refactor/retest MD

## 5.6 QA and Documenter (1 คน)

นับ MD เมื่อมีงาน:
- Test scenario/test case preparation
- SIT/UAT execution support and retest
- Defect log and traceability
- User guide/runbook/release note/handover docs

เงื่อนไขสำคัญ:
- ต้องมี regression รอบอย่างน้อย 1 รอบต่อกลุ่มงานหลัก

---

## 6) Complexity Model (เงื่อนไขถ่วงน้ำหนัก)

กำหนดความซับซ้อนของแต่ละงานเป็น 4 ระดับ:

- S = Simple
- M = Medium
- L = Large
- XL = Extra Large

ให้ทีมตกลงค่า multiplier กลางก่อน estimate (ห้ามเปลี่ยนกลางรอบโดยไม่บันทึกเหตุผล)

ตัวอย่างโครงสร้างคำนวณ:

- Base MD (Role) = MD มาตรฐานของงานระดับ M
- Adjusted MD (Role) = Base MD x Complexity Multiplier x Risk Multiplier x Rework Multiplier

โดย:
- Risk Multiplier ใช้เมื่อ requirement/policy ยังไม่ชัด
- Rework Multiplier ใช้เมื่อมี dependency ข้ามทีมสูงหรือมี expected change request

---

## 7) เงื่อนไข Rework และ Buffer

ให้แยก Buffer ออกจาก Base งานเสมอ เพื่อโปร่งใส:

1. Requirement Volatility Buffer
- ใช้กับงานที่ policy ยังไม่ finalize เช่น Prorate

2. Integration Buffer
- ใช้กับงานเชื่อม BI/HCM/Workflow/Export

3. QA Regression Buffer
- ใช้กับงานที่มีผลกระทบข้าม channel

4. Go-live/Hypercare Buffer
- ใช้กับช่วง cutover และ post go-live stabilization

แนวปฏิบัติ:
- บันทึกเหตุผลของ buffer เป็นราย work package
- ไม่ใส่ buffer แบบเหมาโดยไม่ระบุแหล่งความเสี่ยง

---

## 8) Definition of Done สำหรับการปิด MD

งานจะปิด MD ได้เมื่อครบเงื่อนไข:

1. มี output ที่ตรวจสอบได้ (spec/code/test/doc)
2. ผ่าน review ตาม role ที่เกี่ยวข้อง
3. ผ่าน test ตามระดับที่กำหนด (unit/SIT/UAT ตาม phase)
4. อัปเดตเอกสารและ traceability แล้ว

ถ้ายังไม่ครบ ให้ถือเป็น WIP และห้ามนับเป็น completed MD

---

## 9) ตาราง Template สำหรับกรอก Estimate

คอลัมน์แนะนำในการ estimate:

- Work Package ID
- Work Package Name
- Phase (Planning/Design Phase/Development Phase/Stabilizing Phase/Go-live Phase)
- Channel Impact (Common/MT/TT/SI/LAOS)
- Complexity (S/M/L/XL)
- Dependency Level (Low/Medium/High)
- PM MD
- BA MD
- SA MD
- K2 DEV MD
- API DEV MD
- QA/Doc MD
- Buffer MD
- Total MD
- Owner
- Assumption
- Open Question

สูตรรวม:

- Total MD ต่อ Work Package = ผลรวม MD ทุก Role + Buffer MD
- Total Project MD = ผลรวม Total MD ทุก Work Package
- Total MD ต่อ Phase = ผลรวม Total MD ของทุก Work Package ใน Phase นั้น
- Phase Duration = Total MD ต่อ Phase / FTE ที่ลงงานพร้อมกันใน Phase นั้น

---

## 10) Rule เฉพาะสำหรับงาน Prorate และ Special Adjustment

เพื่อไม่ให้ estimate ต่ำเกินจริง ให้บังคับใช้กติกาเพิ่ม:

1. Prorate Logic
- ต้องแยกอย่างน้อย 4 scenario:
  - เข้างานกลางเดือน
  - ลาออกกลางเดือน
  - Transfer ข้าม Region/Channel กลางงวด
  - เปลี่ยน Position กลางงวด
- ทุก scenario ต้องมี:
  - policy statement
  - test case อย่างน้อย normal + edge
  - impact ต่อ For HR output

2. Special Adjustment
- แยกงาน config rule, approval rule, audit trail, report impact
- ต้อง estimate รวมการทำ Before/After view และ traceability

3. หาก policy ยังไม่ finalize
- ให้ใส่งาน BA/SA workshop เพิ่มเป็น explicit MD
- กัน rework buffer เพิ่มใน K2/API/QA

---

## 11) Open Assumptions (ต้องยืนยันก่อน Freeze Estimate)

1. ปริมาณ integration รอบเดือนและ SLA ที่ต้องรองรับ
2. ปริมาณข้อมูลเฉลี่ย/สูงสุดต่อรอบคำนวณ
3. นโยบาย Prorate ทั้ง 4 scenario ที่ HR/Finance อนุมัติแล้ว
4. นโยบายการจ่าย GD ว่ารวม For HR หรือแยก output
5. เกณฑ์ performance target และ non-functional constraints
6. จำนวนรอบ UAT และจำนวนผู้ใช้งานที่เข้าร่วม UAT

ถ้า Assumption เปลี่ยนหลัง freeze ให้เปิด Change Impact และปรับ MD ใหม่

---

## 12) วิธีใช้งานเอกสารนี้

1. ใช้เอกสารนี้เป็น baseline เงื่อนไขก่อนลงตัวเลข
2. แตก work package ตามข้อ 4 แล้วกรอก template ข้อ 9
3. review cross-role รอบแรก (PM/BA/SA/Dev/QA)
4. freeze ตัวเลขพร้อม assumption และ buffer rationale
5. ใช้เวอร์ชันเดียวกันในการรายงานผู้บริหาร

---

จบเอกสาร