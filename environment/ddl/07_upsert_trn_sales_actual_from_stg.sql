/*
07_upsert_trn_sales_actual_from_stg.sql
Purpose:
- Push validated staged sales into trn_sales_actual for both MT and TT
- MT: resolve internal salesman_code via mst_salesman_mapping
- TT: use staged salesman_code directly
- Upsert by business key (period_id, channel_id, salesman_code, product_code)
*/

SET NOCOUNT ON;

IF OBJECT_ID('dbo.stg_bi_sales', 'U') IS NULL
    THROW 50001, 'Table dbo.stg_bi_sales does not exist.', 1;

IF OBJECT_ID('dbo.trn_sales_actual', 'U') IS NULL
    THROW 50002, 'Table dbo.trn_sales_actual does not exist.', 1;

DECLARE @mt_channel_id INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'MT');
DECLARE @tt_channel_id INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = 'TT');

IF @mt_channel_id IS NULL OR @tt_channel_id IS NULL
    THROW 50003, 'Channel code MT/TT not found in mst_channel.', 1;

IF OBJECT_ID('tempdb..#src_base', 'U') IS NOT NULL
    DROP TABLE #src_base;

IF OBJECT_ID('tempdb..#src_ready', 'U') IS NOT NULL
    DROP TABLE #src_ready;

SELECT
    s.batch_id,
    s.data_month,
    s.channel_code,
    s.bi_sales_code,
    s.salesman_code AS staged_salesman_code,
    s.product_code,
    s.actual_amount,
    s.actual_qty,
    c.channel_id,
    p.period_id,
    CASE
        WHEN s.channel_code = 'MT' THEN msm.salesman_code
        ELSE s.salesman_code
    END AS resolved_salesman_code
INTO #src_base
FROM dbo.stg_bi_sales s
INNER JOIN dbo.mst_channel c
    ON c.channel_code = s.channel_code
INNER JOIN dbo.mst_period p
    ON p.sales_month = s.data_month
LEFT JOIN dbo.mst_salesman_mapping msm
    ON s.channel_code = 'MT'
   AND msm.channel_id = c.channel_id
   AND msm.effective_month = s.data_month
   AND msm.bi_sales_code = s.bi_sales_code
   AND msm.product_group_code = s.product_code
   AND msm.is_active = 1
WHERE s.channel_code IN ('MT', 'TT')
  AND s.status IN ('VALIDATED', 'PROCESSED');

SELECT
    batch_id,
    period_id,
    channel_id,
    resolved_salesman_code AS salesman_code,
    product_code,
    SUM(actual_amount) AS actual_amount,
    SUM(actual_qty) AS actual_qty
INTO #src_ready
FROM #src_base
WHERE resolved_salesman_code IS NOT NULL
  AND LTRIM(RTRIM(resolved_salesman_code)) <> ''
GROUP BY
    batch_id,
    period_id,
    channel_id,
    resolved_salesman_code,
    product_code;

MERGE dbo.trn_sales_actual AS tgt
USING #src_ready AS src
   ON tgt.period_id = src.period_id
  AND tgt.channel_id = src.channel_id
  AND tgt.salesman_code = src.salesman_code
  AND tgt.product_code = src.product_code
WHEN MATCHED THEN
    UPDATE SET
        tgt.actual_amount = src.actual_amount,
        tgt.actual_qty = src.actual_qty,
        tgt.source_batch_id = src.batch_id
WHEN NOT MATCHED BY TARGET THEN
    INSERT (
        period_id,
        channel_id,
        salesman_code,
        product_code,
        actual_amount,
        actual_qty,
        source_batch_id
    )
    VALUES (
        src.period_id,
        src.channel_id,
        src.salesman_code,
        src.product_code,
        src.actual_amount,
        src.actual_qty,
        src.batch_id
    );

-- Report unresolved rows (mostly MT mapping gaps or missing TT salesman)
SELECT
    sb.batch_id,
    sb.data_month,
    sb.channel_code,
    sb.bi_sales_code,
    sb.staged_salesman_code,
    sb.product_code,
    sb.actual_amount,
    sb.actual_qty,
    CASE
        WHEN sb.channel_code = 'MT' THEN 'MT mapping not found in mst_salesman_mapping (strict mode)'
        WHEN sb.channel_code = 'TT' THEN 'TT salesman_code is empty'
        ELSE 'Unknown'
    END AS unresolved_reason
FROM #src_base sb
WHERE sb.resolved_salesman_code IS NULL
   OR LTRIM(RTRIM(sb.resolved_salesman_code)) = ''
ORDER BY sb.channel_code, sb.data_month, sb.bi_sales_code, sb.staged_salesman_code, sb.product_code;

DROP TABLE #src_ready;
DROP TABLE #src_base;
