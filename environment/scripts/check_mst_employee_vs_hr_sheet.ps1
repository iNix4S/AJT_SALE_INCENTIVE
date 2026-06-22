function Get-UniqueHeaderRows {
    param([string]$Path)

    $lines = Get-Content -LiteralPath $Path
    if ($lines.Count -lt 2) { return @() }

    $raw = $lines[0].Split(',')
    $seen = @{}
    $headers = foreach ($h in $raw) {
        $n = $h.Trim()
        if ([string]::IsNullOrWhiteSpace($n)) { $n = 'col' }

        if ($seen.ContainsKey($n)) {
            $seen[$n] += 1
            "$n`_$($seen[$n])"
        }
        else {
            $seen[$n] = 1
            $n
        }
    }

    return ($lines | Select-Object -Skip 1 | ConvertFrom-Csv -Header $headers)
}

function Get-SheetCodes {
    param([object[]]$Rows)

    $set = New-Object 'System.Collections.Generic.HashSet[string]'

    foreach ($r in $Rows) {
        $code = $null
        if ($r.PSObject.Properties['EmpCode']) {
            $code = [string]$r.EmpCode
        }

        if ([string]::IsNullOrWhiteSpace($code)) { continue }

        $code = $code.Trim()
        if ($code -eq '#N/A' -or $code -eq '0') { continue }

        [void]$set.Add($code)
    }

    return $set
}

$mtRows = Get-UniqueHeaderRows -Path '4.System Analyst and Design/01.Raw-Extracts/MT/17_HR Rep.values.csv'
$ttRows = Get-UniqueHeaderRows -Path '4.System Analyst and Design/01.Raw-Extracts/TT/14_HR Rep.values.csv'

$mtSheet = Get-SheetCodes -Rows $mtRows
$ttSheet = Get-SheetCodes -Rows $ttRows

$line = Get-Content 'environment/database-dev.env' | Where-Object { $_ -match '^DB_CONNECTION_STRING=' } | Select-Object -First 1
$conn = $line.Substring('DB_CONNECTION_STRING='.Length)
$cn = New-Object System.Data.SqlClient.SqlConnection($conn)
$cn.Open()

try {
    $sql = @"
SELECT c.channel_code, e.employee_code
FROM dbo.mst_employee e
JOIN dbo.mst_channel c ON c.channel_id = e.channel_id
WHERE c.channel_code IN ('MT','TT')
"@

    $cmd = $cn.CreateCommand()
    $cmd.CommandText = $sql

    $da = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
    $dt = New-Object System.Data.DataTable
    [void]$da.Fill($dt)

    $mtDb = New-Object 'System.Collections.Generic.HashSet[string]'
    $ttDb = New-Object 'System.Collections.Generic.HashSet[string]'

    foreach ($row in $dt.Rows) {
        $cc = $row['channel_code'].ToString().Trim()
        $ec = $row['employee_code'].ToString().Trim()

        if ([string]::IsNullOrWhiteSpace($ec)) { continue }

        if ($cc -eq 'MT') { [void]$mtDb.Add($ec) }
        if ($cc -eq 'TT') { [void]$ttDb.Add($ec) }
    }

    $missingMt = @()
    foreach ($k in $mtSheet) {
        if (-not $mtDb.Contains($k)) { $missingMt += $k }
    }

    $missingTt = @()
    foreach ($k in $ttSheet) {
        if (-not $ttDb.Contains($k)) { $missingTt += $k }
    }

    $extraMt = @()
    foreach ($k in $mtDb) {
        if (-not $mtSheet.Contains($k)) { $extraMt += $k }
    }

    $extraTt = @()
    foreach ($k in $ttDb) {
        if (-not $ttSheet.Contains($k)) { $extraTt += $k }
    }

    Write-Output ('SHEET_MT_EMP_CODES=' + $mtSheet.Count)
    Write-Output ('DB_MT_EMP_CODES=' + $mtDb.Count)
    Write-Output ('MISSING_MT=' + $missingMt.Count)
    Write-Output ('EXTRA_MT=' + $extraMt.Count)
    Write-Output ('SAMPLE_MISSING_MT=' + (($missingMt | Sort-Object | Select-Object -First 10) -join ';'))
    Write-Output ('SAMPLE_EXTRA_MT=' + (($extraMt | Sort-Object | Select-Object -First 10) -join ';'))
    Write-Output ''
    Write-Output ('SHEET_TT_EMP_CODES=' + $ttSheet.Count)
    Write-Output ('DB_TT_EMP_CODES=' + $ttDb.Count)
    Write-Output ('MISSING_TT=' + $missingTt.Count)
    Write-Output ('EXTRA_TT=' + $extraTt.Count)
    Write-Output ('SAMPLE_MISSING_TT=' + (($missingTt | Sort-Object | Select-Object -First 10) -join ';'))
    Write-Output ('SAMPLE_EXTRA_TT=' + (($extraTt | Sort-Object | Select-Object -First 10) -join ';'))
}
finally {
    $cn.Close()
}
