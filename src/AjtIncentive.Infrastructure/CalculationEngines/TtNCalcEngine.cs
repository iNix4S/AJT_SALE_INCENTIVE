using Dapper;
using Microsoft.Data.SqlClient;
using NCalc;
using AjtIncentive.Application.Interfaces;

namespace AjtIncentive.Infrastructure.CalculationEngines;

/// <summary>
/// Engine 3: คำนวณ Incentive TT ฝั่ง .NET — ดึง target/actual/master data ผ่าน Dapper
/// แล้ว evaluate สูตร INCENTIVE_PER_PRODUCT ด้วย NCalc (อ่านสูตรจาก mst_formula_expression
/// channel_code='TT'). ws_type ที่ไม่มีสูตรอยู่ใน catalog จะ fallback เป็นการคำนวณตรงด้วย C#
/// (base_rate * weight_pct * goal_mult, สอดคล้องกับ engine อื่น)
///
/// หมายเหตุ: Engine นี้ port logic จาก usp_run_tt_incentive_calculation มาไว้ฝั่ง .NET
/// เป็น best-effort ไม่ได้ผ่านการ auto-compare กับ engine อื่นทีละแถว (ตามที่ผู้ใช้ยืนยัน)
/// </summary>
public sealed class TtNCalcEngine : ITtCalculationEngine
{
    private readonly string _connectionString;

    public TtNCalcEngine(string connectionString)
    {
        _connectionString = connectionString;
    }

    public CalculationEngineType EngineType => CalculationEngineType.NCalc;

    private sealed class TargetRow
    {
        public string SalesmanCode { get; init; } = "";
        public string ProductCode { get; init; } = "";
        public decimal TargetAmount { get; init; }
        public decimal? PctSalesman { get; init; }
    }

    private sealed class HierRow
    {
        public string SalesmanCode { get; init; } = "";
        public string? WsType { get; init; }
        public string? DirectSupCode { get; init; }
        public string? DeptMgrCode { get; init; }
        public string? DivMgrCode { get; init; }
        public string? AdCode { get; init; }
        public DateTime EffectiveMonth { get; init; }
    }

    private sealed class TtProductRow
    {
        public int TtProductId { get; init; }
        public string ProductCode { get; init; } = "";
        public int? MstProductId { get; init; }
    }

    private sealed class MatrixRow
    {
        public int TtProductId { get; init; }
        public string WsType { get; init; } = "";
        public decimal? ProductWeightPercent { get; init; }
        public decimal? IncentiveBase { get; init; }
        public bool UseTeamAchievement { get; init; }
        public DateTime EffectiveFrom { get; init; }
    }

    private sealed class ProductWeightRow
    {
        public int ProductId { get; init; }
        public string WsType { get; init; } = "";
        public decimal WeightPercent { get; init; }
        public DateTime EffectiveFrom { get; init; }
    }

    private sealed class IncentiveRateRow
    {
        public string PositionCode { get; init; } = "";
        public string WsType { get; init; } = "";
        public decimal? RateOld { get; init; }
        public decimal? RateNew { get; init; }
        public DateTime EffectiveFrom { get; init; }
    }

    private sealed class GoalThresholdRow
    {
        public decimal AchievementFrom { get; init; }
        public decimal? AchievementTo { get; init; }
        public decimal Multiplier { get; init; }
        public int SequenceNo { get; init; }
    }

    private sealed class FormulaRow
    {
        public string? WsType { get; init; }
        public string FormulaExpr { get; init; } = "";
    }

    private sealed class DetailRow
    {
        public string EmployeeCode = "";
        public string PositionLevelCode = "";
        public string ProductCode = "";
        public decimal TargetAmount;
        public decimal ActualAmount;
        public decimal Achievement;
        public bool ShortageFlag;
        public decimal FinalAchievement;
        public decimal GoalMultiplier;
        public decimal IncentiveBase;
        public decimal ProductWeight;
        public decimal IncentiveAmount;
    }

    public async Task<int> RunAsync(string periodCode, string wsType, string? approvedBy = null)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();

        var channelId = await conn.ExecuteScalarAsync<int?>(
            "SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'TT'");
        if (channelId is null)
            throw new InvalidOperationException("TT channel not found.");

        var period = await conn.QuerySingleOrDefaultAsync<(int PeriodId, DateTime SalesMonth)?>(
            "SELECT period_id AS PeriodId, sales_month AS SalesMonth FROM dbo.mst_period WHERE period_code = @PeriodCode",
            new { PeriodCode = periodCode });
        if (period is null)
            throw new InvalidOperationException("Period code not found.");

        var periodId = period.Value.PeriodId;
        var salesMonth = period.Value.SalesMonth;

        var legacyWsType = wsType is "TOP_WS" or "WS_SF" or "WS_WH" or "SF_WH" ? wsType
            : wsType == "OLD" ? "TOP_WS" : wsType;

        var hasTargets = await conn.ExecuteScalarAsync<int>(
            "SELECT COUNT(*) FROM dbo.trn_sales_target WHERE period_id=@PeriodId AND channel_id=@ChannelId",
            new { PeriodId = periodId, ChannelId = channelId });
        if (hasTargets == 0)
            throw new InvalidOperationException("No TT target rows for the specified period.");

        await conn.ExecuteAsync(@"
MERGE dbo.trn_calc_run AS tgt
USING (SELECT @PeriodId AS period_id, @ChannelId AS channel_id) AS src
    ON tgt.period_id = src.period_id AND tgt.channel_id = src.channel_id
WHEN MATCHED THEN
    UPDATE SET tgt.run_status = N'CALCULATED', tgt.calculated_at = COALESCE(tgt.calculated_at, SYSUTCDATETIME()),
               tgt.updated_at = SYSUTCDATETIME(), tgt.approved_by = COALESCE(tgt.approved_by, @ApprovedBy)
WHEN NOT MATCHED THEN
    INSERT (period_id, channel_id, run_status, calculated_at, approved_by)
    VALUES (src.period_id, src.channel_id, N'CALCULATED', SYSUTCDATETIME(), @ApprovedBy);",
            new { PeriodId = periodId, ChannelId = channelId, ApprovedBy = approvedBy ?? "system" });

        var runId = await conn.ExecuteScalarAsync<int>(
            "SELECT calc_run_id FROM dbo.trn_calc_run WHERE period_id=@PeriodId AND channel_id=@ChannelId",
            new { PeriodId = periodId, ChannelId = channelId });

        var variablePayMonth = await conn.ExecuteScalarAsync<DateTime?>(
            "SELECT variable_pay_month FROM dbo.mst_payment_cycle WHERE sales_month=@SalesMonth AND is_active=1",
            new { SalesMonth = salesMonth }) ?? salesMonth;

        await conn.ExecuteAsync("DELETE FROM dbo.out_for_hr_variable WHERE calc_run_id=@RunId", new { RunId = runId });
        await conn.ExecuteAsync("DELETE FROM dbo.trn_incentive_detail WHERE calc_run_id=@RunId", new { RunId = runId });

        // ── Load source data ──
        var targets = (await conn.QueryAsync<TargetRow>(@"
SELECT salesman_code AS SalesmanCode, product_code AS ProductCode,
       SUM(target_amount) AS TargetAmount, MAX(pct_salesman) AS PctSalesman
FROM dbo.trn_sales_target WHERE period_id=@PeriodId AND channel_id=@ChannelId
GROUP BY salesman_code, product_code",
            new { PeriodId = periodId, ChannelId = channelId })).ToList();

        var actualLookup = (await conn.QueryAsync<(string SalesmanCode, string ProductCode, decimal ActualAmount)>(@"
SELECT salesman_code AS SalesmanCode, product_code AS ProductCode, SUM(actual_amount) AS ActualAmount
FROM dbo.trn_sales_actual WHERE period_id=@PeriodId AND channel_id=@ChannelId
GROUP BY salesman_code, product_code",
            new { PeriodId = periodId, ChannelId = channelId }))
            .ToDictionary(a => (a.SalesmanCode, a.ProductCode), a => a.ActualAmount);

        var salesmen = targets.Select(t => t.SalesmanCode).Distinct().ToList();
        var hierRows = salesmen.Count == 0
            ? new List<HierRow>()
            : (await conn.QueryAsync<HierRow>(@"
SELECT salesman_code AS SalesmanCode, ws_type AS WsType, direct_sup_code AS DirectSupCode,
       dept_mgr_code AS DeptMgrCode, div_mgr_code AS DivMgrCode, ad_code AS AdCode, effective_month AS EffectiveMonth
FROM dbo.mst_org_hierarchy
WHERE channel_id=@ChannelId AND salesman_code IN @Salesmen",
                new { ChannelId = channelId, Salesmen = salesmen })).ToList();

        HierRow? BestHierRow(string salesmanCode) => hierRows
            .Where(h => h.SalesmanCode == salesmanCode)
            .OrderBy(h => h.EffectiveMonth <= salesMonth ? 0 : 1)
            .ThenBy(h => Math.Abs((h.EffectiveMonth - salesMonth).Days))
            .ThenByDescending(h => h.EffectiveMonth)
            .FirstOrDefault();

        string WsTypeFor(string salesmanCode)
        {
            var row = hierRows
                .Where(h => h.SalesmanCode == salesmanCode && h.WsType != null)
                .OrderBy(h => h.EffectiveMonth <= salesMonth ? 0 : 1)
                .ThenBy(h => Math.Abs((h.EffectiveMonth - salesMonth).Days))
                .ThenByDescending(h => h.EffectiveMonth)
                .FirstOrDefault();
            return row?.WsType ?? legacyWsType;
        }

        var teamAch = targets
            .GroupBy(t => t.ProductCode)
            .ToDictionary(g => g.Key, g =>
            {
                var sumTarget = g.Sum(t => t.TargetAmount);
                var sumActual = g.Sum(t => actualLookup.TryGetValue((t.SalesmanCode, t.ProductCode), out var a) ? a : 0m);
                return sumTarget == 0 ? 0m : Math.Round(sumActual / sumTarget, 4);
            });

        var productMap = (await conn.QueryAsync<TtProductRow>(
            "SELECT tt_product_id AS TtProductId, product_code AS ProductCode, mst_product_id AS MstProductId FROM dbo.mst_tt_product WHERE is_active = 1"))
            .GroupBy(p => p.ProductCode)
            .ToDictionary(g => g.Key, g => g.First());

        var sheetCodeMap = (await conn.QueryAsync<(string ProductCode, string TtSheetCode)>(
            "SELECT product_code AS ProductCode, tt_sheet_code AS TtSheetCode FROM dbo.mst_product WHERE tt_sheet_code IS NOT NULL"))
            .GroupBy(x => x.ProductCode)
            .ToDictionary(g => g.Key, g => g.First().TtSheetCode);

        var matrixRows = (await conn.QueryAsync<MatrixRow>(@"
SELECT tt_product_id AS TtProductId, ws_type AS WsType, product_weight_percent AS ProductWeightPercent,
       incentive_base AS IncentiveBase, use_team_achievement AS UseTeamAchievement, effective_from AS EffectiveFrom
FROM dbo.mst_tt_ws_formula_matrix
WHERE channel_id=@ChannelId AND is_active=1 AND effective_from <= @SalesMonth
  AND (effective_to IS NULL OR effective_to >= @SalesMonth)",
            new { ChannelId = channelId, SalesMonth = salesMonth })).ToList();

        var weightRows = (await conn.QueryAsync<ProductWeightRow>(@"
SELECT product_id AS ProductId, ws_type AS WsType, weight_percent AS WeightPercent, effective_from AS EffectiveFrom
FROM dbo.mst_product_weight
WHERE channel_id=@ChannelId AND is_active=1 AND effective_from <= @SalesMonth
  AND (effective_to IS NULL OR effective_to >= @SalesMonth)",
            new { ChannelId = channelId, SalesMonth = salesMonth })).ToList();

        var shortageRows = (await conn.QueryAsync<(int ProductId, decimal OverrideAchievement)>(
            "SELECT product_id AS ProductId, override_achievement AS OverrideAchievement FROM dbo.mst_shortage_policy WHERE shortage_month=@SalesMonth AND is_active=1",
            new { SalesMonth = salesMonth }))
            .GroupBy(s => s.ProductId)
            .ToDictionary(g => g.Key, g => g.First().OverrideAchievement);

        var rateRows = (await conn.QueryAsync<IncentiveRateRow>(@"
SELECT pl.position_code AS PositionCode, ir.ws_type AS WsType, ir.rate_old AS RateOld, ir.rate_new AS RateNew, ir.effective_from AS EffectiveFrom
FROM dbo.mst_incentive_rate ir
JOIN dbo.mst_position_level pl ON pl.position_level_id = ir.position_level_id
WHERE ir.channel_id=@ChannelId AND ir.is_active=1 AND ir.effective_from <= @SalesMonth
  AND (ir.effective_to IS NULL OR ir.effective_to >= @SalesMonth)",
            new { ChannelId = channelId, SalesMonth = salesMonth })).ToList();

        var goalThresholds = (await conn.QueryAsync<GoalThresholdRow>(
            "SELECT achievement_from AS AchievementFrom, achievement_to AS AchievementTo, multiplier AS Multiplier, sequence_no AS SequenceNo FROM dbo.mst_goal_threshold WHERE is_active = 1"))
            .ToList();

        var formulas = (await conn.QueryAsync<FormulaRow>(@"
SELECT ws_type AS WsType, formula_expr AS FormulaExpr
FROM dbo.mst_formula_expression
WHERE channel_id=@ChannelId AND formula_step='INCENTIVE_PER_PRODUCT' AND is_active=1",
            new { ChannelId = channelId }))
            .Where(f => f.WsType != null)
            .ToDictionary(f => f.WsType!, f => f.FormulaExpr);

        // ── STAFF calculation ──
        var detailRows = new List<DetailRow>();

        foreach (var t in targets)
        {
            if (t.TargetAmount <= 0) continue;

            var actualAmount = actualLookup.TryGetValue((t.SalesmanCode, t.ProductCode), out var a) ? a : 0m;
            var wsTypeForSalesman = WsTypeFor(t.SalesmanCode);

            string baseProductCode;
            if (t.ProductCode.StartsWith("SKU-", StringComparison.OrdinalIgnoreCase))
            {
                var rest = t.ProductCode[4..];
                var dashIdx = rest.IndexOf('-');
                var canonical = dashIdx >= 0 ? rest[..dashIdx] : rest;
                baseProductCode = (sheetCodeMap.TryGetValue(canonical, out var sheetCode) ? sheetCode : canonical)
                    .ToUpperInvariant();
            }
            else
            {
                baseProductCode = t.ProductCode.ToUpperInvariant();
            }

            productMap.TryGetValue(baseProductCode, out var product);
            var ttProductId = product?.TtProductId;
            var mstProductId = product?.MstProductId;

            var matrix = ttProductId is null ? null : matrixRows
                .Where(m => m.TtProductId == ttProductId && m.WsType == wsTypeForSalesman)
                .OrderByDescending(m => m.EffectiveFrom)
                .FirstOrDefault();

            var weight = mstProductId is null ? null : weightRows
                .Where(w => w.ProductId == mstProductId && w.WsType == wsTypeForSalesman)
                .OrderByDescending(w => w.EffectiveFrom)
                .FirstOrDefault();

            decimal overrideAch = 0m;
            var hasShortage = mstProductId is not null && shortageRows.TryGetValue(mstProductId.Value, out overrideAch);

            var rate = rateRows
                .Where(r => r.PositionCode == "STAFF" && r.WsType == wsTypeForSalesman)
                .OrderByDescending(r => r.EffectiveFrom)
                .FirstOrDefault();

            var achievement = t.TargetAmount == 0 ? 0m : Math.Round(actualAmount / t.TargetAmount, 4);

            decimal finalAchievement;
            if (hasShortage)
                finalAchievement = overrideAch;
            else if (matrix?.UseTeamAchievement == true)
                finalAchievement = teamAch.TryGetValue(t.ProductCode, out var ta) ? ta : achievement;
            else
                finalAchievement = achievement;
            finalAchievement = Math.Round(finalAchievement, 4);

            var productWeight = matrix?.ProductWeightPercent ?? weight?.WeightPercent ?? 0m;
            var incentiveBase = matrix?.IncentiveBase ?? rate?.RateNew ?? rate?.RateOld ?? 0m;

            var goalMultiplier = goalThresholds
                .Where(g => finalAchievement >= g.AchievementFrom && (g.AchievementTo is null || finalAchievement <= g.AchievementTo))
                .OrderByDescending(g => g.AchievementFrom).ThenByDescending(g => g.SequenceNo)
                .Select(g => (decimal?)g.Multiplier)
                .FirstOrDefault();

            var effectiveGoalMultiplier = t.PctSalesman ?? goalMultiplier ?? 0m;

            decimal incentiveAmount;
            if (formulas.TryGetValue(wsTypeForSalesman, out var formulaExpr))
            {
                var expr = new Expression(NormalizeForNCalc(formulaExpr));
                expr.Parameters["base_rate"] = (double)incentiveBase;
                expr.Parameters["weight_pct"] = (double)productWeight;
                expr.Parameters["goal_mult"] = (double)effectiveGoalMultiplier;
                incentiveAmount = Convert.ToDecimal(expr.Evaluate());
            }
            else
            {
                // fallback: ไม่มีสูตรใน mst_formula_expression สำหรับ ws_type นี้ — คำนวณตรงเหมือน engine อื่น
                incentiveAmount = Math.Round(incentiveBase * effectiveGoalMultiplier * productWeight, 2);
            }

            detailRows.Add(new DetailRow
            {
                EmployeeCode = t.SalesmanCode,
                PositionLevelCode = "STAFF",
                ProductCode = t.ProductCode,
                TargetAmount = t.TargetAmount,
                ActualAmount = actualAmount,
                Achievement = achievement,
                ShortageFlag = hasShortage,
                FinalAchievement = finalAchievement,
                GoalMultiplier = effectiveGoalMultiplier,
                IncentiveBase = incentiveBase,
                ProductWeight = productWeight,
                IncentiveAmount = incentiveAmount
            });
        }

        // ── Manager cascade ──
        var staffRows = detailRows.Where(d => d.PositionLevelCode == "STAFF").ToList();
        var cascadeLevels = new (string Level, Func<HierRow, string?> PickCode)[]
        {
            ("SECT_MGR", h => h.DirectSupCode),
            ("DEPT_MGR", h => h.DeptMgrCode),
            ("DIV_MGR",  h => h.DivMgrCode),
            ("AD",       h => h.AdCode),
        };

        decimal? RateValue(string positionCode, string wsTypeForRate)
        {
            var r = rateRows.Where(x => x.PositionCode == positionCode && x.WsType == wsTypeForRate)
                .OrderByDescending(x => x.EffectiveFrom).FirstOrDefault();
            return r is null ? null : (r.RateNew ?? r.RateOld);
        }

        foreach (var (level, pickCode) in cascadeLevels)
        {
            var byManager = staffRows
                .Select(s => new { s, ManagerCode = pickCode(BestHierRow(s.EmployeeCode) ?? new HierRow { SalesmanCode = s.EmployeeCode }) })
                .Where(x => !string.IsNullOrEmpty(x.ManagerCode))
                .GroupBy(x => x.ManagerCode!);

            foreach (var grp in byManager)
            {
                var targetSum = grp.Sum(x => x.s.TargetAmount);
                var actualSum = grp.Sum(x => x.s.ActualAmount);
                var avgGoalMultiplier = grp.Average(x => x.s.GoalMultiplier);
                var achievement = Math.Round(avgGoalMultiplier, 4);

                decimal? incentiveBase = level == "DIV_MGR"
                    ? RateValue("DIV_MGR", legacyWsType) ?? RateValue("DEPT_MGR", legacyWsType)
                    : RateValue(level, legacyWsType);

                detailRows.Add(new DetailRow
                {
                    EmployeeCode = grp.Key,
                    PositionLevelCode = level,
                    ProductCode = "*",
                    TargetAmount = Math.Round(targetSum, 2),
                    ActualAmount = Math.Round(actualSum, 2),
                    Achievement = achievement,
                    ShortageFlag = false,
                    FinalAchievement = achievement,
                    GoalMultiplier = achievement,
                    IncentiveBase = incentiveBase ?? 0m,
                    ProductWeight = 1.0000m,
                    IncentiveAmount = Math.Round((incentiveBase ?? 0m) * achievement, 2)
                });
            }
        }

        // ── Persist ──
        foreach (var d in detailRows)
        {
            await conn.ExecuteAsync(@"
INSERT INTO dbo.trn_incentive_detail
    (calc_run_id, salesman_code, position_level_code, product_code, target_amount, actual_amount,
     achievement, shortage_flag, final_achievement, goal_multiplier, incentive_base, product_weight, incentive_amount)
VALUES
    (@RunId, @EmployeeCode, @PositionLevelCode, @ProductCode, @TargetAmount, @ActualAmount,
     @Achievement, @ShortageFlag, @FinalAchievement, @GoalMultiplier, @IncentiveBase, @ProductWeight, @IncentiveAmount)",
                new
                {
                    RunId = runId,
                    d.EmployeeCode,
                    d.PositionLevelCode,
                    d.ProductCode,
                    d.TargetAmount,
                    d.ActualAmount,
                    d.Achievement,
                    d.ShortageFlag,
                    d.FinalAchievement,
                    d.GoalMultiplier,
                    d.IncentiveBase,
                    d.ProductWeight,
                    d.IncentiveAmount
                });
        }

        await conn.ExecuteAsync(@"
;WITH agg AS (
    SELECT
        d.salesman_code AS employee_code,
        SUM(CASE WHEN d.position_level_code = N'STAFF'    THEN d.incentive_amount ELSE 0 END) AS incentive_staff,
        SUM(CASE WHEN d.position_level_code = N'SECT_MGR' THEN d.incentive_amount ELSE 0 END) AS incentive_sect,
        SUM(CASE WHEN d.position_level_code = N'DEPT_MGR' THEN d.incentive_amount ELSE 0 END) AS incentive_dept,
        SUM(CASE WHEN d.position_level_code = N'DIV_MGR'  THEN d.incentive_amount ELSE 0 END) AS incentive_div,
        SUM(CASE WHEN d.position_level_code = N'AD'       THEN d.incentive_amount ELSE 0 END) AS incentive_ad,
        COALESCE((SELECT SUM(k.bonus_amount) FROM dbo.trn_tt_special_kpi_detail k
                  WHERE k.calc_run_id = @RunId AND k.salesman_code = d.salesman_code), 0) AS special_kpi_bonus
    FROM dbo.trn_incentive_detail d
    WHERE d.calc_run_id = @RunId
    GROUP BY d.salesman_code
)
INSERT INTO dbo.out_for_hr_variable
    (calc_run_id, employee_code, employee_name_th, position_level_code, channel_code,
     variable_pay_month, incentive_staff, incentive_sect, incentive_dept, incentive_div, incentive_ad,
     gd_incentive_total, total_variable, payment_method)
SELECT
    @RunId, a.employee_code, COALESCE(e.employee_name_th, a.employee_code), COALESCE(pl.position_code, N'STAFF'), N'TT',
    @VariablePayMonth,
    CAST(ROUND(a.incentive_staff,2) AS DECIMAL(18,2)), CAST(ROUND(a.incentive_sect,2) AS DECIMAL(18,2)),
    CAST(ROUND(a.incentive_dept,2) AS DECIMAL(18,2)), CAST(ROUND(a.incentive_div,2) AS DECIMAL(18,2)),
    CAST(ROUND(a.incentive_ad,2) AS DECIMAL(18,2)), CAST(ROUND(a.special_kpi_bonus,2) AS DECIMAL(18,2)),
    CAST(ROUND(a.incentive_staff+a.incentive_sect+a.incentive_dept+a.incentive_div+a.incentive_ad+a.special_kpi_bonus,2) AS DECIMAL(18,2)),
    N'BANK_TRANSFER'
FROM agg a
LEFT JOIN dbo.mst_employee e ON e.employee_code = a.employee_code AND e.channel_id = @ChannelId
LEFT JOIN dbo.mst_position_level pl ON pl.position_level_id = e.position_level_id;",
            new { RunId = runId, VariablePayMonth = variablePayMonth, ChannelId = channelId });

        await conn.ExecuteAsync(@"
UPDATE dbo.trn_calc_run
SET run_status = N'CALCULATED', calculated_at = COALESCE(calculated_at, SYSUTCDATETIME()),
    updated_at = SYSUTCDATETIME(), approved_by = COALESCE(approved_by, @ApprovedBy)
WHERE calc_run_id = @RunId",
            new { RunId = runId, ApprovedBy = approvedBy ?? "system" });

        return runId;
    }

    private static string NormalizeForNCalc(string formulaExpr) =>
        System.Text.RegularExpressions.Regex.Replace(
            formulaExpr, @"\bROUND\b", "Round", System.Text.RegularExpressions.RegexOptions.IgnoreCase);
}
