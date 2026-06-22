<#
.SYNOPSIS
    Build and Run — AJT Sale Incentive Web App

.DESCRIPTION
    สคริปต์สำหรับ Build และ Run AjtIncentive.Web
    รองรับ mode: build, run, watch, clean, trust-cert, test-scenarios

.PARAMETER Mode
    build       — Build solution เท่านั้น (default)
    run         — Run web app (http)
    run-https   — Run web app (https)
    watch       — Run แบบ hot-reload
    clean       — ลบ bin/ และ obj/ ทั้งหมด
    trust-cert  — Trust dev certificate (ทำครั้งแรกครั้งเดียว)
    test-scenarios — รัน TC01-TC06 ตามไฟล์ test-scenarios

.EXAMPLE
    .\dev.ps1
    .\dev.ps1 -Mode run
    .\dev.ps1 -Mode run-https
    .\dev.ps1 -Mode watch
    .\dev.ps1 -Mode clean
    .\dev.ps1 -Mode trust-cert
    .\dev.ps1 -Mode test-scenarios
#>

param(
    [ValidateSet("build", "run", "run-https", "watch", "clean", "trust-cert", "test-scenarios")]
    [string]$Mode = "build"
)

# ─── Paths ────────────────────────────────────────────────────────────────────
$ScriptDir  = $PSScriptRoot
$SolutionDir = Join-Path $ScriptDir "src"
$SolutionFile = Join-Path $SolutionDir "AjtIncentive.slnx"
$WebProject  = Join-Path $SolutionDir "AjtIncentive.Web\AjtIncentive.Web.csproj"
$ScenarioRunner = Join-Path $ScriptDir "test-scenarios\run-test-scenarios.ps1"

# ─── Helpers ──────────────────────────────────────────────────────────────────
function Write-Step([string]$msg) {
    Write-Host ""
    Write-Host "▶ $msg" -ForegroundColor Cyan
}

function Write-Success([string]$msg) {
    Write-Host "✔ $msg" -ForegroundColor Green
}

function Write-Fail([string]$msg) {
    Write-Host "✖ $msg" -ForegroundColor Red
}

function Assert-DotNet {
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        Write-Fail ".NET SDK ไม่พบ — โปรดติดตั้งก่อน: https://dotnet.microsoft.com/download"
        exit 1
    }
    $ver = dotnet --version
    Write-Host "  .NET SDK: $ver" -ForegroundColor DarkGray
}

# ─── Mode: trust-cert ─────────────────────────────────────────────────────────
function Invoke-TrustCert {
    Write-Step "Trust ASP.NET Core Dev Certificate"
    dotnet dev-certs https --trust
    if ($LASTEXITCODE -eq 0) { Write-Success "Certificate trusted แล้ว" }
    else { Write-Fail "Trust certificate ล้มเหลว (exit $LASTEXITCODE)" }
}

# ─── Mode: clean ──────────────────────────────────────────────────────────────
function Invoke-Clean {
    Write-Step "Clean — ลบ bin/ และ obj/"
    Get-ChildItem -Path $SolutionDir -Include bin,obj -Recurse -Directory |
        ForEach-Object {
            Write-Host "  ลบ: $($_.FullName)" -ForegroundColor DarkGray
            Remove-Item $_.FullName -Recurse -Force
        }
    Write-Success "Clean เสร็จสิ้น"
}

# ─── Stop running AjtIncentive processes ──────────────────────────────────────
function Stop-AppProcess {
    $procs = Get-Process -Name "AjtIncentive.Web" -ErrorAction SilentlyContinue
    if ($procs) {
        Write-Host "  หยุด AjtIncentive.Web process (PID: $($procs.Id -join ', '))..." -ForegroundColor DarkGray
        $procs | Stop-Process -Force
        Start-Sleep -Milliseconds 500
        Write-Success "หยุด process แล้ว"
    }
}

# ─── Mode: build ──────────────────────────────────────────────────────────────
function Invoke-Build {
    Write-Step "Build Solution: AjtIncentive.slnx"
    Stop-AppProcess
    dotnet build $SolutionFile --configuration Debug
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "Build ล้มเหลว (exit $LASTEXITCODE)"
        exit $LASTEXITCODE
    }
    Write-Success "Build สำเร็จ"
}

# ─── Mode: run ────────────────────────────────────────────────────────────────
function Invoke-Run([string]$profile = "http") {
    Write-Step "Run Web App — profile: $profile"
    Write-Host "  URL: http://localhost:5288" -ForegroundColor DarkGray
    if ($profile -eq "https") {
        Write-Host "  URL: https://localhost:7049" -ForegroundColor DarkGray
    }
    Write-Host "  กด Ctrl+C เพื่อหยุด" -ForegroundColor DarkGray
    Write-Host ""
    dotnet run --project $WebProject --launch-profile $profile
}

# ─── Mode: watch ──────────────────────────────────────────────────────────────
function Invoke-Watch {
    Write-Step "Run Web App (Hot-Reload Watch)"
    Write-Host "  URL: http://localhost:5288" -ForegroundColor DarkGray
    Write-Host "  แก้ไขไฟล์แล้ว browser จะ reload อัตโนมัติ" -ForegroundColor DarkGray
    Write-Host "  กด Ctrl+C เพื่อหยุด" -ForegroundColor DarkGray
    Write-Host ""
    dotnet watch run --project $WebProject --launch-profile http
}

# ─── Mode: test-scenarios ─────────────────────────────────────────────────────
function Invoke-TestScenarios {
    Write-Step "Run Test Scenarios (TC01-TC06)"
    if (-not (Test-Path $ScenarioRunner)) {
        Write-Fail "ไม่พบไฟล์ $ScenarioRunner"
        exit 1
    }

    & $ScenarioRunner
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "Scenario tests failed (exit $LASTEXITCODE)"
        exit $LASTEXITCODE
    }

    Write-Success "Scenario tests completed"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "═══════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host "  AJT Sale Incentive — Dev Script" -ForegroundColor DarkCyan
Write-Host "  Mode: $Mode" -ForegroundColor DarkCyan
Write-Host "═══════════════════════════════════════" -ForegroundColor DarkCyan

Assert-DotNet

switch ($Mode) {
    "build"      { Invoke-Build }
    "run"        { Invoke-Build; Invoke-Run "http" }
    "run-https"  { Invoke-Build; Invoke-Run "https" }
    "watch"      { Invoke-Watch }
    "clean"      { Invoke-Clean }
    "trust-cert" { Invoke-TrustCert }
    "test-scenarios" { Invoke-TestScenarios }
}
