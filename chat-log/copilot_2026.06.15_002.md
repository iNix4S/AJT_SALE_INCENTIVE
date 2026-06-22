# Chat Log: copilot_2026.06.15_002

วันที่: 2026-06-15  
เครื่องมือ: GitHub Copilot (Claude Sonnet 4.6)  
หัวข้อหลัก: ทบทวนสูตร Manager rate จาก T_SectAbove Sheet + สร้าง vw_tt_incentive_rate

---

## 1. สิ่งที่ทำในเซสชันนี้

### 1.1 ต่อจาก session 001

- Session 001 แก้ SP ให้ใช้ STAFF rate (4,000) สำหรับ manager cascade
- ผล SECT_MGR ตรงกับ sheet (4,336.97 ✓) แต่ DEPT_MGR/DIV_MGR ยังไม่ถูกต้อง
- ผู้ใช้แสดง rate table จาก T_SectAbove sheet (ภาพ Excel) เพื่อทบทวนสูตร

### 1.2 สรุปสิ่งที่ค้นพบ

**สูตร Excel ที่ analyze:**
```
Direct superior = IF(F4="Section Manager", IF(Q4>0, Q4 * T_SectAbove!$B$4, 0), 0)
```

**T_SectAbove rate ที่ถูกต้องตาม Sheet:**
| Position Level | T_SectAbove ref | Rate ที่ถูก |
|---|---|---|
| Section Manager | `$B$4` | **4,000** |
| Department Manager | `$B$3` | **5,000** |
| Division Manager | `$B$2` | **5,000** |
| Associate Director | `$B$5` | **6,000** |

**ปัญหาที่พบใน DB:**
`mst_incentive_rate.rate_new` มีค่าผิดเดิม: SECT_MGR=11,000 / DEPT_MGR=8,500 / DIV_MGR=8,500 / AD=6,500

---

## 2. การแก้ไข

### 2.1 UPDATE `mst_incentive_rate` (data fix)

```sql
UPDATE ir
SET ir.rate_new = CASE pl.position_code
    WHEN 'SECT_MGR' THEN 4000.00
    WHEN 'DEPT_MGR' THEN 5000.00
    WHEN 'DIV_MGR'  THEN 5000.00
    WHEN 'AD'       THEN 6000.00
    END
FROM dbo.mst_incentive_rate ir
JOIN dbo.mst_position_level pl ON pl.position_level_id = ir.position_level_id
WHERE ir.channel_id = 2
  AND pl.position_code IN ('SECT_MGR','DEPT_MGR','DIV_MGR','AD')
  AND ir.is_active = 1;
```

### 2.2 แก้ SP v6 — เปลี่ยน rate lookup กลับไปใช้ position-specific

SP v5 (session 001): hardcode `position_code = N'STAFF'` → ใช้ 4,000 สำหรับทุก level  
SP v6 (session 002): เปลี่ยนกลับเป็น `position_code = mc.position_level_code` → แต่ละ level ได้ rate ของตัวเอง

```sql
-- v6: ดึง rate ตาม position_level_code
-- SECT_MGR → 4,000 | DEPT_MGR → 5,000 | DIV_MGR → 5,000 (fallback DEPT) | AD → 6,000
```

---

## 3. ผลลัพธ์หลัง Fix (FY2026-05 non-STAFF rows)

| salesman_code | position_level | pct | base | incentive_amt |
|---|---|---|---|---|
| 110000 | SECT_MGR | 108.42% | 4,000 | **4,336.97** ✓ |
| 120000 | SECT_MGR | 102.95% | 4,000 | 4,118.18 ✓ |
| 130000 | SECT_MGR | 101.48% | 4,000 | 4,059.39 ✓ |
| 140000 | SECT_MGR | 102.38% | 4,000 | 4,095.00 ✓ |
| 150000 | SECT_MGR | 106.00% | 4,000 | 4,240.00 (data issue) |
| 160000 | SECT_MGR | 97.73% | 4,000 | 3,909.09 ✓ |
| 000003 | DEPT_MGR | 103.14% | **5,000** | 5,157.24 |
| 000002 | DIV_MGR | 103.14% | **5,000** | 5,157.24 |

---

## 4. สร้าง View ใหม่: `vw_tt_incentive_rate` (DDL 34)

**วัตถุประสงค์**: แสดง TT incentive rate ทุก position × ws_type พร้อม `rate_effective = COALESCE(rate_new, rate_old)`  
เหมาะสำหรับ verify ว่า rate ตรงกับ T_SectAbove sheet

**ตัวอย่างผลลัพธ์:**
| position_code | ws_type | rate_old | rate_new | rate_effective |
|---|---|---|---|---|
| STAFF | TOP_WS | 4,000 | 4,000 | 4,000 |
| STAFF | WS_SF | 3,500 | 3,500 | 3,500 |
| SECT_MGR | * | 9,000 | 4,000 | 4,000 |
| DEPT_MGR | * | 7,000 | 5,000 | 5,000 |
| DIV_MGR | * | 7,000 | 5,000 | 5,000 |
| AD | * | 5,000 | 6,000 | 6,000 |

**ไฟล์ DDL**: `environment/ddl/34_create_view_vw_tt_incentive_rate.sql`

---

## 5. Topics อื่นที่ถามในเซสชันนี้

### 5.1 TT Compensation Rate อยู่ใน table ไหน
- **`mst_incentive_rate`** — rate ต่อ position level (Section/Dept/Div/AD)
- **`mst_tt_ws_formula_matrix`** — incentive_base ต่อ product × ws_type (STAFF level)
- ทั้งสองตารางต่างกัน: mst_incentive_rate = "เท่าไรต่อคน", formula_matrix = "base × weight ต่อ product"

### 5.2 คอลัมน์ใน out_for_hr_variable → Sheet ไหน
| คอลัมน์ DB | Sheet |
|---|---|
| incentive_staff | Sheet 15 คอลัมน์ "Salesman" |
| incentive_sect | Sheet 15 คอลัมน์ "Direct superior" |
| incentive_dept | Sheet 15 คอลัมน์ "Dept. superior" |
| incentive_div | Sheet 15 คอลัมน์ "Div. superior" |
| incentive_ad | Sheet 15/16 คอลัมน์ "AD" |
| gd_incentive_total | ไม่ได้มาจาก Sheet 15 — มาจาก Sheet 18-25 (Special KPI Bonus) |

### 5.3 SP ใช้กี่ตัวในการ "คำนวณ"
- **คำนวณ**: ตัวเดียว — `usp_run_tt_incentive_calculation`
- **ตรวจสอบ**: `usp_check_tt_incentive_result` เป็นแค่ QA tool (read-only)

---

## 6. ไฟล์ที่แก้ไข / สร้างใหม่

| ไฟล์ | การเปลี่ยนแปลง |
|------|---------------|
| `environment/ddl/15_create_proc_run_tt_incentive_calculation.sql` | SP v6: rate lookup กลับไปใช้ position-specific (ไม่ hardcode STAFF) |
| `environment/ddl/34_create_view_vw_tt_incentive_rate.sql` | **ใหม่**: View TT incentive rate พร้อม rate_effective |
| `final-docs/AJT_TT_Quick_Run_And_Check.sql` | เพิ่ม Step 4: query vw_tt_incentive_rate |

---

## 7. Data Fix ที่ทำใน DB โดยตรง

| ตาราง | Action | รายละเอียด |
|-------|--------|-----------|
| `mst_incentive_rate` | UPDATE rate_new | SECT_MGR: 11,000→4,000 / DEPT_MGR: 8,500→5,000 / DIV_MGR: 8,500→5,000 / AD: 6,500→6,000 |

> **หมายเหตุ**: rate_old ยังคงค่าเดิมเป็น historical reference — SP ใช้ COALESCE(rate_new, rate_old)

---

## 8. Lessons Learned

- T_SectAbove sheet มี rate แยกต่อ position level — SECT_MGR ≠ DEPT_MGR ≠ DIV_MGR ≠ AD
- SECT_MGR rate (4,000) = STAFF rate ในกรณีนี้ แต่เป็นความบังเอิญ ไม่ใช่กฎ
- `mst_incentive_rate.rate_new` ใน DB ต้องตรงกับ T_SectAbove sheet เสมอ — ต้องตรวจก่อน deploy ทุกรอบ
- View `vw_tt_incentive_rate` ช่วย verify ได้ทันทีโดยไม่ต้อง query raw table

---

## 9. Pending / ยังไม่ได้ทำ

- 150000 data issue: 150001 ขาด product Q ใน trn_sales_target — ต้องตรวจว่าจำเป็นต้อง INSERT หรือไม่
- AD (000001?) ไม่ปรากฏใน trn_incentive_detail — อาจไม่มี hierarchy row หรือ ad_code ไม่ match
