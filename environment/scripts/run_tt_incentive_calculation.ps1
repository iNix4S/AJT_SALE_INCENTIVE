param(
    [string[]]$PeriodCodes = @('FY2026-04','FY2026-05'),
    [string]$WsType = 'TOP_WS',
    [string]$ApprovedBy = 'system',
    [string]$ConnectionString
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

$ddlPaths = @(
    'environment/ddl/19_create_tt_formula_matrix_option_band_and_special_kpi.sql',
    'environment/ddl/15_create_proc_run_tt_incentive_calculation.sql'
)

foreach ($ddlPath in $ddlPaths) {
    if (-not (Test-Path -LiteralPath $ddlPath)) {
        throw "DDL file not found: $ddlPath"
    }
}

$cn = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
$cn.Open()

try {
    foreach ($ddlPath in $ddlPaths) {
        $sqlText = Get-Content -LiteralPath $ddlPath -Raw
        $batches = [regex]::Split($sqlText, '(?im)^\s*GO\s*\r?\n')
        foreach ($b in $batches) {
            if ([string]::IsNullOrWhiteSpace($b)) { continue }
            $cmd = $cn.CreateCommand()
            $cmd.CommandTimeout = 0
            $cmd.CommandText = $b
            [void]$cmd.ExecuteNonQuery()
        }
    }

    'TT_CALC_PROC_DEPLOYED=1'

    foreach ($period in $PeriodCodes) {
        $exec = $cn.CreateCommand()
        $exec.CommandTimeout = 0
        $exec.CommandText = @"
EXEC dbo.usp_run_tt_incentive_calculation
     @PeriodCode = @period_code,
     @WsType = @ws_type,
     @ApprovedBy = @approved_by;
"@
        [void]$exec.Parameters.AddWithValue('@period_code', $period)
        [void]$exec.Parameters.AddWithValue('@ws_type', $WsType)
        [void]$exec.Parameters.AddWithValue('@approved_by', $ApprovedBy)

        $da = New-Object System.Data.SqlClient.SqlDataAdapter($exec)
        $dt = New-Object System.Data.DataTable
        [void]$da.Fill($dt)

        "TT_CALC_PERIOD=$period"
        $dt | Format-Table -AutoSize | Out-String
    }
}
finally {
    $cn.Close()
}
