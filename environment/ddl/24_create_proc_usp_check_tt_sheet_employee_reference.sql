SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*
Purpose:
- Reusable procedure สำหรับตรวจพนักงานจาก sheet TT ด้วย parameter
- ลดการแก้ไฟล์ SQL template ทุกครั้ง
- เพิ่มผลลัพธ์ lineage เพื่อ trace กลับไปยังชื่อ sheet/ไฟล์/คอลัมน์

Result sets:
1) Context (period/run/input count)
2) Coverage per employee (target/actual/hierarchy/employee/for_hr)
3) For HR values for selected employees
4) Summary (PASS/FAIL)
5) Lineage map (check -> sheet/file/key column -> db target)
*/
CREATE OR ALTER PROCEDURE dbo.usp_check_tt_sheet_employee_reference
    @PeriodCode NVARCHAR(20) = N'FY2026-05',
    @EmployeeListCsv NVARCHAR(MAX),
    @ChannelCode NVARCHAR(20) = N'TT',
    @InputSheetName NVARCHAR(200) = N'1) For HR',
    @InputSheetFile NVARCHAR(260) = N'15_1) For HR.values.csv'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @channel_id INT = (
        SELECT channel_id
        FROM dbo.mst_channel
        WHERE channel_code = @ChannelCode
    );

    DECLARE @period_id INT = (
        SELECT period_id
        FROM dbo.mst_period
        WHERE period_code = @PeriodCode
    );

    DECLARE @run_id INT = (
        SELECT TOP 1 calc_run_id
        FROM dbo.trn_calc_run
        WHERE channel_id = @channel_id
          AND period_id = @period_id
        ORDER BY calc_run_id DESC
    );

    IF @channel_id IS NULL
        THROW 58001, 'Channel code not found.', 1;

    IF @period_id IS NULL
        THROW 58002, 'Period code not found.', 1;

    IF @EmployeeListCsv IS NULL OR LTRIM(RTRIM(@EmployeeListCsv)) = N''
        THROW 58003, 'Employee list is empty. Please pass comma-separated employee codes.', 1;

    IF @run_id IS NULL
        THROW 58004, 'No calc_run found for this period/channel. Please run calculation first.', 1;

    DECLARE @normalized_csv NVARCHAR(MAX) = @EmployeeListCsv;
    SET @normalized_csv = REPLACE(@normalized_csv, CHAR(13), N',');
    SET @normalized_csv = REPLACE(@normalized_csv, CHAR(10), N',');
    SET @normalized_csv = REPLACE(@normalized_csv, N';', N',');
    SET @normalized_csv = REPLACE(@normalized_csv, N'|', N',');

    DECLARE @sample TABLE (
        sheet_salesman_code NVARCHAR(50) NOT NULL PRIMARY KEY
    );

    INSERT INTO @sample(sheet_salesman_code)
    SELECT DISTINCT LTRIM(RTRIM(value))
    FROM STRING_SPLIT(@normalized_csv, N',')
    WHERE LTRIM(RTRIM(value)) <> N'';

    IF NOT EXISTS (SELECT 1 FROM @sample)
        THROW 58005, 'No valid employee code found after parsing EmployeeListCsv.', 1;

    DECLARE @checks TABLE (
        sheet_salesman_code NVARCHAR(50) NOT NULL PRIMARY KEY,
        in_target BIT NOT NULL,
        in_actual BIT NOT NULL,
        in_hierarchy BIT NOT NULL,
        in_employee BIT NOT NULL,
        in_for_hr BIT NOT NULL
    );

    INSERT INTO @checks (
        sheet_salesman_code,
        in_target,
        in_actual,
        in_hierarchy,
        in_employee,
        in_for_hr
    )
    SELECT
        s.sheet_salesman_code,
        CASE WHEN EXISTS (
            SELECT 1
            FROM dbo.trn_sales_target t
            WHERE t.channel_id = @channel_id
              AND t.period_id = @period_id
              AND t.salesman_code = s.sheet_salesman_code
        ) THEN 1 ELSE 0 END AS in_target,
        CASE WHEN EXISTS (
            SELECT 1
            FROM dbo.trn_sales_actual a
            WHERE a.channel_id = @channel_id
              AND a.period_id = @period_id
              AND a.salesman_code = s.sheet_salesman_code
        ) THEN 1 ELSE 0 END AS in_actual,
        CASE WHEN EXISTS (
            SELECT 1
            FROM dbo.mst_org_hierarchy h
            WHERE h.channel_id = @channel_id
              AND h.salesman_code = s.sheet_salesman_code
        ) THEN 1 ELSE 0 END AS in_hierarchy,
        CASE WHEN EXISTS (
            SELECT 1
            FROM dbo.mst_employee e
            WHERE e.channel_id = @channel_id
              AND e.employee_code = s.sheet_salesman_code
        ) THEN 1 ELSE 0 END AS in_employee,
        CASE WHEN EXISTS (
            SELECT 1
            FROM dbo.out_for_hr_variable o
            WHERE o.calc_run_id = @run_id
              AND o.employee_code = s.sheet_salesman_code
        ) THEN 1 ELSE 0 END AS in_for_hr
    FROM @sample s;
    SELECT
        @PeriodCode AS period_code,
        @period_id AS period_id,
        @channel_id AS channel_id,
        @ChannelCode AS channel_code,
        @run_id AS calc_run_id,
        (SELECT COUNT(*) FROM @sample) AS input_employee_count,
        @InputSheetName AS input_sheet_name,
        @InputSheetFile AS input_sheet_file,
        N'employee_code/salesman_code' AS input_sheet_key_column;

    SELECT
        @run_id AS calc_run_id,
        c.sheet_salesman_code,
        c.in_target,
        N'3)Target & Cal' AS target_sheet_name,
        N'11_3)Target & Cal.values.csv' AS target_sheet_file,
        N'salesman_code' AS target_sheet_key_column,
        c.in_actual,
        N'Actual' AS actual_sheet_name,
        N'12_Actual.values.csv' AS actual_sheet_file,
        N'salesman_code' AS actual_sheet_key_column,
        c.in_hierarchy,
        N'T_SectAbove' AS hierarchy_sheet_name,
        N'08_T_SectAbove.values.csv' AS hierarchy_sheet_file,
        N'salesman_code' AS hierarchy_sheet_key_column,
        c.in_employee,
        N'HR Rep (master source)' AS employee_sheet_name,
        N'14_HR Rep.values.csv' AS employee_sheet_file,
        N'employee_code' AS employee_sheet_key_column,
        c.in_for_hr
        ,@InputSheetName AS for_hr_sheet_name
        ,@InputSheetFile AS for_hr_sheet_file
        ,N'employee_code' AS for_hr_sheet_key_column
    FROM @checks c
    ORDER BY c.sheet_salesman_code;

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

    SELECT
        COUNT(*) AS total_employees,
         SUM(CAST(c.in_target AS INT)) AS pass_target,
         SUM(CAST(c.in_actual AS INT)) AS pass_actual,
         SUM(CAST(c.in_hierarchy AS INT)) AS pass_hierarchy,
         SUM(CAST(c.in_employee AS INT)) AS pass_employee,
         SUM(CAST(c.in_for_hr AS INT)) AS pass_for_hr,
         CASE WHEN SUM(CAST(c.in_target AS INT)) = COUNT(*)
             AND SUM(CAST(c.in_actual AS INT)) = COUNT(*)
             AND SUM(CAST(c.in_hierarchy AS INT)) = COUNT(*)
             AND SUM(CAST(c.in_for_hr AS INT)) = COUNT(*)
             THEN N'PASS'
             ELSE N'FAIL'
        END AS e2e_status_without_employee_master,
         CASE WHEN SUM(CAST(c.in_target AS INT)) = COUNT(*)
             AND SUM(CAST(c.in_actual AS INT)) = COUNT(*)
             AND SUM(CAST(c.in_hierarchy AS INT)) = COUNT(*)
             AND SUM(CAST(c.in_employee AS INT)) = COUNT(*)
             AND SUM(CAST(c.in_for_hr AS INT)) = COUNT(*)
             THEN N'PASS'
             ELSE N'FAIL'
        END AS e2e_status_with_employee_master
    FROM @checks c;

    SELECT
        N'input_employee_list' AS check_name,
        @InputSheetName AS sheet_name,
        @InputSheetFile AS sheet_file,
        N'employee_code/salesman_code' AS sheet_key_column,
        N'@sample.sheet_salesman_code' AS internal_target,
        N'list from @EmployeeListCsv' AS note
    UNION ALL
    SELECT
        N'in_target',
        N'3)Target & Cal',
        N'11_3)Target & Cal.values.csv',
        N'salesman_code',
        N'dbo.trn_sales_target.salesman_code',
        N'filtered by channel_id + period_id'
    UNION ALL
    SELECT
        N'in_actual',
        N'Actual',
        N'12_Actual.values.csv',
        N'salesman_code',
        N'dbo.trn_sales_actual.salesman_code',
        N'filtered by channel_id + period_id'
    UNION ALL
    SELECT
        N'in_hierarchy',
        N'T_SectAbove',
        N'08_T_SectAbove.values.csv',
        N'salesman_code',
        N'dbo.mst_org_hierarchy.salesman_code',
        N'channel scope only'
    UNION ALL
    SELECT
        N'in_employee',
        N'HR Rep (master source)',
        N'14_HR Rep.values.csv',
        N'employee_code',
        N'dbo.mst_employee.employee_code',
        N'if missing then in_employee = 0'
    UNION ALL
    SELECT
        N'in_for_hr',
        @InputSheetName,
        @InputSheetFile,
        N'employee_code',
        N'dbo.out_for_hr_variable.employee_code',
        N'filtered by latest calc_run_id of selected period/channel';
END
GO
