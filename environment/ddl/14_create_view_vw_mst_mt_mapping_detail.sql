SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- ============================================================
-- View  : dbo.vw_mst_mt_mapping_detail
-- Purpose: MT Mapping detail — รวม BI SalesCode + Product Group
--          + Salesman Code + Product Name + Internal Product ref
--          ใช้สำหรับ reporting, validation gate และ audit
-- Tables : mst_salesman_mapping (main)
--          mst_channel          (channel context)
--          mst_product_mapping  (BI product code → internal product)
--          mst_product          (product name + group)
-- Note   : เฉพาะ MT channel เท่านั้น (channel_code = 'MT')
--          salesman_name_th = NULL เพราะ BI salesman code (5490000xxx)
--          ยังไม่มี reference table เชื่อมกับ HR employee code
-- Updated: 2026-06-14
-- ============================================================
CREATE OR ALTER VIEW dbo.vw_mst_mt_mapping_detail
AS
SELECT
    sm.salesman_mapping_id,

    -- Channel
    ch.channel_code,
    ch.channel_name_th,
    ch.channel_name_en,

    -- Period
    sm.effective_month,
    FORMAT(sm.effective_month, 'yyyy-MM') AS effective_month_ym,

    -- BI → Salesman mapping (คีย์หลักจาก sheet Mapping)
    sm.bi_sales_code,
    sm.product_group_code,

    -- Product name (ผ่าน mst_product_mapping: source_product_code = product_group_code)
    mp.product_name_th,
    mp.product_name_en,
    mp.product_group_code  AS internal_product_group_code,  -- เช่น G1_CORE, G2_GD
    pm.mapping_type        AS product_mapping_type,

    -- Salesman (BI system code — ยังไม่มี name reference ใน DB)
    sm.salesman_code,

    -- Internal product ref
    mp.product_code        AS internal_product_code,

    -- Status
    sm.is_active           AS mapping_is_active,
    sm.created_at,
    sm.updated_at

FROM dbo.mst_salesman_mapping sm

-- Channel (filter MT only)
INNER JOIN dbo.mst_channel ch
    ON ch.channel_id = sm.channel_id
   AND ch.channel_code = 'MT'

-- Product mapping: BI product_group_code → internal product
-- (1:1 — source_product_code = AJ, AJP, RD, ... ตรงกับ product_group_code ใน mst_salesman_mapping)
LEFT JOIN dbo.mst_product_mapping pm
    ON pm.source_product_code = sm.product_group_code
   AND pm.source_system       = 'BI'
   AND pm.is_active           = 1

-- Internal product detail + product name
LEFT JOIN dbo.mst_product mp
    ON mp.product_id = pm.target_product_id
   AND mp.is_active  = 1;
GO
