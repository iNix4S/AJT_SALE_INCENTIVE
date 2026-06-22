SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*
Purpose:
- Provide one-stop TT formula definition view for configuration and validation.
- Combine ws_type matrix, position rates, goal threshold, Option1 payout, and Special KPI rule.
- Show example payout values from configured formula components.
*/
CREATE OR ALTER VIEW dbo.vw_tt_incentive_formula_definition
AS
WITH tt_matrix AS (
    SELECT
        m.tt_ws_formula_id,
        m.channel_id,
        c.channel_code,
        c.channel_name_th,
        c.channel_name_en,
        m.ws_type,
        m.product_id,
        p.product_code,
        p.product_name_th,
        p.product_name_en,
        m.g_group_code,
        m.product_weight_percent,
        m.incentive_base,
        m.effective_from,
        m.effective_to,
        m.is_active AS matrix_is_active
    FROM dbo.mst_tt_ws_formula_matrix m
    JOIN dbo.mst_channel c
        ON c.channel_id = m.channel_id
    JOIN dbo.mst_product p
        ON p.product_id = m.product_id
    WHERE c.channel_code = N'TT'
      AND m.is_active = 1
)
SELECT
    tm.tt_ws_formula_id,
    tm.channel_id,
    tm.channel_code,
    tm.channel_name_th,
    tm.channel_name_en,
    tm.ws_type,
    tm.product_id,
    tm.product_code,
    tm.product_name_th,
    tm.product_name_en,
    tm.g_group_code,
    tm.product_weight_percent,
    tm.incentive_base,
    tm.effective_from,
    tm.effective_to,

    gt.goal_threshold_id,
    gt.achievement_from AS goal_achievement_from,
    gt.achievement_to AS goal_achievement_to,
    gt.multiplier AS goal_multiplier,
    gt.sequence_no AS goal_sequence_no,

    staff_rate.rate_old AS staff_rate_old,
    staff_rate.rate_new AS staff_rate_new,
    sect_rate.rate_old AS sect_mgr_rate_old,
    sect_rate.rate_new AS sect_mgr_rate_new,
    dept_rate.rate_old AS dept_mgr_rate_old,
    dept_rate.rate_new AS dept_mgr_rate_new,
    div_rate.rate_old AS div_mgr_rate_old,
    div_rate.rate_new AS div_mgr_rate_new,
    ad_rate.rate_old AS ad_rate_old,
    ad_rate.rate_new AS ad_rate_new,

    band.tt_option1_band_id,
    band.band_code AS option1_band_code,
    band.achievement_from AS option1_achievement_from,
    band.achievement_to AS option1_achievement_to,
    band.sequence_no AS option1_sequence_no,
    payout.payout_amount AS option1_payout_amount,

    kpi.tt_special_kpi_rule_id,
    kpi.kpi_threshold AS special_kpi_threshold,
    kpi.bonus_amount AS special_kpi_bonus_amount,

    CAST(ROUND(tm.incentive_base * gt.multiplier * tm.product_weight_percent, 2) AS DECIMAL(18,2)) AS example_staff_incentive,
    CAST(ROUND(COALESCE(sect_rate.rate_new, sect_rate.rate_old, 0) * gt.multiplier, 2) AS DECIMAL(18,2)) AS example_sect_incentive,
    CAST(ROUND(COALESCE(dept_rate.rate_new, dept_rate.rate_old, 0) * gt.multiplier, 2) AS DECIMAL(18,2)) AS example_dept_incentive,
    CAST(ROUND(COALESCE(div_rate.rate_new, div_rate.rate_old, COALESCE(dept_rate.rate_new, dept_rate.rate_old, 0)) * gt.multiplier, 2) AS DECIMAL(18,2)) AS example_div_incentive,
    CAST(ROUND(COALESCE(ad_rate.rate_new, ad_rate.rate_old, 0) * gt.multiplier, 2) AS DECIMAL(18,2)) AS example_ad_incentive
FROM tt_matrix tm
JOIN dbo.mst_goal_threshold gt
    ON gt.is_active = 1
LEFT JOIN dbo.mst_tt_option1_band band
    ON band.channel_id = tm.channel_id
   AND band.is_active = 1
   AND band.effective_from <= tm.effective_from
   AND (band.effective_to IS NULL OR band.effective_to >= tm.effective_from)
LEFT JOIN dbo.mst_tt_option1_payout payout
    ON payout.tt_option1_band_id = band.tt_option1_band_id
   AND payout.g_group_code = tm.g_group_code
   AND payout.is_active = 1
OUTER APPLY (
    SELECT TOP 1 r.tt_special_kpi_rule_id, r.kpi_threshold, r.bonus_amount
    FROM dbo.mst_tt_special_kpi_rule r
    WHERE r.channel_id = tm.channel_id
      AND r.ws_type = tm.ws_type
      AND r.g_group_code = tm.g_group_code
      AND r.is_active = 1
      AND r.effective_from <= tm.effective_from
      AND (r.effective_to IS NULL OR r.effective_to >= tm.effective_from)
    ORDER BY r.effective_from DESC
) kpi
OUTER APPLY (
    SELECT TOP 1 ir.rate_old, ir.rate_new
    FROM dbo.mst_incentive_rate ir
    JOIN dbo.mst_position_level pl
      ON pl.position_level_id = ir.position_level_id
    WHERE ir.channel_id = tm.channel_id
      AND ir.ws_type = tm.ws_type
      AND pl.position_code = N'STAFF'
      AND ir.is_active = 1
      AND ir.effective_from <= tm.effective_from
      AND (ir.effective_to IS NULL OR ir.effective_to >= tm.effective_from)
    ORDER BY ir.effective_from DESC
) staff_rate
OUTER APPLY (
    SELECT TOP 1 ir.rate_old, ir.rate_new
    FROM dbo.mst_incentive_rate ir
    JOIN dbo.mst_position_level pl
      ON pl.position_level_id = ir.position_level_id
    WHERE ir.channel_id = tm.channel_id
      AND ir.ws_type = tm.ws_type
      AND pl.position_code = N'SECT_MGR'
      AND ir.is_active = 1
      AND ir.effective_from <= tm.effective_from
      AND (ir.effective_to IS NULL OR ir.effective_to >= tm.effective_from)
    ORDER BY ir.effective_from DESC
) sect_rate
OUTER APPLY (
    SELECT TOP 1 ir.rate_old, ir.rate_new
    FROM dbo.mst_incentive_rate ir
    JOIN dbo.mst_position_level pl
      ON pl.position_level_id = ir.position_level_id
    WHERE ir.channel_id = tm.channel_id
      AND ir.ws_type = tm.ws_type
      AND pl.position_code = N'DEPT_MGR'
      AND ir.is_active = 1
      AND ir.effective_from <= tm.effective_from
      AND (ir.effective_to IS NULL OR ir.effective_to >= tm.effective_from)
    ORDER BY ir.effective_from DESC
) dept_rate
OUTER APPLY (
    SELECT TOP 1 ir.rate_old, ir.rate_new
    FROM dbo.mst_incentive_rate ir
    JOIN dbo.mst_position_level pl
      ON pl.position_level_id = ir.position_level_id
    WHERE ir.channel_id = tm.channel_id
      AND ir.ws_type = tm.ws_type
      AND pl.position_code = N'DIV_MGR'
      AND ir.is_active = 1
      AND ir.effective_from <= tm.effective_from
      AND (ir.effective_to IS NULL OR ir.effective_to >= tm.effective_from)
    ORDER BY ir.effective_from DESC
) div_rate
OUTER APPLY (
    SELECT TOP 1 ir.rate_old, ir.rate_new
    FROM dbo.mst_incentive_rate ir
    JOIN dbo.mst_position_level pl
      ON pl.position_level_id = ir.position_level_id
    WHERE ir.channel_id = tm.channel_id
      AND ir.ws_type = tm.ws_type
      AND pl.position_code = N'AD'
      AND ir.is_active = 1
      AND ir.effective_from <= tm.effective_from
      AND (ir.effective_to IS NULL OR ir.effective_to >= tm.effective_from)
    ORDER BY ir.effective_from DESC
) ad_rate;
GO
