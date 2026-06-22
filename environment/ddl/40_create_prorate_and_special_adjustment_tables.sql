-- ============================================================
-- DDL: trn_prorate_adjustment + trn_special_adjustment
-- Purpose: รองรับ Prorate Logic (3.2) และ Special Adjustment (Function 4)
-- Date: 2026-06-22
-- ============================================================

USE [AJT_SALE_INCENTIVE];
GO

-- ============================================================
-- 1. trn_prorate_adjustment
--    บันทึก prorate factor สำหรับพนักงานที่เข้า/ออก/โอนย้ายกลางเดือน
--    prorate_factor = actual_days / total_days
-- ============================================================
IF OBJECT_ID('dbo.trn_prorate_adjustment', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.trn_prorate_adjustment (
        prorate_id    INT           IDENTITY(1,1) NOT NULL,
        period_id     INT           NOT NULL,
        channel_id    INT           NOT NULL,
        employee_code NVARCHAR(50)  NOT NULL,
        prorate_type  NVARCHAR(30)  NOT NULL,   -- JOIN / RESIGN / TRANSFER / POSITION_CHANGE
        actual_days   INT           NOT NULL,   -- วันทำงานจริงในเดือน
        total_days    INT           NOT NULL    -- วันทำงานทั้งหมดในเดือน (ปกติ 22)
            CONSTRAINT DF_prorate_total_days DEFAULT (22),
        remarks       NVARCHAR(500) NULL,
        approved_by   NVARCHAR(100) NULL,
        is_active     BIT           NOT NULL
            CONSTRAINT DF_prorate_is_active DEFAULT (1),
        created_at    DATETIME2(0)  NOT NULL
            CONSTRAINT DF_prorate_created_at DEFAULT SYSUTCDATETIME(),
        updated_at    DATETIME2(0)  NULL,

        CONSTRAINT PK_trn_prorate_adjustment PRIMARY KEY CLUSTERED (prorate_id),
        CONSTRAINT UQ_prorate_period_channel_emp UNIQUE (period_id, channel_id, employee_code),
        CONSTRAINT FK_prorate_period  FOREIGN KEY (period_id)  REFERENCES dbo.mst_period(period_id),
        CONSTRAINT FK_prorate_channel FOREIGN KEY (channel_id) REFERENCES dbo.mst_channel(channel_id),
        CONSTRAINT CK_prorate_type CHECK (prorate_type IN (
            N'JOIN', N'RESIGN', N'TRANSFER', N'POSITION_CHANGE'
        )),
        CONSTRAINT CK_prorate_actual_days CHECK (actual_days >= 0 AND actual_days <= 31),
        CONSTRAINT CK_prorate_total_days  CHECK (total_days  >  0 AND total_days  <= 31)
    );

    CREATE INDEX IX_prorate_period_channel ON dbo.trn_prorate_adjustment (period_id, channel_id);
    PRINT 'trn_prorate_adjustment created';
END
ELSE
BEGIN
    PRINT 'trn_prorate_adjustment already exists';
END
GO

-- ============================================================
-- 2. trn_special_adjustment
--    บันทึก Special Adjustment ทั้ง Shortage และ Special Situation
--    ประเภท SHORTAGE   : override_achievement → ปรับ Actual เป็น Standard 100%
--    ประเภท SPECIAL_SITUATION : adjusted_target_amount + adjusted_weight_percent
-- ============================================================
IF OBJECT_ID('dbo.trn_special_adjustment', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.trn_special_adjustment (
        adjustment_id              INT           IDENTITY(1,1) NOT NULL,
        period_id                  INT           NOT NULL,
        channel_id                 INT           NOT NULL,
        adjustment_type            NVARCHAR(30)  NOT NULL,   -- SHORTAGE / SPECIAL_SITUATION
        employee_code              NVARCHAR(50)  NULL,       -- NULL = ใช้กับทุก employee
        product_code               NVARCHAR(30)  NULL,
        -- สำหรับ SHORTAGE: ปรับ achievement เป็น value นี้ (เช่น 1.0000 = 100%)
        override_achievement       DECIMAL(9,4)  NULL,
        -- สำหรับ SPECIAL_SITUATION: ปรับ target หรือ weight
        adjusted_target_amount     DECIMAL(18,2) NULL,
        adjusted_weight_percent    DECIMAL(9,4)  NULL,
        reason                     NVARCHAR(500) NOT NULL,
        is_active                  BIT           NOT NULL
            CONSTRAINT DF_spadj_is_active DEFAULT (1),
        approved_by                NVARCHAR(100) NULL,
        created_at                 DATETIME2(0)  NOT NULL
            CONSTRAINT DF_spadj_created_at DEFAULT SYSUTCDATETIME(),
        updated_at                 DATETIME2(0)  NULL,

        CONSTRAINT PK_trn_special_adjustment PRIMARY KEY CLUSTERED (adjustment_id),
        CONSTRAINT FK_spadj_period  FOREIGN KEY (period_id)  REFERENCES dbo.mst_period(period_id),
        CONSTRAINT FK_spadj_channel FOREIGN KEY (channel_id) REFERENCES dbo.mst_channel(channel_id),
        CONSTRAINT CK_spadj_type CHECK (adjustment_type IN (N'SHORTAGE', N'SPECIAL_SITUATION'))
    );

    CREATE INDEX IX_spadj_period_channel ON dbo.trn_special_adjustment (period_id, channel_id);
    CREATE INDEX IX_spadj_type ON dbo.trn_special_adjustment (adjustment_type);
    PRINT 'trn_special_adjustment created';
END
ELSE
BEGIN
    PRINT 'trn_special_adjustment already exists';
END
GO

PRINT '══════════════════════════════════════════════════';
PRINT 'Prorate + Special Adjustment tables ready';
PRINT '══════════════════════════════════════════════════';
GO
