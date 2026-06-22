SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*
Purpose:
- Provide a relation-ready view for mst_employee.
- Join channel, job function, and position level in one place.
*/
CREATE OR ALTER VIEW dbo.vw_mst_employee_detail
AS
SELECT
    e.employee_id,
    e.employee_code,
    e.employee_name_th,
    e.employee_name_en,

    e.channel_id,
    c.channel_code,
    c.channel_name_th,
    c.channel_name_en,
    c.calc_type,

    e.job_function_id,
    jf.job_function_code,
    jf.job_function_name_th,
    jf.job_function_name_en,
    jf.is_fixed_rate_eligible,
    jf.channel_id AS job_function_channel_id,

    e.position_level_id,
    pl.position_code,
    pl.position_name_th,
    pl.position_name_en,
    pl.hierarchy_level,

    e.cost_center,
    e.company_code,
    e.effective_from,
    e.effective_to,
    e.is_active,

    CASE
        WHEN e.effective_from IS NULL THEN CAST(0 AS bit)
        WHEN e.effective_from <= CAST(GETDATE() AS date)
         AND (e.effective_to IS NULL OR e.effective_to >= CAST(GETDATE() AS date))
        THEN CAST(1 AS bit)
        ELSE CAST(0 AS bit)
    END AS is_currently_effective,

    CASE
        WHEN jf.channel_id IS NOT NULL AND jf.channel_id <> e.channel_id THEN CAST(1 AS bit)
        ELSE CAST(0 AS bit)
    END AS is_job_function_channel_mismatch,

    e.created_at,
    e.updated_at
FROM dbo.mst_employee e
LEFT JOIN dbo.mst_channel c
    ON c.channel_id = e.channel_id
LEFT JOIN dbo.mst_job_function jf
    ON jf.job_function_id = e.job_function_id
LEFT JOIN dbo.mst_position_level pl
    ON pl.position_level_id = e.position_level_id;
GO
