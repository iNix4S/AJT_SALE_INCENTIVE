# Chat Log - copilot_2026.06.14_030

วันที่: 2026-06-14
Agent: Copilot (GPT-5.3-Codex)

## 1) วัตถุประสงค์ของงานรอบนี้
- จัดทำสคริปต์ upsert สำหรับ TT Top WS product mapping + product weight ให้ครบ 11 ตัว
- รันสคริปต์และยืนยันผลใน DEV database

## 2) สิ่งที่ดำเนินการ
1. ตรวจ schema จริงของตาราง
- dbo.mst_product_mapping
- dbo.mst_product_weight

2. สร้างไฟล์ SQL ใหม่
- environment/ddl/18_upsert_tt_topws_product_mapping_and_weight.sql
- ครอบคลุม Top WS codes: A,R,B,AP,Q,M,NS,Y,P,T,RK
- map ไป product codes: AJ,RD,BD,AJP,RDC,RM,RDNS,YY,PDC,TKM,RKR
- upsert mapping (source_system=TOP_WS, mapping_type=DIRECT_PRODUCT_MAP)
- upsert TT weights (ws_type=OLD, effective_from=2026-04-01)

3. รันสคริปต์จริงและตรวจผล
- ผลตรวจหลังรัน: has_product_master=1, has_product_mapping=1, has_tt_weight=1 ครบทุกตัว

## 3) ไฟล์ที่เพิ่ม/แก้ไข
- environment/ddl/18_upsert_tt_topws_product_mapping_and_weight.sql
- chat-log/copilot_2026.06.14_030.md

## 4) สถานะ
- เสร็จสิ้น
- TT Top WS product setup พร้อมครบทั้ง 11 ตัวในมิติ product master + mapping + TT weight
