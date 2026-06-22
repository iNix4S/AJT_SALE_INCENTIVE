SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- ============================================================
-- View  : dbo.vw_trn_sales_actual_pivot_fiscal_month
-- Purpose: Pivot trn_sales_actual เป็นรายเดือนเรียงซ้ายไปขวาแบบปีงบฯ
--          April -> March
--
-- Grain:
--   1 แถว ต่อ (channel_code, salesman_code, product_code, fiscal_year)
--
-- Notes:
--   fiscal_year คำนวณจาก month_no:
--     - month_no >= 4  => fiscal_year = year_no
--     - month_no <  4  => fiscal_year = year_no - 1
--
--   ตัวอย่าง:
--     May-2026  => fiscal_year 2026
--     Jan-2027  => fiscal_year 2026
-- ============================================================
CREATE OR ALTER VIEW dbo.vw_trn_sales_actual_pivot_fiscal_month
AS
WITH actual_base AS (
    SELECT
        ch.channel_code,
        a.salesman_code,
        a.product_code,
        p.year_no,
        p.month_no,
        CASE
            WHEN p.month_no >= 4 THEN p.year_no
            ELSE p.year_no - 1
        END AS fiscal_year,
        CAST(a.actual_amount AS DECIMAL(18,2)) AS actual_amount
    FROM dbo.trn_sales_actual a
    INNER JOIN dbo.mst_period p
        ON p.period_id = a.period_id
    INNER JOIN dbo.mst_channel ch
        ON ch.channel_id = a.channel_id
),
agg AS (
    SELECT
        channel_code,
        salesman_code,
        product_code,
        fiscal_year,
        month_no,
        SUM(actual_amount) AS month_amount
    FROM actual_base
    GROUP BY
        channel_code,
        salesman_code,
        product_code,
        fiscal_year,
        month_no
)
SELECT
    channel_code,
    fiscal_year,
    salesman_code,
    product_code,
    CAST(COALESCE([4],  0) AS DECIMAL(18,2)) AS April,
    CAST(COALESCE([5],  0) AS DECIMAL(18,2)) AS May,
    CAST(COALESCE([6],  0) AS DECIMAL(18,2)) AS June,
    CAST(COALESCE([7],  0) AS DECIMAL(18,2)) AS July,
    CAST(COALESCE([8],  0) AS DECIMAL(18,2)) AS August,
    CAST(COALESCE([9],  0) AS DECIMAL(18,2)) AS September,
    CAST(COALESCE([10], 0) AS DECIMAL(18,2)) AS October,
    CAST(COALESCE([11], 0) AS DECIMAL(18,2)) AS November,
    CAST(COALESCE([12], 0) AS DECIMAL(18,2)) AS December,
    CAST(COALESCE([1],  0) AS DECIMAL(18,2)) AS January,
    CAST(COALESCE([2],  0) AS DECIMAL(18,2)) AS February,
    CAST(COALESCE([3],  0) AS DECIMAL(18,2)) AS March
FROM agg
PIVOT (
    SUM(month_amount)
    FOR month_no IN ([4],[5],[6],[7],[8],[9],[10],[11],[12],[1],[2],[3])
) p;
GO
