<#
.SYNOPSIS
    แตกข้อมูลจากไฟล์ .xlsx ออกมาเป็น CSV (ค่า) และ Formula CSV (สูตร) แยกราย sheet
    โดยไม่ต้องพึ่ง Excel / Python / Node — ใช้เฉพาะ .NET ที่มากับ PowerShell

.DESCRIPTION
    .xlsx คือ zip ที่บรรจุไฟล์ XML ภายใน สคริปต์นี้จะ:
      1) อ่าน xl/sharedStrings.xml  -> ตารางข้อความ (shared string table)
      2) อ่าน xl/workbook.xml + rels -> map ชื่อ sheet กับไฟล์ worksheet
      3) วนแต่ละ worksheet:
           - <name>.values.csv   : ค่าที่คำนวณ/แสดงผล (resolve shared string แล้ว)
           - <name>.formulas.csv : สูตรในเซลล์ (เฉพาะเซลล์ที่มี <f>) เพื่อเข้าใจตรรกะ
      4) สร้าง _INDEX.md สรุปรายชื่อ sheet + จำนวนแถว/คอลัมน์

.PARAMETER XlsxPath
    พาธไฟล์ .xlsx ต้นทาง

.PARAMETER OutDir
    โฟลเดอร์ปลายทางสำหรับเก็บผลลัพธ์ (จะถูกสร้างให้ถ้ายังไม่มี)

.EXAMPLE
    .\Extract-Xlsx.ps1 -XlsxPath "..\..\1.General Documents\For Test_New Sales Incentive Scheme All Product_New formula_MT.xlsx" -OutDir "..\01.Raw-Extracts\MT"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$XlsxPath,
    [Parameter(Mandatory=$true)][string]$OutDir
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null

if (-not (Test-Path $XlsxPath)) { throw "ไม่พบไฟล์: $XlsxPath" }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# ---- helper: อ่าน entry ใน zip เป็น string ----
function Read-ZipEntry($zip, [string]$name) {
    $e = $zip.Entries | Where-Object { $_.FullName -eq $name }
    if (-not $e) { return $null }
    $r = New-Object System.IO.StreamReader($e.Open(), [System.Text.Encoding]::UTF8)
    $t = $r.ReadToEnd(); $r.Close()
    return $t
}

# ---- helper: แปลงเลขคอลัมน์ A,B,...,AA -> index (1-based) ----
function Convert-ColToIndex([string]$col) {
    $n = 0
    foreach ($ch in $col.ToCharArray()) {
        if ($ch -match '[A-Z]') { $n = $n * 26 + ([int][char]$ch - 64) }
    }
    return $n
}

# ---- helper: escape ค่า CSV ----
function Format-Csv([string]$v) {
    if ($null -eq $v) { return '' }
    if ($v -match '[",\r\n]') { return '"' + ($v -replace '"','""') + '"' }
    return $v
}

$zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $XlsxPath))
try {
    # 1) shared strings
    $shared = New-Object System.Collections.Generic.List[string]
    $ssXml = Read-ZipEntry $zip 'xl/sharedStrings.xml'
    if ($ssXml) {
        $doc = New-Object System.Xml.XmlDocument
        $doc.LoadXml($ssXml)
        foreach ($si in $doc.DocumentElement.ChildNodes) {
            # รวมทุก <t> ภายใน <si> (รองรับ rich text หลาย run)
            $sb = ''
            foreach ($t in $si.SelectNodes('.//*[local-name()="t"]')) { $sb += $t.InnerText }
            $shared.Add($sb)
        }
    }

    # 2) map sheet name -> target file ผ่าน workbook + rels
    $wbXml = Read-ZipEntry $zip 'xl/workbook.xml'
    $relXml = Read-ZipEntry $zip 'xl/_rels/workbook.xml.rels'
    $wbDoc = New-Object System.Xml.XmlDocument; $wbDoc.LoadXml($wbXml)
    $relDoc = New-Object System.Xml.XmlDocument; $relDoc.LoadXml($relXml)

    $relMap = @{}
    foreach ($r in $relDoc.DocumentElement.ChildNodes) { $relMap[$r.Id] = $r.Target }

    $sheets = @()
    foreach ($s in $wbDoc.SelectNodes('//*[local-name()="sheet"]')) {
        $rid = $s.Attributes['r:id'].Value
        $target = $relMap[$rid]
        if ($target -notmatch '^xl/') { $target = 'xl/' + $target }
        $sheets += [pscustomobject]@{ Name = $s.Attributes['name'].Value; Path = $target }
    }

    # 3) วนแต่ละ sheet
    $index = New-Object System.Text.StringBuilder
    [void]$index.AppendLine("# Index การ Extract: $([System.IO.Path]::GetFileName($XlsxPath))")
    [void]$index.AppendLine("")
    [void]$index.AppendLine("| # | Sheet | แถว | คอลัมน์สูงสุด | มีสูตร |")
    [void]$index.AppendLine("|---|-------|-----|---------------|--------|")

    $i = 0
    foreach ($sh in $sheets) {
        $i++
        $xml = Read-ZipEntry $zip $sh.Path
        if (-not $xml) { continue }
        $sd = New-Object System.Xml.XmlDocument; $sd.LoadXml($xml)

        $rows = $sd.SelectNodes('//*[local-name()="sheetData"]/*[local-name()="row"]')
        $maxCol = 0
        $grid = @{}     # "r,c" -> displayValue
        $fgrid = @{}    # "r,c" -> formula
        $maxRow = 0

        foreach ($row in $rows) {
            foreach ($c in $row.ChildNodes) {
                $ref = $c.Attributes['r'].Value
                if ($ref -notmatch '^([A-Z]+)(\d+)$') { continue }
                $colIdx = Convert-ColToIndex $Matches[1]
                $rowIdx = [int]$Matches[2]
                if ($colIdx -gt $maxCol) { $maxCol = $colIdx }
                if ($rowIdx -gt $maxRow) { $maxRow = $rowIdx }

                $type = $c.Attributes['t']
                $vNode = $c.SelectSingleNode('*[local-name()="v"]')
                $fNode = $c.SelectSingleNode('*[local-name()="f"]')
                $isNode = $c.SelectSingleNode('*[local-name()="is"]') # inline string

                $val = ''
                if ($type -and $type.Value -eq 's' -and $vNode) {
                    $idx = [int]$vNode.InnerText
                    if ($idx -lt $shared.Count) { $val = $shared[$idx] }
                } elseif ($type -and $type.Value -eq 'inlineStr' -and $isNode) {
                    foreach ($t in $isNode.SelectNodes('.//*[local-name()="t"]')) { $val += $t.InnerText }
                } elseif ($vNode) {
                    $val = $vNode.InnerText
                }

                $grid["$rowIdx,$colIdx"] = $val
                if ($fNode) { $fgrid["$rowIdx,$colIdx"] = '=' + $fNode.InnerText }
            }
        }

        # sanitize ชื่อไฟล์
        $safe = ($sh.Name -replace '[\\/:*?"<>|]', '_').Trim()
        $valPath = Join-Path $OutDir ("{0:00}_{1}.values.csv" -f $i, $safe)
        $fPath   = Join-Path $OutDir ("{0:00}_{1}.formulas.csv" -f $i, $safe)

        # เขียน values.csv
        $vsb = New-Object System.Text.StringBuilder
        for ($r = 1; $r -le $maxRow; $r++) {
            $line = for ($c = 1; $c -le $maxCol; $c++) { Format-Csv ([string]$grid["$r,$c"]) }
            [void]$vsb.AppendLine(($line -join ','))
        }
        [System.IO.File]::WriteAllText($valPath, $vsb.ToString(), (New-Object System.Text.UTF8Encoding($true)))

        # เขียน formulas.csv (เฉพาะ sheet ที่มีสูตร)
        $hasF = $fgrid.Count -gt 0
        if ($hasF) {
            $fsb = New-Object System.Text.StringBuilder
            [void]$fsb.AppendLine("Cell,Formula")
            foreach ($k in ($fgrid.Keys | Sort-Object { [int]($_ -split ',')[0] }, { [int]($_ -split ',')[1] })) {
                $parts = $k -split ','
                # แปลง index กลับเป็น A1 reference แบบง่าย
                $cn = [int]$parts[1]; $colLetters = ''
                while ($cn -gt 0) { $m = ($cn - 1) % 26; $colLetters = [char](65 + $m) + $colLetters; $cn = [int][math]::Floor(($cn - 1) / 26) }
                $cellRef = "$colLetters$($parts[0])"
                [void]$fsb.AppendLine((Format-Csv $cellRef) + ',' + (Format-Csv $fgrid[$k]))
            }
            [System.IO.File]::WriteAllText($fPath, $fsb.ToString(), (New-Object System.Text.UTF8Encoding($true)))
        }

        [void]$index.AppendLine("| $i | $($sh.Name) | $maxRow | $maxCol | $(if($hasF){'✓'}else{'-'}) |")
        Write-Host ("  [{0:00}] {1,-35} rows={2,-5} cols={3,-3} formulas={4}" -f $i, $sh.Name, $maxRow, $maxCol, $(if($hasF){$fgrid.Count}else{0}))
    }

    [System.IO.File]::WriteAllText((Join-Path $OutDir '_INDEX.md'), $index.ToString(), (New-Object System.Text.UTF8Encoding($true)))
    Write-Host "`nเสร็จสิ้น -> $OutDir" -ForegroundColor Green
}
finally {
    $zip.Dispose()
}
