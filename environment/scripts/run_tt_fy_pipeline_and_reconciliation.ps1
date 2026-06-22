param(
    [int]$FiscalStartYear = 2026,
    [string]$WsType = 'TOP_WS',
    [string]$ApprovedBy = 'copilot_pipeline',
    [string]$ConnectionString,
    [string]$TtExtractDir = '4.System Analyst and Design/01.Raw-Extracts/TT',
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

function Invoke-SqlBatches {
    param(
        [System.Data.SqlClient.SqlConnection]$Connection,
        [string]$SqlFilePath
    )

    if (-not (Test-Path -LiteralPath $SqlFilePath)) {
        throw "SQL file not found: $SqlFilePath"
    }

    $sqlText = Get-Content -LiteralPath $SqlFilePath -Raw
    $batches = [regex]::Split($sqlText, '(?im)^\s*GO\s*\r?\n')

    foreach ($batch in $batches) {
        if ([string]::IsNullOrWhiteSpace($batch)) { continue }
        $cmd = $Connection.CreateCommand()
        $cmd.CommandTimeout = 0
        $cmd.CommandText = $batch
        [void]$cmd.ExecuteNonQuery()
    }
}

function ConvertTo-NullableDecimal {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }

    $raw = $Value.Trim().Replace(',', '')
    $num = 0.0
    if ([double]::TryParse($raw, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$num)) {
        return [decimal]$num
    }

    return $null
}

function Get-TargetCalRows {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }

    $lines = @(Get-Content -LiteralPath $Path)
    if ($lines.Count -lt 4) {
        return @()
    }

    $headerParts = $lines[2].Split(',')
    $nameCount = @{}
    $colIndex = 0
    $uniqueHeaders = foreach ($h in $headerParts) {
        $colIndex += 1
        $name = ([string]$h).Trim().TrimStart([char]0xFEFF)
        if ([string]::IsNullOrWhiteSpace($name)) {
            $name = "col_$colIndex"
        }
        if (-not $nameCount.ContainsKey($name)) {
            $nameCount[$name] = 1
            $name
        }
        else {
            $nameCount[$name] += 1
            "{0}_{1}" -f $name, $nameCount[$name]
        }
    }

    $dataLines = $lines | Select-Object -Skip 3
    $normalizedCsv = @(($uniqueHeaders -join ',')) + $dataLines
    return ($normalizedCsv | ConvertFrom-Csv)
}

function Get-NonEmptyDataRowCount {
    param(
        [string]$Path,
        [int]$SkipLines = 1
    )

    if (-not (Test-Path -LiteralPath $Path)) { return 0 }

    $lines = @(Get-Content -LiteralPath $Path)
    if ($lines.Count -le $SkipLines) { return 0 }

    $count = 0
    foreach ($line in ($lines | Select-Object -Skip $SkipLines)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $first = ($line.Split(',')[0]).Trim()
        if ([string]::IsNullOrWhiteSpace($first)) { continue }
        $count += 1
    }

    return $count
}

function New-SourceMetricsTable {
    $dt = New-Object System.Data.DataTable
    [void]$dt.Columns.Add('sheet_no', [int])
    [void]$dt.Columns.Add('sheet_name', [string])
    [void]$dt.Columns.Add('source_row_count', [int])
    [void]$dt.Columns.Add('source_amount', [decimal])
    [void]$dt.Columns.Add('compare_mode', [string])
    [void]$dt.Columns.Add('row_tolerance', [int])
    [void]$dt.Columns.Add('amount_tolerance', [decimal])
    return ,$dt
}

function Add-SourceMetricRow {
    param(
        [System.Data.DataTable]$Table,
        [int]$SheetNo,
        [string]$SheetName,
        [Nullable[int]]$RowCount,
        [Nullable[decimal]]$Amount,
        [string]$CompareMode,
        [Nullable[int]]$RowTolerance,
        [Nullable[decimal]]$AmountTolerance
    )

    $dr = $Table.NewRow()
    $dr['sheet_no'] = $SheetNo
    $dr['sheet_name'] = $SheetName
    if ($null -eq $RowCount) { $dr['source_row_count'] = [DBNull]::Value } else { $dr['source_row_count'] = $RowCount }
    if ($null -eq $Amount) { $dr['source_amount'] = [DBNull]::Value } else { $dr['source_amount'] = $Amount }
    $dr['compare_mode'] = $CompareMode
    if ($null -eq $RowTolerance) { $dr['row_tolerance'] = [DBNull]::Value } else { $dr['row_tolerance'] = $RowTolerance }
    if ($null -eq $AmountTolerance) { $dr['amount_tolerance'] = [DBNull]::Value } else { $dr['amount_tolerance'] = $AmountTolerance }
    [void]$Table.Rows.Add($dr)
}

function Get-MonthKey {
    param([datetime]$SalesMonth)

    return [PSCustomObject]@{
        Short3 = $SalesMonth.ToString('MMM', [System.Globalization.CultureInfo]::InvariantCulture)
        Full = $SalesMonth.ToString('MMMM', [System.Globalization.CultureInfo]::InvariantCulture)
        Label = $SalesMonth.ToString('MMM-yy', [System.Globalization.CultureInfo]::InvariantCulture)
    }
}

function Build-SourceMetricsForPeriod {
    param(
        [string]$BaseDir,
        [datetime]$SalesMonth
    )

    $month = Get-MonthKey -SalesMonth $SalesMonth
    $dt = New-SourceMetricsTable

    $cfg = @(
        @{ No = 1; Name = '01_Top WS'; File = '01_Top WS.values.csv'; Skip = 1; Mode = 'INFO' },
        @{ No = 2; Name = '02_WS SF'; File = '02_WS SF.values.csv'; Skip = 1; Mode = 'INFO' },
        @{ No = 3; Name = '03_WS WH'; File = '03_WS WH.values.csv'; Skip = 1; Mode = 'INFO' },
        @{ No = 4; Name = '04_Test'; File = '04_Test.values.csv'; Skip = 1; Mode = 'INFO' },
        @{ No = 5; Name = '05_SF WH'; File = '05_SF WH.values.csv'; Skip = 1; Mode = 'INFO' },
        @{ No = 6; Name = '06_M_Month'; File = '06_M_Month.values.csv'; Skip = 0; Mode = 'NONZERO' },
        @{ No = 7; Name = '07_Product'; File = '07_Product.values.csv'; Skip = 0; Mode = 'NONZERO' },
        @{ No = 8; Name = '08_T_SectAbove'; File = '08_T_SectAbove.values.csv'; Skip = 0; Mode = 'NONZERO' },
        @{ No = 9; Name = '09_2) หลักการคำนวน Table'; File = '09_2) หลักการคำนวน Table.values.csv'; Skip = 1; Mode = 'INFO' },
        @{ No = 10; Name = '10_Period'; File = '10_Period.values.csv'; Skip = 0; Mode = 'NONZERO' },
        @{ No = 11; Name = '11_3)Target & Cal'; File = '11_3)Target & Cal.values.csv'; Skip = 3; Mode = 'NONZERO' },
        @{ No = 12; Name = '12_Actual'; File = '12_Actual.values.csv'; Skip = 1; Mode = 'EXACT' },
        @{ No = 13; Name = '13_ASTBase'; File = '13_ASTBase.values.csv'; Skip = 1; Mode = 'NONZERO' },
        @{ No = 14; Name = '14_HR Rep'; File = '14_HR Rep.values.csv'; Skip = 1; Mode = 'NONZERO' },
        @{ No = 15; Name = '15_1) For HR'; File = '15_1) For HR.values.csv'; Skip = 1; Mode = 'NONZERO' },
        @{ No = 16; Name = '16_1) For HR (AD)'; File = '16_1) For HR (AD).values.csv'; Skip = 1; Mode = 'NONZERO' },
        @{ No = 17; Name = '17_Shortage'; File = '17_Shortage.values.csv'; Skip = 1; Mode = 'NONZERO' },
        @{ No = 18; Name = '18_Aji Plus'; File = '18_Aji Plus.values.csv'; Skip = 0; Mode = 'INFO' },
        @{ No = 19; Name = '19_Actual_Aji Plus'; File = '19_Actual_Aji Plus.values.csv'; Skip = 0; Mode = 'INFO' },
        @{ No = 20; Name = '20_RDQ'; File = '20_RDQ.values.csv'; Skip = 0; Mode = 'INFO' },
        @{ No = 21; Name = '21_Actual_RDQ'; File = '21_Actual_RDQ.values.csv'; Skip = 0; Mode = 'INFO' },
        @{ No = 22; Name = '22_RDM'; File = '22_RDM.values.csv'; Skip = 0; Mode = 'INFO' },
        @{ No = 23; Name = '23_Actual_RDM'; File = '23_Actual_RDM.values.csv'; Skip = 0; Mode = 'INFO' },
        @{ No = 24; Name = '24_RDNS'; File = '24_RDNS.values.csv'; Skip = 0; Mode = 'INFO' },
        @{ No = 25; Name = '25_Actual_RDNS'; File = '25_Actual_RDNS.values.csv'; Skip = 0; Mode = 'INFO' },
        @{ No = 26; Name = '26_Sales Target'; File = '26_Sales Target.values.csv'; Skip = 0; Mode = 'INFO' }
    )

    foreach ($c in $cfg) {
        $path = Join-Path $BaseDir $c.File
        $rowCount = Get-NonEmptyDataRowCount -Path $path -SkipLines $c.Skip
        Add-SourceMetricRow -Table $dt -SheetNo $c.No -SheetName $c.Name -RowCount $rowCount -Amount $null -CompareMode $c.Mode -RowTolerance 0 -AmountTolerance 0
    }

    $targetCalPath = Join-Path $BaseDir '11_3)Target & Cal.values.csv'
    $targetRows = Get-TargetCalRows -Path $targetCalPath
    $targetMonthCol = '{0}_T' -f $month.Short3
    $targetAmount = 0.0
    $targetCount = 0
    foreach ($r in $targetRows) {
        if (-not ($r.PSObject.Properties.Name -contains 'SalesmanCode')) { continue }
        if ([string]::IsNullOrWhiteSpace([string]$r.SalesmanCode)) { continue }
        if (-not ($r.PSObject.Properties.Name -contains $targetMonthCol)) { continue }
        $v = ConvertTo-NullableDecimal -Value ([string]$r.$targetMonthCol)
        if ($null -eq $v) { continue }
        if ($v -le 0) { continue }
        $targetAmount += [double]$v
        $targetCount += 1
    }
    $row11 = $dt.Select('sheet_no = 11')[0]
    $row11['source_row_count'] = $targetCount
    $row11['source_amount'] = [decimal]([Math]::Round($targetAmount, 2))
    $row11['amount_tolerance'] = [decimal]5

    $actualPath = Join-Path $BaseDir '12_Actual.values.csv'
    if (Test-Path -LiteralPath $actualPath) {
        $actualRows = Import-Csv -LiteralPath $actualPath
        $actualMonthCol = $month.Full
        $actualAmount = 0.0
        $actualCount = 0
        foreach ($r in $actualRows) {
            if ([string]::IsNullOrWhiteSpace([string]$r.'Salesman Code')) { continue }
            $v = $null
            if ($r.PSObject.Properties.Name -contains $actualMonthCol) {
                $v = ConvertTo-NullableDecimal -Value ([string]$r.$actualMonthCol)
            }
            if ($null -eq $v) { continue }
            if ($v -le 0) { continue }
            $actualAmount += [double]$v
            $actualCount += 1
        }
        $row12 = $dt.Select('sheet_no = 12')[0]
        $row12['source_row_count'] = $actualCount
        $row12['source_amount'] = [decimal]([Math]::Round($actualAmount, 2))
        $row12['row_tolerance'] = 2
        $row12['amount_tolerance'] = [decimal]5
    }

    $forHrPath = Join-Path $BaseDir '15_1) For HR.values.csv'
    if (Test-Path -LiteralPath $forHrPath) {
        $forHrRows = Import-Csv -LiteralPath $forHrPath
        $hrAmount = 0.0
        $hrCount = 0
        foreach ($r in $forHrRows) {
            $payMonth = [string]$r.'sales incentive ของเดือน'
            if (-not [string]::IsNullOrWhiteSpace($payMonth) -and $payMonth -ne $month.Label) {
                continue
            }
            $v = ConvertTo-NullableDecimal -Value ([string]$r.'Monthly Sales compensation')
            if ($null -eq $v) { continue }
            $hrAmount += [double]$v
            $hrCount += 1
        }
        $row15 = $dt.Select('sheet_no = 15')[0]
        $row15['source_row_count'] = $hrCount
        $row15['source_amount'] = [decimal]([Math]::Round($hrAmount, 2))
        $row15['amount_tolerance'] = [decimal]5
    }

    return $dt
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
    Invoke-SqlBatches -Connection $cn -SqlFilePath 'environment/ddl/16_add_incentive_div_to_out_for_hr_variable.sql'
    Invoke-SqlBatches -Connection $cn -SqlFilePath 'environment/ddl/19_create_tt_formula_matrix_option_band_and_special_kpi.sql'
    Invoke-SqlBatches -Connection $cn -SqlFilePath 'environment/ddl/15_create_proc_run_tt_incentive_calculation.sql'
    Invoke-SqlBatches -Connection $cn -SqlFilePath 'environment/ddl/17_create_proc_validate_tt_26_sheets_pass_fail.sql'

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
ORDER BY p.sales_month;
"@
    [void]$periodCmd.Parameters.AddWithValue('@fiscal_start_year', $FiscalStartYear)

    $daPeriods = New-Object System.Data.SqlClient.SqlDataAdapter($periodCmd)
    $dtPeriods = New-Object System.Data.DataTable
    [void]$daPeriods.Fill($dtPeriods)

    if ($dtPeriods.Rows.Count -eq 0) {
        throw "No periods found for FY$FiscalStartYear"
    }

    $periodRows = @($dtPeriods.Rows | Where-Object { [int]$_.target_rows -gt 0 })
    if ($periodRows.Count -eq 0) {
        $periodRows = @($dtPeriods.Rows)
    }

    $runResults = New-Object System.Data.DataTable
    [void]$runResults.Columns.Add('period_code', [string])
    [void]$runResults.Columns.Add('sales_month', [string])
    [void]$runResults.Columns.Add('calc_run_id', [int])
    [void]$runResults.Columns.Add('trn_incentive_detail_rows', [int])
    [void]$runResults.Columns.Add('out_for_hr_variable_rows', [int])

    $allValidation = New-Object System.Data.DataTable
    $allValidationInitialized = $false

    foreach ($pr in $periodRows) {
        $periodCode = [string]$pr.period_code
        $salesMonth = [datetime]$pr.sales_month

        $exec = $cn.CreateCommand()
        $exec.CommandTimeout = 0
        $exec.CommandText = @"
EXEC dbo.usp_run_tt_incentive_calculation
     @PeriodCode = @period_code,
     @WsType = @ws_type,
     @ApprovedBy = @approved_by;
"@
        [void]$exec.Parameters.AddWithValue('@period_code', $periodCode)
        [void]$exec.Parameters.AddWithValue('@ws_type', $WsType)
        [void]$exec.Parameters.AddWithValue('@approved_by', $ApprovedBy)

        $daExec = New-Object System.Data.SqlClient.SqlDataAdapter($exec)
        $dtExec = New-Object System.Data.DataTable
        [void]$daExec.Fill($dtExec)

        if ($dtExec.Rows.Count -gt 0) {
            $r = $runResults.NewRow()
            $r['period_code'] = $periodCode
            $r['sales_month'] = $salesMonth.ToString('yyyy-MM-dd')
            $r['calc_run_id'] = [int]$dtExec.Rows[0].calc_run_id
            $r['trn_incentive_detail_rows'] = [int]$dtExec.Rows[0].trn_incentive_detail_rows
            $r['out_for_hr_variable_rows'] = [int]$dtExec.Rows[0].out_for_hr_variable_rows
            [void]$runResults.Rows.Add($r)
        }

        $srcMetrics = Build-SourceMetricsForPeriod -BaseDir $TtExtractDir -SalesMonth $salesMonth

        $prep = $cn.CreateCommand()
        $prep.CommandText = @"
IF OBJECT_ID('tempdb..#tt_sheet_source_metrics') IS NOT NULL DROP TABLE #tt_sheet_source_metrics;
CREATE TABLE #tt_sheet_source_metrics (
    sheet_no INT NOT NULL,
    sheet_name NVARCHAR(100) NOT NULL,
    source_row_count INT NULL,
    source_amount DECIMAL(18,2) NULL,
    compare_mode NVARCHAR(20) NOT NULL,
    row_tolerance INT NULL,
    amount_tolerance DECIMAL(18,2) NULL
);
"@
        [void]$prep.ExecuteNonQuery()

        $bulk = New-Object System.Data.SqlClient.SqlBulkCopy($cn)
        $bulk.DestinationTableName = '#tt_sheet_source_metrics'
        $bulk.BulkCopyTimeout = 0
        foreach ($col in @('sheet_no','sheet_name','source_row_count','source_amount','compare_mode','row_tolerance','amount_tolerance')) {
            [void]$bulk.ColumnMappings.Add($col, $col)
        }
        $bulk.WriteToServer($srcMetrics)
        $bulk.Close()

        $validate = $cn.CreateCommand()
        $validate.CommandText = 'EXEC dbo.usp_validate_tt_26_sheets_pass_fail @PeriodCode = @period_code;'
        [void]$validate.Parameters.AddWithValue('@period_code', $periodCode)

        $daVal = New-Object System.Data.SqlClient.SqlDataAdapter($validate)
        $dtVal = New-Object System.Data.DataTable
        [void]$daVal.Fill($dtVal)

        if (-not $allValidationInitialized) {
            $allValidation = $dtVal.Clone()
            $allValidationInitialized = $true
        }
        foreach ($row in $dtVal.Rows) {
            [void]$allValidation.ImportRow($row)
        }
    }

    $ts = (Get-Date).ToString('yyyyMMdd_HHmmss')
    $runCsv = Join-Path $OutputDir ("AJT_TT_FY_Run_Result_{0}.csv" -f $ts)
    $valCsv = Join-Path $OutputDir ("AJT_TT_26Sheet_Validation_Matrix_{0}.csv" -f $ts)
    $mdPath = Join-Path $OutputDir ("AJT_TT_FY_Reconciliation_Report_{0}.md" -f $ts)

    $runResults | Export-Csv -LiteralPath $runCsv -NoTypeInformation -Encoding UTF8
    $allValidation | Export-Csv -LiteralPath $valCsv -NoTypeInformation -Encoding UTF8

    $statusSummary = $allValidation | Group-Object validation_status | Sort-Object Name
    $failedRows = @($allValidation | Where-Object { $_.validation_status -eq 'FAIL' })

    $md = New-Object System.Text.StringBuilder
    [void]$md.AppendLine('# AJT TT FY Reconciliation Report')
    [void]$md.AppendLine('')
    [void]$md.AppendLine(("Generated At: {0}" -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))
    [void]$md.AppendLine(("Fiscal Year Start: {0}" -f $FiscalStartYear))
    [void]$md.AppendLine(("WS Type: {0}" -f $WsType))
    [void]$md.AppendLine('')
    [void]$md.AppendLine('## 1) TT Pipeline Run Result by Period')
    [void]$md.AppendLine('')
    [void]$md.AppendLine('| period_code | sales_month | calc_run_id | trn_incentive_detail_rows | out_for_hr_variable_rows |')
    [void]$md.AppendLine('|---|---|---:|---:|---:|')
    foreach ($r in $runResults.Rows) {
        [void]$md.AppendLine(("| {0} | {1} | {2} | {3} | {4} |" -f $r.period_code, $r.sales_month, $r.calc_run_id, $r.trn_incentive_detail_rows, $r.out_for_hr_variable_rows))
    }

    [void]$md.AppendLine('')
    [void]$md.AppendLine('## 2) Validation Status Summary (26 Sheets x Period)')
    [void]$md.AppendLine('')
    [void]$md.AppendLine('| status | count |')
    [void]$md.AppendLine('|---|---:|')
    foreach ($s in $statusSummary) {
        [void]$md.AppendLine(("| {0} | {1} |" -f $s.Name, $s.Count))
    }

    [void]$md.AppendLine('')
    [void]$md.AppendLine('## 3) Failed Items')
    [void]$md.AppendLine('')
    if ($failedRows.Count -eq 0) {
        [void]$md.AppendLine('No FAIL rows found.')
    }
    else {
        [void]$md.AppendLine('| period_code | sheet_no | sheet_name | source_row_count | db_row_count | source_amount | db_amount | row_gap_abs | amount_gap_abs |')
        [void]$md.AppendLine('|---|---:|---|---:|---:|---:|---:|---:|---:|')
        foreach ($f in $failedRows) {
            [void]$md.AppendLine(("| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} |" -f $f.period_code, $f.sheet_no, $f.sheet_name, $f.source_row_count, $f.db_row_count, $f.source_amount, $f.db_amount, $f.row_gap_abs, $f.amount_gap_abs))
        }
    }

    [void]$md.AppendLine('')
    [void]$md.AppendLine('## 4) Output Files')
    [void]$md.AppendLine('')
    [void]$md.AppendLine(("- Run CSV: {0}" -f $runCsv))
    [void]$md.AppendLine(("- Validation Matrix CSV: {0}" -f $valCsv))

    [System.IO.File]::WriteAllText($mdPath, $md.ToString(), [System.Text.Encoding]::UTF8)

    "TT_FY_RUN_PERIODS=$($runResults.Rows.Count)"
    "TT_FY_REPORT_MD=$mdPath"
    "TT_FY_RUN_CSV=$runCsv"
    "TT_FY_VALIDATION_CSV=$valCsv"
}
finally {
    $cn.Close()
}
