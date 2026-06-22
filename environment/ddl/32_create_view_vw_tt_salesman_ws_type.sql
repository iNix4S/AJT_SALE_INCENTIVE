-- =============================================================
-- Script  : 32_create_view_vw_tt_salesman_ws_type.sql
-- Purpose : View แสดง ws_type ต่อ salesman + chain ของ hierarchy
--           สำหรับ TT channel ทุก period ที่มีข้อมูลใน mst_org_hierarchy
-- =============================================================

CREATE OR ALTER VIEW dbo.vw_tt_salesman_ws_type AS
SELECT
    p.period_code,
    p.sales_month,
    c.channel_code,
    h.salesman_code,
    h.ws_type,
    h.direct_sup_code,
    h.dept_mgr_code,
    h.div_mgr_code,
    h.ad_code,
    h.is_active
FROM dbo.mst_org_hierarchy h
JOIN dbo.mst_channel c ON c.channel_id = h.channel_id
JOIN dbo.mst_period  p ON p.sales_month = h.effective_month
WHERE c.channel_code = N'TT';
GO

-- ── Verify
SELECT * FROM dbo.vw_tt_salesman_ws_type
WHERE period_code = N'FY2026-05'
ORDER BY ws_type, salesman_code;
GO
