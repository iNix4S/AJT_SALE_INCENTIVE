-- =============================================================
-- AJT_SIS: Transaction + Interface Tables — Full Design
-- Date: 2026-06-13  Version: v1.0
-- Scope:
--   A) Interface Staging (inbound from BI/DWC and HCM)
--   B) Calculation Transaction (targets, actuals, results)
--   C) Output (For HR: variable + fixed)
--   D) Audit / Change Log
-- =============================================================

USE [AJT_SIS];
GO

-- ============================================================
-- A1. INTERFACE: Staging — BI/DWC Sales (inbound raw)
--     Source: IR-001  BI/DWC → Incentive System
-- ============================================================

IF OBJECT_ID('dbo.stg_bi_sales', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.stg_bi_sales (
        stg_bi_sales_id     BIGINT IDENTITY(1,1) NOT NULL,
        batch_id            NVARCHAR(50)    NOT NULL,           -- รหัสชุดการนำเข้า
        import_date         DATETIME2(0)    NOT NULL CONSTRAINT DF_stg_bi_sales_import_date DEFAULT (SYSUTCDATETIME()),
        source_system       NVARCHAR(50)    NOT NULL,           -- 'BI' | 'DWC'
        data_month          DATE            NOT NULL,           -- เดือนยอดขาย YYYY-MM-01
        channel_code        NVARCHAR(20)    NOT NULL,           -- MT | TT
        bi_sales_code       NVARCHAR(50)    NULL,               -- MT: บัญชี BI (ก่อน mapping)
        salesman_code       NVARCHAR(50)    NULL,               -- TT: Salesman Code ตรง
        product_code        NVARCHAR(50)    NOT NULL,           -- MT: Product Group / TT: SKU
        actual_qty          DECIMAL(18,4)   NULL,
        actual_amount       DECIMAL(18,2)   NOT NULL,
        currency            NVARCHAR(10)    NOT NULL CONSTRAINT DF_stg_bi_sales_currency DEFAULT ('THB'),
        raw_row_no          INT             NULL,               -- ลำดับแถวต้นฉบับ
        status              NVARCHAR(20)    NOT NULL CONSTRAINT DF_stg_bi_sales_status DEFAULT ('PENDING'),
        -- PENDING | VALIDATED | ERROR | PROCESSED
        error_message       NVARCHAR(1000)  NULL,
        created_at          DATETIME2(0)    NOT NULL CONSTRAINT DF_stg_bi_sales_created_at DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_stg_bi_sales PRIMARY KEY CLUSTERED (stg_bi_sales_id)
    );
    CREATE INDEX IX_stg_bi_sales_batch ON dbo.stg_bi_sales (batch_id);
    CREATE INDEX IX_stg_bi_sales_data_month ON dbo.stg_bi_sales (data_month, channel_code);
END
GO

-- ============================================================
-- A2. INTERFACE: Staging — HCM Employee (inbound raw)
--     Source: IR-002  HCM → Incentive System
--     Report: Personal Employment (Main & Active)_AST
-- ============================================================

IF OBJECT_ID('dbo.stg_hcm_employee', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.stg_hcm_employee (
        stg_hcm_employee_id BIGINT IDENTITY(1,1) NOT NULL,
        batch_id            NVARCHAR(50)    NOT NULL,
        import_date         DATETIME2(0)    NOT NULL CONSTRAINT DF_stg_hcm_emp_import_date DEFAULT (SYSUTCDATETIME()),
        source_system       NVARCHAR(50)    NOT NULL CONSTRAINT DF_stg_hcm_emp_source DEFAULT ('HCM'),
        data_month          DATE            NOT NULL,           -- เดือนข้อมูล
        employee_code       NVARCHAR(50)    NOT NULL,
        employee_name_th    NVARCHAR(200)   NOT NULL,
        employee_name_en    NVARCHAR(200)   NULL,
        company_code        NVARCHAR(50)    NULL,
        cost_center         NVARCHAR(50)    NULL,
        position_code       NVARCHAR(50)    NULL,               -- map → mst_position_level
        job_function_code   NVARCHAR(50)    NULL,               -- map → mst_job_function
        channel_code        NVARCHAR(20)    NULL,               -- map → mst_channel
        employment_status   NVARCHAR(30)    NULL,               -- Active | Inactive
        hire_date           DATE            NULL,
        termination_date    DATE            NULL,
        raw_row_no          INT             NULL,
        status              NVARCHAR(20)    NOT NULL CONSTRAINT DF_stg_hcm_emp_status DEFAULT ('PENDING'),
        error_message       NVARCHAR(1000)  NULL,
        created_at          DATETIME2(0)    NOT NULL CONSTRAINT DF_stg_hcm_emp_created_at DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_stg_hcm_employee PRIMARY KEY CLUSTERED (stg_hcm_employee_id)
    );
    CREATE INDEX IX_stg_hcm_employee_batch ON dbo.stg_hcm_employee (batch_id);
    CREATE INDEX IX_stg_hcm_employee_month ON dbo.stg_hcm_employee (data_month, employee_code);
END
GO

-- ============================================================
-- A3. INTERFACE: Import Batch Log
-- ============================================================

IF OBJECT_ID('dbo.int_import_batch', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.int_import_batch (
        batch_id            NVARCHAR(50)    NOT NULL,
        batch_type          NVARCHAR(30)    NOT NULL,           -- BI_SALES | HCM_EMPLOYEE
        source_system       NVARCHAR(50)    NOT NULL,
        data_month          DATE            NOT NULL,
        file_name           NVARCHAR(500)   NULL,
        total_rows          INT             NOT NULL CONSTRAINT DF_int_batch_total DEFAULT (0),
        valid_rows          INT             NOT NULL CONSTRAINT DF_int_batch_valid DEFAULT (0),
        error_rows          INT             NOT NULL CONSTRAINT DF_int_batch_error DEFAULT (0),
        status              NVARCHAR(20)    NOT NULL CONSTRAINT DF_int_batch_status DEFAULT ('IN_PROGRESS'),
        -- IN_PROGRESS | COMPLETED | FAILED | PARTIAL
        started_at          DATETIME2(0)    NOT NULL CONSTRAINT DF_int_batch_started DEFAULT (SYSUTCDATETIME()),
        completed_at        DATETIME2(0)    NULL,
        created_by          NVARCHAR(100)   NULL,
        CONSTRAINT PK_int_import_batch PRIMARY KEY CLUSTERED (batch_id)
    );
    CREATE INDEX IX_int_import_batch_type_month ON dbo.int_import_batch (batch_type, data_month);
END
GO

-- ============================================================
-- B1. TRANSACTION: Sales Actual (validated, after mapping)
-- ============================================================

IF OBJECT_ID('dbo.trn_sales_actual', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.trn_sales_actual (
        sales_actual_id     BIGINT IDENTITY(1,1) NOT NULL,
        period_id           INT             NOT NULL,
        channel_id          INT             NOT NULL,
        salesman_code       NVARCHAR(50)    NOT NULL,
        product_code        NVARCHAR(50)    NOT NULL,           -- MT: Product Group / TT: SKU
        actual_amount       DECIMAL(18,2)   NOT NULL,
        actual_qty          DECIMAL(18,4)   NULL,
        source_batch_id     NVARCHAR(50)    NOT NULL,
        created_at          DATETIME2(0)    NOT NULL CONSTRAINT DF_trn_sales_actual_created_at DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_trn_sales_actual PRIMARY KEY CLUSTERED (sales_actual_id),
        CONSTRAINT UQ_trn_sales_actual UNIQUE (period_id, channel_id, salesman_code, product_code),
        CONSTRAINT FK_trn_sales_actual_period FOREIGN KEY (period_id) REFERENCES dbo.mst_period(period_id),
        CONSTRAINT FK_trn_sales_actual_channel FOREIGN KEY (channel_id) REFERENCES dbo.mst_channel(channel_id)
    );
    CREATE INDEX IX_trn_sales_actual_period_channel ON dbo.trn_sales_actual (period_id, channel_id);
    CREATE INDEX IX_trn_sales_actual_salesman ON dbo.trn_sales_actual (salesman_code);
END
GO

-- ============================================================
-- B2. TRANSACTION: Sales Target (per period / salesman / product)
-- ============================================================

IF OBJECT_ID('dbo.trn_sales_target', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.trn_sales_target (
        sales_target_id     BIGINT IDENTITY(1,1) NOT NULL,
        period_id           INT             NOT NULL,
        channel_id          INT             NOT NULL,
        salesman_code       NVARCHAR(50)    NOT NULL,
        product_code        NVARCHAR(50)    NOT NULL,
        target_amount       DECIMAL(18,2)   NOT NULL,
        approved_by         NVARCHAR(100)   NULL,
        approved_at         DATETIME2(0)    NULL,
        created_at          DATETIME2(0)    NOT NULL CONSTRAINT DF_trn_sales_target_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at          DATETIME2(0)    NULL,
        CONSTRAINT PK_trn_sales_target PRIMARY KEY CLUSTERED (sales_target_id),
        CONSTRAINT UQ_trn_sales_target UNIQUE (period_id, channel_id, salesman_code, product_code),
        CONSTRAINT FK_trn_sales_target_period FOREIGN KEY (period_id) REFERENCES dbo.mst_period(period_id),
        CONSTRAINT FK_trn_sales_target_channel FOREIGN KEY (channel_id) REFERENCES dbo.mst_channel(channel_id)
    );
    CREATE INDEX IX_trn_sales_target_period_channel ON dbo.trn_sales_target (period_id, channel_id);
END
GO

-- ============================================================
-- B3. TRANSACTION: Calculation Run (header per period + channel)
-- ============================================================

IF OBJECT_ID('dbo.trn_calc_run', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.trn_calc_run (
        calc_run_id         INT IDENTITY(1,1) NOT NULL,
        period_id           INT             NOT NULL,
        channel_id          INT             NOT NULL,
        run_status          NVARCHAR(30)    NOT NULL CONSTRAINT DF_trn_calc_run_status DEFAULT ('DRAFT'),
        -- DRAFT | CALCULATED | REVIEWED | APPROVED | EXPORTED
        calculated_at       DATETIME2(0)    NULL,
        reviewed_at         DATETIME2(0)    NULL,
        approved_at         DATETIME2(0)    NULL,
        exported_at         DATETIME2(0)    NULL,
        approved_by         NVARCHAR(100)   NULL,
        remarks             NVARCHAR(500)   NULL,
        created_at          DATETIME2(0)    NOT NULL CONSTRAINT DF_trn_calc_run_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at          DATETIME2(0)    NULL,
        CONSTRAINT PK_trn_calc_run PRIMARY KEY CLUSTERED (calc_run_id),
        CONSTRAINT UQ_trn_calc_run UNIQUE (period_id, channel_id),
        CONSTRAINT FK_trn_calc_run_period FOREIGN KEY (period_id) REFERENCES dbo.mst_period(period_id),
        CONSTRAINT FK_trn_calc_run_channel FOREIGN KEY (channel_id) REFERENCES dbo.mst_channel(channel_id)
    );
END
GO

-- ============================================================
-- B4. TRANSACTION: Incentive Calculation Detail (per salesman/product)
-- ============================================================

IF OBJECT_ID('dbo.trn_incentive_detail', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.trn_incentive_detail (
        incentive_detail_id BIGINT IDENTITY(1,1) NOT NULL,
        calc_run_id         INT             NOT NULL,
        salesman_code       NVARCHAR(50)    NOT NULL,
        position_level_code NVARCHAR(50)    NOT NULL,           -- STAFF | SECT_MGR | DEPT_MGR | AD
        product_code        NVARCHAR(50)    NOT NULL,
        target_amount       DECIMAL(18,2)   NOT NULL,
        actual_amount       DECIMAL(18,2)   NOT NULL,
        achievement         DECIMAL(9,4)    NOT NULL,           -- ROUND(actual/target, 4)
        shortage_flag       BIT             NOT NULL CONSTRAINT DF_trn_inc_det_shortage DEFAULT (0),
        final_achievement   DECIMAL(9,4)    NOT NULL,           -- after shortage override
        goal_multiplier     DECIMAL(9,4)    NOT NULL,           -- XLOOKUP result
        incentive_base      DECIMAL(18,2)   NOT NULL,
        product_weight      DECIMAL(9,4)    NOT NULL,
        incentive_amount    DECIMAL(18,2)   NOT NULL,           -- base × GOAL × weight
        created_at          DATETIME2(0)    NOT NULL CONSTRAINT DF_trn_inc_det_created_at DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_trn_incentive_detail PRIMARY KEY CLUSTERED (incentive_detail_id),
        CONSTRAINT UQ_trn_incentive_detail UNIQUE (calc_run_id, salesman_code, position_level_code, product_code),
        CONSTRAINT FK_trn_incentive_detail_run FOREIGN KEY (calc_run_id) REFERENCES dbo.trn_calc_run(calc_run_id)
    );
    CREATE INDEX IX_trn_incentive_detail_salesman ON dbo.trn_incentive_detail (calc_run_id, salesman_code);
END
GO

-- ============================================================
-- B5. TRANSACTION: GD Incentive Detail
-- ============================================================

IF OBJECT_ID('dbo.trn_gd_incentive_detail', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.trn_gd_incentive_detail (
        gd_incentive_id     BIGINT IDENTITY(1,1) NOT NULL,
        calc_run_id         INT             NOT NULL,
        salesman_code       NVARCHAR(50)    NOT NULL,
        gd_product_id       INT             NOT NULL,
        incentive_month     DATE            NOT NULL,           -- เดือนที่คำนวณ (1 ใน 12)
        target_amount       DECIMAL(18,2)   NOT NULL,
        actual_amount       DECIMAL(18,2)   NOT NULL,
        achievement         DECIMAL(9,4)    NOT NULL,
        payout_amount       DECIMAL(18,2)   NOT NULL,           -- VLOOKUP step payout
        created_at          DATETIME2(0)    NOT NULL CONSTRAINT DF_trn_gd_inc_created_at DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_trn_gd_incentive_detail PRIMARY KEY CLUSTERED (gd_incentive_id),
        CONSTRAINT UQ_trn_gd_incentive UNIQUE (calc_run_id, salesman_code, gd_product_id, incentive_month),
        CONSTRAINT FK_trn_gd_inc_run FOREIGN KEY (calc_run_id) REFERENCES dbo.trn_calc_run(calc_run_id),
        CONSTRAINT FK_trn_gd_inc_product FOREIGN KEY (gd_product_id) REFERENCES dbo.mst_gd_product(gd_product_id)
    );
    CREATE INDEX IX_trn_gd_incentive_salesman ON dbo.trn_gd_incentive_detail (calc_run_id, salesman_code);
END
GO

-- ============================================================
-- C1. OUTPUT: For HR — Variable Incentive (one row per employee per run)
-- ============================================================

IF OBJECT_ID('dbo.out_for_hr_variable', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.out_for_hr_variable (
        for_hr_variable_id  BIGINT IDENTITY(1,1) NOT NULL,
        calc_run_id         INT             NOT NULL,
        employee_code       NVARCHAR(50)    NOT NULL,
        employee_name_th    NVARCHAR(200)   NOT NULL,
        position_level_code NVARCHAR(50)    NOT NULL,
        channel_code        NVARCHAR(20)    NOT NULL,
        variable_pay_month  DATE            NOT NULL,           -- from mst_payment_cycle
        incentive_staff     DECIMAL(18,2)   NOT NULL CONSTRAINT DF_out_hr_var_staff DEFAULT (0),
        incentive_sect      DECIMAL(18,2)   NOT NULL CONSTRAINT DF_out_hr_var_sect DEFAULT (0),
        incentive_dept      DECIMAL(18,2)   NOT NULL CONSTRAINT DF_out_hr_var_dept DEFAULT (0),
        incentive_ad        DECIMAL(18,2)   NOT NULL CONSTRAINT DF_out_hr_var_ad DEFAULT (0),
        gd_incentive_total  DECIMAL(18,2)   NOT NULL CONSTRAINT DF_out_hr_var_gd DEFAULT (0),
        total_variable      DECIMAL(18,2)   NOT NULL,           -- sum after floor logic
        payment_method      NVARCHAR(50)    NULL,
        export_batch_id     NVARCHAR(50)    NULL,
        created_at          DATETIME2(0)    NOT NULL CONSTRAINT DF_out_hr_var_created_at DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_out_for_hr_variable PRIMARY KEY CLUSTERED (for_hr_variable_id),
        CONSTRAINT UQ_out_for_hr_variable UNIQUE (calc_run_id, employee_code),
        CONSTRAINT FK_out_hr_var_run FOREIGN KEY (calc_run_id) REFERENCES dbo.trn_calc_run(calc_run_id)
    );
    CREATE INDEX IX_out_hr_var_run ON dbo.out_for_hr_variable (calc_run_id);
    CREATE INDEX IX_out_hr_var_pay_month ON dbo.out_for_hr_variable (variable_pay_month);
END
GO

-- ============================================================
-- C2. OUTPUT: For HR — Fixed Incentive
-- ============================================================

IF OBJECT_ID('dbo.out_for_hr_fixed', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.out_for_hr_fixed (
        for_hr_fixed_id     BIGINT IDENTITY(1,1) NOT NULL,
        calc_run_id         INT             NOT NULL,
        employee_code       NVARCHAR(50)    NOT NULL,
        employee_name_th    NVARCHAR(200)   NOT NULL,
        job_function_code   NVARCHAR(50)    NOT NULL,
        channel_code        NVARCHAR(20)    NOT NULL,
        fixed_pay_month     DATE            NOT NULL,           -- from mst_payment_cycle
        fix_rate_amount     DECIMAL(18,2)   NOT NULL,
        total_fixed         DECIMAL(18,2)   NOT NULL,
        payment_method      NVARCHAR(50)    NULL,
        export_batch_id     NVARCHAR(50)    NULL,
        created_at          DATETIME2(0)    NOT NULL CONSTRAINT DF_out_hr_fix_created_at DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_out_for_hr_fixed PRIMARY KEY CLUSTERED (for_hr_fixed_id),
        CONSTRAINT UQ_out_for_hr_fixed UNIQUE (calc_run_id, employee_code),
        CONSTRAINT FK_out_hr_fix_run FOREIGN KEY (calc_run_id) REFERENCES dbo.trn_calc_run(calc_run_id)
    );
    CREATE INDEX IX_out_hr_fix_run ON dbo.out_for_hr_fixed (calc_run_id);
    CREATE INDEX IX_out_hr_fix_pay_month ON dbo.out_for_hr_fixed (fixed_pay_month);
END
GO

-- ============================================================
-- C3. OUTPUT: Export Batch Log (SSRS output record)
-- ============================================================

IF OBJECT_ID('dbo.out_export_batch', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.out_export_batch (
        export_batch_id     NVARCHAR(50)    NOT NULL,
        calc_run_id         INT             NOT NULL,
        export_type         NVARCHAR(30)    NOT NULL,           -- VARIABLE | FIXED | GD | ALL
        export_format       NVARCHAR(20)    NOT NULL CONSTRAINT DF_out_export_format DEFAULT ('SSRS'),
        file_name           NVARCHAR(500)   NULL,
        total_employees     INT             NOT NULL CONSTRAINT DF_out_export_total DEFAULT (0),
        total_amount        DECIMAL(18,2)   NOT NULL CONSTRAINT DF_out_export_amount DEFAULT (0),
        exported_at         DATETIME2(0)    NOT NULL CONSTRAINT DF_out_export_at DEFAULT (SYSUTCDATETIME()),
        exported_by         NVARCHAR(100)   NULL,
        CONSTRAINT PK_out_export_batch PRIMARY KEY CLUSTERED (export_batch_id),
        CONSTRAINT FK_out_export_run FOREIGN KEY (calc_run_id) REFERENCES dbo.trn_calc_run(calc_run_id)
    );
END
GO

-- ============================================================
-- D1. AUDIT: Parameter Change Log
-- ============================================================

IF OBJECT_ID('dbo.aud_parameter_change', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.aud_parameter_change (
        change_id           BIGINT IDENTITY(1,1) NOT NULL,
        table_name          NVARCHAR(100)   NOT NULL,           -- ชื่อตารางที่แก้
        record_id           NVARCHAR(100)   NOT NULL,           -- PK ของแถวที่แก้
        field_name          NVARCHAR(100)   NOT NULL,
        old_value           NVARCHAR(1000)  NULL,
        new_value           NVARCHAR(1000)  NULL,
        change_reason       NVARCHAR(500)   NULL,               -- บังคับสำหรับ As-needed
        changed_by          NVARCHAR(100)   NOT NULL,
        changed_at          DATETIME2(3)    NOT NULL CONSTRAINT DF_aud_param_changed_at DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_aud_parameter_change PRIMARY KEY CLUSTERED (change_id)
    );
    CREATE INDEX IX_aud_parameter_change_table ON dbo.aud_parameter_change (table_name, changed_at);
END
GO

-- ============================================================
-- D2. AUDIT: Approval Log
-- ============================================================

IF OBJECT_ID('dbo.aud_approval_log', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.aud_approval_log (
        approval_log_id     BIGINT IDENTITY(1,1) NOT NULL,
        calc_run_id         INT             NOT NULL,
        action              NVARCHAR(30)    NOT NULL,           -- SUBMIT | REVIEW | APPROVE | REJECT | EXPORT
        from_status         NVARCHAR(30)    NOT NULL,
        to_status           NVARCHAR(30)    NOT NULL,
        performed_by        NVARCHAR(100)   NOT NULL,
        performed_at        DATETIME2(3)    NOT NULL CONSTRAINT DF_aud_approval_at DEFAULT (SYSUTCDATETIME()),
        remarks             NVARCHAR(500)   NULL,
        CONSTRAINT PK_aud_approval_log PRIMARY KEY CLUSTERED (approval_log_id),
        CONSTRAINT FK_aud_approval_run FOREIGN KEY (calc_run_id) REFERENCES dbo.trn_calc_run(calc_run_id)
    );
    CREATE INDEX IX_aud_approval_log_run ON dbo.aud_approval_log (calc_run_id);
END
GO
