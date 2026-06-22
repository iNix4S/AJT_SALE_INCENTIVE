param(
    [string]$MtAstBasePath = "4.System Analyst and Design/01.Raw-Extracts/MT/11_ASTBase.values.csv",
    [string]$TtAstBasePath = "4.System Analyst and Design/01.Raw-Extracts/TT/13_ASTBase.values.csv",
    [string]$ConnectionString
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

function Convert-MonthNameToNumber {
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

function New-StagingDataTable {
    $dt = New-Object System.Data.DataTable
    [void]$dt.Columns.Add('channel_code', [string])
    [void]$dt.Columns.Add('effective_month', [datetime])
    [void]$dt.Columns.Add('salesman_code', [string])
    [void]$dt.Columns.Add('direct_sup_code', [string])
    [void]$dt.Columns.Add('dept_mgr_code', [string])
    [void]$dt.Columns.Add('div_mgr_code', [string])
    [void]$dt.Columns.Add('ad_code', [string])
    return $dt
}

function Add-AstRowsToStaging {
    param(
        [System.Data.DataTable]$Staging,
        [object[]]$Rows,
        [string]$ChannelCode
    )

    $dupGuard = New-Object 'System.Collections.Generic.HashSet[string]'

    foreach ($r in $Rows) {
        $monthName = Get-PropertyValue -Row $r -CandidateNames @('เดือน')
        $yearText = Get-PropertyValue -Row $r -CandidateNames @('ปี')
        $salesmanCode = ConvertTo-NormalizedCode (Get-PropertyValue -Row $r -CandidateNames @('Salesman Code_2', 'Salesman Code'))

        if ([string]::IsNullOrWhiteSpace($salesmanCode)) {
            continue
        }

        $monthNo = Convert-MonthNameToNumber -MonthName $monthName
        if ($null -eq $monthNo) {
            continue
        }

        $yearNo = 0
        if (-not [int]::TryParse($yearText, [ref]$yearNo)) {
            continue
        }

        $effectiveMonth = [datetime]::new($yearNo, $monthNo, 1)
        $directSup = ConvertTo-NormalizedCode (Get-PropertyValue -Row $r -CandidateNames @('DirectSupCode'))
        $deptMgr = ConvertTo-NormalizedCode (Get-PropertyValue -Row $r -CandidateNames @('DeptMgrCode', 'DeptMgQode'))
        $divMgr = ConvertTo-NormalizedCode (Get-PropertyValue -Row $r -CandidateNames @('DivMgrCode', 'DivMgQode'))
        $adCode = ConvertTo-NormalizedCode (Get-PropertyValue -Row $r -CandidateNames @('ADCode', 'AdCode'))

        $dedupeKey = "{0}|{1}|{2}" -f $ChannelCode, $effectiveMonth.ToString('yyyy-MM-01'), $salesmanCode
        if (-not $dupGuard.Add($dedupeKey)) {
            continue
        }

        $newRow = $Staging.NewRow()
        $newRow['channel_code'] = $ChannelCode
        $newRow['effective_month'] = $effectiveMonth
        $newRow['salesman_code'] = $salesmanCode
        $newRow['direct_sup_code'] = if ($null -eq $directSup) { [System.DBNull]::Value } else { $directSup }
        $newRow['dept_mgr_code'] = if ($null -eq $deptMgr) { [System.DBNull]::Value } else { $deptMgr }
        $newRow['div_mgr_code'] = if ($null -eq $divMgr) { [System.DBNull]::Value } else { $divMgr }
        $newRow['ad_code'] = if ($null -eq $adCode) { [System.DBNull]::Value } else { $adCode }

        [void]$Staging.Rows.Add($newRow)
    }
}

if ([string]::IsNullOrWhiteSpace($ConnectionString)) {
    $ConnectionString = Get-ConnectionStringFromEnv -EnvFilePath 'environment/database-dev.env'
}

$mtRows = Get-AstRowsWithUniqueHeaders -Path $MtAstBasePath
$ttRows = Get-AstRowsWithUniqueHeaders -Path $TtAstBasePath

$stage = New-StagingDataTable
if ($null -eq $stage) {
    $stage = New-Object System.Data.DataTable
    [void]$stage.Columns.Add('channel_code', [string])
    [void]$stage.Columns.Add('effective_month', [datetime])
    [void]$stage.Columns.Add('salesman_code', [string])
    [void]$stage.Columns.Add('direct_sup_code', [string])
    [void]$stage.Columns.Add('dept_mgr_code', [string])
    [void]$stage.Columns.Add('div_mgr_code', [string])
    [void]$stage.Columns.Add('ad_code', [string])
}
Add-AstRowsToStaging -Staging $stage -Rows $mtRows -ChannelCode 'MT'
Add-AstRowsToStaging -Staging $stage -Rows $ttRows -ChannelCode 'TT'

if ($stage.Rows.Count -eq 0) {
    throw 'No valid ASTBase rows found to load into mst_org_hierarchy'
}

$cn = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
$cn.Open()

try {
    $tx = $cn.BeginTransaction()

    try {
        $createTemp = $cn.CreateCommand()
        $createTemp.Transaction = $tx
        $createTemp.CommandText = @"
CREATE TABLE #org_src (
    channel_code nvarchar(10) NOT NULL,
    effective_month date NOT NULL,
    salesman_code nvarchar(50) NOT NULL,
    direct_sup_code nvarchar(50) NULL,
    dept_mgr_code nvarchar(50) NULL,
    div_mgr_code nvarchar(50) NULL,
    ad_code nvarchar(50) NULL
);
"@
        [void]$createTemp.ExecuteNonQuery()

        $bulk = New-Object System.Data.SqlClient.SqlBulkCopy($cn, [System.Data.SqlClient.SqlBulkCopyOptions]::Default, $tx)
        $bulk.DestinationTableName = '#org_src'
        $bulk.BulkCopyTimeout = 0
        [void]$bulk.ColumnMappings.Add('channel_code', 'channel_code')
        [void]$bulk.ColumnMappings.Add('effective_month', 'effective_month')
        [void]$bulk.ColumnMappings.Add('salesman_code', 'salesman_code')
        [void]$bulk.ColumnMappings.Add('direct_sup_code', 'direct_sup_code')
        [void]$bulk.ColumnMappings.Add('dept_mgr_code', 'dept_mgr_code')
        [void]$bulk.ColumnMappings.Add('div_mgr_code', 'div_mgr_code')
        [void]$bulk.ColumnMappings.Add('ad_code', 'ad_code')
        $bulk.WriteToServer($stage)

        $merge = $cn.CreateCommand()
        $merge.Transaction = $tx
        $merge.CommandTimeout = 0
        $merge.CommandText = @"
;WITH src AS (
    SELECT
        c.channel_id,
        s.effective_month,
        s.salesman_code,
        s.direct_sup_code,
        s.dept_mgr_code,
        s.div_mgr_code,
        s.ad_code
    FROM #org_src s
    JOIN dbo.mst_channel c
        ON c.channel_code = s.channel_code
)
MERGE dbo.mst_org_hierarchy AS tgt
USING src
ON tgt.channel_id = src.channel_id
AND tgt.effective_month = src.effective_month
AND tgt.salesman_code = src.salesman_code
WHEN MATCHED THEN
    UPDATE SET
        tgt.direct_sup_code = src.direct_sup_code,
        tgt.dept_mgr_code = src.dept_mgr_code,
        tgt.div_mgr_code = src.div_mgr_code,
        tgt.ad_code = src.ad_code,
        tgt.is_active = 1,
        tgt.updated_at = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (
        channel_id,
        effective_month,
        salesman_code,
        direct_sup_code,
        dept_mgr_code,
        div_mgr_code,
        ad_code,
        is_active
    )
    VALUES (
        src.channel_id,
        src.effective_month,
        src.salesman_code,
        src.direct_sup_code,
        src.dept_mgr_code,
        src.div_mgr_code,
        src.ad_code,
        1
    );
"@
        [void]$merge.ExecuteNonQuery()

        $tx.Commit()
    }
    catch {
        $tx.Rollback()
        throw
    }
}
finally {
    $cn.Close()
}

Write-Output ("Loaded/Merged rows from ASTBase into mst_org_hierarchy: " + $stage.Rows.Count)
