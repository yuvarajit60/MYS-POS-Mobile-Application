/*
  Multi-tenant control-plane schema. Routes each mobile login to the real
  database it belongs to: MOBILE_USER_DIRECTORY maps a username (and,
  for OTP login, a mobile number) to a TENANTCODE, and TENANTS maps that
  code to the actual connection string. See Auth/ITenantRegistry.cs for
  how the API resolves this per request, and Data/ITenantContext.cs /
  Data/ISqlConnectionFactory.cs for how every other query then transparently
  goes to the right tenant's database.

  TEMPORARY LOCATION: running against db_ams_pos_test for now, since this
  needs a database of its own (a dedicated MYS_MOBILE_CONTROL) and the
  amstech login lacks CREATE DATABASE rights to make one itself — someone
  with sysadmin/dbcreator rights needs to run `CREATE DATABASE
  MYS_MOBILE_CONTROL;` first. Once that exists: re-run this script against
  it, update appsettings' ConnectionStrings:ControlDb (and Render's
  ConnectionStrings__ControlDb) to point there instead, and drop these two
  tables back out of db_ams_pos_test.

  Idempotent — safe to re-run.

  SECURITY: fill in @DbPassword (declared just before section 3 below,
  redeclared there rather than at the top of the file since a DECLARE
  doesn't survive a GO batch boundary) with the real amstech password
  before running this — it's deliberately left out of this committed
  file. Unlike appsettings.Development.json (gitignored), a .sql file in
  this repo is not, so a real credential typed directly into the INSERTs
  would land in git history permanently, including anyone's future clone
  of this repo.
*/

------------------------------------------------------------
-- 1. TENANTS — one row per customer's real database
------------------------------------------------------------
IF OBJECT_ID(N'dbo.TENANTS', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TENANTS
    (
        TENANTCODE       VARCHAR(20)  NOT NULL PRIMARY KEY,
        TENANTNAME       VARCHAR(100) NOT NULL,
        CONNECTIONSTRING VARCHAR(500) NOT NULL,
        STATUS           BIT          NOT NULL CONSTRAINT DF_TENANTS_STATUS DEFAULT 1,
        CREATEDDATE      DATETIME     NOT NULL CONSTRAINT DF_TENANTS_CREATEDDATE DEFAULT GETDATE()
    );
END
GO

------------------------------------------------------------
-- 2. MOBILE_USER_DIRECTORY — which tenant a login belongs to
------------------------------------------------------------
IF OBJECT_ID(N'dbo.MOBILE_USER_DIRECTORY', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.MOBILE_USER_DIRECTORY
    (
        USERNAME    VARCHAR(50) NOT NULL PRIMARY KEY,
        MOBILENO    VARCHAR(20) NULL,
        TENANTCODE  VARCHAR(20) NOT NULL CONSTRAINT FK_MOBILE_USER_DIRECTORY_TENANTS REFERENCES dbo.TENANTS(TENANTCODE),
        STATUS      BIT         NOT NULL CONSTRAINT DF_MOBILE_USER_DIRECTORY_STATUS DEFAULT 1,
        CREATEDDATE DATETIME    NOT NULL CONSTRAINT DF_MOBILE_USER_DIRECTORY_CREATEDDATE DEFAULT GETDATE()
    );
    CREATE INDEX IX_MOBILE_USER_DIRECTORY_MOBILENO ON dbo.MOBILE_USER_DIRECTORY(MOBILENO);
END
GO

------------------------------------------------------------
-- 3. Seed tenants — fill in @DbPassword before running (see this file's
--    header). All three tenants share the same server/login today; if a
--    future customer ever lives on a different server or login, just
--    write that row's CONNECTIONSTRING out in full instead of using
--    @DbPassword.
------------------------------------------------------------
DECLARE @DbPassword VARCHAR(100) = '<REPLACE_WITH_REAL_AMSTECH_PASSWORD>';

IF NOT EXISTS (SELECT 1 FROM dbo.TENANTS WHERE TENANTCODE = 'AMS_ERP')
    INSERT INTO dbo.TENANTS (TENANTCODE, TENANTNAME, CONNECTIONSTRING)
    VALUES ('AMS_ERP', 'AMS ERP (Customer A)', 'Server=103.191.208.18;Database=db_ams_erp;User Id=amstech;Password=' + @DbPassword + ';TrustServerCertificate=True;');

IF NOT EXISTS (SELECT 1 FROM dbo.TENANTS WHERE TENANTCODE = 'SMS_ERP')
    INSERT INTO dbo.TENANTS (TENANTCODE, TENANTNAME, CONNECTIONSTRING)
    VALUES ('SMS_ERP', 'SMS ERP (Customer B)', 'Server=103.191.208.18;Database=DB_AMS_ERP_SMS;User Id=amstech;Password=' + @DbPassword + ';TrustServerCertificate=True;');

-- Sandbox tenant, used only for local dev/testing against db_ams_pos_test itself.
IF NOT EXISTS (SELECT 1 FROM dbo.TENANTS WHERE TENANTCODE = 'TEST_DB')
    INSERT INTO dbo.TENANTS (TENANTCODE, TENANTNAME, CONNECTIONSTRING)
    VALUES ('TEST_DB', 'Sandbox (db_ams_pos_test)', 'Server=103.191.208.18;Database=db_ams_pos_test;User Id=amstech;Password=' + @DbPassword + ';TrustServerCertificate=True;');

------------------------------------------------------------
-- 4. Seed the directory
------------------------------------------------------------
-- 'amserp' was already created directly in db_ams_erp.USERS for this purpose.
IF NOT EXISTS (SELECT 1 FROM dbo.MOBILE_USER_DIRECTORY WHERE USERNAME = 'amserp')
    INSERT INTO dbo.MOBILE_USER_DIRECTORY (USERNAME, MOBILENO, TENANTCODE)
    VALUES ('amserp', NULL, 'AMS_ERP');

-- 'smserp' still needs to be created in DB_AMS_ERP_SMS.USERS (mirroring how
-- 'amserp' was set up in db_ams_erp) before this row is added — see the
-- corresponding go-live guidance for DB_AMS_ERP_SMS.
-- INSERT INTO dbo.MOBILE_USER_DIRECTORY (USERNAME, MOBILENO, TENANTCODE)
-- VALUES ('smserp', NULL, 'SMS_ERP');
GO
