USE [AJT_SIS];
GO

-- Schema: dbo (default — no custom schema needed)

IF OBJECT_ID('dbo.mst_channel', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.mst_channel (
        channel_id INT IDENTITY(1,1) NOT NULL,
        channel_code NVARCHAR(20) NOT NULL,
        channel_name_th NVARCHAR(100) NOT NULL,
        channel_name_en NVARCHAR(100) NOT NULL,
        calc_type NVARCHAR(30) NOT NULL,
        is_active BIT NOT NULL CONSTRAINT DF_mst_channel_is_active DEFAULT (1),
        created_at DATETIME2(0) NOT NULL CONSTRAINT DF_mst_channel_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at DATETIME2(0) NULL,
        CONSTRAINT PK_mst_channel PRIMARY KEY CLUSTERED (channel_id),
        CONSTRAINT UQ_mst_channel_code UNIQUE (channel_code)
    );
END
GO

IF OBJECT_ID('dbo.mst_position_level', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.mst_position_level (
        position_level_id INT IDENTITY(1,1) NOT NULL,
        position_code NVARCHAR(50) NOT NULL,
        position_name_th NVARCHAR(100) NOT NULL,
        position_name_en NVARCHAR(100) NULL,
        hierarchy_level TINYINT NOT NULL,
        is_active BIT NOT NULL CONSTRAINT DF_mst_position_level_is_active DEFAULT (1),
        created_at DATETIME2(0) NOT NULL CONSTRAINT DF_mst_position_level_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at DATETIME2(0) NULL,
        CONSTRAINT PK_mst_position_level PRIMARY KEY CLUSTERED (position_level_id),
        CONSTRAINT UQ_mst_position_level_code UNIQUE (position_code)
    );
END
GO

IF OBJECT_ID('dbo.mst_job_function', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.mst_job_function (
        job_function_id INT IDENTITY(1,1) NOT NULL,
        job_function_code NVARCHAR(50) NOT NULL,
        job_function_name_th NVARCHAR(150) NOT NULL,
        job_function_name_en NVARCHAR(150) NULL,
        channel_id INT NULL,
        is_fixed_rate_eligible BIT NOT NULL CONSTRAINT DF_mst_job_function_fixed_rate DEFAULT (0),
        is_active BIT NOT NULL CONSTRAINT DF_mst_job_function_is_active DEFAULT (1),
        created_at DATETIME2(0) NOT NULL CONSTRAINT DF_mst_job_function_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at DATETIME2(0) NULL,
        CONSTRAINT PK_mst_job_function PRIMARY KEY CLUSTERED (job_function_id),
        CONSTRAINT UQ_mst_job_function_code UNIQUE (job_function_code),
        CONSTRAINT FK_mst_job_function_channel FOREIGN KEY (channel_id) REFERENCES dbo.mst_channel(channel_id)
    );
END
GO

IF OBJECT_ID('dbo.mst_employee', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.mst_employee (
        employee_id INT IDENTITY(1,1) NOT NULL,
        employee_code NVARCHAR(50) NOT NULL,
        employee_name_th NVARCHAR(200) NOT NULL,
        employee_name_en NVARCHAR(200) NULL,
        channel_id INT NULL,
        job_function_id INT NULL,
        position_level_id INT NULL,
        cost_center NVARCHAR(50) NULL,
        company_code NVARCHAR(50) NULL,
        effective_from DATE NOT NULL,
        effective_to DATE NULL,
        is_active BIT NOT NULL CONSTRAINT DF_mst_employee_is_active DEFAULT (1),
        created_at DATETIME2(0) NOT NULL CONSTRAINT DF_mst_employee_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at DATETIME2(0) NULL,
        CONSTRAINT PK_mst_employee PRIMARY KEY CLUSTERED (employee_id),
        CONSTRAINT UQ_mst_employee_code UNIQUE (employee_code),
        CONSTRAINT FK_mst_employee_channel FOREIGN KEY (channel_id) REFERENCES dbo.mst_channel(channel_id),
        CONSTRAINT FK_mst_employee_job_function FOREIGN KEY (job_function_id) REFERENCES dbo.mst_job_function(job_function_id),
        CONSTRAINT FK_mst_employee_position_level FOREIGN KEY (position_level_id) REFERENCES dbo.mst_position_level(position_level_id)
    );
END
GO

IF OBJECT_ID('dbo.mst_org_hierarchy', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.mst_org_hierarchy (
        hierarchy_id INT IDENTITY(1,1) NOT NULL,
        channel_id INT NOT NULL,
        effective_month DATE NOT NULL,
        salesman_code NVARCHAR(50) NOT NULL,
        direct_sup_code NVARCHAR(50) NULL,
        dept_mgr_code NVARCHAR(50) NULL,
        div_mgr_code NVARCHAR(50) NULL,
        ad_code NVARCHAR(50) NULL,
        is_active BIT NOT NULL CONSTRAINT DF_mst_org_hierarchy_is_active DEFAULT (1),
        created_at DATETIME2(0) NOT NULL CONSTRAINT DF_mst_org_hierarchy_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at DATETIME2(0) NULL,
        CONSTRAINT PK_mst_org_hierarchy PRIMARY KEY CLUSTERED (hierarchy_id),
        CONSTRAINT UQ_mst_org_hierarchy UNIQUE (channel_id, effective_month, salesman_code),
        CONSTRAINT FK_mst_org_hierarchy_channel FOREIGN KEY (channel_id) REFERENCES dbo.mst_channel(channel_id)
    );

    CREATE INDEX IX_mst_org_hierarchy_effective_month ON dbo.mst_org_hierarchy (effective_month);
END
GO

IF OBJECT_ID('dbo.mst_product', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.mst_product (
        product_id INT IDENTITY(1,1) NOT NULL,
        product_code NVARCHAR(50) NOT NULL,
        product_name_th NVARCHAR(200) NOT NULL,
        product_name_en NVARCHAR(200) NULL,
        product_group_code NVARCHAR(50) NULL,
        product_group_name NVARCHAR(150) NULL,
        is_gd_product BIT NOT NULL CONSTRAINT DF_mst_product_is_gd DEFAULT (0),
        gd_product_code NVARCHAR(50) NULL,
        is_active BIT NOT NULL CONSTRAINT DF_mst_product_is_active DEFAULT (1),
        created_at DATETIME2(0) NOT NULL CONSTRAINT DF_mst_product_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at DATETIME2(0) NULL,
        CONSTRAINT PK_mst_product PRIMARY KEY CLUSTERED (product_id),
        CONSTRAINT UQ_mst_product_code UNIQUE (product_code)
    );
END
GO

IF OBJECT_ID('dbo.mst_product_mapping', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.mst_product_mapping (
        product_mapping_id INT IDENTITY(1,1) NOT NULL,
        source_system NVARCHAR(50) NOT NULL,
        source_product_code NVARCHAR(50) NOT NULL,
        target_product_id INT NOT NULL,
        mapping_type NVARCHAR(50) NOT NULL,
        remarks NVARCHAR(500) NULL,
        is_active BIT NOT NULL CONSTRAINT DF_mst_product_mapping_is_active DEFAULT (1),
        created_at DATETIME2(0) NOT NULL CONSTRAINT DF_mst_product_mapping_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at DATETIME2(0) NULL,
        CONSTRAINT PK_mst_product_mapping PRIMARY KEY CLUSTERED (product_mapping_id),
        CONSTRAINT UQ_mst_product_mapping UNIQUE (source_system, source_product_code, mapping_type),
        CONSTRAINT FK_mst_product_mapping_product FOREIGN KEY (target_product_id) REFERENCES dbo.mst_product(product_id)
    );
END
GO

IF OBJECT_ID('dbo.mst_salesman_mapping', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.mst_salesman_mapping (
        salesman_mapping_id INT IDENTITY(1,1) NOT NULL,
        channel_id INT NOT NULL,
        effective_month DATE NOT NULL,
        bi_sales_code NVARCHAR(50) NOT NULL,
        product_group_code NVARCHAR(50) NOT NULL,
        salesman_code NVARCHAR(50) NOT NULL,
        is_active BIT NOT NULL CONSTRAINT DF_mst_salesman_mapping_is_active DEFAULT (1),
        created_at DATETIME2(0) NOT NULL CONSTRAINT DF_mst_salesman_mapping_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at DATETIME2(0) NULL,
        CONSTRAINT PK_mst_salesman_mapping PRIMARY KEY CLUSTERED (salesman_mapping_id),
        CONSTRAINT UQ_mst_salesman_mapping UNIQUE (channel_id, effective_month, bi_sales_code, product_group_code),
        CONSTRAINT FK_mst_salesman_mapping_channel FOREIGN KEY (channel_id) REFERENCES dbo.mst_channel(channel_id)
    );

    CREATE INDEX IX_mst_salesman_mapping_salesman_code ON dbo.mst_salesman_mapping (salesman_code);
END
GO

IF OBJECT_ID('dbo.mst_period', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.mst_period (
        period_id INT IDENTITY(1,1) NOT NULL,
        period_code NVARCHAR(20) NOT NULL,
        sales_month DATE NOT NULL,
        year_no INT NOT NULL,
        month_no TINYINT NOT NULL,
        status NVARCHAR(30) NOT NULL,
        is_closed BIT NOT NULL CONSTRAINT DF_mst_period_is_closed DEFAULT (0),
        created_at DATETIME2(0) NOT NULL CONSTRAINT DF_mst_period_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at DATETIME2(0) NULL,
        CONSTRAINT PK_mst_period PRIMARY KEY CLUSTERED (period_id),
        CONSTRAINT UQ_mst_period_code UNIQUE (period_code),
        CONSTRAINT UQ_mst_period_sales_month UNIQUE (sales_month)
    );
END
GO

IF OBJECT_ID('dbo.mst_payment_cycle', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.mst_payment_cycle (
        payment_cycle_id INT IDENTITY(1,1) NOT NULL,
        sales_month DATE NOT NULL,
        variable_pay_month DATE NOT NULL,
        fixed_pay_month DATE NOT NULL,
        display_order TINYINT NOT NULL,
        is_active BIT NOT NULL CONSTRAINT DF_mst_payment_cycle_is_active DEFAULT (1),
        created_at DATETIME2(0) NOT NULL CONSTRAINT DF_mst_payment_cycle_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at DATETIME2(0) NULL,
        CONSTRAINT PK_mst_payment_cycle PRIMARY KEY CLUSTERED (payment_cycle_id),
        CONSTRAINT UQ_mst_payment_cycle_sales_month UNIQUE (sales_month)
    );
END
GO

IF OBJECT_ID('dbo.mst_goal_threshold', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.mst_goal_threshold (
        goal_threshold_id INT IDENTITY(1,1) NOT NULL,
        achievement_from DECIMAL(9,4) NOT NULL,
        achievement_to DECIMAL(9,4) NULL,
        multiplier DECIMAL(9,4) NOT NULL,
        sequence_no INT NOT NULL,
        is_active BIT NOT NULL CONSTRAINT DF_mst_goal_threshold_is_active DEFAULT (1),
        created_at DATETIME2(0) NOT NULL CONSTRAINT DF_mst_goal_threshold_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at DATETIME2(0) NULL,
        CONSTRAINT PK_mst_goal_threshold PRIMARY KEY CLUSTERED (goal_threshold_id),
        CONSTRAINT UQ_mst_goal_threshold UNIQUE (achievement_from, sequence_no)
    );
END
GO

IF OBJECT_ID('dbo.mst_incentive_rate', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.mst_incentive_rate (
        incentive_rate_id INT IDENTITY(1,1) NOT NULL,
        channel_id INT NOT NULL,
        position_level_id INT NOT NULL,
        ws_type NVARCHAR(50) NOT NULL,
        rate_old DECIMAL(18,2) NULL,
        rate_new DECIMAL(18,2) NULL,
        effective_from DATE NOT NULL,
        effective_to DATE NULL,
        is_active BIT NOT NULL CONSTRAINT DF_mst_incentive_rate_is_active DEFAULT (1),
        created_at DATETIME2(0) NOT NULL CONSTRAINT DF_mst_incentive_rate_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at DATETIME2(0) NULL,
        CONSTRAINT PK_mst_incentive_rate PRIMARY KEY CLUSTERED (incentive_rate_id),
        CONSTRAINT UQ_mst_incentive_rate UNIQUE (channel_id, position_level_id, ws_type, effective_from),
        CONSTRAINT FK_mst_incentive_rate_channel FOREIGN KEY (channel_id) REFERENCES dbo.mst_channel(channel_id),
        CONSTRAINT FK_mst_incentive_rate_position_level FOREIGN KEY (position_level_id) REFERENCES dbo.mst_position_level(position_level_id)
    );
END
GO

IF OBJECT_ID('dbo.mst_product_weight', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.mst_product_weight (
        product_weight_id INT IDENTITY(1,1) NOT NULL,
        channel_id INT NOT NULL,
        product_id INT NOT NULL,
        ws_type NVARCHAR(50) NOT NULL,
        weight_percent DECIMAL(9,4) NOT NULL,
        effective_from DATE NOT NULL,
        effective_to DATE NULL,
        is_active BIT NOT NULL CONSTRAINT DF_mst_product_weight_is_active DEFAULT (1),
        created_at DATETIME2(0) NOT NULL CONSTRAINT DF_mst_product_weight_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at DATETIME2(0) NULL,
        CONSTRAINT PK_mst_product_weight PRIMARY KEY CLUSTERED (product_weight_id),
        CONSTRAINT UQ_mst_product_weight UNIQUE (channel_id, product_id, ws_type, effective_from),
        CONSTRAINT FK_mst_product_weight_channel FOREIGN KEY (channel_id) REFERENCES dbo.mst_channel(channel_id),
        CONSTRAINT FK_mst_product_weight_product FOREIGN KEY (product_id) REFERENCES dbo.mst_product(product_id)
    );
END
GO

IF OBJECT_ID('dbo.mst_shortage_policy', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.mst_shortage_policy (
        shortage_policy_id INT IDENTITY(1,1) NOT NULL,
        product_id INT NOT NULL,
        shortage_month DATE NOT NULL,
        override_achievement DECIMAL(9,4) NOT NULL CONSTRAINT DF_mst_shortage_policy_override DEFAULT (1.0000),
        reason_code NVARCHAR(50) NULL,
        remarks NVARCHAR(500) NULL,
        is_active BIT NOT NULL CONSTRAINT DF_mst_shortage_policy_is_active DEFAULT (1),
        created_at DATETIME2(0) NOT NULL CONSTRAINT DF_mst_shortage_policy_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at DATETIME2(0) NULL,
        CONSTRAINT PK_mst_shortage_policy PRIMARY KEY CLUSTERED (shortage_policy_id),
        CONSTRAINT UQ_mst_shortage_policy UNIQUE (product_id, shortage_month),
        CONSTRAINT FK_mst_shortage_policy_product FOREIGN KEY (product_id) REFERENCES dbo.mst_product(product_id)
    );
END
GO

IF OBJECT_ID('dbo.mst_fix_rate', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.mst_fix_rate (
        fix_rate_id INT IDENTITY(1,1) NOT NULL,
        channel_id INT NOT NULL,
        job_function_id INT NOT NULL,
        amount DECIMAL(18,2) NOT NULL,
        effective_from DATE NOT NULL,
        effective_to DATE NULL,
        is_active BIT NOT NULL CONSTRAINT DF_mst_fix_rate_is_active DEFAULT (1),
        created_at DATETIME2(0) NOT NULL CONSTRAINT DF_mst_fix_rate_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at DATETIME2(0) NULL,
        CONSTRAINT PK_mst_fix_rate PRIMARY KEY CLUSTERED (fix_rate_id),
        CONSTRAINT UQ_mst_fix_rate UNIQUE (channel_id, job_function_id, effective_from),
        CONSTRAINT FK_mst_fix_rate_channel FOREIGN KEY (channel_id) REFERENCES dbo.mst_channel(channel_id),
        CONSTRAINT FK_mst_fix_rate_job_function FOREIGN KEY (job_function_id) REFERENCES dbo.mst_job_function(job_function_id)
    );
END
GO

IF OBJECT_ID('dbo.mst_gd_product', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.mst_gd_product (
        gd_product_id INT IDENTITY(1,1) NOT NULL,
        product_id INT NOT NULL,
        gd_product_code NVARCHAR(50) NOT NULL,
        gd_product_name_th NVARCHAR(150) NOT NULL,
        gd_product_name_en NVARCHAR(150) NULL,
        channel_id INT NULL,
        is_active BIT NOT NULL CONSTRAINT DF_mst_gd_product_is_active DEFAULT (1),
        created_at DATETIME2(0) NOT NULL CONSTRAINT DF_mst_gd_product_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at DATETIME2(0) NULL,
        CONSTRAINT PK_mst_gd_product PRIMARY KEY CLUSTERED (gd_product_id),
        CONSTRAINT UQ_mst_gd_product_code UNIQUE (gd_product_code),
        CONSTRAINT UQ_mst_gd_product_product UNIQUE (product_id),
        CONSTRAINT FK_mst_gd_product_product FOREIGN KEY (product_id) REFERENCES dbo.mst_product(product_id),
        CONSTRAINT FK_mst_gd_product_channel FOREIGN KEY (channel_id) REFERENCES dbo.mst_channel(channel_id)
    );
END
GO

IF OBJECT_ID('dbo.mst_gd_payout', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.mst_gd_payout (
        gd_payout_id INT IDENTITY(1,1) NOT NULL,
        gd_product_id INT NOT NULL,
        achievement_from DECIMAL(9,4) NOT NULL,
        achievement_to DECIMAL(9,4) NULL,
        payout_amount DECIMAL(18,2) NOT NULL,
        sequence_no INT NOT NULL,
        effective_from DATE NOT NULL,
        effective_to DATE NULL,
        is_active BIT NOT NULL CONSTRAINT DF_mst_gd_payout_is_active DEFAULT (1),
        created_at DATETIME2(0) NOT NULL CONSTRAINT DF_mst_gd_payout_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at DATETIME2(0) NULL,
        CONSTRAINT PK_mst_gd_payout PRIMARY KEY CLUSTERED (gd_payout_id),
        CONSTRAINT UQ_mst_gd_payout UNIQUE (gd_product_id, achievement_from, effective_from),
        CONSTRAINT FK_mst_gd_payout_gd_product FOREIGN KEY (gd_product_id) REFERENCES dbo.mst_gd_product(gd_product_id)
    );
END
GO

IF OBJECT_ID('dbo.mst_system_parameter', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.mst_system_parameter (
        system_parameter_id INT IDENTITY(1,1) NOT NULL,
        parameter_group NVARCHAR(100) NOT NULL,
        parameter_code NVARCHAR(100) NOT NULL,
        parameter_value NVARCHAR(500) NOT NULL,
        parameter_type NVARCHAR(30) NOT NULL,
        effective_from DATE NOT NULL,
        effective_to DATE NULL,
        is_active BIT NOT NULL CONSTRAINT DF_mst_system_parameter_is_active DEFAULT (1),
        created_at DATETIME2(0) NOT NULL CONSTRAINT DF_mst_system_parameter_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at DATETIME2(0) NULL,
        CONSTRAINT PK_mst_system_parameter PRIMARY KEY CLUSTERED (system_parameter_id),
        CONSTRAINT UQ_mst_system_parameter UNIQUE (parameter_group, parameter_code, effective_from)
    );
END
GO

IF OBJECT_ID('dbo.mst_policy_rule', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.mst_policy_rule (
        policy_rule_id INT IDENTITY(1,1) NOT NULL,
        rule_code NVARCHAR(100) NOT NULL,
        rule_name NVARCHAR(200) NOT NULL,
        rule_value NVARCHAR(500) NULL,
        rule_description NVARCHAR(1000) NULL,
        approval_status NVARCHAR(30) NOT NULL,
        effective_from DATE NOT NULL,
        effective_to DATE NULL,
        is_active BIT NOT NULL CONSTRAINT DF_mst_policy_rule_is_active DEFAULT (1),
        created_at DATETIME2(0) NOT NULL CONSTRAINT DF_mst_policy_rule_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at DATETIME2(0) NULL,
        CONSTRAINT PK_mst_policy_rule PRIMARY KEY CLUSTERED (policy_rule_id),
        CONSTRAINT UQ_mst_policy_rule UNIQUE (rule_code, effective_from)
    );
END
GO

