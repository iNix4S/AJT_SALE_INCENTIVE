SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*
Purpose:
- เพิ่ม column use_team_achievement ใน mst_tt_ws_formula_matrix
- เปิด flag สำหรับผลิตภัณฑ์ RD (R) และ YY (Y) ซึ่งชีตคำนวณ achievement ระดับ team ไม่ใช่รายบุคคล
*/

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'dbo'
      AND TABLE_NAME   = 'mst_tt_ws_formula_matrix'
      AND COLUMN_NAME  = 'use_team_achievement'
)
BEGIN
    ALTER TABLE dbo.mst_tt_ws_formula_matrix
    ADD use_team_achievement BIT NOT NULL DEFAULT 0;
END;
GO

UPDATE dbo.mst_tt_ws_formula_matrix
SET use_team_achievement = 1,
    updated_at = SYSUTCDATETIME()
WHERE product_id IN (
    SELECT product_id FROM dbo.mst_product WHERE product_code IN (N'RD', N'YY') AND is_active = 1
);

SELECT
    m.ws_type,
    p.product_code,
    m.g_group_code,
    m.product_weight_percent,
    m.incentive_base,
    m.use_team_achievement
FROM dbo.mst_tt_ws_formula_matrix m
JOIN dbo.mst_product p ON p.product_id = m.product_id
JOIN dbo.mst_channel c ON c.channel_id = m.channel_id
WHERE c.channel_code = N'TT' AND m.is_active = 1
ORDER BY m.ws_type, p.product_code;
GO
