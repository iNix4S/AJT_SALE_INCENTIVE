SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*
Purpose:
- TT incentive formula matrix in LONG format (unpivoted).
- CROSS JOIN ws_matrix × goal_threshold: one row per ws_type × product × threshold band.
- Fully dynamic — no hardcoded multiplier values.
- Use for: verifying formula config matches sheet "2) หลักการคำนวน Table",
           tracing which band a given achievement falls into,
           comparing DB values against Excel sheet cell-by-cell.

Source tables:
  mst_tt_ws_formula_matrix  (via vw_tt_formula_ws_matrix)
  mst_goal_threshold        (via vw_tt_formula_goal_threshold)

Key formula:
  incentive_per_product = incentive_base × product_weight_percent × goal_multiplier
  (matches SP: incentive_amount = incentive_base × goal_multiplier × product_weight per row)

Rows: 4 ws_types × ~11 products × 9 bands ≈ 396 rows
*/
CREATE OR ALTER VIEW dbo.vw_tt_formula_incentive_matrix
AS
SELECT
    -- ---- Identity ----
    m.ws_type,
    m.g_group_code,
    m.product_code,
    m.product_name_th,
    CAST(m.product_weight_percent * 100 AS DECIMAL(5,2))           AS weight_pct,
    m.incentive_base,

    -- ---- Threshold band ----
    t.sequence_no                                                    AS band_seq,
    CAST(t.achievement_from * 100 AS DECIMAL(6,2))                  AS ach_from_pct,
    CAST(ISNULL(t.achievement_to, 9.9999) * 100 AS DECIMAL(6,2))   AS ach_to_pct,   -- NULL = no upper cap
    t.achievement_from,
    t.achievement_to,
    CAST(t.multiplier * 100 AS DECIMAL(6,2))                        AS goal_multiplier_pct,
    t.multiplier                                                     AS goal_multiplier,

    -- ---- Computed payout per product per band ----
    CAST(ROUND(m.incentive_base * m.product_weight_percent * t.multiplier, 2)
         AS DECIMAL(9,2))                                           AS incentive_per_product,

    -- ---- Reference ----
    m.effective_from,
    m.effective_to

FROM dbo.vw_tt_formula_ws_matrix    m   -- mst_tt_ws_formula_matrix (is_active=1 already filtered)
CROSS JOIN dbo.vw_tt_formula_goal_threshold t   -- mst_goal_threshold (is_active=1 already filtered)
