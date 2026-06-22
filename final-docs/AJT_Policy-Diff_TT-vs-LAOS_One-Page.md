# AJT Policy Diff: TT vs LAOS (One-Page)

วันที่: 2026-06-14  
เวอร์ชัน: v1.0  
วัตถุประสงค์: เอกสาร 1 หน้าเพื่อใช้คุยกับ Business ว่าทำไม TT และ LAOS จึงตั้งใจให้ใช้นโยบายคำนวณต่างกัน

---

## Executive Summary

TT กับ LAOS ถูกออกแบบให้ต่างกันที่ `calc_type` โดยตั้งใจตามนโยบาย:

- TT ใช้ `SINGLE_SHEET_5_LEVEL_AVG` เพื่อรองรับการคำนวณแบบ hierarchy 5 ระดับ
- LAOS ใช้ `SINGLE_SHEET` เพื่อคงความเรียบง่ายของ flow ใน baseline ปัจจุบัน

ดังนั้นความต่างนี้เป็น **policy decision** ไม่ใช่ความผิดพลาดของข้อมูล

---

## Policy Diff Table (TT vs LAOS)

| หัวข้อ | TT (Traditional Trade) | LAOS | นัยเชิงนโยบายสำหรับ Business |
|---|---|---|---|
| `calc_type` | `SINGLE_SHEET_5_LEVEL_AVG` | `SINGLE_SHEET` | TT มี logic ซับซ้อนกว่า LAOS โดยตั้งใจ |
| แนวคิด worksheet | single-sheet | single-sheet | เหมือนกันในมุมโครงแผ่นงาน |
| แนวคิด engine logic | 5-level cascade | single-sheet baseline | ต่างกันที่ engine ไม่ใช่รูปแบบ sheet |
| ระดับ hierarchy ที่รองรับ | STAFF -> SECT_MGR -> DEPT_MGR -> DIV_MGR -> AD | ไม่บังคับ 5-level แบบ TT | TT ต้อง trace ผลหลายชั้น, LAOS โฟกัส flow ที่ง่ายกว่า |
| วิธี aggregate หลัก | AVERAGEIFS ตามสายบังคับบัญชา | ไม่ใช้ profile 5-level แบบ TT | TT ต้องการ governance เชิงโครงสร้างมากกว่า |
| ตัวแปรผลลัพธ์ Variable | รองรับ component ครบระดับ (รวม Division) | baseline แบบ single-sheet | policy การจ่ายของ TT ละเอียดกว่า |
| ความซับซ้อนในการทดสอบ/ตรวจสอบ | สูงกว่า | ต่ำกว่า | TT ต้องมี test scenario มากกว่า LAOS |
| ความเสี่ยงจากข้อมูลโครงสร้าง | สูง (ขึ้นกับ hierarchy completeness) | ต่ำกว่า | TT ต้องคุมคุณภาพ ASTBase/Hierarchy เข้มกว่า |
| ความพร้อม rollout | ต้องพึ่งความครบของ mapping/hierarchy มาก | rollout ได้เร็วกว่า | เหมาะกับการทำ phased rollout คนละความเข้ม |
| ความยืดหยุ่นในอนาคต | รองรับกติกาซับซ้อนได้ดีกว่า | เรียบง่ายและ maintain ง่าย | เลือกตาม trade-off ระหว่าง complexity กับ speed |

---

## สิ่งที่ต้องยืนยันกับ Business (Decision Checkpoints)

1. ต้องการคง LAOS เป็น `SINGLE_SHEET` ต่อไปในระยะถัดไปหรือไม่
2. ถ้า LAOS จะยกระดับเป็น cascade ต้องการระดับใด (เช่น 3-level หรือ 5-level)
3. KPI/Policy ของ LAOS ต้อง trace ตามหัวหน้าหลายชั้นแบบ TT หรือไม่
4. หากเปลี่ยน LAOS ในอนาคต ให้กำหนด effective period ชัดเจนเพื่อไม่กระทบย้อนหลัง

---

## Recommended Message สำหรับใช้คุยในที่ประชุม

"TT กับ LAOS ต่างกันที่ policy intent: TT ต้องรองรับโครงสร้างจ่ายหลายชั้นจึงใช้ `SINGLE_SHEET_5_LEVEL_AVG` ขณะที่ LAOS ตั้งใจให้เป็น baseline ที่ง่ายและควบคุมได้เร็วด้วย `SINGLE_SHEET` ดังนั้นค่า `calc_type` ที่ต่างกันถือว่าถูกต้องตามนโยบายปัจจุบัน"

---

## อ้างอิง

1. `environment/ddl/02_ajt_sis_poc_seed_data.sql`
2. `4.System Analyst and Design/database design/DB-Design_AJT-New-Sale-Incentive_v1.0_2026-06-13.md`
3. `final-docs/AJT_System-Flow-Process_Summary.md`
