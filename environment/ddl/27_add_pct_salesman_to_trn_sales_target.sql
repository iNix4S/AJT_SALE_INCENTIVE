-- =============================================================
-- Script  : 27_add_pct_salesman_to_trn_sales_target.sql
-- Purpose : Add pct_salesman column to dbo.trn_sales_target
--
-- Background
-- ----------
-- The TT incentive sheet (11_3)Target & Cal.values.csv) contains a
-- column called "%Salesman".  For team-level products (R → RD, Y → YY)
-- this value is the pre-computed goal_multiplier from the sheet's own
-- team-achievement formula.  Because the DB team scope (all salesmen in
-- the channel) can differ from the sheet's team scope (section / a
-- subset), storing this value lets the SP use the sheet figure directly
-- and removes the dependency on having identical team data in the DB.
--
-- Semantics
-- ---------
--   NULL  → compute goal_multiplier from DB data (existing behaviour)
--   value → use this decimal directly as goal_multiplier, bypassing the
--            mst_goal_threshold lookup for that row.
--
-- Usage in SP
-- -----------
-- usp_run_tt_incentive_calculation will honour pct_salesman
-- (see 15_create_proc_run_tt_incentive_calculation.sql, updated in
--  the same release).
--
-- Import guidance
-- ---------------
-- When loading target data from the sheet, populate pct_salesman from
-- the "%Salesman" column.  Products that use individual achievement
-- (not team) may be left as NULL; the SP will compute them normally.
-- =============================================================

IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.trn_sales_target')
      AND name = N'pct_salesman'
)
BEGIN
    ALTER TABLE dbo.trn_sales_target
        ADD pct_salesman DECIMAL(9,4) NULL;

    EXEC sys.sp_addextendedproperty
        @name       = N'MS_Description',
        @value      = N'Pre-computed goal_multiplier ("%Salesman") imported from the incentive sheet. NULL = compute from DB data. Non-NULL = use directly, bypassing mst_goal_threshold lookup.',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE',  @level1name = N'trn_sales_target',
        @level2type = N'COLUMN', @level2name = N'pct_salesman';

    PRINT 'Column pct_salesman added to dbo.trn_sales_target.';
END
ELSE
BEGIN
    PRINT 'Column pct_salesman already exists on dbo.trn_sales_target — skipped.';
END
GO
