/*
08_reconciliation_actual_sheet_vs_stg_trn_audit.sql
Purpose:
- Monthly reconciliation between Actual Sheet load (in stg_bi_sales) vs stg_bi_sales vs trn_sales_actual
- Audit-ready summary by month and channel
- Show strict-mode MT mapping gaps explicitly

Scope assumptions:
- Sheet-based loads use batch pattern: BATCH-BI-<CHANNEL>-<YYYYMM>-SHEET
- stg rows considered for processing status: VALIDATED / PROCESSED
*/

SET NOCOUNT ON;

DECLARE @run_at_utc DATETIME2(0) = SYSUTCDATETIME();
DECLARE @sheet_batch_like NVARCHAR(50) = 'BATCH-BI-%-SHEET';

IF OBJECT_ID('dbo.stg_bi_sales', 'U') IS NULL
    THROW 50011, 'Table dbo.stg_bi_sales does not exist.', 1;

IF OBJECT_ID('dbo.trn_sales_actual', 'U') IS NULL
    THROW 50012, 'Table dbo.trn_sales_actual does not exist.', 1;

IF OBJECT_ID('tempdb..#sheet_scope', 'U') IS NOT NULL DROP TABLE #sheet_scope;
IF OBJECT_ID('tempdb..#stg_monthly', 'U') IS NOT NULL DROP TABLE #stg_monthly;
IF OBJECT_ID('tempdb..#stg_distinct_key_monthly', 'U') IS NOT NULL DROP TABLE #stg_distinct_key_monthly;
IF OBJECT_ID('tempdb..#trn_monthly', 'U') IS NOT NULL DROP TABLE #trn_monthly;
IF OBJECT_ID('tempdb..#recon_monthly', 'U') IS NOT NULL DROP TABLE #recon_monthly;

SELECT
    s.data_month,
    s.channel_code,
    COUNT(*) AS sheet_row_count,
    SUM(s.actual_amount) AS sheet_actual_amount,
    SUM(COALESCE(s.actual_qty, 0)) AS sheet_actual_qty
INTO #sheet_scope
FROM dbo.stg_bi_sales s
WHERE s.batch_id LIKE @sheet_batch_like
  AND s.status IN ('VALIDATED', 'PROCESSED')
GROUP BY s.data_month, s.channel_code;

SELECT
    s.data_month,
    s.channel_code,
    COUNT(*) AS stg_row_count,
    SUM(s.actual_amount) AS stg_actual_amount,
    SUM(COALESCE(s.actual_qty, 0)) AS stg_actual_qty
INTO #stg_monthly
FROM dbo.stg_bi_sales s
WHERE s.batch_id LIKE @sheet_batch_like
  AND s.status IN ('VALIDATED', 'PROCESSED')
GROUP BY s.data_month, s.channel_code;

SELECT
    x.data_month,
    x.channel_code,
    COUNT(*) AS stg_distinct_business_key_count
INTO #stg_distinct_key_monthly
FROM (
    SELECT DISTINCT
        s.data_month,
        s.channel_code,
        CASE
            WHEN s.channel_code = 'MT' THEN msm.salesman_code
            ELSE s.salesman_code
        END AS resolved_salesman_code,
        s.product_code
    FROM dbo.stg_bi_sales s
    INNER JOIN dbo.mst_channel c
        ON c.channel_code = s.channel_code
    LEFT JOIN dbo.mst_salesman_mapping msm
        ON s.channel_code = 'MT'
       AND msm.channel_id = c.channel_id
       AND msm.effective_month = s.data_month
       AND msm.bi_sales_code = s.bi_sales_code
       AND msm.product_group_code = s.product_code
       AND msm.is_active = 1
    WHERE s.batch_id LIKE @sheet_batch_like
      AND s.status IN ('VALIDATED', 'PROCESSED')
) x
WHERE COALESCE(x.resolved_salesman_code, '') <> ''
GROUP BY x.data_month, x.channel_code;

SELECT
    p.sales_month AS data_month,
    c.channel_code,
    COUNT(*) AS trn_row_count,
    SUM(a.actual_amount) AS trn_actual_amount,
    SUM(COALESCE(a.actual_qty, 0)) AS trn_actual_qty
INTO #trn_monthly
FROM dbo.trn_sales_actual a
INNER JOIN dbo.mst_period p
    ON p.period_id = a.period_id
INNER JOIN dbo.mst_channel c
    ON c.channel_id = a.channel_id
WHERE a.source_batch_id LIKE @sheet_batch_like
GROUP BY p.sales_month, c.channel_code;

SELECT
    @run_at_utc AS run_at_utc,
    COALESCE(sh.data_month, st.data_month, tr.data_month) AS data_month,
    COALESCE(sh.channel_code, st.channel_code, tr.channel_code) AS channel_code,
    COALESCE(sh.sheet_row_count, 0) AS sheet_row_count,
    COALESCE(st.stg_row_count, 0) AS stg_row_count,
    COALESCE(sk.stg_distinct_business_key_count, 0) AS stg_distinct_business_key_count,
    COALESCE(tr.trn_row_count, 0) AS trn_row_count,
    COALESCE(sh.sheet_actual_amount, 0) AS sheet_actual_amount,
    COALESCE(st.stg_actual_amount, 0) AS stg_actual_amount,
    COALESCE(tr.trn_actual_amount, 0) AS trn_actual_amount,
    COALESCE(sh.sheet_row_count, 0) - COALESCE(st.stg_row_count, 0) AS gap_sheet_vs_stg_rows,
    COALESCE(st.stg_row_count, 0) - COALESCE(tr.trn_row_count, 0) AS gap_stg_vs_trn_rows,
    COALESCE(sk.stg_distinct_business_key_count, 0) - COALESCE(tr.trn_row_count, 0) AS gap_stg_distinct_key_vs_trn_rows,
    COALESCE(sh.sheet_actual_amount, 0) - COALESCE(st.stg_actual_amount, 0) AS gap_sheet_vs_stg_amount,
    COALESCE(st.stg_actual_amount, 0) - COALESCE(tr.trn_actual_amount, 0) AS gap_stg_vs_trn_amount
INTO #recon_monthly
FROM #sheet_scope sh
FULL OUTER JOIN #stg_monthly st
    ON st.data_month = sh.data_month
   AND st.channel_code = sh.channel_code
LEFT JOIN #stg_distinct_key_monthly sk
    ON sk.data_month = COALESCE(sh.data_month, st.data_month)
   AND sk.channel_code = COALESCE(sh.channel_code, st.channel_code)
FULL OUTER JOIN #trn_monthly tr
    ON tr.data_month = COALESCE(sh.data_month, st.data_month)
   AND tr.channel_code = COALESCE(sh.channel_code, st.channel_code);

-- Resultset 1: Monthly reconciliation summary
SELECT
    run_at_utc,
    data_month,
    channel_code,
    sheet_row_count,
    stg_row_count,
    stg_distinct_business_key_count,
    trn_row_count,
    sheet_actual_amount,
    stg_actual_amount,
    trn_actual_amount,
    gap_sheet_vs_stg_rows,
    gap_stg_vs_trn_rows,
    gap_stg_distinct_key_vs_trn_rows,
    gap_sheet_vs_stg_amount,
    gap_stg_vs_trn_amount,
    CASE
        WHEN gap_sheet_vs_stg_rows = 0
         AND gap_sheet_vs_stg_amount = 0
         AND gap_stg_distinct_key_vs_trn_rows = 0
         AND gap_stg_vs_trn_amount = 0
            THEN 'PASS'
        ELSE 'CHECK'
    END AS reconciliation_status
FROM #recon_monthly
ORDER BY data_month, channel_code;

-- Resultset 2: Strict-mode MT mapping gaps (detail)
SELECT
    @run_at_utc AS run_at_utc,
    s.batch_id,
    s.data_month,
    s.channel_code,
    s.bi_sales_code,
    s.product_code,
    s.actual_amount,
    s.actual_qty,
    s.raw_row_no,
    s.status,
    'MT mapping not found in mst_salesman_mapping (strict mode)' AS unresolved_reason
FROM dbo.stg_bi_sales s
INNER JOIN dbo.mst_channel c
    ON c.channel_code = s.channel_code
LEFT JOIN dbo.mst_salesman_mapping msm
    ON msm.channel_id = c.channel_id
   AND msm.effective_month = s.data_month
   AND msm.bi_sales_code = s.bi_sales_code
   AND msm.product_group_code = s.product_code
   AND msm.is_active = 1
WHERE s.batch_id LIKE @sheet_batch_like
  AND s.channel_code = 'MT'
  AND s.status IN ('VALIDATED', 'PROCESSED')
  AND msm.salesman_code IS NULL
ORDER BY s.data_month, s.bi_sales_code, s.product_code, s.raw_row_no;

-- Resultset 3: Aggregate MT mapping gap by month
SELECT
    @run_at_utc AS run_at_utc,
    s.data_month,
    COUNT(*) AS unresolved_row_count,
    SUM(s.actual_amount) AS unresolved_actual_amount
FROM dbo.stg_bi_sales s
INNER JOIN dbo.mst_channel c
    ON c.channel_code = s.channel_code
LEFT JOIN dbo.mst_salesman_mapping msm
    ON msm.channel_id = c.channel_id
   AND msm.effective_month = s.data_month
   AND msm.bi_sales_code = s.bi_sales_code
   AND msm.product_group_code = s.product_code
   AND msm.is_active = 1
WHERE s.batch_id LIKE @sheet_batch_like
  AND s.channel_code = 'MT'
  AND s.status IN ('VALIDATED', 'PROCESSED')
  AND msm.salesman_code IS NULL
GROUP BY s.data_month
ORDER BY s.data_month;

DROP TABLE #recon_monthly;
DROP TABLE #trn_monthly;
DROP TABLE #stg_distinct_key_monthly;
DROP TABLE #stg_monthly;
DROP TABLE #sheet_scope;
