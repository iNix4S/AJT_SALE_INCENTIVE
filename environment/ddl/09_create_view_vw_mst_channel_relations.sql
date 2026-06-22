SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*
Purpose:
- Provide a one-stop relation-ready view for mst_channel.
- Include channel master fields and relation metrics from FK child tables.
*/
CREATE OR ALTER VIEW dbo.vw_mst_channel_relations
AS
SELECT
    c.channel_id,
    c.channel_code,
    c.channel_name_th,
    c.channel_name_en,
    c.calc_type,
    c.is_active,
    c.created_at,
    c.updated_at,

    ISNULL(e.employee_count, 0) AS employee_count,
    ISNULL(jf.job_function_count, 0) AS job_function_count,
    ISNULL(gp.gd_product_count, 0) AS gd_product_count,
    ISNULL(ir.incentive_rate_count, 0) AS incentive_rate_count,
    ISNULL(fr.fix_rate_count, 0) AS fix_rate_count,
    ISNULL(pw.product_weight_count, 0) AS product_weight_count,
    ISNULL(oh.org_hierarchy_count, 0) AS org_hierarchy_count,
    oh.org_hierarchy_latest_effective_month,
    ISNULL(sm.salesman_mapping_count, 0) AS salesman_mapping_count,
    sm.salesman_mapping_latest_effective_month,
    ISNULL(tsa.trn_sales_actual_count, 0) AS trn_sales_actual_count,
    tsa.trn_sales_actual_latest_period_id,
    ISNULL(tst.trn_sales_target_count, 0) AS trn_sales_target_count,
    tst.trn_sales_target_latest_period_id,
    ISNULL(tcr.calc_run_count, 0) AS calc_run_count,
    tcr.calc_run_latest_period_id
FROM dbo.mst_channel c
LEFT JOIN (
    SELECT channel_id, COUNT(1) AS employee_count
    FROM dbo.mst_employee
    GROUP BY channel_id
) e ON e.channel_id = c.channel_id
LEFT JOIN (
    SELECT channel_id, COUNT(1) AS job_function_count
    FROM dbo.mst_job_function
    GROUP BY channel_id
) jf ON jf.channel_id = c.channel_id
LEFT JOIN (
    SELECT channel_id, COUNT(1) AS gd_product_count
    FROM dbo.mst_gd_product
    GROUP BY channel_id
) gp ON gp.channel_id = c.channel_id
LEFT JOIN (
    SELECT channel_id, COUNT(1) AS incentive_rate_count
    FROM dbo.mst_incentive_rate
    GROUP BY channel_id
) ir ON ir.channel_id = c.channel_id
LEFT JOIN (
    SELECT channel_id, COUNT(1) AS fix_rate_count
    FROM dbo.mst_fix_rate
    GROUP BY channel_id
) fr ON fr.channel_id = c.channel_id
LEFT JOIN (
    SELECT channel_id, COUNT(1) AS product_weight_count
    FROM dbo.mst_product_weight
    GROUP BY channel_id
) pw ON pw.channel_id = c.channel_id
LEFT JOIN (
    SELECT
        channel_id,
        COUNT(1) AS org_hierarchy_count,
        MAX(effective_month) AS org_hierarchy_latest_effective_month
    FROM dbo.mst_org_hierarchy
    GROUP BY channel_id
) oh ON oh.channel_id = c.channel_id
LEFT JOIN (
    SELECT
        channel_id,
        COUNT(1) AS salesman_mapping_count,
        MAX(effective_month) AS salesman_mapping_latest_effective_month
    FROM dbo.mst_salesman_mapping
    GROUP BY channel_id
) sm ON sm.channel_id = c.channel_id
LEFT JOIN (
    SELECT
        channel_id,
        COUNT(1) AS trn_sales_actual_count,
        MAX(period_id) AS trn_sales_actual_latest_period_id
    FROM dbo.trn_sales_actual
    GROUP BY channel_id
) tsa ON tsa.channel_id = c.channel_id
LEFT JOIN (
    SELECT
        channel_id,
        COUNT(1) AS trn_sales_target_count,
        MAX(period_id) AS trn_sales_target_latest_period_id
    FROM dbo.trn_sales_target
    GROUP BY channel_id
) tst ON tst.channel_id = c.channel_id
LEFT JOIN (
    SELECT
        channel_id,
        COUNT(1) AS calc_run_count,
        MAX(period_id) AS calc_run_latest_period_id
    FROM dbo.trn_calc_run
    GROUP BY channel_id
) tcr ON tcr.channel_id = c.channel_id;
GO
