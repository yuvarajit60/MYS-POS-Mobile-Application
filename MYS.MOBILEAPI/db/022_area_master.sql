/*
  Area master — the Site form's free-text "Area Name" field becomes a
  picker sourced from dbo.AREA, scoped to the site's own City (dbo.AREA
  has its own CityId, so an area belongs to exactly one city).

  IMPORTANT: dbo.AREA already exists on db_ams_pos_test with real data
  (8 rows, genuine Coimbatore-area names) and a schema that does NOT
  follow this project's usual ALLCAPS legacy-desktop column convention —
  it uses PascalCase (AreaId, AreaName, CityId, IsActive, CreatedOn,
  CreatedBy, UpdatedOn, UpdatedBy), evidently created ahead of this
  feature by hand rather than by the desktop app. It does NOT exist yet
  on db_ams_erp / DB_AMS_ERP_SMS (confirmed 2026-09-21). This script
  matches that already-established sandbox shape exactly rather than
  inventing a different one, so the same backend code works unmodified
  against all three databases and the real sandbox data isn't disturbed.

  CreatedBy/UpdatedBy store the acting user's username (VARCHAR-style
  convention already used for DELIVERY_DETAILS.CREATE_USER etc.
  elsewhere in this project), not a numeric user ID.

  SITE.AREAID (new column, INT NOT NULL DEFAULT 0 — same "unset"
  sentinel convention as every other *ID column added in this project)
  links each site to its Area row. AREANAME is still stored on SITE too
  (same relationship as SITEID/SHIPPINGADDRESS on SALESORDER): AREAID is
  the real reference, AREANAME is the human-readable snapshot the app
  already reads directly off SITE without a join.

  Idempotent — safe to re-run.
*/

------------------------------------------------------------
-- 1. AREA table (only created where it doesn't already exist)
------------------------------------------------------------
IF OBJECT_ID(N'dbo.AREA', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.AREA
    (
        AreaId    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Area PRIMARY KEY,
        AreaName  NVARCHAR(MAX) NOT NULL,
        CityId    INT           NOT NULL,
        IsActive  BIT           NOT NULL CONSTRAINT DF_Area_IsActive DEFAULT 1,
        CreatedOn DATETIME2     NOT NULL CONSTRAINT DF_Area_CreatedOn DEFAULT SYSDATETIME(),
        CreatedBy NVARCHAR(MAX) NULL,
        UpdatedOn DATETIME2     NOT NULL CONSTRAINT DF_Area_UpdatedOn DEFAULT SYSDATETIME(),
        UpdatedBy NVARCHAR(MAX) NULL
    );
END
GO

------------------------------------------------------------
-- 2. SITE.AREAID
------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'SITE' AND COLUMN_NAME = 'AREAID'
)
BEGIN
    ALTER TABLE dbo.SITE
        ADD AREAID INT NOT NULL CONSTRAINT DF_SITE_AREAID DEFAULT 0;
END
GO
