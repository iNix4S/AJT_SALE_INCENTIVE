param(
    [string]$MtMappingPath = "4.System Analyst and Design/01.Raw-Extracts/MT/19_Mapping.values.csv",
    [string]$MtActualPath = "4.System Analyst and Design/01.Raw-Extracts/MT/18_Actual.values.csv",
    [int]$FiscalStartYear = 2026,
    [string]$ConnectionString,
    [string]$OutputConflictCsv = "environment/generated/mapping_conflicts_from_sheet.csv"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ConvertTo-NullableDecimal {
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

function Get-ValueByColumn {
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

function Get-FiscalMonths {
    param([int]$StartYear)

    return @(
        @{ Header = "April"; Date = [datetime]::new($StartYear, 4, 1) },
        @{ Header = "May"; Date = [datetime]::new($StartYear, 5, 1) },
        @{ Header = "June"; Date = [datetime]::new($StartYear, 6, 1) },
        @{ Header = "July"; Date = [datetime]::new($StartYear, 7, 1) },
        @{ Header = "August"; Date = [datetime]::new($StartYear, 8, 1) },
        @{ Header = "September"; Date = [datetime]::new($StartYear, 9, 1) },
        @{ Header = "October"; Date = [datetime]::new($StartYear, 10, 1) },
        @{ Header = "November"; Date = [datetime]::new($StartYear, 11, 1) },
        @{ Header = "December"; Date = [datetime]::new($StartYear, 12, 1) },
        @{ Header = "January"; Date = [datetime]::new($StartYear + 1, 1, 1) },
        @{ Header = "February"; Date = [datetime]::new($StartYear + 1, 2, 1) },
        @{ Header = "March"; Date = [datetime]::new($StartYear + 1, 3, 1) }
    )
}

function New-MappingEntry {
    param(
        [datetime]$EffectiveMonth,
        [string]$BiSalesCode,
        [string]$ProductGroupCode,
        [string]$SalesmanCode,
        [string]$Source
    )

    [pscustomobject]@{
        effective_month = $EffectiveMonth.ToString("yyyy-MM-01")
        bi_sales_code = $BiSalesCode.Trim()
        product_group_code = $ProductGroupCode.Trim()
        salesman_code = $SalesmanCode.Trim()
        source = $Source
    }
}

function Add-MappingWithPriority {
    param(
        [System.Collections.Generic.Dictionary[string,object]]$MapDict,
        [System.Collections.Generic.List[object]]$ConflictList,
        [pscustomobject]$Entry
    )

    $key = "{0}|{1}|{2}" -f $Entry.effective_month, $Entry.bi_sales_code, $Entry.product_group_code

    if (-not $MapDict.ContainsKey($key)) {
        $MapDict[$key] = $Entry
        return
    }

    $existing = $MapDict[$key]
    if ($existing.salesman_code -eq $Entry.salesman_code) {
        return
    }

    $existingPriority = if ($existing.source -eq "MAPPING_SHEET") { 2 } else { 1 }
    $newPriority = if ($Entry.source -eq "MAPPING_SHEET") { 2 } else { 1 }

    $ConflictList.Add([pscustomobject]@{
        effective_month = $Entry.effective_month
        bi_sales_code = $Entry.bi_sales_code
        product_group_code = $Entry.product_group_code
        existing_salesman_code = $existing.salesman_code
        existing_source = $existing.source
        incoming_salesman_code = $Entry.salesman_code
        incoming_source = $Entry.source
        resolved_salesman_code = if ($newPriority -ge $existingPriority) { $Entry.salesman_code } else { $existing.salesman_code }
    })

    if ($newPriority -ge $existingPriority) {
        $MapDict[$key] = $Entry
    }
}

if ([string]::IsNullOrWhiteSpace($ConnectionString)) {
    throw "ConnectionString is required"
}

if (-not (Test-Path -LiteralPath $MtMappingPath)) {
    throw "Mapping sheet file not found: $MtMappingPath"
}

if (-not (Test-Path -LiteralPath $MtActualPath)) {
    throw "Actual sheet file not found: $MtActualPath"
}

$months = Get-FiscalMonths -StartYear $FiscalStartYear
$mapDict = New-Object 'System.Collections.Generic.Dictionary[string,object]'
$conflicts = New-Object 'System.Collections.Generic.List[object]'

# 1) Import explicit mapping sheet rows and apply to all fiscal months
$mappingRows = Import-Csv -LiteralPath $MtMappingPath
foreach ($row in $mappingRows) {
    $bi = Get-ValueByColumn -Row $row -ColumnName 'SalesCode_BI'
    $product = Get-ValueByColumn -Row $row -ColumnName 'Product Group'
    $salesman = Get-ValueByColumn -Row $row -ColumnName 'Salesman Code'

    if ([string]::IsNullOrWhiteSpace($bi) -or [string]::IsNullOrWhiteSpace($product) -or [string]::IsNullOrWhiteSpace($salesman)) {
        continue
    }

    foreach ($m in $months) {
        $entry = New-MappingEntry -EffectiveMonth $m.Date -BiSalesCode $bi -ProductGroupCode $product -SalesmanCode $salesman -Source "MAPPING_SHEET"
        Add-MappingWithPriority -MapDict $mapDict -ConflictList $conflicts -Entry $entry
    }
}

# 2) Infer mapping from MT Actual sheet (month-aware)
$actualRows = Import-Csv -LiteralPath $MtActualPath
foreach ($row in $actualRows) {
    $salesmanCode = Get-ValueByColumn -Row $row -ColumnName 'Salesman Code'
    $biSalesCode = Get-ValueByColumn -Row $row -ColumnName 'Salesman BI'
    $productGroup = Get-ValueByColumn -Row $row -ColumnName 'Product Group'

    if ([string]::IsNullOrWhiteSpace($salesmanCode) -or [string]::IsNullOrWhiteSpace($productGroup)) {
        continue
    }

    if ([string]::IsNullOrWhiteSpace($biSalesCode)) {
        $biSalesCode = $salesmanCode
    }

    foreach ($m in $months) {
        $rawValue = Get-ValueByColumn -Row $row -ColumnName $m.Header
        $amount = ConvertTo-NullableDecimal -Value $rawValue
        if ($null -eq $amount) {
            continue
        }

        $entry = New-MappingEntry -EffectiveMonth $m.Date -BiSalesCode $biSalesCode -ProductGroupCode $productGroup -SalesmanCode $salesmanCode -Source "ACTUAL_SHEET"
        Add-MappingWithPriority -MapDict $mapDict -ConflictList $conflicts -Entry $entry
    }
}

if ($conflicts.Count -gt 0) {
    $parent = Split-Path -Path $OutputConflictCsv -Parent
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $conflicts | Export-Csv -LiteralPath $OutputConflictCsv -NoTypeInformation -Encoding UTF8
}

# Prepare DB write
$cn = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
$cn.Open()

try {
    $tx = $cn.BeginTransaction()

    try {
        $getMtChannel = $cn.CreateCommand()
        $getMtChannel.Transaction = $tx
        $getMtChannel.CommandText = "SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'MT'"
        $channelIdObj = $getMtChannel.ExecuteScalar()

        if ($null -eq $channelIdObj -or $channelIdObj -is [System.DBNull]) {
            throw "channel_code MT not found in mst_channel"
        }

        $mtChannelId = [int]$channelIdObj

        $mergeSql = @"
MERGE dbo.mst_salesman_mapping AS tgt
USING (
    SELECT
        @channel_id AS channel_id,
        @effective_month AS effective_month,
        @bi_sales_code AS bi_sales_code,
        @product_group_code AS product_group_code,
        @salesman_code AS salesman_code
) AS src
ON tgt.channel_id = src.channel_id
AND tgt.effective_month = src.effective_month
AND tgt.bi_sales_code = src.bi_sales_code
AND tgt.product_group_code = src.product_group_code
WHEN MATCHED THEN
    UPDATE SET
        tgt.salesman_code = src.salesman_code,
        tgt.is_active = 1,
        tgt.updated_at = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (
        channel_id,
        effective_month,
        bi_sales_code,
        product_group_code,
        salesman_code,
        is_active
    )
    VALUES (
        src.channel_id,
        src.effective_month,
        src.bi_sales_code,
        src.product_group_code,
        src.salesman_code,
        1
    );
"@

        $upsert = $cn.CreateCommand()
        $upsert.Transaction = $tx
        $upsert.CommandText = $mergeSql
        $upsert.CommandTimeout = 0

        $null = $upsert.Parameters.Add("@channel_id", [System.Data.SqlDbType]::Int)
        $null = $upsert.Parameters.Add("@effective_month", [System.Data.SqlDbType]::Date)
        $null = $upsert.Parameters.Add("@bi_sales_code", [System.Data.SqlDbType]::NVarChar, 50)
        $null = $upsert.Parameters.Add("@product_group_code", [System.Data.SqlDbType]::NVarChar, 50)
        $null = $upsert.Parameters.Add("@salesman_code", [System.Data.SqlDbType]::NVarChar, 50)

        $records = $mapDict.Values | Sort-Object effective_month, bi_sales_code, product_group_code
        foreach ($r in $records) {
            $upsert.Parameters["@channel_id"].Value = $mtChannelId
            $upsert.Parameters["@effective_month"].Value = [datetime]::ParseExact($r.effective_month, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
            $upsert.Parameters["@bi_sales_code"].Value = $r.bi_sales_code
            $upsert.Parameters["@product_group_code"].Value = $r.product_group_code
            $upsert.Parameters["@salesman_code"].Value = $r.salesman_code
            [void]$upsert.ExecuteNonQuery()
        }

        $tx.Commit()

        Write-Host ("Loaded/updated mapping rows: " + $records.Count)
        Write-Host ("Conflict rows detected: " + $conflicts.Count)
        if ($conflicts.Count -gt 0) {
            Write-Host ("Conflict report: " + $OutputConflictCsv)
        }
    }
    catch {
        $tx.Rollback()
        throw
    }
}
finally {
    $cn.Close()
}
