# Canva Diagram Pack - AJT New Sale Incentive

เวอร์ชัน: v1.0  
วันที่: 2026-06-13  
แหล่งข้อมูลหลัก: [Business-Process-Design_AJT-New-Sale-Incentive_v1.0_2026-06-13.md](../Business-Process-Design_AJT-New-Sale-Incentive_v1.0_2026-06-13.md)

## 1) ไฟล์ที่พร้อมใช้งานใน Canva

- [AJT_Business_Process_EndToEnd_Canva.pptx](AJT_Business_Process_EndToEnd_Canva.pptx)
- [AJT_Business_Process_EndToEnd_Canva.png](AJT_Business_Process_EndToEnd_Canva.png)
- [AJT_Business_Process_EndToEnd_Canva.svg](AJT_Business_Process_EndToEnd_Canva.svg)

## 2) วิธีใช้งานใน Canva

1. เปิด Canva -> Create a design (Presentation 16:9 แนะนำ)
2. ไปที่ Uploads -> Upload files
3. แนะนำลำดับไฟล์ที่ควรลองอัปโหลด:
	- ตัวเลือกที่เสถียรที่สุด: `AJT_Business_Process_EndToEnd_Canva.pptx`
	- ทางเลือกเร็ว: `AJT_Business_Process_EndToEnd_Canva.png`
	- ตัวเลือกแก้ไขเวกเตอร์: `AJT_Business_Process_EndToEnd_Canva.svg`
4. ลากไฟล์ลงหน้าออกแบบ
5. หากใช้ PPTX: Canva จะ import เป็นสไลด์และแก้กล่องข้อความ/shape ต่อได้
6. หากใช้ PNG: เหมาะกับการวางเป็นภาพพื้นฐานแล้วทับ text เพิ่ม

## 3) Mapping ที่ฝังใน Diagram

- Process flow รายเดือน: Start -> M1..M8 -> End
- MT/TT split path + GD + Fixed Rate
- Exception loop และ As-needed adjustment loop
- Control references: CP-1 ถึง CP-9
- Approval rejected loop กลับไป calculation

## 4) Prompt สำหรับสร้าง Diagram เพิ่มใน Canva (Magic Design)

### Prompt A: Swimlane RACI Diagram

สร้าง swimlane diagram ภาษาไทย โทน corporate สำหรับกระบวนการ AJT New Sale Incentive มี lane: Sales Operations, System, Business Owner, HR, Data Team, HCM Owner และ flow: Set Period -> Import BI/HCM -> Validation -> MT/TT Calculation + GD + Fixed -> Review/Approve -> Export to HR -> Audit/Close พร้อมใส่ป้าย RACI ในแต่ละขั้น และกำกับ control points CP-1 ถึง CP-9

### Prompt B: KPI/SLA Monitoring Diagram

สร้าง dashboard flow diagram ภาษาไทย สำหรับติดตาม KPI/SLA ของ Incentive process โดยมี metric: Validation Pass Rate >= 98%, Accuracy >= 99.5%, Rework <= 5%, Export timeliness ภายใน payroll cut-off, Cycle time <= 1 วันทำการหลังข้อมูลครบ เชื่อมแต่ละ metric กับช่วง process: Input/Validate, Calculation, Approval, Export, Close

### Prompt C: Traceability Matrix Visual

สร้าง matrix infographic ภาษาไทย แสดงการเชื่อมโยง System Flow block กับ FR และ Control Point: Input/Validate -> FR-006..009 -> CP-1,2,6; MT Path -> FR-010..014 -> CP-3,7; TT Path -> FR-015 -> CP-7; GD -> FR-023..029 -> CP-7; Output/Export -> FR-016,018,020 -> CP-8; Approval -> FR-019,022 -> CP-4; Audit/Close -> FR-021 -> CP-5,9

## 5) หมายเหตุ

- จัดเตรียมทั้ง `PPTX`, `PNG`, `SVG` เพื่อรองรับความเข้ากันได้ของ Canva ที่ต่างกันตาม account/tenant
- ถ้าต้องการ ผมสามารถสร้างไฟล์ SVG เพิ่มอีก 3 แบบให้เป็นชุดเดียวกัน: Swimlane RACI, KPI/SLA, Traceability Matrix
