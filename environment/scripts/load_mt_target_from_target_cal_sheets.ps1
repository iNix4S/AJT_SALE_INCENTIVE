<#
.SYNOPSIS
    Load MT sales targets from all 4 Target & Cal sheets into trn_sales_target.
    Sheets: Staff (13), Sect (14), Dept (15), AD (16).
.NOTES
    Created: 2026-06-22
    Target DB: AJT_SALE_INCENTIVE @ 192.168.11.40
    Channel: MT (channel_id=1)
    FY: Apr 2026 (period 1) through Mar 2027 (period 12)
#>

param(
    [string]$ConnectionString,
    [int]$FiscalStartYear = 2026,
    [string]$ApprovedBy = "sheet_loader_mt"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---- helpers ----------------------------------------------------------------

function Get-ConnectionStringFromEnv {
    param([string]$EnvFilePath)
    $line = Get-Content -LiteralPath $EnvFilePath |
            Where-Object { $_ -match '^DB_CONNECTION_STRING=' } |
            Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($line)) {
        throw "DB_CONNECTION_STRING not found in $EnvFilePath"
    }
    return $line.Substring('DB_CONNECTION_STRING='.Length)
}

function ConvertTo-NullableDecimal {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $raw = $Value.Trim().Replace(',', '')
    if ($raw -eq '#N/A' -or $raw -eq 'N/A') { return $null }
    $num = 0.0
    if ([double]::TryParse($raw, [System.Globalization.NumberStyles]::Float,
            [System.Globalization.CultureInfo]::InvariantCulture, [ref]$num)) {
        return [decimal]$num
    }
    return $null
}

function Get-TargetCalRows {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "CSV not found: $Path" }
    $lines = Get-Content -LiteralPath $Path
    if ($lines.Count -lt 4) { throw "CSV format invalid (< 4 lines): $Path" }

    # Line index 2 (0-based) = actual field header row
    $headerParts = $lines[2].Split(',')
    $nameCount   = @{}
    $colIndex    = 0
    $uniqueHeaders = foreach ($h in $headerParts) {
        $colIndex++
        $name = ([string]$h).Trim().TrimStart([char]0xFEFF)
        if ([string]::IsNullOrWhiteSpace($name)) { $name = "col_$colIndex" }
        if (-not $nameCount.ContainsKey($name)) {
            $nameCount[$name] = 1; $name
        } else {
            $nameCount[$name]++
            "{0}_{1}" -f $name, $nameCount[$name]
        }
    }
    $dataLines   = $lines | Select-Object -Skip 3
    $normalizedCsv = @(($uniqueHeaders -join ',')) + $dataLines
    return ($normalizedCsv | ConvertFrom-Csv)
}

# ---- month → period mapping -------------------------------------------------
$monthCols = @(
    @{ Col = "Apr_T"; PeriodId = 1;  Date = [datetime]::new($FiscalStartYear,     4, 1) },
    @{ Col = "May_T"; PeriodId = 2;  Date = [datetime]::new($FiscalStartYear,     5, 1) },
    @{ Col = "Jun_T"; PeriodId = 3;  Date = [datetime]::new($FiscalStartYear,     6, 1) },
    @{ Col = "Jul_T"; PeriodId = 4;  Date = [datetime]::new($FiscalStartYear,     7, 1) },
    @{ Col = "Aug_T"; PeriodId = 5;  Date = [datetime]::new($FiscalStartYear,     8, 1) },
    @{ Col = "Sep_T"; PeriodId = 6;  Date = [datetime]::new($FiscalStartYear,     9, 1) },
    @{ Col = "Oct_T"; PeriodId = 7;  Date = [datetime]::new($FiscalStartYear,    10, 1) },
    @{ Col = "Nov_T"; PeriodId = 8;  Date = [datetime]::new($FiscalStartYear,    11, 1) },
    @{ Col = "Dec_T"; PeriodId = 9;  Date = [datetime]::new($FiscalStartYear,    12, 1) },
    @{ Col = "Jan_T"; PeriodId = 10; Date = [datetime]::new($FiscalStartYear + 1, 1, 1) },
    @{ Col = "Feb_T"; PeriodId = 11; Date = [datetime]::new($FiscalStartYear + 1, 2, 1) },
    @{ Col = "Mar_T"; PeriodId = 12; Date = [datetime]::new($FiscalStartYear + 1, 3, 1) }
)

# ---- source CSV files -------------------------------------------------------
$baseDir = "4.System Analyst and Design/01.Raw-Extracts/MT"
$sheets  = @(
    @{ Path = "$baseDir/13_3)Target & Cal_Staff.values.csv"; Label = "Staff"  },
    @{ Path = "$baseDir/14_3)Target & Cal_Sect.values.csv";  Label = "Sect"   },
    @{ Path = "$baseDir/15_3)Target & Cal_Dept.values.csv";  Label = "Dept"   },
    @{ Path = "$baseDir/16_3)Target & Cal_AD.values.csv";    Label = "AD"     }
)

# ---- DB connection ----------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($ConnectionString)) {
    $ConnectionString = Get-ConnectionStringFromEnv -EnvFilePath "environment/database-dev - cds.env"
}

$cn = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
$cn.Open()

try {
    # Step 0: Delete dummy MT target rows (SP001, SP002)
    $delCmd = $cn.CreateCommand()
    $delCmd.CommandText = "DELETE FROM dbo.trn_sales_target WHERE channel_id = 1 AND salesman_code IN ('SP001','SP002')"
    $deleted = $delCmd.ExecuteNonQuery()
    Write-Host "Deleted $deleted dummy MT target rows (SP001/SP002)"

    $totalInserted = 0
    $totalSkipped  = 0

    foreach ($sheet in $sheets) {
        Write-Host "`n=== Processing sheet: $($sheet.Label) ($($sheet.Path)) ==="
        $rows = Get-TargetCalRows -Path $sheet.Path
        $sheetInserted = 0
        $sheetSkipped  = 0

        foreach ($row in $rows) {
            $team    = ([string]$row.Team).Trim()
            $product = ([string]$row.Product).Trim()

            # Skip invalid rows
            if ([string]::IsNullOrWhiteSpace($team)    -or $team    -eq '#N/A') { $sheetSkipped++; continue }
            if ([string]::IsNullOrWhiteSpace($product) -or $product -eq '#N/A') { $sheetSkipped++; continue }

            foreach ($mc in $monthCols) {
                $rawVal = $null
                try { $rawVal = $row.($mc.Col) } catch { }

                $targetAmt = ConvertTo-NullableDecimal -Value "$rawVal"
                if ($null -eq $targetAmt) { $sheetSkipped++; continue }

                $cmd = $cn.CreateCommand()
                $cmd.CommandText = @"
IF NOT EXISTS (
    SELECT 1 FROM dbo.trn_sales_target
    WHERE channel_id = 1 AND period_id = @period_id
      AND salesman_code = @sc AND product_code = @pc
)
INSERT INTO dbo.trn_sales_target
    (period_id, channel_id, salesman_code, product_code, target_amount,
     approved_by, approved_at, created_at, updated_at, pct_salesman)
VALUES
    (@period_id, 1, @sc, @pc, @amt,
     @approved_by, @approved_at, SYSDATETIME(), NULL, NULL)
"@
                $cmd.Parameters.AddWithValue("@period_id",    $mc.PeriodId)  | Out-Null
                $cmd.Parameters.AddWithValue("@sc",           $team)         | Out-Null
                $cmd.Parameters.AddWithValue("@pc",           $product)      | Out-Null
                $cmd.Parameters.AddWithValue("@amt",          $targetAmt)    | Out-Null
                $cmd.Parameters.AddWithValue("@approved_by",  $ApprovedBy)   | Out-Null
                $cmd.Parameters.AddWithValue("@approved_at",  $mc.Date)      | Out-Null

                $affected = $cmd.ExecuteNonQuery()
                if ($affected -gt 0) { $sheetInserted++ } else { $sheetSkipped++ }
            }
        }

        Write-Host "  Sheet $($sheet.Label): inserted=$sheetInserted  skipped=$sheetSkipped"
        $totalInserted += $sheetInserted
        $totalSkipped  += $sheetSkipped
    }

    Write-Host "`n=== TOTAL inserted=$totalInserted  skipped=$totalSkipped ==="

    # Final count check
    $cntCmd = $cn.CreateCommand()
    $cntCmd.CommandText = "SELECT COUNT(*) FROM dbo.trn_sales_target WHERE channel_id = 1"
    $finalCount = $cntCmd.ExecuteScalar()
    Write-Host "trn_sales_target (MT) row count after import: $finalCount"
}
finally {
    $cn.Close()
}
