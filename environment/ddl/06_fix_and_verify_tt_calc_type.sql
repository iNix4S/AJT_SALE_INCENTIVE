USE [AJT_SIS];
GO

BEGIN TRAN;

UPDATE dbo.mst_channel
SET
    calc_type = 'SINGLE_SHEET_5_LEVEL_AVG',
    updated_at = SYSUTCDATETIME()
WHERE channel_code = 'TT';

SELECT @@ROWCOUNT AS affected_rows;

COMMIT TRAN;
GO

SELECT
    channel_code,
    channel_name_th,
    calc_type,
    is_active,
    created_at,
    updated_at
FROM dbo.mst_channel
WHERE channel_code = 'TT';
GO
