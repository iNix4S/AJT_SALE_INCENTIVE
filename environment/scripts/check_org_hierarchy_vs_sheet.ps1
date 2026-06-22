function Get-AstRows($path) {
    $lines = Get-Content $path
    if ($lines.Count -lt 2) { return @() }

    $rawHeaders = $lines[0].Split(',')
    $seen = @{}
    $headers = foreach ($h in $rawHeaders) {
        $name = $h.Trim()
        if ([string]::IsNullOrWhiteSpace($name)) { $name = 'col' }
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

function Convert-MonthNameToNumber($monthName) {
    switch ($monthName.ToLower()) {
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

function Get-SheetKeys($rows) {
    $keys = New-Object 'System.Collections.Generic.HashSet[string]'

    foreach ($r in $rows) {
        $monthName = [string]$r.'เดือน'
        $yearText = [string]$r.'ปี'
        $salesmanCode = [string]$r.'Salesman Code_2'

        if ([string]::IsNullOrWhiteSpace($salesmanCode) -or $salesmanCode -eq '#N/A' -or $salesmanCode -eq '0') {
            continue
        }

        $monthNo = Convert-MonthNameToNumber $monthName
        if ($null -eq $monthNo) { continue }

        $yearNo = 0
        if (-not [int]::TryParse($yearText, [ref]$yearNo)) { continue }

        $dt = Get-Date -Year $yearNo -Month $monthNo -Day 1
        $null = $keys.Add(($dt.ToString('yyyy-MM-01') + '|' + $salesmanCode.Trim()))
    }

    return $keys
}

$mtRows = Get-AstRows '4.System Analyst and Design/01.Raw-Extracts/MT/11_ASTBase.values.csv'
$ttRows = Get-AstRows '4.System Analyst and Design/01.Raw-Extracts/TT/13_ASTBase.values.csv'

$mtSheetKeys = Get-SheetKeys $mtRows
$ttSheetKeys = Get-SheetKeys $ttRows

Write-Output ('SHEET_MT_KEYS=' + $mtSheetKeys.Count)
Write-Output ('SHEET_TT_KEYS=' + $ttSheetKeys.Count)

$conn = (Get-Content 'environment/database-dev.env' | Where-Object { $_ -like 'DB_CONNECTION_STRING=*' } | Select-Object -First 1).Split('=', 2)[1]
$cn = New-Object System.Data.SqlClient.SqlConnection($conn)
$cn.Open()

try {
    $sql = @"
SELECT c.channel_code, CONVERT(varchar(10), h.effective_month, 23) AS effective_month, h.salesman_code
FROM dbo.mst_org_hierarchy h
JOIN dbo.mst_channel c ON c.channel_id = h.channel_id
WHERE c.channel_code IN ('MT','TT')
"@

    $cmd = $cn.CreateCommand()
    $cmd.CommandText = $sql

    $da = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
    $dt = New-Object System.Data.DataTable
    [void]$da.Fill($dt)

    $mtDbKeys = New-Object 'System.Collections.Generic.HashSet[string]'
    $ttDbKeys = New-Object 'System.Collections.Generic.HashSet[string]'

    foreach ($row in $dt.Rows) {
        $key = ($row['effective_month'].ToString() + '|' + $row['salesman_code'].ToString().Trim())
        if ($row['channel_code'].ToString() -eq 'MT') { $null = $mtDbKeys.Add($key) }
        if ($row['channel_code'].ToString() -eq 'TT') { $null = $ttDbKeys.Add($key) }
    }

    Write-Output ('DB_MT_KEYS=' + $mtDbKeys.Count)
    Write-Output ('DB_TT_KEYS=' + $ttDbKeys.Count)

    $missingMt = @()
    foreach ($k in $mtSheetKeys) {
        if (-not $mtDbKeys.Contains($k)) { $missingMt += $k }
    }

    $missingTt = @()
    foreach ($k in $ttSheetKeys) {
        if (-not $ttDbKeys.Contains($k)) { $missingTt += $k }
    }

    Write-Output ('MISSING_MT_KEYS=' + $missingMt.Count)
    Write-Output ('MISSING_TT_KEYS=' + $missingTt.Count)
    Write-Output ('SAMPLE_MISSING_MT=' + (($missingMt | Select-Object -First 5) -join ';'))
    Write-Output ('SAMPLE_MISSING_TT=' + (($missingTt | Select-Object -First 5) -join ';'))
}
finally {
    $cn.Close()
}
