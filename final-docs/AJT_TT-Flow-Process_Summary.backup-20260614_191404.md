# AJT TT Flow Process Summary

วันที่: 2026-06-14  
เวอร์ชัน: v1.0  
ขอบเขต: เอกสารอธิบาย TT Flow (Traditional Trade) สำหรับทีม Business, SA, Dev และ QA

---

## 1. วัตถุประสงค์

เอกสารนี้สรุปการไหลของ TT แบบครบลำดับ ตั้งแต่รับข้อมูล ตรวจ validation คำนวณ Staff และ Cascade ขึ้น 5 ระดับ ไปจนถึงการสร้างผลลัพธ์ For HR เพื่อให้ทุกทีมใช้ความเข้าใจเดียวกัน

---

## 2. หลักการของ TT

1. TT ใช้ข้อมูลยอดขายตรงระดับ Salesman Code + SKU
2. TT ไม่ต้องทำ mapping แบบ MT
3. โครงสร้าง worksheet ฝั่งต้นทางเป็น single-sheet แต่การคำนวณในระบบมี hierarchy ครบ 5 ระดับ
4. Logic ระดับบนใช้ AVERAGEIFS เพื่อดึงผลจากระดับล่างตามเงื่อนไข

---

## 3. ลำดับการไหลของ TT

1. รับข้อมูล Salesman Code + SKU จาก BI
2. ตรวจ Validation Gate (Period, required fields, hierarchy)
3. คำนวณระดับ Staff (ราย SKU)
4. ส่งผลขึ้น Section Manager
5. ส่งผลขึ้น Department Manager
6. ส่งผลขึ้น Division Manager
7. ส่งผลขึ้น AD
8. รวมผลเป็น For HR Variable
9. ส่งเข้า Approval และ Export

---

## 4. สูตรหลักที่ใช้ใน TT

1. achievement = ROUND(Actual / Target, 4)
2. ถ้าเข้าเงื่อนไข shortage ให้ override achievement = 1.0
3. GOAL ใช้ lookup ตาม threshold (XLOOKUP หรือ HLOOKUP ตามโครงสร้างตาราง)
4. incentive = base x GOAL x weight
5. การส่งผลขึ้นระดับบนใช้ AVERAGEIFS จากข้อมูลระดับล่าง

---

## 5. โครงสร้าง Hierarchy ของ TT

1. STAFF
2. SECT_MGR
3. DEPT_MGR
4. DIV_MGR
5. AD

หมายเหตุ: TT ต่างจาก MT ที่มี 4 ระดับ เพราะ TT ต้องรองรับ Division layer และ output ต้องมี incentive_div

---

## 6. Validation Gate ที่ต้องผ่านก่อนคำนวณ

1. Period alignment
- เดือนข้อมูลขายต้องตรงกับ period ที่ระบบเปิดคำนวณ

2. Required fields completeness
- ต้องมี Salesman Code, SKU, Actual, Target และ key ฟิลด์ที่จำเป็น

3. Hierarchy consistency
- โครงสร้างสายบังคับบัญชาต้องต่อเนื่องครบตามระดับ

4. Calculation readiness
- ตาราง lookup threshold, weight และ policy ที่เกี่ยวข้องต้องพร้อมใช้งาน

---

## 7. Output ที่ต้องได้จาก TT

1. ผลคำนวณรายระดับ STAFF
2. ผลรวมระดับ SECT_MGR
3. ผลรวมระดับ DEPT_MGR
4. ผลรวมระดับ DIV_MGR
5. ผลรวมระดับ AD
6. For HR Variable ที่มีองค์ประกอบ incentive_div

---

## 8. จุดเสี่ยงสำคัญของ TT

1. แม้ไม่ต้อง mapping แบบ MT แต่ถ้า hierarchy ไม่ครบ จะทำให้ cascade เพี้ยนทั้งสาย
2. ถ้า threshold table ผิด จะทำให้ GOAL ผิดทุกระดับ
3. ถ้า period mismatch จะทำให้จ่ายผิดรอบ
4. ถ้า data type ของ Actual/Target ไม่สะอาด จะทำให้ achievement คลาดเคลื่อน

---

## 9. เช็คลิสต์ QA สำหรับ TT

1. ตรวจว่า achievement คำนวณถูกต้องตามสูตร
2. ตรวจว่า shortage override ทำงานถูก
3. ตรวจว่า GOAL lookup ตรง threshold จริง
4. ตรวจว่า AVERAGEIFS ของแต่ละระดับได้ค่าตามกลุ่ม hierarchy เดียวกัน
5. ตรวจว่ามีค่า incentive_div ใน output
6. ตรวจผลรวม For HR เทียบกับ expected sample

---

## 10. สรุปสั้นที่สุด

TT Flow คือ:

รับยอดขายแบบตรง -> validate -> คำนวณ staff ราย SKU -> cascade 5 ระดับด้วย AVERAGEIFS -> สร้าง For HR Variable

TT เข้าใจง่ายกว่า MT ในมุม mapping แต่ต้องระวังความถูกต้องของ hierarchy และ threshold table เป็นพิเศษ
