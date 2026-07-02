using Dapper;
using Microsoft.Data.SqlClient;
using NCalc;
using AjtIncentive.Application.Interfaces;

namespace AjtIncentive.Infrastructure.CalculationEngines;

/// <summary>
/// Engine 3: คำนวณ Incentive LAOS ฝั่ง .NET ด้วย Dapper + NCalc
/// โดย mirror logic จาก usp_run_laos_incentive_calculation
/// </summary>
public sealed class LaosNCalcEngine : ILaosCalculationEngine
{
    private readonly string _connectionString;

    public LaosNCalcEngine(string connectionString)
    {
        _connectionString = connectionString;
    }

    public CalculationEngineType EngineType => CalculationEngineType.NCalc;

    private sealed class TargetRow
    {
        public string SalesmanCode { get; init; } = "";
        public string ProductCode { get; init; } = "";
        public decimal TargetAmount { get; init; }
    }

    private sealed class HierRow
    {
        public string SalesmanCode { get; init; } = "";
        public string? WsType { get; init; }
        public string? DirectSupCode { get; init; }
        public string? DeptMgrCode { get; init; }
        public DateTime EffectiveMonth { get; init; }
    }

    private sealed class ProductRow
    {
        public int ProductId { get; init; }
        public string ProductCode { get; init; } = "";
    }

    private sealed class WeightRow
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

    private sealed class SpecialAdjustmentRow
    {
        public long AdjustmentId { get; init; }
        public string EmployeeCode { get; init; } = "";
        public string? ProductCode { get; init; }
        public decimal? OverrideAchievement { get; init; }
        public decimal? AdjustedWeightPercent { get; init; }
        public decimal? AdjustedTargetAmount { get; init; }
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

    public async Task<int> RunAsync(string periodCode, string? approvedBy = null)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();

        var channelId = await conn.ExecuteScalarAsync<int?>(
            "SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'LAOS'");
        if (channelId is null)
            throw new InvalidOperationException("LAOS channel not found.");

        var period = await conn.QuerySingleOrDefaultAsync<(int PeriodId, DateTime SalesMonth)?>(
            "SELECT period_id AS PeriodId, sales_month AS SalesMonth FROM dbo.mst_period WHERE period_code = @PeriodCode",
            new { PeriodCode = periodCode });
        if (period is null)
            throw new InvalidOperationException("Period code not found.");

        var periodId = period.Value.PeriodId;
        var salesMonth = period.Value.SalesMonth;
        var legacyWsType = "TOP_WS";

        var hasTargets = await conn.ExecuteScalarAsync<int>(
            "SELECT COUNT(*) FROM dbo.trn_sales_target WHERE period_id=@PeriodId AND channel_id=@ChannelId",
            new { PeriodId = periodId, ChannelId = channelId });
        if (hasTargets == 0)
            throw new InvalidOperationException("No Laos target rows for the specified period.");

        await conn.ExecuteAsync(@"
MERGE dbo.trn_calc_run AS tgt
USING (SELECT @PeriodId AS period_id, @ChannelId AS channel_id) AS src
    ON tgt.period_id = src.period_id AND tgt.channel_id = src.channel_id
WHEN MATCHED THEN
    UPDATE SET tgt.run_status = N'RUNNING', tgt.updated_at = GETDATE(),
               tgt.approved_by = COALESCE(tgt.approved_by, @ApprovedBy)
WHEN NOT MATCHED THEN
    INSERT (period_id, channel_id, run_status, approved_by, created_at)
    VALUES (src.period_id, src.channel_id, N'RUNNING', @ApprovedBy, GETDATE());",
            new { PeriodId = periodId, ChannelId = channelId, ApprovedBy = approvedBy ?? "system" });

        var runId = await conn.ExecuteScalarAsync<int>(
            "SELECT calc_run_id FROM dbo.trn_calc_run WHERE period_id=@PeriodId AND channel_id=@ChannelId",
            new { PeriodId = periodId, ChannelId = channelId });

        await conn.ExecuteAsync("DELETE FROM dbo.out_for_hr_variable WHERE calc_run_id=@RunId", new { RunId = runId });
        await conn.ExecuteAsync("DELETE FROM dbo.trn_incentive_detail WHERE calc_run_id=@RunId", new { RunId = runId });

        var targets = (await conn.QueryAsync<TargetRow>(@"
SELECT salesman_code AS SalesmanCode, product_code AS ProductCode,
       SUM(target_amount) AS TargetAmount
FROM dbo.trn_sales_target
WHERE period_id=@PeriodId AND channel_id=@ChannelId
GROUP BY salesman_code, product_code",
            new { PeriodId = periodId, ChannelId = channelId })).ToList();

        var actualLookup = (await conn.QueryAsync<(string SalesmanCode, string ProductCode, decimal ActualAmount)>(@"
SELECT salesman_code AS SalesmanCode, product_code AS ProductCode, SUM(actual_amount) AS ActualAmount
FROM dbo.trn_sales_actual
WHERE period_id=@PeriodId AND channel_id=@ChannelId
GROUP BY salesman_code, product_code",
            new { PeriodId = periodId, ChannelId = channelId }))
            .ToDictionary(a => (a.SalesmanCode, a.ProductCode), a => a.ActualAmount);

        var salesmen = targets.Select(t => t.SalesmanCode).Distinct().ToList();
        var hierRows = salesmen.Count == 0
            ? new List<HierRow>()
            : (await conn.QueryAsync<HierRow>(@"
SELECT salesman_code AS SalesmanCode,
       ws_type AS WsType,
       direct_sup_code AS DirectSupCode,
       dept_mgr_code AS DeptMgrCode,
       effective_month AS EffectiveMonth
FROM dbo.mst_org_hierarchy
WHERE channel_id=@ChannelId AND salesman_code IN @Salesmen",
                new { ChannelId = channelId, Salesmen = salesmen })).ToList();

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

        HierRow? BestHierRow(string salesmanCode) => hierRows
            .Where(h => h.SalesmanCode == salesmanCode)
            .OrderBy(h => h.EffectiveMonth <= salesMonth ? 0 : 1)
            .ThenBy(h => Math.Abs((h.EffectiveMonth - salesMonth).Days))
            .ThenByDescending(h => h.EffectiveMonth)
            .FirstOrDefault();

        var productRows = (await conn.QueryAsync<ProductRow>(
            "SELECT product_id AS ProductId, product_code AS ProductCode FROM dbo.mst_product WHERE is_active = 1"))
            .GroupBy(p => p.ProductCode)
            .ToDictionary(g => g.Key.ToUpperInvariant(), g => g.First());

        var weightRows = (await conn.QueryAsync<WeightRow>(@"
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

        var specialAdjustmentRows = (await conn.QueryAsync<SpecialAdjustmentRow>(@"
SELECT adjustment_id AS AdjustmentId, employee_code AS EmployeeCode, product_code AS ProductCode,
       override_achievement AS OverrideAchievement, adjusted_weight_percent AS AdjustedWeightPercent,
       adjusted_target_amount AS AdjustedTargetAmount
FROM dbo.trn_special_adjustment
WHERE period_id=@PeriodId AND channel_id=@ChannelId AND is_active=1",
            new { PeriodId = periodId, ChannelId = channelId })).ToList();

        var rateRows = (await conn.QueryAsync<IncentiveRateRow>(@"
SELECT pl.position_code AS PositionCode, ir.ws_type AS WsType,
       ir.rate_old AS RateOld, ir.rate_new AS RateNew, ir.effective_from AS EffectiveFrom
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
            .Where(f => !string.IsNullOrWhiteSpace(f.WsType))
            .ToDictionary(f => f.WsType!, f => f.FormulaExpr, StringComparer.OrdinalIgnoreCase);

        static string MapLaosProductCode(string raw)
        {
            var upper = raw.ToUpperInvariant();
            return upper switch
            {
                "A" => "AJ",
                "AP" => "AJP",
                "R" => "RD",
                "B" => "BD",
                "P" => "PDC",
                "Y" => "YY",
                _ => upper
            };
        }

        SpecialAdjustmentRow? PickAdjustment(string employeeCode, string mappedProductCode)
        {
            return specialAdjustmentRows
                .Where(x => x.EmployeeCode == employeeCode && (x.ProductCode == null || x.ProductCode == mappedProductCode))
                .OrderBy(x => x.ProductCode == null ? 1 : 0)
                .ThenByDescending(x => x.AdjustmentId)
                .FirstOrDefault();
        }

        decimal? RateValue(string positionCode, string wsTypeForRate)
        {
            var r = rateRows.Where(x => x.PositionCode == positionCode && x.WsType == wsTypeForRate)
                .OrderByDescending(x => x.EffectiveFrom)
                .FirstOrDefault();
            return r is null ? null : (r.RateNew ?? r.RateOld);
        }

        var detailRows = new List<DetailRow>();

        foreach (var t in targets)
        {
            if (t.TargetAmount <= 0) continue;

            var actualAmount = actualLookup.TryGetValue((t.SalesmanCode, t.ProductCode), out var a) ? a : 0m;
            var wsTypeForSalesman = WsTypeFor(t.SalesmanCode);

            var baseProductCode = t.ProductCode.StartsWith("SKU-", StringComparison.OrdinalIgnoreCase)
                ? t.ProductCode[4..].Split('-', 2)[0]
                : t.ProductCode;
            var mappedProductCode = MapLaosProductCode(baseProductCode);

            productRows.TryGetValue(mappedProductCode, out var product);
            var productId = product?.ProductId;

            var weight = productId is null
                ? null
                : weightRows
                    .Where(w => w.ProductId == productId && w.WsType == wsTypeForSalesman)
                    .OrderByDescending(w => w.EffectiveFrom)
                    .FirstOrDefault();

            var specialAdj = PickAdjustment(t.SalesmanCode, mappedProductCode);
            decimal overrideAch = 0m;
            var hasShortage = productId is not null && shortageRows.TryGetValue(productId.Value, out overrideAch);
            var staffRate = RateValue("STAFF", wsTypeForSalesman) ?? 0m;

            var achievement = t.TargetAmount == 0 ? 0m : Math.Round(actualAmount / t.TargetAmount, 4);

            decimal finalAchievement;
            if (specialAdj?.OverrideAchievement is not null)
            {
                finalAchievement = specialAdj.OverrideAchievement.Value;
            }
            else if (specialAdj?.AdjustedTargetAmount is not null && specialAdj.AdjustedTargetAmount > 0)
            {
                finalAchievement = Math.Round(actualAmount / specialAdj.AdjustedTargetAmount.Value, 4);
            }
            else if (hasShortage)
            {
                finalAchievement = overrideAch;
            }
            else
            {
                finalAchievement = achievement;
            }
            finalAchievement = Math.Round(finalAchievement, 4);

            var productWeight = specialAdj?.AdjustedWeightPercent ?? weight?.WeightPercent ?? 0m;

            var goalMultiplier = goalThresholds
                .Where(g => finalAchievement >= g.AchievementFrom && (g.AchievementTo is null || finalAchievement <= g.AchievementTo))
                .OrderByDescending(g => g.AchievementFrom)
                .ThenByDescending(g => g.SequenceNo)
                .Select(g => (decimal?)g.Multiplier)
                .FirstOrDefault() ?? 0m;

            decimal incentiveAmount;
            if (formulas.TryGetValue(wsTypeForSalesman, out var formulaExpr))
            {
                var expr = new Expression(NormalizeForNCalc(formulaExpr));
                expr.Parameters["base_rate"] = (double)staffRate;
                expr.Parameters["weight_pct"] = (double)productWeight;
                expr.Parameters["goal_mult"] = (double)goalMultiplier;
                incentiveAmount = Convert.ToDecimal(expr.Evaluate());
            }
            else
            {
                incentiveAmount = Math.Round(staffRate * goalMultiplier * productWeight, 2);
            }

            detailRows.Add(new DetailRow
            {
                EmployeeCode = t.SalesmanCode,
                PositionLevelCode = "STAFF",
                ProductCode = t.ProductCode,
                TargetAmount = t.TargetAmount,
                ActualAmount = actualAmount,
                Achievement = achievement,
                ShortageFlag = hasShortage || specialAdj?.OverrideAchievement is not null,
                FinalAchievement = finalAchievement,
                GoalMultiplier = goalMultiplier,
                IncentiveBase = staffRate,
                ProductWeight = productWeight,
                IncentiveAmount = Math.Round(incentiveAmount, 2)
            });
        }

        var staffRows = detailRows.Where(d => d.PositionLevelCode == "STAFF").ToList();
        var managerLevels = new (string Level, Func<HierRow, string?> PickCode)[]
        {
            ("SECT_MGR", h => h.DirectSupCode),
            ("DEPT_MGR", h => h.DeptMgrCode)
        };

        foreach (var (level, pickCode) in managerLevels)
        {
            var byManager = staffRows
                .Select(s => new { s, ManagerCode = pickCode(BestHierRow(s.EmployeeCode) ?? new HierRow { SalesmanCode = s.EmployeeCode }) })
                .Where(x => !string.IsNullOrEmpty(x.ManagerCode))
                .GroupBy(x => x.ManagerCode!);

            foreach (var grp in byManager)
            {
                var targetSum = grp.Sum(x => x.s.TargetAmount);
                var actualSum = grp.Sum(x => x.s.ActualAmount);
                // SQL ต้นทางใช้ AVG(CAST(goal_multiplier AS DECIMAL(18,6)))
                // ซึ่งจากข้อมูลจริงได้ผลเชิง scale=6 แบบไม่ปัดขึ้นในเคสนี้
                // จึง truncate ที่ 6 ตำแหน่งเพื่อ parity กับผล Stored Procedure
                var avgGoalMultiplier = grp.Average(x => x.s.GoalMultiplier);
                var rawAchievement = decimal.Truncate(avgGoalMultiplier * 1_000_000m) / 1_000_000m;
                var achievement = decimal.Round(rawAchievement, 4, MidpointRounding.AwayFromZero);
                var incentiveBase = RateValue(level, legacyWsType) ?? 0m;

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
                    IncentiveBase = incentiveBase,
                    ProductWeight = 1.0000m,
                    IncentiveAmount = decimal.Round(incentiveBase * rawAchievement, 2, MidpointRounding.AwayFromZero)
                });
            }
        }

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
INSERT INTO dbo.out_for_hr_variable
    (calc_run_id, employee_code, employee_name_th, position_level_code, channel_code,
     variable_pay_month, incentive_staff, incentive_sect, incentive_dept, incentive_ad,
     gd_incentive_total, total_variable, payment_method)
SELECT
    @RunId,
    d.salesman_code,
    COALESCE(e.employee_name_th, d.salesman_code),
    d.position_level_code,
    N'LAOS',
    @SalesMonth,
    CAST(ROUND(SUM(CASE WHEN d.position_level_code = N'STAFF' THEN d.incentive_amount ELSE 0 END), 2) AS DECIMAL(18,2)),
    CAST(ROUND(SUM(CASE WHEN d.position_level_code = N'SECT_MGR' THEN d.incentive_amount ELSE 0 END), 2) AS DECIMAL(18,2)),
    CAST(ROUND(SUM(CASE WHEN d.position_level_code = N'DEPT_MGR' THEN d.incentive_amount ELSE 0 END), 2) AS DECIMAL(18,2)),
    CAST(ROUND(SUM(CASE WHEN d.position_level_code = N'AD' THEN d.incentive_amount ELSE 0 END), 2) AS DECIMAL(18,2)),
    CAST(0.00 AS DECIMAL(18,2)),
    CAST(ROUND(SUM(d.incentive_amount), 2) AS DECIMAL(18,2)),
    N'BANK_TRANSFER'
FROM dbo.trn_incentive_detail d
LEFT JOIN dbo.mst_employee e ON e.employee_code = d.salesman_code AND e.channel_id = @ChannelId
WHERE d.calc_run_id = @RunId
GROUP BY d.salesman_code, d.position_level_code, e.employee_name_th;",
            new { RunId = runId, SalesMonth = salesMonth, ChannelId = channelId });

        await conn.ExecuteAsync(@"
UPDATE dbo.trn_calc_run
SET run_status = N'COMPLETED', updated_at = GETDATE(), approved_by = COALESCE(approved_by, @ApprovedBy)
WHERE calc_run_id = @RunId",
            new { RunId = runId, ApprovedBy = approvedBy ?? "system" });

        return runId;
    }

    private static string NormalizeForNCalc(string formulaExpr) =>
        System.Text.RegularExpressions.Regex.Replace(
            formulaExpr, @"\bROUND\b", "Round", System.Text.RegularExpressions.RegexOptions.IgnoreCase);
}
