param(
    [string]$ConnectionString,
    [string]$SqlFilePath = "environment/ddl/08_reconciliation_actual_sheet_vs_stg_trn_audit.sql",
    [string]$OutputDir = "environment/generated/reconciliation"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ConnectionString)) {
    throw "ConnectionString is required"
}

if (-not (Test-Path -LiteralPath $SqlFilePath)) {
    throw "SQL file not found: $SqlFilePath"
}

if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$sql = Get-Content -LiteralPath $SqlFilePath -Raw
$cn = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
$cn.Open()

try {
    $cmd = $cn.CreateCommand()
    $cmd.CommandText = $sql
    $cmd.CommandTimeout = 0

    $da = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
    $ds = New-Object System.Data.DataSet
    [void]$da.Fill($ds)

    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmss")

    $summaryPath = Join-Path $OutputDir ("reconciliation_summary_{0}.csv" -f $timestamp)
    $gapDetailPath = Join-Path $OutputDir ("reconciliation_mt_gap_detail_{0}.csv" -f $timestamp)
    $gapMonthlyPath = Join-Path $OutputDir ("reconciliation_mt_gap_monthly_{0}.csv" -f $timestamp)

    if ($ds.Tables.Count -gt 0) {
        $ds.Tables[0] | Export-Csv -LiteralPath $summaryPath -NoTypeInformation -Encoding UTF8
    }

    if ($ds.Tables.Count -gt 1) {
        $ds.Tables[1] | Export-Csv -LiteralPath $gapDetailPath -NoTypeInformation -Encoding UTF8
    }

    if ($ds.Tables.Count -gt 2) {
        $ds.Tables[2] | Export-Csv -LiteralPath $gapMonthlyPath -NoTypeInformation -Encoding UTF8
    }

    Write-Host "Generated reconciliation reports:"
    Write-Host "- $summaryPath"
    Write-Host "- $gapDetailPath"
    Write-Host "- $gapMonthlyPath"
}
finally {
    $cn.Close()
}
