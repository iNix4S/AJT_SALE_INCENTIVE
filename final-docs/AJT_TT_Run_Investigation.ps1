################################################################
# AJT TT – Run Investigation Script
# Purpose : รันการตรวจสอบ incentive ของพนักงาน TT แบบ end-to-end
#           เทียบ DB result vs sheet reference ทีละ layer
#
# Usage   :
#   .\AJT_TT_Run_Investigation.ps1
#   .\AJT_TT_Run_Investigation.ps1 -SalesmanCode 110002 -PeriodCode FY2026-05
#
# Output  : console table + optional -OutputCsv .\result.csv
################################################################

param(
    [string]$SalesmanCode  = '110001',
    [string]$PeriodCode    = 'FY2026-05',
    [string]$TeamProducts  = 'R,Y',
    [string]$OutputCsv     = '',
    [string]$EnvFile       = 'environment/database-dev.env'
)

# ── Sheet reference per-product (salesman 110001, May-26)
# แก้ตารางนี้ให้ตรงกับค่าในชีตของ salesman ที่ต้องการทดสอบ
# format: product_code = sheet_incentive_amount
$SheetRef = @{
    'A'  = 180.00
    'R'  = 400.00
    'B'  = 1040.00
    'P'  = 360.00
    'Y'  = 600.00
    'AP' = 200.00
    'M'  = 190.00
    'Q'  = 520.00
    'RK' = 180.00
    'NS' = 360.00
    'T'  = 260.00
}
$SheetStaffTotal   = 4290.00
$SheetPctSalesmanR = 1.00   # %Salesman column จาก sheet สำหรับ R
$SheetPctSalesmanY = 1.00   # %Salesman column จาก sheet สำหรับ Y

# ── Connection
$line = Get-Content $EnvFile | Where-Object { $_ -match '^DB_CONNECTION_STRING=' } | Select-Object -First 1
$cs   = $line.Substring('DB_CONNECTION_STRING='.Length)

function Exec-Query($cn, $sql, $label) {
    $cmd = $cn.CreateCommand()
    $cmd.CommandTimeout = 0
    $cmd.CommandText = $sql
    $da = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
    $ds = New-Object System.Data.DataSet
    [void]$da.Fill($ds)
    Write-Host "`n$('─'*72)" -ForegroundColor Cyan
    Write-Host "  $label" -ForegroundColor Yellow
    Write-Host "$('─'*72)" -ForegroundColor Cyan
    foreach ($tbl in $ds.Tables) {
        if ($tbl.Rows.Count -gt 0) {
            $tbl | Format-Table -AutoSize | Out-String | Write-Host
        }
    }
    return $ds
}

$cn = New-Object System.Data.SqlClient.SqlConnection($cs)
$cn.Open()

try {
    # ── 0: EXEC stored procedure
    Exec-Query $cn @"
EXEC dbo.usp_check_tt_sheet_employee_reference
    @PeriodCode      = N'$PeriodCode',
    @EmployeeListCsv = N'$SalesmanCode',
    @ChannelCode     = N'TT',
    @InputSheetName  = N'1) For HR',
    @InputSheetFile  = N'15_1) For HR.values.csv';
"@ "STEP 0 : usp_check_tt_sheet_employee_reference (@PeriodCode=$PeriodCode, @SalesmanCode=$SalesmanCode)"

    # ── resolve IDs
    $idsResult = Exec-Query $cn @"
DECLARE @tt INT=(SELECT channel_id FROM dbo.mst_channel WHERE channel_code=N'TT');
DECLARE @pid INT=(SELECT period_id FROM dbo.mst_period WHERE period_code=N'$PeriodCode');
DECLARE @rid INT=(SELECT TOP 1 calc_run_id FROM dbo.trn_calc_run WHERE channel_id=@tt AND period_id=@pid ORDER BY calc_run_id DESC);
SELECT @tt AS tt, @pid AS period_id, @rid AS run_id;
"@ "RESOLVE IDs"
    $tt        = $idsResult.Tables[0].Rows[0]['tt']
    $periodId  = $idsResult.Tables[0].Rows[0]['period_id']
    $rid       = $idsResult.Tables[0].Rows[0]['run_id']

    # ── L6: per-product comparison with sheet reference
    $sheetCaseDB = ($SheetRef.Keys | Sort-Object | ForEach-Object {
        "WHEN '$_' THEN $($SheetRef[$_])"
    }) -join ' '

    Exec-Query $cn @"
DECLARE @run_id INT = $rid;
SELECT
    d.product_code,
    CAST(d.final_achievement AS DECIMAL(9,4)) AS final_ach_used,
    CAST(d.goal_multiplier AS DECIMAL(9,4))   AS mult_db,
    d.incentive_amount                         AS db_incentive,
    CASE d.product_code $sheetCaseDB ELSE NULL END AS sheet_incentive,
    d.incentive_amount
      - CASE d.product_code $sheetCaseDB ELSE 0 END AS gap,
    CASE WHEN ABS(d.incentive_amount
                  - CASE d.product_code $sheetCaseDB ELSE 0 END) < 0.01
         THEN N'PASS' ELSE N'FAIL' END AS status
FROM dbo.trn_incentive_detail d
WHERE d.calc_run_id = @run_id
  AND d.salesman_code = N'$SalesmanCode'
  AND d.position_level_code = N'STAFF'
ORDER BY d.product_code;
"@ "L6 : Per-product comparison (DB vs Sheet)"

    # ── L7: For HR output
    Exec-Query $cn @"
DECLARE @run_id INT = $rid;
SELECT
    o.employee_code,
    o.incentive_staff,
    o.gd_incentive_total,
    o.total_variable,
    $SheetStaffTotal AS sheet_staff_total,
    o.incentive_staff - $SheetStaffTotal AS gap_incentive_staff
FROM dbo.out_for_hr_variable o
WHERE o.calc_run_id = $rid AND o.employee_code = N'$SalesmanCode';
"@ "L7 : For HR output vs sheet expected ($SheetStaffTotal)"

    # ── L4 / L10: team achievement for team-level products
    $teamProdSql = ($TeamProducts.Split(',') | ForEach-Object { "'$($_.Trim())'" }) -join ','
    Exec-Query $cn @"
DECLARE @tt INT=$tt; DECLARE @period_id INT=$periodId;
SELECT
    t.product_code,
    COUNT(DISTINCT t.salesman_code)           AS salesman_count,
    SUM(t.target_amount)                      AS team_target,
    SUM(COALESCE(a.actual_amount,0))          AS team_actual,
    CAST(SUM(COALESCE(a.actual_amount,0))
        /NULLIF(SUM(t.target_amount),0) AS DECIMAL(9,4)) AS team_achievement,
    /* Which band does this fall in? */
    (SELECT TOP 1 CAST(gt.multiplier AS DECIMAL(9,4))
     FROM dbo.mst_goal_threshold gt
     WHERE gt.is_active=1
       AND SUM(COALESCE(a.actual_amount,0))/NULLIF(SUM(t.target_amount),0)
           >= gt.achievement_from
       AND (gt.achievement_to IS NULL
            OR SUM(COALESCE(a.actual_amount,0))/NULLIF(SUM(t.target_amount),0)
               < gt.achievement_to)
     ORDER BY gt.achievement_from DESC) AS db_mult_from_team_ach
FROM dbo.trn_sales_target t
LEFT JOIN dbo.trn_sales_actual a
    ON  a.channel_id=t.channel_id AND a.period_id=t.period_id
    AND a.salesman_code=t.salesman_code AND a.product_code=t.product_code
WHERE t.channel_id=@tt AND t.period_id=@period_id
  AND t.product_code IN ($teamProdSql)
GROUP BY t.product_code
ORDER BY t.product_code;
"@ "L4/L10 : Team achievement for team-level products ($TeamProducts)"

    # ── Root cause summary
    Write-Host "`n$('═'*72)" -ForegroundColor Magenta
    Write-Host "  ROOT CAUSE SUMMARY" -ForegroundColor Magenta
    Write-Host "$('═'*72)" -ForegroundColor Magenta

    $ds6 = $cn.CreateCommand()
    $ds6.CommandText = @"
DECLARE @run_id INT=$rid;
SELECT SUM(d.incentive_amount) AS db_total
FROM dbo.trn_incentive_detail d
WHERE d.calc_run_id=@run_id AND d.salesman_code=N'$SalesmanCode' AND d.position_level_code=N'STAFF';
"@
    $rdr = $ds6.ExecuteScalar()
    $dbTotal = [decimal]$rdr
    $gap = $dbTotal - $SheetStaffTotal

    Write-Host ""
    Write-Host ("  DB incentive_staff total : {0,10:N2}" -f $dbTotal)   -ForegroundColor White
    Write-Host ("  Sheet expected total     : {0,10:N2}" -f $SheetStaffTotal) -ForegroundColor White
    Write-Host ("  Gap (DB - Sheet)         : {0,10:N2}" -f $gap) -ForegroundColor $(if ([Math]::Abs($gap) -lt 1) {'Green'} else {'Red'})
    Write-Host ""

    if ([Math]::Abs($gap) -lt 1) {
        Write-Host "  RESULT: PASS – DB matches sheet within 1 baht." -ForegroundColor Green
    } else {
        Write-Host "  RESULT: FAIL – remaining gap needs investigation." -ForegroundColor Red
        Write-Host ""
        Write-Host "  Common causes:" -ForegroundColor Yellow
        Write-Host "    [R, Y] Sheet uses section/team achievement that differs from channel-wide team_ach in test DB."
        Write-Host "           Sheet's '%Salesman' column = pre-computed mult (R=1.0, Y=1.0)."
        Write-Host "           DB team_ach for R = channel-wide SUM(actual)/SUM(target) for all $($TeamProducts.Split(',').Count*7) salesmen."
        Write-Host "           To match exactly: upload production data with correct team scope, OR"
        Write-Host "           Add pct_salesman column to trn_sales_target from sheet import."
    }
    Write-Host ""
    Write-Host "  To investigate further, run: final-docs\AJT_TT_Incentive_Investigation_Script.sql" -ForegroundColor Cyan
    Write-Host "  Change @SalesmanCode and @TeamProductCsv as needed." -ForegroundColor Cyan
    Write-Host ""

    # optional CSV export
    if ($OutputCsv -ne '') {
        $exportSql = @"
DECLARE @run_id INT=$rid;
SELECT d.product_code, d.final_achievement, d.goal_multiplier, d.incentive_amount,
       CASE d.product_code $sheetCaseDB ELSE NULL END AS sheet_incentive,
       d.incentive_amount - CASE d.product_code $sheetCaseDB ELSE 0 END AS gap
FROM dbo.trn_incentive_detail d
WHERE d.calc_run_id=@run_id AND d.salesman_code=N'$SalesmanCode' AND d.position_level_code=N'STAFF'
ORDER BY d.product_code;
"@
        $ecmd = $cn.CreateCommand(); $ecmd.CommandText = $exportSql
        $eda = New-Object System.Data.SqlClient.SqlDataAdapter($ecmd)
        $edt = New-Object System.Data.DataTable; [void]$eda.Fill($edt)
        $edt | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
        Write-Host "  CSV exported: $OutputCsv" -ForegroundColor Green
    }
}
finally {
    $cn.Close()
}
