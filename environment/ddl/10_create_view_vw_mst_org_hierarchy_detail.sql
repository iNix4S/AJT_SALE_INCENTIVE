SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*
Purpose:
- Provide a relation-ready detail view for mst_org_hierarchy.
- Join channel, period, and employee master for each hierarchy role code.
*/
CREATE OR ALTER VIEW dbo.vw_mst_org_hierarchy_detail
AS
SELECT
    h.hierarchy_id,
    h.channel_id,
    c.channel_code,
    c.channel_name_th,
    c.channel_name_en,
    c.calc_type,

    h.effective_month,
    p.period_id,
    p.period_code,
    p.year_no,
    p.month_no,
    p.status AS period_status,
    p.is_closed AS period_is_closed,

    h.salesman_code,
    emp_sales.employee_id AS salesman_employee_id,
    emp_sales.employee_name_th AS salesman_name_th,
    emp_sales.employee_name_en AS salesman_name_en,

    h.direct_sup_code,
    emp_direct.employee_id AS direct_sup_employee_id,
    emp_direct.employee_name_th AS direct_sup_name_th,
    emp_direct.employee_name_en AS direct_sup_name_en,

    h.dept_mgr_code,
    emp_dept.employee_id AS dept_mgr_employee_id,
    emp_dept.employee_name_th AS dept_mgr_name_th,
    emp_dept.employee_name_en AS dept_mgr_name_en,

    h.div_mgr_code,
    emp_div.employee_id AS div_mgr_employee_id,
    emp_div.employee_name_th AS div_mgr_name_th,
    emp_div.employee_name_en AS div_mgr_name_en,

    h.ad_code,
    emp_ad.employee_id AS ad_employee_id,
    emp_ad.employee_name_th AS ad_name_th,
    emp_ad.employee_name_en AS ad_name_en,

    h.is_active,
    h.created_at,
    h.updated_at
FROM dbo.mst_org_hierarchy h
JOIN dbo.mst_channel c
    ON c.channel_id = h.channel_id
LEFT JOIN dbo.mst_period p
    ON p.sales_month = h.effective_month
LEFT JOIN dbo.mst_employee emp_sales
    ON emp_sales.employee_code = h.salesman_code
    AND emp_sales.channel_id = h.channel_id
LEFT JOIN dbo.mst_employee emp_direct
    ON emp_direct.employee_code = h.direct_sup_code
    AND emp_direct.channel_id = h.channel_id
LEFT JOIN dbo.mst_employee emp_dept
    ON emp_dept.employee_code = h.dept_mgr_code
    AND emp_dept.channel_id = h.channel_id
LEFT JOIN dbo.mst_employee emp_div
    ON emp_div.employee_code = h.div_mgr_code
    AND emp_div.channel_id = h.channel_id
LEFT JOIN dbo.mst_employee emp_ad
    ON emp_ad.employee_code = h.ad_code
    AND emp_ad.channel_id = h.channel_id;
GO
