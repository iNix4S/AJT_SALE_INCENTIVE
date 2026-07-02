SET NOCOUNT ON;

DECLARE @PeriodId INT = 1;
DECLARE @ChannelId INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'SI');
DECLARE @RunId INT;

IF @ChannelId IS NULL
    THROW 50000, 'SI channel not found', 1;

IF OBJECT_ID('dbo.tmp_si_baseline_detail', 'U') IS NULL OR OBJECT_ID('dbo.tmp_si_baseline_hr', 'U') IS NULL
    THROW 50001, 'SI baseline snapshot tables not found', 1;

SELECT TOP (1) @RunId = calc_run_id
FROM dbo.trn_calc_run
WHERE channel_id = @ChannelId
  AND period_id = @PeriodId
ORDER BY calc_run_id DESC;

SELECT
    @RunId AS current_run_id,
    (SELECT COUNT(*) FROM dbo.trn_incentive_detail WHERE calc_run_id = @RunId) AS current_detail_rows,
    (SELECT COUNT(*) FROM dbo.out_for_hr_variable WHERE calc_run_id = @RunId) AS current_hr_rows;

SELECT COUNT(*) AS base_minus_current_detail
FROM
(
    SELECT salesman_code, position_level_code, product_code, target_amount, actual_amount,
           achievement, shortage_flag, final_achievement, goal_multiplier,
           incentive_base, product_weight, incentive_amount
    FROM dbo.tmp_si_baseline_detail
    EXCEPT
    SELECT salesman_code, position_level_code, product_code, target_amount, actual_amount,
           achievement, shortage_flag, final_achievement, goal_multiplier,
           incentive_base, product_weight, incentive_amount
    FROM dbo.trn_incentive_detail
    WHERE calc_run_id = @RunId
) AS d1;

SELECT COUNT(*) AS current_minus_base_detail
FROM
(
    SELECT salesman_code, position_level_code, product_code, target_amount, actual_amount,
           achievement, shortage_flag, final_achievement, goal_multiplier,
           incentive_base, product_weight, incentive_amount
    FROM dbo.trn_incentive_detail
    WHERE calc_run_id = @RunId
    EXCEPT
    SELECT salesman_code, position_level_code, product_code, target_amount, actual_amount,
           achievement, shortage_flag, final_achievement, goal_multiplier,
           incentive_base, product_weight, incentive_amount
    FROM dbo.tmp_si_baseline_detail
) AS d2;

SELECT COUNT(*) AS base_minus_current_hr
FROM
(
    SELECT employee_code, position_level_code, incentive_staff, incentive_sect,
           incentive_dept, incentive_div, incentive_ad, total_variable
    FROM dbo.tmp_si_baseline_hr
    EXCEPT
    SELECT employee_code, position_level_code, incentive_staff, incentive_sect,
           incentive_dept, incentive_div, incentive_ad, total_variable
    FROM dbo.out_for_hr_variable
    WHERE calc_run_id = @RunId
) AS h1;

SELECT COUNT(*) AS current_minus_base_hr
FROM
(
    SELECT employee_code, position_level_code, incentive_staff, incentive_sect,
           incentive_dept, incentive_div, incentive_ad, total_variable
    FROM dbo.out_for_hr_variable
    WHERE calc_run_id = @RunId
    EXCEPT
    SELECT employee_code, position_level_code, incentive_staff, incentive_sect,
           incentive_dept, incentive_div, incentive_ad, total_variable
    FROM dbo.tmp_si_baseline_hr
) AS h2;
