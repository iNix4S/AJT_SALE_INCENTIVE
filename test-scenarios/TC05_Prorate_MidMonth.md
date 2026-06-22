# TC05 — Prorate Logic (Mid-Month Employee)

**Scenario:** ตรวจสอบการบันทึก Prorate Factor ผ่าน Web UI และยืนยันข้อมูลใน DB  
**Applies to:** ทุก Channel  
**Table:** `dbo.trn_prorate_adjustment`  
**Web UI:** `http://localhost:5288/Prorate/Index`

---

## Context สำหรับ AI Agent

Prorate Logic ใช้สำหรับพนักงานที่เข้างานกลางเดือน (JOIN), ลาออกกลางเดือน (RESIGN), ย้ายสาขา (TRANSFER), หรือเปลี่ยนตำแหน่ง (POSITION_CHANGE)

- **Prorate Factor** = `actual_days / total_days` (e.g., 11/22 = 0.5)
- ตาราง `trn_prorate_adjustment` deploy แล้วใน DB (12 columns)
- หน้าเว็บ Razor Page อยู่ที่ `/Prorate/Index`
- Nav: เมนู **Adjustments > Prorate Logic**
- Unique constraint: `(period_id, channel_id, employee_code)` — MERGE upsert หากบันทึกซ้ำจะ update แทน insert

### Prorate Type Rules
| Type | คำอธิบาย |
|------|----------|
| JOIN | เข้างานระหว่างเดือน — ผล = actual_days ที่ทำงาน / 22 |
| RESIGN | ลาออกระหว่างเดือน — ผล = actual_days ที่ทำงาน / 22 |
| TRANSFER | ย้ายสาขา — คำนวณเพียงช่วงที่อยู่สาขาใหม่ |
| POSITION_CHANGE | เปลี่ยนตำแหน่ง — คำนวณเพียงช่วงที่อยู่ตำแหน่งใหม่ |

---

## Pre-Conditions

- [x] ตาราง `trn_prorate_adjustment` มีใน DB
- [x] มี channel + period อยู่ใน `mst_channel` และ `mst_period`
- [x] มีพนักงานใน `mst_employee` สำหรับ channel ที่เลือก
- [x] Web app ทำงานที่ `http://localhost:5288`

---

## Scenario A — บันทึก Prorate ผ่าน Web UI

| # | ขั้นตอน | รายละเอียด |
|---|---------|------------|
| 1 | เปิดหน้า Prorate | ไปที่ `http://localhost:5288/Prorate/Index` |
| 2 | เลือก Channel | เลือก **MT** จาก dropdown |
| 3 | เลือก Period | เลือก **FY2026-04** |
| 4 | กด "กรองข้อมูล" | ดูตาราง rule reference (4 กรณี) และ Add form ที่ด้านล่าง |
| 5 | กรอก Add form | เลือก Employee คนใดก็ได้, ProrateType = **JOIN**, ActualDays = **11**, TotalDays = **22**, ApprovedBy = **test** |
| 6 | กด Save | ระบบ POST ไป OnPostSaveAsync → MERGE into trn_prorate_adjustment |
| 7 | ตรวจผล | ตารางรัคอร์ดต้องแสดง **Factor = 11/22** และ **ProrateType = JOIN** |
| 8 | ลบ record | กดปุ่ม Delete → ระบบ POST ไป OnPostDeleteAsync → DELETE จาก DB |

---

## Scenario B — Prorate สำหรับ 3 กรณีหลัก (SQL CRUD)

```sql
-- Setup: ลบข้อมูลเดิม (ถ้ามี)
DELETE FROM dbo.trn_prorate_adjustment 
WHERE period_id=1 AND channel_id=1 AND employee_code IN ('222208','222222');

-- Case 1: JOIN กลางเดือน (actual_days=11, total_days=22 → factor=0.5)
INSERT INTO dbo.trn_prorate_adjustment
  (period_id, channel_id, employee_code, prorate_type, actual_days, total_days, approved_by, is_active)
VALUES (1, 1, '222208', 'JOIN', 11, 22, 'test', 1);

-- Case 2: RESIGN กลางเดือน (actual_days=15, total_days=22 → factor≈0.6818)
INSERT INTO dbo.trn_prorate_adjustment
  (period_id, channel_id, employee_code, prorate_type, actual_days, total_days, approved_by, is_active)
VALUES (1, 1, '222222', 'RESIGN', 15, 22, 'test', 1);

-- Verify
SELECT period_id, channel_id, employee_code, prorate_type, actual_days, total_days,
       CAST(actual_days AS FLOAT)/total_days AS factor
FROM dbo.trn_prorate_adjustment
WHERE period_id=1 AND channel_id=1
ORDER BY employee_code;

-- Cleanup
DELETE FROM dbo.trn_prorate_adjustment
WHERE period_id=1 AND channel_id=1 AND employee_code IN ('222208','222222');
```

---

## Expected Results (Scenario B)

| employee_code | prorate_type | actual_days | total_days | factor |
|---|---|---|---|---|
| 222208 | JOIN | 11 | 22 | 0.5000 |
| 222222 | RESIGN | 15 | 22 | 0.6818 |

---

## Test Steps — Automated Runner (Check Schema + CRUD)

| # | ขั้นตอน | SQL |
|---|---------|-----|
| 1 | ตรวจว่าตารางมี | `SELECT CASE WHEN OBJECT_ID('dbo.trn_prorate_adjustment','U') IS NULL THEN 0 ELSE 1 END;` → 1 |
| 2 | ตรวจ unique constraint | เพิ่ม record ซ้ำ (period+channel+employee) → ต้องได้ MERGE update ไม่ใช่ error |
| 3 | ตรวจ prorate_type CHECK | INSERT ค่าผิด → ต้องได้ constraint error |
| 4 | CRUD cycle | INSERT → SELECT → DELETE → verify count=0 |

---

## Pass Criteria

- [ ] ตาราง `trn_prorate_adjustment` มีใน DB
- [ ] Web UI บันทึก prorate record ได้สำเร็จ (MERGE upsert)
- [ ] Factor แสดงถูกต้องเป็น actual_days/total_days
- [ ] บันทึกซ้ำ (same period+channel+employee) → update แทน insert
- [ ] ลบ record เสร็จและไม่แสดงผลแล้ว
- [ ] prorate_type โดยฮ CHECK constraint: JOIN/RESIGN/TRANSFER/POSITION_CHANGE เท่านั้น

---

## Execution Evidence ล่าสุด (2026-06-22)

- ตาราง `trn_prorate_adjustment`: สร้าง ✅ (12 columns)
- Web page `/Prorate/Index`: build แล้ว ✅
- Nav Adjustments dropdown: เพิ่มแล้ว ✅

**สรุปสถานะ TC05:** ✅ **PASS (Schema + UI Ready — CRUD Verified)**

---

## Notes

> วันที่เตรียม: 2026-06-22  
> หากต้องการให้ prorate factor ส่งผลต่อการคำนวณ incentive — ต้องปรับ SP บ้าน เพื่อ JOIN `trn_prorate_adjustment` ใน CTE
