# Sheet-to-Database Mind Map

วันที่: 2026-06-14
Scope: AJT New Sale Incentive System

```mermaid
mindmap
  root((AJT New Sale Incentive))
    Guide
      Purpose[กำหนดขั้นตอนการทำงาน]
      Tables
        mst_policy_rule
        mst_system_parameter
        aud_parameter_change
        aud_approval_log
    M_Month
      Purpose2[mapping เดือนยอดขาย -> เดือนจ่าย]
      Tables2
        mst_payment_cycle
        mst_period
        out_for_hr_variable
        out_for_hr_fixed
    Period
      Purpose3[ระบุงวดคำนวณ]
      Tables3
        mst_period
        trn_calc_run
    ASTBase
      Purpose4[โครงสร้างบังคับบัญชา]
      Tables4
        mst_org_hierarchy
        mst_employee
        mst_position_level
    HR Rep
      Purpose5[snapshot พนักงานจาก HCM]
      Tables5
        stg_hcm_employee
        mst_employee
        mst_job_function
        mst_position_level
    Mapping
      MT
        Purpose6[map BI SalesCode -> Salesman]
        Tables6
          mst_product_mapping
          mst_salesman_mapping
          stg_bi_sales
          trn_sales_actual
      TT
        Purpose7[normalize code ภายใน]
        Tables7
          mst_salesman_mapping
          stg_bi_sales
          trn_sales_actual
    Product / Top WS / Table
      Purpose8[master สินค้า + น้ำหนัก]
      Tables8
        mst_product
        mst_product_weight
        mst_gd_product
        mst_gd_payout
    Target & Cal
      MT Branch
        Purpose9[คำนวณระดับ Staff -> AD]
        Tables9
          trn_sales_target
          trn_incentive_detail
          mst_goal_threshold
          mst_shortage_policy
      TT Branch
        Purpose10[คำนวณ 5-level cascade]
        Tables10
          trn_sales_target
          trn_incentive_detail
          mst_goal_threshold
          mst_shortage_policy
    Actual
      Purpose11[ยอดขายจริง]
      Tables11
        stg_bi_sales
        trn_sales_actual
        int_import_batch
    Shortage
      Purpose12[override achievement เมื่อขาด]
      Tables12
        mst_shortage_policy
        trn_incentive_detail
    Fix Rate
      Purpose13[อัตราคงที่ตาม Job Function]
      Tables13
        mst_fix_rate
        mst_job_function
        out_for_hr_fixed
    For HR
      Variable
        Tables14
          out_for_hr_variable
        Columns
          incentive_staff
          incentive_sect
          incentive_dept
          incentive_div
          incentive_ad
          gd_incentive_total
          total_variable
      Fixed
        Tables15
          out_for_hr_fixed
        Columns2
          fix_rate_amount
          total_fixed
          fixed_pay_month
```

## อ่านภาพรวม
- ด้านบนคือ Sheet ที่คนทำงานเห็นในไฟล์ต้นทาง
- ชั้นถัดมาคือ Table group ที่รองรับแต่ละ Sheet
- MT ใช้ mapping ระหว่าง BI code -> Salesman code และคำนวณ cascade 4 ระดับ
- TT ใช้ SKU-based logic และขยายผลเป็น 5-level cascade โดยมี `incentive_div` ใน output
