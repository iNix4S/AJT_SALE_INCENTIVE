/*
============================================================================
  Extended Data Management Stored Procedures
  ---------------------------------------------------------------------------
  วัตถุประสงค์:
    - ปิดช่องโหว่ SQL เขียนข้อมูลแบบ direct SQL ใน module หลัก
    - รวม business rule ของ period/formula/target/prorate/special/sandbox ใน DB
    - ให้เรียกใช้งานแบบมาตรฐานร่วมกันได้จาก Web/API/Integration

  ครอบคลุมตาราง:
    1) mst_period
    2) mst_formula_expression
    3) trn_sales_target
    4) trn_prorate_adjustment
    5) trn_special_adjustment
    6) sbx_calc_run
    7) sbx_incentive_detail

  หมายเหตุ:
    - master data ชุดเดิม (channel/product/rate/weight/etc.) อยู่ที่
      database/scripts/usp_master_data_management.sql
============================================================================
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- ============================================================================
-- 1) mst_period
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_master_period_upsert
    @PeriodId      INT = NULL OUTPUT,
    @PeriodCode    NVARCHAR(40),
    @SalesMonth    DATE,
    @YearNo        INT,
    @MonthNo       TINYINT,
    @Status        NVARCHAR(60),
    @IsClosed      BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @PeriodCode = UPPER(LTRIM(RTRIM(@PeriodCode)));
    SET @Status = UPPER(LTRIM(RTRIM(@Status)));

    IF @PeriodCode IS NULL OR @PeriodCode = ''
        THROW 51101, N'period_code is required.', 1;

    IF @MonthNo < 1 OR @MonthNo > 12
        THROW 51102, N'month_no must be between 1 and 12.', 1;

    IF @PeriodId IS NULL OR @PeriodId = 0
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.mst_period WHERE period_code = @PeriodCode)
            THROW 51103, N'Duplicate period_code.', 1;

        IF EXISTS (SELECT 1 FROM dbo.mst_period WHERE sales_month = @SalesMonth)
            THROW 51104, N'Duplicate sales_month.', 1;

        INSERT INTO dbo.mst_period
            (period_code, sales_month, year_no, month_no, status, is_closed, created_at, updated_at)
        VALUES
            (@PeriodCode, @SalesMonth, @YearNo, @MonthNo, @Status, @IsClosed, SYSUTCDATETIME(), NULL);

        SET @PeriodId = CAST(SCOPE_IDENTITY() AS INT);
    END
    ELSE
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM dbo.mst_period WHERE period_id = @PeriodId)
            THROW 51105, N'period_id not found.', 1;

        IF EXISTS (SELECT 1 FROM dbo.mst_period WHERE period_code = @PeriodCode AND period_id <> @PeriodId)
            THROW 51103, N'Duplicate period_code.', 1;

        IF EXISTS (SELECT 1 FROM dbo.mst_period WHERE sales_month = @SalesMonth AND period_id <> @PeriodId)
            THROW 51104, N'Duplicate sales_month.', 1;

        UPDATE dbo.mst_period
        SET period_code = @PeriodCode,
            sales_month = @SalesMonth,
            year_no = @YearNo,
            month_no = @MonthNo,
            status = @Status,
            is_closed = @IsClosed,
            updated_at = SYSUTCDATETIME()
        WHERE period_id = @PeriodId;
    END
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_master_period_delete
    @PeriodId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.mst_period WHERE period_id = @PeriodId)
        THROW 51105, N'period_id not found.', 1;

    DELETE FROM dbo.mst_period WHERE period_id = @PeriodId;

    SELECT @@ROWCOUNT AS DeletedRows;
END
GO

-- ============================================================================
-- 2) mst_formula_expression
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_formula_expression_upsert_version
    @FormulaId          INT = NULL OUTPUT,
    @FormulaCode        NVARCHAR(100),
    @FormulaName        NVARCHAR(200),
    @FormulaStep        NVARCHAR(50),
    @ChannelId          INT = NULL,
    @PositionLevelId    INT = NULL,
    @WsType             NVARCHAR(50) = NULL,
    @FormulaExpr        NVARCHAR(1000),
    @VariablesJson      NVARCHAR(2000) = NULL,
    @Description        NVARCHAR(500) = NULL,
    @SortOrder          INT = 0,
    @EffectiveFrom      DATE,
    @EffectiveTo        DATE = NULL,
    @IsActive           BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @HasVersionColumns BIT = CASE
        WHEN COL_LENGTH('dbo.mst_formula_expression', 'formula_version') IS NOT NULL
         AND COL_LENGTH('dbo.mst_formula_expression', 'status') IS NOT NULL
         AND COL_LENGTH('dbo.mst_formula_expression', 'parent_formula_id') IS NOT NULL
        THEN 1 ELSE 0 END;

    SET @FormulaCode = UPPER(LTRIM(RTRIM(@FormulaCode)));

    IF @FormulaCode IS NULL OR @FormulaCode = ''
        THROW 51111, N'formula_code is required.', 1;

    IF @FormulaExpr IS NULL OR LTRIM(RTRIM(@FormulaExpr)) = ''
        THROW 51112, N'formula_expr is required.', 1;

    IF @EffectiveTo IS NOT NULL AND @EffectiveTo < @EffectiveFrom
        THROW 51113, N'effective_to must not be earlier than effective_from.', 1;

    IF @ChannelId IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM dbo.mst_channel WHERE channel_id = @ChannelId)
        THROW 51114, N'channel_id not found in mst_channel.', 1;

    IF @PositionLevelId IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM dbo.mst_position_level WHERE position_level_id = @PositionLevelId)
        THROW 51115, N'position_level_id not found in mst_position_level.', 1;

    IF @HasVersionColumns = 1
    BEGIN
        DECLARE @ParentId INT = NULL;
        DECLARE @NextVersion INT = 1;

        SELECT TOP(1)
            @ParentId = formula_id,
            @NextVersion = ISNULL(formula_version, 1) + 1
        FROM dbo.mst_formula_expression
        WHERE UPPER(formula_code) = @FormulaCode
        ORDER BY ISNULL(formula_version, 1) DESC, formula_id DESC;

        INSERT INTO dbo.mst_formula_expression
        (
            formula_code, formula_name, formula_step, channel_id, position_level_id, ws_type,
            formula_expr, variables_json, description, sort_order,
            effective_from, effective_to, is_active,
            formula_version, parent_formula_id, status,
            created_at, updated_at
        )
        VALUES
        (
            @FormulaCode, @FormulaName, @FormulaStep, @ChannelId, @PositionLevelId, @WsType,
            @FormulaExpr, @VariablesJson, @Description, @SortOrder,
            @EffectiveFrom, @EffectiveTo, @IsActive,
            @NextVersion,
            CASE WHEN @ParentId IS NULL THEN NULL ELSE @ParentId END,
            CASE WHEN @IsActive = 1 THEN N'ACTIVE' ELSE N'DRAFT' END,
            SYSUTCDATETIME(), NULL
        );

        SET @FormulaId = CAST(SCOPE_IDENTITY() AS INT);
    END
    ELSE
    BEGIN
        IF @FormulaId IS NULL OR @FormulaId = 0
        BEGIN
            IF EXISTS (SELECT 1 FROM dbo.mst_formula_expression WHERE UPPER(formula_code) = @FormulaCode)
                THROW 51116, N'Duplicate formula_code (legacy schema).', 1;

            INSERT INTO dbo.mst_formula_expression
            (
                formula_code, formula_name, formula_step, channel_id, position_level_id, ws_type,
                formula_expr, variables_json, description, sort_order,
                effective_from, effective_to, is_active,
                created_at, updated_at
            )
            VALUES
            (
                @FormulaCode, @FormulaName, @FormulaStep, @ChannelId, @PositionLevelId, @WsType,
                @FormulaExpr, @VariablesJson, @Description, @SortOrder,
                @EffectiveFrom, @EffectiveTo, @IsActive,
                SYSUTCDATETIME(), NULL
            );

            SET @FormulaId = CAST(SCOPE_IDENTITY() AS INT);
        END
        ELSE
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.mst_formula_expression WHERE formula_id = @FormulaId)
                THROW 51117, N'formula_id not found.', 1;

            UPDATE dbo.mst_formula_expression
            SET formula_code = @FormulaCode,
                formula_name = @FormulaName,
                formula_step = @FormulaStep,
                channel_id = @ChannelId,
                position_level_id = @PositionLevelId,
                ws_type = @WsType,
                formula_expr = @FormulaExpr,
                variables_json = @VariablesJson,
                description = @Description,
                sort_order = @SortOrder,
                effective_from = @EffectiveFrom,
                effective_to = @EffectiveTo,
                is_active = @IsActive,
                updated_at = SYSUTCDATETIME()
            WHERE formula_id = @FormulaId;
        END
    END
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_formula_expression_set_active
    @FormulaCode NVARCHAR(100),
    @IsActive BIT
AS
BEGIN
    SET NOCOUNT ON;

    SET @FormulaCode = UPPER(LTRIM(RTRIM(@FormulaCode)));

    IF NOT EXISTS (SELECT 1 FROM dbo.mst_formula_expression WHERE UPPER(formula_code) = @FormulaCode)
        THROW 51118, N'formula_code not found.', 1;

    IF COL_LENGTH('dbo.mst_formula_expression', 'status') IS NOT NULL
    BEGIN
        UPDATE dbo.mst_formula_expression
        SET is_active = @IsActive,
            status = CASE WHEN @IsActive = 1 THEN N'ACTIVE' ELSE N'RETIRED' END,
            updated_at = SYSUTCDATETIME()
        WHERE UPPER(formula_code) = @FormulaCode;
    END
    ELSE
    BEGIN
        UPDATE dbo.mst_formula_expression
        SET is_active = @IsActive,
            updated_at = SYSUTCDATETIME()
        WHERE UPPER(formula_code) = @FormulaCode;
    END

    SELECT @@ROWCOUNT AS UpdatedRows;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_formula_expression_delete
    @FormulaId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.mst_formula_expression WHERE formula_id = @FormulaId)
        THROW 51117, N'formula_id not found.', 1;

    DELETE FROM dbo.mst_formula_expression WHERE formula_id = @FormulaId;

    SELECT @@ROWCOUNT AS DeletedRows;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_formula_expression_clone_channel
    @TargetChannel NVARCHAR(20),
    @SourceChannel NVARCHAR(20),
    @SetInactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @SourceChannelId INT = (
        SELECT TOP(1) channel_id FROM dbo.mst_channel WHERE UPPER(channel_code) = UPPER(@SourceChannel)
    );
    DECLARE @TargetChannelId INT = (
        SELECT TOP(1) channel_id FROM dbo.mst_channel WHERE UPPER(channel_code) = UPPER(@TargetChannel)
    );

    IF @SourceChannelId IS NULL OR @TargetChannelId IS NULL
        THROW 51119, N'Invalid source or target channel.', 1;

    IF COL_LENGTH('dbo.mst_formula_expression', 'formula_version') IS NOT NULL
       AND COL_LENGTH('dbo.mst_formula_expression', 'status') IS NOT NULL
       AND COL_LENGTH('dbo.mst_formula_expression', 'parent_formula_id') IS NOT NULL
    BEGIN
        INSERT INTO dbo.mst_formula_expression
        (
            formula_code, formula_name, formula_step, channel_id, position_level_id, ws_type,
            formula_expr, variables_json, description, sort_order,
            effective_from, effective_to, is_active,
            formula_version, parent_formula_id, status,
            created_at, updated_at
        )
        SELECT
            CONCAT(@TargetChannel, N'_', source.formula_code, N'_', FORMAT(SYSUTCDATETIME(), 'yyyyMMddHHmmss')),
            source.formula_name,
            source.formula_step,
            @TargetChannelId,
            source.position_level_id,
            source.ws_type,
            source.formula_expr,
            source.variables_json,
            CONCAT(N'Cloned from ', @SourceChannel, N': ', source.formula_code),
            source.sort_order,
            source.effective_from,
            source.effective_to,
            CASE WHEN @SetInactive = 1 THEN 0 ELSE source.is_active END,
            1,
            source.formula_id,
            CASE WHEN @SetInactive = 1 THEN N'DRAFT' ELSE N'ACTIVE' END,
            SYSUTCDATETIME(),
            NULL
        FROM dbo.mst_formula_expression source
        WHERE source.channel_id = @SourceChannelId
          AND source.is_active = 1;
    END
    ELSE
    BEGIN
        INSERT INTO dbo.mst_formula_expression
        (
            formula_code, formula_name, formula_step, channel_id, position_level_id, ws_type,
            formula_expr, variables_json, description, sort_order,
            effective_from, effective_to, is_active,
            created_at, updated_at
        )
        SELECT
            CONCAT(@TargetChannel, N'_', source.formula_code, N'_', FORMAT(SYSUTCDATETIME(), 'yyyyMMddHHmmss')),
            source.formula_name,
            source.formula_step,
            @TargetChannelId,
            source.position_level_id,
            source.ws_type,
            source.formula_expr,
            source.variables_json,
            CONCAT(N'Cloned from ', @SourceChannel, N': ', source.formula_code),
            source.sort_order,
            source.effective_from,
            source.effective_to,
            CASE WHEN @SetInactive = 1 THEN 0 ELSE source.is_active END,
            SYSUTCDATETIME(),
            NULL
        FROM dbo.mst_formula_expression source
        WHERE source.channel_id = @SourceChannelId
          AND source.is_active = 1;
    END

    SELECT @@ROWCOUNT AS InsertedRows;
END
GO

-- ============================================================================
-- 3) trn_sales_target
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_trn_sales_target_upsert
    @SalesTargetId    BIGINT = NULL OUTPUT,
    @PeriodId         INT,
    @ChannelId        INT,
    @SalesmanCode     NVARCHAR(100),
    @ProductCode      NVARCHAR(100),
    @TargetAmount     DECIMAL(18,2),
    @PctSalesman      DECIMAL(9,4) = NULL,
    @ApprovedBy       NVARCHAR(200) = NULL,
    @ApprovedAt       DATETIME2(0) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.mst_period WHERE period_id = @PeriodId)
        THROW 51121, N'period_id not found in mst_period.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.mst_channel WHERE channel_id = @ChannelId)
        THROW 51122, N'channel_id not found in mst_channel.', 1;

    IF @SalesmanCode IS NULL OR LTRIM(RTRIM(@SalesmanCode)) = ''
        THROW 51123, N'salesman_code is required.', 1;

    IF @ProductCode IS NULL OR LTRIM(RTRIM(@ProductCode)) = ''
        THROW 51124, N'product_code is required.', 1;

    IF @SalesTargetId IS NULL OR @SalesTargetId = 0
    BEGIN
        IF EXISTS (
            SELECT 1 FROM dbo.trn_sales_target
            WHERE period_id = @PeriodId
              AND channel_id = @ChannelId
              AND salesman_code = @SalesmanCode
              AND product_code = @ProductCode
        )
            THROW 51125, N'Duplicate period/channel/salesman/product target.', 1;

        INSERT INTO dbo.trn_sales_target
            (period_id, channel_id, salesman_code, product_code, target_amount, pct_salesman, approved_by, approved_at, created_at, updated_at)
        VALUES
            (@PeriodId, @ChannelId, @SalesmanCode, @ProductCode, @TargetAmount, @PctSalesman, NULLIF(@ApprovedBy, ''), @ApprovedAt, SYSUTCDATETIME(), NULL);

        SET @SalesTargetId = CAST(SCOPE_IDENTITY() AS BIGINT);
    END
    ELSE
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM dbo.trn_sales_target WHERE sales_target_id = @SalesTargetId)
            THROW 51126, N'sales_target_id not found.', 1;

        IF EXISTS (
            SELECT 1 FROM dbo.trn_sales_target
            WHERE period_id = @PeriodId
              AND channel_id = @ChannelId
              AND salesman_code = @SalesmanCode
              AND product_code = @ProductCode
              AND sales_target_id <> @SalesTargetId
        )
            THROW 51125, N'Duplicate period/channel/salesman/product target.', 1;

        UPDATE dbo.trn_sales_target
        SET period_id = @PeriodId,
            channel_id = @ChannelId,
            salesman_code = @SalesmanCode,
            product_code = @ProductCode,
            target_amount = @TargetAmount,
            pct_salesman = @PctSalesman,
            approved_by = NULLIF(@ApprovedBy, ''),
            approved_at = @ApprovedAt,
            updated_at = SYSUTCDATETIME()
        WHERE sales_target_id = @SalesTargetId;
    END
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_trn_sales_target_delete
    @SalesTargetId BIGINT,
    @PeriodId INT,
    @ChannelId INT
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM dbo.trn_sales_target
    WHERE sales_target_id = @SalesTargetId
      AND period_id = @PeriodId
      AND channel_id = @ChannelId;

    SELECT @@ROWCOUNT AS DeletedRows;
END
GO

-- ============================================================================
-- 4) trn_prorate_adjustment
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_trn_prorate_adjustment_upsert
    @ProrateId       INT = NULL OUTPUT,
    @PeriodId        INT,
    @ChannelId       INT,
    @EmployeeCode    NVARCHAR(100),
    @ProrateType     NVARCHAR(60),
    @ActualDays      INT,
    @TotalDays       INT,
    @ApprovedBy      NVARCHAR(200) = NULL,
    @Remarks         NVARCHAR(1000) = NULL,
    @IsActive        BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.mst_period WHERE period_id = @PeriodId)
        THROW 51131, N'period_id not found in mst_period.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.mst_channel WHERE channel_id = @ChannelId)
        THROW 51132, N'channel_id not found in mst_channel.', 1;

    IF @EmployeeCode IS NULL OR LTRIM(RTRIM(@EmployeeCode)) = ''
        THROW 51133, N'employee_code is required.', 1;

    IF @ActualDays < 0 OR @TotalDays <= 0 OR @ActualDays > @TotalDays
        THROW 51134, N'Invalid actual_days/total_days.', 1;

    DECLARE @ExistingId INT = (
        SELECT TOP(1) prorate_id
        FROM dbo.trn_prorate_adjustment
        WHERE period_id = @PeriodId
          AND channel_id = @ChannelId
          AND employee_code = @EmployeeCode
        ORDER BY prorate_id DESC
    );

    IF @ProrateId IS NULL OR @ProrateId = 0
        SET @ProrateId = @ExistingId;

    IF @ProrateId IS NULL OR @ProrateId = 0
    BEGIN
        INSERT INTO dbo.trn_prorate_adjustment
            (period_id, channel_id, employee_code, prorate_type, actual_days, total_days, remarks, approved_by, is_active, created_at, updated_at)
        VALUES
            (@PeriodId, @ChannelId, @EmployeeCode, @ProrateType, @ActualDays, @TotalDays, @Remarks, @ApprovedBy, @IsActive, SYSUTCDATETIME(), NULL);

        SET @ProrateId = CAST(SCOPE_IDENTITY() AS INT);
    END
    ELSE
    BEGIN
        UPDATE dbo.trn_prorate_adjustment
        SET prorate_type = @ProrateType,
            actual_days = @ActualDays,
            total_days = @TotalDays,
            remarks = @Remarks,
            approved_by = @ApprovedBy,
            is_active = @IsActive,
            updated_at = SYSUTCDATETIME()
        WHERE prorate_id = @ProrateId;
    END
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_trn_prorate_adjustment_delete
    @ProrateId INT
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM dbo.trn_prorate_adjustment
    WHERE prorate_id = @ProrateId;

    SELECT @@ROWCOUNT AS DeletedRows;
END
GO

-- ============================================================================
-- 5) trn_special_adjustment
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_trn_special_adjustment_upsert
    @AdjustmentId             INT = NULL OUTPUT,
    @PeriodId                 INT,
    @ChannelId                INT,
    @AdjustmentType           NVARCHAR(60),
    @EmployeeCode             NVARCHAR(100) = NULL,
    @ProductCode              NVARCHAR(60) = NULL,
    @OverrideAchievement      DECIMAL(9,4) = NULL,
    @AdjustedTargetAmount     DECIMAL(18,2) = NULL,
    @AdjustedWeightPercent    DECIMAL(9,4) = NULL,
    @Reason                   NVARCHAR(1000),
    @ApprovedBy               NVARCHAR(200) = NULL,
    @IsActive                 BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.mst_period WHERE period_id = @PeriodId)
        THROW 51141, N'period_id not found in mst_period.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.mst_channel WHERE channel_id = @ChannelId)
        THROW 51142, N'channel_id not found in mst_channel.', 1;

    IF @AdjustmentType IS NULL OR LTRIM(RTRIM(@AdjustmentType)) = ''
        THROW 51143, N'adjustment_type is required.', 1;

    IF @Reason IS NULL OR LTRIM(RTRIM(@Reason)) = ''
        THROW 51144, N'reason is required.', 1;

    IF @AdjustmentId IS NULL OR @AdjustmentId = 0
    BEGIN
        INSERT INTO dbo.trn_special_adjustment
            (period_id, channel_id, adjustment_type, employee_code, product_code,
             override_achievement, adjusted_target_amount, adjusted_weight_percent,
             reason, is_active, approved_by, created_at, updated_at)
        VALUES
            (@PeriodId, @ChannelId, @AdjustmentType, NULLIF(@EmployeeCode, ''), NULLIF(@ProductCode, ''),
             @OverrideAchievement, @AdjustedTargetAmount, @AdjustedWeightPercent,
             @Reason, @IsActive, NULLIF(@ApprovedBy, ''), SYSUTCDATETIME(), NULL);

        SET @AdjustmentId = CAST(SCOPE_IDENTITY() AS INT);
    END
    ELSE
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM dbo.trn_special_adjustment WHERE adjustment_id = @AdjustmentId)
            THROW 51145, N'adjustment_id not found.', 1;

        UPDATE dbo.trn_special_adjustment
        SET period_id = @PeriodId,
            channel_id = @ChannelId,
            adjustment_type = @AdjustmentType,
            employee_code = NULLIF(@EmployeeCode, ''),
            product_code = NULLIF(@ProductCode, ''),
            override_achievement = @OverrideAchievement,
            adjusted_target_amount = @AdjustedTargetAmount,
            adjusted_weight_percent = @AdjustedWeightPercent,
            reason = @Reason,
            is_active = @IsActive,
            approved_by = NULLIF(@ApprovedBy, ''),
            updated_at = SYSUTCDATETIME()
        WHERE adjustment_id = @AdjustmentId;
    END
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_trn_special_adjustment_delete
    @AdjustmentId INT
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM dbo.trn_special_adjustment
    WHERE adjustment_id = @AdjustmentId;

    SELECT @@ROWCOUNT AS DeletedRows;
END
GO

-- ============================================================================
-- 6) sbx_calc_run
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_sbx_calc_run_create
    @SandboxRunId        BIGINT = NULL OUTPUT,
    @TargetChannelId     INT,
    @SourceChannelId     INT,
    @PeriodId            INT,
    @Engine              NVARCHAR(50),
    @FormulaSetRef       NVARCHAR(200) = NULL,
    @RunStatus           NVARCHAR(30) = N'CALCULATED',
    @ApprovedBy          NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.mst_channel WHERE channel_id = @TargetChannelId)
        THROW 51151, N'target_channel_id not found.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.mst_channel WHERE channel_id = @SourceChannelId)
        THROW 51152, N'source_channel_id not found.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.mst_period WHERE period_id = @PeriodId)
        THROW 51153, N'period_id not found.', 1;

    INSERT INTO dbo.sbx_calc_run
        (target_channel_id, source_channel_id, period_id, engine, formula_set_ref, run_status, approved_by, created_at, updated_at)
    VALUES
        (@TargetChannelId, @SourceChannelId, @PeriodId, @Engine, @FormulaSetRef, @RunStatus, @ApprovedBy, SYSUTCDATETIME(), NULL);

    SET @SandboxRunId = CAST(SCOPE_IDENTITY() AS BIGINT);
END
GO

-- ============================================================================
-- 7) sbx_incentive_detail
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_sbx_incentive_detail_insert
    @SandboxIncentiveDetailId  BIGINT = NULL OUTPUT,
    @SandboxRunId              BIGINT,
    @SalesmanCode              NVARCHAR(100),
    @ProductCode               NVARCHAR(100),
    @TargetAmount              DECIMAL(18,2),
    @ActualAmount              DECIMAL(18,2),
    @Achievement               DECIMAL(9,4),
    @GoalMultiplier            DECIMAL(9,4),
    @IncentiveBase             DECIMAL(18,2),
    @ProductWeight             DECIMAL(9,4),
    @FormulaExpr               NVARCHAR(1000),
    @IncentiveAmount           DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.sbx_calc_run WHERE sandbox_run_id = @SandboxRunId)
        THROW 51161, N'sandbox_run_id not found.', 1;

    INSERT INTO dbo.sbx_incentive_detail
        (sandbox_run_id, salesman_code, product_code, target_amount, actual_amount, achievement,
         goal_multiplier, incentive_base, product_weight, formula_expr, incentive_amount, created_at)
    VALUES
        (@SandboxRunId, @SalesmanCode, @ProductCode, @TargetAmount, @ActualAmount, @Achievement,
         @GoalMultiplier, @IncentiveBase, @ProductWeight, @FormulaExpr, @IncentiveAmount, SYSUTCDATETIME());

    SET @SandboxIncentiveDetailId = CAST(SCOPE_IDENTITY() AS BIGINT);
END
GO
