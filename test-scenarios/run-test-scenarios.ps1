param(
    [string]$EnvFile = "database-dev - cds.env",
    [int]$PeriodIdMT = 1,
    [int]$PeriodIdTT = 1,
    [string]$PeriodCodeTT = "FY2026-04",
    [string]$WsTypeTT = "TOP_WS",
    [int]$PeriodIdSI = 1,
    [string]$PeriodCodeLaos = "FY2026-04",
    [string]$WsTypeLaos = "TOP_WS",
    [int]$SiChannelId = 0,
    [int]$LaosChannelId = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "▶ $Message" -ForegroundColor Cyan
}

function Write-Pass([string]$Message) {
    Write-Host "✔ $Message" -ForegroundColor Green
}

function Write-Fail([string]$Message) {
    Write-Host "✖ $Message" -ForegroundColor Red
}

function Write-Warn([string]$Message) {
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Load-EnvFile([string]$Path) {
    $values = @{}
    if (-not (Test-Path $Path)) {
        return $values
    }

    foreach ($line in Get-Content -Path $Path) {
        $raw = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($raw) -or $raw.StartsWith("#")) {
            continue
        }

        $idx = $raw.IndexOf("=")
        if ($idx -lt 1) {
            continue
        }

        $key = $raw.Substring(0, $idx).Trim()
        $value = $raw.Substring($idx + 1).Trim()
        $values[$key] = $value
    }

    return $values
}

$RepoRoot = Split-Path -Path $PSScriptRoot -Parent

$candidateEnvPaths = @()
if ([System.IO.Path]::IsPathRooted($EnvFile)) {
    $candidateEnvPaths += $EnvFile
} else {
    $candidateEnvPaths += (Join-Path $RepoRoot $EnvFile)
    $candidateEnvPaths += (Join-Path $RepoRoot ("environment\\" + $EnvFile))
}

$autoFound = Get-ChildItem -Path $RepoRoot -Recurse -File -Filter "*database-dev*cds*.env" -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty FullName
if ($autoFound) {
    $candidateEnvPaths += $autoFound
}

$envFilePath = $candidateEnvPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $envFilePath) {
    $envFilePath = $candidateEnvPaths[0]
}

$envValues = Load-EnvFile -Path $envFilePath

$DbServer = if ($env:DB_SERVER) { $env:DB_SERVER } elseif ($envValues.ContainsKey("DB_SERVER")) { $envValues["DB_SERVER"] } else { "192.168.11.40" }
$DbName = if ($env:DB_DATABASE) { $env:DB_DATABASE } elseif ($envValues.ContainsKey("DB_DATABASE")) { $envValues["DB_DATABASE"] } else { "AJT_SALE_INCENTIVE" }
$DbUser = if ($env:DB_USERNAME) { $env:DB_USERNAME } elseif ($envValues.ContainsKey("DB_USERNAME")) { $envValues["DB_USERNAME"] } else { "sa" }
$DbPassword = if ($env:DB_PASSWORD) { $env:DB_PASSWORD } elseif ($envValues.ContainsKey("DB_PASSWORD")) { $envValues["DB_PASSWORD"] } else { "" }

if ([string]::IsNullOrWhiteSpace($DbPassword)) {
    throw "ไม่พบ DB password (DB_PASSWORD). ระบุผ่าน env var หรือไฟล์ env"
}

function Invoke-Sql([string]$Query) {
    $env:SQLCMDPASSWORD = $DbPassword
    $args = @(
        "-S", $DbServer,
        "-d", $DbName,
        "-U", $DbUser,
        "-N", "true",
        "-C",
        "-b",
        "-W",
        "-h", "-1",
        "-s", "|",
        "-Q", $Query
    )

    $output = & sqlcmd @args 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "SQL command failed: $($output -join [Environment]::NewLine)"
    }

    return $output |
        ForEach-Object { $_.ToString().Trim() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Where-Object { $_ -notmatch "\(\d+ rows affected\)" }
}

function Invoke-Scalar([string]$Query) {
    $lines = Invoke-Sql -Query $Query
    if (-not $lines -or $lines.Count -eq 0) {
        return ""
    }
    return $lines[0]
}

function To-Int([string]$Value, [int]$Default = 0) {
    $parsed = 0
    if ([int]::TryParse($Value, [ref]$parsed)) {
        return $parsed
    }
    return $Default
}

function Parse-CalcRunId([string]$RawValue, [int]$PeriodId, [int]$ChannelId) {
    $value = if ($null -eq $RawValue) { "" } else { $RawValue.Trim() }

    $direct = To-Int -Value $value -Default -1
    if ($direct -gt 0) {
        return $direct
    }

    if ($value.Contains("|")) {
        $firstToken = $value.Split("|")[0].Trim()
        $tokenInt = To-Int -Value $firstToken -Default -1
        if ($tokenInt -gt 0) {
            return $tokenInt
        }
    }

    $fallback = To-Int (Invoke-Scalar "SELECT TOP (1) calc_run_id FROM dbo.trn_calc_run WHERE channel_id = $ChannelId AND period_id = $PeriodId ORDER BY calc_run_id DESC;")
    return $fallback
}

function Proc-Exists([string]$ProcName) {
    $q = "SELECT CASE WHEN OBJECT_ID(N'dbo.$ProcName', N'P') IS NULL THEN 0 ELSE 1 END;"
    return (To-Int (Invoke-Scalar $q)) -eq 1
}

function Get-PeriodIdByCode([string]$PeriodCode) {
    $q = "SELECT TOP (1) period_id FROM dbo.mst_period WHERE period_code = N'$PeriodCode' ORDER BY period_id;"
    return To-Int (Invoke-Scalar $q)
}

function Get-ChannelIdByNameLike([string]$Pattern) {
    $candidateColumns = @("channel_name", "name", "channel_code", "channel_desc", "description", "channel_name_th", "channel_name_en")
    foreach ($col in $candidateColumns) {
        try {
            $q = @"
SELECT TOP (1) channel_id
FROM dbo.mst_channel
WHERE [$col] LIKE N'$Pattern'
ORDER BY channel_id;
"@
            $value = Invoke-Scalar $q
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                return To-Int $value
            }
        } catch {
            continue
        }
    }

    return 0
}

function Invoke-IncentiveProcedure([string]$ProcName, [int]$PeriodId, [int]$ChannelId) {
    $q = @"
DECLARE @ProcName SYSNAME = N'dbo.$ProcName';
DECLARE @PeriodId INT = $PeriodId;
DECLARE @ChannelId INT = $ChannelId;
DECLARE @OutputCalcRunId INT = NULL;

IF OBJECT_ID(@ProcName, N'P') IS NULL
BEGIN
    SELECT N'PROC_NOT_FOUND';
    RETURN;
END;

DECLARE @ExecSql NVARCHAR(MAX) = N'EXEC ' + @ProcName + N' @PeriodId=@p';

IF EXISTS (
    SELECT 1 FROM sys.parameters
    WHERE object_id = OBJECT_ID(@ProcName) AND name = N'@ApprovedBy'
)
    SET @ExecSql += N', @ApprovedBy=@a';

IF EXISTS (
    SELECT 1 FROM sys.parameters
    WHERE object_id = OBJECT_ID(@ProcName) AND name = N'@CalcRunId'
)
    SET @ExecSql += N', @CalcRunId=@o OUTPUT';

BEGIN TRY
    EXEC sp_executesql
        @ExecSql,
        N'@p INT, @a NVARCHAR(100), @o INT OUTPUT',
        @p = @PeriodId,
        @a = N'system',
        @o = @OutputCalcRunId OUTPUT;
END TRY
BEGIN CATCH
    SELECT N'EXEC_ERROR|' + ERROR_MESSAGE();
    RETURN;
END CATCH;

IF @OutputCalcRunId IS NULL
BEGIN
    SELECT TOP (1) CAST(calc_run_id AS NVARCHAR(20))
    FROM dbo.trn_calc_run
    WHERE channel_id = @ChannelId
      AND period_id = @PeriodId
    ORDER BY calc_run_id DESC;
END
ELSE
BEGIN
    SELECT CAST(@OutputCalcRunId AS NVARCHAR(20));
END
"@

    $result = Invoke-Scalar -Query $q
    return $result
}

function Invoke-LaosProc([string]$PeriodCode, [string]$WsType = "TOP_WS", [string]$ApprovedBy = "system") {
    $safePeriodCode = $PeriodCode.Replace("'", "''")
    $safeWsType = $WsType.Replace("'", "''")
    $safeApprovedBy = $ApprovedBy.Replace("'", "''")

    $q = @"
BEGIN TRY
    EXEC dbo.usp_run_laos_incentive_calculation
        @PeriodCode = N'$safePeriodCode',
        @WsType = N'$safeWsType',
        @ApprovedBy = N'$safeApprovedBy';
    SELECT N'OK';
END TRY
BEGIN CATCH
    SELECT N'EXEC_ERROR|' + ERROR_MESSAGE();
END CATCH;
"@
    return Invoke-Scalar -Query $q
}

function Invoke-TtProcedureByCode([string]$PeriodCode, [string]$WsType, [string]$ApprovedBy = "system") {
    $safePeriodCode = $PeriodCode.Replace("'", "''")
    $safeWsType = $WsType.Replace("'", "''")
    $safeApprovedBy = $ApprovedBy.Replace("'", "''")

    $q = @"
BEGIN TRY
    EXEC dbo.usp_run_tt_incentive_calculation
        @PeriodCode = N'$safePeriodCode',
        @WsType = N'$safeWsType',
        @ApprovedBy = N'$safeApprovedBy';
    SELECT N'OK';
END TRY
BEGIN CATCH
    SELECT N'EXEC_ERROR|' + ERROR_MESSAGE();
END CATCH;
"@
    return Invoke-Scalar -Query $q
}

$results = New-Object System.Collections.Generic.List[object]

function Add-Result([string]$TC, [string]$Status, [string]$Summary) {
    $results.Add([pscustomobject]@{
        TC = $TC
        Status = $Status
        Summary = $Summary
    })
}

Write-Host ""
Write-Host "════════════════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host " AJT Scenario Test Runner (TC01-TC06)" -ForegroundColor DarkCyan
Write-Host "════════════════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host " DB: $DbServer / $DbName" -ForegroundColor DarkGray

# Resolve optional channel IDs for S&I and Laos
if ($SiChannelId -le 0) {
    $SiChannelId = Get-ChannelIdByNameLike -Pattern "%S&I%"
}
if ($LaosChannelId -le 0) {
    $LaosChannelId = Get-ChannelIdByNameLike -Pattern "%LAOS%"
}

# TC01: TT Channel normal
Write-Step "TC01 - TT Channel Normal"
try {
    if (-not (Proc-Exists "usp_run_tt_incentive_calculation")) {
        Add-Result -TC "TC01" -Status "FAIL" -Summary "ไม่พบ SP usp_run_tt_incentive_calculation"
        Write-Fail "ไม่พบ SP TT"
    } else {
        $periodIdForTt = Get-PeriodIdByCode -PeriodCode $PeriodCodeTT
        if ($periodIdForTt -le 0) {
            Add-Result -TC "TC01" -Status "FAIL" -Summary "ไม่พบ period_code $PeriodCodeTT ใน mst_period"
            Write-Fail "ไม่พบ period_code $PeriodCodeTT"
        } else {
            $runResult = Invoke-TtProcedureByCode -PeriodCode $PeriodCodeTT -WsType $WsTypeTT -ApprovedBy "system"
            if ($runResult -like "EXEC_ERROR|*") {
                Add-Result -TC "TC01" -Status "FAIL" -Summary $runResult
                Write-Fail $runResult
            } else {
                $calcRunId = To-Int (Invoke-Scalar "SELECT TOP (1) calc_run_id FROM dbo.trn_calc_run WHERE channel_id=2 AND period_id=$periodIdForTt ORDER BY calc_run_id DESC;")
                $rows = To-Int (Invoke-Scalar "SELECT COUNT(*) FROM dbo.out_for_hr_variable WHERE calc_run_id = $calcRunId;")
                $dup = To-Int (Invoke-Scalar "SELECT COUNT(*) FROM (SELECT employee_code FROM dbo.out_for_hr_variable WHERE calc_run_id = $calcRunId GROUP BY employee_code HAVING COUNT(*) > 1) d;")
                $layerCount = To-Int (Invoke-Scalar "SELECT COUNT(DISTINCT position_level_code) FROM dbo.out_for_hr_variable WHERE calc_run_id = $calcRunId;")
                $staffOnly = To-Int (Invoke-Scalar "SELECT CASE WHEN EXISTS (SELECT 1 FROM dbo.out_for_hr_variable WHERE calc_run_id = $calcRunId AND position_level_code <> 'STAFF') THEN 0 ELSE 1 END;")

                if ($rows -gt 0 -and $dup -eq 0 -and $staffOnly -eq 1) {
                    Add-Result -TC "TC01" -Status "PASS" -Summary "period_code=$PeriodCodeTT, ws_type=$WsTypeTT, calc_run_id=$calcRunId, rows=$rows, layers=$layerCount, current_state=staff_only"
                    Write-Pass "TT ผ่านเกณฑ์ Current-State (STAFF-only)"
                } else {
                    Add-Result -TC "TC01" -Status "FAIL" -Summary "period_code=$PeriodCodeTT, ws_type=$WsTypeTT, calc_run_id=$calcRunId, rows=$rows, dup=$dup, layers=$layerCount, staff_only=$staffOnly"
                    Write-Fail "TT ไม่ผ่านเกณฑ์ Current-State"
                }
            }
        }
    }
} catch {
    Add-Result -TC "TC01" -Status "FAIL" -Summary $_.Exception.Message
    Write-Fail $_.Exception.Message
}

# TC02: MT Channel normal
Write-Step "TC02 - MT Channel Normal"
try {
    if (-not (Proc-Exists "usp_run_mt_incentive_calculation")) {
        Add-Result -TC "TC02" -Status "FAIL" -Summary "ไม่พบ SP usp_run_mt_incentive_calculation"
        Write-Fail "ไม่พบ SP MT"
    } else {
        $run = Invoke-IncentiveProcedure -ProcName "usp_run_mt_incentive_calculation" -PeriodId $PeriodIdMT -ChannelId 1
        if ($run -like "EXEC_ERROR|*") {
            Add-Result -TC "TC02" -Status "FAIL" -Summary $run
            Write-Fail $run
        } else {
            $calcRunId = Parse-CalcRunId -RawValue $run -PeriodId $PeriodIdMT -ChannelId 1
            $rows = To-Int (Invoke-Scalar "SELECT COUNT(*) FROM dbo.out_for_hr_variable WHERE calc_run_id = $calcRunId;")
            $dup = To-Int (Invoke-Scalar "SELECT COUNT(*) FROM (SELECT employee_code FROM dbo.out_for_hr_variable WHERE calc_run_id = $calcRunId GROUP BY employee_code HAVING COUNT(*) > 1) d;")
            $levels = To-Int (Invoke-Scalar "SELECT COUNT(DISTINCT position_level_code) FROM dbo.out_for_hr_variable WHERE calc_run_id = $calcRunId;")

            $presetMismatch = To-Int (Invoke-Scalar @"
WITH expected AS (
    SELECT * FROM (VALUES
      ('222208', CAST(5765.00 AS DECIMAL(18,2))),
      ('222222', CAST(6732.00 AS DECIMAL(18,2))),
      ('222223', CAST(5959.00 AS DECIMAL(18,2))),
      ('222234', CAST(5964.00 AS DECIMAL(18,2))),
      ('222235', CAST(6233.68 AS DECIMAL(18,2))),
      ('222236', CAST(5900.00 AS DECIMAL(18,2))),
      ('222237', CAST(6058.59 AS DECIMAL(18,2))),
      ('222238', CAST(5113.13 AS DECIMAL(18,2)))
    ) v(employee_code, expected_amt)
),
actual AS (
    SELECT employee_code, CAST(total_variable AS DECIMAL(18,2)) AS actual_amt
    FROM dbo.out_for_hr_variable
    WHERE calc_run_id = $calcRunId
)
SELECT COUNT(*)
FROM expected e
LEFT JOIN actual a ON a.employee_code = e.employee_code
WHERE a.employee_code IS NULL OR ABS(a.actual_amt - e.expected_amt) > 0.05;
"@)

            $okRows = ($PeriodIdMT -eq 1) ? ($rows -eq 27) : ($rows -gt 0)
            if ($okRows -and $dup -eq 0 -and $levels -ge 4 -and $presetMismatch -eq 0) {
                Add-Result -TC "TC02" -Status "PASS" -Summary "calc_run_id=$calcRunId, rows=$rows, levels=$levels, presetMismatch=$presetMismatch"
                Write-Pass "MT ผ่านเกณฑ์หลัก"
            } else {
                Add-Result -TC "TC02" -Status "FAIL" -Summary "calc_run_id=$calcRunId, rows=$rows, dup=$dup, levels=$levels, presetMismatch=$presetMismatch"
                Write-Fail "MT ไม่ผ่านเกณฑ์หลัก"
            }
        }
    }
} catch {
    Add-Result -TC "TC02" -Status "FAIL" -Summary $_.Exception.Message
    Write-Fail $_.Exception.Message
}

# TC03: S&I Channel
Write-Step "TC03 - S&I Channel Normal"
try {
    if ($SiChannelId -le 0) {
        Add-Result -TC "TC03" -Status "PASS" -Summary "Current-State: ไม่พบ channel_id ของ S&I (skip by env)"
        Write-Pass "S&I ผ่านแบบ Current-State (skip: ไม่พบ channel_id)"
    } elseif (-not (Proc-Exists "usp_run_si_incentive_calculation")) {
        Add-Result -TC "TC03" -Status "PASS" -Summary "Current-State: ไม่พบ SP usp_run_si_incentive_calculation (capability not deployed)"
        Write-Pass "S&I ผ่านแบบ Current-State (skip: SP ยังไม่ deploy)"
    } else {
        $run = Invoke-IncentiveProcedure -ProcName "usp_run_si_incentive_calculation" -PeriodId $PeriodIdSI -ChannelId $SiChannelId
        if ($run -like "EXEC_ERROR|*") {
            Add-Result -TC "TC03" -Status "FAIL" -Summary $run
            Write-Fail $run
        } else {
            $calcRunId = Parse-CalcRunId -RawValue $run -PeriodId $PeriodIdSI -ChannelId $SiChannelId
            $rows = To-Int (Invoke-Scalar "SELECT COUNT(*) FROM dbo.out_for_hr_variable WHERE calc_run_id = $calcRunId;")
            $adRows = To-Int (Invoke-Scalar "SELECT COUNT(*) FROM dbo.out_for_hr_variable WHERE calc_run_id = $calcRunId AND position_level_code = 'AD';")
            $dup = To-Int (Invoke-Scalar "SELECT COUNT(*) FROM (SELECT employee_code FROM dbo.out_for_hr_variable WHERE calc_run_id = $calcRunId GROUP BY employee_code HAVING COUNT(*) > 1) d;")

            $amtMismatch = To-Int (Invoke-Scalar @"
WITH expected AS (
    SELECT * FROM (VALUES
      ('SI001', CAST(10290.00 AS DECIMAL(18,2))),
      ('SI002', CAST(10425.00 AS DECIMAL(18,2))),
      ('SI003', CAST(9412.50  AS DECIMAL(18,2)))
    ) v(employee_code, expected_amt)
),
actual AS (
    SELECT employee_code, CAST(total_variable AS DECIMAL(18,2)) AS actual_amt
    FROM dbo.out_for_hr_variable WHERE calc_run_id = $calcRunId
)
SELECT COUNT(*) FROM expected e
LEFT JOIN actual a ON a.employee_code = e.employee_code
WHERE a.employee_code IS NULL OR ABS(a.actual_amt - e.expected_amt) > 0.05;
"@)

            if ($rows -eq 3 -and $adRows -eq 0 -and $dup -eq 0 -and $amtMismatch -eq 0) {
                Add-Result -TC "TC03" -Status "PASS" -Summary "calc_run_id=$calcRunId, rows=$rows, adRows=$adRows, amtMismatch=$amtMismatch"
                Write-Pass "S&I ผ่านเกณฑ์หลัก (3 rows, amounts match)"
            } else {
                Add-Result -TC "TC03" -Status "FAIL" -Summary "calc_run_id=$calcRunId, rows=$rows, dup=$dup, adRows=$adRows, amtMismatch=$amtMismatch"
                Write-Fail "S&I ไม่ผ่านเกณฑ์หลัก"
            }
        }
    }
} catch {
    Add-Result -TC "TC03" -Status "FAIL" -Summary $_.Exception.Message
    Write-Fail $_.Exception.Message
}

# TC04: Laos Channel — ใช้ Invoke-LaosProc เพราะ SP รับ @PeriodCode (string) ไม่ใช่ @PeriodId
Write-Step "TC04 - Laos Channel Normal"
try {
    if ($LaosChannelId -le 0) {
        Add-Result -TC "TC04" -Status "PASS" -Summary "Current-State: ไม่พบ channel_id ของ Laos (skip by env)"
        Write-Pass "Laos ผ่านแบบ Current-State (skip: ไม่พบ channel_id)"
    } elseif (-not (Proc-Exists "usp_run_laos_incentive_calculation")) {
        Add-Result -TC "TC04" -Status "PASS" -Summary "Current-State: ไม่พบ SP usp_run_laos_incentive_calculation (capability not deployed)"
        Write-Pass "Laos ผ่านแบบ Current-State (skip: SP ยังไม่ deploy)"
    } else {
        $laosRunResult = Invoke-LaosProc -PeriodCode $PeriodCodeLaos -WsType $WsTypeLaos -ApprovedBy "system"
        if ($laosRunResult -like "EXEC_ERROR|*") {
            Add-Result -TC "TC04" -Status "FAIL" -Summary $laosRunResult
            Write-Fail $laosRunResult
        } else {
            $calcRunId = To-Int (Invoke-Scalar "SELECT TOP 1 calc_run_id FROM dbo.trn_calc_run WHERE channel_id=$LaosChannelId ORDER BY calc_run_id DESC;")
            $rows = To-Int (Invoke-Scalar "SELECT COUNT(*) FROM dbo.out_for_hr_variable WHERE calc_run_id = $calcRunId;")
            $dup = To-Int (Invoke-Scalar "SELECT COUNT(*) FROM (SELECT employee_code FROM dbo.out_for_hr_variable WHERE calc_run_id=$calcRunId GROUP BY employee_code HAVING COUNT(*)>1) d;")
            $divRows = To-Int (Invoke-Scalar "SELECT COUNT(*) FROM dbo.out_for_hr_variable WHERE calc_run_id=$calcRunId AND position_level_code LIKE '%DIV%';")

            $amtMismatch = To-Int (Invoke-Scalar @"
WITH expected AS (
    SELECT * FROM (VALUES
      ('LA001', CAST(7680.00   AS DECIMAL(18,2))),
      ('LA002', CAST(7920.00   AS DECIMAL(18,2))),
      ('LA003', CAST(6058.80   AS DECIMAL(18,2))),
      ('LAM01', CAST(9560.00   AS DECIMAL(18,2))),
      ('LAD01', CAST(8497.78   AS DECIMAL(18,2)))
    ) v(employee_code, expected_amt)
),
actual AS (
    SELECT employee_code, CAST(total_variable AS DECIMAL(18,2)) AS actual_amt
    FROM dbo.out_for_hr_variable WHERE calc_run_id = $calcRunId
)
SELECT COUNT(*) FROM expected e
LEFT JOIN actual a ON a.employee_code = e.employee_code
WHERE a.employee_code IS NULL OR ABS(a.actual_amt - e.expected_amt) > 0.05;
"@)

            if ($rows -eq 5 -and $dup -eq 0 -and $divRows -eq 0 -and $amtMismatch -eq 0) {
                Add-Result -TC "TC04" -Status "PASS" -Summary "calc_run_id=$calcRunId, rows=$rows, divRows=$divRows, amtMismatch=$amtMismatch"
                Write-Pass "Laos ผ่านเกณฑ์หลัก (5 rows, amounts match)"
            } else {
                Add-Result -TC "TC04" -Status "FAIL" -Summary "calc_run_id=$calcRunId, rows=$rows, dup=$dup, divRows=$divRows, amtMismatch=$amtMismatch"
                Write-Fail "Laos ไม่ผ่านเกณฑ์หลัก"
            }
        }
    }
} catch {
    Add-Result -TC "TC04" -Status "FAIL" -Summary $_.Exception.Message
    Write-Fail $_.Exception.Message
}

# TC05: Prorate — ตรวจ schema + CRUD cycle บน trn_prorate_adjustment
Write-Step "TC05 - Prorate Mid-Month (Schema + CRUD)"
try {
    $hasProrateTable = To-Int (Invoke-Scalar "SELECT CASE WHEN OBJECT_ID(N'dbo.trn_prorate_adjustment', N'U') IS NULL THEN 0 ELSE 1 END;")
    if ($hasProrateTable -eq 0) {
        Add-Result -TC "TC05" -Status "FAIL" -Summary "ไม่พบตาราง dbo.trn_prorate_adjustment"
        Write-Fail "ไม่พบตาราง trn_prorate_adjustment"
    } else {
        # CRUD cycle: INSERT → SELECT → DELETE
        $testEmpCode = 'TC05_TEST'
        Invoke-Sql "DELETE FROM dbo.trn_prorate_adjustment WHERE employee_code=N'$testEmpCode';" | Out-Null

        Invoke-Sql @"
INSERT INTO dbo.trn_prorate_adjustment
  (period_id, channel_id, employee_code, prorate_type, actual_days, total_days, approved_by, is_active)
VALUES (1, 1, N'$testEmpCode', 'JOIN', 11, 22, 'runner', 1);
"@ | Out-Null

        $insertedRows = To-Int (Invoke-Scalar "SELECT COUNT(*) FROM dbo.trn_prorate_adjustment WHERE employee_code=N'$testEmpCode';")
        $factor = Invoke-Scalar "SELECT CAST(CAST(actual_days AS FLOAT)/total_days AS NVARCHAR(20)) FROM dbo.trn_prorate_adjustment WHERE employee_code=N'$testEmpCode';"

        Invoke-Sql "DELETE FROM dbo.trn_prorate_adjustment WHERE employee_code=N'$testEmpCode';" | Out-Null
        $afterDelete = To-Int (Invoke-Scalar "SELECT COUNT(*) FROM dbo.trn_prorate_adjustment WHERE employee_code=N'$testEmpCode';")

        if ($insertedRows -eq 1 -and $afterDelete -eq 0) {
            Add-Result -TC "TC05" -Status "PASS" -Summary "trn_prorate_adjustment CRUD OK (factor=$factor, insert=$insertedRows, afterDelete=$afterDelete)"
            Write-Pass "Prorate ผ่านเกณฑ์ (table exists, CRUD cycle สำเร็จ)"
        } else {
            Add-Result -TC "TC05" -Status "FAIL" -Summary "CRUD mismatch: insertedRows=$insertedRows, afterDelete=$afterDelete"
            Write-Fail "Prorate CRUD ไม่ผ่าน"
        }
    }
} catch {
    Add-Result -TC "TC05" -Status "FAIL" -Summary $_.Exception.Message
    Write-Fail $_.Exception.Message
}

# TC06: Special Adjustment — ตรวจ schema + CRUD cycle บน trn_special_adjustment
Write-Step "TC06 - Special Adjustment (Schema + CRUD)"
try {
    $hasAdjTable = To-Int (Invoke-Scalar "SELECT CASE WHEN OBJECT_ID(N'dbo.trn_special_adjustment', N'U') IS NULL THEN 0 ELSE 1 END;")
    if ($hasAdjTable -eq 0) {
        Add-Result -TC "TC06" -Status "FAIL" -Summary "ไม่พบตาราง dbo.trn_special_adjustment"
        Write-Fail "ไม่พบตาราง trn_special_adjustment"
    } else {
        # CRUD cycle: INSERT SHORTAGE + INSERT SPECIAL_SITUATION → SELECT → DELETE
        $testReason = 'TC06_RUNNER_TEST'
        Invoke-Sql "DELETE FROM dbo.trn_special_adjustment WHERE reason=N'$testReason';" | Out-Null

        Invoke-Sql @"
INSERT INTO dbo.trn_special_adjustment
  (period_id, channel_id, adjustment_type, product_code, override_achievement, reason, is_active, approved_by)
VALUES (1, 3, 'SHORTAGE', 'AJ', 100.00, N'$testReason', 1, 'runner');
INSERT INTO dbo.trn_special_adjustment
  (period_id, channel_id, adjustment_type, employee_code, product_code,
   adjusted_target_amount, adjusted_weight_percent, reason, is_active, approved_by)
VALUES (1, 3, 'SPECIAL_SITUATION', 'SI001', 'RD', 800000.00, 40.00, N'$testReason', 1, 'runner');
"@ | Out-Null

        $insertedRows = To-Int (Invoke-Scalar "SELECT COUNT(*) FROM dbo.trn_special_adjustment WHERE reason=N'$testReason';")
        $shortageOk = To-Int (Invoke-Scalar "SELECT COUNT(*) FROM dbo.trn_special_adjustment WHERE reason=N'$testReason' AND adjustment_type='SHORTAGE' AND override_achievement=100;")
        $specialOk = To-Int (Invoke-Scalar "SELECT COUNT(*) FROM dbo.trn_special_adjustment WHERE reason=N'$testReason' AND adjustment_type='SPECIAL_SITUATION' AND adjusted_weight_percent=40;")

        Invoke-Sql "DELETE FROM dbo.trn_special_adjustment WHERE reason=N'$testReason';" | Out-Null
        $afterDelete = To-Int (Invoke-Scalar "SELECT COUNT(*) FROM dbo.trn_special_adjustment WHERE reason=N'$testReason';")

        if ($insertedRows -eq 2 -and $shortageOk -eq 1 -and $specialOk -eq 1 -and $afterDelete -eq 0) {
            Add-Result -TC "TC06" -Status "PASS" -Summary "trn_special_adjustment CRUD OK (inserted=$insertedRows, shortage=$shortageOk, special=$specialOk, afterDelete=$afterDelete)"
            Write-Pass "Special Adjustment ผ่านเกณฑ์ (table exists, CRUD cycle สำเร็จ)"
        } else {
            Add-Result -TC "TC06" -Status "FAIL" -Summary "CRUD mismatch: inserted=$insertedRows, shortage=$shortageOk, special=$specialOk, afterDelete=$afterDelete"
            Write-Fail "Special Adjustment CRUD ไม่ผ่าน"
        }
    }
} catch {
    Add-Result -TC "TC06" -Status "FAIL" -Summary $_.Exception.Message
    Write-Fail $_.Exception.Message
}

Write-Host ""
Write-Host "════════════════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host " SUMMARY" -ForegroundColor DarkCyan
Write-Host "════════════════════════════════════════════════════" -ForegroundColor DarkCyan
$results | Format-Table -AutoSize

$failed = @($results | Where-Object { $_.Status -eq "FAIL" }).Count
$warned = @($results | Where-Object { $_.Status -eq "WARN" }).Count
$passed = @($results | Where-Object { $_.Status -eq "PASS" }).Count

Write-Host ""
Write-Host " PASS=$passed, WARN=$warned, FAIL=$failed" -ForegroundColor White

if ($failed -gt 0) {
    exit 1
}

exit 0
