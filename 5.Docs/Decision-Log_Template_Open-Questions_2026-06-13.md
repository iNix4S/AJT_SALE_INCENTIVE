# Decision Log Template — Open Questions (Critical 3 Items)

เวอร์ชัน: v0.1  
วันที่สร้าง: 2026-06-13  
วัตถุประสงค์: ใช้บันทึกมติอย่างเป็นทางการสำหรับ 3 ประเด็นค้างที่มีผลต่อ Scope, Policy, และการออกแบบระบบจ่าย Incentive

---

## แนวทางใช้งาน

1. ใช้ไฟล์นี้ในการประชุม Requirement/Policy Sign-off
2. 1 แถว = 1 ประเด็นที่ต้องตัดสินใจ
3. ระบุ Decision ให้ชัดว่าเลือกทางไหน (ห้ามใช้คำกว้าง เช่น "ตามเดิม")
4. กำหนด Owner ที่มีอำนาจตัดสินใจจริง
5. ระบุ Due Date แบบชัดเจน (YYYY-MM-DD)
6. บันทึก Impact ทั้งเชิงระบบและเชิงธุรกิจ
7. ระบุผู้อนุมัติสุดท้ายในช่อง Approved By

---

## Decision Log (Template with Prefilled Issues)

| ID | ประเด็น | ที่มาที่ไป (สรุป) | Decision | Owner | Due Date | Impact | Approved By |
| --- | --- | --- | --- | --- | --- | --- | --- |
| DL-001 | Policy จุด 108% -> ตัวคูณ 1.06 (ไม่ใช่ 1.08) | พบจากการถอดตรรกะสูตรเดิมว่าจุด 108% ไม่ได้ใช้ตัวคูณตรงตาม intuition จึงต้องยืนยันว่าเป็น policy table/step rule ที่ตั้งใจไว้ | [กรอกมติ: ยืนยัน 1.06 หรือปรับใหม่ พร้อม effective period] | [Business Owner] | [YYYY-MM-DD] | [ถ้ายืนยัน 1.06: คง baseline เดิม / ถ้าปรับ: ต้องแก้ Rule Engine, UAT baseline, เอกสาร BR/FR] | [ชื่อ-ตำแหน่ง] |
| DL-002 | Scope/Policy ของ Laos Dept ใน TT For HR (AD) | ยังไม่ชัดว่า Laos Dept อยู่ในขอบเขตรอบเดียวกับ TT ปกติ หรือเป็นเงื่อนไขแยกเฉพาะ policy/organization | [กรอกมติ: In-Scope/Out-of-Scope, วิธีคำนวณ, รอบจ่าย, data owner] | [Sales Ops + HR Owner] | [YYYY-MM-DD] | [กระทบ data model, output template, approval flow และ effort integration] | [ชื่อ-ตำแหน่ง] |
| DL-003 | Scope ของ GD payout engine (รวม For HR หรือจ่ายแยก / additive หรือ replace) | พบ scheme GD แยก แต่ยังไม่ชัดการ wire เข้า For HR และมีความเสี่ยงจ่ายซ้ำกับน้ำหนัก G2 ในสูตรหลัก | [กรอกมติ: payout route, anti-double-count rule, posting target table] | [Business Owner + HR + IT Lead] | [YYYY-MM-DD] | [กระทบ calculation/output architecture, BR-009, และความเสี่ยงการจ่ายซ้ำ] | [ชื่อ-ตำแหน่ง] |

---

## Guidance: วิธีกรอกช่อง Decision ให้ใช้งานได้จริง

### DL-001 (Policy 108% -> 1.06)

กรอกให้ครบอย่างน้อย:
- Rule Statement: Achievement ช่วงใดใช้ตัวคูณใด
- Effective Date/Period: เริ่มใช้เมื่อไร
- Backdate Policy: หากรอบก่อนหน้าไม่ตรง rule ใหม่ให้ทำอย่างไร
- Exception Handling: กรณีข้อมูลผิด/ขาดให้ระบบจัดการอย่างไร

ตัวอย่างรูปแบบ Decision ที่ดี:
- "ยืนยัน policy เดิม: Achievement 108% ใช้ multiplier = 1.06 มีผลตั้งแต่ Period 2026-04 และไม่ backdate"

### DL-002 (Laos Dept Scope/Policy)

กรอกให้ครบอย่างน้อย:
- Scope: In-Scope หรือ Out-of-Scope ในเฟสปัจจุบัน
- Source of Truth: ข้อมูลจากระบบใดเป็นทางการ
- Processing Route: เข้า TT For HR (AD) เดียวกันหรือแยก flow
- Output Responsibility: ฝั่งใดเป็นผู้รับผลลัพธ์และอนุมัติ

ตัวอย่างรูปแบบ Decision ที่ดี:
- "Laos Dept เป็น In-Scope เฉพาะ TT AD flow, ใช้ข้อมูลจาก HCM+BI ตาม period เดียวกัน, ส่งออกในไฟล์แยกชุด Laos"

### DL-003 (GD Payout Engine)

กรอกให้ครบอย่างน้อย:
- Payout Route: รวม For HR หรือจ่ายแยก
- Double-Count Rule: additive หรือ replace กับน้ำหนัก G2 หลัก
- Data Contract: Target/Actual/Payout table ใครเป็นเจ้าของ
- Reconciliation Rule: วิธีตรวจสอบผลรวมก่อนอนุมัติ

ตัวอย่างรูปแบบ Decision ที่ดี:
- "GD จ่ายแยกไฟล์, กำหนด replace กับน้ำหนัก G2 สำหรับ product code ที่อยู่ใน GD list เพื่อตัดความเสี่ยง double-count"

---

## Sign-off Checklist (ก่อนปิดมติ)

- Decision ทุกข้อระบุชัดเจนและตีความได้ทางเดียว
- Owner ยืนยันรับผิดชอบพร้อม Due Date
- Impact ถูกประเมินทั้งด้านระบบ ข้อมูล และธุรกิจ
- Approved By ลงนามครบ
- BRD/SRS และเอกสาร SA ที่เกี่ยวข้องถูกอัปเดตตามมติ

---

## Reference Links

- 3 ประเด็นคำถามค้างใน SA README: ../4.System Analyst and Design/README.md
- รายละเอียด GD scope คำถาม SP-1..SP-6: ../4.System Analyst and Design/02.Sheet-Understanding/MT/11_Special-Product-Incentive_AjiPlus-RDQ-RDM-RDNS.md
- Open Questions ใน BRD/SRS: ./BRD-SRS_AJT-New-Sale-Incentive_Draft-v0.1_2026-06-12.md
