/*
AJT TT - Reusable Employee Reference Check from Sheet
Purpose:
- ตรวจพนักงานจาก sheet TT ว่าอ้างอิงได้ครบใน Target/Actual/Hierarchy/Employee/For HR
- ใช้ซ้ำได้โดยเปลี่ยน @PeriodCode และ @EmployeeListCsv

How to use:
1) ใส่ @PeriodCode
2) ใส่ @EmployeeListCsv เป็น SalesmanCode คั่นด้วย comma
3) รัน script
*/

DECLARE @PeriodCode NVARCHAR(20) = N'FY2026-05';
DECLARE @EmployeeListCsv NVARCHAR(MAX) = N'110001,110002,120001,160001';

DECLARE @tt INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'TT');
DECLARE @period_id INT = (SELECT period_id FROM dbo.mst_period WHERE period_code = @PeriodCode);
DECLARE @run_id INT = (
    SELECT TOP 1 calc_run_id
    FROM dbo.trn_calc_run
    WHERE channel_id = @tt
      AND period_id = @period_id
    ORDER BY calc_run_id DESC
);

IF @tt IS NULL
    THROW 57001, 'TT channel not found.', 1;

IF @period_id IS NULL
    THROW 57002, 'Period code not found.', 1;

IF @run_id IS NULL
    THROW 57003, 'No calc_run found for this period/channel. Please run TT calculation first.', 1;

DECLARE @sample TABLE (sheet_salesman_code NVARCHAR(50) PRIMARY KEY);

INSERT INTO @sample(sheet_salesman_code)
SELECT DISTINCT LTRIM(RTRIM(value))
FROM STRING_SPLIT(@EmployeeListCsv, ',')
WHERE LTRIM(RTRIM(value)) <> N'';

/* Result set 1: Context */
SELECT
    @PeriodCode AS period_code,
    @period_id AS period_id,
    @run_id AS calc_run_id,
    (SELECT COUNT(*) FROM @sample) AS input_employee_count;

/* Result set 2: Reference coverage by employee */
SELECT
    @run_id AS calc_run_id,
    s.sheet_salesman_code,
    CASE WHEN EXISTS (
        SELECT 1
        FROM dbo.trn_sales_target t
        WHERE t.channel_id = @tt
          AND t.period_id = @period_id
          AND t.salesman_code = s.sheet_salesman_code
    ) THEN 1 ELSE 0 END AS in_target,
    CASE WHEN EXISTS (
        SELECT 1
        FROM dbo.trn_sales_actual a
        WHERE a.channel_id = @tt
          AND a.period_id = @period_id
          AND a.salesman_code = s.sheet_salesman_code
    ) THEN 1 ELSE 0 END AS in_actual,
    CASE WHEN EXISTS (
        SELECT 1
        FROM dbo.mst_org_hierarchy h
        WHERE h.channel_id = @tt
          AND h.salesman_code = s.sheet_salesman_code
    ) THEN 1 ELSE 0 END AS in_hierarchy,
    CASE WHEN EXISTS (
        SELECT 1
        FROM dbo.mst_employee e
        WHERE e.channel_id = @tt
          AND e.employee_code = s.sheet_salesman_code
    ) THEN 1 ELSE 0 END AS in_employee,
    CASE WHEN EXISTS (
        SELECT 1
        FROM dbo.out_for_hr_variable o
        WHERE o.calc_run_id = @run_id
          AND o.employee_code = s.sheet_salesman_code
    ) THEN 1 ELSE 0 END AS in_for_hr
FROM @sample s
ORDER BY s.sheet_salesman_code;

/* Result set 3: For HR values for selected employees */
SELECT
    o.employee_code,
    o.incentive_staff,
    o.incentive_sect,
    o.incentive_dept,
    o.incentive_div,
    o.incentive_ad,
    o.gd_incentive_total,
    o.total_variable
FROM dbo.out_for_hr_variable o
WHERE o.calc_run_id = @run_id
  AND o.employee_code IN (SELECT sheet_salesman_code FROM @sample)
ORDER BY o.employee_code;

/* Result set 4: Summary */
;WITH checks AS (
    SELECT
        s.sheet_salesman_code,
        CASE WHEN EXISTS (
            SELECT 1 FROM dbo.trn_sales_target t
            WHERE t.channel_id = @tt AND t.period_id = @period_id AND t.salesman_code = s.sheet_salesman_code
        ) THEN 1 ELSE 0 END AS in_target,
        CASE WHEN EXISTS (
            SELECT 1 FROM dbo.trn_sales_actual a
            WHERE a.channel_id = @tt AND a.period_id = @period_id AND a.salesman_code = s.sheet_salesman_code
        ) THEN 1 ELSE 0 END AS in_actual,
        CASE WHEN EXISTS (
            SELECT 1 FROM dbo.mst_org_hierarchy h
            WHERE h.channel_id = @tt AND h.salesman_code = s.sheet_salesman_code
        ) THEN 1 ELSE 0 END AS in_hierarchy,
        CASE WHEN EXISTS (
            SELECT 1 FROM dbo.mst_employee e
            WHERE e.channel_id = @tt AND e.employee_code = s.sheet_salesman_code
        ) THEN 1 ELSE 0 END AS in_employee,
        CASE WHEN EXISTS (
            SELECT 1 FROM dbo.out_for_hr_variable o
            WHERE o.calc_run_id = @run_id AND o.employee_code = s.sheet_salesman_code
        ) THEN 1 ELSE 0 END AS in_for_hr
    FROM @sample s
)
SELECT
    COUNT(*) AS total_employees,
    SUM(in_target) AS pass_target,
    SUM(in_actual) AS pass_actual,
    SUM(in_hierarchy) AS pass_hierarchy,
    SUM(in_employee) AS pass_employee,
    SUM(in_for_hr) AS pass_for_hr,
    CASE WHEN SUM(in_target)=COUNT(*) AND SUM(in_actual)=COUNT(*) AND SUM(in_hierarchy)=COUNT(*) AND SUM(in_for_hr)=COUNT(*)
         THEN N'PASS'
         ELSE N'FAIL'
    END AS e2e_status_without_employee_master,
    CASE WHEN SUM(in_target)=COUNT(*) AND SUM(in_actual)=COUNT(*) AND SUM(in_hierarchy)=COUNT(*) AND SUM(in_employee)=COUNT(*) AND SUM(in_for_hr)=COUNT(*)
         THEN N'PASS'
         ELSE N'FAIL'
    END AS e2e_status_with_employee_master
FROM checks;
