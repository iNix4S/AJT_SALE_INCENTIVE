# Chat Log - copilot_2026.06.14_033

วันที่: 2026-06-14
Agent: Copilot (GPT-5.3-Codex)

## 1) วัตถุประสงค์
- แปลง query template สูตร TT สำหรับ Business ให้เป็น Stored Procedure

## 2) สิ่งที่ดำเนินการ
1. สร้างไฟล์ DDL ใหม่
- environment/ddl/21_create_proc_usp_get_tt_incentive_formula_template.sql

2. สร้าง Stored Procedure
- ชื่อ: dbo.usp_get_tt_incentive_formula_template
- Parameters:
  - @WsType (default TOP_WS)
  - @PeriodCode (default FY2026-05)
  - @SalesMonth (optional)
  - @AchievementForSimulation (default 1.0500)

3. คงรูปแบบผลลัพธ์เป็น 4 sections เหมือน template เดิม
- Section A: สูตรหลักราย Product
- Section B: Goal Threshold
- Section C: Option1 Band + Payout
- Section D: Simulation payout

4. Deploy + Run test บน DEV
- ผลลัพธ์ครบ 4 result sets และมีข้อมูลจริง

## 3) ไฟล์ที่แก้ไข/เพิ่ม
- environment/ddl/21_create_proc_usp_get_tt_incentive_formula_template.sql
- chat-log/copilot_2026.06.14_033.md

## 4) สถานะ
- งานตามคำขอเสร็จสิ้น
