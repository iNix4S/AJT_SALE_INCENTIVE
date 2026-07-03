# Extended SP Reference (14 Procedures)

เอกสารนี้สรุปวิธีเรียกใช้งาน Stored Procedure ชุด Extended Data Management
จากไฟล์ [database/scripts/usp_extended_data_management.sql](database/scripts/usp_extended_data_management.sql)

ใช้กับฐานข้อมูล AJT_SIS

## Quick Start

```sql
-- แนะนำให้ใช้ transaction ตอนทดสอบ
BEGIN TRAN;

-- เรียก SP ตามตัวอย่างในเอกสารนี้

ROLLBACK TRAN; -- เปลี่ยนเป็น COMMIT เมื่อต้องการบันทึกจริง
```

## 1) dbo.usp_master_period_upsert

วัตถุประสงค์: เพิ่มหรือแก้ไขข้อมูล period

Parameters
- @PeriodId INT OUTPUT: ใส่ NULL หรือ 0 เพื่อ insert, ใส่ค่า period_id เพื่อ update
- @PeriodCode NVARCHAR(40): รหัส period (required)
- @SalesMonth DATE: เดือนขาย (required)
- @YearNo INT: ปี (required)
- @MonthNo TINYINT: 1-12 (required)
- @Status NVARCHAR(60): สถานะ (required)
- @IsClosed BIT = 0: ปิด period หรือไม่

ตัวอย่าง EXEC
```sql
DECLARE @PeriodId INT = NULL;
EXEC dbo.usp_master_period_upsert
    @PeriodId = @PeriodId OUTPUT,
    @PeriodCode = N'2026-12',
    @SalesMonth = '2026-12-01',
    @YearNo = 2026,
    @MonthNo = 12,
    @Status = N'OPEN',
    @IsClosed = 0;
SELECT @PeriodId AS PeriodId;
```

## 2) dbo.usp_master_period_delete

วัตถุประสงค์: ลบ period ตาม id

Parameters
- @PeriodId INT: period id ที่ต้องการลบ

ตัวอย่าง EXEC
```sql
EXEC dbo.usp_master_period_delete @PeriodId = 1001;
```

## 3) dbo.usp_formula_expression_upsert_version

วัตถุประสงค์: เพิ่ม/ปรับสูตร โดยรองรับ versioned schema อัตโนมัติ

Parameters
- @FormulaId INT OUTPUT: output id ของ record ที่สร้าง/แก้
- @FormulaCode NVARCHAR(100): รหัสสูตร (required)
- @FormulaName NVARCHAR(200): ชื่อสูตร (required)
- @FormulaStep NVARCHAR(50): เช่น INCENTIVE_PER_PRODUCT (required)
- @ChannelId INT = NULL
- @PositionLevelId INT = NULL
- @WsType NVARCHAR(50) = NULL
- @FormulaExpr NVARCHAR(1000): expression (required)
- @VariablesJson NVARCHAR(2000) = NULL
- @Description NVARCHAR(500) = NULL
- @SortOrder INT = 0
- @EffectiveFrom DATE (required)
- @EffectiveTo DATE = NULL
- @IsActive BIT = 1

ตัวอย่าง EXEC
```sql
DECLARE @FormulaId INT = NULL;
EXEC dbo.usp_formula_expression_upsert_version
    @FormulaId = @FormulaId OUTPUT,
    @FormulaCode = N'MT_INCENTIVE_STD',
    @FormulaName = N'MT Incentive Standard',
    @FormulaStep = N'INCENTIVE_PER_PRODUCT',
    @ChannelId = 1,
    @PositionLevelId = NULL,
    @WsType = NULL,
    @FormulaExpr = N'[base_rate] * [weight_pct] * [goal_mult]',
    @VariablesJson = N'[]',
    @Description = N'baseline formula',
    @SortOrder = 10,
    @EffectiveFrom = '2026-01-01',
    @EffectiveTo = NULL,
    @IsActive = 1;
SELECT @FormulaId AS FormulaId;
```

## 4) dbo.usp_formula_expression_set_active

วัตถุประสงค์: เปิด/ปิด active สูตรทั้งหมดที่มี formula_code เดียวกัน

Parameters
- @FormulaCode NVARCHAR(100)
- @IsActive BIT

ตัวอย่าง EXEC
```sql
EXEC dbo.usp_formula_expression_set_active
    @FormulaCode = N'MT_INCENTIVE_STD',
    @IsActive = 0;
```

## 5) dbo.usp_formula_expression_delete

วัตถุประสงค์: ลบสูตรตาม formula_id

Parameters
- @FormulaId INT

ตัวอย่าง EXEC
```sql
EXEC dbo.usp_formula_expression_delete @FormulaId = 14;
```

## 6) dbo.usp_formula_expression_clone_channel

วัตถุประสงค์: clone สูตร active จาก source channel ไป target channel

Parameters
- @TargetChannel NVARCHAR(20)
- @SourceChannel NVARCHAR(20)
- @SetInactive BIT = 0

ตัวอย่าง EXEC
```sql
EXEC dbo.usp_formula_expression_clone_channel
    @TargetChannel = N'MT',
    @SourceChannel = N'TT',
    @SetInactive = 1;
```

## 7) dbo.usp_trn_sales_target_upsert

วัตถุประสงค์: เพิ่ม/แก้ข้อมูล target ราย salesman-product

Parameters
- @SalesTargetId BIGINT OUTPUT: NULL/0 เพื่อ insert, ใส่ค่าเพื่อ update
- @PeriodId INT
- @ChannelId INT
- @SalesmanCode NVARCHAR(100)
- @ProductCode NVARCHAR(100)
- @TargetAmount DECIMAL(18,2)
- @PctSalesman DECIMAL(9,4) = NULL
- @ApprovedBy NVARCHAR(200) = NULL
- @ApprovedAt DATETIME2(0) = NULL

ตัวอย่าง EXEC
```sql
DECLARE @SalesTargetId BIGINT = NULL;
EXEC dbo.usp_trn_sales_target_upsert
    @SalesTargetId = @SalesTargetId OUTPUT,
    @PeriodId = 1,
    @ChannelId = 1,
    @SalesmanCode = N'EMP001',
    @ProductCode = N'P001',
    @TargetAmount = 250000,
    @PctSalesman = 1.0000,
    @ApprovedBy = N'manager01',
    @ApprovedAt = SYSUTCDATETIME();
SELECT @SalesTargetId AS SalesTargetId;
```

## 8) dbo.usp_trn_sales_target_delete

วัตถุประสงค์: ลบ target ตาม composite key ที่ใช้งานในหน้า Target

Parameters
- @SalesTargetId BIGINT
- @PeriodId INT
- @ChannelId INT

ตัวอย่าง EXEC
```sql
EXEC dbo.usp_trn_sales_target_delete
    @SalesTargetId = 21834,
    @PeriodId = 1,
    @ChannelId = 1;
```

## 9) dbo.usp_trn_prorate_adjustment_upsert

วัตถุประสงค์: เพิ่ม/แก้ prorate adjustment ของพนักงาน

Parameters
- @ProrateId INT OUTPUT: NULL/0 เพื่อ insert หรือ auto-detect record เดิม
- @PeriodId INT
- @ChannelId INT
- @EmployeeCode NVARCHAR(100)
- @ProrateType NVARCHAR(60): ต้องผ่าน check constraint เช่น JOIN, TRANSFER, RESIGN, POSITION_CHANGE
- @ActualDays INT
- @TotalDays INT
- @ApprovedBy NVARCHAR(200) = NULL
- @Remarks NVARCHAR(1000) = NULL
- @IsActive BIT = 1

ตัวอย่าง EXEC
```sql
DECLARE @ProrateId INT = NULL;
EXEC dbo.usp_trn_prorate_adjustment_upsert
    @ProrateId = @ProrateId OUTPUT,
    @PeriodId = 1,
    @ChannelId = 1,
    @EmployeeCode = N'EMP001',
    @ProrateType = N'JOIN',
    @ActualDays = 20,
    @TotalDays = 30,
    @ApprovedBy = N'hr01',
    @Remarks = N'mid-month join',
    @IsActive = 1;
SELECT @ProrateId AS ProrateId;
```

## 10) dbo.usp_trn_prorate_adjustment_delete

วัตถุประสงค์: ลบ prorate adjustment ตาม id

Parameters
- @ProrateId INT

ตัวอย่าง EXEC
```sql
EXEC dbo.usp_trn_prorate_adjustment_delete @ProrateId = 9;
```

## 11) dbo.usp_trn_special_adjustment_upsert

วัตถุประสงค์: เพิ่ม/แก้ special adjustment (SHORTAGE หรือ SPECIAL_SITUATION)

Parameters
- @AdjustmentId INT OUTPUT: NULL/0 เพื่อ insert, ใส่ค่าเพื่อ update
- @PeriodId INT
- @ChannelId INT
- @AdjustmentType NVARCHAR(60)
- @EmployeeCode NVARCHAR(100) = NULL
- @ProductCode NVARCHAR(60) = NULL
- @OverrideAchievement DECIMAL(9,4) = NULL
- @AdjustedTargetAmount DECIMAL(18,2) = NULL
- @AdjustedWeightPercent DECIMAL(9,4) = NULL
- @Reason NVARCHAR(1000)
- @ApprovedBy NVARCHAR(200) = NULL
- @IsActive BIT = 1

ตัวอย่าง EXEC (SHORTAGE)
```sql
DECLARE @AdjustmentId INT = NULL;
EXEC dbo.usp_trn_special_adjustment_upsert
    @AdjustmentId = @AdjustmentId OUTPUT,
    @PeriodId = 1,
    @ChannelId = 1,
    @AdjustmentType = N'SHORTAGE',
    @EmployeeCode = N'EMP001',
    @ProductCode = N'P001',
    @OverrideAchievement = 0.8500,
    @AdjustedTargetAmount = NULL,
    @AdjustedWeightPercent = NULL,
    @Reason = N'product shortage approved',
    @ApprovedBy = N'manager01',
    @IsActive = 1;
SELECT @AdjustmentId AS AdjustmentId;
```

ตัวอย่าง EXEC (SPECIAL_SITUATION)
```sql
DECLARE @AdjustmentId INT = NULL;
EXEC dbo.usp_trn_special_adjustment_upsert
    @AdjustmentId = @AdjustmentId OUTPUT,
    @PeriodId = 1,
    @ChannelId = 1,
    @AdjustmentType = N'SPECIAL_SITUATION',
    @EmployeeCode = N'EMP001',
    @ProductCode = N'P001',
    @OverrideAchievement = NULL,
    @AdjustedTargetAmount = 100000,
    @AdjustedWeightPercent = 0.9000,
    @Reason = N'approved special campaign',
    @ApprovedBy = N'manager01',
    @IsActive = 1;
SELECT @AdjustmentId AS AdjustmentId;
```

## 12) dbo.usp_trn_special_adjustment_delete

วัตถุประสงค์: ลบ special adjustment ตาม id

Parameters
- @AdjustmentId INT

ตัวอย่าง EXEC
```sql
EXEC dbo.usp_trn_special_adjustment_delete @AdjustmentId = 11;
```

## 13) dbo.usp_sbx_calc_run_create

วัตถุประสงค์: สร้าง sandbox run header

Parameters
- @SandboxRunId BIGINT OUTPUT
- @TargetChannelId INT
- @SourceChannelId INT
- @PeriodId INT
- @Engine NVARCHAR(50)
- @FormulaSetRef NVARCHAR(200) = NULL
- @RunStatus NVARCHAR(30) = N'CALCULATED'
- @ApprovedBy NVARCHAR(200) = NULL

ตัวอย่าง EXEC
```sql
DECLARE @SandboxRunId BIGINT = NULL;
EXEC dbo.usp_sbx_calc_run_create
    @SandboxRunId = @SandboxRunId OUTPUT,
    @TargetChannelId = 1,
    @SourceChannelId = 1,
    @PeriodId = 1,
    @Engine = N'TEST',
    @FormulaSetRef = N'mt-v1',
    @RunStatus = N'CALCULATED',
    @ApprovedBy = N'sandbox-api';
SELECT @SandboxRunId AS SandboxRunId;
```

## 14) dbo.usp_sbx_incentive_detail_insert

วัตถุประสงค์: เพิ่มรายละเอียด incentive ของ sandbox run

Parameters
- @SandboxIncentiveDetailId BIGINT OUTPUT
- @SandboxRunId BIGINT
- @SalesmanCode NVARCHAR(100)
- @ProductCode NVARCHAR(100)
- @TargetAmount DECIMAL(18,2)
- @ActualAmount DECIMAL(18,2)
- @Achievement DECIMAL(9,4)
- @GoalMultiplier DECIMAL(9,4)
- @IncentiveBase DECIMAL(18,2)
- @ProductWeight DECIMAL(9,4)
- @FormulaExpr NVARCHAR(1000)
- @IncentiveAmount DECIMAL(18,2)

ตัวอย่าง EXEC
```sql
DECLARE @SandboxIncentiveDetailId BIGINT = NULL;
EXEC dbo.usp_sbx_incentive_detail_insert
    @SandboxIncentiveDetailId = @SandboxIncentiveDetailId OUTPUT,
    @SandboxRunId = 4,
    @SalesmanCode = N'EMP001',
    @ProductCode = N'P001',
    @TargetAmount = 100000,
    @ActualAmount = 120000,
    @Achievement = 1.2000,
    @GoalMultiplier = 1.1000,
    @IncentiveBase = 5000,
    @ProductWeight = 0.2500,
    @FormulaExpr = N'[base_rate] * [weight_pct] * [goal_mult]',
    @IncentiveAmount = 1375;
SELECT @SandboxIncentiveDetailId AS SandboxIncentiveDetailId;
```

## Suggested Verification Queries

```sql
SELECT TOP (20) * FROM dbo.mst_period ORDER BY period_id DESC;
SELECT TOP (20) * FROM dbo.mst_formula_expression ORDER BY formula_id DESC;
SELECT TOP (20) * FROM dbo.trn_sales_target ORDER BY sales_target_id DESC;
SELECT TOP (20) * FROM dbo.trn_prorate_adjustment ORDER BY prorate_id DESC;
SELECT TOP (20) * FROM dbo.trn_special_adjustment ORDER BY adjustment_id DESC;
SELECT TOP (20) * FROM dbo.sbx_calc_run ORDER BY sandbox_run_id DESC;
SELECT TOP (20) * FROM dbo.sbx_incentive_detail ORDER BY sandbox_incentive_detail_id DESC;
```
