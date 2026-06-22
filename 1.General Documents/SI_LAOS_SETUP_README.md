# S&I และ Laos Channel Setup Documentation

วันที่: 2026-06-22  
วัตถุประสงค์: เพิ่มข้อมูลทดสอบสำหรับ S&I และ Laos channels พร้อม master config, สูตรคำนวณ, และ stored procedures

---

## 📁 ไฟล์ที่สร้าง

### S&I Channel (ใช้ MT เป็นต้นแบบ)

1. **setup_si_channel_full.sql**
   - เพิ่ม S&I channel ใน mst_channel
   - สร้าง employee 4 คน (SI001-SI003 + SIM01)
   - สร้าง org hierarchy
   - สร้าง incentive_rate (ตาม MT pattern)
   - สร้าง product_weight (6 products: AJ, RD, BD, YY, AJP, PDC)
   - สร้าง sample targets + actuals

2. **usp_run_si_incentive_calculation.sql**
   - SP สำหรับคำนวณ S&I incentive
   - Parameters: @PeriodId, @ApprovedBy
   - Pattern: MT simplified (per-product calculation)
   - Features:
     - Product weight-based calculation
     - Manager actuals via org hierarchy
     - Shortage override support
     - Rounding: ROUND(.,0) for STAFF/DEPT_MGR; no round for SECT_MGR/AD

3. **AJT_SI_Quick_Run_And_Check.sql**
   - Script สำหรับทดสอบ S&I calculation
   - แสดงผล: Run summary, Incentive detail, For HR summary

### Laos Channel (ใช้ TT เป็นต้นแบบ)

1. **setup_laos_channel_full.sql**
   - เพิ่ม Laos channel ใน mst_channel
   - สร้าง employee 5 คน (LA001-LA003 + managers)
   - สร้าง org hierarchy (รวม ws_type)
   - สร้าง incentive_rate แบบ ws_type (TOP_WS, WS_SF)
   - สร้าง product_weight แบบ ws_type
   - สร้าง TT product mapping (mst_tt_product)
   - สร้าง sample targets + actuals (SKU- format)

2. **usp_run_laos_incentive_calculation.sql**
   - SP สำหรับคำนวณ Laos incentive
   - Parameters: @PeriodCode, @WsType, @ApprovedBy
   - Pattern: TT simplified
   - Features:
     - Product mapping: SKU-{alias}-XXX → base product (A→AJ, R→RD, etc.)
     - ws_type per salesman from org hierarchy
     - Manager calculation: avg(goal_multiplier)
     - Shortage override support

3. **AJT_LAOS_Quick_Run_And_Check.sql**
   - Script สำหรับทดสอบ Laos calculation
   - แสดงผล: Run summary, Incentive detail, For HR summary, Product mapping

---

## 🚀 วิธีใช้งาน

### ขั้นตอนที่ 1: Setup ฐานข้อมูล (รันครั้งแรก)

```sql
-- S&I Channel Setup
USE [AJT_SALE_INCENTIVE];
GO

-- 1. สร้าง master data
:r .\environment\scripts\setup_si_channel_full.sql
GO

-- 2. สร้าง stored procedure
:r .\environment\scripts\usp_run_si_incentive_calculation.sql
GO

-- Laos Channel Setup
-- 3. สร้าง master data
:r .\environment\scripts\setup_laos_channel_full.sql
GO

-- 4. สร้าง stored procedure
:r .\environment\scripts\usp_run_laos_incentive_calculation.sql
GO
```

### ขั้นตอนที่ 2: รันการคำนวณและตรวจสอบผล

```sql
-- S&I Calculation
:r .\final-docs\AJT_SI_Quick_Run_And_Check.sql
GO

-- Laos Calculation
:r .\final-docs\AJT_LAOS_Quick_Run_And_Check.sql
GO
```

### ขั้นตอนที่ 3: ตรวจสอบผลใน Web Application

1. เปิด browser ไปที่: http://localhost:5288/Calculation
2. ตรวจสอบว่า S&I และ Laos buttons **ไม่ disabled** (แสดงว่า SP ถูก deploy แล้ว)
3. ทดสอบรันการคำนวณผ่าน UI:
   - S&I: เลือก Period → คลิก "Run S&I Calculation"
   - Laos: เลือก Period → คลิก "Run Laos Calculation"
4. ตรวจสอบผลใน For HR page: http://localhost:5288/ForHR
   - เลือก Channel: S&I หรือ Laos
   - เลือก Period
   - คลิก "Load For HR"
   - Export CSV Report

---

## 📊 ข้อมูลตัวอย่างที่สร้าง

### S&I Channel

**Employees:**
- SI001: นาย ส. นำเข้า (STAFF)
- SI002: นาง ศ. ส่งออก (STAFF)
- SI003: นาย ษ. ขายดี (STAFF)
- SIM01: นาง ส. หัวหน้า (SECT_MGR)

**Sample Data:**
- Period: First period in mst_period
- Products: AJ, RD, BD
- Achievement: SI001=105%, SI002=110%, SI003=95%

### Laos Channel

**Employees:**
- LA001: นาย ล. ขายลาว (STAFF, TOP_WS)
- LA002: นาง อ. ส่งออก (STAFF, TOP_WS)
- LA003: นาย ว. นำเข้า (STAFF, WS_SF)
- LAM01: นาง ล. หัวหน้า (SECT_MGR)
- LAD01: นาย อ. ผู้จัดการ (DEPT_MGR)

**Sample Data:**
- Period: First period code in mst_period
- Products: SKU-A-xxx (AJ), SKU-R-xxx (RD), SKU-B-xxx (BD)
- Achievement: LA001=108%, LA002=112%, LA003=102%

---

## ✅ การตรวจสอบความถูกต้อง

### S&I Channel

```sql
-- ตรวจสอบ SP exists
SELECT OBJECT_ID('dbo.usp_run_si_incentive_calculation');
-- ถ้าได้ค่า NOT NULL แสดงว่า SP ถูกสร้างแล้ว

-- ตรวจสอบ channel config
SELECT * FROM dbo.mst_channel WHERE channel_code = 'SI';

-- ตรวจสอบ employees
SELECT * FROM dbo.mst_employee WHERE employee_code LIKE 'SI%';

-- ตรวจสอบ incentive rates
SELECT ir.*, pl.position_code
FROM dbo.mst_incentive_rate ir
JOIN dbo.mst_position_level pl ON pl.position_level_id = ir.position_level_id
WHERE ir.channel_id = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'SI');
```

### Laos Channel

```sql
-- ตรวจสอบ SP exists
SELECT OBJECT_ID('dbo.usp_run_laos_incentive_calculation');

-- ตรวจสอบ channel config
SELECT * FROM dbo.mst_channel WHERE channel_code = 'LAOS';

-- ตรวจสอบ employees
SELECT * FROM dbo.mst_employee WHERE employee_code LIKE 'LA%';

-- ตรวจสอบ ws_type setup
SELECT e.employee_code, e.employee_name_th, h.ws_type
FROM dbo.mst_employee e
JOIN dbo.mst_org_hierarchy h ON h.salesman_code = e.employee_code
WHERE e.employee_code LIKE 'LA%'
  AND h.channel_id = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'LAOS');
```

---

## 🔄 การอัปเดต Portal Service

หลังจาก deploy SP แล้ว ระบบจะตรวจสอบ capability อotัตโนมัติผ่าน `PortalDataService.GetDashboardSnapshotAsync()`:

```csharp
// ตรวจสอบว่า SP ถูก deploy แล้วหรือไม่
HasSiSp   = OBJECT_ID('dbo.usp_run_si_incentive_calculation') IS NOT NULL
HasLaosSp = OBJECT_ID('dbo.usp_run_laos_incentive_calculation') IS NOT NULL
```

ถ้า SP ถูก deploy:
- Calculation page: S&I และ Laos buttons จะเป็น **enabled**
- Dashboard: ActiveChannelCount จะรวม S&I และ Laos
- For HR page: dropdown จะแสดง S&I และ Laos channels

---

## 📝 หมายเหตุ

1. **S&I Pattern (MT-like)**
   - เหมาะสำหรับ channel ที่คำนวณแบบ per-product
   - ใช้ period_id เป็น parameter
   - ไม่มี ws_type complexity

2. **Laos Pattern (TT-like)**
   - เหมาะสำหรับ channel ที่มี ws_type และ product mapping
   - ใช้ period_code + ws_type เป็น parameters
   - รองรับ SKU-{alias}-XXX product format

3. **Test Scenarios**
   - TC03: S&I calculation test
   - TC04: Laos calculation test
   - รัน: `.\dev.ps1 -Mode test-scenarios`

4. **Database Requirements**
   - SQL Server 2019+
   - Database: AJT_SALE_INCENTIVE
   - Tables: ตาม schema ใน 01_ajt_sis_poc_master_tables.sql

---

## 🐛 Troubleshooting

**ปัญหา: SP ไม่ถูก deploy**
```sql
-- ตรวจสอบ error messages
SELECT * FROM sys.messages WHERE language_id = 1033 AND message_id >= 50000;

-- Re-create SP
:r .\environment\scripts\usp_run_si_incentive_calculation.sql
:r .\environment\scripts\usp_run_laos_incentive_calculation.sql
```

**ปัญหา: Calculation button ยัง disabled**
- รีสตาร์ท web application
- ตรวจสอบ `GetDashboardSnapshotAsync` query
- Clear browser cache

**ปัญหา: ไม่มีข้อมูลใน For HR**
- ตรวจสอบว่ารัน calculation แล้วหรือไม่
- ตรวจสอบ `out_for_hr_variable` table
- ดู calc_run_id และ run_status

---

## 📚 อ้างอิง

- MT SP: `environment/scripts/usp_run_mt_incentive_calculation.sql`
- TT SP: `environment/ddl/15_create_proc_run_tt_incentive_calculation.sql`
- Schema: `environment/ddl/01_ajt_sis_poc_master_tables.sql`
- Web Portal: `src/AjtIncentive.Web/`
