param(
    [string]$CsvPath = "4.System Analyst and Design/01.Raw-Extracts/TT/11_3)Target & Cal.values.csv",
    [int]$FiscalStartYear = 2026,
    [string]$ConnectionString,
    [string]$ChannelCode = "TT",
    [string]$ApprovedBy = "sheet_loader"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-ConnectionStringFromEnv {
    param([string]$EnvFilePath)

    $line = Get-Content -LiteralPath $EnvFilePath | Where-Object { $_ -match '^DB_CONNECTION_STRING=' } | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($line)) {
        throw "DB_CONNECTION_STRING not found in $EnvFilePath"
    }

    return $line.Substring('DB_CONNECTION_STRING='.Length)
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
        throw "CSV not found: $Path"
    }

    $lines = Get-Content -LiteralPath $Path
    if ($lines.Count -lt 4) {
        throw "CSV format invalid (expected at least 4 lines): $Path"
    }

    # line 3 is actual field header in extracted sheet format.
    # Some exported sheets contain duplicated names (for example Apr_I twice),
    # so we normalize to unique names before ConvertFrom-Csv.
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

if ([string]::IsNullOrWhiteSpace($ConnectionString)) {
    $ConnectionString = Get-ConnectionStringFromEnv -EnvFilePath "environment/database-dev.env"
}

$monthCols = @(
    @{ Col = "Apr_T"; Date = [datetime]::new($FiscalStartYear, 4, 1) },
    @{ Col = "May_T"; Date = [datetime]::new($FiscalStartYear, 5, 1) },
    @{ Col = "Jun_T"; Date = [datetime]::new($FiscalStartYear, 6, 1) },
    @{ Col = "Jul_T"; Date = [datetime]::new($FiscalStartYear, 7, 1) },
    @{ Col = "Aug_T"; Date = [datetime]::new($FiscalStartYear, 8, 1) },
    @{ Col = "Sep_T"; Date = [datetime]::new($FiscalStartYear, 9, 1) },
    @{ Col = "Oct_T"; Date = [datetime]::new($FiscalStartYear, 10, 1) },
    @{ Col = "Nov_T"; Date = [datetime]::new($FiscalStartYear, 11, 1) },
    @{ Col = "Dec_T"; Date = [datetime]::new($FiscalStartYear, 12, 1) },
    @{ Col = "Jan_T"; Date = [datetime]::new($FiscalStartYear + 1, 1, 1) },
    @{ Col = "Feb_T"; Date = [datetime]::new($FiscalStartYear + 1, 2, 1) },
    @{ Col = "Mar_T"; Date = [datetime]::new($FiscalStartYear + 1, 3, 1) }
)

$rows = Get-TargetCalRows -Path $CsvPath

$cn = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
$cn.Open()

try {
    $cmd = $cn.CreateCommand()
    $cmd.CommandText = @"
SELECT channel_id FROM dbo.mst_channel WHERE channel_code = @channel_code;
SELECT period_id, sales_month FROM dbo.mst_period;
"@
    [void]$cmd.Parameters.AddWithValue("@channel_code", $ChannelCode)

    $da = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
    $ds = New-Object System.Data.DataSet
    [void]$da.Fill($ds)

    if ($ds.Tables[0].Rows.Count -eq 0) {
        throw "Channel not found: $ChannelCode"
    }

    $channelId = [int]$ds.Tables[0].Rows[0].channel_id

    $periodByDate = @{}
    foreach ($r in $ds.Tables[1].Rows) {
        $d = ([datetime]$r.sales_month).Date.ToString("yyyy-MM-dd")
        $periodByDate[$d] = [int]$r.period_id
    }

    $dt = New-Object System.Data.DataTable
    [void]$dt.Columns.Add("period_id", [int])
    [void]$dt.Columns.Add("channel_id", [int])
    [void]$dt.Columns.Add("salesman_code", [string])
    [void]$dt.Columns.Add("product_code", [string])
    [void]$dt.Columns.Add("target_amount", [decimal])
    [void]$dt.Columns.Add("approved_by", [string])
    [void]$dt.Columns.Add("approved_at", [datetime])

    $skippedNoPeriod = 0
    $skippedNoKey = 0

    foreach ($r in $rows) {
        $salesman = [string]$r.SalesmanCode
        $product = [string]$r.Product

        if ([string]::IsNullOrWhiteSpace($salesman) -or [string]::IsNullOrWhiteSpace($product)) {
            $skippedNoKey += 1
            continue
        }

        $salesman = $salesman.Trim()
        $product = $product.Trim()

        foreach ($m in $monthCols) {
            $value = ConvertTo-NullableDecimal -Value ([string]$r.($m.Col))
            if ($null -eq $value) { continue }
            if ($value -le 0) { continue }

            $salesMonthKey = $m.Date.ToString("yyyy-MM-dd")
            if (-not $periodByDate.ContainsKey($salesMonthKey)) {
                $skippedNoPeriod += 1
                continue
            }

            $dr = $dt.NewRow()
            $dr.period_id = $periodByDate[$salesMonthKey]
            $dr.channel_id = $channelId
            $dr.salesman_code = $salesman
            $dr.product_code = $product
            $dr.target_amount = [decimal]::Round($value, 2)
            $dr.approved_by = $ApprovedBy
            $dr.approved_at = [datetime]::UtcNow
            [void]$dt.Rows.Add($dr)
        }
    }

    $prep = $cn.CreateCommand()
    $prep.CommandText = @"
IF OBJECT_ID('tempdb..#tt_target_src') IS NOT NULL DROP TABLE #tt_target_src;
CREATE TABLE #tt_target_src (
    period_id INT NOT NULL,
    channel_id INT NOT NULL,
    salesman_code NVARCHAR(50) NOT NULL,
    product_code NVARCHAR(50) NOT NULL,
    target_amount DECIMAL(18,2) NOT NULL,
    approved_by NVARCHAR(100) NULL,
    approved_at DATETIME2(0) NULL
);
"@
    [void]$prep.ExecuteNonQuery()

    $bulk = New-Object System.Data.SqlClient.SqlBulkCopy($cn)
    $bulk.DestinationTableName = "#tt_target_src"
    $bulk.BulkCopyTimeout = 0
    $bulk.BatchSize = 5000
    foreach ($col in @("period_id","channel_id","salesman_code","product_code","target_amount","approved_by","approved_at")) {
        [void]$bulk.ColumnMappings.Add($col, $col)
    }
    $bulk.WriteToServer($dt)
    $bulk.Close()

    $merge = $cn.CreateCommand()
    $merge.CommandText = @'
DECLARE @merge_actions TABLE(action_name NVARCHAR(10));

MERGE dbo.trn_sales_target AS tgt
USING #tt_target_src AS src
    ON tgt.period_id = src.period_id
   AND tgt.channel_id = src.channel_id
   AND tgt.salesman_code = src.salesman_code
   AND tgt.product_code = src.product_code
WHEN MATCHED THEN
    UPDATE SET
        tgt.target_amount = src.target_amount,
        tgt.approved_by = src.approved_by,
        tgt.approved_at = src.approved_at,
        tgt.updated_at = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (period_id, channel_id, salesman_code, product_code, target_amount, approved_by, approved_at)
    VALUES (src.period_id, src.channel_id, src.salesman_code, src.product_code, src.target_amount, src.approved_by, src.approved_at)
OUTPUT $action INTO @merge_actions(action_name);

SELECT
    SUM(CASE WHEN action_name = 'INSERT' THEN 1 ELSE 0 END) AS inserted_rows,
    SUM(CASE WHEN action_name = 'UPDATE' THEN 1 ELSE 0 END) AS updated_rows,
    COUNT(*) AS affected_rows
FROM @merge_actions;
'@

    $daMerge = New-Object System.Data.SqlClient.SqlDataAdapter($merge)
    $dtMerge = New-Object System.Data.DataTable
    [void]$daMerge.Fill($dtMerge)

    $inserted = 0
    $updated = 0
    $affected = 0
    if ($dtMerge.Rows.Count -gt 0) {
        $inserted = [int]($dtMerge.Rows[0].inserted_rows)
        $updated = [int]($dtMerge.Rows[0].updated_rows)
        $affected = [int]($dtMerge.Rows[0].affected_rows)
    }

    "TT_TARGET_ROWS_PARSED=$($dt.Rows.Count)"
    "TT_TARGET_INSERTED=$inserted"
    "TT_TARGET_UPDATED=$updated"
    "TT_TARGET_AFFECTED=$affected"
    "TT_TARGET_SKIPPED_NO_KEY=$skippedNoKey"
    "TT_TARGET_SKIPPED_NO_PERIOD=$skippedNoPeriod"
}
finally {
    $cn.Close()
}
