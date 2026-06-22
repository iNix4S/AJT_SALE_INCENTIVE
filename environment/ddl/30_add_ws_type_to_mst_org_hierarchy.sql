-- =============================================================
-- Script  : 30_add_ws_type_to_mst_org_hierarchy.sql
-- Purpose : เพิ่มคอลัมน์ ws_type ใน mst_org_hierarchy
--           เพื่อให้ SP lookup ws_type รายคนแทนการรับ parameter
--           เดียวสำหรับทุกคน
--
-- ws_type values (ตรงกับ mst_tt_ws_formula_matrix):
--   TOP_WS  = TT Cash Van / Top WS (Top Wholesale)
--   WS_SF   = Shop Front
--   WS_WH   = Warehouse
--   SF_WH   = Shop Front + Warehouse
--   NULL    = ใช้ @WsType parameter เป็น fallback
-- =============================================================

IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.mst_org_hierarchy')
      AND name = N'ws_type'
)
BEGIN
    ALTER TABLE dbo.mst_org_hierarchy
        ADD ws_type NVARCHAR(50) NULL;

    EXEC sys.sp_addextendedproperty
        @name       = N'MS_Description',
        @value      = N'Formula ws_type สำหรับ salesman คนนี้ (TOP_WS / WS_SF / WS_WH / SF_WH). NULL = ใช้ @WsType parameter fallback ใน SP.',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE',  @level1name = N'mst_org_hierarchy',
        @level2type = N'COLUMN', @level2name = N'ws_type';

    PRINT 'Column ws_type added to dbo.mst_org_hierarchy.';
END
ELSE
    PRINT 'Column ws_type already exists — skipped.';
GO
