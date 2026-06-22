SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*
Purpose:
- Provide topic-based sub views from dbo.vw_mst_org_hierarchy_detail.
- Keep business users focused on only the columns needed per use case.
*/

CREATE OR ALTER VIEW dbo.vw_mst_org_hierarchy_core
AS
SELECT
    hierarchy_id,
    channel_id,
    channel_code,
    channel_name_th,
    channel_name_en,
    calc_type,
    effective_month,
    is_active,
    created_at,
    updated_at
FROM dbo.vw_mst_org_hierarchy_detail;
GO

CREATE OR ALTER VIEW dbo.vw_mst_org_hierarchy_period_context
AS
SELECT
    hierarchy_id,
    channel_code,
    effective_month,
    period_id,
    period_code,
    year_no,
    month_no,
    period_status,
    period_is_closed,
    is_active
FROM dbo.vw_mst_org_hierarchy_detail;
GO

CREATE OR ALTER VIEW dbo.vw_mst_org_hierarchy_salesman
AS
SELECT
    hierarchy_id,
    channel_code,
    effective_month,
    period_code,
    salesman_code,
    salesman_employee_id,
    salesman_name_th,
    salesman_name_en,
    is_active
FROM dbo.vw_mst_org_hierarchy_detail;
GO

CREATE OR ALTER VIEW dbo.vw_mst_org_hierarchy_management_chain
AS
SELECT
    hierarchy_id,
    channel_code,
    effective_month,
    period_code,
    salesman_code,
    salesman_name_th,
    direct_sup_code,
    direct_sup_employee_id,
    direct_sup_name_th,
    dept_mgr_code,
    dept_mgr_employee_id,
    dept_mgr_name_th,
    div_mgr_code,
    div_mgr_employee_id,
    div_mgr_name_th,
    ad_code,
    ad_employee_id,
    ad_name_th,
    is_active
FROM dbo.vw_mst_org_hierarchy_detail;
GO

CREATE OR ALTER VIEW dbo.vw_mst_org_hierarchy_data_quality
AS
SELECT
    hierarchy_id,
    channel_code,
    effective_month,
    period_code,
    salesman_code,
    direct_sup_code,
    dept_mgr_code,
    div_mgr_code,
    ad_code,
    salesman_employee_id,
    direct_sup_employee_id,
    dept_mgr_employee_id,
    div_mgr_employee_id,
    ad_employee_id,
    CASE WHEN salesman_employee_id IS NULL THEN 1 ELSE 0 END AS is_missing_salesman_master,
    CASE WHEN direct_sup_code IS NOT NULL AND direct_sup_employee_id IS NULL THEN 1 ELSE 0 END AS is_missing_direct_sup_master,
    CASE WHEN dept_mgr_code IS NOT NULL AND dept_mgr_employee_id IS NULL THEN 1 ELSE 0 END AS is_missing_dept_mgr_master,
    CASE WHEN div_mgr_code IS NOT NULL AND div_mgr_employee_id IS NULL THEN 1 ELSE 0 END AS is_missing_div_mgr_master,
    CASE WHEN ad_code IS NOT NULL AND ad_employee_id IS NULL THEN 1 ELSE 0 END AS is_missing_ad_master,
    is_active
FROM dbo.vw_mst_org_hierarchy_detail;
GO
