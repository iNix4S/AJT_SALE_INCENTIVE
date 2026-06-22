# Chat Log

Date: 2026-06-12
File: claude_2026.06.12_001.md

- Notes:
ได้ครับ ผมสามารถอ่านไฟล์ .xlsx ได้ ขอดูว่ามีไฟล์อะไรบ้างในโฟลเดอร์ก่อนนะครับ

Globpattern: "1.General Documents/**/*.xlsx"
Found 2 files
Globpattern: "1.General Documents/**/*"
Found 5 files
มีไฟล์ .xlsx อยู่ 2 ไฟล์ครับ ผมจะลองอ่านดูเนื้อหา ขอตรวจสอบเครื่องมือที่ใช้อ่านก่อนนะครับ

Bash Check for Python xlsx libraries
IN
python -c "import openpyxl; print('openpyxl OK')" 2>&1; python -c "import pandas; print('pandas OK')" 2>&1

OUT
Exit code 49
Python was not found; run without arguments to install from the Microsoft Store, or disable this shortcut from Settings > Apps > Advanced app settings > App execution aliases.
Python was not found; run without arguments to install from the Microsoft Store, or disable this shortcut from Settings > Apps > Advanced app settings > App execution aliases.
PowerShell Check available interpreters
IN
(Get-Command python3, py, python -ErrorAction SilentlyContinue | Select-Object Name, Source); "---"; (Get-Command node -ErrorAction SilentlyContinue | Select-Object Name, Source)

OUT
Exit code 1
Name        Source
----        ------
python3.exe C:\Users\wimut\AppData\Local\Microsoft\WindowsApps\python3.exe
python.exe  C:\Users\wimut\AppData\Local\Microsoft\WindowsApps\python.exe
---
ไม่มี Python/Node ที่ใช้งานได้จริงครับ แต่ไฟล์ .xlsx เป็น zip archive ที่มี XML อยู่ข้างใน ผมจะอ่านโดยแตกไฟล์ออกมาแล้ว parse XML ผ่าน .NET ใน PowerShell ครับ

PowerShell List internal entries of xlsx files
IN
Add-Type -AssemblyName System.IO.Compression.FileSystem
$base = "d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\1.General Documents"
Get-ChildItem -Path $base -Filter *.xlsx | ForEach-Object {
  $z = [System.IO.Compression.ZipFile]::OpenRead($_.FullName)
  "=== $($_.Name) ==="
  $z.Entries | Select-Object FullName, Length | Format-Table -AutoSize | Out-String
  $z.Dispose()
}

OUT
=== For Test_New Sales Incentive Scheme All Product_New formula_MT.xlsx ===

FullName                                       Length
--------                                       ------
[Content_Types].xml                              6101
_rels/.rels                                       588
xl/workbook.xml                                  5590
xl/_rels/workbook.xml.rels                       5544
xl/worksheets/sheet4.xml                         5829
xl/worksheets/sheet5.xml                        30299
xl/worksheets/sheet6.xml                         4518
xl/worksheets/sheet7.xml                         4816
xl/worksheets/sheet8.xml                         2024
xl/worksheets/sheet9.xml                         1881
xl/worksheets/sheet10.xml                        2332
xl/worksheets/sheet11.xml                       18719
xl/worksheets/sheet12.xml                       41542
xl/worksheets/sheet13.xml                     2265484
xl/worksheets/sheet14.xml                     1072534
xl/worksheets/sheet15.xml                      581483
xl/worksheets/sheet16.xml                      296758
xl/worksheets/sheet17.xml                       24491
xl/worksheets/sheet18.xml                      167052
xl/worksheets/sheet19.xml                        7402
xl/worksheets/sheet20.xml                       80372
xl/worksheets/sheet21.xml                     1329734
xl/worksheets/sheet22.xml                        2460
xl/worksheets/sheet23.xml                        2117
xl/worksheets/sheet24.xml                      218043
xl/worksheets/sheet25.xml                       21649
xl/worksheets/sheet26.xml                      237043
xl/worksheets/sheet27.xml                       20905
xl/worksheets/sheet28.xml                      234101
xl/worksheets/sheet29.xml                       20140
xl/worksheets/sheet30.xml                      233270
xl/worksheets/sheet31.xml                       19963
xl/worksheets/sheet32.xml                        1040
xl/theme/theme1.xml                              8721
xl/styles.xml                                   64387
xl/sharedStrings.xml                            15290
xl/drawings/drawing1.xml                         1215
xl/media/image1.png                            168370
xl/worksheets/sheet1.xml                        29812
xl/worksheets/sheet2.xml                        29633
xl/worksheets/sheet3.xml                        29690
xl/worksheets/_rels/sheet4.xml.rels               299
xl/worksheets/_rels/sheet10.xml.rels              322
xl/worksheets/_rels/sheet12.xml.rels              322
xl/worksheets/_rels/sheet14.xml.rels              322
xl/worksheets/_rels/sheet20.xml.rels              322
xl/worksheets/_rels/sheet21.xml.rels              322
xl/drawings/_rels/drawing1.xml.rels               292
xl/metadata.xml                                   733
xl/printerSettings/printerSettings1.bin          1312
xl/printerSettings/printerSettings2.bin          1312
xl/printerSettings/printerSettings3.bin          1312
xl/printerSettings/printerSettings4.bin          1312
xl/externalLinks/externalLink1.xml              24385
xl/calcChain.xml                               650633
docProps/core.xml                                 817
xl/externalLinks/_rels/externalLink1.xml.rels     691
docProps/app.xml                                 1895
xl/printerSettings/printerSettings5.bin          1312


=== For Test_Pain_New Sales Incentive Scheme All Product_New formula_TT.xlsx ===

FullName                                       Length
--------                                       ------
[Content_Types].xml                              5555
_rels/.rels                                       732
xl/workbook.xml                                  4470
xl/_rels/workbook.xml.rels                       4686
xl/worksheets/sheet4.xml                         5852
xl/worksheets/sheet5.xml                        30573
xl/worksheets/sheet6.xml                         4950
xl/worksheets/sheet7.xml                         1995
xl/worksheets/sheet8.xml                         1850
xl/worksheets/sheet9.xml                        50035
xl/worksheets/sheet10.xml                        2283
xl/worksheets/sheet11.xml                     3445643
xl/worksheets/sheet12.xml                       32379
xl/worksheets/sheet13.xml                       21933
xl/worksheets/sheet14.xml                       74480
xl/worksheets/sheet15.xml                       85031
xl/worksheets/sheet16.xml                        9186
xl/worksheets/sheet17.xml                        2525
xl/worksheets/sheet18.xml                      226273
xl/worksheets/sheet19.xml                       21624
xl/worksheets/sheet20.xml                      237059
xl/worksheets/sheet21.xml                       20892
xl/worksheets/sheet22.xml                      234120
xl/worksheets/sheet23.xml                       20125
xl/worksheets/sheet24.xml                      233262
xl/worksheets/sheet25.xml                       19901
xl/worksheets/sheet26.xml                        1019
xl/theme/theme1.xml                              8721
xl/styles.xml                                   71770
xl/sharedStrings.xml                            10897
xl/drawings/drawing1.xml                         1218
xl/media/image1.png                            168370
xl/drawings/vmlDrawing1.vml                      1185
xl/worksheets/sheet1.xml                        29979
xl/worksheets/sheet2.xml                        29917
xl/worksheets/sheet3.xml                        29958
xl/worksheets/_rels/sheet4.xml.rels               299
docProps/thumbnail.emf                          20856
xl/worksheets/_rels/sheet12.xml.rels              322
xl/worksheets/_rels/sheet15.xml.rels              322
xl/worksheets/_rels/sheet16.xml.rels              605
xl/drawings/_rels/drawing1.xml.rels               292
xl/worksheets/_rels/sheet11.xml.rels              322
docProps/app.xml                                 1552
xl/printerSettings/printerSettings1.bin          1692
xl/printerSettings/printerSettings2.bin          1692
xl/printerSettings/printerSettings3.bin          1312
xl/printerSettings/printerSettings4.bin          1312
xl/externalLinks/externalLink1.xml              75511
xl/comments1.xml                                  771
xl/calcChain.xml                               409040
xl/externalLinks/_rels/externalLink1.xml.rels     426
xl/metadata.xml                                   733
docProps/core.xml                                 621
อ่านได้ครับ ทั้งสองไฟล์มีหลาย sheet ผมจะดึงชื่อ sheet และข้อความ (shared strings) เพื่อเข้าใจโครงสร้างก่อน

PowerShell Extract sheet names from workbook.xml
IN
Add-Type -AssemblyName System.IO.Compression.FileSystem
$base = "d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\1.General Documents"
function Get-Entry($zip,$name){ $z=[System.IO.Compression.ZipFile]::OpenRead($zip); $e=$z.Entries|?{$_.FullName -eq $name}; $r=New-Object IO.StreamReader($e.Open()); $t=$r.ReadToEnd(); $r.Close(); $z.Dispose(); return $t }
Get-ChildItem -Path $base -Filter *.xlsx | ForEach-Object {
  "############ $($_.Name) ############"
  $wb = Get-Entry $_.FullName 'xl/workbook.xml'
  [regex]::Matches($wb,'<sheet[^>]*name="([^"]*)"[^>]*sheetId="([^"]*)"') | ForEach-Object { "  sheetId=$($_.Groups[2].Value)  name=$($_.Groups[1].Value)" }
}

OUT
############ For Test_New Sales Incentive Scheme All Product_New formula_MT.xlsx ############
  sheetId=2  name=Top WS
  sheetId=10  name= WS SF
  sheetId=9  name=WS WH
  sheetId=4  name=Test
  sheetId=26  name=SF WH
  sheetId=23  name=Guide
  sheetId=20  name=M_Month
  sheetId=28  name=Product
  sheetId=22  name=T_SectAbove
  sheetId=21  name=Period
  sheetId=19  name=ASTBase
  sheetId=32  name=2) หลักการคำนวน Table
  sheetId=14  name=3)Target &amp; Cal_Staff
  sheetId=33  name=3)Target &amp; Cal_Sect
  sheetId=34  name=3)Target &amp; Cal_Dept
  sheetId=35  name=3)Target &amp; Cal_AD
  sheetId=18  name=HR Rep
  sheetId=15  name=Actual
  sheetId=37  name=Mapping
  sheetId=17  name=1) For HR
  sheetId=29  name=1) For HR (FIX)
  sheetId=24  name=Shortage
  sheetId=30  name=ค่าตอบแทนการขายในอัตราคงที่
  sheetId=1  name=Aji Plus
  sheetId=3  name=Actual_Aji Plus
  sheetId=5  name=RDQ
  sheetId=6  name=Actual_RDQ
  sheetId=7  name=RDM
  sheetId=8  name=Actual_RDM
  sheetId=12  name=RDNS
  sheetId=13  name=Actual_RDNS
  sheetId=11  name=Sales Target
############ For Test_Pain_New Sales Incentive Scheme All Product_New formula_TT.xlsx ############
  sheetId=2  name=Top WS
  sheetId=10  name= WS SF
  sheetId=9  name=WS WH
  sheetId=4  name=Test
  sheetId=26  name=SF WH
  sheetId=20  name=M_Month
  sheetId=28  name=Product
  sheetId=22  name=T_SectAbove
  sheetId=16  name=2) หลักการคำนวน Table
  sheetId=21  name=Period
  sheetId=14  name=3)Target &amp; Cal
  sheetId=15  name=Actual
  sheetId=19  name=ASTBase
  sheetId=18  name=HR Rep
  sheetId=17  name=1) For HR
  sheetId=31  name=1) For HR (AD)
  sheetId=24  name=Shortage
  sheetId=1  name=Aji Plus
  sheetId=3  name=Actual_Aji Plus
  sheetId=5  name=RDQ
  sheetId=6  name=Actual_RDQ
  sheetId=7  name=RDM
  sheetId=8  name=Actual_RDM
  sheetId=12  name=RDNS
  sheetId=13  name=Actual_RDNS
  sheetId=11  name=Sales Target
อ่านได้ครับ ✅ ผมยืนยันว่าสามารถอ่านไฟล์ .xlsx ทั้งสองไฟล์ได้ โดยแตก XML ข้างในออกมา parse แม้เครื่องนี้จะไม่มี Python/Node ก็ตาม

นี่คือภาพรวมโครงสร้างที่อ่านได้:

ไฟล์ที่ 1 — ..._New formula_MT.xlsx (ช่องทาง MT)
มี 30 sheets เช่น:

Top WS, WS SF, WS WH, SF WH — worksheet หลัก/working sheet
Guide, 2) หลักการคำนวน Table — คำอธิบายหลักการคำนวณ
3)Target & Cal_Staff / _Sect / _Dept / _AD — การคำนวณ target แยกตามระดับ (พนักงาน/แผนก/ฝ่าย/AD)
1) For HR, 1) For HR (FIX), HR Rep — ส่วนสำหรับ HR
Product, Period, M_Month, Mapping, ASTBase — ตารางอ้างอิง (master data)
Aji Plus, RDQ, RDM, RDNS + Actual_* แต่ละตัว — กลุ่มสินค้าและยอดจริง
Sales Target, Actual, Shortage, ค่าตอบแทนการขายในอัตราคงที่
ไฟล์ที่ 2 — ..._Pain_..._TT.xlsx (ช่องทาง TT)
โครงสร้างคล้ายกัน 26 sheets ต่างที่:

3)Target & Cal (รวมเป็น sheet เดียว แทนที่จะแยก Staff/Sect/Dept/AD)
1) For HR (AD) แทน FIX
มี comments อยู่ใน sheet ด้วย
ทั้งสองไฟล์เป็น โมเดลคำนวณ Sales Incentive แบบใหม่ (New formula) แยกตามช่องทาง MT (Modern Trade) และ TT (Traditional Trade) — มีสูตรเชื่อมโยงข้าม sheet จำนวนมาก (calcChain ใหญ่มาก) และอ้างอิงไฟล์ภายนอก (externalLinks)

อยากให้ผมเจาะลึก sheet ไหนเป็นพิเศษครับ? เช่น:

"2) หลักการคำนวน Table" หรือ Guide — เพื่อเข้าใจตรรกะการคำนวณก่อน
"3)Target & Cal_*" — ดูสูตรการคำนวณ incentive จริง
ดึงเนื้อหาทุก sheet ออกมาเป็นข้อความ/CSV เพื่อใช้อ้างอิงในการพัฒนาระบบ
สร้าง folder project structure เพื่อสำหรับงานอ่าน และทำความเข้าใจในไฟล์ .xlsx ให้สร้างเอาไว้ที่ D:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design
Bash Inspect project root and target folder
IN
cd "d:/Users/wimut/OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED/My Projects/28.AJT New Sale Incentive" && ls -la && echo "--- 4.System folder? ---" && ls -la "4.System Analyst and Design" 2>&1

OUT
total 20
drwxr-xr-x 1 wimut 197609    0 Jun 12 22:13 .
drwxr-xr-x 1 wimut 197609    0 Jun 12 12:05 ..
drwxr-xr-x 1 wimut 197609    0 Jun 12 14:05 .github
drwxr-xr-x 1 wimut 197609    0 Jun 12 14:22 1.General Documents
drwxr-xr-x 1 wimut 197609    0 Jun 12 14:17 2.Planning
drwxr-xr-x 1 wimut 197609    0 Jun 12 14:17 3.Estimate Manday(s)
drwxr-xr-x 1 wimut 197609    0 Jun 12 14:17 4.System Analyst and Design
drwxr-xr-x 1 wimut 197609    0 Jun 12 22:14 5.Docs
-rw-r--r-- 1 wimut 197609 2792 Jun 12 14:33 README.md
--- 4.System folder? ---
total 8
drwxr-xr-x 1 wimut 197609 0 Jun 12 14:17 .
drwxr-xr-x 1 wimut 197609 0 Jun 12 22:13 ..
Read d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\README.md
เข้าใจบริบทโครงการแล้วครับ โฟลเดอร์ 4.System Analyst and Design มีไว้สำหรับงาน SA (BRD/SRS/Data Mapping ฯลฯ) และตอนนี้ยังว่างอยู่ ผมจะสร้างโครงสร้างย่อยที่ออกแบบมาเพื่อ "อ่านและทำความเข้าใจไฟล์ .xlsx" โดยเฉพาะ พร้อมเครื่องมือ extract ที่ใช้ซ้ำได้

เริ่มจากสร้างโฟลเดอร์:

PowerShell Create SA subfolder structure
IN
$root = "d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design"
$dirs = @(
  "00.Extraction-Tools",
  "01.Raw-Extracts\MT",
  "01.Raw-Extracts\TT",
  "02.Sheet-Understanding\MT",
  "02.Sheet-Understanding\TT",
  "03.Calculation-Logic",
  "04.Data-Dictionary",
  "05.Process-Flow"
)
foreach($d in $dirs){ New-Item -ItemType Directory -Force -Path (Join-Path $root $d) | Out-Null }
Get-ChildItem -Path $root -Recurse -Directory | Select-Object FullName

OUT
FullName
--------
D:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst an…
D:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst an…
D:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst an…
D:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst an…
D:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst an…
D:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst an…
D:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst an…
D:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst an…
D:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst an…
D:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst an…
โฟลเดอร์สร้างครบแล้ว ต่อไปสร้างเครื่องมือ extract และเอกสารกำกับแต่ละโฟลเดอร์:

Write d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\00.Extraction-Tools\Extract-Xlsx.ps1
182 lines
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
Now let me test the extraction script on both files to confirm it works:

PowerShell Run extraction on both xlsx files
IN
$sa = "d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design"
$src = "d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\1.General Documents"
Write-Host "===== MT ====="
& "$sa\00.Extraction-Tools\Extract-Xlsx.ps1" -XlsxPath "$src\For Test_New Sales Incentive Scheme All Product_New formula_MT.xlsx" -OutDir "$sa\01.Raw-Extracts\MT"
Write-Host "`n===== TT ====="
& "$sa\00.Extraction-Tools\Extract-Xlsx.ps1" -XlsxPath "$src\For Test_Pain_New Sales Incentive Scheme All Product_New formula_TT.xlsx" -OutDir "$sa\01.Raw-Extracts\TT"

OUT
===== MT =====
  [01] Top WS                              rows=48    cols=27  formulas=222
  [02]  WS SF                              rows=48    cols=27  formulas=222
  [03] WS WH                               rows=48    cols=27  formulas=222
  [04] Test                                rows=5     cols=23  formulas=20
  [05] SF WH                               rows=48    cols=27  formulas=222
  [06] Guide                               rows=25    cols=3   formulas=0
  [07] M_Month                             rows=22    cols=4   formulas=0
  [08] Product                             rows=12    cols=1   formulas=0
  [09] T_SectAbove                         rows=5     cols=2   formulas=0
  [10] Period                              rows=2     cols=4   formulas=3
  [11] ASTBase                             rows=28    cols=19  formulas=0
  [12] 2) หลักการคำนวน Table               rows=50    cols=26  formulas=243
  [13] 3)Target & Cal_Staff                rows=165   cols=66  formulas=5990
  [14] 3)Target & Cal_Sect                 rows=151   cols=66  formulas=3372
  [15] 3)Target & Cal_Dept                 rows=55    cols=66  formulas=1766
  [16] 3)Target & Cal_AD                   rows=37    cols=66  formulas=855
  [17] HR Rep                              rows=29    cols=29  formulas=28
  [18] Actual                              rows=222   cols=16  formulas=442
  [19] Mapping                             rows=25    cols=4   formulas=24
  [20] 1) For HR                           rows=35    cols=19  formulas=405
  [21] 1) For HR (FIX)                     rows=520   cols=14  formulas=5665
  [22] Shortage                            rows=4     cols=13  formulas=0
  [23] ค่าตอบแทนการขายในอัตราคงที่         rows=8     cols=2   formulas=0
  [24] Aji Plus                            rows=58    cols=68  formulas=2109
  [25] Actual_Aji Plus                     rows=62    cols=8   formulas=0
  [26] RDQ                                 rows=58    cols=69  formulas=2621
  [27] Actual_RDQ                          rows=62    cols=8   formulas=0
  [28] RDM                                 rows=58    cols=68  formulas=2565
  [29] Actual_RDM                          rows=63    cols=8   formulas=0
  [30] RDNS                                rows=58    cols=68  formulas=2564
  [31] Actual_RDNS                         rows=62    cols=8   formulas=0
  [32] Sales Target                        rows=0     cols=0   formulas=0

เสร็จสิ้น -> d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\01.Raw-Extracts\MT

===== TT =====
  [01] Top WS                              rows=48    cols=27  formulas=224
  [02]  WS SF                              rows=48    cols=27  formulas=224
  [03] WS WH                               rows=48    cols=27  formulas=224
  [04] Test                                rows=5     cols=23  formulas=21
  [05] SF WH                               rows=48    cols=27  formulas=224
  [06] M_Month                             rows=22    cols=4   formulas=0
  [07] Product                             rows=12    cols=1   formulas=0
  [08] T_SectAbove                         rows=5     cols=2   formulas=0
  [09] 2) หลักการคำนวน Table               rows=108   cols=16  formulas=655
  [10] Period                              rows=2     cols=4   formulas=3
  [11] 3)Target & Cal                      rows=158   cols=66  formulas=7650
  [12] Actual                              rows=146   cols=14  formulas=0
  [13] ASTBase                             rows=23    cols=19  formulas=88
  [14] HR Rep                              rows=91    cols=29  formulas=0
  [15] 1) For HR                           rows=23    cols=24  formulas=440
  [16] 1) For HR (AD)                      rows=9     cols=28  formulas=22
  [17] Shortage                            rows=4     cols=13  formulas=0
  [18] Aji Plus                            rows=58    cols=68  formulas=2223
  [19] Actual_Aji Plus                     rows=62    cols=8   formulas=0
  [20] RDQ                                 rows=58    cols=69  formulas=2621
  [21] Actual_RDQ                          rows=62    cols=8   formulas=0
  [22] RDM                                 rows=58    cols=68  formulas=2565
  [23] Actual_RDM                          rows=63    cols=8   formulas=0
  [24] RDNS                                rows=58    cols=68  formulas=2564
  [25] Actual_RDNS                         rows=62    cols=8   formulas=0
  [26] Sales Target                        rows=0     cols=0   formulas=0

เสร็จสิ้น -> d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\01.Raw-Extracts\TT
ทำงานได้สมบูรณ์ — extract ครบทุก sheet พร้อมแยก ค่า (values) และ สูตร (formulas) ออกมาเป็น CSV แล้ว ตอนนี้สร้างเอกสารกำกับโครงสร้าง:

Write d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\README.md
47 lines
# 4. System Analyst and Design

โฟลเดอร์นี้ใช้สำหรับงานวิเคราะห์และออกแบบระบบ (SA) ของโครงการ AJT New Sale Incentive
โดยมีจุดเริ่มต้นที่งาน **"อ่านและทำความเข้าใจไฟล์ .xlsx ต้นฉบับ"** จาก `1.General Documents`
เพื่อถอดตรรกะการคำนวณ Incentive ออกมาเป็นเอกสารที่นำไปออกแบบระบบต่อได้

## ไฟล์ต้นฉบับที่วิเคราะห์
| ช่องทาง | ไฟล์ต้นฉบับ (ใน `1.General Documents`) |
|---------|------------------------------------------|
| MT (Modern Trade) | `For Test_New Sales Incentive Scheme All Product_New formula_MT.xlsx` |
| TT (Traditional Trade) | `For Test_Pain_New Sales Incentive Scheme All Product_New formula_TT.xlsx` |

> ⚠️ ไม่แก้ไขไฟล์ต้นฉบับโดยตรง — งานทั้งหมดทำบนข้อมูลที่ extract ออกมาแล้วเท่านั้น

## โครงสร้างโฟลเดอร์

| โฟลเดอร์ | วัตถุประสงค์ |
|----------|--------------|
| `00.Extraction-Tools` | สคริปต์ `Extract-Xlsx.ps1` สำหรับแตกข้อมูล .xlsx เป็น CSV (ไม่ต้องใช้ Excel/Python) |
| `01.Raw-Extracts` | ผลลัพธ์ที่ extract แล้ว แยกเป็น `MT/` และ `TT/` — มีทั้ง `.values.csv` (ค่า) และ `.formulas.csv` (สูตร) ราย sheet พร้อม `_INDEX.md` |
| `02.Sheet-Understanding` | บันทึกความเข้าใจราย sheet (สรุปว่า sheet นี้ทำอะไร, input/output, จุดสำคัญ) |
| `03.Calculation-Logic` | สรุปตรรกะการคำนวณ Incentive ทั้ง flow (target, actual, achievement %, payout) |
| `04.Data-Dictionary` | พจนานุกรมข้อมูล — นิยาม field, ตาราง master, ความหมายของ code/ค่าต่าง ๆ |
| `05.Process-Flow` | แผนภาพ/คำอธิบายลำดับการไหลของข้อมูลและการคำนวณข้าม sheet |

## วิธีใช้เครื่องมือ extract

เปิด PowerShell ที่โฟลเดอร์ `00.Extraction-Tools` แล้วรัน:

```powershell
.\Extract-Xlsx.ps1 `
  -XlsxPath "..\..\1.General Documents\For Test_New Sales Incentive Scheme All Product_New formula_MT.xlsx" `
  -OutDir   "..\01.Raw-Extracts\MT"
```

ผลลัพธ์ต่อ sheet:
- `NN_<ชื่อ sheet>.values.csv` — ค่าที่คำนวณ/แสดงผล (resolve ข้อความ shared string แล้ว)
- `NN_<ชื่อ sheet>.formulas.csv` — รายการเซลล์ที่มีสูตร (`Cell, Formula`) เพื่อใช้ถอดตรรกะ
- `_INDEX.md` — สรุปรายชื่อ sheet + จำนวนแถว/คอลัมน์ + มีสูตรหรือไม่

## ลำดับการทำงานที่แนะนำ
1. รัน `Extract-Xlsx.ps1` ทั้ง MT และ TT → ได้ข้อมูลใน `01.Raw-Extracts`
2. ไล่อ่าน `_INDEX.md` เพื่อเห็นภาพรวมทุก sheet
3. บันทึกความเข้าใจราย sheet ลง `02.Sheet-Understanding`
4. รวบยอดตรรกะการคำนวณลง `03.Calculation-Logic` และ field ลง `04.Data-Dictionary`
5. วาด flow ภาพรวมลง `05.Process-Flow`
Now the placeholder/template docs for the analysis folders:

Write d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\02.Sheet-Understanding\_TEMPLATE.md
23 lines
# Sheet: <ชื่อ sheet>

- **ไฟล์ต้นทาง:** MT / TT
- **ประเภท:** Master Data / Input / Calculation / Output / Reference
- **จำนวนแถว x คอลัมน์:** _

## วัตถุประสงค์ของ sheet
อธิบายว่า sheet นี้ทำหน้าที่อะไรในภาพรวมการคำนวณ Incentive

## Input (รับข้อมูลจากไหน)
- มาจาก sheet/ไฟล์ภายนอกใด, เซลล์/ช่วงใด

## Output (ส่งข้อมูลไปไหน)
- ถูกอ้างอิงโดย sheet ใดบ้าง

## สูตร/ตรรกะสำคัญ
| เซลล์ | สูตร | ความหมาย |
|-------|------|----------|
| | | |

## ข้อสังเกต / คำถามค้างคา
- ประเด็นที่ต้องยืนยันกับลูกค้า/Business
Write d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\03.Calculation-Logic\README.md
15 lines
# 03. Calculation Logic

รวบรวมตรรกะการคำนวณ Sales Incentive ที่ถอดได้จากไฟล์ .xlsx ทั้ง MT และ TT
เป้าหมายคือเปลี่ยนสูตรใน Excel ให้เป็นกฎเชิงธุรกิจ (business rules) ที่นำไปพัฒนาระบบได้

## หัวข้อที่ต้องสรุป
- โครงสร้างกลุ่มสินค้า: Aji Plus / RDQ / RDM / RDNS
- การกำหนด **Target** (ราย Staff / Section / Dept / AD)
- การเก็บ **Actual** และการคำนวณ **% Achievement**
- ตารางอัตรา/ขั้นบันได payout ("2) หลักการคำนวน Table")
- เงื่อนไข Shortage และค่าตอบแทนในอัตราคงที่
- ความต่างของกฎระหว่างช่องทาง **MT** กับ **TT**

> อ้างอิงสูตรดิบได้จาก `01.Raw-Extracts/<MT|TT>/*.formulas.csv`
Write d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\04.Data-Dictionary\README.md
15 lines
# 04. Data Dictionary

นิยามข้อมูลที่ใช้ในโมเดลการคำนวณ Incentive เพื่อใช้อ้างอิงตอนออกแบบฐานข้อมูล/โครงสร้างระบบ

## รูปแบบที่แนะนำ
| Field | ชื่อไทย | ประเภท | ที่มา (sheet/คอลัมน์) | ความหมาย / ค่าที่เป็นไปได้ |
|-------|---------|--------|------------------------|-----------------------------|
| | | | | |

## ตาราง Master ที่พบในไฟล์
- `Product` — รายการกลุ่มสินค้า
- `M_Month`, `Period` — มิติเวลา/รอบคำนวณ
- `Mapping` — การ map ระหว่างรหัส/ชื่อ
- `T_SectAbove`, `ASTBase` — ฐานข้อมูลโครงสร้างองค์กร/ฐานคำนวณ
Write d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\05.Process-Flow\README.md
20 lines
# 05. Process Flow

แผนภาพและคำอธิบายลำดับการไหลของข้อมูล/การคำนวณข้าม sheet
ตั้งแต่การนำเข้า Target & Actual จนถึงผลลัพธ์ Incentive ที่ส่งให้ HR

## สิ่งที่ควรมี
- Data Flow ภาพรวม: แหล่งข้อมูล → คำนวณ → output (1) For HR)
- ลำดับการคำนวณข้าม sheet (dependency chain)
- จุดเชื่อมต่อกับไฟล์ภายนอก (externalLinks ที่พบในไฟล์ต้นฉบับ)
- ความต่างของ flow ระหว่าง MT และ TT

> แนะนำเขียน diagram ด้วย Mermaid เพื่อให้แก้ไข/รีวิวง่าย เช่น:
>
> ```mermaid
> flowchart LR
>   Target --> Cal
>   Actual --> Cal
>   Cal --> ForHR[1) For HR]
> ```
เสร็จแล้ว ขอแสดงโครงสร้างทั้งหมดที่สร้าง:

PowerShell Show final folder tree
IN
$root = "d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design"
Get-ChildItem -Path $root -Recurse | Sort-Object FullName | ForEach-Object {
  $rel = $_.FullName.Substring($root.Length+1)
  if ($_.PSIsContainer) { "[DIR]  $rel" } else { "       $rel  ($([math]::Round($_.Length/1KB,1)) KB)" }
}

OUT
[DIR]  00.Extraction-Tools
       00.Extraction-Tools\Extract-Xlsx.ps1  (8.3 KB)
[DIR]  01.Raw-Extracts
[DIR]  01.Raw-Extracts\MT
       01.Raw-Extracts\MT\_INDEX.md  (1.4 KB)
       01.Raw-Extracts\MT\01_Top WS.formulas.csv  (2 KB)
       01.Raw-Extracts\MT\01_Top WS.values.csv  (3.2 KB)
       01.Raw-Extracts\MT\02_WS SF.formulas.csv  (2 KB)
       01.Raw-Extracts\MT\02_WS SF.values.csv  (3.3 KB)
       01.Raw-Extracts\MT\03_WS WH.formulas.csv  (2 KB)
       01.Raw-Extracts\MT\03_WS WH.values.csv  (3.4 KB)
       01.Raw-Extracts\MT\04_Test.formulas.csv  (1 KB)
       01.Raw-Extracts\MT\04_Test.values.csv  (0.5 KB)
       01.Raw-Extracts\MT\05_SF WH.formulas.csv  (2 KB)
       01.Raw-Extracts\MT\05_SF WH.values.csv  (4 KB)
       01.Raw-Extracts\MT\06_Guide.values.csv  (1.1 KB)
       01.Raw-Extracts\MT\07_M_Month.values.csv  (0.5 KB)
       01.Raw-Extracts\MT\08_Product.values.csv  (0.1 KB)
       01.Raw-Extracts\MT\09_T_SectAbove.values.csv  (0.1 KB)
       01.Raw-Extracts\MT\10_Period.formulas.csv  (0.1 KB)
       01.Raw-Extracts\MT\10_Period.values.csv  (0.2 KB)
       01.Raw-Extracts\MT\11_ASTBase.values.csv  (2.3 KB)
       01.Raw-Extracts\MT\12_2) หลักการคำนวน Table.formulas.csv  (1.7 KB)
       01.Raw-Extracts\MT\12_2) หลักการคำนวน Table.values.csv  (7.2 KB)
       01.Raw-Extracts\MT\13_3)Target & Cal_Staff.formulas.csv  (1836.5 KB)
       01.Raw-Extracts\MT\13_3)Target & Cal_Staff.values.csv  (46.1 KB)
       01.Raw-Extracts\MT\14_3)Target & Cal_Sect.formulas.csv  (859.3 KB)
       01.Raw-Extracts\MT\14_3)Target & Cal_Sect.values.csv  (23.6 KB)
       01.Raw-Extracts\MT\15_3)Target & Cal_Dept.formulas.csv  (445.8 KB)
       01.Raw-Extracts\MT\15_3)Target & Cal_Dept.values.csv  (11.6 KB)
       01.Raw-Extracts\MT\16_3)Target & Cal_AD.formulas.csv  (215.5 KB)
       01.Raw-Extracts\MT\16_3)Target & Cal_AD.values.csv  (7.1 KB)
       01.Raw-Extracts\MT\17_HR Rep.formulas.csv  (0.4 KB)
       01.Raw-Extracts\MT\17_HR Rep.values.csv  (2.2 KB)
       01.Raw-Extracts\MT\18_Actual.formulas.csv  (14.3 KB)
       01.Raw-Extracts\MT\18_Actual.values.csv  (38.7 KB)
       01.Raw-Extracts\MT\19_Mapping.formulas.csv  (0.2 KB)
       01.Raw-Extracts\MT\19_Mapping.values.csv  (1 KB)
       01.Raw-Extracts\MT\20_1) For HR.formulas.csv  (58.2 KB)
       01.Raw-Extracts\MT\20_1) For HR.values.csv  (3.1 KB)
       01.Raw-Extracts\MT\21_1) For HR (FIX).formulas.csv  (1088.3 KB)
       01.Raw-Extracts\MT\21_1) For HR (FIX).values.csv  (17 KB)
       01.Raw-Extracts\MT\22_Shortage.values.csv  (0.1 KB)
       01.Raw-Extracts\MT\23_ค่าตอบแทนการขายในอัตราคงที่.values.csv  (0.4 KB)
       01.Raw-Extracts\MT\24_Aji Plus.formulas.csv  (53.2 KB)
       01.Raw-Extracts\MT\24_Aji Plus.values.csv  (37.6 KB)
       01.Raw-Extracts\MT\25_Actual_Aji Plus.values.csv  (6.9 KB)
       01.Raw-Extracts\MT\26_RDQ.formulas.csv  (72.3 KB)
       01.Raw-Extracts\MT\26_RDQ.values.csv  (36.1 KB)
       01.Raw-Extracts\MT\27_Actual_RDQ.values.csv  (6.6 KB)
       01.Raw-Extracts\MT\28_RDM.formulas.csv  (71.9 KB)
       01.Raw-Extracts\MT\28_RDM.values.csv  (36.3 KB)
       01.Raw-Extracts\MT\29_Actual_RDM.values.csv  (5.4 KB)
       01.Raw-Extracts\MT\30_RDNS.formulas.csv  (72.2 KB)
       01.Raw-Extracts\MT\30_RDNS.values.csv  (35.1 KB)
       01.Raw-Extracts\MT\31_Actual_RDNS.values.csv  (5.7 KB)
       01.Raw-Extracts\MT\32_Sales Target.values.csv  (0 KB)
[DIR]  01.Raw-Extracts\TT
       01.Raw-Extracts\TT\_INDEX.md  (1.1 KB)
       01.Raw-Extracts\TT\01_Top WS.formulas.csv  (2 KB)
       01.Raw-Extracts\TT\01_Top WS.values.csv  (3.1 KB)
       01.Raw-Extracts\TT\02_WS SF.formulas.csv  (2 KB)
       01.Raw-Extracts\TT\02_WS SF.values.csv  (3.3 KB)
       01.Raw-Extracts\TT\03_WS WH.formulas.csv  (2 KB)
       01.Raw-Extracts\TT\03_WS WH.values.csv  (3.4 KB)
       01.Raw-Extracts\TT\04_Test.formulas.csv  (1.1 KB)
       01.Raw-Extracts\TT\04_Test.values.csv  (0.5 KB)
       01.Raw-Extracts\TT\05_SF WH.formulas.csv  (2 KB)
       01.Raw-Extracts\TT\05_SF WH.values.csv  (3.9 KB)
       01.Raw-Extracts\TT\06_M_Month.values.csv  (0.5 KB)
       01.Raw-Extracts\TT\07_Product.values.csv  (0.1 KB)
       01.Raw-Extracts\TT\08_T_SectAbove.values.csv  (0.1 KB)
       01.Raw-Extracts\TT\09_2) หลักการคำนวน Table.formulas.csv  (11.6 KB)
       01.Raw-Extracts\TT\09_2) หลักการคำนวน Table.values.csv  (4.8 KB)
       01.Raw-Extracts\TT\10_Period.formulas.csv  (0.1 KB)
       01.Raw-Extracts\TT\10_Period.values.csv  (0.2 KB)
       01.Raw-Extracts\TT\11_3)Target & Cal.formulas.csv  (3066.3 KB)
       01.Raw-Extracts\TT\11_3)Target & Cal.values.csv  (41.6 KB)
       01.Raw-Extracts\TT\12_Actual.values.csv  (6.5 KB)
       01.Raw-Extracts\TT\13_ASTBase.formulas.csv  (3 KB)
       01.Raw-Extracts\TT\13_ASTBase.values.csv  (2.3 KB)
       01.Raw-Extracts\TT\14_HR Rep.values.csv  (9.8 KB)
       01.Raw-Extracts\TT\15_1) For HR.formulas.csv  (59.7 KB)
       01.Raw-Extracts\TT\15_1) For HR.values.csv  (3.9 KB)
       01.Raw-Extracts\TT\16_1) For HR (AD).formulas.csv  (3.2 KB)
       01.Raw-Extracts\TT\16_1) For HR (AD).values.csv  (0.8 KB)
       01.Raw-Extracts\TT\17_Shortage.values.csv  (0.1 KB)
       01.Raw-Extracts\TT\18_Aji Plus.formulas.csv  (58.4 KB)
       01.Raw-Extracts\TT\18_Aji Plus.values.csv  (37.7 KB)
       01.Raw-Extracts\TT\19_Actual_Aji Plus.values.csv  (6.9 KB)
       01.Raw-Extracts\TT\20_RDQ.formulas.csv  (72.3 KB)
       01.Raw-Extracts\TT\20_RDQ.values.csv  (36.1 KB)
       01.Raw-Extracts\TT\21_Actual_RDQ.values.csv  (6.6 KB)
       01.Raw-Extracts\TT\22_RDM.formulas.csv  (71.9 KB)
       01.Raw-Extracts\TT\22_RDM.values.csv  (36.4 KB)
       01.Raw-Extracts\TT\23_Actual_RDM.values.csv  (5.4 KB)
       01.Raw-Extracts\TT\24_RDNS.formulas.csv  (72.2 KB)
       01.Raw-Extracts\TT\24_RDNS.values.csv  (35.1 KB)
       01.Raw-Extracts\TT\25_Actual_RDNS.values.csv  (5.7 KB)
       01.Raw-Extracts\TT\26_Sales Target.values.csv  (0 KB)
[DIR]  02.Sheet-Understanding
       02.Sheet-Understanding\_TEMPLATE.md  (1 KB)
[DIR]  02.Sheet-Understanding\MT
[DIR]  02.Sheet-Understanding\TT
[DIR]  03.Calculation-Logic
       03.Calculation-Logic\README.md  (1.1 KB)
[DIR]  04.Data-Dictionary
       04.Data-Dictionary\README.md  (1 KB)
[DIR]  05.Process-Flow
       05.Process-Flow\README.md  (1 KB)
       README.md  (3.9 KB)
สร้างเสร็จเรียบร้อยครับ ✅ ที่ 4.System Analyst and Design

โครงสร้างที่ได้

4.System Analyst and Design/
├── README.md                     ← คู่มือภาพรวม + วิธีใช้เครื่องมือ
├── 00.Extraction-Tools/
│   └── Extract-Xlsx.ps1          ← สคริปต์แตก .xlsx → CSV (ไม่ต้องใช้ Excel/Python/Node)
├── 01.Raw-Extracts/
│   ├── MT/  (32 sheets + _INDEX.md)   ← .values.csv + .formulas.csv ราย sheet
│   └── TT/  (26 sheets + _INDEX.md)
├── 02.Sheet-Understanding/
│   ├── _TEMPLATE.md              ← เทมเพลตบันทึกความเข้าใจราย sheet
│   ├── MT/  └── TT/
├── 03.Calculation-Logic/  (README หัวข้อที่ต้องถอด)
├── 04.Data-Dictionary/    (README + รูปแบบตาราง)
└── 05.Process-Flow/       (README + ตัวอย่าง Mermaid)
จุดเด่นที่ได้เลย
เครื่องมือใช้ซ้ำได้ — รันใหม่เมื่อไฟล์ต้นฉบับอัปเดต ก็ได้ CSV ชุดใหม่ทันที โดยไม่แตะไฟล์ต้นฉบับ (ตรงตามกติกาในREADME โครงการ)
แยกค่ากับสูตร — .values.csv ดูผลลัพธ์, .formulas.csv ดูตรรกะ (Cell, Formula) ซึ่งสำคัญมากเพราะแกนหลักของ incentive อยู่ในสูตร เช่น 3)Target & Cal_Staff มีถึง ~5,990 สูตร
มี _INDEX.md สรุปทุก sheet (แถว/คอลัมน์/มีสูตรไหม) ใช้เป็นจุดเริ่มไล่อ่าน
ผมได้ extract ข้อมูลจริงทั้ง MT และ TT ลงไปแล้ว พร้อมให้เริ่มวิเคราะห์ได้เลย

อยากให้ผมเริ่มขั้นต่อไปไหมครับ — เช่น ไล่อ่าน 2) หลักการคำนวน Table + Guide แล้วเขียนสรุปตรรกะการคำนวณลง 03.Calculation-Logic ให้เป็นเอกสารตั้งต้น?

ไล่อ่าน 2) หลักการคำนวน Table + Guide แล้วเขียนสรุปตรรกะการคำนวณลง 03.Calculation-Logic ให้เป็นเอกสารตั้งต้น
รับทราบครับ ผมจะไล่อ่าน Guide และ 2) หลักการคำนวน Table ทั้งฝั่ง MT และ TT แล้วสรุปลง 03.Calculation-Logic

เริ่มอ่านไฟล์ที่ extract ไว้:

Read d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\01.Raw-Extracts\MT\06_Guide.values.csv
Read d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\01.Raw-Extracts\MT\12_2) หลักการคำนวน Table.values.csv
ฝั่ง MT เห็นโครงสร้างตารางแล้ว ฝั่ง TT มี 108 แถว น่าจะมีรายละเอียดมากกว่า ขออ่าน TT version และ formulas:

Read d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\01.Raw-Extracts\TT\09_2) หลักการคำนวน Table.values.csv
ฝั่ง TT ชัดเจนมาก — เห็นโครงสร้างตาราง lookup เต็มรูปแบบ ขอดู formulas เพื่อยืนยันวิธีคำนวณ และดู Top WS ที่เป็นตัวนำค่าไปใช้:

Read d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\01.Raw-Extracts\TT\09_2) หลักการคำนวน Table.formulas.csv
Table ดึงค่าจาก Top WS เป็นหลัก — แสดงว่าตัวพารามิเตอร์จริงอยู่ในชุด WS sheets ขอดู Top WS ทั้งค่าและสูตร:

Read d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\01.Raw-Extracts\TT\01_Top WS.values.csv
ครบถ้วนพอจะเขียนเอกสารตั้งต้นแล้วครับ ผมเข้าใจโครงสร้างหลักดังนี้: Top WS คือชุดพารามิเตอร์แม่ (base incentive ตามตำแหน่ง, ตาราง achievement→payout, น้ำหนักรายกลุ่มสินค้า) และ 2) หลักการคำนวน Table คือมุมมองสรุปที่ดึงค่าจาก WS sheets มาแสดง ตอนนี้เขียนเอกสารสรุป:

Write d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\03.Calculation-Logic\00_สรุปตรรกะการคำนวณ_ตั้งต้น.md
198 lines
# สรุปตรรกะการคำนวณ Sales Incentive (เอกสารตั้งต้น)

> เวอร์ชัน: Draft v0.1 — 2026-06-12
> ที่มา: ถอดจาก sheet **`Guide`** และ **`2) หลักการคำนวน Table`** (อ้างอิงต่อเนื่องไปยัง `Top WS` / WS sheets)
> ครอบคลุม: ช่องทาง **MT** และ **TT**
> สถานะ: เอกสารตั้งต้นเพื่อตั้งหลักความเข้าใจ — ส่วนที่ยังไม่ยืนยันถูกทำเครื่องหมาย ❓ ไว้ที่ท้ายเอกสาร

---

## 1. ภาพรวมกระบวนการ (จาก sheet `Guide`)

`Guide` กำหนด "วิธีใช้งานไฟล์" ไว้ 3 ระดับความถี่:

### 1.1 รายปี (Annually)
| ขั้น | Sheet | รายละเอียด |
|------|-------|------------|
| 1 | `M_Month` | ตั้งรอบจ่าย Incentive = ปีละ 1 ครั้ง (กำหนด cycle) |

### 1.2 รายเดือน (Monthly) — กระบวนการหลักที่ทำซ้ำทุกเดือน
| ขั้น | Sheet | รายละเอียด |
|------|-------|------------|
| 1 | `Period` | กำหนดช่วงเวลา (period) ของรอบ Incentive |
| 2 | `Actual` | ดาวน์โหลดข้อมูลยอดขายจาก **BI** แล้ว copy ลง sheet `Actual` |
| 3 | `ASTBase` | อัปเดตข้อมูล AST Base + copy สูตรในคอลัมน์ที่ไฮไลต์สีเหลือง |
| 4 | `HR Rep` | ดาวน์โหลดรายงาน *Personal Employment (Main & Active)_AST* จาก **HCM** → อัปเดต `HR Rep` + copy สูตรคอลัมน์สีเหลือง |
| 5 | `For HR` | กรอก Employee ID แล้ว copy สูตรทุกคอลัมน์ ยกเว้น Employee ID และ Payment Method |

### 1.3 ปรับเมื่อจำเป็น (As needed)
| ขั้น | Sheet | รายละเอียด |
|------|-------|------------|
| 1 | `T_SectAbove` | ปรับอัตราค่าตอบแทนตาม **ระดับตำแหน่ง** (position level) |
| 2 | `Table` | ปรับอัตราค่าตอบแทนตาม **Job Function** |
| 3 | `Target & Cal` | ปรับ **เป้าขาย (sales target)** ตามเงื่อนไขธุรกิจ |
| 4 | `Shortage` | ปรับ shortage ราย product/เดือน |
| 5 | `Fix Rate` | ปรับอัตราคงที่รายพนักงาน (sheet `ค่าตอบแทนการขายในอัตราคงที่`) |

> ⚠️ หมายเหตุจาก Guide: ต้องตรวจสอบว่าข้อมูลยอดขายและพนักงาน **สอดคล้องกับ period ของเดือนนั้น** เสมอ และให้ recheck Job Function

**ลำดับการไหลของข้อมูล (ภาพรวม):**
```
Period (ตั้งรอบ)
   └─> Actual (ยอดขายจริงจาก BI) ─┐
   └─> ASTBase (ฐานข้อมูล AST) ────┤
   └─> HR Rep (ข้อมูลพนักงานจาก HCM)┤
                                    ▼
                          Target & Cal (คำนวณ achievement + incentive)
                                    ▼
                          For HR (ผลลัพธ์จ่ายรายคน) ──> ส่ง HR
```

---

## 2. โครงสร้างตารางอัตรา (จาก `2) หลักการคำนวน Table` + `Top WS`)

> สำคัญ: sheet `2) หลักการคำนวน Table` ส่วนใหญ่ **ดึงค่ามาจาก `Top WS`** (เช่น `='Top WS'!H6`) ดังนั้น **พารามิเตอร์ตัวจริงอยู่ในชุด WS sheets** ได้แก่ `Top WS`, `WS SF`, `WS WH`, `SF WH` — ตารางนี้เป็นเพียงมุมมองสรุป/นำเสนอ

### 2.1 Incentive Base ตามตำแหน่ง (Top WS, คอลัมน์ Depot Old/New)
ค่าฐาน incentive ต่อเดือน แยกตามตำแหน่ง (มีคอลัมน์ Old vs New):

| ตำแหน่ง (Depot) | Old | New |
|------------------|-----|-----|
| Area Manager | 5,000 | 5,000 |
| Depocho | 4,000 | 4,000 |
| D.Depocho | 4,000 | 4,000 |
| CV | 2,500 | 2,500 |
| Driver | 1,200 | 1,200 |
| CVFV | – | 2,500 |
| WSF | – | 3,500 |
| WH | – | 3,500 |

### 2.2 ตาราง Achievement → Payout Multiplier (GOAL)
หัวใจของการคำนวณคือการแปลง **% บรรลุเป้า (achievement)** เป็น **ตัวคูณจ่าย (GOAL multiplier)**:

| Money (ผลต่างจากเป้า) | -0.10 | -0.05 | 0 | +0.03 | +0.08 | +0.10 | +0.15 | +0.20 | +0.30 |
|---|---|---|---|---|---|---|---|---|---|
| **Achievement %** | 90% | 95% | 100% | 103% | 108% | 110% | 115% | 120% | 130% |
| **GOAL (ตัวคูณจ่าย)** | 0.90 | 0.95 | 1.00 | 1.03 | 1.06 | 1.10 | 1.15 | 1.20 | 1.30 |
| **Threshold (≥)** | 0.9001 | 0.9501 | 1.0001 | 1.0301 | 1.0601 | 1.1001 | 1.1501 | 1.2001 | 1.3001 |

- **Payout รวม = Incentive Base × GOAL** เช่น ฐาน 4,000:
  90% → 3,600 | 100% → 4,000 | 130% → 5,200
- ใช้ **lookup แบบขั้นบันได** (step): นำ achievement จริงไปเทียบ threshold เพื่อหา GOAL
- จุดสังเกต: ความสัมพันธ์ **ไม่เชิงเส้นช่วงบน** — achievement 108% ได้ตัวคูณ 1.06 (ไม่ใช่ 1.08), 110%→1.10, 130%→1.30
- หาก achievement < 90% (Money < -0.1) → ดู §2.5 (Extreme/Special) และ ❓

### 2.3 น้ำหนักรายกลุ่มสินค้า (Product Weight) — รวม = 100%
Incentive ฐานถูกกระจายตามกลุ่มสินค้า/รหัสสินค้า โดยน้ำหนัก **ต่างกันตามชุด WS** (ตำแหน่ง/Job Function):

| กลุ่ม | รหัส | Top WS | WS SF | WS WH | SF WH |
|-------|------|--------|-------|-------|-------|
| **G1 (CORE)** | A | 0.05 | 0.05 | 0.10 | 0.08 |
| | R | 0.10 | 0.10 | 0.15 | 0.13 |
| | B | 0.20 | 0.10 | 0.25 | 0.18 |
| **G2 (GD)** | AP | 0.05 | 0.05 | 0.05 | 0.05 |
| | Q | 0.10 | 0.10 | 0.05 | 0.06 |
| | M | 0.05 | 0.10 | 0.05 | 0.07 |
| | NS | 0.10 | 0.10 | 0.05 | 0.07 |
| **G3 (BB)** | Y | 0.15 | 0.15 | 0.10 | 0.13 |
| | P | 0.10 | 0.15 | 0.10 | 0.13 |
| **Others** | T | 0.05 | 0.05 | 0.05 | 0.05 |
| | RK | 0.05 | 0.05 | 0.05 | 0.05 |
| **รวม** | | **1.00** | **1.00** | **1.00** | **1.00** |

> Top WS มี cell ตรวจสอบ `SUM(weight)=1` (เซลล์ C2/C30 ตรวจผลรวม)

### 2.4 สูตรคำนวณ incentive รายสินค้า
```
incentive_รายสินค้า = Incentive_Base × GOAL(achievement) × Weight_สินค้า
incentive_รวม       = Σ (ทุกสินค้า)
```
ตัวอย่างจาก Top WS (ฐาน 4,000, สินค้า A weight 0.05):
- ที่ 100% → 4,000 × 1.00 × 0.05 = **200**
- ที่ 90%  → 4,000 × 0.90 × 0.05 = **180**
- ที่ 130% → 4,000 × 1.30 × 0.05 = **260**

ตาราง lookup รายสินค้า (Top WS rows 19–28) เก็บค่าสำเร็จรูปไว้ตาม threshold แล้ว (A,R,B,AP,…) เพื่อให้ sheet คำนวณดึงไปใช้ตรง ๆ

### 2.5 EXTRA / Special KPI และเกณฑ์ Extreme (Top WS rows 33–48)
นอกเหนือจาก incentive ปกติ มีโครงสร้างโบนัส/พิเศษเพิ่ม:
- **Special KPI** แยกราย G1/G2/G3/Ot (เช่น G1=220, G2=180 … รวมตัวอย่าง = 1,224)
- **เกณฑ์ Extreme** เป็นขั้นบันไดละเอียดกว่า: `<80% / 80–<90% / 90–<95% / 95–<100% / 100–<105% / 105–<110% / 110–<115% / 115–<120% / 120–<130% / >130%`
  - ตัวอย่าง mapping เป็นจำนวนเงิน: 0 / 1,200 / 1,350 / 1,425 / 1,500 / 1,575 / 1,725 / 1,875 / 1,950 / 2,100
  - Money เทียบเท่า: -0.2 / -0.1 / -0.05 / – / 0.05 / 0.15 / 0.25 / 0.3 / 0.4
- มี **Option1** เป็นอีกชุดเกณฑ์ขั้นบันได (ราย G1–G4) — ❓ ใช้กรณีใด

### 2.6 Cascade Concept (โครงสร้างไหลขึ้นตามสายงาน)
Top WS ระบุแนวคิด incentive แบบ cascade ขึ้นตามลำดับชั้น:
```
Salesman ──> Depocho ──> Area Manager ──> Division Manager
(ผลรวม/ผลเฉลี่ยของระดับล่าง กลายเป็นฐานคำนวณของระดับบน)
```
สอดคล้องกับ sheet `3)Target & Cal_Staff / _Sect / _Dept / _AD` (ฝั่ง MT แยกเป็น 4 sheet ตามระดับ; ฝั่ง TT รวมเป็น `3)Target & Cal` เดียว)

---

## 3. ความต่างระหว่าง MT และ TT (เบื้องต้น)

| ประเด็น | MT | TT |
|---------|-----|-----|
| sheet `Target & Cal` | แยก 4 ระดับ: `_Staff`, `_Sect`, `_Dept`, `_AD` | รวมเป็น sheet เดียว `3)Target & Cal` |
| sheet `For HR` | มี `1) For HR` + `1) For HR (FIX)` | มี `1) For HR` + `1) For HR (AD)` |
| โครงสร้างตารางอัตรา | คีย์ด้วย **Team/Sales unit ID** (เช่น 5490000718) + คอลัมน์รหัสสินค้า (AJ, RD, BD, AJP, RDC, RM, ND, YY, PDC, TKM, RKR, AMV, AJA, FP, QM) | คีย์ด้วย **ชุด WS + กลุ่มสินค้า** (G1/G2/G3/Others, รหัส A/R/B/AP/Q/M/NS/Y/P/T/RK) |
| sheet `Guide` | มี | ไม่มี (ฝัง logic เดียวกัน) |
| sheet `ค่าตอบแทนการขายในอัตราคงที่` (Fix Rate) | มี | ไม่มีแยก (ใช้ For HR (AD)) |

> ⚠️ รหัสสินค้าระหว่าง MT (AJ/RD/BD/…) กับ TT (A/R/B/…) ดูเหมือนเป็นคนละ coding scheme — ต้องทำ mapping (ดู sheet `Mapping`) — ❓

---

## 4. สรุปสูตรหลัก (Business Rules ฉบับร่าง)

```
# Input
target            = เป้าขายของหน่วย/คน (จาก Target & Cal)
actual            = ยอดขายจริง (จาก Actual / BI)
base              = incentive ฐานตามตำแหน่ง (Top WS / WS sheet)
weight[product]   = น้ำหนักรายสินค้า (รวม = 1)

# Step 1: Achievement
achievement = actual / target          # ต่อสินค้า หรือ รวม (❓ ระดับใด)

# Step 2: หา GOAL multiplier จากตาราง (step lookup)
goal = LOOKUP(achievement, threshold_table -> goal_table)
       # < 90% : ดูเกณฑ์ Extreme/Special (§2.5)

# Step 3: Incentive
incentive[product] = base × goal × weight[product]
incentive_total    = Σ incentive[product]  (+ Special KPI / Extra ถ้ามี)

# Step 4: Cascade ขึ้นตามสายงาน
Depocho/Area/Division incentive = f(ผลรวม/เฉลี่ยของระดับล่าง)   # ❓ สูตรรวม

# Step 5: ปรับด้วย Fix Rate / Shortage แล้วส่งออก For HR
```

---

## 5. คำถามค้างคา / ต้องยืนยันกับ Business (❓)

1. **ระดับการคิด achievement**: คิดราย "สินค้า" หรือ "ยอดรวม" หรือทั้งสอง? (ตาราง Money ดูเป็นยอดรวม แต่ weight เป็นรายสินค้า)
2. **กรณี achievement < 90%**: จ่ายตาม GOAL 0.9 ต่อไป, จ่าย 0, หรือเข้าเกณฑ์ Extreme? (ตาราง Extreme เริ่มที่ <80% = 0)
3. **ความต่าง Money vs GOAL ช่วงบน**: ทำไม 108% → 1.06 ไม่ใช่ 1.08 (ตั้งใจหรือ artifact ของไฟล์ทดสอบ)
4. **EXTRA / Special KPI / Option1**: ใช้เมื่อไหร่ คำนวณรวมกับ incentive ปกติอย่างไร
5. **สูตร Cascade**: incentive ของ Depocho/Area/Division รวมจากระดับล่างด้วยสูตรใด (sum / average / weighted)
6. **Mapping รหัสสินค้า MT (AJ/RD/BD…) ↔ TT (A/R/B…)**: ใช้ sheet `Mapping` ทำอะไรบ้าง
7. **Old vs New base**: เงื่อนไขเลือกใช้คอลัมน์ Old หรือ New
8. **Shortage & Fix Rate**: ปรับลด/แทนที่ incentive ปกติอย่างไร

---

## 6. ขั้นตอนถัดไปที่แนะนำ
1. อ่าน `Top WS` formulas เต็ม + `3)Target & Cal_Staff` (MT) เพื่อยืนยัน §4 (สูตรจริง)
2. อ่าน `Actual` + `ASTBase` + `HR Rep` เพื่อเข้าใจ input pipeline
3. อ่าน `1) For HR` เพื่อเข้าใจ output ที่ส่งให้ HR
4. ทำ Data Dictionary (`04.Data-Dictionary`) ของรหัสสินค้า/ตำแหน่ง/field
5. วาด Process Flow (`05.Process-Flow`) แบบ Mermaid จาก §1
```
เขียนเอกสารตั้งต้นเสร็จแล้วครับ → 00_สรุปตรรกะการคำนวณ_ตั้งต้น.md

สิ่งที่อ่านและถอดออกมา
จาก Guide — ได้ flow การทำงาน 3 ระดับ:

รายปี: ตั้งรอบจ่าย (M_Month)
รายเดือน (หลัก): Period → Actual (ยอดจาก BI) → ASTBase → HR Rep (ข้อมูลพนักงานจาก HCM) → For HR
ปรับเมื่อจำเป็น: T_SectAbove, Table, Target & Cal, Shortage, Fix Rate
จาก 2) หลักการคำนวน Table (+ Top WS) — พบว่า Table เป็นแค่มุมมองที่ดึงค่าจาก Top WS ตัวพารามิเตอร์จริงอยู่ในชุด WS sheets ได้สูตรแกนกลาง:


incentive รายสินค้า = Incentive_Base × GOAL(achievement) × Weight_สินค้า
Base ตามตำแหน่ง: Area Manager 5,000 / Depocho 4,000 / WSF·WH 3,500 ...
ตาราง Achievement→GOAL (step lookup): 90%→0.90, 100%→1.00, 130%→1.30 (ไม่เชิงเส้นช่วงบน)
Weight รายสินค้ารวม = 100% แยกกลุ่ม G1(CORE)/G2(GD)/G3(BB)/Others และต่างกันตามชุด WS
มีชั้น EXTRA/Special KPI, Extreme bracket, และแนวคิด Cascade (Salesman→Depocho→Area→Division)
จุดสำคัญที่บันทึกไว้
ความต่าง MT vs TT — MT แยก Target & Cal 4 ระดับ + คีย์ด้วย Team ID และใช้รหัสสินค้า AJ/RD/BD…; TT รวมเป็น sheet เดียว + ใช้รหัส A/R/B… (ต้องทำ mapping)
8 คำถามค้างคา (❓) ที่ต้องยืนยันกับ Business เช่น คิด achievement ราย​สินค้าหรือยอดรวม, กรณี <90% จ่ายอย่างไร, สูตร cascade, เงื่อนไข Old vs New base
เอกสารระบุสถานะเป็น Draft v0.1 และมี §6 ขั้นตอนถัดไป (อ่าน Top WS formulas เต็ม + 3)Target & Cal_Staff เพื่อยืนยันสูตรจริง)

อยากให้ผมเดินหน้า §6 ข้อ 1 ต่อเลยไหมครับ — เจาะ 3)Target & Cal_Staff (MT) ซึ่งมี ~5,990 สูตร เพื่อยืนยันว่าสูตรจริงตรงกับที่ถอดไว้ และไขคำถามค้างคาข้อ 1, 5 (ระดับ achievement + สูตร cascade)?

ต้องอ่านไฟล์ไหนใน 4.System Analyst and Design/ ถึงจะเข้าใจภาพรวมของทั้ง 2 ไฟล์
เพื่อเข้าใจภาพรวมของทั้ง 2 ไฟล์ (.xlsx MT และ TT) อ่านตามลำดับนี้ครับ:

ลำดับการอ่านที่แนะนำ
1. เริ่มที่ภาพรวมโครงสร้างงาน → 4.System Analyst and Design/README.md
อธิบายว่าแต่ละโฟลเดอร์เก็บอะไร, ไฟล์ต้นฉบับคือไฟล์ไหน, และวิธีใช้เครื่องมือ extract

2. เข้าใจตรรกะการคำนวณ (สำคัญที่สุด) → 03.Calculation-Logic/00_สรุปตรรกะการคำนวณ_ตั้งต้น.md
เอกสารนี้ตอบ "ภาพรวมทั้ง 2 ไฟล์" ได้ครบที่สุด มี:

§1 flow การทำงาน (จาก Guide)
§2 สูตรแกนกลาง + ตารางอัตรา
§3 ความต่าง MT vs TT ← ตรงคำถามคุณโดยตรง
§5 คำถามค้างคา
3. ดูรายการ sheet ทั้งหมดของแต่ละไฟล์ →

01.Raw-Extracts/MT/_INDEX.md (32 sheets)
01.Raw-Extracts/TT/_INDEX.md (26 sheets)
แต่ละ INDEX บอกชื่อ sheet + จำนวนแถว/คอลัมน์ + มีสูตรหรือไม่

4. เจาะข้อมูลดิบราย sheet (เมื่อต้องการลงลึก) → ไฟล์ .values.csv (ค่า) และ .formulas.csv (สูตร) ใน 01.Raw-Extracts/MT/ หรือ /TT/

สรุปสั้น
ต้องการ	อ่านไฟล์
เข้าใจภาพรวม + ความต่าง 2 ไฟล์เร็วที่สุด	03.Calculation-Logic/00_สรุปตรรกะการคำนวณ_ตั้งต้น.md
รู้ว่ามี sheet อะไรบ้าง	01.Raw-Extracts/{MT,TT}/_INDEX.md
โครงสร้างโฟลเดอร์/วิธีใช้เครื่องมือ	README.md
เจาะค่า/สูตรจริงราย sheet	01.Raw-Extracts/{MT,TT}/*.csv
หมายเหตุ: 02.Sheet-Understanding, 04.Data-Dictionary, 05.Process-Flow ยังเป็นเทมเพลต/README ว่างอยู่ — ยังไม่มีเนื้อหาวิเคราะห์ จะมีข้อมูลเมื่อเราทำขั้นถัดไป

อ่านไฟล์เดียวที่ครบที่สุดตอนนี้คือ 00_สรุปตรรกะการคำนวณ_ตั้งต้น.md ครับ — ถ้าอยากให้ผมเสริมให้สมบูรณ์ขึ้น (เช่นเติม 02.Sheet-Understanding ให้ครบทุก sheet เพื่อเป็นคู่มืออ่านภาพรวมแบบ sheet-by-sheet) บอกได้เลยครับ

มีการอธิบายตาม ข้อความนี้ หรือยัง "For Test_New Sales Incentive Scheme All Product_New formula_MT.xlsx = คิดแบบ product group ที่ salesman 1 คนดูแลหลาย product group

For Test_Pain_New Sales Incentive Scheme All Product_New formula_TT.xlsx = แบบการคำนวณแบบ standard ทั่วไปคือคิดตามยอดขายของ salesman ตาม SKU"
ยังครับ — เอกสารปัจจุบัน ยังไม่ได้อธิบายในมุมนี้

ตอนนี้ใน 00_สรุปตรรกะการคำนวณ_ตั้งต้น.md §3 ผมอธิบายความต่างไว้ใน เชิงโครงสร้างไฟล์ เท่านั้น เช่น:

MT แยก Target & Cal เป็น 4 ระดับ + คีย์ด้วย Team ID
TT รวมเป็น sheet เดียว + ใช้รหัสสินค้าแบบกลุ่ม G1/G2/G3
แต่ ยังไม่ได้ระบุแก่นเชิงธุรกิจ ที่คุณบอก คือ:

ไฟล์	หลักการคิด (ตามที่คุณอธิบาย)
MT (..._formula_MT.xlsx)	คิดแบบ product group — salesman 1 คนดูแลหลาย product group
TT (..._Pain_..._TT.xlsx)	คิดแบบ standard ทั่วไป — ตามยอดขายของ salesman ราย SKU
⚠️ ขอตั้งข้อสังเกตเพื่อความถูกต้อง: ข้อมูลที่ผม extract มาดูเหมือนจะ "สลับด้าน" กับคำอธิบายนี้ — ฝั่ง TT ต่างหากที่ผมเห็นโครงสร้างจัดกลุ่มชัดเจน (G1 CORE / G2 GD / G3 BB / Others) ส่วนฝั่ง MT เห็นเป็นคอลัมน์รหัสสินค้าจำนวนมาก (AJ, RD, BD, AJP, RDC, RM, ND, …) ที่ดูใกล้ระดับ SKU มากกว่า

เพื่อไม่ให้บันทึกผิด ผมอยากยืนยันก่อนว่าจะให้ผมทำแบบไหนครับ:

AskUserQuestion
OUT
Your questions have been answered: "คำอธิบาย MT=product group / TT=ราย SKU ที่คุณให้มา ควรบันทึกอย่างไร เมื่อเทียบกับสิ่งที่ผม extract เจอ (ที่ดูเหมือนสลับด้าน)?"="บันทึกตามที่คุณบอก + ผมไปตรวจสอบ". You can now continue with these answers in mind.
รับทราบครับ — ผมจะ บันทึกตามที่คุณบอก และ ไปตรวจสอบกับ data จริง (Target & Cal ทั้ง 2 ไฟล์) เพื่อยืนยัน/ปรับความเข้าใจ เริ่มตรวจสอบ:

Read d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\01.Raw-Extracts\MT\13_3)Target & Cal_Staff.values.csv
MT ชัดเจนแล้ว — แต่ละ salesman (Team เช่น 5490000718) มี หลายแถว แยกตาม Product (AJ, AJP, AMV, BD, FP, PDC, RD, RDC, …) ตรงกับที่คุณบอก ตรวจฝั่ง TT ต่อ:

Read d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\01.Raw-Extracts\TT\11_3)Target & Cal.values.csv
ทั้งสองไฟล์ key เป็น (Salesman × Product) เหมือนกัน — แต่ละ salesman มีหลายแถวตาม product เช่นกัน แต่ รหัสสินค้าต่างกัน: MT ใช้ AJ/RD/BD/AJP/RDC… (15 ตัว) ส่วน TT ใช้ A/R/B/AP/Q… (11 ตัว ตรงกับกลุ่ม G1/G2/G3) ขอตรวจ Mapping กับ Product เพื่อยืนยันว่าตัวไหนเป็น SKU ตัวไหนเป็น group:

Read d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\01.Raw-Extracts\MT\19_Mapping.values.csv
MT Mapping ยืนยันชัด — คอลัมน์ชื่อ "Product Group" สำหรับรหัส AJ/RD/BD/… ตรงกับที่คุณบอกว่า MT คิดแบบ product group ขอดู Product master ทั้งสองไฟล์เพื่อปิดประเด็น:

Read d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\01.Raw-Extracts\MT\08_Product.values.csv
Read d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\01.Raw-Extracts\TT\07_Product.values.csv
ครบแล้ว — ได้ข้อมูลพอจะสรุปและปิดประเด็นชัดเจน Product master ทั้งสองไฟล์เหมือนกัน 11 ตัว และผมพบหลักฐานที่ reconcile กับคำอธิบายของคุณได้พอดี ตอนนี้อัปเดต §3 ในเอกสาร:

Edit d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\03.Calculation-Logic\00_สรุปตรรกะการคำนวณ_ตั้งต้น.md
Edit failed
Read d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\03.Calculation-Logic\00_สรุปตรรกะการคำนวณ_ตั้งต้น.md (lines 119-140)
Read d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\03.Calculation-Logic\00_สรุปตรรกะการคำนวณ_ตั้งต้น.md (lines 137-152)
Edit d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\03.Calculation-Logic\00_สรุปตรรกะการคำนวณ_ตั้งต้น.md
Added 30 lines
อัปเดตเรียบร้อยครับ (warning ที่ขึ้นเป็น markdown style เล็กน้อย ไม่กระทบเนื้อหา)

สรุป: ตอนนี้บันทึกแล้ว ✅ พร้อมตรวจสอบยืนยันกับ data จริง
ผมทำ 2 อย่างตามที่คุณเลือก:

1. บันทึกคำอธิบายของคุณ (เป็น requirement ตั้งต้น) ใน §3.1 ของ 00_สรุปตรรกะการคำนวณ_ตั้งต้น.md

2. ตรวจสอบกับข้อมูลจริง (Target & Cal, Mapping, Product) → ยืนยันว่าสอดคล้องกัน:

MT	TT
sheet Mapping	มี — คอลัมน์ชื่อ "Product Group" ตรง ๆ	ไม่มี
การ assign	บัญชี BI เดียวกันถูกแตกตาม product group กระจายให้ salesman คนละคน	salesman เป็นเจ้าของยอดตัวเอง
รหัสสินค้า	15 product group (AJ/RD/BD/…)	11 = ตรง 1:1 กับ Product master (A=AJINOMOTO, R=ROSDEE…)
หลักฐานเด็ดที่ยืนยันคำคุณ: ใน MT Mapping บัญชี BI 1190064712 ถูกแบ่ง — AJ/AJP/YY/RKR ให้ salesman คนหนึ่ง, RDC/RM/ND/RD ให้อีกคน, BD/PDC/TKM ให้อีกคน → คือ "แบ่งงานตาม product group, 1 salesman ถือหลายกลุ่ม" พอดี ส่วน TT ไม่มีการแตกบัญชีแบบนี้เลย (ไม่มี sheet Mapping)

ข้อสังเกตที่ผมเพิ่มไว้ในเอกสาร (🔑): จุดที่อาจดูสับสนคือ MT มีรหัส (15) มากกว่า TT (11) ทั้งที่บอกว่าเป็น "group" — แต่แก่นจริงไม่ได้อยู่ที่จำนวนรหัส อยู่ที่ หน่วยความรับผิดชอบ (ownership): MT จัด incentive รอบ product-group ownership, TT จัดรอบ salesman-owns-sales รายสินค้า

ยังค้าง (❓ ข้อ 6): mapping ว่าสินค้า 11 ตัว ถูกซอยเป็น product group 15 ตัวของ MT อย่างไร — ต้องยืนยันกับ Business

อยากให้ผมไล่หาความสัมพันธ์รหัส MT 15 ↔ สินค้า 11 ตัวต่อเลยไหมครับ เพื่อปิด ❓ ข้อนี้?

ไล่หาความสัมพันธ์รหัส MT 15 ↔ สินค้า 11 ตัวต่อเลยไหมครับ เพื่อปิด
ได้ครับ ผมจะไล่หาแหล่งที่ระบุความสัมพันธ์ 15 ↔ 11 ขอตรวจหลายแหล่งพร้อมกัน — Actual, ASTBase, และ 4 sheet สินค้า (Aji Plus/RDQ/RDM/RDNS) รวมถึงค้นหารหัสกำกวม (AMV, AJA, FP, QM):

Read d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\01.Raw-Extracts\MT\18_Actual.values.csv
Actual ใช้ "Product Group" code เช่นกัน และผมเห็นรหัสเพิ่ม (LPD ใน row 26) แสดงว่ารหัสต้นทางมีมากกว่า 15 ขอดู ASTBase และ sheet สินค้า Aji Plus ที่น่าจะมี reference:

Read d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\01.Raw-Extracts\MT\11_ASTBase.values.csv
ASTBase เป็นลำดับชั้นพนักงาน (Salesman→DirectSup→Dept→Div) ไม่เกี่ยวสินค้า ขอดู 4 sheet หมวดสินค้า ซึ่งน่าจะนิยามว่าโค้ดไหนอยู่หมวดไหน:

Read d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\01.Raw-Extracts\MT\25_Actual_Aji Plus.values.csv
Actual_Aji Plus เป็นยอดขายราย salesman ไม่ใช่ตาราง mapping ขอวิเคราะห์เชิงข้อมูล — ดึงรายการรหัส Product Group ที่ปรากฏจริงใน Actual (รายการเต็มจาก BI) เทียบกับ 15 ตัวใน Target & Cal:

PowerShell List distinct product group codes across MT sheets
IN
$mt = "d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\01.Raw-Extracts\MT"
function Get-DistinctCol($file,$colIndex){
  $rows = Import-Csv -Path $file -Header (0..70 | ForEach-Object { "c$_" })
  $rows | Select-Object -Skip 1 | ForEach-Object { $_.("c$colIndex") } | Where-Object { $_ -and $_ -ne '' } | Sort-Object -Unique
}
"=== Actual (col 'Product Group' = index 3) ==="
Get-DistinctCol "$mt\18_Actual.values.csv" 3
"`n=== Target & Cal_Staff (col 'Product' = index 1) ==="
Get-DistinctCol "$mt\13_3)Target & Cal_Staff.values.csv" 1
"`n=== Mapping (col 'Product Group' = index 1) ==="
Get-DistinctCol "$mt\19_Mapping.values.csv" 1

OUT
=== Actual (col 'Product Group' = index 3) ===
AJ
AJA
AJP
AMV
BD
FP
HDSH
LPD
LQSS
ND
PDC
QM
RD
RDC
RKR
RM
SBU
STICK
SUP
SWEET
TKM
YY

=== Target & Cal_Staff (col 'Product' = index 1) ===
AJ
AJA
AJP
AMV
BD
FP
ND
PDC
Product
QM
RD
RDC
RKR
RM
TKM
YY

=== Mapping (col 'Product Group' = index 1) ===
AJ
AJA
AJP
BD
FP
ND
PDC
RD
RDC
RKR
RM
TKM
YY
ได้ภาพครบแล้ว — BI ต้นทางมี 22 รหัส, ใช้คิด incentive 15 รหัส (ตัดออก 7: HDSH, LPD, LQSS, SBU, STICK, SUP, SWEET) ตอนนี้หาตัว map รหัส→ชื่อสินค้า ขอค้นว่าชื่อสินค้าเต็มปรากฏคู่กับรหัสที่ไหนบ้าง:

Grep "AJINOMOTO|ROSDEE|BIRDY|YUMYUM|Takumi|AJI-PLUS" (in d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\01.Raw-Extracts)
7 lines of output
ชื่อสินค้าปรากฏใน WS sheets ของ MT ขอดูบริบทใน Top WS (MT) ที่มีทั้งชื่อและรหัส:

Grep "AJINOMOTO|ROSDEE|BIRDY|YUMYUM|Takumi|AJI-PLUS|POWDER" (in d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\01.Raw-Extracts\MT\01_Top WS.values.csv)
11 lines of output
เจอแล้ว — MT Top WS ใช้ ชื่อสินค้า 11 ตัวเดียวกับ TT จัดกลุ่ม G1/G2/G3/Others เป๊ะ ทำให้ผม map รหัสได้ครบ ขอสร้าง Data Dictionary ของรหัสสินค้า (ที่อยู่ที่เหมาะสม) และอัปเดตเอกสารหลัก:

Write d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\04.Data-Dictionary\01_Product-Code-Mapping.md
62 lines
# Product Code Mapping (MT ↔ TT ↔ Product Master)

> เวอร์ชัน: Draft v0.1 — 2026-06-12
> ที่มา: `Top WS` (MT/TT), `2) หลักการคำนวน Table`, `Mapping` (MT), `Actual` (MT), `Product` master
> วัตถุประสงค์: ปิดคำถาม ❓ "รหัส MT 15 ตัว สัมพันธ์กับสินค้า 11 ตัวอย่างไร"

## ข้อสรุปหลัก
- **`Product` master เหมือนกันทั้ง MT และ TT = 11 สินค้า**
- **`Top WS` ของ MT และ TT ใช้ชื่อสินค้า 11 ตัวเดียวกัน** จัดกลุ่ม G1/G2/G3/Others + น้ำหนักเหมือนกัน (ยืนยัน cross-check แล้ว ✅)
- ความต่างอยู่ที่ **รหัสที่ใช้ในชั้นปฏิบัติการ (Target & Cal / Actual / Mapping)**:
  - **TT** ใช้รหัสสั้น 11 ตัว = **1:1 กับสินค้า** (ระดับสินค้า/SKU)
  - **MT** ใช้รหัส **"Product Group" 15 ตัว** ที่ดึงจาก BI โดย 11 ตัว map 1:1 กับสินค้า และมีอีก **4 ตัวที่เป็นสินค้าย่อย/variant** นอกเหนือ 11 master

## ตาราง mapping ที่ยืนยันแล้ว (11 ตัว 1:1) ✅
cross-check จาก 3 แหล่ง: ชื่อใน Top WS (MT) ↔ รหัส MT ↔ รหัส TT

| กลุ่ม (Top WS) | สินค้า (Product master) | รหัส MT | รหัส TT | น้ำหนัก (Top WS) |
|----------------|--------------------------|---------|---------|------------------|
| **G1 (CORE)** | AJINOMOTO | `AJ` | `A` | 0.05 |
| | ROSDEE | `RD` | `R` | 0.10 |
| | BIRDY | `BD` | `B` | 0.20 |
| **G2 (GD)** | AJI-PLUS | `AJP` | `AP` | 0.05 |
| | ROSDEE CUBE | `RDC` | `Q` | 0.10 |
| | ROSDEE MENU | `RM` | `M` | 0.05 |
| | ROSDEE NOODLE | `ND` | `NS` | 0.10 |
| **G3 (BB)** | YUMYUM | `YY` | `Y` | 0.15 |
| | POWDER COFFEE | `PDC` | `P` | 0.10 |
| **Others** | Takumi-Aji | `TKM` | `T` | 0.05 |
| | ROSDEE MENU KKR | `RKR` | `RK` | 0.05 |
| | **รวม** | | | **1.00** ✅ |

> หมายเหตุ: TT `Q` = ROSDEE CUBE และ TT `NS` / MT `ND` = ROSDEE NOODLE (ระวังสับสน — รหัสไม่ตรงตัวอักษรแรกเป๊ะ)

## รหัส MT เพิ่มเติม 4 ตัว (ไม่อยู่ใน 11 master) — ต้องยืนยัน ❓
ปรากฏใน MT `Target & Cal` + `Actual` และได้รับ incentive รายแถวจริง แต่ **ไม่มีชื่อใน `Product` master** และ **ไม่มีน้ำหนักแยกใน Top WS** → น่าจะเป็น sub-brand/variant ที่ม้วนรวมเข้าสินค้าหลักตัวใดตัวหนึ่ง

| รหัส MT | สมมติฐาน parent (ยังไม่ยืนยัน) | เหตุผล |
|---------|-------------------------------|--------|
| `AJA` | ตระกูล AJINOMOTO (?) | ขึ้นต้น "AJ" |
| `AMV` | ตระกูล AJINOMOTO (?) | ขึ้นต้น "A" |
| `FP` | ❓ | ไม่ทราบ |
| `QM` | ตระกูล ROSDEE CUBE (?) | ขึ้นต้น "Q" คล้าย TT `Q` |

> ⚠️ ต้องให้ Business ยืนยันว่า 4 รหัสนี้คือสินค้าอะไร และ map เข้ากลุ่ม/สินค้าหลักใด (หรือคิด incentive แยกอิสระ)

## รหัส BI ที่ถูกตัดออกจากการคิด Incentive (7 ตัว)
`Actual` (BI) ของ MT มีรหัส Product Group ทั้งหมด **22 ตัว** แต่ `Target & Cal` ใช้เพียง 15 ตัว → ตัดออก 7 ตัว:

`HDSH`, `LPD`, `LQSS`, `SBU`, `STICK`, `SUP`, `SWEET`

> ⚠️ ต้องยืนยันเหตุผลการตัด (ไม่อยู่ในเงื่อนไข incentive / เป็นสินค้านอก scope) — และ TT มีการตัดแบบนี้หรือไม่

## สรุปความสัมพันธ์เชิงตัวเลข
```
BI source (MT Actual)         22 รหัส
   └─ ใช้คิด incentive (MT)    15 รหัส   (ตัด 7)
        ├─ map 1:1 กับสินค้า    11 รหัส   ✅ = Product master
        └─ sub-variant          4 รหัส   ❓ (AJA, AMV, FP, QM)

TT Actual / Target & Cal      11 รหัส = 1:1 กับสินค้า (SKU) ✅
```
Now update ❓ ข้อ 6 ในเอกสารหลักให้ชี้ไปยัง Data Dictionary และสรุปสถานะ:

Read d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\03.Calculation-Logic\00_สรุปตรรกะการคำนวณ_ตั้งต้น.md (lines 187-206)
Read d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\03.Calculation-Logic\00_สรุปตรรกะการคำนวณ_ตั้งต้น.md (lines 207-231)
Edit d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\03.Calculation-Logic\00_สรุปตรรกะการคำนวณ_ตั้งต้น.md
Modified
เสร็จแล้วครับ — ปิดประเด็นหลักได้ บันทึกไว้ใน 04.Data-Dictionary/01_Product-Code-Mapping.md และเชื่อมจาก ❓ ข้อ 6 ในเอกสารหลัก

ผลการไล่หาความสัมพันธ์
กุญแจสำคัญที่พบ: Top WS ของ MT ใช้ชื่อสินค้า 11 ตัวเดียวกับ TT จัดกลุ่ม G1/G2/G3/Others + น้ำหนักเหมือนกันเป๊ะ → ทำให้ map รหัสได้ครบ โดย cross-check 3 แหล่ง (ชื่อใน Top WS ↔ รหัส MT ↔ รหัส TT)

✅ ยืนยันแล้ว 11 ตัว (1:1)
สินค้า	MT	TT		สินค้า	MT	TT
AJINOMOTO	AJ	A		ROSDEE NOODLE	ND	NS
ROSDEE	RD	R		YUMYUM	YY	Y
BIRDY	BD	B		POWDER COFFEE	PDC	P
AJI-PLUS	AJP	AP		Takumi-Aji	TKM	T
ROSDEE CUBE	RDC	Q		ROSDEE MENU KKR	RKR	RK
ROSDEE MENU	RM	M				
⚠️ จุดระวังสับสน: TT Q=ROSDEE CUBE (ไม่ใช่ตัว Q), และ ROSDEE NOODLE = MT ND / TT NS

ความสัมพันธ์เชิงตัวเลขทั้งหมด

BI source (MT Actual)       22 รหัส
  └─ คิด incentive (MT)      15 รหัส   (ตัด 7)
       ├─ map 1:1 กับสินค้า   11 ตัว   ✅
       └─ sub-variant          4 ตัว   ❓ (AJA, AMV, FP, QM)
TT                           11 รหัส = 1:1 กับสินค้า ✅
คงเหลือ 2 จุดเล็ก ๆ ที่ต้องให้ Business ยืนยัน (บันทึกไว้แล้ว)
4 รหัส MT เพิ่ม AJA / AMV / FP / QM — เป็นสินค้าย่อยที่ได้ incentive จริงแต่ไม่อยู่ใน 11 master (ผมใส่สมมติฐาน parent ไว้ แต่ยังไม่ฟันธง เพราะไม่มีหลักฐานในไฟล์)
7 รหัส BI ที่ถูกตัด HDSH / LPD / LQSS / SBU / STICK / SUP / SWEET — ต้องยืนยันเหตุผลที่ไม่นำมาคิด
ทั้งสองจุดนี้ต้องถาม Business ครับ (ในไฟล์ไม่มี reference ที่ระบุ) — ผมตั้งใจ ไม่เดามั่ว เพื่อไม่ให้เอกสาร SA คลาดเคลื่อน

อยากให้ผมเดินหน้าต่อข้อไหนใน §6 ไหมครับ เช่น เจาะสูตร Cascade (❓ ข้อ 5) หรือ pipeline ขาเข้า (Actual/ASTBase/HR Rep)?

ปัจจุบันตามโครงสร้าง 4.System Analyst and Design ทำงานถึง folder ไหน แต่ละ folder ได้กี่ %
ขอตรวจสถานะปัจจุบันของแต่ละโฟลเดอร์ก่อน:

Bash List all files in SA folder
IN
cd "d:/Users/wimut/OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED/My Projects/28.AJT New Sale Incentive/4.System Analyst and Design" && find . -type f | sort

OUT
./00.Extraction-Tools/Extract-Xlsx.ps1
./01.Raw-Extracts/MT/01_Top WS.formulas.csv
./01.Raw-Extracts/MT/01_Top WS.values.csv
./01.Raw-Extracts/MT/02_WS SF.formulas.csv
./01.Raw-Extracts/MT/02_WS SF.values.csv
./01.Raw-Extracts/MT/03_WS WH.formulas.csv
./01.Raw-Extracts/MT/03_WS WH.values.csv
./01.Raw-Extracts/MT/04_Test.formulas.csv
./01.Raw-Extracts/MT/04_Test.values.csv
./01.Raw-Extracts/MT/05_SF WH.formulas.csv
./01.Raw-Extracts/MT/05_SF WH.values.csv
./01.Raw-Extracts/MT/06_Guide.values.csv
./01.Raw-Extracts/MT/07_M_Month.values.csv
./01.Raw-Extracts/MT/08_Product.values.csv
./01.Raw-Extracts/MT/09_T_SectAbove.values.csv
./01.Raw-Extracts/MT/10_Period.formulas.csv
./01.Raw-Extracts/MT/10_Period.values.csv
./01.Raw-Extracts/MT/11_ASTBase.values.csv
./01.Raw-Extracts/MT/12_2) หลักการคำนวน Table.formulas.csv
./01.Raw-Extracts/MT/12_2) หลักการคำนวน Table.values.csv
./01.Raw-Extracts/MT/13_3)Target & Cal_Staff.formulas.csv
./01.Raw-Extracts/MT/13_3)Target & Cal_Staff.values.csv
./01.Raw-Extracts/MT/14_3)Target & Cal_Sect.formulas.csv
./01.Raw-Extracts/MT/14_3)Target & Cal_Sect.values.csv
./01.Raw-Extracts/MT/15_3)Target & Cal_Dept.formulas.csv
./01.Raw-Extracts/MT/15_3)Target & Cal_Dept.values.csv
./01.Raw-Extracts/MT/16_3)Target & Cal_AD.formulas.csv
./01.Raw-Extracts/MT/16_3)Target & Cal_AD.values.csv
./01.Raw-Extracts/MT/17_HR Rep.formulas.csv
./01.Raw-Extracts/MT/17_HR Rep.values.csv
./01.Raw-Extracts/MT/18_Actual.formulas.csv
./01.Raw-Extracts/MT/18_Actual.values.csv
./01.Raw-Extracts/MT/19_Mapping.formulas.csv
./01.Raw-Extracts/MT/19_Mapping.values.csv
./01.Raw-Extracts/MT/20_1) For HR.formulas.csv
./01.Raw-Extracts/MT/20_1) For HR.values.csv
./01.Raw-Extracts/MT/21_1) For HR (FIX).formulas.csv
./01.Raw-Extracts/MT/21_1) For HR (FIX).values.csv
./01.Raw-Extracts/MT/22_Shortage.values.csv
./01.Raw-Extracts/MT/23_ค่าตอบแทนการขายในอัตราคงที่.values.csv
./01.Raw-Extracts/MT/24_Aji Plus.formulas.csv
./01.Raw-Extracts/MT/24_Aji Plus.values.csv
./01.Raw-Extracts/MT/25_Actual_Aji Plus.values.csv
./01.Raw-Extracts/MT/26_RDQ.formulas.csv
./01.Raw-Extracts/MT/26_RDQ.values.csv
./01.Raw-Extracts/MT/27_Actual_RDQ.values.csv
./01.Raw-Extracts/MT/28_RDM.formulas.csv
./01.Raw-Extracts/MT/28_RDM.values.csv
./01.Raw-Extracts/MT/29_Actual_RDM.values.csv
./01.Raw-Extracts/MT/30_RDNS.formulas.csv
./01.Raw-Extracts/MT/30_RDNS.values.csv
./01.Raw-Extracts/MT/31_Actual_RDNS.values.csv
./01.Raw-Extracts/MT/32_Sales Target.values.csv
./01.Raw-Extracts/MT/_INDEX.md
./01.Raw-Extracts/TT/01_Top WS.formulas.csv
./01.Raw-Extracts/TT/01_Top WS.values.csv
./01.Raw-Extracts/TT/02_WS SF.formulas.csv
./01.Raw-Extracts/TT/02_WS SF.values.csv
./01.Raw-Extracts/TT/03_WS WH.formulas.csv
./01.Raw-Extracts/TT/03_WS WH.values.csv
./01.Raw-Extracts/TT/04_Test.formulas.csv
./01.Raw-Extracts/TT/04_Test.values.csv
./01.Raw-Extracts/TT/05_SF WH.formulas.csv
./01.Raw-Extracts/TT/05_SF WH.values.csv
./01.Raw-Extracts/TT/06_M_Month.values.csv
./01.Raw-Extracts/TT/07_Product.values.csv
./01.Raw-Extracts/TT/08_T_SectAbove.values.csv
./01.Raw-Extracts/TT/09_2) หลักการคำนวน Table.formulas.csv
./01.Raw-Extracts/TT/09_2) หลักการคำนวน Table.values.csv
./01.Raw-Extracts/TT/10_Period.formulas.csv
./01.Raw-Extracts/TT/10_Period.values.csv
./01.Raw-Extracts/TT/11_3)Target & Cal.formulas.csv
./01.Raw-Extracts/TT/11_3)Target & Cal.values.csv
./01.Raw-Extracts/TT/12_Actual.values.csv
./01.Raw-Extracts/TT/13_ASTBase.formulas.csv
./01.Raw-Extracts/TT/13_ASTBase.values.csv
./01.Raw-Extracts/TT/14_HR Rep.values.csv
./01.Raw-Extracts/TT/15_1) For HR.formulas.csv
./01.Raw-Extracts/TT/15_1) For HR.values.csv
./01.Raw-Extracts/TT/16_1) For HR (AD).formulas.csv
./01.Raw-Extracts/TT/16_1) For HR (AD).values.csv
./01.Raw-Extracts/TT/17_Shortage.values.csv
./01.Raw-Extracts/TT/18_Aji Plus.formulas.csv
./01.Raw-Extracts/TT/18_Aji Plus.values.csv
./01.Raw-Extracts/TT/19_Actual_Aji Plus.values.csv
./01.Raw-Extracts/TT/20_RDQ.formulas.csv
./01.Raw-Extracts/TT/20_RDQ.values.csv
./01.Raw-Extracts/TT/21_Actual_RDQ.values.csv
./01.Raw-Extracts/TT/22_RDM.formulas.csv
./01.Raw-Extracts/TT/22_RDM.values.csv
./01.Raw-Extracts/TT/23_Actual_RDM.values.csv
./01.Raw-Extracts/TT/24_RDNS.formulas.csv
./01.Raw-Extracts/TT/24_RDNS.values.csv
./01.Raw-Extracts/TT/25_Actual_RDNS.values.csv
./01.Raw-Extracts/TT/26_Sales Target.values.csv
./01.Raw-Extracts/TT/_INDEX.md
./02.Sheet-Understanding/_TEMPLATE.md
./03.Calculation-Logic/00_สรุปตรรกะการคำนวณ_ตั้งต้น.md
./03.Calculation-Logic/README.md
./04.Data-Dictionary/01_Product-Code-Mapping.md
./04.Data-Dictionary/README.md
./05.Process-Flow/README.md
./README.md
ตรวจแล้วครับ นี่คือสถานะปัจจุบันของแต่ละโฟลเดอร์ใน 4.System Analyst and Design:

สรุปความคืบหน้า
โฟลเดอร์	%	สถานะ	สิ่งที่ทำแล้ว	สิ่งที่ยังขาด
00.Extraction-Tools	100%	✅ เสร็จ	สคริปต์ Extract-Xlsx.ps1 ใช้งานได้จริง รันซ้ำได้	–
01.Raw-Extracts	100%	✅ เสร็จ	extract ครบ MT (32 sheets) + TT (26 sheets) แยก values/formulas + _INDEX.md	–
03.Calculation-Logic	~40%	🟡 กำลังทำ	เอกสารตั้งต้น (flow, สูตรแกน, ตารางอัตรา, MT vs TT)	ยืนยันสูตรจริงจาก formulas, Cascade, Extreme, Shortage, Fix Rate, output For HR
04.Data-Dictionary	~25%	🟡 กำลังทำ	Product Code Mapping (15↔11) ครบ	รหัสตำแหน่ง, field dictionary, master (M_Month/Period/T_SectAbove/org codes)
02.Sheet-Understanding	~5%	🔴 ยังไม่เริ่ม	มีแค่ _TEMPLATE.md	บันทึกราย sheet ทั้ง ~58 sheets
05.Process-Flow	~5%	🔴 ยังไม่เริ่ม	มีแค่ README + ตัวอย่าง Mermaid	diagram จริงของ data flow + dependency
ภาพรวม

ความคืบหน้า SA โดยรวม ≈ 35–40%

✅ เสร็จ:        00 (เครื่องมือ) + 01 (ข้อมูลดิบ)      ← ฐานพร้อมใช้ครบ
🟡 กำลังทำ:      03 (ตรรกะ ~40%) + 04 (dict ~25%)
🔴 ยังไม่เริ่ม:   02 (sheet-by-sheet) + 05 (flow diagram)
ตอนนี้เราอยู่ที่: เก็บข้อมูลครบ 100% แล้ว และกำลังอยู่ช่วง "ถอดความเข้าใจ" — ได้แกนหลักของ logic + product mapping แล้ว แต่ยังเหลือการยืนยันสูตรจริงและขยายให้ครบทุก sheet/field

หมายเหตุเรื่อง %: ตัวเลขนี้ประเมินจาก "งานอ่าน/ทำความเข้าใจไฟล์" เป็นหลัก ยังไม่รวม deliverable SA เต็มรูป (BRD/SRS/Use Case/API Spec) ที่ปกติอยู่ในโฟลเดอร์นี้ด้วย — ถ้านับรวมขอบเขต SA ทั้งหมด % จะต่ำกว่านี้

อยากให้ผมดันโฟลเดอร์ไหนต่อครับ? แนะนำ 03 (ยืนยันสูตร Cascade + achievement) เพราะเป็นแกนการคำนวณ หรือจะให้ทำ 02 (sheet-by-sheet) ให้ครบเพื่อเป็นคู่มืออ่านภาพรวมก่อนก็ได้

ทำ 03.Calculation-Logic ให้เสร็จก่อน
รับทราบครับ จะทำ 03.Calculation-Logic ให้เสร็จ ต้องยืนยันสูตรจริงจาก formulas เพื่อปิด ❓ ที่เหลือ ขออ่านไฟล์สำคัญพร้อมกัน:

Read d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\01.Raw-Extracts\MT\13_3)Target & Cal_Staff.formulas.csv
เห็นสูตร Step 1 (Percent) และ Step 2 (Round/GOAL) ชัดแล้ว — ขออ่านต่อส่วนสูตร Incentive (คอลัมน์ AZ เป็นต้นไป) และ Top WS:

Read d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\01.Raw-Extracts\MT\13_3)Target & Cal_Staff.formulas.csv (lines 99-158)
สูตร Incentive ชัดเจนแล้ว — ยืนยันโมเดล incentive = Payout(team,goal) × Weight(team,product) คิดราย product/เดือน ตอนนี้ขอดู Cascade (Sect), Shortage, Fix Rate และ For HR เพื่อปิด ❓ ที่เหลือ:

Read d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\01.Raw-Extracts\MT\22_Shortage.values.csv
Read d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\01.Raw-Extracts\MT\23_ค่าตอบแทนการขายในอัตราคงที่.values.csv
Shortage และ Fix Rate ชัดแล้ว ขอดู Cascade (Sect/AD) และ output For HR:

Read d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\01.Raw-Extracts\MT\14_3)Target & Cal_Sect.formulas.csv
Cascade เข้าใจแล้ว — ระดับ Sect ใช้ SUMIFS รวม Target+Actual จากระดับ Staff (group by product + DirectSupCode) แล้วคำนวณ incentive ใหม่ที่ระดับนั้น (ไม่ใช่บวก incentive) ขอดู For HR (output) ปิดท้าย:

Read d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\01.Raw-Extracts\MT\20_1) For HR.values.csv
For HR คือ output รายคน — ดึง incentive จากระดับที่ตรงกับ Job Function (Staff/Section/Dept/AD) ขอดูสูตรยืนยันการดึงค่า:

Read d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\4.System Analyst and Design\01.Raw-Extracts\MT\20_1) For HR.formulas.csv
Credit balance is too low