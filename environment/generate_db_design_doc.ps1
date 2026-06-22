$OutputPath = "d:\Users\wimut\OneDrive - CDS SOLUTION CORP.,COMPANY LIMITED\My Projects\28.AJT New Sale Incentive\environment\AJT_SIS_Database_Design_v1.0_2026-06-13.docx"

try {
    $Word = New-Object -ComObject Word.Application
    $Word.Visible = $false
    $Doc = $Word.Documents.Add()
    $Sel = $Word.Selection

    # ── Styles helper ─────────────────────────────────────────────────────────────
    function Set-Style($sel, $styleName) {
        try { $sel.Style = $styleName } catch {}
    }
    function Add-Heading1($sel, $text) {
        Set-Style $sel "Heading 1"
        $sel.TypeText($text)
        $sel.TypeParagraph()
        Set-Style $sel "Normal"
    }
    function Add-Heading2($sel, $text) {
        Set-Style $sel "Heading 2"
        $sel.TypeText($text)
        $sel.TypeParagraph()
        Set-Style $sel "Normal"
    }
    function Add-Heading3($sel, $text) {
        Set-Style $sel "Heading 3"
        $sel.TypeText($text)
        $sel.TypeParagraph()
        Set-Style $sel "Normal"
    }
    function Add-Para($sel, $text) {
        Set-Style $sel "Normal"
        $sel.TypeText($text)
        $sel.TypeParagraph()
    }
    function Add-Bold($sel, $label, $value) {
        $sel.Font.Bold = $true;  $sel.TypeText($label)
        $sel.Font.Bold = $false; $sel.TypeText($value)
        $sel.TypeParagraph()
    }

    # ── TABLE HELPER ──────────────────────────────────────────────────────────────
    function Add-TableRow($table, $row, $cols) {
        for ($c = 0; $c -lt $cols.Count; $c++) {
            $table.Cell($row, $c + 1).Range.Text = $cols[$c]
        }
    }
    function Style-HeaderRow($table) {
        $row = $table.Rows(1)
        $row.Range.Font.Bold = $true
        $row.Range.Font.Size = 9
        $row.Shading.BackgroundPatternColor = 0x004080  # dark blue
        $row.Range.Font.Color = 16777215               # white
    }

    # ══════════════════════════════════════════════════════════════════════════════
    # COVER PAGE
    # ══════════════════════════════════════════════════════════════════════════════
    Set-Style $Sel "Title"
    $Sel.TypeText("AJT Sale Incentive System")
    $Sel.TypeParagraph()
    Set-Style $Sel "Subtitle"
    $Sel.TypeText("Database Design Document — POC")
    $Sel.TypeParagraph()
    Set-Style $Sel "Normal"
    $Sel.TypeParagraph()
    Add-Bold $Sel "Version : " "1.0"
    Add-Bold $Sel "Date    : " "2026-06-13"
    Add-Bold $Sel "Status  : " "Draft — POC"
    Add-Bold $Sel "Database: " "AJT_SIS  (SQL Server localhost,1437)"
    Add-Bold $Sel "Schema  : " "dbo"
    Add-Bold $Sel "Author  : " "System Analyst / SA Team"
    $Sel.InsertBreak(7)  # Page break

    # ══════════════════════════════════════════════════════════════════════════════
    # 1. OVERVIEW
    # ══════════════════════════════════════════════════════════════════════════════
    Add-Heading1 $Sel "1. ภาพรวมระบบ (System Overview)"
    Add-Para $Sel "ระบบ AJT Sale Incentive System เป็นระบบจัดการและคำนวณค่าตอบแทนการขาย (Sales Incentive) สำหรับ 4 ช่องทาง ได้แก่ MT (Modern Trade), TT (Traditional Trade), S&I และ Laos โดย migrate จากระบบ Excel ปัจจุบันมาเป็นระบบที่จัดการได้ผ่าน Nintex K2 Workflow + .NET Core API"
    Add-Para $Sel "เอกสารนี้ระบุโครงสร้างฐานข้อมูลระดับ POC ประกอบด้วย Master Tables 19 ตาราง พร้อม Seed Data ตั้งต้น"

    Add-Heading2 $Sel "1.1 สภาพแวดล้อมฐานข้อมูล (Database Environment)"
    $envTbl = $Doc.Tables.Add($Sel.Range, 5, 2)
    $envTbl.Borders.Enable = $true
    Add-TableRow $envTbl 1 @("Parameter","Value")
    Add-TableRow $envTbl 2 @("Server","localhost,1437")
    Add-TableRow $envTbl 3 @("Database","AJT_SIS")
    Add-TableRow $envTbl 4 @("Schema","dbo (default)")
    Add-TableRow $envTbl 5 @("Authentication","SQL Login — sa")
    Style-HeaderRow $envTbl
    $envTbl.AutoFitBehavior(1)
    $Sel.EndOf(6) | Out-Null
    $Sel.MoveDown()
    $Sel.TypeParagraph()

    # ══════════════════════════════════════════════════════════════════════════════
    # 2. TABLE INVENTORY
    # ══════════════════════════════════════════════════════════════════════════════
    Add-Heading1 $Sel "2. รายการตาราง (Table Inventory)"
    $invTbl = $Doc.Tables.Add($Sel.Range, 20, 4)
    $invTbl.Borders.Enable = $true
    Add-TableRow $invTbl 1 @("Table Name","Group","Seed Rows","Description")
    $rows = @(
        @("mst_channel","Master","4","ช่องทางขาย — MT,TT,S&I,Laos + calc_type"),
        @("mst_position_level","Master","5","ระดับตำแหน่ง Staff/Sect/Dept/Div/AD (hierarchy)"),
        @("mst_goal_threshold","Parameter","10","GOAL table: achievement → multiplier (0.9–1.3)"),
        @("mst_payment_cycle","Parameter","12","M_Month: เดือนยอดขาย → รอบจ่าย Variable & Fixed"),
        @("mst_period","Transaction","0","รอบคำนวณรายเดือน + สถานะรอบ"),
        @("mst_job_function","Master","11","Job Function รวม fixed-rate eligible flag"),
        @("mst_employee","Transaction","0","ข้อมูลพนักงาน (import จาก HCM)"),
        @("mst_org_hierarchy","Transaction","0","ASTBase: Salesman → DirectSup → Dept → AD"),
        @("mst_product","Master","11","สินค้า 11 ชนิด รวม GD flag และ GD code"),
        @("mst_product_mapping","Reference","0","Map MT ↔ TT product code / BI source code"),
        @("mst_salesman_mapping","Reference","0","MT Mapping: BI SalesCode+ProductGroup → Salesman"),
        @("mst_incentive_rate","Parameter","0","Base incentive rate ตามตำแหน่ง + WS type"),
        @("mst_product_weight","Parameter","0","Product weight per channel + WS type"),
        @("mst_shortage_policy","Parameter","0","Shortage flag ราย product+month"),
        @("mst_fix_rate","Parameter","6","Fixed Rate ราย Job Function — TT channel"),
        @("mst_gd_product","Master","4","GD products: AJI-PLUS, RDQ, RDM, RDNS"),
        @("mst_gd_payout","Parameter","40","GD payout step table ราย product × threshold"),
        @("mst_system_parameter","Config","0","System config กลาง — key/value"),
        @("mst_policy_rule","Config","5","Open Questions / policy rules รอยืนยัน")
    )
    for ($i = 0; $i -lt $rows.Count; $i++) {
        Add-TableRow $invTbl ($i+2) $rows[$i]
    }
    Style-HeaderRow $invTbl
    $invTbl.AutoFitBehavior(1)
    $Sel.EndOf(6) | Out-Null
    $Sel.MoveDown()
    $Sel.TypeParagraph()
    $Sel.InsertBreak(7)

    # ══════════════════════════════════════════════════════════════════════════════
    # 3. ENTITY RELATIONSHIPS
    # ══════════════════════════════════════════════════════════════════════════════
    Add-Heading1 $Sel "3. ความสัมพันธ์ระหว่างตาราง (Entity Relationships)"
    Add-Para $Sel "Foreign Key Relationships ทั้งหมดในระบบ (dbo schema):"
    $fkTbl = $Doc.Tables.Add($Sel.Range, 16, 4)
    $fkTbl.Borders.Enable = $true
    Add-TableRow $fkTbl 1 @("FK Constraint","Parent Table.Column","→","Referenced Table.Column")
    $fkRows = @(
        @("FK_mst_job_function_channel",     "mst_job_function.channel_id",       "→","mst_channel.channel_id"),
        @("FK_mst_employee_channel",          "mst_employee.channel_id",           "→","mst_channel.channel_id"),
        @("FK_mst_employee_job_function",     "mst_employee.job_function_id",      "→","mst_job_function.job_function_id"),
        @("FK_mst_employee_position_level",   "mst_employee.position_level_id",    "→","mst_position_level.position_level_id"),
        @("FK_mst_org_hierarchy_channel",     "mst_org_hierarchy.channel_id",      "→","mst_channel.channel_id"),
        @("FK_mst_product_mapping_product",   "mst_product_mapping.target_product_id","→","mst_product.product_id"),
        @("FK_mst_salesman_mapping_channel",  "mst_salesman_mapping.channel_id",   "→","mst_channel.channel_id"),
        @("FK_mst_incentive_rate_channel",    "mst_incentive_rate.channel_id",     "→","mst_channel.channel_id"),
        @("FK_mst_incentive_rate_pos_level",  "mst_incentive_rate.position_level_id","→","mst_position_level.position_level_id"),
        @("FK_mst_product_weight_channel",    "mst_product_weight.channel_id",     "→","mst_channel.channel_id"),
        @("FK_mst_product_weight_product",    "mst_product_weight.product_id",     "→","mst_product.product_id"),
        @("FK_mst_shortage_policy_product",   "mst_shortage_policy.product_id",    "→","mst_product.product_id"),
        @("FK_mst_fix_rate_channel",          "mst_fix_rate.channel_id",           "→","mst_channel.channel_id"),
        @("FK_mst_fix_rate_job_function",     "mst_fix_rate.job_function_id",      "→","mst_job_function.job_function_id"),
        @("FK_mst_gd_product_product",        "mst_gd_product.product_id",         "→","mst_product.product_id"),
        @("FK_mst_gd_payout_gd_product",      "mst_gd_payout.gd_product_id",       "→","mst_gd_product.gd_product_id")
    )
    for ($i = 0; $i -lt $fkRows.Count; $i++) {
        Add-TableRow $fkTbl ($i+2) $fkRows[$i]
    }
    Style-HeaderRow $fkTbl
    $fkTbl.AutoFitBehavior(1)
    $Sel.EndOf(6) | Out-Null
    $Sel.MoveDown()
    $Sel.TypeParagraph()
    $Sel.InsertBreak(7)

    # ══════════════════════════════════════════════════════════════════════════════
    # 4. TABLE DEFINITIONS (19 tables)
    # ══════════════════════════════════════════════════════════════════════════════
    Add-Heading1 $Sel "4. คำจำกัดความตาราง (Table Definitions)"

    # Helper: create a column-definition table
    function Add-ColTable($doc, $sel, $cols) {
        # $cols = array of @(colname, datatype, nullable, pk, default, description)
        $t = $doc.Tables.Add($sel.Range, ($cols.Count+1), 6)
        $t.Borders.Enable = $true
        Add-TableRow $t 1 @("Column","Data Type","Null","PK","Default","Description")
        for ($i = 0; $i -lt $cols.Count; $i++) {
            Add-TableRow $t ($i+2) $cols[$i]
        }
        Style-HeaderRow $t
        # set column widths
        $t.Columns(1).SetWidth(110, 2)
        $t.Columns(2).SetWidth(100, 2)
        $t.Columns(3).SetWidth(35,  2)
        $t.Columns(4).SetWidth(25,  2)
        $t.Columns(5).SetWidth(80,  2)
        $t.Columns(6).SetWidth(120, 2)
        $t.Range.Font.Size = 8
        $sel.EndOf(6) | Out-Null
        $sel.MoveDown()
        $sel.TypeParagraph()
    }

    # ── mst_channel ───────────────────────────────────────────────────────────────
    Add-Heading2 $Sel "4.1 mst_channel"
    Add-Para $Sel "ตารางช่องทางขาย — MT, TT, S&I, Laos พร้อมระบุประเภทการคำนวณ"
    Add-ColTable $Doc $Sel @(
        @("channel_id",      "INT IDENTITY","NO","PK","auto","Primary Key"),
        @("channel_code",    "NVARCHAR(20)", "NO","",  "","รหัสช่องทาง เช่น MT, TT"),
        @("channel_name_th", "NVARCHAR(100)","NO","",  "","ชื่อช่องทาง (ภาษาไทย)"),
        @("channel_name_en", "NVARCHAR(100)","NO","",  "","ชื่อช่องทาง (ภาษาอังกฤษ)"),
        @("calc_type",       "NVARCHAR(30)", "NO","",  "","CASCADE_4_LEVEL / SINGLE_SHEET"),
        @("is_active",       "BIT",          "NO","",  "1","สถานะใช้งาน"),
        @("created_at",      "DATETIME2(0)", "NO","",  "SYSUTCDATETIME()","เวลาสร้างข้อมูล (UTC)"),
        @("updated_at",      "DATETIME2(0)", "YES","", "","เวลาแก้ไขล่าสุด")
    )

    # ── mst_position_level ────────────────────────────────────────────────────────
    Add-Heading2 $Sel "4.2 mst_position_level"
    Add-Para $Sel "ระดับตำแหน่ง — Staff(1) → Section Manager(2) → Dept Manager(3) → Division Manager(4) → AD(5)"
    Add-ColTable $Doc $Sel @(
        @("position_level_id","INT IDENTITY","NO","PK","auto","Primary Key"),
        @("position_code",    "NVARCHAR(50)", "NO","",  "","รหัสตำแหน่ง เช่น STAFF, SECT_MGR"),
        @("position_name_th", "NVARCHAR(100)","NO","",  "","ชื่อตำแหน่ง (ภาษาไทย)"),
        @("position_name_en", "NVARCHAR(100)","YES","", "","ชื่อตำแหน่ง (ภาษาอังกฤษ)"),
        @("hierarchy_level",  "TINYINT",      "NO","",  "","ลำดับ cascade (1=ล่างสุด, 5=สูงสุด)"),
        @("is_active",        "BIT",          "NO","",  "1","สถานะใช้งาน"),
        @("created_at",       "DATETIME2(0)", "NO","",  "SYSUTCDATETIME()","เวลาสร้าง"),
        @("updated_at",       "DATETIME2(0)", "YES","", "","เวลาแก้ไข")
    )

    # ── mst_goal_threshold ────────────────────────────────────────────────────────
    Add-Heading2 $Sel "4.3 mst_goal_threshold"
    Add-Para $Sel "GOAL Table — ตาราง achievement threshold → multiplier แบบ step-down จาก Top WS sheet"
    Add-ColTable $Doc $Sel @(
        @("goal_threshold_id","INT IDENTITY","NO","PK","auto","Primary Key"),
        @("achievement_from", "DECIMAL(9,4)", "NO","",  "","ขั้นต่ำ achievement (inclusive)"),
        @("achievement_to",   "DECIMAL(9,4)", "YES","", "","ขั้นสูงสุด (NULL = ไม่มี cap)"),
        @("multiplier",       "DECIMAL(9,4)", "NO","",  "","ตัวคูณ GOAL (0.00 – 1.30)"),
        @("sequence_no",      "INT",          "NO","",  "","ลำดับ (1–10)"),
        @("is_active",        "BIT",          "NO","",  "1","สถานะใช้งาน"),
        @("created_at",       "DATETIME2(0)", "NO","",  "SYSUTCDATETIME()","เวลาสร้าง"),
        @("updated_at",       "DATETIME2(0)", "YES","", "","เวลาแก้ไข")
    )

    # ── mst_payment_cycle ─────────────────────────────────────────────────────────
    Add-Heading2 $Sel "4.4 mst_payment_cycle"
    Add-Para $Sel "M_Month — Payment Calendar: map เดือนยอดขาย → รอบจ่าย Variable และ Fixed แยกกัน (Fixed เร็วกว่า Variable 1 เดือน)"
    Add-ColTable $Doc $Sel @(
        @("payment_cycle_id",  "INT IDENTITY","NO","PK","auto","Primary Key"),
        @("sales_month",       "DATE",        "NO","",  "","เดือนยอดขาย (YYYY-MM-01)"),
        @("variable_pay_month","DATE",        "NO","",  "","รอบจ่าย Variable Incentive"),
        @("fixed_pay_month",   "DATE",        "NO","",  "","รอบจ่าย Fixed Incentive"),
        @("display_order",     "TINYINT",     "NO","",  "","ลำดับแสดงผล (1–12)"),
        @("is_active",         "BIT",         "NO","",  "1","สถานะใช้งาน"),
        @("created_at",        "DATETIME2(0)","NO","",  "SYSUTCDATETIME()","เวลาสร้าง"),
        @("updated_at",        "DATETIME2(0)","YES","", "","เวลาแก้ไข")
    )

    # ── mst_period ────────────────────────────────────────────────────────────────
    Add-Heading2 $Sel "4.5 mst_period"
    Add-Para $Sel "รอบคำนวณรายเดือน — Period ที่ user ตั้งใน workflow แต่ละรอบ พร้อมสถานะ Draft/Calculated/Approved/Exported"
    Add-ColTable $Doc $Sel @(
        @("period_id",  "INT IDENTITY","NO","PK","auto","Primary Key"),
        @("period_code","NVARCHAR(20)", "NO","",  "","รหัสรอบ เช่น 2026-04"),
        @("sales_month","DATE",        "NO","",  "","เดือนยอดขาย (FK-ready กับ mst_payment_cycle)"),
        @("year_no",    "INT",         "NO","",  "","ปี (เช่น 2026)"),
        @("month_no",   "TINYINT",     "NO","",  "","เดือน (1–12)"),
        @("status",     "NVARCHAR(30)","NO","",  "","Draft/Calculated/Reviewed/Approved/Exported"),
        @("is_closed",  "BIT",         "NO","",  "0","ปิดรอบแล้ว"),
        @("created_at", "DATETIME2(0)","NO","",  "SYSUTCDATETIME()","เวลาสร้าง"),
        @("updated_at", "DATETIME2(0)","YES","", "","เวลาแก้ไข")
    )
    $Sel.InsertBreak(7)

    # ── mst_job_function ──────────────────────────────────────────────────────────
    Add-Heading2 $Sel "4.6 mst_job_function"
    Add-Para $Sel "Job Function ทั้งหมด — ครอบคลุม Fixed-Rate group (TT) และ cascade roles (MT+TT)"
    Add-ColTable $Doc $Sel @(
        @("job_function_id",       "INT IDENTITY","NO","PK","auto","Primary Key"),
        @("job_function_code",     "NVARCHAR(50)", "NO","",  "","รหัส เช่น TT_CV_SALES"),
        @("job_function_name_th",  "NVARCHAR(150)","NO","",  "","ชื่อภาษาไทย"),
        @("job_function_name_en",  "NVARCHAR(150)","YES","", "","ชื่อภาษาอังกฤษ"),
        @("channel_id",            "INT",          "YES","", "","FK→mst_channel (NULL=ทุก channel)"),
        @("is_fixed_rate_eligible","BIT",          "NO","",  "0","1=จ่าย Fixed Rate"),
        @("is_active",             "BIT",          "NO","",  "1","สถานะใช้งาน"),
        @("created_at",            "DATETIME2(0)", "NO","",  "SYSUTCDATETIME()","เวลาสร้าง"),
        @("updated_at",            "DATETIME2(0)", "YES","", "","เวลาแก้ไข")
    )

    # ── mst_employee ──────────────────────────────────────────────────────────────
    Add-Heading2 $Sel "4.7 mst_employee"
    Add-Para $Sel "ข้อมูลพนักงาน — import จาก HCM Personal Employment report รายเดือน"
    Add-ColTable $Doc $Sel @(
        @("employee_id",      "INT IDENTITY","NO","PK","auto","Primary Key"),
        @("employee_code",    "NVARCHAR(50)", "NO","",  "","Employee Code (unique)"),
        @("employee_name_th", "NVARCHAR(200)","NO","",  "","ชื่อพนักงาน (ภาษาไทย)"),
        @("employee_name_en", "NVARCHAR(200)","YES","", "","ชื่อพนักงาน (ภาษาอังกฤษ)"),
        @("channel_id",       "INT",          "YES","", "","FK→mst_channel"),
        @("job_function_id",  "INT",          "YES","", "","FK→mst_job_function"),
        @("position_level_id","INT",          "YES","", "","FK→mst_position_level"),
        @("cost_center",      "NVARCHAR(50)", "YES","", "","Cost Center"),
        @("company_code",     "NVARCHAR(50)", "YES","", "","Company Code"),
        @("effective_from",   "DATE",         "NO","",  "","วันเริ่มมีผล"),
        @("effective_to",     "DATE",         "YES","", "","วันสิ้นผล"),
        @("is_active",        "BIT",          "NO","",  "1","สถานะใช้งาน"),
        @("created_at",       "DATETIME2(0)", "NO","",  "SYSUTCDATETIME()","เวลาสร้าง"),
        @("updated_at",       "DATETIME2(0)", "YES","", "","เวลาแก้ไข")
    )

    # ── mst_org_hierarchy ─────────────────────────────────────────────────────────
    Add-Heading2 $Sel "4.8 mst_org_hierarchy"
    Add-Para $Sel "โครงสร้างสายงาน (ASTBase) — Salesman → DirectSup → DeptMgr → DivMgr → AD ราย effective_month"
    Add-ColTable $Doc $Sel @(
        @("hierarchy_id",    "INT IDENTITY","NO","PK","auto","Primary Key"),
        @("channel_id",      "INT",         "NO","",  "","FK→mst_channel"),
        @("effective_month", "DATE",        "NO","",  "","เดือนที่มีผล (YYYY-MM-01)"),
        @("salesman_code",   "NVARCHAR(50)","NO","",  "","รหัส Salesman (Staff)"),
        @("direct_sup_code", "NVARCHAR(50)","YES","", "","รหัส Section Manager"),
        @("dept_mgr_code",   "NVARCHAR(50)","YES","", "","รหัส Department Manager"),
        @("div_mgr_code",    "NVARCHAR(50)","YES","", "","รหัส Division Manager"),
        @("ad_code",         "NVARCHAR(50)","YES","", "","รหัส Associate Director"),
        @("is_active",       "BIT",         "NO","",  "1","สถานะใช้งาน"),
        @("created_at",      "DATETIME2(0)","NO","",  "SYSUTCDATETIME()","เวลาสร้าง"),
        @("updated_at",      "DATETIME2(0)","YES","", "","เวลาแก้ไข")
    )
    $Sel.InsertBreak(7)

    # ── mst_product ───────────────────────────────────────────────────────────────
    Add-Heading2 $Sel "4.9 mst_product"
    Add-Para $Sel "Master สินค้า 11 ชนิด — แยกกลุ่ม G1_CORE, G2_GD, G3_BB, OTHERS และระบุ GD product code"
    Add-ColTable $Doc $Sel @(
        @("product_id",        "INT IDENTITY","NO","PK","auto","Primary Key"),
        @("product_code",      "NVARCHAR(50)", "NO","",  "","รหัสสินค้า เช่น AJ, RD, AJP"),
        @("product_name_th",   "NVARCHAR(200)","NO","",  "","ชื่อสินค้า (ภาษาไทย)"),
        @("product_name_en",   "NVARCHAR(200)","YES","", "","ชื่อสินค้า (ภาษาอังกฤษ)"),
        @("product_group_code","NVARCHAR(50)", "YES","", "","กลุ่มสินค้า G1_CORE/G2_GD/G3_BB/OTHERS"),
        @("product_group_name","NVARCHAR(150)","YES","", "","ชื่อกลุ่มสินค้า"),
        @("is_gd_product",     "BIT",          "NO","",  "0","1=สินค้า Growth Driver"),
        @("gd_product_code",   "NVARCHAR(50)", "YES","", "","รหัส GD ย่อ (AP,Q,M,NS)"),
        @("is_active",         "BIT",          "NO","",  "1","สถานะใช้งาน"),
        @("created_at",        "DATETIME2(0)", "NO","",  "SYSUTCDATETIME()","เวลาสร้าง"),
        @("updated_at",        "DATETIME2(0)", "YES","", "","เวลาแก้ไข")
    )

    # ── mst_salesman_mapping ──────────────────────────────────────────────────────
    Add-Heading2 $Sel "4.10 mst_salesman_mapping"
    Add-Para $Sel "MT Mapping — BI SalesCode + ProductGroup → Salesman Code (ใช้เฉพาะ MT channel)"
    Add-ColTable $Doc $Sel @(
        @("salesman_mapping_id", "INT IDENTITY","NO","PK","auto","Primary Key"),
        @("channel_id",          "INT",         "NO","",  "","FK→mst_channel (MT=1)"),
        @("effective_month",     "DATE",        "NO","",  "","เดือนที่มีผล"),
        @("bi_sales_code",       "NVARCHAR(50)","NO","",  "","BI SalesCode"),
        @("product_group_code",  "NVARCHAR(50)","NO","",  "","รหัสกลุ่มสินค้า"),
        @("salesman_code",       "NVARCHAR(50)","NO","",  "","รหัส Salesman ที่ map ไป"),
        @("is_active",           "BIT",         "NO","",  "1","สถานะใช้งาน"),
        @("created_at",          "DATETIME2(0)","NO","",  "SYSUTCDATETIME()","เวลาสร้าง"),
        @("updated_at",          "DATETIME2(0)","YES","", "","เวลาแก้ไข")
    )

    # ── mst_incentive_rate ────────────────────────────────────────────────────────
    Add-Heading2 $Sel "4.11 mst_incentive_rate"
    Add-Para $Sel "Base Incentive Rate ตามตำแหน่ง + WS type (Top WS / WS SF / WS WH / SF WH)"
    Add-ColTable $Doc $Sel @(
        @("incentive_rate_id", "INT IDENTITY","NO","PK","auto","Primary Key"),
        @("channel_id",        "INT",         "NO","",  "","FK→mst_channel"),
        @("position_level_id", "INT",         "NO","",  "","FK→mst_position_level"),
        @("ws_type",           "NVARCHAR(50)","NO","",  "","ประเภท WS: TOP_WS/WS_SF/WS_WH/SF_WH"),
        @("rate_old",          "DECIMAL(18,2)","YES","", "","อัตราเก่า"),
        @("rate_new",          "DECIMAL(18,2)","YES","", "","อัตราใหม่"),
        @("effective_from",    "DATE",        "NO","",  "","วันเริ่มมีผล"),
        @("effective_to",      "DATE",        "YES","", "","วันสิ้นผล"),
        @("is_active",         "BIT",         "NO","",  "1","สถานะใช้งาน"),
        @("created_at",        "DATETIME2(0)","NO","",  "SYSUTCDATETIME()","เวลาสร้าง"),
        @("updated_at",        "DATETIME2(0)","YES","", "","เวลาแก้ไข")
    )
    $Sel.InsertBreak(7)

    # ── mst_product_weight ────────────────────────────────────────────────────────
    Add-Heading2 $Sel "4.12 mst_product_weight"
    Add-Para $Sel "น้ำหนักสินค้า (weight_percent) ราย channel + product + WS type รวม = 100%"
    Add-ColTable $Doc $Sel @(
        @("product_weight_id","INT IDENTITY","NO","PK","auto","Primary Key"),
        @("channel_id",       "INT",         "NO","",  "","FK→mst_channel"),
        @("product_id",       "INT",         "NO","",  "","FK→mst_product"),
        @("ws_type",          "NVARCHAR(50)","NO","",  "","ประเภท WS"),
        @("weight_percent",   "DECIMAL(9,4)","NO","",  "","สัดส่วนน้ำหนัก (0–1)"),
        @("effective_from",   "DATE",        "NO","",  "","วันเริ่มมีผล"),
        @("effective_to",     "DATE",        "YES","", "","วันสิ้นผล"),
        @("is_active",        "BIT",         "NO","",  "1","สถานะใช้งาน"),
        @("created_at",       "DATETIME2(0)","NO","",  "SYSUTCDATETIME()","เวลาสร้าง"),
        @("updated_at",       "DATETIME2(0)","YES","", "","เวลาแก้ไข")
    )

    # ── mst_shortage_policy ───────────────────────────────────────────────────────
    Add-Heading2 $Sel "4.13 mst_shortage_policy"
    Add-Para $Sel "Shortage Flag ราย product + month — บังคับ achievement = override_achievement (default 1.0000)"
    Add-ColTable $Doc $Sel @(
        @("shortage_policy_id",  "INT IDENTITY","NO","PK","auto","Primary Key"),
        @("product_id",          "INT",         "NO","",  "","FK→mst_product"),
        @("shortage_month",      "DATE",        "NO","",  "","เดือนที่ขาด (YYYY-MM-01)"),
        @("override_achievement","DECIMAL(9,4)","NO","",  "1.0000","achievement ที่ใช้แทน"),
        @("reason_code",         "NVARCHAR(50)","YES","", "","รหัสเหตุผล"),
        @("remarks",             "NVARCHAR(500)","YES","", "","หมายเหตุ"),
        @("is_active",           "BIT",         "NO","",  "1","สถานะใช้งาน"),
        @("created_at",          "DATETIME2(0)","NO","",  "SYSUTCDATETIME()","เวลาสร้าง"),
        @("updated_at",          "DATETIME2(0)","YES","", "","เวลาแก้ไข")
    )

    # ── mst_fix_rate ──────────────────────────────────────────────────────────────
    Add-Heading2 $Sel "4.14 mst_fix_rate"
    Add-Para $Sel "Fixed Rate ราย Job Function — ค่าจ้างคงที่รายเดือน ไม่ขึ้นกับ achievement | Source: ค่าตอบแทนการขายในอัตราคงที่"
    Add-ColTable $Doc $Sel @(
        @("fix_rate_id",    "INT IDENTITY","NO","PK","auto","Primary Key"),
        @("channel_id",     "INT",         "NO","",  "","FK→mst_channel"),
        @("job_function_id","INT",         "NO","",  "","FK→mst_job_function"),
        @("amount",         "DECIMAL(18,2)","NO","", "","จำนวนเงิน (บาท/เดือน)"),
        @("effective_from", "DATE",        "NO","",  "","วันเริ่มมีผล"),
        @("effective_to",   "DATE",        "YES","", "","วันสิ้นผล"),
        @("is_active",      "BIT",         "NO","",  "1","สถานะใช้งาน"),
        @("created_at",     "DATETIME2(0)","NO","",  "SYSUTCDATETIME()","เวลาสร้าง"),
        @("updated_at",     "DATETIME2(0)","YES","", "","เวลาแก้ไข")
    )

    # ── mst_gd_product ────────────────────────────────────────────────────────────
    Add-Heading2 $Sel "4.15 mst_gd_product"
    Add-Para $Sel "GD Products (Growth Driver G2) — 4 สินค้า: AJI-PLUS, ROSDEE CUBE, ROSDEE MENU, ROSDEE NOODLE"
    Add-ColTable $Doc $Sel @(
        @("gd_product_id",     "INT IDENTITY","NO","PK","auto","Primary Key"),
        @("product_id",        "INT",         "NO","",  "","FK→mst_product (UNIQUE)"),
        @("gd_product_code",   "NVARCHAR(50)","NO","",  "","รหัส GD ย่อ: AP,Q,M,NS"),
        @("gd_product_name_th","NVARCHAR(150)","NO","",  "","ชื่อสินค้า (ภาษาไทย)"),
        @("gd_product_name_en","NVARCHAR(150)","YES","", "","ชื่อสินค้า (ภาษาอังกฤษ)"),
        @("channel_id",        "INT",         "YES","", "","FK→mst_channel (NULL=ทุก channel)"),
        @("is_active",         "BIT",         "NO","",  "1","สถานะใช้งาน"),
        @("created_at",        "DATETIME2(0)","NO","",  "SYSUTCDATETIME()","เวลาสร้าง"),
        @("updated_at",        "DATETIME2(0)","YES","", "","เวลาแก้ไข")
    )
    $Sel.InsertBreak(7)

    # ── mst_gd_payout ─────────────────────────────────────────────────────────────
    Add-Heading2 $Sel "4.16 mst_gd_payout"
    Add-Para $Sel "GD Payout Step Table — 40 rows (4 products × 10 thresholds) | Base: AP=200, Q=400, M=200, NS=400 บาท"
    Add-ColTable $Doc $Sel @(
        @("gd_payout_id",    "INT IDENTITY","NO","PK","auto","Primary Key"),
        @("gd_product_id",   "INT",         "NO","",  "","FK→mst_gd_product"),
        @("achievement_from","DECIMAL(9,4)","NO","",  "","ขั้นต่ำ achievement"),
        @("achievement_to",  "DECIMAL(9,4)","YES","", "","ขั้นสูงสุด (NULL=ไม่มี cap)"),
        @("payout_amount",   "DECIMAL(18,2)","NO","", "","จำนวนเงิน payout (บาท)"),
        @("sequence_no",     "INT",         "NO","",  "","ลำดับขั้น (1–10)"),
        @("effective_from",  "DATE",        "NO","",  "","วันเริ่มมีผล"),
        @("effective_to",    "DATE",        "YES","", "","วันสิ้นผล"),
        @("is_active",       "BIT",         "NO","",  "1","สถานะใช้งาน"),
        @("created_at",      "DATETIME2(0)","NO","",  "SYSUTCDATETIME()","เวลาสร้าง"),
        @("updated_at",      "DATETIME2(0)","YES","", "","เวลาแก้ไข")
    )

    # ── mst_product_mapping ───────────────────────────────────────────────────────
    Add-Heading2 $Sel "4.17 mst_product_mapping"
    Add-Para $Sel "Product Code Mapping — MT↔TT cross-reference และ BI source code mapping"
    Add-ColTable $Doc $Sel @(
        @("product_mapping_id", "INT IDENTITY","NO","PK","auto","Primary Key"),
        @("source_system",      "NVARCHAR(50)","NO","",  "","ระบบต้นทาง: BI, MT, TT"),
        @("source_product_code","NVARCHAR(50)","NO","",  "","รหัสสินค้าในระบบต้นทาง"),
        @("target_product_id",  "INT",         "NO","",  "","FK→mst_product"),
        @("mapping_type",       "NVARCHAR(50)","NO","",  "","ประเภท mapping"),
        @("remarks",            "NVARCHAR(500)","YES","","","หมายเหตุ"),
        @("is_active",          "BIT",         "NO","",  "1","สถานะใช้งาน"),
        @("created_at",         "DATETIME2(0)","NO","",  "SYSUTCDATETIME()","เวลาสร้าง"),
        @("updated_at",         "DATETIME2(0)","YES","", "","เวลาแก้ไข")
    )

    # ── mst_system_parameter ──────────────────────────────────────────────────────
    Add-Heading2 $Sel "4.18 mst_system_parameter"
    Add-Para $Sel "System Configuration — key/value table สำหรับ parameter กลางของระบบ"
    Add-ColTable $Doc $Sel @(
        @("system_parameter_id","INT IDENTITY","NO","PK","auto","Primary Key"),
        @("parameter_group",    "NVARCHAR(100)","NO","", "","กลุ่มพารามิเตอร์"),
        @("parameter_code",     "NVARCHAR(100)","NO","", "","รหัสพารามิเตอร์"),
        @("parameter_value",    "NVARCHAR(500)","NO","", "","ค่าพารามิเตอร์"),
        @("parameter_type",     "NVARCHAR(30)", "NO","", "","ประเภทค่า: STRING/NUMBER/BOOL/DATE"),
        @("effective_from",     "DATE",         "NO","", "","วันเริ่มมีผล"),
        @("effective_to",       "DATE",         "YES","","","วันสิ้นผล"),
        @("is_active",          "BIT",          "NO","", "1","สถานะใช้งาน"),
        @("created_at",         "DATETIME2(0)", "NO","", "SYSUTCDATETIME()","เวลาสร้าง"),
        @("updated_at",         "DATETIME2(0)", "YES","","","เวลาแก้ไข")
    )

    # ── mst_policy_rule ───────────────────────────────────────────────────────────
    Add-Heading2 $Sel "4.19 mst_policy_rule"
    Add-Para $Sel "Policy Rules — เก็บ Open Questions และ business rules ที่รอยืนยัน (PENDING → APPROVED)"
    Add-ColTable $Doc $Sel @(
        @("policy_rule_id", "INT IDENTITY","NO","PK","auto","Primary Key"),
        @("rule_code",      "NVARCHAR(100)","NO","",  "","รหัส rule เช่น GOAL_108_POLICY"),
        @("rule_name",      "NVARCHAR(200)","NO","",  "","ชื่อ rule"),
        @("rule_value",     "NVARCHAR(500)","YES","", "","ค่า rule (PENDING/ค่าที่ approve)"),
        @("rule_description","NVARCHAR(1000)","YES","","","คำอธิบายจาก Open Question"),
        @("approval_status","NVARCHAR(30)", "NO","",  "","PENDING / APPROVED / REJECTED"),
        @("effective_from", "DATE",         "NO","",  "","วันเริ่มมีผล"),
        @("effective_to",   "DATE",         "YES","", "","วันสิ้นผล"),
        @("is_active",      "BIT",          "NO","",  "1","สถานะใช้งาน"),
        @("created_at",     "DATETIME2(0)", "NO","",  "SYSUTCDATETIME()","เวลาสร้าง"),
        @("updated_at",     "DATETIME2(0)", "YES","", "","เวลาแก้ไข")
    )
    $Sel.InsertBreak(7)

    # ══════════════════════════════════════════════════════════════════════════════
    # 5. SEED DATA SUMMARY
    # ══════════════════════════════════════════════════════════════════════════════
    Add-Heading1 $Sel "5. ข้อมูลตั้งต้น (Seed Data Summary)"
    Add-Para $Sel "ข้อมูลด้านล่างนี้ถูก insert เข้าฐานข้อมูล AJT_SIS จากไฟล์ Raw Extract ใน 4.System Analyst and Design"

    Add-Heading2 $Sel "5.1 mst_channel — 4 rows"
    $chTbl = $Doc.Tables.Add($Sel.Range, 5, 3)
    $chTbl.Borders.Enable = $true
    Add-TableRow $chTbl 1 @("channel_code","channel_name_en","calc_type")
    Add-TableRow $chTbl 2 @("MT","Modern Trade","CASCADE_4_LEVEL")
    Add-TableRow $chTbl 3 @("TT","Traditional Trade","SINGLE_SHEET")
    Add-TableRow $chTbl 4 @("SI","Specialty & Institutional","CASCADE_4_LEVEL")
    Add-TableRow $chTbl 5 @("LAOS","Laos","SINGLE_SHEET")
    Style-HeaderRow $chTbl; $chTbl.AutoFitBehavior(1)
    $Sel.EndOf(6)|Out-Null; $Sel.MoveDown(); $Sel.TypeParagraph()

    Add-Heading2 $Sel "5.2 mst_goal_threshold — 10 rows (Top WS source)"
    $gtTbl = $Doc.Tables.Add($Sel.Range, 11, 4)
    $gtTbl.Borders.Enable = $true
    Add-TableRow $gtTbl 1 @("seq","achievement_from","achievement_to","multiplier")
    $gtData = @(
        @("1","0.0000","0.8999","0.0000"), @("2","0.9000","0.9499","0.9000"),
        @("3","0.9500","0.9999","0.9500"), @("4","1.0000","1.0299","1.0000"),
        @("5","1.0300","1.0599","1.0300"), @("6","1.0600","1.0999","1.0600"),
        @("7","1.1000","1.1499","1.1000"), @("8","1.1500","1.1999","1.1500"),
        @("9","1.2000","1.2999","1.2000"), @("10","1.3000","(no cap)","1.3000")
    )
    for ($i=0;$i -lt $gtData.Count;$i++) { Add-TableRow $gtTbl ($i+2) $gtData[$i] }
    Style-HeaderRow $gtTbl; $gtTbl.AutoFitBehavior(1)
    $Sel.EndOf(6)|Out-Null; $Sel.MoveDown(); $Sel.TypeParagraph()

    Add-Heading2 $Sel "5.3 mst_payment_cycle — 12 rows (M_Month source)"
    $pcTbl = $Doc.Tables.Add($Sel.Range, 13, 4)
    $pcTbl.Borders.Enable = $true
    Add-TableRow $pcTbl 1 @("display_order","sales_month","fixed_pay_month","variable_pay_month")
    $pcData = @(
        @("1","Apr-26","May-26","Jun-26"), @("2","May-26","Jun-26","Jul-26"),
        @("3","Jun-26","Jul-26","Aug-26"), @("4","Jul-26","Aug-26","Sep-26"),
        @("5","Aug-26","Sep-26","Oct-26"), @("6","Sep-26","Oct-26","Nov-26"),
        @("7","Oct-26","Nov-26","Dec-26"), @("8","Nov-26","Dec-26","Jan-27"),
        @("9","Dec-26","Jan-27","Feb-27"), @("10","Jan-27","Feb-27","Mar-27"),
        @("11","Feb-27","Mar-27","Apr-27"), @("12","Mar-27","Apr-27","May-27")
    )
    for ($i=0;$i -lt $pcData.Count;$i++) { Add-TableRow $pcTbl ($i+2) $pcData[$i] }
    Style-HeaderRow $pcTbl; $pcTbl.AutoFitBehavior(1)
    $Sel.EndOf(6)|Out-Null; $Sel.MoveDown(); $Sel.TypeParagraph()

    Add-Heading2 $Sel "5.4 mst_fix_rate — 6 rows (ค่าตอบแทนคงที่ source)"
    $frTbl = $Doc.Tables.Add($Sel.Range, 7, 3)
    $frTbl.Borders.Enable = $true
    Add-TableRow $frTbl 1 @("job_function_code","job_function_name_en","amount (THB/month)")
    $frData = @(
        @("TT_SR_CV_SALES","TT Senior Cash Van Sales","3,000"),
        @("TT_SR_CV_FV","TT Senior Cash Van Food Vender","3,000"),
        @("TT_CV_SALES","TT Cash Van Sales","2,500"),
        @("TT_CV_FV","TT Cash Van Food Vender","2,500"),
        @("SHOP_FRONT","Shop Front","1,500"),
        @("SALES_ASSISTANT","Sales Assistant","1,200")
    )
    for ($i=0;$i -lt $frData.Count;$i++) { Add-TableRow $frTbl ($i+2) $frData[$i] }
    Style-HeaderRow $frTbl; $frTbl.AutoFitBehavior(1)
    $Sel.EndOf(6)|Out-Null; $Sel.MoveDown(); $Sel.TypeParagraph()

    Add-Heading2 $Sel "5.5 mst_gd_payout — 40 rows (4 GD products × 10 thresholds)"
    Add-Para $Sel "Base amount per product: AJI-PLUS=200, ROSDEE CUBE=400, ROSDEE MENU=200, ROSDEE NOODLE=400 (บาท)"
    Add-Para $Sel "payout = base × multiplier (GOAL table เดียวกัน)"

    # ══════════════════════════════════════════════════════════════════════════════
    # 6. OPEN QUESTIONS / POLICY RULES
    # ══════════════════════════════════════════════════════════════════════════════
    $Sel.InsertBreak(7)
    Add-Heading1 $Sel "6. Open Questions / Policy Rules (PENDING)"
    Add-Para $Sel "ตาราง mst_policy_rule เก็บ business rules ที่ยังรอการยืนยันจาก Business Owner"
    $prtbl = $Doc.Tables.Add($Sel.Range, 6, 3)
    $prtbl.Borders.Enable = $true
    Add-TableRow $prtbl 1 @("rule_code","approval_status","description")
    Add-TableRow $prtbl 2 @("GOAL_108_POLICY","PENDING","OQ-1: achievement 108% ใช้ multiplier 1.06 หรือ 1.08")
    Add-TableRow $prtbl 3 @("GD_INTEGRATION_METHOD","PENDING","OQ-7/8: GD incentive รวม For HR หรือ replace G2 weight")
    Add-TableRow $prtbl 4 @("GD_PAYOUT_METHOD","PENDING","OQ-9: GD output รวม For HR เดียวหรือ export แยก")
    Add-TableRow $prtbl 5 @("PRORATE_LOGIC","PENDING","OQ-?: พนักงานเข้า/ออกกลางเดือน ใช้ prorate หรือไม่")
    Add-TableRow $prtbl 6 @("DOUBLE_COUNT_GUARD","PENDING","BR-009/OQ-8: ป้องกัน double-count GD vs G2 weight")
    Style-HeaderRow $prtbl; $prtbl.AutoFitBehavior(1)
    $Sel.EndOf(6)|Out-Null; $Sel.MoveDown(); $Sel.TypeParagraph()

    # ══════════════════════════════════════════════════════════════════════════════
    # 7. NOTES
    # ══════════════════════════════════════════════════════════════════════════════
    Add-Heading1 $Sel "7. หมายเหตุ (Notes)"
    Add-Para $Sel "• ตารางที่มี row_count = 0 รอข้อมูล import จาก BI/HCM ในขั้นตอน transaction data"
    Add-Para $Sel "• ไฟล์ DDL : environment/ddl/01_ajt_sis_poc_master_tables.sql"
    Add-Para $Sel "• ไฟล์ Seed: environment/ddl/02_ajt_sis_poc_seed_data.sql"
    Add-Para $Sel "• Open Questions ทั้ง 12 ข้อ อ้างอิง BRD-SRS § 16 ต้องปิดก่อนเริ่ม Phase 2 Build"
    Add-Para $Sel "• Schema dbo ใช้เป็น default ไม่ต้องกำหนด custom schema"

    # ── SAVE ──────────────────────────────────────────────────────────────────────
    $Doc.SaveAs([ref]$OutputPath, [ref]16)  # wdFormatXMLDocument = 16
    $Doc.Close()
    $Word.Quit()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($Word) | Out-Null

    Write-Host "SUCCESS: $OutputPath"
} catch {
    Write-Host "ERROR: $_"
    try { $Word.Quit() } catch {}
}
