-- =============================================================
-- Script  : 28_update_pct_salesman_fy2026_05_tt.sql
-- Purpose : Populate pct_salesman in dbo.trn_sales_target
--           for channel TT, period FY2026-05, from the sheet
--           column "%Salesman"  (11_3)Target & Cal.values.csv).
--
-- Background
-- ----------
-- Products R (→ RD) and Y (→ YY) use TEAM-level achievement.
-- The sheet records the pre-computed goal_multiplier for each
-- salesman row in the "%Salesman" column.
-- For FY2026-05 TT, both R and Y have %Salesman = 1.00 for all
-- salesmen, meaning the team achievement fell in the band
-- [0.9501, 1.0001) → goal_multiplier = 1.00.
--
-- All other products (A, AP, B, M, NS, P, Q, RK, T) already
-- produce the correct goal_multiplier from DB data, so they
-- are left as NULL (no override needed).
--
-- How to maintain this for future periods
-- -----------------------------------------
-- Re-run a version of this script with the correct %Salesman
-- values extracted from the new sheet.  Only R and Y (or any
-- other product whose sheet team-scope differs from DB) need
-- to be set; individual products can remain NULL.
--
-- Prerequisite: 27_add_pct_salesman_to_trn_sales_target.sql
-- =============================================================

DECLARE @PeriodCode  NVARCHAR(20) = N'FY2026-05';
DECLARE @ChannelCode NVARCHAR(20) = N'TT';

DECLARE @period_id INT  = (SELECT period_id  FROM dbo.mst_period  WHERE period_code  = @PeriodCode);
DECLARE @channel_id INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = @ChannelCode);

IF @period_id IS NULL  RAISERROR('Period code %s not found.', 16, 1, @PeriodCode);
IF @channel_id IS NULL RAISERROR('Channel code %s not found.', 16, 1, @ChannelCode);
GO

-- ── Sheet values: product_code → pct_salesman (goal_multiplier)
-- Source : 11_3)Target & Cal.values.csv, column "%Salesman"
-- Only R and Y are overridden; all others remain NULL.
DECLARE @PeriodCode  NVARCHAR(20) = N'FY2026-05';
DECLARE @ChannelCode NVARCHAR(20) = N'TT';

DECLARE @period_id  INT = (SELECT period_id  FROM dbo.mst_period  WHERE period_code  = @PeriodCode);
DECLARE @channel_id INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = @ChannelCode);

UPDATE t
SET    t.pct_salesman = v.pct_salesman,
       t.updated_at   = SYSUTCDATETIME()
FROM   dbo.trn_sales_target t
JOIN  (VALUES
    (N'R', CAST(1.0000 AS DECIMAL(9,4))),   -- team achievement band [0.9501,1.0001) → mult=1.00
    (N'Y', CAST(1.0000 AS DECIMAL(9,4)))    -- team achievement band [0.9501,1.0001) → mult=1.00
) AS v (product_code, pct_salesman)
    ON t.product_code = v.product_code
WHERE  t.period_id  = @period_id
  AND  t.channel_id = @channel_id;

PRINT CONCAT('Updated ', @@ROWCOUNT, ' rows — pct_salesman set for R and Y in ', @ChannelCode, ' ', @PeriodCode, '.');
GO

-- ── Verify: show updated rows
DECLARE @PeriodCode  NVARCHAR(20) = N'FY2026-05';
DECLARE @ChannelCode NVARCHAR(20) = N'TT';

SELECT t.salesman_code, t.product_code, t.target_amount, t.pct_salesman
FROM   dbo.trn_sales_target t
JOIN   dbo.mst_period  p ON p.period_id  = t.period_id  AND p.period_code  = @PeriodCode
JOIN   dbo.mst_channel c ON c.channel_id = t.channel_id AND c.channel_code = @ChannelCode
WHERE  t.product_code IN (N'R', N'Y')
ORDER  BY t.salesman_code, t.product_code;
GO
