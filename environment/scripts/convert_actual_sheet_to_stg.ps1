param(
    [string]$MtActualPath = "4.System Analyst and Design/01.Raw-Extracts/MT/18_Actual.values.csv",
    [string]$TtActualPath = "4.System Analyst and Design/01.Raw-Extracts/TT/12_Actual.values.csv",
    [int]$FiscalStartYear = 2026,
    [string]$OutputCsv = "environment/generated/stg_bi_sales_from_actual_sheet.csv",
    [switch]$IncludeZero,
    [string]$ConnectionString,
    [switch]$LoadToDatabase,
    [switch]$UpsertTrn
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ConvertTo-Decimal {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    $styles = [System.Globalization.NumberStyles]::Float -bor [System.Globalization.NumberStyles]::AllowThousands
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $parsed = 0.0
    if ([double]::TryParse($Value.Trim(), $styles, $culture, [ref]$parsed)) {
        return [decimal]$parsed
    }

    return $null
}

function Get-ColumnValue {
    param(
        [psobject]$Row,
        [string]$ColumnName
    )

    $prop = $Row.PSObject.Properties[$ColumnName]
    if ($null -eq $prop) {
        return $null
    }

    return $prop.Value
}

function Get-MonthMap {
    param([int]$StartYear)

    return @(
        @{ Header = "April";    Date = [datetime]::new($StartYear, 4, 1) },
        @{ Header = "May";      Date = [datetime]::new($StartYear, 5, 1) },
        @{ Header = "June";     Date = [datetime]::new($StartYear, 6, 1) },
        @{ Header = "July";     Date = [datetime]::new($StartYear, 7, 1) },
        @{ Header = "August";   Date = [datetime]::new($StartYear, 8, 1) },
        @{ Header = "September";Date = [datetime]::new($StartYear, 9, 1) },
        @{ Header = "October";  Date = [datetime]::new($StartYear, 10, 1) },
        @{ Header = "November"; Date = [datetime]::new($StartYear, 11, 1) },
        @{ Header = "December"; Date = [datetime]::new($StartYear, 12, 1) },
        @{ Header = "January";  Date = [datetime]::new($StartYear + 1, 1, 1) },
        @{ Header = "February"; Date = [datetime]::new($StartYear + 1, 2, 1) },
        @{ Header = "March";    Date = [datetime]::new($StartYear + 1, 3, 1) },
        @{ Header = "MaQh";     Date = [datetime]::new($StartYear + 1, 3, 1) }
    )
}

function New-ParentDirectory {
    param([string]$Path)
    $parent = Split-Path -Path $Path -Parent
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
}

function New-StgRow {
    param(
        [string]$ChannelCode,
        [datetime]$DataMonth,
        [string]$BiSalesCode,
        [string]$SalesmanCode,
        [string]$ProductCode,
        [decimal]$ActualAmount,
        [int]$RawRowNo,
        [string]$SourceSheet
    )

    $batchMonth = $DataMonth.ToString("yyyyMM")
    [pscustomobject]@{
        batch_id       = "BATCH-BI-$ChannelCode-$batchMonth-SHEET"
        source_system  = "BI"
        data_month     = $DataMonth.ToString("yyyy-MM-01")
        channel_code   = $ChannelCode
        bi_sales_code  = $BiSalesCode
        salesman_code  = $SalesmanCode
        product_code   = $ProductCode
        actual_amount  = [decimal]::Round($ActualAmount, 2)
        actual_qty     = $null
        raw_row_no     = $RawRowNo
        status         = "PROCESSED"
        source_sheet   = $SourceSheet
    }
}

function Convert-MtActual {
    param(
        [string]$Path,
        [hashtable]$MonthMap,
        [bool]$KeepZero
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "MT Actual file not found: $Path"
    }

    $rows = Import-Csv -LiteralPath $Path
    $result = New-Object System.Collections.Generic.List[object]
    $rawRowNo = 0

    foreach ($row in $rows) {
        $rawRowNo++
        $biCode = $row.'Salesman BI'
        if ([string]::IsNullOrWhiteSpace($biCode)) {
            $biCode = $row.'Salesman Code'
        }

        $product = $row.'Product Group'
        if ([string]::IsNullOrWhiteSpace($biCode) -or [string]::IsNullOrWhiteSpace($product)) {
            continue
        }

        foreach ($header in @("April","May","June","July","August","September","October","November","December","January","February","March")) {
            if (-not $MonthMap.ContainsKey($header)) {
                continue
            }

            $rawValue = Get-ColumnValue -Row $row -ColumnName $header
            $value = ConvertTo-Decimal -Value $rawValue
            if ($null -eq $value) {
                continue
            }

            if ((-not $KeepZero) -and $value -eq 0) {
                continue
            }

            $sheetSalesmanCode = $row.'Salesman Code'
            $result.Add((New-StgRow -ChannelCode "MT" -DataMonth $MonthMap[$header] -BiSalesCode $biCode -SalesmanCode $sheetSalesmanCode -ProductCode $product -ActualAmount $value -RawRowNo $rawRowNo -SourceSheet "MT:Actual"))
        }
    }

    return $result
}

function Convert-TtActual {
    param(
        [string]$Path,
        [hashtable]$MonthMap,
        [bool]$KeepZero
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "TT Actual file not found: $Path"
    }

    $rows = Import-Csv -LiteralPath $Path
    $result = New-Object System.Collections.Generic.List[object]
    $rawRowNo = 0

    foreach ($row in $rows) {
        $rawRowNo++
        $salesman = $row.'Salesman Code'
        $product = $row.'Product'

        if ([string]::IsNullOrWhiteSpace($salesman) -or [string]::IsNullOrWhiteSpace($product)) {
            continue
        }

        foreach ($header in @("April","May","June","July","August","September","October","November","December","January","February","March","MaQh")) {
            if (-not $MonthMap.ContainsKey($header)) {
                continue
            }

            $rawValue = Get-ColumnValue -Row $row -ColumnName $header
            $value = ConvertTo-Decimal -Value $rawValue
            if ($null -eq $value) {
                continue
            }

            if ((-not $KeepZero) -and $value -eq 0) {
                continue
            }

            $result.Add((New-StgRow -ChannelCode "TT" -DataMonth $MonthMap[$header] -BiSalesCode $null -SalesmanCode $salesman -ProductCode $product -ActualAmount $value -RawRowNo $rawRowNo -SourceSheet "TT:Actual"))
        }
    }

    return $result
}

function Write-StgToDatabase {
    param(
        [object[]]$Rows,
        [string]$ConnString
    )

    if ([string]::IsNullOrWhiteSpace($ConnString)) {
        throw "ConnectionString is required when -LoadToDatabase is specified"
    }

    $dataTable = New-Object System.Data.DataTable
    $null = $dataTable.Columns.Add("batch_id", [string])
    $null = $dataTable.Columns.Add("source_system", [string])
    $null = $dataTable.Columns.Add("data_month", [datetime])
    $null = $dataTable.Columns.Add("channel_code", [string])
    $null = $dataTable.Columns.Add("bi_sales_code", [string])
    $null = $dataTable.Columns.Add("salesman_code", [string])
    $null = $dataTable.Columns.Add("product_code", [string])
    $null = $dataTable.Columns.Add("actual_amount", [decimal])
    $null = $dataTable.Columns.Add("actual_qty", [decimal])
    $null = $dataTable.Columns.Add("raw_row_no", [int])
    $null = $dataTable.Columns.Add("status", [string])

    foreach ($r in $Rows) {
        $dr = $dataTable.NewRow()
        $dr["batch_id"] = $r.batch_id
        $dr["source_system"] = $r.source_system
        $dr["data_month"] = [datetime]::ParseExact($r.data_month, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
        $dr["channel_code"] = $r.channel_code
        $dr["bi_sales_code"] = if ([string]::IsNullOrWhiteSpace($r.bi_sales_code)) { [DBNull]::Value } else { $r.bi_sales_code }
        $dr["salesman_code"] = if ([string]::IsNullOrWhiteSpace($r.salesman_code)) { [DBNull]::Value } else { $r.salesman_code }
        $dr["product_code"] = $r.product_code
        $dr["actual_amount"] = $r.actual_amount
        $dr["actual_qty"] = [DBNull]::Value
        $dr["raw_row_no"] = $r.raw_row_no
        $dr["status"] = $r.status
        $dataTable.Rows.Add($dr)
    }

    $connection = New-Object System.Data.SqlClient.SqlConnection($ConnString)
    $connection.Open()

    try {
        $batchIds = $Rows | Select-Object -ExpandProperty batch_id -Unique
        if ($batchIds.Count -gt 0) {
            $deleteCmd = $connection.CreateCommand()
            $paramNames = New-Object System.Collections.Generic.List[string]

            for ($i = 0; $i -lt $batchIds.Count; $i++) {
                $paramName = "@b$i"
                $null = $paramNames.Add($paramName)
                $null = $deleteCmd.Parameters.AddWithValue($paramName, $batchIds[$i])
            }

            $deleteCmd.CommandText = "DELETE FROM dbo.stg_bi_sales WHERE batch_id IN (" + ($paramNames -join ",") + ")"
            $deleteCmd.CommandTimeout = 0
            [void]$deleteCmd.ExecuteNonQuery()
        }

        $bulk = New-Object System.Data.SqlClient.SqlBulkCopy($connection)
        $bulk.DestinationTableName = "dbo.stg_bi_sales"
        $bulk.BatchSize = 5000
        $bulk.BulkCopyTimeout = 0

        foreach ($col in @("batch_id","source_system","data_month","channel_code","bi_sales_code","salesman_code","product_code","actual_amount","actual_qty","raw_row_no","status")) {
            $null = $bulk.ColumnMappings.Add($col, $col)
        }

        $bulk.WriteToServer($dataTable)
    }
    finally {
        if ($bulk) { $bulk.Close() }
        $connection.Close()
    }
}

function Invoke-UpsertTrnSalesActual {
    param([string]$ConnString)

    $sqlPath = "environment/ddl/07_upsert_trn_sales_actual_from_stg.sql"
    if (-not (Test-Path -LiteralPath $sqlPath)) {
        throw "Upsert SQL file not found: $sqlPath"
    }

    $sql = Get-Content -LiteralPath $sqlPath -Raw
    $connection = New-Object System.Data.SqlClient.SqlConnection($ConnString)
    $connection.Open()

    try {
        $cmd = $connection.CreateCommand()
        $cmd.CommandText = $sql
        $cmd.CommandTimeout = 0
        [void]$cmd.ExecuteNonQuery()
    }
    finally {
        $connection.Close()
    }
}

$monthMap = @{}
foreach ($m in (Get-MonthMap -StartYear $FiscalStartYear)) {
    $monthMap[$m.Header] = $m.Date
}

$allRows = New-Object System.Collections.Generic.List[object]
$allRows.AddRange((Convert-MtActual -Path $MtActualPath -MonthMap $monthMap -KeepZero:$IncludeZero.IsPresent))
$allRows.AddRange((Convert-TtActual -Path $TtActualPath -MonthMap $monthMap -KeepZero:$IncludeZero.IsPresent))

New-ParentDirectory -Path $OutputCsv
$allRows | Sort-Object channel_code, data_month, bi_sales_code, salesman_code, product_code, raw_row_no |
    Export-Csv -LiteralPath $OutputCsv -NoTypeInformation -Encoding UTF8

Write-Host "Exported rows to $OutputCsv"
Write-Host ("Total rows: " + $allRows.Count)
Write-Host ("MT rows: " + (($allRows | Where-Object { $_.channel_code -eq 'MT' }).Count))
Write-Host ("TT rows: " + (($allRows | Where-Object { $_.channel_code -eq 'TT' }).Count))

if ($LoadToDatabase.IsPresent) {
    Write-StgToDatabase -Rows $allRows -ConnString $ConnectionString
    Write-Host "Inserted rows into dbo.stg_bi_sales"

    if ($UpsertTrn.IsPresent) {
        Invoke-UpsertTrnSalesActual -ConnString $ConnectionString
        Write-Host "Executed upsert into dbo.trn_sales_actual"
    }
}
