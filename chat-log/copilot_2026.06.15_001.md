# Chat Log: copilot_2026.06.15_001

วันที่: 2026-06-15  
เครื่องมือ: GitHub Copilot (Claude Sonnet 4.6)  
หัวข้อหลัก: Proof + Fix สูตรคำนวณ Section Manager (incentive_sect)

---

## 1. สรุปสิ่งที่ทำในเซสชันนี้

### 1.1 ตรวจสอบผลลัพธ์ Section Manager (ต่อจาก session ก่อน)

- ผลการตรวจ `out_for_hr_variable` พบว่า `incentive_sect` สูงผิดปกติ เช่น 110000 = 138,600 แทน 4,336.97
- ดู `trn_incentive_detail` ระดับ SECT_MGR พบว่ามี **11 rows ต่อ manager** (แยกตาม product_code)
- Root cause: SP คำนวณ `incentive_sect` ผิดหลายชั้น

---

## 2. Root Causes ที่พบทั้งหมด

| # | ปัญหา | ผลกระทบ |
|---|-------|---------|
| 1 | `mgr_raw` group by `(manager_code, product_code)` | INSERT 11 rows × rate แทน 1 row ต่อ manager |
| 2 | ใช้ `final_achievement` (stepped ratio ราย product) แทน `goal_multiplier` | AVG ผิด เพราะ final_achievement ≠ pct_salesman |
| 3 | `mgr_calc` floor ค่า avg < 1.0 เป็น 1.0 | Manager ควรถูก penalized ได้ เช่น 160000=97.73% |
| 4 | ใช้ threshold lookup สำหรับ `goal_multiplier` ของ manager | ควรใช้ raw avg โดยตรงตาม sheet formula |
| 5 | ใช้ `incentive_base = SECT_MGR rate (11,000)` | Sheet ใช้ STAFF rate (4,000) — formula: base × avg pct |
| 6 | Round avg เป็น DECIMAL(9,4) ก่อนคูณ | เสีย precision ใน incentive_amount (เลขหลัง comma คลาดเคลื่อน) |
| 7 | `staff_salesman_pct` intermediate CTE bias (avg-of-avg) | เมื่อ staff มีจำนวน product ต่างกัน ผลลัพธ์เพี้ยน |

---

## 3. สูตรที่ถูกต้อง (ยืนยันจาก Sheet)

### Section Manager

```
incentive_sect = STAFF_rate × AVG(goal_multiplier ของทุก product×staff row ในสังกัด section)
```

ตัวอย่าง Section 110000 (Bangpoo):
- Staff มี 3 คน × ~11 products = ~33 rows
- AVG(goal_multiplier) = 1.084242...
- incentive_sect = 4,000 × 1.084242... = **4,336.97** ✓

**สูตรเดียวกันใช้กับ DEPT_MGR, DIV_MGR, AD** (เปลี่ยนแค่ level ของ staff ที่ aggregate)

---

## 4. การแก้ไข SP (DDL 15) — v3.0 → v5.0 (deploy หลายรอบ)

### แก้ไขหลัก 6 จุดใน `usp_run_tt_incentive_calculation`:

**จุดที่ 1: `#staff_rows`** — เพิ่ม `goal_multiplier` column
```sql
-- เพิ่ม d.goal_multiplier ใน SELECT จาก trn_incentive_detail
goal_multiplier,  -- pct_salesman or threshold multiplier
```

**จุดที่ 2: `mgr_raw` CTE** — group by manager_code เท่านั้น + ใช้ direct AVG(goal_multiplier)
```sql
-- ก่อน: GROUP BY manager_code, product_code  → product_code = product ต่างๆ
-- หลัง: GROUP BY manager_code                → product_code = N'*' (dummy)
-- ก่อน: AVG(final_achievement)
-- หลัง: AVG(CAST(s.goal_multiplier AS DECIMAL(18,6)))
```

**จุดที่ 3: `mgr_calc` CTE** — ลบ floor-to-1.0 logic
```sql
-- ก่อน: CASE WHEN avg < 1 THEN 1 ELSE avg END
-- หลัง: m.avg_final_achievement โดยตรง
-- เพิ่ม: m.avg_final_achievement AS raw_achievement  (full precision)
```

**จุดที่ 4: INSERT goal_multiplier** — ใช้ `mc.final_achievement` (ค่า 4dp) แทน threshold lookup

**จุดที่ 5: INSERT incentive_amount** — ใช้ `mc.raw_achievement` (full precision) ในการคูณ
```sql
-- ก่อน: base × COALESCE(threshold_lookup, 0)
-- หลัง: base × mc.raw_achievement
```

**จุดที่ 6: rate_data OUTER APPLY** — เปลี่ยนจาก position-specific rate เป็น STAFF rate
```sql
-- ก่อน: position_code = mc.position_level_code  (SECT_MGR = 11,000)
-- หลัง: position_code = N'STAFF'                (= 4,000 ตาม sheet)
```

---

## 5. ผลลัพธ์หลัง Fix (Section Manager FY2026-05)

| Section | Manager | %Direct Superior (SP) | incentive_sect (SP) | incentive_sect (Sheet) | Match |
|---------|---------|----------------------|---------------------|------------------------|-------|
| 110000 | Bangpoo | 108.42% | **4,336.97** | 4,336.97 | ✓ |
| 120000 | Nonthaburi | 102.95% | **4,118.18** | 4,118.18 | ✓ |
| 130000 | Pathum Thani | 101.48% | **4,059.39** | 4,059.39 | ✓ |
| 140000 | Pattanakan | 102.38% | **4,095.00** | 4,095.00 | ✓ |
| 150000 | Ram Indra | 106.00% | **4,240.00** | 4,181.82 | ⚠ data |
| 160000 | Thonburi | 97.73% | **3,909.09** | 3,909.09 | ✓ |

> **หมายเหตุ 150000**: ต่าง 58 บาท เพราะ **data issue** — 150001 ไม่มีข้อมูล product Q (target=0) ใน `trn_sales_actual` ทำให้ SP exclude row นั้น แต่ sheet มี Q ด้วย gm=0.90 (11 products) ส่งผลให้ avg ต่างกัน

---

## 6. ไฟล์ที่แก้ไข

| ไฟล์ | การเปลี่ยนแปลง |
|------|---------------|
| `environment/ddl/15_create_proc_run_tt_incentive_calculation.sql` | แก้สูตรคำนวณ manager incentive ครบทั้ง 6 จุด, SP เวอร์ชัน v3.0 (final) |

---

## 7. ไฟล์ที่ Deploy/Run

| Action | รายละเอียด |
|--------|-----------|
| Deploy SP | `15_create_proc_run_tt_incentive_calculation.sql` (5 รอบ, แก้ทีละจุด) |
| Re-run Calc | `EXEC dbo.usp_run_tt_incentive_calculation @PeriodCode=N'FY2026-05', @WsType=N'TOP_WS', @ApprovedBy=N'system'` |

---

## 8. สิ่งที่ยังค้างอยู่

- **150000 (Ram Indra)** — data issue product Q ของ 150001: ควรตรวจว่า `trn_sales_target` มี Q หรือไม่ และถ้าจำเป็นต้องมีก็ INSERT เพิ่ม
- **Section Manager formula** ใช้ STAFF rate = 4,000 — ถ้า WS_SF/WS_WH มี section manager ด้วย ต้องตรวจว่าควรใช้ rate ของ ws_type ของ manager หรือ avg ของ staff ใต้สังกัด

---

## 9. Lessons Learned

- Manager incentive ใน sheet ใช้ STAFF rate (4,000) ไม่ใช่ SECT_MGR rate (11,000)
- `mgr_raw` ต้อง GROUP BY manager_code เท่านั้น (product_code = '*') จึงจะได้ 1 row ต่อ manager
- AVG ต้องทำบน product rows โดยตรง ไม่ใช่ avg-of-avg ผ่าน per-salesman CTE
- Manager ถูก penalized ได้ (ไม่มี floor 1.0) ตาม sheet จริง
- ต้องเก็บ raw_achievement (full precision DECIMAL(18,6)) ไว้คำนวณ แล้วค่อย round ผลลัพธ์

---

## 10. Queries ที่ใช้ Verify

```powershell
# ตรวจ SECT_MGR results
$conn.CommandText = @"
SELECT d.salesman_code, 
       CAST(d.achievement AS VARCHAR(10)) AS pct,
       CAST(d.incentive_base AS VARCHAR(8)) AS base,
       CAST(d.incentive_amount AS VARCHAR(12)) AS incentive_sect
FROM dbo.trn_incentive_detail d
WHERE d.calc_run_id = (
    SELECT MAX(r.calc_run_id) FROM dbo.trn_calc_run r 
    JOIN dbo.mst_period p ON p.period_id = r.period_id 
    WHERE p.period_code = N'FY2026-05' AND r.channel_id = 2
) AND d.position_level_code = N'SECT_MGR'
ORDER BY d.salesman_code
"@
```
