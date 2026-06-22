-- =============================================================
-- AJT_SIS: Schema Discovery Queries
-- Run this script in AJT_SIS database, then share results with SA
-- Date: 2026-06-13
-- =============================================================

USE [AJT_SIS];
GO

-- ----------------------------------------------------------------
-- 1. Existing schemas
-- ----------------------------------------------------------------
SELECT
    name AS schema_name,
    SCHEMA_OWNER = (SELECT name FROM sys.database_principals p WHERE p.principal_id = s.principal_id)
FROM sys.schemas s
WHERE name NOT IN ('sys','INFORMATION_SCHEMA','db_owner','db_accessadmin',
                   'db_securityadmin','db_ddladmin','db_backupoperator',
                   'db_datareader','db_datawriter','db_denydatareader','db_denydatawriter','guest')
ORDER BY name;
GO

-- ----------------------------------------------------------------
-- 2. All user tables with schema and row count
-- ----------------------------------------------------------------
SELECT
    t.TABLE_SCHEMA,
    t.TABLE_NAME,
    p.rows AS row_count,
    t.TABLE_TYPE
FROM INFORMATION_SCHEMA.TABLES t
INNER JOIN sys.tables st ON st.name = t.TABLE_NAME
    AND SCHEMA_NAME(st.schema_id) = t.TABLE_SCHEMA
INNER JOIN sys.partitions p ON p.object_id = st.object_id AND p.index_id IN (0,1)
WHERE t.TABLE_TYPE = 'BASE TABLE'
ORDER BY t.TABLE_SCHEMA, t.TABLE_NAME;
GO

-- ----------------------------------------------------------------
-- 3. All columns with data type detail (for all user tables)
-- ----------------------------------------------------------------
SELECT
    c.TABLE_SCHEMA,
    c.TABLE_NAME,
    c.COLUMN_NAME,
    c.ORDINAL_POSITION,
    c.COLUMN_DEFAULT,
    c.IS_NULLABLE,
    c.DATA_TYPE,
    c.CHARACTER_MAXIMUM_LENGTH,
    c.NUMERIC_PRECISION,
    c.NUMERIC_SCALE,
    c.DATETIME_PRECISION,
    CASE WHEN kcu.COLUMN_NAME IS NOT NULL THEN 'PK' ELSE '' END AS is_pk
FROM INFORMATION_SCHEMA.COLUMNS c
LEFT JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
    ON tc.TABLE_SCHEMA = c.TABLE_SCHEMA
    AND tc.TABLE_NAME = c.TABLE_NAME
    AND tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
LEFT JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
    ON kcu.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
    AND kcu.TABLE_SCHEMA = c.TABLE_SCHEMA
    AND kcu.TABLE_NAME = c.TABLE_NAME
    AND kcu.COLUMN_NAME = c.COLUMN_NAME
WHERE c.TABLE_SCHEMA NOT IN ('sys','INFORMATION_SCHEMA','guest')
ORDER BY c.TABLE_SCHEMA, c.TABLE_NAME, c.ORDINAL_POSITION;
GO

-- ----------------------------------------------------------------
-- 4. Primary keys
-- ----------------------------------------------------------------
SELECT
    tc.TABLE_SCHEMA,
    tc.TABLE_NAME,
    tc.CONSTRAINT_NAME,
    tc.CONSTRAINT_TYPE,
    kcu.COLUMN_NAME,
    kcu.ORDINAL_POSITION
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
    ON kcu.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
    AND kcu.TABLE_SCHEMA = tc.TABLE_SCHEMA
    AND kcu.TABLE_NAME = tc.TABLE_NAME
WHERE tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
ORDER BY tc.TABLE_SCHEMA, tc.TABLE_NAME, kcu.ORDINAL_POSITION;
GO

-- ----------------------------------------------------------------
-- 5. Foreign keys
-- ----------------------------------------------------------------
SELECT
    fk.name AS fk_name,
    SCHEMA_NAME(tp.schema_id) AS parent_schema,
    tp.name AS parent_table,
    cp.name AS parent_column,
    SCHEMA_NAME(tr.schema_id) AS referenced_schema,
    tr.name AS referenced_table,
    cr.name AS referenced_column
FROM sys.foreign_keys fk
INNER JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id
INNER JOIN sys.tables tp ON tp.object_id = fkc.parent_object_id
INNER JOIN sys.columns cp ON cp.object_id = fkc.parent_object_id AND cp.column_id = fkc.parent_column_id
INNER JOIN sys.tables tr ON tr.object_id = fkc.referenced_object_id
INNER JOIN sys.columns cr ON cr.object_id = fkc.referenced_object_id AND cr.column_id = fkc.referenced_column_id
ORDER BY parent_schema, parent_table, fk_name;
GO

-- ----------------------------------------------------------------
-- 6. Unique constraints and indexes
-- ----------------------------------------------------------------
SELECT
    SCHEMA_NAME(t.schema_id) AS schema_name,
    t.name AS table_name,
    i.name AS index_name,
    CASE i.is_unique_constraint WHEN 1 THEN 'UNIQUE CONSTRAINT'
         WHEN 0 THEN CASE i.is_unique WHEN 1 THEN 'UNIQUE INDEX' ELSE 'INDEX' END
    END AS index_type,
    c.name AS column_name,
    ic.key_ordinal
FROM sys.indexes i
INNER JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
INNER JOIN sys.columns c ON c.object_id = i.object_id AND c.column_id = ic.column_id
INNER JOIN sys.tables t ON t.object_id = i.object_id
WHERE i.is_primary_key = 0
  AND t.is_ms_shipped = 0
  AND SCHEMA_NAME(t.schema_id) NOT IN ('sys','INFORMATION_SCHEMA','guest')
ORDER BY schema_name, table_name, index_name, ic.key_ordinal;
GO

-- ----------------------------------------------------------------
-- 7. ajt-schema specific: quick check if schema + tables already exist
-- ----------------------------------------------------------------
SELECT
    SCHEMA_NAME(t.schema_id) AS schema_name,
    t.name AS table_name,
    p.rows AS row_count
FROM sys.tables t
INNER JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0,1)
WHERE SCHEMA_NAME(t.schema_id) = 'ajt'
ORDER BY t.name;
GO
