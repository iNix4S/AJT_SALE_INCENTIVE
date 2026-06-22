# Chat Log - copilot_2026.06.14_035

วันที่: 2026-06-14  
Agent: GitHub Copilot (Claude Sonnet 4.6)

---

## วัตถุประสงค์ของ session นี้

1. Implement per-salesman ws_type support ใน TT incentive calculation
2. สร้าง view ถาวรสำหรับดู ws_type ต่อ salesman ต่อเดือน
3. ตอบคำถาม ws_type mapping กับชีต
4. อัปเดตเอกสาร AJT_TT-Flow-Process_Summary.md ให้ครบ v2.0

---

## การดำเนินการในรอบนี้

### 1. DDL 30 — เพิ่ม ws_type column ใน mst_org_hierarchy
- ไฟล์: `environment/ddl/30_add_ws_type_to_mst_org_hierarchy.sql`
- `ALTER TABLE dbo.mst_org_hierarchy ADD ws_type NVARCHAR(50) NULL`
- Deploy แล้ว ✅

### 2. DDL 31 — INSERT TT org hierarchy FY2026-05 พร้อม ws_type
- ไฟล์: `environment/ddl/31_insert_tt_org_hierarchy_fy2026_05.sql`
- MERGE 22 rows: 14 salesmen + 6 section mgrs + dept/div mgr
- ws_type mapping จาก Job Function suffix ใน sheet 1) For HR:
  - `(Top W)` → TOP_WS (incentive_base 4,000)
  - `(Shop Front)` → WS_SF (incentive_base 3,500)
  - `(Warehouse)` → WS_WH (incentive_base 3,500)
  - ไม่มี qualifier → TOP_WS (default)
- Hierarchy chain: staff/sup → section mgr (xxxxxx0) → dept_mgr=000003 → div_mgr=000002
- Deploy แล้ว ✅

### 3. DDL 15 — Redeploy SP usp_run_tt_incentive_calculation (v2.0)
- ไฟล์: `environment/ddl/15_create_proc_run_tt_incentive_calculation.sql`
- เพิ่ม `hier_ws` CTE: lookup ws_type จาก mst_org_hierarchy รายคน, fallback `@LegacyWsType`
- Thread `ws_type` ผ่าน staff_join → staff_map → staff_calc
- เปลี่ยน 3 OUTER APPLY (formula matrix, product weight, staff rate) ให้ใช้ `COALESCE(sm.ws_type, @LegacyWsType)`
- Manager rates (SECT_MGR ขึ้นไป) คงใช้ `@LegacyWsType` เพราะ rates เหมือนกันทุก ws_type
- Deploy แล้ว ✅

### 4. DDL 32 — View vw_tt_salesman_ws_type
- ไฟล์: `environment/ddl/32_create_view_vw_tt_salesman_ws_type.sql`
- แสดง: period_code, sales_month, channel_code, salesman_code, ws_type, direct_sup_code, dept_mgr_code, div_mgr_code, ad_code, is_active
- JOIN: mst_org_hierarchy → mst_channel → mst_period (ไม่มี channel_id ใน mst_period)
- ใช้ query: `SELECT * FROM dbo.vw_tt_salesman_ws_type WHERE period_code = N'FY2026-05'`
- Deploy แล้ว ✅

### 5. อัปเดต AJT_TT-Flow-Process_Summary.md → v2.0
- ไฟล์: `final-docs/AJT_TT-Flow-Process_Summary.md`
- เพิ่ม Changelog table
- แก้ section 2, 4, 5, 6, 8, 9, matrix row 13
- เพิ่ม section 11 (Features ที่ implement แล้ว)
- เพิ่ม section 12 (Views ทั้งหมด 11 views)
- เพิ่ม section 13 (DDL Script Index 32 scripts)
- เพิ่ม section 14 (สรุปสั้น updated)

---

## ผลลัพธ์ที่ verify แล้ว (FY2026-05)

| ws_type | salesman | incentive_staff |
|---|---|---|
| TOP_WS | 110001 | 4,290 |
| TOP_WS | 120001 | 4,120 |
| TOP_WS | 130001 | 4,340 |
| TOP_WS | 140001 | 4,120 |
| TOP_WS | 150001 | 3,740 |
| TOP_WS | 160001 | 4,100 |
| TOP_WS | 160002 | 4,050 |
| WS_SF | 110002 | 3,960.25 |
| WS_SF | 120002 | 3,587.50 |
| WS_SF | 130002 | 3,673.25 |
| WS_SF | 140002 | 3,640 |
| WS_WH | 110003 | 3,657.50 |
| WS_WH | 130003 | 3,260.25 |
| WS_WH | 140003 | 3,318 |

---

## ข้อมูลสำคัญที่ค้นพบใหม่ใน session นี้

- `mst_period` **ไม่มี** column `channel_id` — view ต้อง JOIN แค่ `sales_month` เท่านั้น
- ws_type ของ salesman ดูจาก **Job Function suffix** ในวงเล็บ ไม่ใช่ Position Level
- "Depot Cho" คือชื่อ **Job Function** ไม่ใช่ตำแหน่ง
- ต้นทางของ ws_type คือ sheet **"1) For HR"** ไฟล์ `15_1) For HR.values.csv` คอลัมน์ G

---

## สถานะ DB ปัจจุบัน

| Table / Object | สถานะ |
|---|---|
| `mst_org_hierarchy.ws_type` | ✅ มี column แล้ว |
| `mst_org_hierarchy` TT FY2026-05 | ✅ 22 rows พร้อม ws_type |
| `trn_sales_target.pct_salesman` | ✅ มี column + data TT FY2026-05 (28 rows) |
| SP `usp_run_tt_incentive_calculation` | ✅ v2.0 per-salesman ws_type + pct_salesman |
| View `vw_tt_salesman_ws_type` | ✅ deploy แล้ว |
| View `vw_trn_sales_actual_pivot_fiscal_month` | ✅ deploy แล้ว |

---

## งานที่ยังค้างอยู่ (ยังไม่ได้ทำ)

1. **mst_org_hierarchy สำหรับ FY2026-04** — ยังไม่มี hierarchy data สำหรับ April (เฉพาะ May ที่มี)
   - ถ้าต้องการ run FY2026-04 ต้อง insert rows ที่ effective_month='2026-04-01' ด้วย
2. **Hierarchy data สำหรับ period อื่น** — ปัจจุบันมีเฉพาะ FY2026-05
3. **incentive_sect / incentive_dept / incentive_div** — ยังเป็น 0 ทุกคน เพราะต้องตรวจ cascade logic ว่า section manager ถูก pick ขึ้นไปถูกต้องหรือไม่
4. **Section Manager incentive** — 110000, 120000 ฯลฯ ควรได้รับ incentive_sect แต่ยังไม่ได้ verify

---

## Quick Reference สำหรับ Agent คนถัดไป

```sql
-- ดู ws_type รายคน
SELECT * FROM dbo.vw_tt_salesman_ws_type WHERE period_code = N'FY2026-05' ORDER BY ws_type, salesman_code;

-- รัน + check
EXEC dbo.usp_run_tt_incentive_calculation @PeriodCode=N'FY2026-05', @WsType=N'TOP_WS', @ApprovedBy=N'system';
EXEC dbo.usp_check_tt_sheet_employee_reference
    @PeriodCode=N'FY2026-05',
    @EmployeeListCsv=N'110001,110002,110003,120001,120002,130001,130002,130003,140001,140002,140003,150001,160001,160002',
    @ChannelCode=N'TT', @InputSheetName=N'1) For HR', @InputSheetFile=N'15_1) For HR.values.csv';

-- ดูผลล่าสุด
SELECT h.ws_type, o.employee_code, o.incentive_staff, o.total_variable
FROM dbo.out_for_hr_variable o
JOIN dbo.trn_calc_run r ON r.calc_run_id=o.calc_run_id
JOIN dbo.mst_period p ON p.period_id=r.period_id AND p.period_code='FY2026-05'
JOIN dbo.mst_channel c ON c.channel_id=r.channel_id AND c.channel_code='TT'
LEFT JOIN dbo.mst_org_hierarchy h
    ON h.channel_id=r.channel_id AND h.salesman_code=o.employee_code
   AND h.effective_month=(SELECT sales_month FROM dbo.mst_period WHERE period_code='FY2026-05')
WHERE o.incentive_staff > 0
ORDER BY h.ws_type, o.employee_code;
```

---

## ไฟล์สำคัญในโปรเจกต์

| ไฟล์ | วัตถุประสงค์ |
|---|---|
| `environment/ddl/15_*.sql` | SP หลักคำนวณ TT incentive |
| `environment/ddl/30_*.sql` | ADD ws_type column |
| `environment/ddl/31_*.sql` | INSERT TT hierarchy FY2026-05 |
| `environment/ddl/32_*.sql` | View vw_tt_salesman_ws_type |
| `final-docs/AJT_TT-Flow-Process_Summary.md` | เอกสาร TT Flow v2.0 |
| `final-docs/AJT_TT_Quick_Run_And_Check.sql` | Quick run + check script |
| `4.System Analyst and Design/01.Raw-Extracts/TT/15_1) For HR.values.csv` | ต้นทาง ws_type ของ salesman |
