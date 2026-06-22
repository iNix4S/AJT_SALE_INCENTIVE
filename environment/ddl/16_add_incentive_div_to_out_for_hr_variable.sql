SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*
16_add_incentive_div_to_out_for_hr_variable.sql
Purpose:
- Add TT-required column incentive_div to out_for_hr_variable.
- Keep backward compatibility by setting default 0.
*/
IF COL_LENGTH('dbo.out_for_hr_variable', 'incentive_div') IS NULL
BEGIN
    ALTER TABLE dbo.out_for_hr_variable
    ADD incentive_div DECIMAL(18,2) NULL;
END
GO

IF COL_LENGTH('dbo.out_for_hr_variable', 'incentive_div') IS NOT NULL
   AND NOT EXISTS (
       SELECT 1
       FROM sys.default_constraints dc
       INNER JOIN sys.columns c
           ON c.object_id = dc.parent_object_id
          AND c.column_id = dc.parent_column_id
       INNER JOIN sys.tables t
           ON t.object_id = c.object_id
       INNER JOIN sys.schemas s
           ON s.schema_id = t.schema_id
       WHERE s.name = 'dbo'
         AND t.name = 'out_for_hr_variable'
         AND c.name = 'incentive_div'
   )
BEGIN
    ALTER TABLE dbo.out_for_hr_variable
    ADD CONSTRAINT DF_out_for_hr_variable_incentive_div DEFAULT (0) FOR incentive_div;
END
GO

IF COL_LENGTH('dbo.out_for_hr_variable', 'incentive_div') IS NOT NULL
BEGIN
    UPDATE dbo.out_for_hr_variable
    SET incentive_div = 0
    WHERE incentive_div IS NULL;
END
GO
