/*
  GO-LIVE PREREQUISITES for DB_AMS_ERP_SMS (real production DB).

  Found by comparing db_ams_pos_test (dev/test copy) against DB_AMS_ERP_SMS
  (read-only comparison, 2026-08-27) — three objects the mobile API code
  assumes already exist (same as the desktop-app tables it was built
  against) turned out to be present in the test copy but MISSING from real
  production. Everything else compared column-for-column identical:
  TRIPENTRY/TRIPENTRY_DETAILS (incl. the mobile-added METERORHOURSID/
  TIMESTART/TIMECLOSE/METERSTART/METERCLOSE/VEHICLEID columns), SITE,
  VEHICLE, PRODUCT, COMPANY, CUSTOMER, USERS all matched exactly, and
  TRANSACTIONS already has SALESORDER/TRIPENTRY numbering rows seeded for
  the one active location — no changes needed there.

  Idempotent — safe to re-run. Run this BEFORE deploy_mobile_schema.sql
  (order doesn't strictly matter — nothing here has a SQL-level dependency
  on the mobile stored procs, or vice versa — but this reads as prerequisites-
  first).

  *** HIGHEST-RISK ITEM: the EMPLOYEE.ISDRIVER column add below. ***
  EMPLOYEE is a live, heavily-used desktop-app table. A NOT NULL column
  with a DEFAULT is safe against any INSERT that lists explicit column
  names (existing rows/inserts are unaffected). It is NOT safe against a
  positional `INSERT INTO EMPLOYEE VALUES (...)` with no column list
  anywhere in the desktop app — that would break the moment a new column
  is appended. Confirm the desktop app's EMPLOYEE insert uses an explicit
  column list before running this in production. Without this column,
  mobile login fails entirely (not just driver detection) — AuthService's
  base login query selects EMP.ISDRIVER directly, for every user.
*/

------------------------------------------------------------
-- 1. EMPLOYEE.ISDRIVER — required for ALL mobile login (not just
--    driver-restriction) since AuthService's queries select it directly.
------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'EMPLOYEE' AND COLUMN_NAME = 'ISDRIVER'
)
BEGIN
    ALTER TABLE dbo.EMPLOYEE
        ADD ISDRIVER INT NOT NULL CONSTRAINT DF_EMPLOYEE_ISDRIVER DEFAULT 0;
END
GO

------------------------------------------------------------
-- 2. PRODUCT_DETAILS — written by the mobile "Add New Product" flow
--    (ProductService.CreateAsync/UpdateAsync) right after PRODUCT itself.
------------------------------------------------------------
IF OBJECT_ID(N'dbo.PRODUCT_DETAILS', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PRODUCT_DETAILS
    (
        PRODUCTID        INT           NOT NULL,
        PRODUCTNAME      VARCHAR(100)  NOT NULL,
        SALE_RATE        NUMERIC(12,2) NOT NULL,
        RETAIL_RATE      NUMERIC(18,0) NOT NULL,
        PURCHASE_RATE    NUMERIC(12,2) NOT NULL,
        VALID_START_DATE DATETIME      NOT NULL,
        VALID_END_DATE   DATETIME      NULL,
        CREATE_DATE      DATETIME      NOT NULL,
        CREATE_USER      VARCHAR(50)   NOT NULL,
        MODIFIED_DATE    DATETIME      NULL,
        MODIFIED_USER    VARCHAR(50)   NULL,
        VALID            INT           NOT NULL CONSTRAINT DF_PRODUCT_DETAILS_VALID DEFAULT 1
    );
END
GO

------------------------------------------------------------
-- 3. EMPLOYEE_VEHICLE_MAPPING — read by the mobile Trip Entry screen to
--    auto-fill a driver's vehicle (EmployeeService.GetDriverVehicleAsync).
--    Mobile only ever reads this table; the desktop app is expected to
--    populate it. Matches test DB's column typing exactly, including
--    EMPLOYEEID/VEHICLEID being VARCHAR rather than INT (a pre-existing
--    quirk, not something introduced here).
------------------------------------------------------------
IF OBJECT_ID(N'dbo.EMPLOYEE_VEHICLE_MAPPING', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.EMPLOYEE_VEHICLE_MAPPING
    (
        MAPPINGID          INT IDENTITY(1,1) NOT NULL,
        EMPLOYEEID         VARCHAR(50)  NULL,
        VEHICLEID          VARCHAR(50)  NULL,
        VALIDSTARTDATE     DATETIME     NULL,
        VALIDENDDATE       DATETIME     NULL,
        CREATEDUSERID      INT          NOT NULL,
        LASTMODIFYEDUSERID INT          NOT NULL,
        USERCREATEDDATE    DATETIME     NULL,
        LASTMODIFYEDDATE   DATETIME     NULL,
        CREATEDEMPLOYEEID  INT          NOT NULL,
        MODIFYEDEMPLOYEEID INT          NOT NULL
    );
END
GO
