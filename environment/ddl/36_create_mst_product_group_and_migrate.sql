SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*
Purpose:
- Normalize product group data out of mst_product into a new table mst_product_group.
- mst_product previously stored product_group_code + product_group_name inline.
- After migration:
    mst_product_group  : master of all product groups (G1_CORE / G2_GD / G3_BB / OTHERS)
    mst_product        : references mst_product_group via product_group_id (FK)
- Also adds tt_sheet_code to mst_product to store TT sheet short alias (A/R/B/AP/Q/M/NS/P/Y/RK/T)
  so SP can lookup by alias instead of hardcoded CASE.

Context:
- MT uses product_group_code for grouping (product_code is a subset of product_group)
- TT uses product_code directly (sheet "Actual" stores short aliases per salesman×product)
- mst_product.gd_product_code only covered G2 products — replaced by tt_sheet_code (all products)

Rollback:
- mst_product.product_group_code column is KEPT (not dropped) for backward compatibility.
  Drop separately after confirming all references are updated.
*/

-- ============================================================
-- Step 1: Create mst_product_group
-- ============================================================
IF OBJECT_ID('dbo.mst_product_group', 'U') IS NOT NULL
    DROP TABLE dbo.mst_product_group;

CREATE TABLE dbo.mst_product_group (
    product_group_id      INT           IDENTITY(1,1) NOT NULL,
    product_group_code    NVARCHAR(50)  NOT NULL,           -- G1_CORE / G2_GD / G3_BB / OTHERS
    product_group_name_th NVARCHAR(200) NULL,
    product_group_name_en NVARCHAR(200) NULL,
    g_group_code          NVARCHAR(20)  NULL,               -- short code used in TT formula matrix (G1/G2/G3/OT)
    display_order         TINYINT       NULL,               -- sort order for display
    is_active             BIT           NOT NULL CONSTRAINT DF_mst_product_group_is_active DEFAULT 1,
    created_at            DATETIME2(0)  NOT NULL CONSTRAINT DF_mst_product_group_created_at DEFAULT SYSUTCDATETIME(),
    updated_at            DATETIME2(0)  NULL,
    CONSTRAINT PK_mst_product_group PRIMARY KEY (product_group_id),
    CONSTRAINT UQ_mst_product_group_code UNIQUE (product_group_code)
);

-- ============================================================
-- Step 2: Seed mst_product_group from distinct values in mst_product
-- ============================================================
INSERT INTO dbo.mst_product_group
    (product_group_code, product_group_name_th, product_group_name_en, g_group_code, display_order, is_active)
VALUES
    (N'G1_CORE', N'สินค้าหลัก (Core)',          N'Core Products',      N'G1', 1, 1),
    (N'G2_GD',   N'สินค้ากลุ่ม GD',             N'GD Products',        N'G2', 2, 1),
    (N'G3_BB',   N'สินค้ากลุ่ม BB',             N'BB Products',        N'G3', 3, 1),
    (N'OTHERS',  N'สินค้าอื่นๆ',                N'Other Products',     N'OT', 4, 1);

-- ============================================================
-- Step 3: Add product_group_id (FK column) + tt_sheet_code to mst_product
-- ============================================================
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.mst_product') AND name = 'product_group_id'
)
    ALTER TABLE dbo.mst_product ADD product_group_id INT NULL;

IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.mst_product') AND name = 'tt_sheet_code'
)
    ALTER TABLE dbo.mst_product ADD tt_sheet_code NVARCHAR(20) NULL;
    -- TT sheet short alias (A/R/B/AP/Q/M/NS/P/Y/RK/T)
    -- Used for lookup instead of hardcoded CASE in SP

-- ============================================================
-- Step 4: Populate product_group_id from existing product_group_code
-- ============================================================
UPDATE p
SET p.product_group_id = pg.product_group_id
FROM dbo.mst_product p
JOIN dbo.mst_product_group pg
    ON pg.product_group_code = p.product_group_code;

-- ============================================================
-- Step 5: Populate tt_sheet_code (TT sheet alias for all products)
--         Matches CASE mapping in usp_run_tt_incentive_calculation (staff_map CTE)
-- ============================================================
GO
UPDATE dbo.mst_product SET tt_sheet_code = N'A'  WHERE product_code = N'AJ';
UPDATE dbo.mst_product SET tt_sheet_code = N'R'  WHERE product_code = N'RD';
UPDATE dbo.mst_product SET tt_sheet_code = N'B'  WHERE product_code = N'BD';
UPDATE dbo.mst_product SET tt_sheet_code = N'AP' WHERE product_code = N'AJP';
UPDATE dbo.mst_product SET tt_sheet_code = N'Q'  WHERE product_code = N'RDC';
UPDATE dbo.mst_product SET tt_sheet_code = N'M'  WHERE product_code = N'RM';
UPDATE dbo.mst_product SET tt_sheet_code = N'NS' WHERE product_code = N'RDNS';
UPDATE dbo.mst_product SET tt_sheet_code = N'P'  WHERE product_code = N'PDC';
UPDATE dbo.mst_product SET tt_sheet_code = N'Y'  WHERE product_code = N'YY';
UPDATE dbo.mst_product SET tt_sheet_code = N'RK' WHERE product_code = N'RKR';
UPDATE dbo.mst_product SET tt_sheet_code = N'T'  WHERE product_code = N'TKM';

-- ============================================================
-- Step 6: Add FK constraint (after data is populated)
-- ============================================================
IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_mst_product_product_group'
)
    ALTER TABLE dbo.mst_product
    ADD CONSTRAINT FK_mst_product_product_group
        FOREIGN KEY (product_group_id)
        REFERENCES dbo.mst_product_group (product_group_id);

-- ============================================================
-- Step 7: Verify
-- ============================================================
SELECT
    p.product_id,
    p.product_code,
    p.tt_sheet_code,
    p.product_group_code        AS old_group_code,
    pg.product_group_id,
    pg.product_group_code       AS new_group_code,
    pg.g_group_code,
    pg.display_order,
    p.is_active
FROM dbo.mst_product p
LEFT JOIN dbo.mst_product_group pg
    ON pg.product_group_id = p.product_group_id
ORDER BY pg.display_order, p.product_code;

SELECT * FROM dbo.mst_product_group ORDER BY display_order;
