SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*
22_upsert_tt_ws_type_completeness.sql
Purpose:
- Ensure TT formula data is complete for ws_type: TOP_WS, WS_SF, WS_WH, SF_WH.
- Fill missing rows in mst_tt_special_kpi_rule and mst_incentive_rate.
- Keep backward-compatible behavior by cloning from existing TOP_WS/OLD setup.
*/

DECLARE @tt_channel_id INT = (
    SELECT channel_id
    FROM dbo.mst_channel
    WHERE channel_code = N'TT'
);

IF @tt_channel_id IS NULL
    THROW 54001, 'TT channel not found.', 1;

/* ------------------------------------------------------------
1) Ensure Special KPI rules exist for all ws_type (G1,G2,G3,OT)
   Source of truth: latest active TOP_WS rule per g_group
------------------------------------------------------------ */
;WITH ws_list AS (
    SELECT N'TOP_WS' AS ws_type
    UNION ALL SELECT N'WS_SF'
    UNION ALL SELECT N'WS_WH'
    UNION ALL SELECT N'SF_WH'
),
top_ws_latest AS (
    SELECT
        r.g_group_code,
        r.kpi_threshold,
        r.bonus_amount,
        r.effective_from,
        ROW_NUMBER() OVER (
            PARTITION BY r.g_group_code
            ORDER BY r.effective_from DESC
        ) AS rn
    FROM dbo.mst_tt_special_kpi_rule r
    WHERE r.channel_id = @tt_channel_id
      AND r.ws_type = N'TOP_WS'
      AND r.is_active = 1
),
src AS (
    SELECT
        @tt_channel_id AS channel_id,
        w.ws_type,
        t.g_group_code,
        t.kpi_threshold,
        t.bonus_amount,
        t.effective_from
    FROM ws_list w
    JOIN top_ws_latest t
      ON t.rn = 1
)
MERGE dbo.mst_tt_special_kpi_rule AS tgt
USING src
   ON tgt.channel_id = src.channel_id
  AND tgt.ws_type = src.ws_type
  AND tgt.g_group_code = src.g_group_code
  AND tgt.effective_from = src.effective_from
WHEN MATCHED THEN
    UPDATE SET
        tgt.kpi_threshold = src.kpi_threshold,
        tgt.bonus_amount = src.bonus_amount,
        tgt.effective_to = NULL,
        tgt.is_active = 1,
        tgt.updated_at = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (channel_id, ws_type, g_group_code, kpi_threshold, bonus_amount, effective_from, effective_to, is_active)
    VALUES (src.channel_id, src.ws_type, src.g_group_code, src.kpi_threshold, src.bonus_amount, src.effective_from, NULL, 1);

/* ------------------------------------------------------------
2) Ensure position rates exist for all ws_type
    - STAFF: source from TT matrix base by ws_type (TOP_WS/WS_SF/WS_WH/SF_WH)
   - SECT_MGR/DEPT_MGR/AD: clone from OLD to ws_type
   - DIV_MGR: if OLD missing, derive from DEPT_MGR OLD, then clone to ws_type
------------------------------------------------------------ */

DECLARE @pl_staff INT = (SELECT position_level_id FROM dbo.mst_position_level WHERE position_code = N'STAFF');
DECLARE @pl_sect  INT = (SELECT position_level_id FROM dbo.mst_position_level WHERE position_code = N'SECT_MGR');
DECLARE @pl_dept  INT = (SELECT position_level_id FROM dbo.mst_position_level WHERE position_code = N'DEPT_MGR');
DECLARE @pl_div   INT = (SELECT position_level_id FROM dbo.mst_position_level WHERE position_code = N'DIV_MGR');
DECLARE @pl_ad    INT = (SELECT position_level_id FROM dbo.mst_position_level WHERE position_code = N'AD');

IF @pl_staff IS NULL OR @pl_sect IS NULL OR @pl_dept IS NULL OR @pl_div IS NULL OR @pl_ad IS NULL
    THROW 54002, 'Required position levels not found.', 1;

;WITH old_dept AS (
    SELECT TOP 1 ir.rate_old, ir.rate_new, ir.effective_from
    FROM dbo.mst_incentive_rate ir
    WHERE ir.channel_id = @tt_channel_id
      AND ir.position_level_id = @pl_dept
      AND ir.ws_type = N'OLD'
      AND ir.is_active = 1
    ORDER BY ir.effective_from DESC
)
MERGE dbo.mst_incentive_rate AS tgt
USING (
    SELECT @tt_channel_id AS channel_id, @pl_div AS position_level_id, N'OLD' AS ws_type,
           d.rate_old, d.rate_new, d.effective_from
    FROM old_dept d
) src
   ON tgt.channel_id = src.channel_id
  AND tgt.position_level_id = src.position_level_id
  AND tgt.ws_type = src.ws_type
  AND tgt.effective_from = src.effective_from
WHEN MATCHED THEN
    UPDATE SET
        tgt.rate_old = src.rate_old,
        tgt.rate_new = src.rate_new,
        tgt.effective_to = NULL,
        tgt.is_active = 1,
        tgt.updated_at = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (channel_id, position_level_id, ws_type, rate_old, rate_new, effective_from, effective_to, is_active)
    VALUES (src.channel_id, src.position_level_id, src.ws_type, src.rate_old, src.rate_new, src.effective_from, NULL, 1);

;WITH ws_list AS (
    SELECT N'TOP_WS' AS ws_type
    UNION ALL SELECT N'WS_SF'
    UNION ALL SELECT N'WS_WH'
    UNION ALL SELECT N'SF_WH'
),
base_old AS (
    SELECT
        ir.position_level_id,
        ir.rate_old,
        ir.rate_new,
        ir.effective_from,
        ROW_NUMBER() OVER (
            PARTITION BY ir.position_level_id
            ORDER BY ir.effective_from DESC
        ) AS rn
    FROM dbo.mst_incentive_rate ir
    WHERE ir.channel_id = @tt_channel_id
      AND ir.ws_type = N'OLD'
      AND ir.position_level_id IN (@pl_sect, @pl_dept, @pl_div, @pl_ad)
      AND ir.is_active = 1
),
src AS (
    SELECT
        @tt_channel_id AS channel_id,
        b.position_level_id,
        w.ws_type,
        b.rate_old,
        b.rate_new,
        b.effective_from
    FROM base_old b
    JOIN ws_list w
      ON b.rn = 1
)
MERGE dbo.mst_incentive_rate AS tgt
USING src
   ON tgt.channel_id = src.channel_id
  AND tgt.position_level_id = src.position_level_id
  AND tgt.ws_type = src.ws_type
  AND tgt.effective_from = src.effective_from
WHEN MATCHED THEN
    UPDATE SET
        tgt.rate_old = src.rate_old,
        tgt.rate_new = src.rate_new,
        tgt.effective_to = NULL,
        tgt.is_active = 1,
        tgt.updated_at = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (channel_id, position_level_id, ws_type, rate_old, rate_new, effective_from, effective_to, is_active)
    VALUES (src.channel_id, src.position_level_id, src.ws_type, src.rate_old, src.rate_new, src.effective_from, NULL, 1);

/* Ensure STAFF ws_type rates align with TT matrix base values */
;WITH staff_src AS (
    SELECT
        @tt_channel_id AS channel_id,
        @pl_staff AS position_level_id,
        m.ws_type,
        CAST(MAX(m.incentive_base) AS DECIMAL(18,2)) AS rate_old,
        CAST(MAX(m.incentive_base) AS DECIMAL(18,2)) AS rate_new,
        MIN(m.effective_from) AS effective_from
    FROM dbo.mst_tt_ws_formula_matrix m
    WHERE m.channel_id = @tt_channel_id
      AND m.is_active = 1
      AND m.ws_type IN (N'TOP_WS', N'WS_SF', N'WS_WH', N'SF_WH')
    GROUP BY m.ws_type
)
MERGE dbo.mst_incentive_rate AS tgt
USING staff_src src
   ON tgt.channel_id = src.channel_id
  AND tgt.position_level_id = src.position_level_id
  AND tgt.ws_type = src.ws_type
  AND tgt.effective_from = src.effective_from
WHEN MATCHED THEN
    UPDATE SET
        tgt.rate_old = src.rate_old,
        tgt.rate_new = src.rate_new,
        tgt.effective_to = NULL,
        tgt.is_active = 1,
        tgt.updated_at = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (channel_id, position_level_id, ws_type, rate_old, rate_new, effective_from, effective_to, is_active)
    VALUES (src.channel_id, src.position_level_id, src.ws_type, src.rate_old, src.rate_new, src.effective_from, NULL, 1);
GO
