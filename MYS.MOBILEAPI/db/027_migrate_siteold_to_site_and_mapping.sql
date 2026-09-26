/*
  Populates dbo.SITE + dbo.SITE_MAPPING from dbo.SITEOLD.

  Supersedes 026_site_customer_mapping_split.sql for db_ams_erp and
  DB_AMS_ERP_SMS: both were restructured manually (the original dbo.SITE
  renamed aside to dbo.SITEOLD, then a fresh new-shape dbo.SITE created)
  before 026 was run, so 026's in-place ALTER TABLE / column-drop approach
  no longer applies there — this script is the one to run instead. (026
  still applies as documented to any database that keeps its original
  dbo.SITE and only needs the old columns dropped in place.)

  Confirmed via read-only check immediately before writing this: both
  db_ams_erp (25 rows) and DB_AMS_ERP_SMS (26 rows) have dbo.SITEOLD with
  every row's CUSTOMERID populated, dbo.SITE already recreated fresh and
  empty, and dbo.SITE_MAPPING not created yet. No blank SITENAME/AREANAME
  rows, single CITYID (1 = COIMBATORE) in use, and no SITEID overlap
  between SITEOLD and the new SITE.

  - Creates dbo.SITE_MAPPING if missing (same shape as 026/deploy_mobile_schema.sql).
  - SITEID is preserved exactly via IDENTITY_INSERT. TRIPENTRY.SITEID,
    SALESORDER.SITEID and DELIVERY_DETAILS.SITEID all reference these IDs,
    so a re-generated identity would silently misdirect every historical
    row pointing at a site.
  - AREAID: SITEOLD predates the Area master and carries AREAID = 0 with
    only a free-text AREANAME. Resolved against dbo.AREA by name+city
    (case-insensitive, trimmed), auto-creating a new AREA row for any area
    name with no existing match (falls back to SITENAME if AREANAME is
    ever blank, though no such rows exist in either prod database today).
  - SITE_MAPPING gets one row per SITEOLD row that has a CUSTOMERID,
    carrying over that row's own audit columns (no separate mapping
    history exists to preserve) and STATUS = the SITEOLD row's own STATUS,
    so a soft-deleted site doesn't get an active mapping.

  Idempotent: every step is guarded, so it's safe to re-run — a re-run
  after a partial failure only inserts whatever's still missing.
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

-- 1. Auto-create any missing AREA rows for SITEOLD's free-text area names.
INSERT INTO dbo.AREA (AreaName, CityId, IsActive, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
SELECT DISTINCT effective.AreaNameResolved, SO.CITYID, 1, SYSDATETIME(), 'SITEOLD Migration', SYSDATETIME(), 'SITEOLD Migration'
FROM dbo.SITEOLD SO
CROSS APPLY (SELECT COALESCE(NULLIF(LTRIM(RTRIM(SO.AREANAME)), ''), SO.SITENAME) AS AreaNameResolved) effective
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.AREA A
    WHERE UPPER(LTRIM(RTRIM(A.AreaName))) = UPPER(LTRIM(RTRIM(effective.AreaNameResolved)))
      AND A.CityId = SO.CITYID
);
GO

-- 2. Insert SITE rows, preserving SITEID, resolving AreaId via the same match.
SET IDENTITY_INSERT dbo.SITE ON;

INSERT INTO dbo.SITE (SITEID, SITENAME, AREAID, STATUS, CREATEDLOCATIONID, MODIFYEDLOCATIONID, CREATEDUSERID, LASTMODIFYEDUSERID, USERCREATEDDATE, LASTMODIFYEDDATE, CREATEDEMPLOYEEID, MODIFYEDEMPLOYEEID)
SELECT SO.SITEID, SO.SITENAME, A.AreaId, SO.STATUS, SO.CREATEDLOCATIONID, SO.MODIFYEDLOCATIONID, SO.CREATEDUSERID, SO.LASTMODIFYEDUSERID, SO.USERCREATEDDATE, SO.LASTMODIFYEDDATE, SO.CREATEDEMPLOYEEID, SO.MODIFYEDEMPLOYEEID
FROM dbo.SITEOLD SO
CROSS APPLY (SELECT COALESCE(NULLIF(LTRIM(RTRIM(SO.AREANAME)), ''), SO.SITENAME) AS AreaNameResolved) effective
INNER JOIN dbo.AREA A ON UPPER(LTRIM(RTRIM(A.AreaName))) = UPPER(LTRIM(RTRIM(effective.AreaNameResolved))) AND A.CityId = SO.CITYID
WHERE NOT EXISTS (SELECT 1 FROM dbo.SITE S WHERE S.SITEID = SO.SITEID);

SET IDENTITY_INSERT dbo.SITE OFF;
GO

-- 3. Insert SITE_MAPPING rows for every SITEOLD row that has a CUSTOMERID.
INSERT INTO dbo.SITE_MAPPING (SITEID, CUSTOMERID, STATUS, CREATEDLOCATIONID, MODIFYEDLOCATIONID, CREATEDUSERID, LASTMODIFYEDUSERID, USERCREATEDDATE, LASTMODIFYEDDATE, CREATEDEMPLOYEEID, MODIFYEDEMPLOYEEID)
SELECT SO.SITEID, SO.CUSTOMERID, SO.STATUS, SO.CREATEDLOCATIONID, SO.MODIFYEDLOCATIONID, SO.CREATEDUSERID, SO.LASTMODIFYEDUSERID, SO.USERCREATEDDATE, SO.LASTMODIFYEDDATE, SO.CREATEDEMPLOYEEID, SO.MODIFYEDEMPLOYEEID
FROM dbo.SITEOLD SO
WHERE SO.CUSTOMERID IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.SITE_MAPPING SM WHERE SM.SITEID = SO.SITEID);
GO
