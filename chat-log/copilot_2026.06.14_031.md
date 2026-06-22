# Chat Log - copilot_2026.06.14_031

วันที่: 2026-06-14
Agent: Copilot (GPT-5.3-Codex)

## 1) วัตถุประสงค์ของงานรอบนี้
- Implement สูตร TT ตามคำขอ 3 ส่วนใน pipeline ปัจจุบัน
  1. ตารางสูตร matrix ต่อ ws_type (Top WS, WS SF, WS WH, SF WH)
  2. ตาราง band แบบ Option1 พร้อม payout ต่อ G-group
  3. การคำนวณ EXTRA/Special KPI ใน run pipeline เดิม

## 2) สิ่งที่ดำเนินการ
1. สร้าง DDL ใหม่
- environment/ddl/19_create_tt_formula_matrix_option_band_and_special_kpi.sql
- เพิ่มตาราง:
  - mst_tt_ws_formula_matrix
  - mst_tt_option1_band
  - mst_tt_option1_payout
  - mst_tt_special_kpi_rule
  - trn_tt_special_kpi_detail
- seed ข้อมูล matrix ครบ 4 ws_type และ Option1 band+payout
- sync ค่าไป legacy tables (mst_product_weight, mst_incentive_rate) เพื่อ backward compatibility

2. ปรับ procedure pipeline
- environment/ddl/15_create_proc_run_tt_incentive_calculation.sql
- default @WsType เป็น TOP_WS
- เพิ่มการ lookup matrix จาก mst_tt_ws_formula_matrix (fallback ไป legacy table)
- เพิ่มการคำนวณ Special KPI และเขียนลง trn_tt_special_kpi_detail
- รวม Special KPI เข้าผลรวม output โดยบวกเพิ่มใน total_variable

3. ปรับ runner scripts
- environment/scripts/run_tt_incentive_calculation.ps1
  - default WsType = TOP_WS
  - deploy DDL 19 ก่อน deploy proc
- environment/scripts/run_tt_fy_pipeline_and_reconciliation.ps1
  - default WsType = TOP_WS
  - deploy DDL 19 ใน pipeline deploy sequence

## 3) ผลทดสอบ
1. Deploy สำเร็จ
- 19_create_tt_formula_matrix_option_band_and_special_kpi.sql
- 15_create_proc_run_tt_incentive_calculation.sql

2. Run สำเร็จ
- EXEC usp_run_tt_incentive_calculation @PeriodCode='FY2026-05', @WsType='TOP_WS'
- result: trn_incentive_detail_rows=239, out_for_hr_variable_rows=22

3. ตรวจข้อมูลฟีเจอร์ใหม่
- Matrix rows:
  - TOP_WS=11, WS_SF=11, WS_WH=11, SF_WH=11
- Option1:
  - band rows=11
  - payout rows=44
- Special KPI:
  - FY2026-05 rows=22
  - bonus total=6972.00

## 4) ไฟล์ที่แก้ไข/เพิ่ม
- environment/ddl/19_create_tt_formula_matrix_option_band_and_special_kpi.sql
- environment/ddl/15_create_proc_run_tt_incentive_calculation.sql
- environment/scripts/run_tt_incentive_calculation.ps1
- environment/scripts/run_tt_fy_pipeline_and_reconciliation.ps1
- chat-log/copilot_2026.06.14_031.md

## 5) สถานะ
- คำขอทั้ง 3 ข้อ implement แล้วและใช้งานจริงใน pipeline ได้
