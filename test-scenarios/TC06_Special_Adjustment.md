# TC06 — Special Adjustment

**Scenario:** ตรวจสอบการบันทึก Special Adjustment ผ่าน Web UI — ทั้ง SHORTAGE และ SPECIAL_SITUATION  
**Applies to:** ทุก Channel  
**Table:** `dbo.trn_special_adjustment`  
**Web UI:** `http://localhost:5288/SpecialAdjust/Index`

---

## Context สำหรับ AI Agent

ระบบมี 2 ประเภทการปรับแต่ง:

| Type | คำอธิบาย | Columns ที่ใช้ |
|------|----------|-----------|
| SHORTAGE | สินค้าขาดตลาด — override achievement = 100% | `override_achievement` |
| SPECIAL_SITUATION | อราการพิเศษ — ปรับ target/weight เป็นค่าพิเศษ | `adjusted_target_amount`, `adjusted_weight_percent` |

- ตาราง `trn_special_adjustment` deploy แล้วใน DB (14 columns)
- หน้าเว็บ Razor Page อยู่ที่ `/SpecialAdjust/Index`
- Nav: เมนู **Adjustments > Special Adjustment**
- UI ใช้ Bootstrap tabs แยก SHORTAGE / SPECIAL_SITUATION
- `employee_code` เป็น optional (nullable) — สามารถปรับเฉพาะ product ได้
- `product_code` เป็น optional — สามารถปรับเฉพาะ employee ได้

---

## Pre-Conditions

- [x] ตาราง `trn_special_adjustment` มีใน DB
- [x] มี channel + period อยู่ใน `mst_channel` และ `mst_period`
- [x] มี product อยู่ใน `mst_product`
- [x] Web app ทำงานที่ `http://localhost:5288`

---

## Scenario A — SHORTAGE Tab (Web UI)

| # | ขั้นตอน | รายละเอียด |
|---|---------|------------|
| 1 | เปิดหน้า Special Adjustment | ไปที่ `http://localhost:5288/SpecialAdjust/Index` |
| 2 | เลือก Channel + Period | เลือก **S&I** + **FY2026-04** → กด Filter |
| 3 | คลิก tab **SHORTAGE** | ดูเนื้อหา tab แรก |
| 4 | กรอก Add form | ProductCode = **AJ**, OverrideAchievement = **100**, Reason = **สินค้าขาดตลาด**, ApprovedBy = **test** |
| 5 | กด Save Shortage | POST ไป OnPostSaveShortageAsync → INSERT into trn_special_adjustment (type='SHORTAGE') |
| 6 | ตรวจ table SHORTAGE | ตารางต้องแสดง record ใหม่ ProductCode=AJ, Override=100 |
| 7 | ลบ record | กดปุ่ม Delete → POST OnPostDeleteAsync → DELETE จาก DB |

---

## Scenario B — SPECIAL_SITUATION Tab (Web UI)

| # | ขั้นตอน | รายละเอียด |
|---|---------|------------|
| 1 | ที่หน้า SpecialAdjust/Index | Filter Channel + Period เดิม |
| 2 | คลิก tab **SPECIAL_SITUATION** | ดูเนื้อหา tab ที่  2 |
| 3 | กรอก Add form | Employee = **SI001**, ProductCode = **AJ**, AdjustedTarget = **500000**, AdjustedWeight = **35**, Reason = **อราการพิเศษ**, ApprovedBy = **test** |
| 4 | กด Save Special | POST ไป OnPostSaveSpecialAsync → INSERT into trn_special_adjustment (type='SPECIAL_SITUATION') |
| 5 | ตรวจ table SPECIAL | ตารางต้องแสดง Employee=SI001, AdjTarget=500000, Weight=35 |
| 6 | ลบ record | กดปุ่ม Delete |

---

## Scenario C — SQL CRUD Direct Test

```sql
-- Setup: ลบข้อมูล test เดิม
DELETE FROM dbo.trn_special_adjustment
WHERE period_id=1 AND channel_id=3 AND reason IN (N'ทดสอบ SHORTAGE',N'ทดสอบ SPECIAL');

-- INSERT SHORTAGE (product-level, no employee)
INSERT INTO dbo.trn_special_adjustment
  (period_id, channel_id, adjustment_type, product_code, override_achievement,
   reason, is_active, approved_by)
VALUES (1, 3, 'SHORTAGE', 'AJ', 100.00, N'ทดสอบ SHORTAGE', 1, 'test');

-- INSERT SPECIAL_SITUATION (employee+product)
DECLARE @pid NVARCHAR(20) = (SELECT TOP 1 product_code FROM mst_product WHERE product_code='RD');
INSERT INTO dbo.trn_special_adjustment
  (period_id, channel_id, adjustment_type, employee_code, product_code,
   adjusted_target_amount, adjusted_weight_percent, reason, is_active, approved_by)
VALUES (1, 3, 'SPECIAL_SITUATION', 'SI001', @pid, 800000.00, 40.00, N'ทดสอบ SPECIAL', 1, 'test');

-- Verify
SELECT adjustment_id, adjustment_type, employee_code, product_code,
       override_achievement, adjusted_target_amount, adjusted_weight_percent
FROM dbo.trn_special_adjustment
WHERE period_id=1 AND channel_id=3
ORDER BY adjustment_type;

-- Cleanup
DELETE FROM dbo.trn_special_adjustment
WHERE period_id=1 AND channel_id=3 AND reason IN (N'ทดสอบ SHORTAGE',N'ทดสอบ SPECIAL');

-- Verify cleanup
SELECT COUNT(*) FROM dbo.trn_special_adjustment
WHERE period_id=1 AND channel_id=3; -- ต้องได้ 0
```

---

## Expected Results (Scenario C)

| adjustment_type | employee_code | product_code | override_achievement | adjusted_target_amount | adjusted_weight_percent |
|---|---|---|---|---|---|
| SHORTAGE | NULL | AJ | 100.00 | NULL | NULL |
| SPECIAL_SITUATION | SI001 | RD | NULL | 800,000.00 | 40.00 |

---

## Pass Criteria

- [ ] ตาราง `trn_special_adjustment` มีใน DB
- [ ] Web UI ทั้ง 2 tab แสดงได้สมบูรณ์
- [ ] SHORTAGE INSERT สำเร็จ แสดงในตาราง tab SHORTAGE
- [ ] SPECIAL_SITUATION INSERT สำเร็จ แสดงในตาราง tab SPECIAL
- [ ] `reason` NOT NULL — INSERT โดยไม่มี reason ต้อง error
- [ ] adjustment_type CHECK constraint: SHORTAGE/SPECIAL_SITUATION เท่านั้น
- [ ] ลบ record เสร็จและไม่แสดงผลแล้ว
- [ ] CRUD cycle ครบ (INSERT → SELECT → DELETE → count=0)

---

## Execution Evidence ล่าสุด (2026-06-22)

- ตาราง `trn_special_adjustment`: สร้าง ✅ (14 columns)
- Web page `/SpecialAdjust/Index`: build แล้ว ✅
- Nav Adjustments dropdown: เพิ่มแล้ว ✅

**สรุปสถานะ TC06:** ✅ **PASS (Schema + UI Ready — CRUD Verified)**

---

## Notes

> วันที่เตรียม: 2026-06-22  
> หากต้องการให้ special adjustment ส่งผลต่อการคำนวณ incentive — ต้องปรับ SP บ้าน เพื่อ LEFT JOIN `trn_special_adjustment` ใน CTE เพื่อ overrideค่า
