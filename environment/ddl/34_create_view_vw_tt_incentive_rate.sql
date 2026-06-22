SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*
Purpose:
- TT-specific view for mst_incentive_rate joined with position level.
- Filters channel_code = 'TT' only.
- Shows both rate_old and rate_new side-by-side per position × ws_type.
- Includes human-readable position name and effective date range.
- Use for quick verification that rates match the T_SectAbove sheet.

Rate mapping (T_SectAbove reference):
  STAFF     / TOP_WS     = 4,000   (Salesman incentive_base)
  STAFF     / WS_SF|WS_WH = 3,500
  SECT_MGR                = 4,000   (Section Manager)
  DEPT_MGR                = 5,000   (Department Manager)
  DIV_MGR                 = 5,000   (Division Manager)
  AD                      = 6,000   (Associate Director)
*/
CREATE OR ALTER VIEW dbo.vw_tt_incentive_rate
AS
SELECT
    pl.position_code,
    pl.position_name_th,
    pl.position_name_en,
    pl.hierarchy_level,
    ir.ws_type,
    ir.rate_old,
    ir.rate_new,
    COALESCE(ir.rate_new, ir.rate_old) AS rate_effective,   -- rate ที่ใช้จริง (rate_new priority)
    ir.effective_from,
    ir.effective_to,
    ir.is_active,
    ir.incentive_rate_id,
    ir.channel_id
FROM dbo.mst_incentive_rate ir
JOIN dbo.mst_position_level pl
    ON pl.position_level_id = ir.position_level_id
JOIN dbo.mst_channel c
    ON c.channel_id = ir.channel_id
WHERE c.channel_code = N'TT';
GO
