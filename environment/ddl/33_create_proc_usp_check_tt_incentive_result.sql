SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*
Purpose:
- เวอร์ชันกระชับของ usp_check_tt_sheet_employee_reference
- ตัด Sheet Reference columns และ Lineage result set ออก
- เหมาะสำหรับใช้ตรวจผลประจำวัน / ad-hoc check โดยไม่ต้องระบุ sheet context

Result sets:
1) Context (period / run / employee count)
2) Coverage per employee (in_target / in_actual / in_hierarchy / in_employee / in_for_hr)
3) For HR values for selected employees
4) Summary (PASS/FAIL)
*/
CREATE OR ALTER PROCEDURE dbo.usp_check_tt_incentive_result
    @PeriodCode      NVARCHAR(20)  = N'FY2026-05',
    @EmployeeListCsv NVARCHAR(MAX),
    @ChannelCode     NVARCHAR(20)  = N'TT'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @channel_id INT = (
        SELECT channel_id FROM dbo.mst_channel WHERE channel_code = @ChannelCode
    );
    DECLARE @period_id INT = (
        SELECT period_id FROM dbo.mst_period WHERE period_code = @PeriodCode
    );
    DECLARE @run_id INT = (
        SELECT TOP 1 calc_run_id
        FROM dbo.trn_calc_run
        WHERE channel_id = @channel_id
          AND period_id  = @period_id
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

    -- Normalize delimiters
    DECLARE @csv NVARCHAR(MAX) = @EmployeeListCsv;
    SET @csv = REPLACE(@csv, CHAR(13), N',');
    SET @csv = REPLACE(@csv, CHAR(10), N',');
    SET @csv = REPLACE(@csv, N';',     N',');
    SET @csv = REPLACE(@csv, N'|',     N',');

    DECLARE @sample TABLE (salesman_code NVARCHAR(50) NOT NULL PRIMARY KEY);
    INSERT INTO @sample (salesman_code)
    SELECT DISTINCT LTRIM(RTRIM(value))
    FROM STRING_SPLIT(@csv, N',')
    WHERE LTRIM(RTRIM(value)) <> N'';

    IF NOT EXISTS (SELECT 1 FROM @sample)
        THROW 58005, 'No valid employee code found after parsing EmployeeListCsv.', 1;

    -- Coverage flags per employee
    DECLARE @checks TABLE (
        salesman_code NVARCHAR(50) NOT NULL PRIMARY KEY,
        in_target    BIT NOT NULL,
        in_actual    BIT NOT NULL,
        in_hierarchy BIT NOT NULL,
        in_employee  BIT NOT NULL,
        in_for_hr    BIT NOT NULL
    );

    INSERT INTO @checks (salesman_code, in_target, in_actual, in_hierarchy, in_employee, in_for_hr)
    SELECT
        s.salesman_code,
        CASE WHEN EXISTS (SELECT 1 FROM dbo.trn_sales_target  t WHERE t.channel_id=@channel_id AND t.period_id=@period_id AND t.salesman_code=s.salesman_code) THEN 1 ELSE 0 END,
        CASE WHEN EXISTS (SELECT 1 FROM dbo.trn_sales_actual  a WHERE a.channel_id=@channel_id AND a.period_id=@period_id AND a.salesman_code=s.salesman_code) THEN 1 ELSE 0 END,
        CASE WHEN EXISTS (SELECT 1 FROM dbo.mst_org_hierarchy h WHERE h.channel_id=@channel_id AND h.salesman_code=s.salesman_code)                           THEN 1 ELSE 0 END,
        CASE WHEN EXISTS (SELECT 1 FROM dbo.mst_employee      e WHERE e.channel_id=@channel_id AND e.employee_code=s.salesman_code)                           THEN 1 ELSE 0 END,
        CASE WHEN EXISTS (SELECT 1 FROM dbo.out_for_hr_variable o WHERE o.calc_run_id=@run_id  AND o.employee_code=s.salesman_code)                           THEN 1 ELSE 0 END
    FROM @sample s;

    -- ── Result Set 1: Context ──────────────────────────────────────────────────
    SELECT
        @PeriodCode                        AS period_code,
        @period_id                         AS period_id,
        @ChannelCode                       AS channel_code,
        @run_id                            AS calc_run_id,
        (SELECT COUNT(*) FROM @sample)     AS input_employee_count;

    -- ── Result Set 2: Coverage per employee ───────────────────────────────────
    SELECT
        c.salesman_code,
        c.in_target,
        c.in_actual,
        c.in_hierarchy,
        c.in_employee,
        c.in_for_hr
    FROM @checks c
    ORDER BY c.salesman_code;

    -- ── Result Set 3: For HR values ───────────────────────────────────────────
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
      AND o.employee_code IN (SELECT salesman_code FROM @sample)
    ORDER BY o.employee_code;

    -- ── Result Set 4: Summary ─────────────────────────────────────────────────
    SELECT
        COUNT(*) AS total_employees,
        SUM(CAST(c.in_target    AS INT)) AS pass_target,
        SUM(CAST(c.in_actual    AS INT)) AS pass_actual,
        SUM(CAST(c.in_hierarchy AS INT)) AS pass_hierarchy,
        SUM(CAST(c.in_employee  AS INT)) AS pass_employee,
        SUM(CAST(c.in_for_hr    AS INT)) AS pass_for_hr,
        CASE
            WHEN SUM(CAST(c.in_target    AS INT)) = COUNT(*)
             AND SUM(CAST(c.in_actual    AS INT)) = COUNT(*)
             AND SUM(CAST(c.in_hierarchy AS INT)) = COUNT(*)
             AND SUM(CAST(c.in_for_hr    AS INT)) = COUNT(*)
            THEN N'PASS' ELSE N'FAIL'
        END AS e2e_status
    FROM @checks c;
END
GO
