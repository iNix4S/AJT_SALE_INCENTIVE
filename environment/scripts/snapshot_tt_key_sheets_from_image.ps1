param(
    [string]$SourceDir = "4.System Analyst and Design/01.Raw-Extracts/TT",
    [string]$OutputDir = "4.System Analyst and Design/01.Raw-Extracts/TT/00_Key-Sheets-From-Image"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$requiredPrefixes = @(
    "01_Top WS",
    "02_WS SF",
    "03_WS WH",
    "05_SF WH",
    "09_2) หลักการคำนวน Table",
    "11_3)Target & Cal"
)

if (-not (Test-Path -LiteralPath $SourceDir)) {
    throw "SourceDir not found: $SourceDir"
}

if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$copied = New-Object System.Collections.Generic.List[string]
$missing = New-Object System.Collections.Generic.List[string]

foreach ($prefix in $requiredPrefixes) {
    $matches = Get-ChildItem -LiteralPath $SourceDir -File |
        Where-Object { $_.BaseName -like "$prefix*" -and ($_.Extension -eq ".csv" -or $_.Extension -eq ".md") }

    if ($matches.Count -eq 0) {
        $missing.Add($prefix)
        continue
    }

    foreach ($m in $matches) {
        $dest = Join-Path $OutputDir $m.Name
        Copy-Item -LiteralPath $m.FullName -Destination $dest -Force
        $copied.Add($m.Name)
    }
}

"SNAPSHOT_OUTPUT_DIR=$OutputDir"
"COPIED_FILES=$($copied.Count)"
$copied | Sort-Object | ForEach-Object { "COPIED: $_" }

if ($missing.Count -gt 0) {
    "MISSING_PREFIXES=$($missing.Count)"
    $missing | ForEach-Object { "MISSING: $_" }
}
else {
    "MISSING_PREFIXES=0"
}
