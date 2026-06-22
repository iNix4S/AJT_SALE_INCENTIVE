SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*
18_upsert_tt_topws_product_mapping_and_weight.sql
Purpose:
- Upsert TT Top WS product mapping (A,R,B,AP,Q,M,NS,Y,P,T,RK) into mst_product_mapping.
- Upsert TT product weights for ws_type='OLD' to complete all 11 products.

Top WS weight model (sum = 100%):
A 5%, R 10%, B 20%, AP 5%, Q 10%, M 5%, NS 10%, Y 15%, P 10%, T 5%, RK 5%
*/

DECLARE @tt_channel_id INT = (SELECT channel_id FROM dbo.mst_channel WHERE channel_code = N'TT');
DECLARE @effective_from DATE = '2026-04-01';
DECLARE @ws_type NVARCHAR(50) = N'OLD';

IF @tt_channel_id IS NULL
    THROW 52001, 'TT channel not found.', 1;

IF OBJECT_ID('tempdb..#topws_map', 'U') IS NOT NULL DROP TABLE #topws_map;
CREATE TABLE #topws_map (
    source_product_code NVARCHAR(50) NOT NULL,
    target_product_code NVARCHAR(50) NOT NULL,
    weight_percent DECIMAL(9,4) NOT NULL
);

INSERT INTO #topws_map (source_product_code, target_product_code, weight_percent)
VALUES
    (N'A',  N'AJ',   0.0500),
    (N'R',  N'RD',   0.1000),
    (N'B',  N'BD',   0.2000),
    (N'AP', N'AJP',  0.0500),
    (N'Q',  N'RDC',  0.1000),
    (N'M',  N'RM',   0.0500),
    (N'NS', N'RDNS', 0.1000),
    (N'Y',  N'YY',   0.1500),
    (N'P',  N'PDC',  0.1000),
    (N'T',  N'TKM',  0.0500),
    (N'RK', N'RKR',  0.0500);

IF EXISTS (
    SELECT 1
    FROM #topws_map m
    LEFT JOIN dbo.mst_product p
        ON p.product_code = m.target_product_code
    WHERE p.product_id IS NULL
)
    THROW 52002, 'Some target_product_code values do not exist in mst_product.', 1;

;WITH src AS (
    SELECT
        m.source_product_code,
        p.product_id AS target_product_id,
        m.weight_percent
    FROM #topws_map m
    INNER JOIN dbo.mst_product p
        ON p.product_code = m.target_product_code
)
MERGE dbo.mst_product_mapping AS tgt
USING src
    ON tgt.source_product_code = src.source_product_code
   AND tgt.target_product_id = src.target_product_id
WHEN MATCHED THEN
    UPDATE SET
        tgt.source_system = N'TOP_WS',
        tgt.mapping_type = N'DIRECT_PRODUCT_MAP',
        tgt.remarks = N'TT Top WS mapping',
        tgt.is_active = 1,
        tgt.updated_at = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (source_system, source_product_code, target_product_id, mapping_type, remarks, is_active)
    VALUES (N'TOP_WS', src.source_product_code, src.target_product_id, N'DIRECT_PRODUCT_MAP', N'TT Top WS mapping', 1);

;WITH src AS (
    SELECT
        @tt_channel_id AS channel_id,
        p.product_id,
        @ws_type AS ws_type,
        m.weight_percent,
        @effective_from AS effective_from
    FROM #topws_map m
    INNER JOIN dbo.mst_product p
        ON p.product_code = m.target_product_code
)
MERGE dbo.mst_product_weight AS tgt
USING src
    ON tgt.channel_id = src.channel_id
   AND tgt.product_id = src.product_id
   AND tgt.ws_type = src.ws_type
   AND tgt.effective_from = src.effective_from
WHEN MATCHED THEN
    UPDATE SET
        tgt.weight_percent = src.weight_percent,
        tgt.effective_to = NULL,
        tgt.is_active = 1,
        tgt.updated_at = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (channel_id, product_id, ws_type, weight_percent, effective_from, effective_to, is_active)
    VALUES (src.channel_id, src.product_id, src.ws_type, src.weight_percent, src.effective_from, NULL, 1);

-- Result summary
;WITH topws(code) AS (
    SELECT v.code FROM (VALUES
        (N'A'),(N'R'),(N'B'),(N'AP'),(N'Q'),(N'M'),(N'NS'),(N'Y'),(N'P'),(N'T'),(N'RK')
    ) v(code)
),
code_map AS (
    SELECT
        t.code AS top_ws_code,
        CASE UPPER(t.code)
            WHEN N'A' THEN N'AJ'
            WHEN N'AP' THEN N'AJP'
            WHEN N'R' THEN N'RD'
            WHEN N'B' THEN N'BD'
            WHEN N'P' THEN N'PDC'
            WHEN N'Q' THEN N'RDC'
            WHEN N'M' THEN N'RM'
            WHEN N'NS' THEN N'RDNS'
            WHEN N'RK' THEN N'RKR'
            WHEN N'T' THEN N'TKM'
            WHEN N'Y' THEN N'YY'
            ELSE UPPER(t.code)
        END AS mapped_product_code
    FROM topws t
)
SELECT
    cm.top_ws_code,
    cm.mapped_product_code,
    CASE WHEN p.product_id IS NULL THEN 0 ELSE 1 END AS has_product_master,
    CASE WHEN pm.product_mapping_id IS NULL THEN 0 ELSE 1 END AS has_product_mapping,
    CASE WHEN pw.product_weight_id IS NULL THEN 0 ELSE 1 END AS has_tt_weight,
    pw.weight_percent
FROM code_map cm
LEFT JOIN dbo.mst_product p
    ON p.product_code = cm.mapped_product_code
LEFT JOIN dbo.mst_product_mapping pm
    ON pm.source_product_code = cm.top_ws_code
   AND pm.target_product_id = p.product_id
   AND pm.is_active = 1
OUTER APPLY (
    SELECT TOP 1 pw.product_weight_id, pw.weight_percent
    FROM dbo.mst_product_weight pw
    WHERE pw.channel_id = @tt_channel_id
      AND pw.product_id = p.product_id
      AND pw.ws_type = @ws_type
      AND pw.is_active = 1
    ORDER BY pw.effective_from DESC
) pw
ORDER BY cm.top_ws_code;

DROP TABLE #topws_map;
GO
