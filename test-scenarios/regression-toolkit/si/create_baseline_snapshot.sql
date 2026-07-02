SET NOCOUNT ON;

DECLARE @PeriodId INT = 1;
DECLARE @ChannelId INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'SI');
DECLARE @BaseRunId INT;

IF @ChannelId IS NULL
    THROW 50000, 'SI channel not found', 1;

EXEC dbo.usp_run_si_incentive_calculation @PeriodId = @PeriodId, @ApprovedBy = 'baseline_snapshot';

SELECT TOP (1) @BaseRunId = calc_run_id
FROM dbo.trn_calc_run
WHERE channel_id = @ChannelId
  AND period_id = @PeriodId
ORDER BY calc_run_id DESC;

IF OBJECT_ID('dbo.tmp_si_baseline_detail', 'U') IS NOT NULL DROP TABLE dbo.tmp_si_baseline_detail;
IF OBJECT_ID('dbo.tmp_si_baseline_hr', 'U') IS NOT NULL DROP TABLE dbo.tmp_si_baseline_hr;

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
INTO dbo.tmp_si_baseline_detail
FROM dbo.trn_incentive_detail
WHERE calc_run_id = @BaseRunId;

SELECT
    employee_code,
    position_level_code,
    incentive_staff,
    incentive_sect,
    incentive_dept,
    incentive_div,
    incentive_ad,
    total_variable
INTO dbo.tmp_si_baseline_hr
FROM dbo.out_for_hr_variable
WHERE calc_run_id = @BaseRunId;

SELECT
    @BaseRunId AS baseline_run_id,
    (SELECT COUNT(*) FROM dbo.tmp_si_baseline_detail) AS baseline_detail_rows,
    (SELECT COUNT(*) FROM dbo.tmp_si_baseline_hr) AS baseline_hr_rows;
