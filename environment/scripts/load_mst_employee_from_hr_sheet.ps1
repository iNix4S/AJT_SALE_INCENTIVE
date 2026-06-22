param(
    [string]$MtHrRepPath = "4.System Analyst and Design/01.Raw-Extracts/MT/17_HR Rep.values.csv",
    [string]$TtHrRepPath = "4.System Analyst and Design/01.Raw-Extracts/TT/14_HR Rep.values.csv",
    [string]$ConnectionString,
    [string]$BatchId,
    [string]$SourceSystem = "HR_REP_SHEET",
    [datetime]$DataMonth
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-ConnectionStringFromEnv {
    param([string]$EnvFilePath)

    $line = Get-Content -LiteralPath $EnvFilePath | Where-Object { $_ -match '^DB_CONNECTION_STRING=' } | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($line)) {
        throw "DB_CONNECTION_STRING not found in $EnvFilePath"
    }

    return $line.Substring('DB_CONNECTION_STRING='.Length)
}

function Get-UniqueHeaderRows {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "File not found: $Path"
    }

    $lines = Get-Content -LiteralPath $Path
    if ($lines.Count -lt 2) {
        return @()
    }

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

function Get-PropertyValue {
    param(
        [psobject]$Row,
        [string[]]$CandidateNames
    )

    foreach ($name in $CandidateNames) {
        $prop = $Row.PSObject.Properties[$name]
        if ($null -ne $prop) {
            return [string]$prop.Value
        }
    }

    return $null
}

function ConvertTo-NormalizedCode {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    $trimmed = $Value.Trim()
    if ($trimmed -eq '#N/A' -or $trimmed -eq '0') {
        return $null
    }

    return $trimmed
}

function ConvertTo-NullableDate {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    $parsed = [datetime]::MinValue
    if ([datetime]::TryParse($Value.Trim(), [ref]$parsed)) {
        return $parsed.Date
    }

    return $null
}

function ConvertTo-PositionCode {
    param([string]$PositionText)

    if ([string]::IsNullOrWhiteSpace($PositionText)) {
        return 'STAFF'
    }

    $text = $PositionText.Trim().ToLower()

    if ($text -like '*associate director*' -or $text -like '*ผู้อำนวยการ*') { return 'AD' }
    if ($text -like '*division manager*' -or $text -like '*ผู้จัดการฝ่าย*') { return 'DIV_MGR' }
    if ($text -like '*department manager*' -or $text -like '*ผู้จัดการแผนก*') { return 'DEPT_MGR' }
    if ($text -like '*section manager*' -or $text -like '*ผู้จัดการส่วน*') { return 'SECT_MGR' }

    return 'STAFF'
}

function ConvertTo-JobFunctionCode {
    param(
        [string]$JobTitle,
        [string]$PositionCode
    )

    $title = if ([string]::IsNullOrWhiteSpace($JobTitle)) { '' } else { $JobTitle.Trim().ToLower() }

    if ($title -like '*associate director*') { return 'ASSOC_DIRECTOR' }
    if ($title -like '*division manager*') { return 'DIV_MANAGER' }
    if ($title -like '*department manager*') { return 'DEPT_MANAGER' }
    if ($title -like '*section manager*') { return 'SECTION_MANAGER' }

    switch ($PositionCode) {
        'AD' { return 'ASSOC_DIRECTOR' }
        'DIV_MGR' { return 'DIV_MANAGER' }
        'DEPT_MGR' { return 'DEPT_MANAGER' }
        'SECT_MGR' { return 'SECTION_MANAGER' }
        default { return 'SALESMAN' }
    }
}

function Get-EmployeeNameTh {
    param([psobject]$Row, [string]$FallbackCode)

    $name1 = Get-PropertyValue -Row $Row -CandidateNames @('Full Name (Auto)')
    if (-not [string]::IsNullOrWhiteSpace($name1)) { return $name1.Trim() }

    $name2 = Get-PropertyValue -Row $Row -CandidateNames @('Full Name Alt1 (Auto)')
    if (-not [string]::IsNullOrWhiteSpace($name2)) { return $name2.Trim() }

    $mergeName = Get-PropertyValue -Row $Row -CandidateNames @('MergeName')
    if (-not [string]::IsNullOrWhiteSpace($mergeName)) { return $mergeName.Trim() }

    $lastName = Get-PropertyValue -Row $Row -CandidateNames @('Last Name')
    $firstName = Get-PropertyValue -Row $Row -CandidateNames @('First Name')
    $fullName = (($firstName + ' ' + $lastName).Trim())
    if (-not [string]::IsNullOrWhiteSpace($fullName)) { return $fullName }

    return $FallbackCode
}

function New-StagingTable {
    $dt = New-Object System.Data.DataTable
    [void]$dt.Columns.Add('batch_id', [string])
    [void]$dt.Columns.Add('import_date', [datetime])
    [void]$dt.Columns.Add('source_system', [string])
    [void]$dt.Columns.Add('data_month', [datetime])
    [void]$dt.Columns.Add('employee_code', [string])
    [void]$dt.Columns.Add('employee_name_th', [string])
    [void]$dt.Columns.Add('employee_name_en', [string])
    [void]$dt.Columns.Add('company_code', [string])
    [void]$dt.Columns.Add('cost_center', [string])
    [void]$dt.Columns.Add('position_code', [string])
    [void]$dt.Columns.Add('job_function_code', [string])
    [void]$dt.Columns.Add('channel_code', [string])
    [void]$dt.Columns.Add('employment_status', [string])
    [void]$dt.Columns.Add('hire_date', [datetime])
    [void]$dt.Columns.Add('termination_date', [datetime])
    [void]$dt.Columns.Add('raw_row_no', [int])
    [void]$dt.Columns.Add('status', [string])
    [void]$dt.Columns.Add('error_message', [string])
    [void]$dt.Columns.Add('created_at', [datetime])
    return ,$dt
}

function Add-RowsToStaging {
    param(
        [System.Data.DataTable]$Staging,
        [object[]]$Rows,
        [string]$ChannelCode,
        [string]$BatchId,
        [string]$SourceSystem,
        [datetime]$DataMonth,
        [datetime]$ImportDate
    )

    $rowNo = 0
    foreach ($r in $Rows) {
        $rowNo += 1

        $employeeCode = ConvertTo-NormalizedCode (Get-PropertyValue -Row $r -CandidateNames @('EmpCode', 'User/Employee ID'))
        if ([string]::IsNullOrWhiteSpace($employeeCode)) {
            continue
        }

        $positionText = Get-PropertyValue -Row $r -CandidateNames @('Position Name (TH)', 'Position Level')
        $positionCode = ConvertTo-PositionCode -PositionText $positionText

        $jobTitle = Get-PropertyValue -Row $r -CandidateNames @('Job Title')
        $jobFunctionCode = ConvertTo-JobFunctionCode -JobTitle $jobTitle -PositionCode $positionCode

        $employeeNameTh = Get-EmployeeNameTh -Row $r -FallbackCode $employeeCode
        $employeeNameEn = Get-PropertyValue -Row $r -CandidateNames @('Full Name Alt1 (Auto)')

        $companyCode = ConvertTo-NormalizedCode (Get-PropertyValue -Row $r -CandidateNames @('Company Company Name'))
        $costCenter = ConvertTo-NormalizedCode (Get-PropertyValue -Row $r -CandidateNames @('Cost Centre'))
        $hireDate = ConvertTo-NullableDate (Get-PropertyValue -Row $r -CandidateNames @('Employment Details Hire Date/Concurrent Date'))
        $terminationDate = ConvertTo-NullableDate (Get-PropertyValue -Row $r -CandidateNames @('Employment Details Retirement Date'))

        $newRow = $Staging.NewRow()
        $newRow['batch_id'] = $BatchId
        $newRow['import_date'] = $ImportDate
        $newRow['source_system'] = $SourceSystem
        $newRow['data_month'] = $DataMonth
        $newRow['employee_code'] = $employeeCode
        $newRow['employee_name_th'] = $employeeNameTh
        $newRow['employee_name_en'] = if ([string]::IsNullOrWhiteSpace($employeeNameEn)) { [System.DBNull]::Value } else { $employeeNameEn.Trim() }
        $newRow['company_code'] = if ($null -eq $companyCode) { [System.DBNull]::Value } else { $companyCode }
        $newRow['cost_center'] = if ($null -eq $costCenter) { [System.DBNull]::Value } else { $costCenter }
        $newRow['position_code'] = $positionCode
        $newRow['job_function_code'] = $jobFunctionCode
        $newRow['channel_code'] = $ChannelCode
        $newRow['employment_status'] = 'ACTIVE'
        $newRow['hire_date'] = if ($null -eq $hireDate) { [System.DBNull]::Value } else { $hireDate }
        $newRow['termination_date'] = if ($null -eq $terminationDate) { [System.DBNull]::Value } else { $terminationDate }
        $newRow['raw_row_no'] = $rowNo
        $newRow['status'] = 'READY'
        $newRow['error_message'] = [System.DBNull]::Value
        $newRow['created_at'] = $ImportDate

        [void]$Staging.Rows.Add($newRow)
    }
}

if ([string]::IsNullOrWhiteSpace($ConnectionString)) {
    $ConnectionString = Get-ConnectionStringFromEnv -EnvFilePath 'environment/database-dev.env'
}

if ([string]::IsNullOrWhiteSpace($BatchId)) {
    $BatchId = 'HR_REP_' + (Get-Date).ToString('yyyyMMdd_HHmmss')
}

$cn = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
$cn.Open()

try {
    if ($PSBoundParameters.ContainsKey('DataMonth') -eq $false) {
        $cmdDataMonth = $cn.CreateCommand()
        $cmdDataMonth.CommandText = "SELECT MAX(sales_month) FROM dbo.mst_period"
        $maxMonth = $cmdDataMonth.ExecuteScalar()

        if ($null -eq $maxMonth -or $maxMonth -is [System.DBNull]) {
            $DataMonth = (Get-Date).Date
        }
        else {
            $DataMonth = [datetime]$maxMonth
        }
    }

    $mtRows = Get-UniqueHeaderRows -Path $MtHrRepPath
    $ttRows = Get-UniqueHeaderRows -Path $TtHrRepPath

    $staging = New-StagingTable
    $importDate = [datetime]::UtcNow

    Add-RowsToStaging -Staging $staging -Rows $mtRows -ChannelCode 'MT' -BatchId $BatchId -SourceSystem $SourceSystem -DataMonth $DataMonth -ImportDate $importDate
    Add-RowsToStaging -Staging $staging -Rows $ttRows -ChannelCode 'TT' -BatchId $BatchId -SourceSystem $SourceSystem -DataMonth $DataMonth -ImportDate $importDate

    if ($staging.Rows.Count -eq 0) {
        throw 'No valid HR Rep rows to load.'
    }

    $tx = $cn.BeginTransaction()
    try {
        $deleteCmd = $cn.CreateCommand()
        $deleteCmd.Transaction = $tx
        $deleteCmd.CommandText = "DELETE FROM dbo.stg_hcm_employee WHERE batch_id = @batch_id"
        [void]$deleteCmd.Parameters.Add('@batch_id', [System.Data.SqlDbType]::NVarChar, 50)
        $deleteCmd.Parameters['@batch_id'].Value = $BatchId
        [void]$deleteCmd.ExecuteNonQuery()

        $bulk = New-Object System.Data.SqlClient.SqlBulkCopy($cn, [System.Data.SqlClient.SqlBulkCopyOptions]::Default, $tx)
        $bulk.DestinationTableName = 'dbo.stg_hcm_employee'
        $bulk.BulkCopyTimeout = 0
        foreach ($c in $staging.Columns) {
            [void]$bulk.ColumnMappings.Add($c.ColumnName, $c.ColumnName)
        }
        $bulk.WriteToServer($staging)

        $mergeSql = @"
;WITH src AS (
    SELECT
        s.employee_code,
        s.employee_name_th,
        s.employee_name_en,
        c.channel_id,
        jf.job_function_id,
        pl.position_level_id,
        s.cost_center,
        s.company_code,
        COALESCE(s.hire_date, s.data_month) AS effective_from,
        s.termination_date AS effective_to,
        CASE
            WHEN s.termination_date IS NOT NULL AND s.termination_date < CAST(GETDATE() AS date) THEN CAST(0 AS bit)
            ELSE CAST(1 AS bit)
        END AS is_active
    FROM dbo.stg_hcm_employee s
    LEFT JOIN dbo.mst_channel c
        ON c.channel_code = s.channel_code
    LEFT JOIN dbo.mst_job_function jf
        ON jf.job_function_code = s.job_function_code
        AND (jf.channel_id IS NULL OR jf.channel_id = c.channel_id)
    LEFT JOIN dbo.mst_position_level pl
        ON pl.position_code = s.position_code
    WHERE s.batch_id = @batch_id
), src_dedup AS (
    SELECT
        employee_code,
        MAX(employee_name_th) AS employee_name_th,
        MAX(employee_name_en) AS employee_name_en,
        MAX(channel_id) AS channel_id,
        MAX(job_function_id) AS job_function_id,
        MAX(position_level_id) AS position_level_id,
        MAX(cost_center) AS cost_center,
        MAX(company_code) AS company_code,
        MIN(effective_from) AS effective_from,
        MAX(effective_to) AS effective_to,
        CAST(MAX(CAST(is_active AS tinyint)) AS bit) AS is_active
    FROM src
    GROUP BY employee_code
)
MERGE dbo.mst_employee AS tgt
USING src_dedup AS src
ON tgt.employee_code = src.employee_code
WHEN MATCHED THEN
    UPDATE SET
        tgt.employee_name_th = src.employee_name_th,
        tgt.employee_name_en = src.employee_name_en,
        tgt.channel_id = src.channel_id,
        tgt.job_function_id = src.job_function_id,
        tgt.position_level_id = src.position_level_id,
        tgt.cost_center = src.cost_center,
        tgt.company_code = src.company_code,
        tgt.effective_from = src.effective_from,
        tgt.effective_to = src.effective_to,
        tgt.is_active = src.is_active,
        tgt.updated_at = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (
        employee_code,
        employee_name_th,
        employee_name_en,
        channel_id,
        job_function_id,
        position_level_id,
        cost_center,
        company_code,
        effective_from,
        effective_to,
        is_active
    )
    VALUES (
        src.employee_code,
        src.employee_name_th,
        src.employee_name_en,
        src.channel_id,
        src.job_function_id,
        src.position_level_id,
        src.cost_center,
        src.company_code,
        src.effective_from,
        src.effective_to,
        src.is_active
    );
"@

        $mergeCmd = $cn.CreateCommand()
        $mergeCmd.Transaction = $tx
        $mergeCmd.CommandText = $mergeSql
        $mergeCmd.CommandTimeout = 0
        [void]$mergeCmd.Parameters.Add('@batch_id', [System.Data.SqlDbType]::NVarChar, 50)
        $mergeCmd.Parameters['@batch_id'].Value = $BatchId
        [void]$mergeCmd.ExecuteNonQuery()

        $tx.Commit()
    }
    catch {
        $tx.Rollback()
        throw
    }
}
finally {
    $cn.Close()
}

Write-Output ('BATCH_ID=' + $BatchId)
Write-Output ('DATA_MONTH=' + $DataMonth.ToString('yyyy-MM-01'))
Write-Output ('STG_LOADED_ROWS=' + $staging.Rows.Count)
Write-Output 'MERGE_TO_MST_EMPLOYEE=DONE'
