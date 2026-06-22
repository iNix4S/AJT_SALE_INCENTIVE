param(
    [int]$FiscalStartYear = 2026,
    [string[]]$WsTypes = @('TOP_WS','WS_SF','WS_WH','SF_WH'),
    [string]$ApprovedBy = 'ws_type_report',
    [string]$ConnectionString,
    [switch]$RestoreTopWs = $true,
    [string]$OutputDir = 'final-docs'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ConnectionStringFromEnv {
    param([string]$EnvFilePath)

    $line = Get-Content -LiteralPath $EnvFilePath | Where-Object { $_ -match '^DB_CONNECTION_STRING=' } | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($line)) {
        throw "DB_CONNECTION_STRING not found in $EnvFilePath"
    }

    return $line.Substring('DB_CONNECTION_STRING='.Length)
}

if ([string]::IsNullOrWhiteSpace($ConnectionString)) {
    $ConnectionString = Get-ConnectionStringFromEnv -EnvFilePath 'environment/database-dev.env'
}

if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$cn = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
$cn.Open()

try {
    $periodCmd = $cn.CreateCommand()
    $periodCmd.CommandText = @"
DECLARE @fy_start DATE = DATEFROMPARTS(@fiscal_start_year, 4, 1);
DECLARE @fy_end DATE = DATEFROMPARTS(@fiscal_start_year + 1, 3, 1);
DECLARE @tt_channel_id INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'TT');

SELECT
    p.period_code,
    p.sales_month,
    COUNT(t.sales_target_id) AS target_rows
FROM dbo.mst_period p
LEFT JOIN dbo.trn_sales_target t
    ON t.period_id = p.period_id
   AND t.channel_id = @tt_channel_id
WHERE p.sales_month >= @fy_start
  AND p.sales_month <= @fy_end
GROUP BY p.period_code, p.sales_month
HAVING COUNT(t.sales_target_id) > 0
ORDER BY p.sales_month;
"@
    [void]$periodCmd.Parameters.AddWithValue('@fiscal_start_year', $FiscalStartYear)

    $daPeriods = New-Object System.Data.SqlClient.SqlDataAdapter($periodCmd)
    $dtPeriods = New-Object System.Data.DataTable
    [void]$daPeriods.Fill($dtPeriods)

    if ($dtPeriods.Rows.Count -eq 0) {
        throw "No periods with TT target data found for FY$FiscalStartYear"
    }

    $results = New-Object System.Data.DataTable
    [void]$results.Columns.Add('ws_type', [string])
    [void]$results.Columns.Add('period_code', [string])
    [void]$results.Columns.Add('sales_month', [string])
    [void]$results.Columns.Add('calc_run_id', [int])
    [void]$results.Columns.Add('detail_rows', [int])
    [void]$results.Columns.Add('hr_rows', [int])
    [void]$results.Columns.Add('incentive_staff', [decimal])
    [void]$results.Columns.Add('incentive_sect', [decimal])
    [void]$results.Columns.Add('incentive_dept', [decimal])
    [void]$results.Columns.Add('incentive_div', [decimal])
    [void]$results.Columns.Add('incentive_ad', [decimal])
    [void]$results.Columns.Add('special_kpi_bonus', [decimal])
    [void]$results.Columns.Add('total_variable', [decimal])

    foreach ($ws in $WsTypes) {
        foreach ($p in $dtPeriods.Rows) {
            $periodCode = [string]$p.period_code
            $salesMonth = ([datetime]$p.sales_month).ToString('yyyy-MM-dd')

            $exec = $cn.CreateCommand()
            $exec.CommandTimeout = 0
            $exec.CommandText = @"
EXEC dbo.usp_run_tt_incentive_calculation
     @PeriodCode = @period_code,
     @WsType = @ws_type,
     @ApprovedBy = @approved_by;
"@
            [void]$exec.Parameters.AddWithValue('@period_code', $periodCode)
            [void]$exec.Parameters.AddWithValue('@ws_type', $ws)
            [void]$exec.Parameters.AddWithValue('@approved_by', $ApprovedBy)
            [void]$exec.ExecuteNonQuery()

            $sumCmd = $cn.CreateCommand()
            $sumCmd.CommandText = @"
DECLARE @run_id INT = (
    SELECT calc_run_id
    FROM dbo.trn_calc_run r
    JOIN dbo.mst_period p ON p.period_id = r.period_id
    JOIN dbo.mst_channel c ON c.channel_id = r.channel_id
    WHERE p.period_code = @period_code
      AND c.channel_code = N'TT'
);

SELECT
    @run_id AS calc_run_id,
    (SELECT COUNT(*) FROM dbo.trn_incentive_detail WHERE calc_run_id = @run_id) AS detail_rows,
    (SELECT COUNT(*) FROM dbo.out_for_hr_variable WHERE calc_run_id = @run_id) AS hr_rows,
    (SELECT COALESCE(SUM(incentive_staff),0) FROM dbo.out_for_hr_variable WHERE calc_run_id = @run_id) AS incentive_staff,
    (SELECT COALESCE(SUM(incentive_sect),0) FROM dbo.out_for_hr_variable WHERE calc_run_id = @run_id) AS incentive_sect,
    (SELECT COALESCE(SUM(incentive_dept),0) FROM dbo.out_for_hr_variable WHERE calc_run_id = @run_id) AS incentive_dept,
    (SELECT COALESCE(SUM(incentive_div),0) FROM dbo.out_for_hr_variable WHERE calc_run_id = @run_id) AS incentive_div,
    (SELECT COALESCE(SUM(incentive_ad),0) FROM dbo.out_for_hr_variable WHERE calc_run_id = @run_id) AS incentive_ad,
    (SELECT COALESCE(SUM(bonus_amount),0) FROM dbo.trn_tt_special_kpi_detail WHERE calc_run_id = @run_id) AS special_kpi_bonus,
    (SELECT COALESCE(SUM(total_variable),0) FROM dbo.out_for_hr_variable WHERE calc_run_id = @run_id) AS total_variable;
"@
            [void]$sumCmd.Parameters.AddWithValue('@period_code', $periodCode)

            $daSum = New-Object System.Data.SqlClient.SqlDataAdapter($sumCmd)
            $dtSum = New-Object System.Data.DataTable
            [void]$daSum.Fill($dtSum)

            if ($dtSum.Rows.Count -gt 0) {
                $r = $results.NewRow()
                $r['ws_type'] = $ws
                $r['period_code'] = $periodCode
                $r['sales_month'] = $salesMonth
                $r['calc_run_id'] = [int]$dtSum.Rows[0].calc_run_id
                $r['detail_rows'] = [int]$dtSum.Rows[0].detail_rows
                $r['hr_rows'] = [int]$dtSum.Rows[0].hr_rows
                $r['incentive_staff'] = [decimal]$dtSum.Rows[0].incentive_staff
                $r['incentive_sect'] = [decimal]$dtSum.Rows[0].incentive_sect
                $r['incentive_dept'] = [decimal]$dtSum.Rows[0].incentive_dept
                $r['incentive_div'] = [decimal]$dtSum.Rows[0].incentive_div
                $r['incentive_ad'] = [decimal]$dtSum.Rows[0].incentive_ad
                $r['special_kpi_bonus'] = [decimal]$dtSum.Rows[0].special_kpi_bonus
                $r['total_variable'] = [decimal]$dtSum.Rows[0].total_variable
                [void]$results.Rows.Add($r)
            }
        }
    }

    if ($RestoreTopWs) {
        foreach ($p in $dtPeriods.Rows) {
            $periodCode = [string]$p.period_code
            $restore = $cn.CreateCommand()
            $restore.CommandTimeout = 0
            $restore.CommandText = @"
EXEC dbo.usp_run_tt_incentive_calculation
     @PeriodCode = @period_code,
     @WsType = N'TOP_WS',
     @ApprovedBy = @approved_by;
"@
            [void]$restore.Parameters.AddWithValue('@period_code', $periodCode)
            [void]$restore.Parameters.AddWithValue('@approved_by', 'restore_top_ws')
            [void]$restore.ExecuteNonQuery()
        }
    }

    $ts = (Get-Date).ToString('yyyyMMdd_HHmmss')
    $csvPath = Join-Path $OutputDir ("AJT_TT_WS_Type_Monthly_Summary_{0}.csv" -f $ts)
    $mdPath = Join-Path $OutputDir ("AJT_TT_WS_Type_Monthly_Summary_{0}.md" -f $ts)

    $results | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8

    $md = New-Object System.Text.StringBuilder
    [void]$md.AppendLine('# AJT TT WS Type Monthly Summary')
    [void]$md.AppendLine('')
    [void]$md.AppendLine(("Generated At: {0}" -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))
    [void]$md.AppendLine(("Fiscal Year Start: {0}" -f $FiscalStartYear))
    [void]$md.AppendLine('')
    [void]$md.AppendLine('| ws_type | period_code | sales_month | detail_rows | hr_rows | incentive_staff | incentive_sect | incentive_dept | incentive_div | incentive_ad | special_kpi_bonus | total_variable |')
    [void]$md.AppendLine('|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|')

    foreach ($row in $results.Rows) {
        [void]$md.AppendLine(("| {0} | {1} | {2} | {3} | {4} | {5:N2} | {6:N2} | {7:N2} | {8:N2} | {9:N2} | {10:N2} | {11:N2} |" -f
            $row.ws_type,
            $row.period_code,
            $row.sales_month,
            $row.detail_rows,
            $row.hr_rows,
            $row.incentive_staff,
            $row.incentive_sect,
            $row.incentive_dept,
            $row.incentive_div,
            $row.incentive_ad,
            $row.special_kpi_bonus,
            $row.total_variable))
    }

    [void]$md.AppendLine('')
    [void]$md.AppendLine(("CSV: {0}" -f $csvPath))

    [System.IO.File]::WriteAllText($mdPath, $md.ToString(), [System.Text.Encoding]::UTF8)

    "WS_TYPE_MONTHLY_CSV=$csvPath"
    "WS_TYPE_MONTHLY_MD=$mdPath"
    "WS_TYPE_MONTHLY_ROWS=$($results.Rows.Count)"
}
finally {
    $cn.Close()
}
