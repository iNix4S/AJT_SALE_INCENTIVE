param(
    [string]$BaseUrl = "http://localhost:5115",
    [string]$ApiKey = "",
    [int]$PeriodId = 1,
    [string]$MtEngine = "StoredProcedure",
    [switch]$SkipCalculationRun,
    [switch]$SkipSandbox
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    throw "ApiKey is required. Example: -ApiKey 'your-key'"
}

$headers = @{
    "X-API-Key" = $ApiKey
}

function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Invoke-Api {
    param(
        [string]$Method,
        [string]$Path,
        [object]$Body = $null
    )

    $uri = "$BaseUrl$Path"
    Write-Host "$Method $uri" -ForegroundColor DarkGray

    if ($null -ne $Body) {
        return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -Body ($Body | ConvertTo-Json -Depth 10) -ContentType "application/json"
    }

    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
}

Write-Step "Health"
$health = Invoke-RestMethod -Method GET -Uri "$BaseUrl/health"
$health | ConvertTo-Json -Depth 5

Write-Step "Formula Validation"
$formulaValidation = Invoke-Api -Method POST -Path "/api/v1/formulas/validate" -Body @{
    formulaExpr = "[base_rate] * [weight_pct] * [goal_mult]"
}
$formulaValidation | ConvertTo-Json -Depth 6

if (-not $SkipCalculationRun) {
    Write-Step "Run MT Calculation"
    $run = Invoke-Api -Method POST -Path "/api/v1/calculation/MT/run" -Body @{
        periodId = $PeriodId
        engine = $MtEngine
        approvedBy = "api-regression"
    }
    $run | ConvertTo-Json -Depth 6

    $calcRunId = $run.data.calcRunId
    if ($calcRunId) {
        Write-Step "Get Run Status"
        $status = Invoke-Api -Method GET -Path "/api/v1/calculation/runs/$calcRunId"
        $status | ConvertTo-Json -Depth 6
    }

    Write-Step "Get MT Results"
    $results = Invoke-Api -Method GET -Path "/api/v1/calculation/MT/results?periodId=$PeriodId"
    $results | ConvertTo-Json -Depth 4
}

if (-not $SkipSandbox) {
    Write-Step "Sandbox Run (Persist=false)"
    $sandboxRun = Invoke-Api -Method POST -Path "/api/v1/calculation/sandbox/run" -Body @{
        targetChannel = "MT"
        sourceTransactionChannel = "MT"
        periodId = $PeriodId
        engine = "NCalc"
        formulaSetRef = "draft"
        persist = $false
        approvedBy = "api-regression"
    }
    $sandboxRun | ConvertTo-Json -Depth 6
}

Write-Step "Regression API completed"
