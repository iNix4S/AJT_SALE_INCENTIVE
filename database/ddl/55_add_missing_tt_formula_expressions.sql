-- ============================================================
-- File    : 55_add_missing_tt_formula_expressions.sql
-- Purpose : เพิ่มสูตรที่ขาดหายไปใน mst_formula_expression สำหรับ TT channel
--
-- Gap ที่พบ (2026-07-06): seed data เดิม (script 42, 2026-06-23) มีแค่
--   - INCENTIVE_PER_PRODUCT: STAFF + ws_type=TOP_WS, WS_SF เท่านั้น
-- แต่ข้อมูลจริงใน mst_org_hierarchy / mst_position_job_function_mapping มี:
--   - ws_type ครบ 3 ค่า: TOP_WS, WS_SF, WS_WH (Warehouse) ← WS_WH ไม่มีสูตร
--   - position=SUPERVISOR ก็มี ws_type TOP_WS/WS_WH ← ไม่เคย seed เลย (เดิม seed แค่ STAFF)
--   - Management cascade (SECT_MGR/DEPT_MGR/DIV_MGR) ← ไม่มีสูตรเลยทั้งกลุ่ม
--     (ต่างจาก MT ที่มี MT_ROLLUP_INCENTIVE)
--
-- หมายเหตุ: การคำนวณจริงใน usp_run_tt_incentive_calculation ทำงานถูกต้องอยู่แล้ว
-- (ไม่กระทบ production) เพราะ TtNCalcEngine.cs มี fallback คำนวณตรงด้วย C#
-- เมื่อไม่พบสูตรใน catalog นี้ — script นี้แค่เติม catalog ให้ครบเพื่อใช้เป็นเอกสาร
-- อ้างอิง/CRUD UI และเปิดทางให้ NCalc engine ใช้สูตรจาก catalog แทน fallback ในอนาคต
--
-- formula_step ใหม่ที่เพิ่ม: 'MANAGER_CASCADE' (เดิมมีแค่ PCT_ACHIEVEMENT,
-- INCENTIVE_PER_PRODUCT, ROLLUP, SPECIAL_KPI) — ใช้ชื่อเดียวกับที่ใช้ในเอกสาร
-- Flow Process ของ SI/LAOS (Step 2: Manager Cascade) เพื่อความสอดคล้อง
--
-- Manager cascade logic (อ้างอิงจาก usp_run_tt_incentive_calculation):
--   1. team_avg_goal_mult = AVG(goal_multiplier) ของพนักงาน STAFF ทุกคนที่ขึ้นตรงกับ
--      manager นั้น (GROUP BY direct_sup_code / dept_mgr_code / div_mgr_code)
--   2. incentive_amount = ROUND(base_rate * team_avg_goal_mult, 0)
--      โดย base_rate ดึงจาก mst_incentive_rate ตาม position_code + ws_type (legacy)
--   ไม่มี weight_pct เพราะเป็นยอดรวมทั้งทีม (product_code = '*') ไม่ใช่ต่อ product
--
-- Created : 2026-07-06
-- ============================================================

-- ── 1. WS_WH (Warehouse) สำหรับ STAFF — รูปแบบเดียวกับ TOP_WS/WS_SF ──────────
IF NOT EXISTS (SELECT 1 FROM dbo.mst_formula_expression WHERE formula_code = N'TT_WSWH_INCENTIVE_PER_PRODUCT')
INSERT INTO dbo.mst_formula_expression
    (formula_code, formula_name, formula_step, channel_id, position_level_id, ws_type,
     formula_expr, variables_json, description, sort_order, effective_from)
VALUES
(N'TT_WSWH_INCENTIVE_PER_PRODUCT', N'TT Warehouse: Incentive ต่อ Product', N'INCENTIVE_PER_PRODUCT',
 (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'TT'),
 (SELECT position_level_id FROM dbo.mst_position_level WHERE position_code = N'STAFF'),
 N'WS_WH',
 N'ROUND([base_rate] * [weight_pct] * [goal_mult], 0)',
 N'{"base_rate":"mst_tt_ws_formula_matrix.incentive_base","weight_pct":"mst_tt_ws_formula_matrix.product_weight_percent","goal_mult":"mst_goal_threshold.multiplier"}',
 N'TT WS_WH (Warehouse) staff incentive ต่อ product (individual achievement)',
 42, '2026-01-01');

-- ── 2. SUPERVISOR position — TOP_WS ──────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM dbo.mst_formula_expression WHERE formula_code = N'TT_SUPERVISOR_TOPWS_INCENTIVE_PER_PRODUCT')
INSERT INTO dbo.mst_formula_expression
    (formula_code, formula_name, formula_step, channel_id, position_level_id, ws_type,
     formula_expr, variables_json, description, sort_order, effective_from)
VALUES
(N'TT_SUPERVISOR_TOPWS_INCENTIVE_PER_PRODUCT', N'TT Supervisor (Top W): Incentive ต่อ Product', N'INCENTIVE_PER_PRODUCT',
 (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'TT'),
 (SELECT position_level_id FROM dbo.mst_position_level WHERE position_code = N'SUPERVISOR'),
 N'TOP_WS',
 N'ROUND([base_rate] * [weight_pct] * [goal_mult], 0)',
 N'{"base_rate":"mst_tt_ws_formula_matrix.incentive_base","weight_pct":"mst_tt_ws_formula_matrix.product_weight_percent","goal_mult":"mst_goal_threshold.multiplier"}',
 N'TT Supervisor TOP_WS incentive ต่อ product (individual achievement)',
 43, '2026-01-01');

-- ── 3. SUPERVISOR position — WS_WH ───────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM dbo.mst_formula_expression WHERE formula_code = N'TT_SUPERVISOR_WSWH_INCENTIVE_PER_PRODUCT')
INSERT INTO dbo.mst_formula_expression
    (formula_code, formula_name, formula_step, channel_id, position_level_id, ws_type,
     formula_expr, variables_json, description, sort_order, effective_from)
VALUES
(N'TT_SUPERVISOR_WSWH_INCENTIVE_PER_PRODUCT', N'TT Supervisor (Warehouse): Incentive ต่อ Product', N'INCENTIVE_PER_PRODUCT',
 (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'TT'),
 (SELECT position_level_id FROM dbo.mst_position_level WHERE position_code = N'SUPERVISOR'),
 N'WS_WH',
 N'ROUND([base_rate] * [weight_pct] * [goal_mult], 0)',
 N'{"base_rate":"mst_tt_ws_formula_matrix.incentive_base","weight_pct":"mst_tt_ws_formula_matrix.product_weight_percent","goal_mult":"mst_goal_threshold.multiplier"}',
 N'TT Supervisor WS_WH (Warehouse) incentive ต่อ product (individual achievement)',
 44, '2026-01-01');

-- ── 4. Management Cascade: SECT_MGR ───────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM dbo.mst_formula_expression WHERE formula_code = N'TT_SECT_MGR_CASCADE')
INSERT INTO dbo.mst_formula_expression
    (formula_code, formula_name, formula_step, channel_id, position_level_id, ws_type,
     formula_expr, variables_json, description, sort_order, effective_from)
VALUES
(N'TT_SECT_MGR_CASCADE', N'TT Section Manager: Team Cascade Incentive', N'MANAGER_CASCADE',
 (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'TT'),
 (SELECT position_level_id FROM dbo.mst_position_level WHERE position_code = N'SECT_MGR'),
 NULL,
 N'ROUND([base_rate] * [team_avg_goal_mult], 0)',
 N'{"base_rate":"mst_incentive_rate.rate_effective (position=SECT_MGR)","team_avg_goal_mult":"AVG(goal_multiplier) ของ STAFF ทุกคนที่ direct_sup_code = รหัส Section Manager นี้"}',
 N'TT Section Manager: ใช้ค่าเฉลี่ย achievement ของทีมลูกน้องตรง (direct_sup_code) คูณ base rate',
 60, '2026-01-01');

-- ── 5. Management Cascade: DEPT_MGR ────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM dbo.mst_formula_expression WHERE formula_code = N'TT_DEPT_MGR_CASCADE')
INSERT INTO dbo.mst_formula_expression
    (formula_code, formula_name, formula_step, channel_id, position_level_id, ws_type,
     formula_expr, variables_json, description, sort_order, effective_from)
VALUES
(N'TT_DEPT_MGR_CASCADE', N'TT Department Manager: Team Cascade Incentive', N'MANAGER_CASCADE',
 (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'TT'),
 (SELECT position_level_id FROM dbo.mst_position_level WHERE position_code = N'DEPT_MGR'),
 NULL,
 N'ROUND([base_rate] * [team_avg_goal_mult], 0)',
 N'{"base_rate":"mst_incentive_rate.rate_effective (position=DEPT_MGR)","team_avg_goal_mult":"AVG(goal_multiplier) ของ STAFF ทุกคนใน dept_mgr_code เดียวกัน"}',
 N'TT Department Manager: ใช้ค่าเฉลี่ย achievement ของ staff ทั้งแผนก คูณ base rate',
 61, '2026-01-01');

-- ── 6. Management Cascade: DIV_MGR ─────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM dbo.mst_formula_expression WHERE formula_code = N'TT_DIV_MGR_CASCADE')
INSERT INTO dbo.mst_formula_expression
    (formula_code, formula_name, formula_step, channel_id, position_level_id, ws_type,
     formula_expr, variables_json, description, sort_order, effective_from)
VALUES
(N'TT_DIV_MGR_CASCADE', N'TT Division Manager: Team Cascade Incentive', N'MANAGER_CASCADE',
 (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'TT'),
 (SELECT position_level_id FROM dbo.mst_position_level WHERE position_code = N'DIV_MGR'),
 NULL,
 N'ROUND([base_rate] * [team_avg_goal_mult], 0)',
 N'{"base_rate":"mst_incentive_rate.rate_effective (position=DIV_MGR)","team_avg_goal_mult":"AVG(goal_multiplier) ของ STAFF ทุกคนใน div_mgr_code เดียวกัน"}',
 N'TT Division Manager: ใช้ค่าเฉลี่ย achievement ของ staff ทั้งดิวิชั่น คูณ base rate',
 62, '2026-01-01');
GO

-- ============================================================
-- VERIFY: ดูสูตร TT ทั้งหมดหลังเพิ่ม (ควรครบทุก ws_type + management cascade)
-- ============================================================
SELECT formula_step, channel_code, position_code, ws_type, job_function_code,
       formula_code, formula_expr
FROM dbo.vw_formula_expression_active
WHERE channel_code IN ('TT', 'SHARED')
ORDER BY formula_step, hierarchy_level, sort_order;
GO
