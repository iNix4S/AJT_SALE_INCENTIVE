# Chat Log - copilot_2026.06.14_034

วันที่: 2026-06-14
Agent: Copilot (GPT-5.3-Codex)

## วัตถุประสงค์
- ตรวจและเติมข้อมูล ws_type ให้ครบในตารางสูตร TT (TOP_WS, WS_SF, WS_WH, SF_WH)

## การดำเนินการ
1. ตรวจสถานะข้อมูลจริงใน DB
- mst_tt_ws_formula_matrix: ครบอยู่แล้ว 11 แถว/ws_type
- mst_tt_option1_band + mst_tt_option1_payout: ครบอยู่แล้ว
- mst_tt_special_kpi_rule: ขาด WS_SF, WS_WH, SF_WH
- mst_incentive_rate: ขาด ws_type สำหรับตำแหน่ง manager และ DIV_MGR

2. เพิ่มสคริปต์ upsert
- environment/ddl/22_upsert_tt_ws_type_completeness.sql
- เติม special KPI rules ให้ครบ 4 ws_type โดยยึด TOP_WS ล่าสุดเป็นต้นแบบ
- เติม incentive rates สำหรับ SECT_MGR/DEPT_MGR/DIV_MGR/AD ให้ครบ 4 ws_type (และ OLD)
- STAFF ws_type ยึดค่าจาก matrix base (TOP_WS=4000, อื่นๆ=3500)

3. แก้ไขผลข้างเคียง
- พบว่า STAFF ws_type ถูกทับเป็น OLD ในรอบแรก
- แก้สคริปต์และ rerun ให้ STAFF กลับมาตาม matrix

## สถานะสุดท้าย
- ข้อมูลครบทั้ง TOP_WS, WS_SF, WS_WH, SF_WH ตามคำขอ
