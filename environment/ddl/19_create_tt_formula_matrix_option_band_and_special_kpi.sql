SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*
19_create_tt_formula_matrix_option_band_and_special_kpi.sql
Purpose:
1) Add TT formula matrix by ws_type (Top WS, WS SF, WS WH, SF WH)
2) Add Option1 band + payout by G-group
3) Add Special KPI rules and transaction detail table for run pipeline
*/

IF OBJECT_ID('dbo.mst_tt_ws_formula_matrix', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.mst_tt_ws_formula_matrix (
        tt_ws_formula_id INT IDENTITY(1,1) NOT NULL,
        channel_id INT NOT NULL,
        ws_type NVARCHAR(50) NOT NULL,
        product_id INT NOT NULL,
        g_group_code NVARCHAR(20) NOT NULL,
        product_weight_percent DECIMAL(9,4) NOT NULL,
        incentive_base DECIMAL(18,2) NOT NULL,
        effective_from DATE NOT NULL,
        effective_to DATE NULL,
        is_active BIT NOT NULL CONSTRAINT DF_mst_tt_ws_formula_matrix_is_active DEFAULT (1),
        created_at DATETIME2(0) NOT NULL CONSTRAINT DF_mst_tt_ws_formula_matrix_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at DATETIME2(0) NULL,
        CONSTRAINT PK_mst_tt_ws_formula_matrix PRIMARY KEY CLUSTERED (tt_ws_formula_id),
        CONSTRAINT UQ_mst_tt_ws_formula_matrix UNIQUE (channel_id, ws_type, product_id, effective_from),
        CONSTRAINT FK_mst_tt_ws_formula_matrix_channel FOREIGN KEY (channel_id) REFERENCES dbo.mst_channel(channel_id),
        CONSTRAINT FK_mst_tt_ws_formula_matrix_product FOREIGN KEY (product_id) REFERENCES dbo.mst_product(product_id)
    );
END
GO

IF OBJECT_ID('dbo.mst_tt_option1_band', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.mst_tt_option1_band (
        tt_option1_band_id INT IDENTITY(1,1) NOT NULL,
        channel_id INT NOT NULL,
        band_code NVARCHAR(30) NOT NULL,
        achievement_from DECIMAL(9,4) NOT NULL,
        achievement_to DECIMAL(9,4) NULL,
        sequence_no INT NOT NULL,
        effective_from DATE NOT NULL,
        effective_to DATE NULL,
        is_active BIT NOT NULL CONSTRAINT DF_mst_tt_option1_band_is_active DEFAULT (1),
        created_at DATETIME2(0) NOT NULL CONSTRAINT DF_mst_tt_option1_band_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at DATETIME2(0) NULL,
        CONSTRAINT PK_mst_tt_option1_band PRIMARY KEY CLUSTERED (tt_option1_band_id),
        CONSTRAINT UQ_mst_tt_option1_band UNIQUE (channel_id, band_code, effective_from),
        CONSTRAINT FK_mst_tt_option1_band_channel FOREIGN KEY (channel_id) REFERENCES dbo.mst_channel(channel_id)
    );
END
GO

IF OBJECT_ID('dbo.mst_tt_option1_payout', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.mst_tt_option1_payout (
        tt_option1_payout_id INT IDENTITY(1,1) NOT NULL,
        tt_option1_band_id INT NOT NULL,
        g_group_code NVARCHAR(20) NOT NULL,
        payout_amount DECIMAL(18,2) NOT NULL,
        is_active BIT NOT NULL CONSTRAINT DF_mst_tt_option1_payout_is_active DEFAULT (1),
        created_at DATETIME2(0) NOT NULL CONSTRAINT DF_mst_tt_option1_payout_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at DATETIME2(0) NULL,
        CONSTRAINT PK_mst_tt_option1_payout PRIMARY KEY CLUSTERED (tt_option1_payout_id),
        CONSTRAINT UQ_mst_tt_option1_payout UNIQUE (tt_option1_band_id, g_group_code),
        CONSTRAINT FK_mst_tt_option1_payout_band FOREIGN KEY (tt_option1_band_id) REFERENCES dbo.mst_tt_option1_band(tt_option1_band_id)
    );
END
GO

IF OBJECT_ID('dbo.mst_tt_special_kpi_rule', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.mst_tt_special_kpi_rule (
        tt_special_kpi_rule_id INT IDENTITY(1,1) NOT NULL,
        channel_id INT NOT NULL,
        ws_type NVARCHAR(50) NOT NULL,
        g_group_code NVARCHAR(20) NOT NULL,
        kpi_threshold DECIMAL(9,4) NOT NULL,
        bonus_amount DECIMAL(18,2) NOT NULL,
        effective_from DATE NOT NULL,
        effective_to DATE NULL,
        is_active BIT NOT NULL CONSTRAINT DF_mst_tt_special_kpi_rule_is_active DEFAULT (1),
        created_at DATETIME2(0) NOT NULL CONSTRAINT DF_mst_tt_special_kpi_rule_created_at DEFAULT (SYSUTCDATETIME()),
        updated_at DATETIME2(0) NULL,
        CONSTRAINT PK_mst_tt_special_kpi_rule PRIMARY KEY CLUSTERED (tt_special_kpi_rule_id),
        CONSTRAINT UQ_mst_tt_special_kpi_rule UNIQUE (channel_id, ws_type, g_group_code, effective_from),
        CONSTRAINT FK_mst_tt_special_kpi_rule_channel FOREIGN KEY (channel_id) REFERENCES dbo.mst_channel(channel_id)
    );
END
GO

IF OBJECT_ID('dbo.trn_tt_special_kpi_detail', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.trn_tt_special_kpi_detail (
        tt_special_kpi_detail_id BIGINT IDENTITY(1,1) NOT NULL,
        calc_run_id INT NOT NULL,
        salesman_code NVARCHAR(50) NOT NULL,
        g_group_code NVARCHAR(20) NOT NULL,
        avg_final_achievement DECIMAL(9,4) NOT NULL,
        kpi_threshold DECIMAL(9,4) NOT NULL,
        bonus_amount DECIMAL(18,2) NOT NULL,
        created_at DATETIME2(0) NOT NULL CONSTRAINT DF_trn_tt_special_kpi_detail_created_at DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_trn_tt_special_kpi_detail PRIMARY KEY CLUSTERED (tt_special_kpi_detail_id),
        CONSTRAINT UQ_trn_tt_special_kpi_detail UNIQUE (calc_run_id, salesman_code, g_group_code),
        CONSTRAINT FK_trn_tt_special_kpi_detail_run FOREIGN KEY (calc_run_id) REFERENCES dbo.trn_calc_run(calc_run_id)
    );
END
GO

DECLARE @tt_channel_id INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'TT');
DECLARE @effective_from DATE = '2026-04-01';

IF @tt_channel_id IS NULL
    THROW 53001, 'TT channel not found.', 1;

IF OBJECT_ID('tempdb..#tt_matrix_seed', 'U') IS NOT NULL DROP TABLE #tt_matrix_seed;
CREATE TABLE #tt_matrix_seed (
    ws_type NVARCHAR(50) NOT NULL,
    product_code NVARCHAR(50) NOT NULL,
    g_group_code NVARCHAR(20) NOT NULL,
    product_weight_percent DECIMAL(9,4) NOT NULL,
    incentive_base DECIMAL(18,2) NOT NULL
);

INSERT INTO #tt_matrix_seed (ws_type, product_code, g_group_code, product_weight_percent, incentive_base)
VALUES
-- TOP_WS (base 4,000)
(N'TOP_WS', N'AJ',   N'G1', 0.05, 4000),
(N'TOP_WS', N'RD',   N'G1', 0.10, 4000),
(N'TOP_WS', N'BD',   N'G1', 0.20, 4000),
(N'TOP_WS', N'AJP',  N'G2', 0.05, 4000),
(N'TOP_WS', N'RDC',  N'G2', 0.10, 4000),
(N'TOP_WS', N'RM',   N'G2', 0.05, 4000),
(N'TOP_WS', N'RDNS', N'G2', 0.10, 4000),
(N'TOP_WS', N'YY',   N'G3', 0.15, 4000),
(N'TOP_WS', N'PDC',  N'G3', 0.10, 4000),
(N'TOP_WS', N'TKM',  N'OT', 0.05, 4000),
(N'TOP_WS', N'RKR',  N'OT', 0.05, 4000),

-- WS_SF (base 3,500)
(N'WS_SF', N'AJ',   N'G1', 0.05, 3500),
(N'WS_SF', N'RD',   N'G1', 0.10, 3500),
(N'WS_SF', N'BD',   N'G1', 0.10, 3500),
(N'WS_SF', N'AJP',  N'G2', 0.05, 3500),
(N'WS_SF', N'RDC',  N'G2', 0.10, 3500),
(N'WS_SF', N'RM',   N'G2', 0.10, 3500),
(N'WS_SF', N'RDNS', N'G2', 0.10, 3500),
(N'WS_SF', N'YY',   N'G3', 0.15, 3500),
(N'WS_SF', N'PDC',  N'G3', 0.15, 3500),
(N'WS_SF', N'TKM',  N'OT', 0.05, 3500),
(N'WS_SF', N'RKR',  N'OT', 0.05, 3500),

-- WS_WH (base 3,500)
(N'WS_WH', N'AJ',   N'G1', 0.10, 3500),
(N'WS_WH', N'RD',   N'G1', 0.15, 3500),
(N'WS_WH', N'BD',   N'G1', 0.25, 3500),
(N'WS_WH', N'AJP',  N'G2', 0.05, 3500),
(N'WS_WH', N'RDC',  N'G2', 0.05, 3500),
(N'WS_WH', N'RM',   N'G2', 0.05, 3500),
(N'WS_WH', N'RDNS', N'G2', 0.05, 3500),
(N'WS_WH', N'YY',   N'G3', 0.10, 3500),
(N'WS_WH', N'PDC',  N'G3', 0.10, 3500),
(N'WS_WH', N'TKM',  N'OT', 0.05, 3500),
(N'WS_WH', N'RKR',  N'OT', 0.05, 3500),

-- SF_WH (base 3,500)
(N'SF_WH', N'AJ',   N'G1', 0.08, 3500),
(N'SF_WH', N'RD',   N'G1', 0.13, 3500),
(N'SF_WH', N'BD',   N'G1', 0.18, 3500),
(N'SF_WH', N'AJP',  N'G2', 0.05, 3500),
(N'SF_WH', N'RDC',  N'G2', 0.06, 3500),
(N'SF_WH', N'RM',   N'G2', 0.07, 3500),
(N'SF_WH', N'RDNS', N'G2', 0.07, 3500),
(N'SF_WH', N'YY',   N'G3', 0.13, 3500),
(N'SF_WH', N'PDC',  N'G3', 0.13, 3500),
(N'SF_WH', N'TKM',  N'OT', 0.05, 3500),
(N'SF_WH', N'RKR',  N'OT', 0.05, 3500);

;WITH src AS (
    SELECT
        @tt_channel_id AS channel_id,
        s.ws_type,
        p.product_id,
        s.g_group_code,
        s.product_weight_percent,
        s.incentive_base,
        @effective_from AS effective_from
    FROM #tt_matrix_seed s
    INNER JOIN dbo.mst_product p
        ON p.product_code = s.product_code
)
MERGE dbo.mst_tt_ws_formula_matrix AS tgt
USING src
    ON tgt.channel_id = src.channel_id
   AND tgt.ws_type = src.ws_type
   AND tgt.product_id = src.product_id
   AND tgt.effective_from = src.effective_from
WHEN MATCHED THEN
    UPDATE SET
        tgt.g_group_code = src.g_group_code,
        tgt.product_weight_percent = src.product_weight_percent,
        tgt.incentive_base = src.incentive_base,
        tgt.effective_to = NULL,
        tgt.is_active = 1,
        tgt.updated_at = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (channel_id, ws_type, product_id, g_group_code, product_weight_percent, incentive_base, effective_from, effective_to, is_active)
    VALUES (src.channel_id, src.ws_type, src.product_id, src.g_group_code, src.product_weight_percent, src.incentive_base, src.effective_from, NULL, 1);

IF OBJECT_ID('tempdb..#tt_band_seed', 'U') IS NOT NULL DROP TABLE #tt_band_seed;
CREATE TABLE #tt_band_seed (
    band_code NVARCHAR(30) NOT NULL,
    achievement_from DECIMAL(9,4) NOT NULL,
    achievement_to DECIMAL(9,4) NULL,
    sequence_no INT NOT NULL
);

INSERT INTO #tt_band_seed (band_code, achievement_from, achievement_to, sequence_no)
VALUES
(N'LT80',   0.0000, 0.8000, 1),
(N'80_90',  0.8000, 0.9000, 2),
(N'90_95',  0.9000, 0.9500, 3),
(N'95_100', 0.9500, 1.0000, 4),
(N'AT100',  1.0000, 1.0000, 5),
(N'100_105',1.0000, 1.0500, 6),
(N'105_110',1.0500, 1.1000, 7),
(N'110_115',1.1000, 1.1500, 8),
(N'115_120',1.1500, 1.2000, 9),
(N'120_130',1.2000, 1.3000, 10),
(N'GT130',  1.3000, NULL,   11);

;WITH src AS (
    SELECT
        @tt_channel_id AS channel_id,
        b.band_code,
        b.achievement_from,
        b.achievement_to,
        b.sequence_no,
        @effective_from AS effective_from
    FROM #tt_band_seed b
)
MERGE dbo.mst_tt_option1_band AS tgt
USING src
    ON tgt.channel_id = src.channel_id
   AND tgt.band_code = src.band_code
   AND tgt.effective_from = src.effective_from
WHEN MATCHED THEN
    UPDATE SET
        tgt.achievement_from = src.achievement_from,
        tgt.achievement_to = src.achievement_to,
        tgt.sequence_no = src.sequence_no,
        tgt.effective_to = NULL,
        tgt.is_active = 1,
        tgt.updated_at = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (channel_id, band_code, achievement_from, achievement_to, sequence_no, effective_from, effective_to, is_active)
    VALUES (src.channel_id, src.band_code, src.achievement_from, src.achievement_to, src.sequence_no, src.effective_from, NULL, 1);

IF OBJECT_ID('tempdb..#tt_option_payout_seed', 'U') IS NOT NULL DROP TABLE #tt_option_payout_seed;
CREATE TABLE #tt_option_payout_seed (
    band_code NVARCHAR(30) NOT NULL,
    g_group_code NVARCHAR(20) NOT NULL,
    payout_amount DECIMAL(18,2) NOT NULL
);

INSERT INTO #tt_option_payout_seed (band_code, g_group_code, payout_amount)
VALUES
-- G1
(N'LT80', N'G1', 180),(N'80_90', N'G1', 180),(N'90_95', N'G1', 190),(N'95_100', N'G1', 200),(N'AT100', N'G1', 206),
(N'100_105', N'G1', 216),(N'105_110', N'G1', 220),(N'110_115', N'G1', 230),(N'115_120', N'G1', 240),(N'120_130', N'G1', 260),(N'GT130', N'G1', 260),
-- G2
(N'LT80', N'G2', 180),(N'80_90', N'G2', 180),(N'90_95', N'G2', 190),(N'95_100', N'G2', 200),(N'AT100', N'G2', 206),
(N'100_105', N'G2', 216),(N'105_110', N'G2', 220),(N'110_115', N'G2', 230),(N'115_120', N'G2', 240),(N'120_130', N'G2', 260),(N'GT130', N'G2', 260),
-- G3
(N'LT80', N'G3', 540),(N'80_90', N'G3', 540),(N'90_95', N'G3', 570),(N'95_100', N'G3', 600),(N'AT100', N'G3', 618),
(N'100_105', N'G3', 648),(N'105_110', N'G3', 660),(N'110_115', N'G3', 690),(N'115_120', N'G3', 720),(N'120_130', N'G3', 780),(N'GT130', N'G3', 780),
-- G4/OT
(N'LT80', N'OT', 180),(N'80_90', N'OT', 180),(N'90_95', N'OT', 190),(N'95_100', N'OT', 200),(N'AT100', N'OT', 206),
(N'100_105', N'OT', 216),(N'105_110', N'OT', 220),(N'110_115', N'OT', 230),(N'115_120', N'OT', 240),(N'120_130', N'OT', 260),(N'GT130', N'OT', 260);

;WITH band_ref AS (
    SELECT tt_option1_band_id, band_code
    FROM dbo.mst_tt_option1_band
    WHERE channel_id = @tt_channel_id
      AND effective_from = @effective_from
)
MERGE dbo.mst_tt_option1_payout AS tgt
USING (
    SELECT b.tt_option1_band_id, s.g_group_code, s.payout_amount
    FROM #tt_option_payout_seed s
    INNER JOIN band_ref b
        ON b.band_code = s.band_code
) src
    ON tgt.tt_option1_band_id = src.tt_option1_band_id
   AND tgt.g_group_code = src.g_group_code
WHEN MATCHED THEN
    UPDATE SET
        tgt.payout_amount = src.payout_amount,
        tgt.is_active = 1,
        tgt.updated_at = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (tt_option1_band_id, g_group_code, payout_amount, is_active)
    VALUES (src.tt_option1_band_id, src.g_group_code, src.payout_amount, 1);

;WITH src AS (
    SELECT @tt_channel_id AS channel_id, N'TOP_WS' AS ws_type, N'G1' AS g_group_code, CAST(1.1000 AS DECIMAL(9,4)) AS kpi_threshold, CAST(220 AS DECIMAL(18,2)) AS bonus_amount, @effective_from AS effective_from
    UNION ALL SELECT @tt_channel_id, N'TOP_WS', N'G2', 0.9500, 180, @effective_from
    UNION ALL SELECT @tt_channel_id, N'TOP_WS', N'G3', 1.0300, 618, @effective_from
    UNION ALL SELECT @tt_channel_id, N'TOP_WS', N'OT', 1.0300, 206, @effective_from
)
MERGE dbo.mst_tt_special_kpi_rule AS tgt
USING src
    ON tgt.channel_id = src.channel_id
   AND tgt.ws_type = src.ws_type
   AND tgt.g_group_code = src.g_group_code
   AND tgt.effective_from = src.effective_from
WHEN MATCHED THEN
    UPDATE SET
        tgt.kpi_threshold = src.kpi_threshold,
        tgt.bonus_amount = src.bonus_amount,
        tgt.effective_to = NULL,
        tgt.is_active = 1,
        tgt.updated_at = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (channel_id, ws_type, g_group_code, kpi_threshold, bonus_amount, effective_from, effective_to, is_active)
    VALUES (src.channel_id, src.ws_type, src.g_group_code, src.kpi_threshold, src.bonus_amount, src.effective_from, NULL, 1);

-- Sync legacy tables for ws_type coverage using matrix values (backward compatibility)
MERGE dbo.mst_product_weight AS tgt
USING (
    SELECT channel_id, product_id, ws_type, product_weight_percent AS weight_percent, effective_from
    FROM dbo.mst_tt_ws_formula_matrix
    WHERE channel_id = @tt_channel_id
      AND effective_from = @effective_from
      AND is_active = 1
) src
    ON tgt.channel_id = src.channel_id
   AND tgt.product_id = src.product_id
   AND tgt.ws_type = src.ws_type
   AND tgt.effective_from = src.effective_from
WHEN MATCHED THEN
    UPDATE SET
        tgt.weight_percent = src.weight_percent,
        tgt.effective_to = NULL,
        tgt.is_active = 1,
        tgt.updated_at = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (channel_id, product_id, ws_type, weight_percent, effective_from, effective_to, is_active)
    VALUES (src.channel_id, src.product_id, src.ws_type, src.weight_percent, src.effective_from, NULL, 1);

MERGE dbo.mst_incentive_rate AS tgt
USING (
    SELECT DISTINCT
        @tt_channel_id AS channel_id,
        pl.position_level_id,
        m.ws_type,
        m.incentive_base AS rate_old,
        m.incentive_base AS rate_new,
        @effective_from AS effective_from
    FROM dbo.mst_tt_ws_formula_matrix m
    INNER JOIN dbo.mst_position_level pl
        ON pl.position_code = N'STAFF'
    WHERE m.channel_id = @tt_channel_id
      AND m.effective_from = @effective_from
      AND m.is_active = 1
) src
    ON tgt.channel_id = src.channel_id
   AND tgt.position_level_id = src.position_level_id
   AND tgt.ws_type = src.ws_type
   AND tgt.effective_from = src.effective_from
WHEN MATCHED THEN
    UPDATE SET
        tgt.rate_old = src.rate_old,
        tgt.rate_new = src.rate_new,
        tgt.effective_to = NULL,
        tgt.is_active = 1,
        tgt.updated_at = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (channel_id, position_level_id, ws_type, rate_old, rate_new, effective_from, effective_to, is_active)
    VALUES (src.channel_id, src.position_level_id, src.ws_type, src.rate_old, src.rate_new, src.effective_from, NULL, 1);

DROP TABLE #tt_matrix_seed;
DROP TABLE #tt_band_seed;
DROP TABLE #tt_option_payout_seed;
GO
