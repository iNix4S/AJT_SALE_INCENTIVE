# AJT TT Database Test Guide

วันที่: 2026-06-14  
เวอร์ชัน: v1.0  
วัตถุประสงค์: คู่มือทดสอบระบบคำนวณ TT ผ่านฐานข้อมูลแบบ end-to-end

---

## 1) ขอบเขตการทดสอบ

คู่มือนี้ครอบคลุมการทดสอบผ่านฐานข้อมูลในประเด็นต่อไปนี้

1. ความพร้อมของ master สูตร TT
- ws formula matrix (TOP_WS, WS_SF, WS_WH, SF_WH)
- goal threshold
- option1 band + payout
- special KPI rules
- position incentive rates

2. ความพร้อมข้อมูลธุรกรรมก่อนคำนวณ
- sales target
- sales actual
- org hierarchy

3. ผลลัพธ์หลังคำนวณ
- trn_incentive_detail
- out_for_hr_variable
- special KPI detail

4. ความครบของ Sub views เพื่ออ่านสูตร
- vw_tt_formula_goal_threshold
- vw_tt_formula_rate_by_position
- vw_tt_formula_ws_matrix
- vw_tt_formula_option1_band_payout
- vw_tt_formula_special_kpi
- vw_tt_formula_catalog

---

## 2) Prerequisite

1. ฐานข้อมูล AJT_SIS เข้าถึงได้จากไฟล์ environment/database-dev.env
2. มีข้อมูล period ที่ต้องการทดสอบ (เช่น FY2026-05)
3. มีสคริปต์คำนวณ TT พร้อมใช้งาน
- environment/scripts/run_tt_incentive_calculation.ps1

---

## 3) Step การทดสอบ

### Step 0: เรียกชุดทดสอบซ้ำผ่าน Stored Procedure (แนะนำ)

SQL

  EXEC dbo.usp_validate_tt_database_test_suite
     @PeriodCode = N'FY2026-05',
     @WsType = N'TOP_WS',
     @RunCalculation = 0,
     @ApprovedBy = N'test_runner';

ความหมายพารามิเตอร์
- @PeriodCode: period ที่ต้องการตรวจ
- @WsType: ws_type สำหรับรอบทดสอบ
- @RunCalculation: 1 = ให้รันคำนวณก่อนตรวจ, 0 = ตรวจจากผลล่าสุด
- @ApprovedBy: ผู้รันทดสอบ

ผลลัพธ์ที่ได้
- Result set 1: context รอบทดสอบ
- Result set 2-4: ความครบสูตร (matrix/special KPI/rate)
- Result set 5: จำนวนข้อมูลตามแท็บ TT หลัก
- Result set 6: ความครบของ sub views
- Result set 7: ws_type coverage ในทุก view (PASS/FAIL)
- Result set 8: gate summary (matrix/goal/input/output)

### Step 1: รันคำนวณ TT รอบทดสอบ

PowerShell

    ./environment/scripts/run_tt_incentive_calculation.ps1 -PeriodCodes FY2026-05 -WsType TOP_WS

ผลที่คาดหวัง
- คำสั่งจบด้วย Exit Code 0
- มีค่า calc_run_id กลับมา
- มีจำนวนแถวใน trn_incentive_detail และ out_for_hr_variable มากกว่า 0

### Step 2: ตรวจความครบของ ws_type ใน master สูตร TT

SQL

    DECLARE @tt INT=(SELECT channel_id FROM dbo.mst_channel WHERE channel_code=N'TT');

    SELECT ws_type, COUNT(*) AS matrix_rows, SUM(product_weight_percent) AS sum_weight
    FROM dbo.mst_tt_ws_formula_matrix
    WHERE channel_id=@tt AND is_active=1
    GROUP BY ws_type
    ORDER BY ws_type;

    SELECT ws_type, g_group_code, COUNT(*) AS rule_rows
    FROM dbo.mst_tt_special_kpi_rule
    WHERE channel_id=@tt AND is_active=1
    GROUP BY ws_type, g_group_code
    ORDER BY ws_type, g_group_code;

    SELECT pl.position_code, ir.ws_type, COUNT(*) AS rate_rows
    FROM dbo.mst_incentive_rate ir
    JOIN dbo.mst_position_level pl ON pl.position_level_id=ir.position_level_id
    WHERE ir.channel_id=@tt AND ir.is_active=1
    GROUP BY pl.position_code, ir.ws_type
    ORDER BY pl.position_code, ir.ws_type;

เกณฑ์ผ่าน
- matrix มีครบ 4 ws_type
- special_kpi_rule มีครบ 4 ws_type x 4 g_group
- rate มีครบ ws_type ที่ใช้งานในแต่ละ position

### Step 3: ตรวจ mapping ตามแท็บ TT หลัก

SQL

    DECLARE @tt INT=(SELECT channel_id FROM dbo.mst_channel WHERE channel_code=N'TT');

    -- Top WS / WS SF / WS WH / SF WH
    SELECT ws_type, COUNT(*) AS rows_cnt
    FROM dbo.mst_tt_ws_formula_matrix
    WHERE channel_id=@tt AND is_active=1
    GROUP BY ws_type
    ORDER BY ws_type;

    -- 2) หลักการคำนวน Table
    SELECT COUNT(*) AS goal_threshold_rows FROM dbo.mst_goal_threshold WHERE is_active=1;
    SELECT COUNT(*) AS option_band_rows FROM dbo.mst_tt_option1_band b WHERE b.channel_id=@tt AND b.is_active=1;
    SELECT COUNT(*) AS option_payout_rows
    FROM dbo.mst_tt_option1_payout p
    JOIN dbo.mst_tt_option1_band b ON b.tt_option1_band_id=p.tt_option1_band_id
    WHERE b.channel_id=@tt AND b.is_active=1 AND p.is_active=1;

    -- 3)Target & Cal
    SELECT
      (SELECT COUNT(*) FROM dbo.trn_sales_target WHERE channel_id=@tt) AS sales_target_rows,
      (SELECT COUNT(*) FROM dbo.trn_sales_actual WHERE channel_id=@tt) AS sales_actual_rows,
      (SELECT COUNT(*) FROM dbo.trn_incentive_detail d JOIN dbo.trn_calc_run r ON r.calc_run_id=d.calc_run_id WHERE r.channel_id=@tt) AS incentive_detail_rows;

    -- 1) For HR
    SELECT COUNT(*) AS for_hr_rows
    FROM dbo.out_for_hr_variable o
    JOIN dbo.trn_calc_run r ON r.calc_run_id=o.calc_run_id
    WHERE r.channel_id=@tt;

    -- 1) For HR (AD)
    SELECT COUNT(*) AS for_hr_ad_rows
    FROM dbo.out_for_hr_variable o
    JOIN dbo.trn_calc_run r ON r.calc_run_id=o.calc_run_id
    WHERE r.channel_id=@tt
      AND o.incentive_ad IS NOT NULL;

    -- Shortage
    SELECT COUNT(*) AS shortage_rows FROM dbo.mst_shortage_policy;

เกณฑ์ผ่าน
- ทุกชุด query คืนค่า > 0 ตามบริบทธุรกิจ
- ws_type หลักครบ 4 ค่า

### Step 4: ตรวจ Sub views อ่านสูตร

SQL

    SELECT name
    FROM sys.views
    WHERE name IN (
      'vw_tt_formula_goal_threshold',
      'vw_tt_formula_rate_by_position',
      'vw_tt_formula_ws_matrix',
      'vw_tt_formula_option1_band_payout',
      'vw_tt_formula_special_kpi',
      'vw_tt_formula_catalog'
    )
    ORDER BY name;

    SELECT TOP 20 *
    FROM dbo.vw_tt_formula_catalog
    ORDER BY source_sheet, ws_type, item_code;

เกณฑ์ผ่าน
- พบ view ครบทั้ง 6 ตัว
- vw_tt_formula_catalog อ่านสูตรได้ทั้ง Goal, Position Rate, WS Matrix

### Step 5: ตรวจความครบ ws_type ในทุก view

SQL

    DECLARE @expected TABLE(ws_type NVARCHAR(50) PRIMARY KEY);
    INSERT INTO @expected(ws_type) VALUES (N'TOP_WS'),(N'WS_SF'),(N'WS_WH'),(N'SF_WH');

    ;WITH checks AS (
        SELECT N'vw_tt_formula_ws_matrix' AS view_name, e.ws_type,
               CASE WHEN EXISTS (SELECT 1 FROM dbo.vw_tt_formula_ws_matrix v WHERE v.ws_type=e.ws_type) THEN 1 ELSE 0 END AS has_data
        FROM @expected e
        UNION ALL
        SELECT N'vw_tt_formula_rate_by_position', e.ws_type,
               CASE WHEN EXISTS (SELECT 1 FROM dbo.vw_tt_formula_rate_by_position v WHERE v.ws_type=e.ws_type) THEN 1 ELSE 0 END
        FROM @expected e
        UNION ALL
        SELECT N'vw_tt_formula_special_kpi', e.ws_type,
               CASE WHEN EXISTS (SELECT 1 FROM dbo.vw_tt_formula_special_kpi v WHERE v.ws_type=e.ws_type) THEN 1 ELSE 0 END
        FROM @expected e
        UNION ALL
        SELECT N'vw_tt_formula_catalog:POSITION_RATE', e.ws_type,
               CASE WHEN EXISTS (SELECT 1 FROM dbo.vw_tt_formula_catalog v WHERE v.formula_type=N'POSITION_RATE' AND v.ws_type=e.ws_type) THEN 1 ELSE 0 END
        FROM @expected e
        UNION ALL
        SELECT N'vw_tt_formula_catalog:WS_MATRIX', e.ws_type,
               CASE WHEN EXISTS (SELECT 1 FROM dbo.vw_tt_formula_catalog v WHERE v.formula_type=N'WS_MATRIX' AND v.ws_type=e.ws_type) THEN 1 ELSE 0 END
        FROM @expected e
    )
    SELECT view_name,
           SUM(has_data) AS pass_ws_type_count,
           COUNT(*) AS expected_ws_type_count,
           CASE WHEN SUM(has_data)=COUNT(*) THEN N'PASS' ELSE N'FAIL' END AS status
    FROM checks
    GROUP BY view_name
    ORDER BY view_name;

เกณฑ์ผ่าน
- ทุก view มีสถานะ PASS

---

## 4) Failure Pattern ที่พบบ่อย

1. Special KPI ไม่ครบ 4 ws_type
- อาการ: view special_kpi หรือผล bonus ไม่ครบบาง ws_type
- วิธีแก้: รัน environment/ddl/22_upsert_tt_ws_type_completeness.sql

2. Rate manager ขาด ws_type
- อาการ: manager incentive กลายเป็น 0 หรือไม่ครบ
- วิธีแก้: ตรวจ mst_incentive_rate และรันสคริปต์ upsert completeness

3. Hierarchy ขาด AD
- อาการ: ไม่มีผล AD ในรอบคำนวณ
- วิธีแก้: เติม ad_code ใน mst_org_hierarchy ให้ครบ chain

---

## 5) Checklist สรุปผลทดสอบ (สำหรับเซ็นรับ)

- [ ] TT calculation run สำเร็จ
- [ ] ws_type master ครบ 4 ค่า
- [ ] Sheet mapping หลักมีข้อมูลครบใน DB
- [ ] Sub views ครบ 6 ตัว
- [ ] ws_type coverage ในทุก view = PASS
- [ ] ไม่มี critical data gap (target/actual/hierarchy)

---

## 6) เอกสารอ้างอิง

- final-docs/AJT_TT-Flow-Process_Summary.md
- final-docs/AJT_TT_Incentive_Formula_Query_Template.sql
- environment/ddl/22_upsert_tt_ws_type_completeness.sql
- environment/ddl/23_create_proc_usp_validate_tt_database_test_suite.sql
- environment/scripts/run_tt_incentive_calculation.ps1
