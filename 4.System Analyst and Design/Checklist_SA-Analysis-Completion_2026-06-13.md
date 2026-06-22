# Checklist: SA Analysis Completion (Folder 4.System Analyst and Design)

วันที่: 2026-06-13

## A) 00.Extraction-Tools

- [ ] สคริปต์ Extract-Xlsx.ps1 รันได้ครบ MT และ TT
- [ ] มีคำอธิบายวิธีใช้งานและตัวอย่างคำสั่ง
- [ ] ผลลัพธ์ extraction สามารถทำซ้ำได้ (reproducible)

## B) 01.Raw-Extracts

- [ ] มี _INDEX.md ครบทั้ง MT และ TT
- [ ] มีไฟล์ values.csv/formulas.csv ตามที่จำเป็นต่อการวิเคราะห์
- [ ] ตรวจชื่อ sheet และจำนวนไฟล์ตรงกับไฟล์ต้นทาง

## C) 02.Sheet-Understanding

- [ ] มี template กลางสำหรับการเขียนทุก sheet
- [ ] MT: ครอบคลุม sheet สำคัญอย่างน้อย Guide, Top WS, Period, Table, Actual, Mapping, ASTBase, HR Rep, Target & Cal, For HR
- [ ] TT: ครอบคลุม sheet สำคัญอย่างน้อย Target & Cal, For HR, For HR (AD)
- [ ] ระบุ Input/Output/สูตรสำคัญ/คำถามค้างคาในแต่ละ sheet
- [ ] มีแผนเติม sheet ที่ยังไม่ครบจนถึง 100%

## D) 03.Calculation-Logic

- [ ] ยืนยันสูตร achievement, goal lookup, incentive calculation แล้ว
- [ ] ยืนยัน MT cascade (Staff -> Sect -> Dept -> AD) แล้ว
- [ ] ยืนยัน For HR logic (floor/max และการรวมหลายระดับ) แล้ว
- [ ] ระบุสิ่งที่ยังไม่ยืนยันจาก Business เป็นรายการชัดเจน

## E) 04.Data-Dictionary

- [ ] Product Code Mapping MT <-> TT ทำแล้ว
- [ ] ระบุรหัสที่ยัง unresolved ชัดเจน
- [ ] มีแผนขยายเป็น field-level dictionary (core entities)

## F) 05.Process-Flow

- [ ] มีภาพรวม Data Flow สำหรับ MT
- [ ] มีภาพรวม Data Flow สำหรับ TT
- [ ] มีความต่าง MT vs TT ชัดเจน
- [ ] มี dependency chain ข้าม sheet

## G) คุณภาพเอกสารและความพร้อมส่งต่อ

- [ ] ทุกไฟล์มีวันที่/เวอร์ชัน/สถานะเอกสาร
- [ ] ทุกข้อสรุปอ้างอิงหลักฐานจาก raw extracts ได้
- [ ] Open Questions ถูกรวบรวมเพื่อนำไปปิดกับ Business
- [ ] เนื้อหาพร้อมส่งต่อเพื่อทำ BRD/SRS และ Solution Design

## H) สถานะรวมแบบเปอร์เซ็นต์ (อัปเดตล่าสุด)

| ส่วนงาน | สถานะปัจจุบัน | % | หลักฐาน |
|---|---|---:|---|
| 00.Extraction-Tools | สคริปต์พร้อมใช้งาน | 100% | [Extract-Xlsx.ps1](00.Extraction-Tools/Extract-Xlsx.ps1) |
| 01.Raw-Extracts | แตกไฟล์ครบ MT/TT พร้อม index | 100% | [MT](01.Raw-Extracts/MT), [TT](01.Raw-Extracts/TT) |
| 02.Sheet-Understanding | ทำแล้วเฉพาะ sheet สำคัญ | 25% | [MT](02.Sheet-Understanding/MT), [TT](02.Sheet-Understanding/TT) |
| 03.Calculation-Logic | สูตรหลักยืนยันแล้ว แต่ยังมีคำถามธุรกิจ | 85% | [00_สรุปตรรกะการคำนวณ_ตั้งต้น.md](03.Calculation-Logic/00_%E0%B8%AA%E0%B8%A3%E0%B8%B8%E0%B8%9B%E0%B8%95%E0%B8%A3%E0%B8%A3%E0%B8%81%E0%B8%B0%E0%B8%81%E0%B8%B2%E0%B8%A3%E0%B8%84%E0%B8%B3%E0%B8%99%E0%B8%A7%E0%B8%93_%E0%B8%95%E0%B8%B1%E0%B9%89%E0%B8%87%E0%B8%95%E0%B9%89%E0%B8%99.md) |
| 04.Data-Dictionary | มี mapping สินค้าแล้ว แต่ field dictionary ยังไม่ครบ | 40% | [01_Product-Code-Mapping.md](04.Data-Dictionary/01_Product-Code-Mapping.md) |
| 05.Process-Flow | มี diagram หลักครบ MT/TT แล้ว | 80% | [01_Data-Flow-Diagram.md](05.Process-Flow/01_Data-Flow-Diagram.md) |

สรุปภาพรวมโฟลเดอร์ 4.System Analyst and Design (ถ่วงตามความสำคัญงาน): ประมาณ 70-75%

## Sign-off ภายในทีม SA

- ผู้จัดทำ: ____________________
- ผู้ทบทวน: ____________________
- วันที่: ____________________
- ผล: [ ] ผ่าน  [ ] ผ่านแบบมีเงื่อนไข  [ ] ไม่ผ่าน
- หมายเหตุ: ____________________________________________________
