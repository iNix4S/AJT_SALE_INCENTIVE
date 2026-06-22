SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*
Purpose:
- Provide one-stop view for position level names and incentive rates.
- Combine mst_position_level and mst_incentive_rate with channel context.
*/
CREATE OR ALTER VIEW dbo.vw_mst_position_incentive_rate_detail
AS
SELECT
    p.position_level_id,
    p.position_code,
    p.position_name_th,
    p.position_name_en,
    p.hierarchy_level,
    p.is_active AS position_is_active,

    r.incentive_rate_id,
    r.channel_id,
    c.channel_code,
    c.channel_name_th,
    c.channel_name_en,
    c.calc_type,
    r.ws_type,
    r.rate_old,
    r.rate_new,
    r.effective_from,
    r.effective_to,
    r.is_active AS incentive_rate_is_active,

    p.created_at AS position_created_at,
    p.updated_at AS position_updated_at,
    r.created_at AS incentive_rate_created_at,
    r.updated_at AS incentive_rate_updated_at
FROM dbo.mst_incentive_rate r
JOIN dbo.mst_position_level p
    ON p.position_level_id = r.position_level_id
JOIN dbo.mst_channel c
    ON c.channel_id = r.channel_id;
GO
