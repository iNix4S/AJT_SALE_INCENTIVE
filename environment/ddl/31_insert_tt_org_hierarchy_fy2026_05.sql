-- =============================================================
-- Script  : 31_insert_tt_org_hierarchy_fy2026_05.sql
-- Purpose : Insert TT org hierarchy สำหรับ FY2026-05
--           พร้อม ws_type ต่อ salesman จาก Job Function ใน sheet
--
-- ws_type mapping (จาก 15_1) For HR.values.csv คอลัมน์ Job Function):
--   "(Top W)"      → TOP_WS   (TT Cash Van Top WS)
--   "(Shop Front)" → WS_SF    (Shop Front)
--   "(Warehouse)"  → WS_WH    (Warehouse)
--   ไม่ระบุ        → TOP_WS   (default Supervisor/Staff ทั่วไป)
--
-- Hierarchy chain:
--   Staff/Supervisor → direct_sup = Section Manager (salesman_code xxxxxx0)
--   Section Manager  → dept_mgr   = employee 000003 (Dept Mgr)
--   Dept Manager     → div_mgr    = employee 000002 (Div Mgr)
-- =============================================================

DECLARE @ch_tt INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'TT');
DECLARE @month DATE = (SELECT sales_month FROM dbo.mst_period WHERE period_code = N'FY2026-05');

IF @ch_tt IS NULL THROW 59001, 'TT channel not found.', 1;
IF @month IS NULL THROW 59002, 'Period FY2026-05 not found.', 1;
GO

DECLARE @ch_tt INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'TT');
DECLARE @month DATE = (SELECT sales_month FROM dbo.mst_period WHERE period_code = N'FY2026-05');

MERGE dbo.mst_org_hierarchy AS tgt
USING (VALUES
-- ── Bangpoo section (direct_sup = 110000, dept = 000003, div = 000002) ──────
--   salesman_code  direct_sup  dept_mgr   div_mgr   ad      ws_type
    (N'110001',     N'110000',  N'000003', N'000002', NULL,   N'TOP_WS'),  -- Supervisor (Top W)
    (N'110002',     N'110000',  N'000003', N'000002', NULL,   N'WS_SF'),   -- Staff (Shop Front)
    (N'110003',     N'110000',  N'000003', N'000002', NULL,   N'WS_WH'),   -- Staff (Warehouse)
    (N'110000',     NULL,       N'000003', N'000002', NULL,   N'TOP_WS'),  -- Section Manager

-- ── Nonthaburi section (direct_sup = 120000) ─────────────────────────────────
    (N'120001',     N'120000',  N'000003', N'000002', NULL,   N'TOP_WS'),  -- Supervisor
    (N'120002',     N'120000',  N'000003', N'000002', NULL,   N'WS_SF'),   -- Staff
    (N'120000',     NULL,       N'000003', N'000002', NULL,   N'TOP_WS'),  -- Section Manager

-- ── Pathum Thani section (direct_sup = 130000) ───────────────────────────────
    (N'130001',     N'130000',  N'000003', N'000002', NULL,   N'TOP_WS'),  -- Supervisor (Top W)
    (N'130002',     N'130000',  N'000003', N'000002', NULL,   N'WS_SF'),   -- Staff (Shop Front)
    (N'130003',     N'130000',  N'000003', N'000002', NULL,   N'WS_WH'),   -- Staff (Warehouse)
    (N'130000',     NULL,       N'000003', N'000002', NULL,   N'TOP_WS'),  -- Section Manager

-- ── Pattanakan section (direct_sup = 140000) ─────────────────────────────────
    (N'140001',     N'140000',  N'000003', N'000002', NULL,   N'TOP_WS'),  -- Supervisor (Top W)
    (N'140002',     N'140000',  N'000003', N'000002', NULL,   N'WS_SF'),   -- Staff (Shop Front)
    (N'140003',     N'140000',  N'000003', N'000002', NULL,   N'WS_WH'),   -- Supervisor (Warehouse)
    (N'140000',     NULL,       N'000003', N'000002', NULL,   N'TOP_WS'),  -- Section Manager

-- ── Ram Indra section (direct_sup = 150000) ──────────────────────────────────
    (N'150001',     N'150000',  N'000003', N'000002', NULL,   N'TOP_WS'),  -- Supervisor
    (N'150000',     NULL,       N'000003', N'000002', NULL,   N'TOP_WS'),  -- Section Manager

-- ── Thonburi section (direct_sup = 160000) ───────────────────────────────────
    (N'160001',     N'160000',  N'000003', N'000002', NULL,   N'TOP_WS'),  -- Supervisor
    (N'160002',     N'160000',  N'000003', N'000002', NULL,   N'TOP_WS'),  -- Supervisor
    (N'160000',     NULL,       N'000003', N'000002', NULL,   N'TOP_WS'),  -- Section Manager

-- ── Department / Division Managers (no salesman code — use employee code) ────
    (N'000003',     NULL,       NULL,      N'000002', NULL,   N'TOP_WS'),  -- Dept Manager
    (N'000002',     NULL,       NULL,      NULL,      NULL,   N'TOP_WS')   -- Div Manager
) AS src (salesman_code, direct_sup_code, dept_mgr_code, div_mgr_code, ad_code, ws_type)
ON  tgt.channel_id      = @ch_tt
AND tgt.effective_month = @month
AND tgt.salesman_code   = src.salesman_code
WHEN MATCHED THEN
    UPDATE SET
        tgt.direct_sup_code = src.direct_sup_code,
        tgt.dept_mgr_code   = src.dept_mgr_code,
        tgt.div_mgr_code    = src.div_mgr_code,
        tgt.ad_code         = src.ad_code,
        tgt.ws_type         = src.ws_type,
        tgt.is_active       = 1,
        tgt.updated_at      = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (channel_id, effective_month, salesman_code,
            direct_sup_code, dept_mgr_code, div_mgr_code, ad_code,
            ws_type, is_active)
    VALUES (@ch_tt, @month, src.salesman_code,
            src.direct_sup_code, src.dept_mgr_code, src.div_mgr_code, src.ad_code,
            src.ws_type, 1);

PRINT CONCAT('Merged ', @@ROWCOUNT, ' rows into mst_org_hierarchy for TT ', FORMAT(@month,'yyyy-MM'), '.');
GO

-- ── Verify
SELECT h.salesman_code, h.ws_type, h.direct_sup_code, h.dept_mgr_code, h.div_mgr_code
FROM dbo.mst_org_hierarchy h
JOIN dbo.mst_channel c ON c.channel_id=h.channel_id AND c.channel_code='TT'
JOIN dbo.mst_period  p ON p.sales_month=h.effective_month AND p.period_code='FY2026-05'
ORDER BY h.salesman_code;
GO
