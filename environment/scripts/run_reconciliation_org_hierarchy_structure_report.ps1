param(
    [string]$MtAstBasePath = "4.System Analyst and Design/01.Raw-Extracts/MT/11_ASTBase.values.csv",
    [string]$TtAstBasePath = "4.System Analyst and Design/01.Raw-Extracts/TT/13_ASTBase.values.csv",
    [string]$ConnectionString,
    [string]$OutputDir = "environment/generated/reconciliation"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-ConnectionStringFromEnv {
    param([string]$EnvFilePath)

    if (-not (Test-Path -LiteralPath $EnvFilePath)) {
        throw "Env file not found: $EnvFilePath"
    }

    $line = Get-Content -LiteralPath $EnvFilePath | Where-Object { $_ -match '^DB_CONNECTION_STRING=' } | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($line)) {
        throw "DB_CONNECTION_STRING not found in $EnvFilePath"
    }

    return $line.Substring('DB_CONNECTION_STRING='.Length)
}

function Get-AstRowsWithUniqueHeaders {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "ASTBase file not found: $Path"
    }

    $lines = Get-Content -LiteralPath $Path
    if ($lines.Count -lt 2) {
        return @()
    }

    $rawHeaders = $lines[0].Split(',')
    $seen = @{}
    $headers = foreach ($h in $rawHeaders) {
        $name = $h.Trim()
        if ([string]::IsNullOrWhiteSpace($name)) {
            $name = 'col'
        }

        if ($seen.ContainsKey($name)) {
            $seen[$name] += 1
            "$name`_$($seen[$name])"
        }
        else {
            $seen[$name] = 1
            $name
        }
    }

    return ($lines | Select-Object -Skip 1 | ConvertFrom-Csv -Header $headers)
}

function Get-PropertyValue {
    param(
        [psobject]$Row,
        [string[]]$CandidateNames
    )

    foreach ($name in $CandidateNames) {
        $prop = $Row.PSObject.Properties[$name]
        if ($null -ne $prop) {
            return [string]$prop.Value
        }
    }

    return $null
}

function ConvertTo-NormalizedCode {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    $trimmed = $Value.Trim()
    if ($trimmed -eq '#N/A' -or $trimmed -eq '0') {
        return $null
    }

    return $trimmed
}

function ConvertTo-MonthNumber {
    param([string]$MonthName)

    if ([string]::IsNullOrWhiteSpace($MonthName)) {
        return $null
    }

    switch ($MonthName.Trim().ToLower()) {
        'january' { return 1 }
        'february' { return 2 }
        'march' { return 3 }
        'april' { return 4 }
        'may' { return 5 }
        'june' { return 6 }
        'july' { return 7 }
        'august' { return 8 }
        'september' { return 9 }
        'october' { return 10 }
        'november' { return 11 }
        'december' { return 12 }
        default { return $null }
    }
}

function ConvertTo-SheetHierarchyMap {
    param(
        [object[]]$Rows,
        [string]$ChannelCode
    )

    $map = New-Object 'System.Collections.Generic.Dictionary[string,object]'

    foreach ($r in $Rows) {
        $monthName = Get-PropertyValue -Row $r -CandidateNames @('เดือน')
        $yearText = Get-PropertyValue -Row $r -CandidateNames @('ปี')
        $salesmanCode = ConvertTo-NormalizedCode (Get-PropertyValue -Row $r -CandidateNames @('Salesman Code_2', 'Salesman Code'))

        if ([string]::IsNullOrWhiteSpace($salesmanCode)) {
            continue
        }

        $monthNo = ConvertTo-MonthNumber -MonthName $monthName
        if ($null -eq $monthNo) {
            continue
        }

        $yearNo = 0
        if (-not [int]::TryParse($yearText, [ref]$yearNo)) {
            continue
        }

        $effectiveMonth = [datetime]::new($yearNo, $monthNo, 1).ToString('yyyy-MM-01')
        $directSup = ConvertTo-NormalizedCode (Get-PropertyValue -Row $r -CandidateNames @('DirectSupCode'))
        $deptMgr = ConvertTo-NormalizedCode (Get-PropertyValue -Row $r -CandidateNames @('DeptMgrCode', 'DeptMgQode'))
        $divMgr = ConvertTo-NormalizedCode (Get-PropertyValue -Row $r -CandidateNames @('DivMgrCode', 'DivMgQode'))

        $key = "{0}|{1}|{2}" -f $ChannelCode, $effectiveMonth, $salesmanCode

        if ($map.ContainsKey($key)) {
            continue
        }

        $map[$key] = [pscustomobject]@{
            channel_code = $ChannelCode
            effective_month = $effectiveMonth
            salesman_code = $salesmanCode
            direct_sup_code = $directSup
            dept_mgr_code = $deptMgr
            div_mgr_code = $divMgr
        }
    }

    return $map
}

function Get-DbHierarchyMap {
    param([string]$ConnString)

    $cn = New-Object System.Data.SqlClient.SqlConnection($ConnString)
    $cn.Open()

    try {
        $sql = @"
SELECT
    c.channel_code,
    CONVERT(varchar(10), h.effective_month, 23) AS effective_month,
    h.salesman_code,
    h.direct_sup_code,
    h.dept_mgr_code,
    h.div_mgr_code
FROM dbo.mst_org_hierarchy h
JOIN dbo.mst_channel c ON c.channel_id = h.channel_id
WHERE c.channel_code IN ('MT','TT')
"@

        $cmd = $cn.CreateCommand()
        $cmd.CommandText = $sql

        $da = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
        $dt = New-Object System.Data.DataTable
        [void]$da.Fill($dt)

        $map = New-Object 'System.Collections.Generic.Dictionary[string,object]'

        foreach ($row in $dt.Rows) {
            $channelCode = $row['channel_code'].ToString().Trim()
            $effectiveMonth = $row['effective_month'].ToString().Trim()
            $salesmanCode = $row['salesman_code'].ToString().Trim()

            if ([string]::IsNullOrWhiteSpace($channelCode) -or [string]::IsNullOrWhiteSpace($effectiveMonth) -or [string]::IsNullOrWhiteSpace($salesmanCode)) {
                continue
            }

            $key = "{0}|{1}|{2}" -f $channelCode, $effectiveMonth, $salesmanCode

            $directSup = ConvertTo-NormalizedCode $row['direct_sup_code'].ToString()
            $deptMgr = ConvertTo-NormalizedCode $row['dept_mgr_code'].ToString()
            $divMgr = ConvertTo-NormalizedCode $row['div_mgr_code'].ToString()

            if ($map.ContainsKey($key)) {
                continue
            }

            $map[$key] = [pscustomobject]@{
                channel_code = $channelCode
                effective_month = $effectiveMonth
                salesman_code = $salesmanCode
                direct_sup_code = $directSup
                dept_mgr_code = $deptMgr
                div_mgr_code = $divMgr
            }
        }

        return $map
    }
    finally {
        $cn.Close()
    }
}

function New-MonthStat {
    param(
        [string]$ChannelCode,
        [string]$EffectiveMonth
    )

    return [pscustomobject]@{
        channel_code = $ChannelCode
        effective_month = $EffectiveMonth
        sheet_key_count = 0
        db_key_count = 0
        missing_in_db_count = 0
        extra_in_db_count = 0
        direct_sup_mismatch_count = 0
        dept_mgr_mismatch_count = 0
        div_mgr_mismatch_count = 0
        status = 'PASS'
    }
}

function Get-OrCreateMonthStat {
    param(
        [System.Collections.Generic.Dictionary[string,object]]$Stats,
        [string]$ChannelCode,
        [string]$EffectiveMonth
    )

    $monthKey = "{0}|{1}" -f $ChannelCode, $EffectiveMonth
    if (-not $Stats.ContainsKey($monthKey)) {
        $Stats[$monthKey] = New-MonthStat -ChannelCode $ChannelCode -EffectiveMonth $EffectiveMonth
    }

    return $Stats[$monthKey]
}

if ([string]::IsNullOrWhiteSpace($ConnectionString)) {
    $ConnectionString = Get-ConnectionStringFromEnv -EnvFilePath 'environment/database-dev.env'
}

if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$mtRows = Get-AstRowsWithUniqueHeaders -Path $MtAstBasePath
$ttRows = Get-AstRowsWithUniqueHeaders -Path $TtAstBasePath

$sheetMap = New-Object 'System.Collections.Generic.Dictionary[string,object]'
$mtMap = ConvertTo-SheetHierarchyMap -Rows $mtRows -ChannelCode 'MT'
$ttMap = ConvertTo-SheetHierarchyMap -Rows $ttRows -ChannelCode 'TT'

foreach ($k in $mtMap.Keys) { $sheetMap[$k] = $mtMap[$k] }
foreach ($k in $ttMap.Keys) { $sheetMap[$k] = $ttMap[$k] }

$dbMap = Get-DbHierarchyMap -ConnString $ConnectionString

$stats = New-Object 'System.Collections.Generic.Dictionary[string,object]'
$details = New-Object 'System.Collections.Generic.List[object]'

foreach ($k in $sheetMap.Keys) {
    $sheetRec = $sheetMap[$k]
    $monthStat = Get-OrCreateMonthStat -Stats $stats -ChannelCode $sheetRec.channel_code -EffectiveMonth $sheetRec.effective_month
    $monthStat.sheet_key_count += 1

    if (-not $dbMap.ContainsKey($k)) {
        $monthStat.missing_in_db_count += 1
        $details.Add([pscustomobject]@{
            channel_code = $sheetRec.channel_code
            effective_month = $sheetRec.effective_month
            salesman_code = $sheetRec.salesman_code
            issue_type = 'MISSING_IN_DB'
            field_name = ''
            sheet_value = ''
            db_value = ''
        }) | Out-Null
        continue
    }

    $dbRec = $dbMap[$k]

    if ($sheetRec.direct_sup_code -ne $dbRec.direct_sup_code) {
        $monthStat.direct_sup_mismatch_count += 1
        $details.Add([pscustomobject]@{
            channel_code = $sheetRec.channel_code
            effective_month = $sheetRec.effective_month
            salesman_code = $sheetRec.salesman_code
            issue_type = 'FIELD_MISMATCH'
            field_name = 'direct_sup_code'
            sheet_value = if ($null -eq $sheetRec.direct_sup_code) { '' } else { $sheetRec.direct_sup_code }
            db_value = if ($null -eq $dbRec.direct_sup_code) { '' } else { $dbRec.direct_sup_code }
        }) | Out-Null
    }

    if ($sheetRec.dept_mgr_code -ne $dbRec.dept_mgr_code) {
        $monthStat.dept_mgr_mismatch_count += 1
        $details.Add([pscustomobject]@{
            channel_code = $sheetRec.channel_code
            effective_month = $sheetRec.effective_month
            salesman_code = $sheetRec.salesman_code
            issue_type = 'FIELD_MISMATCH'
            field_name = 'dept_mgr_code'
            sheet_value = if ($null -eq $sheetRec.dept_mgr_code) { '' } else { $sheetRec.dept_mgr_code }
            db_value = if ($null -eq $dbRec.dept_mgr_code) { '' } else { $dbRec.dept_mgr_code }
        }) | Out-Null
    }

    if ($sheetRec.div_mgr_code -ne $dbRec.div_mgr_code) {
        $monthStat.div_mgr_mismatch_count += 1
        $details.Add([pscustomobject]@{
            channel_code = $sheetRec.channel_code
            effective_month = $sheetRec.effective_month
            salesman_code = $sheetRec.salesman_code
            issue_type = 'FIELD_MISMATCH'
            field_name = 'div_mgr_code'
            sheet_value = if ($null -eq $sheetRec.div_mgr_code) { '' } else { $sheetRec.div_mgr_code }
            db_value = if ($null -eq $dbRec.div_mgr_code) { '' } else { $dbRec.div_mgr_code }
        }) | Out-Null
    }
}

foreach ($k in $dbMap.Keys) {
    $dbRec = $dbMap[$k]
    $monthStat = Get-OrCreateMonthStat -Stats $stats -ChannelCode $dbRec.channel_code -EffectiveMonth $dbRec.effective_month
    $monthStat.db_key_count += 1

    if (-not $sheetMap.ContainsKey($k)) {
        $monthStat.extra_in_db_count += 1
        $details.Add([pscustomobject]@{
            channel_code = $dbRec.channel_code
            effective_month = $dbRec.effective_month
            salesman_code = $dbRec.salesman_code
            issue_type = 'EXTRA_IN_DB'
            field_name = ''
            sheet_value = ''
            db_value = ''
        }) | Out-Null
    }
}

$summary = $stats.Values | Sort-Object channel_code, effective_month
foreach ($r in $summary) {
    if (
        $r.missing_in_db_count -gt 0 -or
        $r.extra_in_db_count -gt 0 -or
        $r.direct_sup_mismatch_count -gt 0 -or
        $r.dept_mgr_mismatch_count -gt 0 -or
        $r.div_mgr_mismatch_count -gt 0
    ) {
        $r.status = 'CHECK'
    }
}

$timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss')
$summaryPath = Join-Path $OutputDir ("org_hierarchy_structure_reconciliation_summary_{0}.csv" -f $timestamp)
$detailPath = Join-Path $OutputDir ("org_hierarchy_structure_reconciliation_detail_{0}.csv" -f $timestamp)

$summary | Export-Csv -LiteralPath $summaryPath -NoTypeInformation -Encoding UTF8
$details | Sort-Object channel_code, effective_month, salesman_code, issue_type, field_name | Export-Csv -LiteralPath $detailPath -NoTypeInformation -Encoding UTF8

Write-Host 'Generated org hierarchy structure reconciliation reports:'
Write-Host ("- " + $summaryPath)
Write-Host ("- " + $detailPath)
