USE [AJT_SIS];
GO

-- Verify current TT calc_type value in dev database
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

-- Expected value for TT after latest logic alignment
-- calc_type = 'SINGLE_SHEET_5_LEVEL_AVG'
