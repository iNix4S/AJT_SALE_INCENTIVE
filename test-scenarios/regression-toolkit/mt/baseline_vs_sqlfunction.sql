SET NOCOUNT ON;

DECLARE @PeriodId INT = 1;
DECLARE @BaseRunId INT;
DECLARE @FnRunId INT;
DECLARE @ChannelId INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'MT');

IF @ChannelId IS NULL
    THROW 50000, 'MT channel not found', 1;

DECLARE @base_detail TABLE
(
    salesman_code NVARCHAR(50),
    position_level_code NVARCHAR(20),
    product_code NVARCHAR(50),
    target_amount DECIMAL(18,2),
    actual_amount DECIMAL(18,2),
    achievement DECIMAL(9,4),
    shortage_flag BIT,
    final_achievement DECIMAL(9,4),
    goal_multiplier DECIMAL(9,4),
    incentive_base DECIMAL(18,4),
    product_weight DECIMAL(18,10),
    incentive_amount DECIMAL(18,4)
);

DECLARE @base_hr TABLE
(
    employee_code NVARCHAR(50),
    position_level_code NVARCHAR(20),
    incentive_staff DECIMAL(18,2),
    incentive_sect DECIMAL(18,2),
    incentive_dept DECIMAL(18,2),
    incentive_div DECIMAL(18,2),
    incentive_ad DECIMAL(18,2),
    total_variable DECIMAL(18,2)
);

EXEC dbo.usp_run_mt_incentive_calculation @PeriodId = @PeriodId, @ApprovedBy = 'baseline';

SELECT TOP (1) @BaseRunId = calc_run_id
FROM dbo.trn_calc_run
WHERE channel_id = @ChannelId
  AND period_id = @PeriodId
ORDER BY calc_run_id DESC;

INSERT INTO @base_detail
SELECT
    salesman_code,
    position_level_code,
    product_code,
    target_amount,
    actual_amount,
    achievement,
    shortage_flag,
    final_achievement,
    goal_multiplier,
    incentive_base,
    product_weight,
    incentive_amount
FROM dbo.trn_incentive_detail
WHERE calc_run_id = @BaseRunId;

INSERT INTO @base_hr
SELECT
    employee_code,
    position_level_code,
    incentive_staff,
    incentive_sect,
    incentive_dept,
    incentive_div,
    incentive_ad,
    total_variable
FROM dbo.out_for_hr_variable
WHERE calc_run_id = @BaseRunId;

EXEC dbo.usp_run_mt_incentive_calculation_via_function @PeriodId = @PeriodId, @ApprovedBy = 'sqlfunction';

SELECT TOP (1) @FnRunId = calc_run_id
FROM dbo.trn_calc_run
WHERE channel_id = @ChannelId
  AND period_id = @PeriodId
ORDER BY calc_run_id DESC;

SELECT
    @BaseRunId AS baseline_run_id,
    @FnRunId AS sqlfunction_run_id,
    (SELECT COUNT(*) FROM dbo.trn_incentive_detail WHERE calc_run_id = @FnRunId) AS detail_rows,
    (SELECT COUNT(*) FROM dbo.out_for_hr_variable WHERE calc_run_id = @FnRunId) AS hr_rows;

SELECT COUNT(*) AS base_minus_fn_detail
FROM
(
    SELECT salesman_code, position_level_code, product_code, target_amount, actual_amount,
           achievement, shortage_flag, final_achievement, goal_multiplier,
           incentive_base, product_weight, incentive_amount
    FROM @base_detail
    EXCEPT
    SELECT salesman_code, position_level_code, product_code, target_amount, actual_amount,
           achievement, shortage_flag, final_achievement, goal_multiplier,
           incentive_base, product_weight, incentive_amount
    FROM dbo.trn_incentive_detail
    WHERE calc_run_id = @FnRunId
) AS d1;

SELECT COUNT(*) AS fn_minus_base_detail
FROM
(
    SELECT salesman_code, position_level_code, product_code, target_amount, actual_amount,
           achievement, shortage_flag, final_achievement, goal_multiplier,
           incentive_base, product_weight, incentive_amount
    FROM dbo.trn_incentive_detail
    WHERE calc_run_id = @FnRunId
    EXCEPT
    SELECT salesman_code, position_level_code, product_code, target_amount, actual_amount,
           achievement, shortage_flag, final_achievement, goal_multiplier,
           incentive_base, product_weight, incentive_amount
    FROM @base_detail
) AS d2;

SELECT COUNT(*) AS base_minus_fn_hr
FROM
(
    SELECT employee_code, position_level_code, incentive_staff, incentive_sect,
           incentive_dept, incentive_div, incentive_ad, total_variable
    FROM @base_hr
    EXCEPT
    SELECT employee_code, position_level_code, incentive_staff, incentive_sect,
           incentive_dept, incentive_div, incentive_ad, total_variable
    FROM dbo.out_for_hr_variable
    WHERE calc_run_id = @FnRunId
) AS h1;

SELECT COUNT(*) AS fn_minus_base_hr
FROM
(
    SELECT employee_code, position_level_code, incentive_staff, incentive_sect,
           incentive_dept, incentive_div, incentive_ad, total_variable
    FROM dbo.out_for_hr_variable
    WHERE calc_run_id = @FnRunId
    EXCEPT
    SELECT employee_code, position_level_code, incentive_staff, incentive_sect,
           incentive_dept, incentive_div, incentive_ad, total_variable
    FROM @base_hr
) AS h2;
