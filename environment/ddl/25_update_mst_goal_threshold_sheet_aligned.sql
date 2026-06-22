SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*
Purpose:
- ปรับ mst_goal_threshold ให้ตรงกับสูตรในชีต TT (09_2) หลักการคำนวน Table.values.csv)

ปัญหาเดิม (DB):
  Band [0.00, 0.90) → multiplier = 0.00  ← ผิด: ให้ 0 บาท แม้ยอดขายบางส่วน
  Band [0.90, 0.95) → multiplier = 0.90  ← เส้นขอบต่ำกว่าชีต (ทำให้ achievement 0.922 ได้ mult=0.90 แทน 0.95)

สูตรชีต:
  Threshold header: 0, 0.9001, 0.9501, 1.0001, 1.0301, 1.0601, 1.1001, 1.1501, 1.2001
  GOAL row:         0.9, 0.95,  1.00,   1.03,   1.06,   1.10,   1.15,   1.20,   1.30

ตารางที่ถูกต้อง:
  Band              achievement_from  achievement_to  multiplier
  1 (Minimum floor) 0.0000           0.9001          0.90
  2                 0.9001           0.9501          0.95
  3                 0.9501           1.0001          1.00
  4                 1.0001           1.0301          1.03
  5                 1.0301           1.0601          1.06
  6                 1.0601           1.1001          1.10
  7                 1.1001           1.1501          1.15
  8                 1.1501           1.2001          1.20
  9 (Cap)          1.2001           NULL            1.30

Note:
  - seq=10 (1.30-NULL, mult=1.30) ถูก deactivate เพราะ seq=9 ใหม่ครอบคลุมแล้ว
  - การเปลี่ยนแปลงนี้ส่งผลต่อทุก channel ที่ใช้ mst_goal_threshold
*/

-- Backup: แสดงค่าก่อนแก้
SELECT
    goal_threshold_id,
    achievement_from,
    achievement_to,
    multiplier,
    sequence_no,
    N'BEFORE' AS state
FROM dbo.mst_goal_threshold
ORDER BY sequence_no;

-- ปรับ Band 1: เดิม [0.00-0.90, mult=0.00] → ใหม่ [0.0000-0.9001, mult=0.90]
UPDATE dbo.mst_goal_threshold
SET achievement_from = 0.0000,
    achievement_to   = 0.9001,
    multiplier       = 0.90,
    updated_at       = SYSUTCDATETIME()
WHERE sequence_no = 1;

-- ปรับ Band 2: เดิม [0.90-0.95, mult=0.90] → ใหม่ [0.9001-0.9501, mult=0.95]
UPDATE dbo.mst_goal_threshold
SET achievement_from = 0.9001,
    achievement_to   = 0.9501,
    multiplier       = 0.95,
    updated_at       = SYSUTCDATETIME()
WHERE sequence_no = 2;

-- ปรับ Band 3: เดิม [0.95-1.00, mult=0.95] → ใหม่ [0.9501-1.0001, mult=1.00]
UPDATE dbo.mst_goal_threshold
SET achievement_from = 0.9501,
    achievement_to   = 1.0001,
    multiplier       = 1.00,
    updated_at       = SYSUTCDATETIME()
WHERE sequence_no = 3;

-- ปรับ Band 4: เดิม [1.00-1.03, mult=1.00] → ใหม่ [1.0001-1.0301, mult=1.03]
UPDATE dbo.mst_goal_threshold
SET achievement_from = 1.0001,
    achievement_to   = 1.0301,
    multiplier       = 1.03,
    updated_at       = SYSUTCDATETIME()
WHERE sequence_no = 4;

-- ปรับ Band 5: เดิม [1.03-1.06, mult=1.03] → ใหม่ [1.0301-1.0601, mult=1.06]
UPDATE dbo.mst_goal_threshold
SET achievement_from = 1.0301,
    achievement_to   = 1.0601,
    multiplier       = 1.06,
    updated_at       = SYSUTCDATETIME()
WHERE sequence_no = 5;

-- ปรับ Band 6: เดิม [1.06-1.10, mult=1.06] → ใหม่ [1.0601-1.1001, mult=1.10]
UPDATE dbo.mst_goal_threshold
SET achievement_from = 1.0601,
    achievement_to   = 1.1001,
    multiplier       = 1.10,
    updated_at       = SYSUTCDATETIME()
WHERE sequence_no = 6;

-- ปรับ Band 7: เดิม [1.10-1.15, mult=1.10] → ใหม่ [1.1001-1.1501, mult=1.15]
UPDATE dbo.mst_goal_threshold
SET achievement_from = 1.1001,
    achievement_to   = 1.1501,
    multiplier       = 1.15,
    updated_at       = SYSUTCDATETIME()
WHERE sequence_no = 7;

-- ปรับ Band 8: เดิม [1.15-1.20, mult=1.15] → ใหม่ [1.1501-1.2001, mult=1.20]
UPDATE dbo.mst_goal_threshold
SET achievement_from = 1.1501,
    achievement_to   = 1.2001,
    multiplier       = 1.20,
    updated_at       = SYSUTCDATETIME()
WHERE sequence_no = 8;

-- ปรับ Band 9: เดิม [1.20-1.30, mult=1.20] → ใหม่ [1.2001-NULL, mult=1.30] (รวมกับ seq=10)
UPDATE dbo.mst_goal_threshold
SET achievement_from = 1.2001,
    achievement_to   = NULL,
    multiplier       = 1.30,
    updated_at       = SYSUTCDATETIME()
WHERE sequence_no = 9;

-- Deactivate Band 10 (1.30-NULL, mult=1.30) ซ้ำกับ seq=9 ใหม่
UPDATE dbo.mst_goal_threshold
SET is_active   = 0,
    updated_at  = SYSUTCDATETIME()
WHERE sequence_no = 10;

-- แสดงผลหลังแก้
SELECT
    goal_threshold_id,
    achievement_from,
    achievement_to,
    multiplier,
    sequence_no,
    is_active,
    N'AFTER' AS state
FROM dbo.mst_goal_threshold
ORDER BY sequence_no;
