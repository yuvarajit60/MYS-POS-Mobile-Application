/*
  Splits dbo.SITE into two tables (matching the split already made on the
  sandbox, db_ams_pos_test):
    - dbo.SITE keeps only site master data — SITENAME + AREAID. City is no
      longer stored directly on SITE; it's derived via AREAID -> AREA.CityId
      -> CITY.CITYID, same chain the Area master already uses.
    - dbo.SITE_MAPPING is new and owns the Site-to-Customer mapping.
      STATUS = 1 marks the currently active mapping for a SITEID (at most
      one active row per site); remapping/unmapping closes the old active
      row (STATUS = 0) rather than overwriting it, so mapping history is
      kept instead of lost.

  Steps, all idempotent/re-runnable:
    1. Create dbo.SITE_MAPPING if missing.
    2. Backfill one active SITE_MAPPING row per existing SITE row that still
       has a CUSTOMERID, before that column is dropped. Skipped per-site if
       a SITE_MAPPING row already exists for it (so re-running this script
       after it partially applied won't duplicate rows).
    3. Drop dbo.SITE.AREANAME, CITYID, CUSTOMERID — each column's default
       constraint (if any) is located and dropped first via dynamic SQL,
       since constraint names differ between db_ams_erp and DB_AMS_ERP_SMS
       (e.g. DF_SITE_CITYID vs DF_SITES_CITYID).

  Confirmed against db_ams_erp/DB_AMS_ERP_SMS before writing this: both
  still have the old single-table shape with every existing SITE row's
  CUSTOMERID populated (25 and 26 rows respectively, all mapped) — so step 2
  will carry every current mapping forward with no data loss.
*/

IF OBJECT_ID(N'dbo.SITE_MAPPING', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SITE_MAPPING
    (
        ID                  INT IDENTITY(1,1) NOT NULL,
        SITEID              INT NOT NULL,
        CUSTOMERID          INT NOT NULL,
        STATUS              BIT NOT NULL CONSTRAINT DF_SITE_MAPPING_STATUS DEFAULT 1,
        CREATEDLOCATIONID   INT NOT NULL CONSTRAINT DF_SITE_MAPPING_CREATEDLOCATIONID DEFAULT 0,
        MODIFYEDLOCATIONID  INT NOT NULL CONSTRAINT DF_SITE_MAPPING_MODIFYEDLOCATIONID DEFAULT 0,
        CREATEDUSERID       INT NOT NULL CONSTRAINT DF_SITE_MAPPING_CREATEDUSERID DEFAULT 0,
        LASTMODIFYEDUSERID  INT NOT NULL CONSTRAINT DF_SITE_MAPPING_LASTMODIFYEDUSERID DEFAULT 0,
        USERCREATEDDATE     DATETIME NULL,
        LASTMODIFYEDDATE    DATETIME NULL,
        CREATEDEMPLOYEEID   INT NOT NULL CONSTRAINT DF_SITE_MAPPING_CREATEDEMPLOYEEID DEFAULT 0,
        MODIFYEDEMPLOYEEID  INT NOT NULL CONSTRAINT DF_SITE_MAPPING_MODIFYEDEMPLOYEEID DEFAULT 0
    );
END
GO

-- Wrapped in EXEC() (dynamic SQL) rather than a plain BEGIN/END block:
-- SITE.CUSTOMERID is validated at compile time even inside an untaken IF
-- branch once SITE already exists (deferred name resolution only covers
-- objects that don't exist yet, not missing columns on ones that do), so a
-- plain INSERT here would fail to compile on the sandbox where the column
-- is already gone.
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'SITE' AND COLUMN_NAME = 'CUSTOMERID')
BEGIN
    EXEC(N'
        INSERT INTO dbo.SITE_MAPPING
            (SITEID, CUSTOMERID, STATUS, CREATEDLOCATIONID, MODIFYEDLOCATIONID, CREATEDUSERID, LASTMODIFYEDUSERID,
             USERCREATEDDATE, LASTMODIFYEDDATE, CREATEDEMPLOYEEID, MODIFYEDEMPLOYEEID)
        SELECT S.SITEID, S.CUSTOMERID, 1, S.CREATEDLOCATIONID, S.MODIFYEDLOCATIONID, S.CREATEDUSERID, S.LASTMODIFYEDUSERID,
               S.USERCREATEDDATE, S.LASTMODIFYEDDATE, S.CREATEDEMPLOYEEID, S.MODIFYEDEMPLOYEEID
        FROM dbo.SITE S
        WHERE S.CUSTOMERID IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM dbo.SITE_MAPPING SM WHERE SM.SITEID = S.SITEID);
    ');
END
GO

DECLARE @ConstraintName SYSNAME;

WHILE EXISTS (
    SELECT 1 FROM sys.default_constraints dc
    JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id
    WHERE dc.parent_object_id = OBJECT_ID('dbo.SITE') AND c.name IN ('AREANAME', 'CITYID', 'CUSTOMERID')
)
BEGIN
    SELECT TOP 1 @ConstraintName = dc.name
    FROM sys.default_constraints dc
    JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id
    WHERE dc.parent_object_id = OBJECT_ID('dbo.SITE') AND c.name IN ('AREANAME', 'CITYID', 'CUSTOMERID');

    EXEC('ALTER TABLE dbo.SITE DROP CONSTRAINT [' + @ConstraintName + ']');
END
GO

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'SITE' AND COLUMN_NAME = 'AREANAME')
    ALTER TABLE dbo.SITE DROP COLUMN AREANAME;
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'SITE' AND COLUMN_NAME = 'CITYID')
    ALTER TABLE dbo.SITE DROP COLUMN CITYID;
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'SITE' AND COLUMN_NAME = 'CUSTOMERID')
    ALTER TABLE dbo.SITE DROP COLUMN CUSTOMERID;
GO
