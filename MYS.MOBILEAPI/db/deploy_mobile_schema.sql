/*
  AMSEL Mobile App — consolidated database objects, final state.
  Run this ONCE against the target database after it already has the full
  existing db_ams_erp schema loaded (see the note in the chat reply this
  file was provided alongside — this script alone is NOT a complete
  database; it only adds the mobile-app-specific objects on top).

  Equivalent to running 001_create_mobile_objects.sql followed by
  002_product_redesign.sql, but with the superseded (001-only) versions of
  TVP_MOBILE_SALESORDER_LINES / SP_MOBILE_CREATE_SALESORDER left out, since
  002 immediately replaces them anyway. Idempotent — safe to re-run.

  Also includes 003_trip_entry.sql's objects (Trip Entry, added later —
  see that file's header for the METERORHOURSID convention it introduces),
  004_prod_prerequisites.sql's objects (EMPLOYEE.ISDRIVER, PRODUCT_DETAILS,
  EMPLOYEE_VEHICLE_MAPPING — these turned out to exist in the dev/test
  database but not in real production when compared directly on 2026-08-27;
  see that file's header for the risk note on the EMPLOYEE.ISDRIVER column add),
  AND 005_delivery_entry.sql's objects (Delivery Entry — see that file's
  header for the DELIVERY_DETAILS no-IDENTITY design note), AND
  006_delivery_tranno_seed.sql's fix (a DELIVERY row was missing from
  dbo.TRANSACTIONS for the active location, so DELIVERYNO generation
  returned NULL until seeded — see that file's header) — sections 8 and 9
  below cover both DELIVERY's and TRIPENTRY's numbering the same way,
  deriving each location's fiscal-year suffix from its own SALESORDER row
  rather than hardcoding one (a database can be on a different fiscal
  year than the one a hardcoded value was written against).

  Sections 10 and 11 below fold in 007_db_ams_erp_missing_tables.sql and
  008_tripentry_meter_precision_fix.sql respectively — both are existence-
  guarded (IF OBJECT_ID/IF NOT EXISTS), so they're safe to include
  unconditionally here: on a database that already has SITE/TRIPENTRY/
  TRIPENTRY_DETAILS in active use (e.g. DB_AMS_ERP_SMS, which already had
  10 real Trip Entry records at the time this was written), those CREATEs
  are skipped and only the genuinely missing pieces (DELIVERY_DETAILS,
  SALESORDER_DETAILS.DELIVERYQTY, the METERSTART/METERCLOSE precision
  fix) are applied; on a database with none of it at all (e.g. db_ams_erp),
  everything gets created fresh with the corrected NUMERIC(18,1) already
  baked in, so section 11 is simply a no-op there.

  NOT included here (run separately — see its own header):
  010_db_ams_erp_delivery_shortname_fix.sql, needed ONLY on db_ams_erp
  specifically — an earlier run of this script's section 8 (before it
  derived the fiscal year dynamically) inserted DELIVERY's row there with
  a hardcoded '25-26/' suffix while every other transaction type on that
  database is '26-27/'. This is a one-off correction for a mistake, not a
  general prerequisite, so it isn't folded in here.

  016_current_date_entrydate.sql originally made SP_MOBILE_CREATE_SALESORDER/
  TRIPENTRY/DELIVERY read the desktop app's "business date" from
  dbo.CHANGE_DATE for ENTRYDATE/ENTRYDATE/DELIVERDATE — this was ROLLED
  BACK by 021_rollback_changedate_for_entries.sql (see that file's header):
  all three now use GETDATE() again, since CHANGE_DATE could sit days
  behind the real date and caused more confusion than it solved for these
  three tables. dbo.CHANGE_DATE itself is untouched and still exists —
  Payment Entry's PAYMENTDATE (017_payment_details.sql) still reads it,
  that wasn't part of this rollback. TRIPDATE remains exactly what the
  rep entered, as it always has.

  Also folds in 017_payment_details.sql (see that file's header): a new
  dbo.PAYMENT_DETAILS table plus SP_MOBILE_CREATE_PAYMENT and
  SP_MOBILE_GET_CUSTOMER_LEDGER, backing a new Payment Entry screen and
  customer ledger report (Delivery/Payment rows with a running Outstanding
  Amount, derived — not stored — from DELIVERY_DETAILS + PAYMENT_DETAILS).

  Also folds in 018_salesorder_siteid.sql (see that file's header):
  SALESORDER.SITEID (new column, mirrors TRIPENTRY.SITEID) is now saved
  by SP_MOBILE_CREATE_SALESORDER alongside the existing SHIPPINGADDRESS
  text snapshot, so the Sales Order screen's site picker has a real
  reference back to dbo.SITE, not just free text.

  Also folds in 019_delivery_details_siteid.sql (see that file's header):
  DELIVERY_DETAILS.SITEID (new column, same convention) is now saved by
  SP_MOBILE_CREATE_DELIVERY, backing a Site picker on Delivery Entry
  scoped to the selected customer, same as Sales Order's.

  Also folds in 022_area_master.sql (see that file's header): dbo.AREA
  already existed by hand on db_ams_pos_test with real data and its own
  PascalCase schema (AreaId/AreaName/CityId/IsActive/CreatedOn/CreatedBy/
  UpdatedOn/UpdatedBy) — NOT this project's usual ALLCAPS convention —
  so this matches that shape exactly rather than inventing a different
  one, and only creates it where missing (real prod). Plus SITE.AREAID,
  so the Site form's Area field is a picker sourced from dbo.AREA
  (scoped to the site's own City) instead of free text.

  Also folds in 023_payment_type.sql (see that file's header):
  PAYMENT_DETAILS.PAYMENTTYPE (new column, defaults to 'Cash') captures
  the Payment Entry screen's new Payment Type selector (Cash/UPI/Acc
  Transfer) and is now saved by SP_MOBILE_CREATE_PAYMENT.

  Also folds in 020_salesorder_discount.sql (see that file's header):
  dbo.TVP_MOBILE_SALESORDER_LINES gets a new DISCOUNTAMOUNT column (a
  flat, tax-exclusive, per-line amount from the Sales Order screen's new
  Discount checkbox) and SP_MOBILE_CREATE_SALESORDER now computes tax on
  the post-discount amount instead of the raw RATE*QTY. Table-valued
  parameter TYPEs can't be ALTERed, only dropped and recreated — section 1
  above already does that unconditionally on every run, so no separate
  guard is needed here the way a plain table column would need one.

  Prerequisites (must already exist in the target database before running
  this — all pre-existing desktop-app objects, not created by this script):
    Tables: USERS, EMPLOYEE, LOCATION, BRANCH, CUSTOMER, CITY, PRODUCT,
            PRODUCTGROUP, BRAND, TYPE, SALESORDER, SALESORDER_DETAILS,
            COMPANY, TRANSACTIONS, SITE, VEHICLE, TRIPENTRY, TRIPENTRY_DETAILS,
            DELIVERY_DETAILS
    Stored procedure: dbo.SP_GENERATETRANNO
    (PRODUCT_DETAILS and EMPLOYEE_VEHICLE_MAPPING moved out of this list —
    this script now creates them itself if missing, per 004.)
*/

------------------------------------------------------------
-- 1. Line-items table type (rep-editable RATE per line)
------------------------------------------------------------
IF OBJECT_ID(N'dbo.SP_MOBILE_CREATE_SALESORDER', N'P') IS NOT NULL
    DROP PROCEDURE dbo.SP_MOBILE_CREATE_SALESORDER;
GO

IF TYPE_ID(N'dbo.TVP_MOBILE_SALESORDER_LINES') IS NOT NULL
    DROP TYPE dbo.TVP_MOBILE_SALESORDER_LINES;
GO

CREATE TYPE dbo.TVP_MOBILE_SALESORDER_LINES AS TABLE
(
    PRODUCTID       INT           NOT NULL,
    QTY             NUMERIC(18,3) NOT NULL,
    RATE            NUMERIC(18,2) NOT NULL,  -- rep-editable, defaults to PRODUCT.MRP client-side
    DISCOUNTAMOUNT  NUMERIC(18,2) NOT NULL   -- flat, tax-exclusive; 0 when the line's Discount checkbox is off
);
GO

------------------------------------------------------------
-- 2. Refresh-token store (backs "skip login next time")
------------------------------------------------------------
IF OBJECT_ID(N'dbo.MOBILE_REFRESH_TOKENS', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.MOBILE_REFRESH_TOKENS
    (
        TOKENID    INT IDENTITY(1,1) PRIMARY KEY,
        USERID     INT          NOT NULL,   -- dbo.USERS has no PK/unique constraint, so no FK
        DEVICEID   VARCHAR(100) NOT NULL,
        TOKENHASH  VARCHAR(200) NOT NULL,
        ISSUEDAT   DATETIME     NOT NULL DEFAULT GETDATE(),
        EXPIRESAT  DATETIME     NOT NULL,
        REVOKEDAT  DATETIME     NULL
    );
    CREATE INDEX IX_MOBILE_REFRESH_TOKENS_TOKENHASH ON dbo.MOBILE_REFRESH_TOKENS(TOKENHASH);
END
GO

------------------------------------------------------------
-- 3. OTP store (first-time mobile login verification)
------------------------------------------------------------
IF OBJECT_ID(N'dbo.MOBILE_OTP', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.MOBILE_OTP
    (
        OTPID     INT IDENTITY(1,1) PRIMARY KEY,
        USERID    INT         NOT NULL,   -- dbo.USERS has no PK/unique constraint, so no FK
        OTP       VARCHAR(10) NOT NULL,
        MOBILENO  VARCHAR(20) NOT NULL,
        EXPIRESAT DATETIME    NOT NULL,
        CONSUMED  BIT         NOT NULL DEFAULT 0,
        CREATEDAT DATETIME    NOT NULL DEFAULT GETDATE()
    );
    CREATE INDEX IX_MOBILE_OTP_USERID ON dbo.MOBILE_OTP(USERID);
END
GO

-- PRODUCTDETAILID prerequisite for section 4's proc below (full context
-- in section 12 near the end of this file, which repeats this idempotent
-- check — harmless — since column references, unlike table references,
-- are validated immediately at CREATE PROCEDURE time against whatever
-- the table's current shape is, not deferred).
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'PRODUCT_DETAILS' AND COLUMN_NAME = 'PRODUCTDETAILID'
)
BEGIN
    ALTER TABLE dbo.PRODUCT_DETAILS ADD PRODUCTDETAILID INT IDENTITY(1,1);
END
GO

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'SALESORDER_DETAILS' AND COLUMN_NAME = 'PRODUCTDETAILID'
)
BEGIN
    ALTER TABLE dbo.SALESORDER_DETAILS
        ADD PRODUCTDETAILID INT NOT NULL CONSTRAINT DF_SALESORDER_DETAILS_PRODUCTDETAILID DEFAULT 0;
END
GO

-- CHANGE_DATE / DELIVERY_DETAILS.DELIVERDATE prerequisites for sections 4,
-- 5, and 7's procs below (all three now read the business "current date"
-- from CHANGE_DATE for ENTRYDATE/DELIVERDATE instead of GETDATE() — see
-- 016_current_date_entrydate.sql's header for the full story). CHANGE_DATE
-- already existed by hand on db_ams_erp/DB_AMS_ERP_SMS as a legacy
-- single-row "business date" table the desktop app uses (its ENTRYDATE
-- can be a day or more behind the wall clock until a "day close" is run);
-- this creates + seeds it only where it's genuinely missing.
IF OBJECT_ID(N'dbo.CHANGE_DATE', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.CHANGE_DATE
    (
        CHANGEDATEID       INT IDENTITY(1,1) NOT NULL,
        CURRENTDATE        DATETIME NULL,
        LASTMODIFYEDUSERID INT      NOT NULL CONSTRAINT DF_CHANGE_DATE_LASTMODIFYEDUSERID DEFAULT 0,
        LASTMODIFYEDDATE   DATETIME NULL,
        CREATEDEMPLOYEEID  INT      NOT NULL CONSTRAINT DF_CHANGE_DATE_CREATEDEMPLOYEEID DEFAULT 0,
        MODIFYEDEMPLOYEEID INT      NOT NULL CONSTRAINT DF_CHANGE_DATE_MODIFYEDEMPLOYEEID DEFAULT 0
    );
    INSERT INTO dbo.CHANGE_DATE (CURRENTDATE, LASTMODIFYEDUSERID, LASTMODIFYEDDATE, CREATEDEMPLOYEEID, MODIFYEDEMPLOYEEID)
    VALUES (GETDATE(), 0, GETDATE(), 0, 0);
END
GO

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'DELIVERY_DETAILS' AND COLUMN_NAME = 'DELIVERDATE'
)
BEGIN
    ALTER TABLE dbo.DELIVERY_DETAILS
        ADD DELIVERDATE DATETIME NOT NULL CONSTRAINT DF_DELIVERY_DETAILS_DELIVERDATE DEFAULT GETDATE();
END
GO

-- SALESORDER.SITEID (folded in from 018_salesorder_siteid.sql — see that
-- file's header) must exist before SP_MOBILE_CREATE_SALESORDER's CREATE
-- PROCEDURE below, same deferred-name-resolution reason as every other
-- prerequisite guard in this section: a column reference on an existing
-- table is validated immediately, not deferred, at CREATE PROCEDURE time.
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'SALESORDER' AND COLUMN_NAME = 'SITEID'
)
BEGIN
    ALTER TABLE dbo.SALESORDER
        ADD SITEID INT NOT NULL CONSTRAINT DF_SALESORDER_SITEID DEFAULT 0;
END
GO

------------------------------------------------------------
-- 4. Sales-order creation proc (final version)
--    Writes ONLY to dbo.SALESORDER / dbo.SALESORDER_DETAILS.
--    Never touches dbo.STOCK_DETAILS or dbo.SALES / dbo.SALES_DETAILS.
--    Prices off dbo.PRODUCT (MRP, tax %) — RATE is rep-editable and
--    trusted from the client; tax % is always re-derived server-side.
--    DISCOUNTAMOUNT is a flat, tax-exclusive, per-line amount (the
--    mobile app's Discount checkbox) subtracted from RATE*QTY before
--    tax — LINETAXABLE clamps at 0 so a discount can never make a line
--    negative. GROSSAMOUNT (RATE*QTY, pre-discount) is still stored on
--    SALESORDER_DETAILS alongside the applied DISCOUNTAMOUNT and the
--    resulting (post-discount) TAXABLEVALUE, same relationship at the
--    SALESORDER header level (ITEMVALUE = gross, TAXABLEVALUE = net).
------------------------------------------------------------
CREATE PROCEDURE dbo.SP_MOBILE_CREATE_SALESORDER
(
    @LOCATIONID        INT,
    @CUSTOMERID        INT,
    @CUSTOMERNAME      VARCHAR(100),
    @MOBILENO          VARCHAR(50),
    @SHIPPINGADDRESS   VARCHAR(500),
    @SITEID            INT = 0,
    @CREATEDUSERID     INT,
    @CREATEDEMPLOYEEID INT,
    @LINES             dbo.TVP_MOBILE_SALESORDER_LINES READONLY,
    @SALESORDERID      INT           OUTPUT,
    @ENTRYNO           VARCHAR(MAX)  OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM @LINES)
    BEGIN
        RAISERROR('At least one line item is required.', 16, 1);
        RETURN;
    END

    IF OBJECT_ID('tempdb..#LinePricing') IS NOT NULL DROP TABLE #LinePricing;

    SELECT
        L.PRODUCTID, L.QTY, L.RATE, L.DISCOUNTAMOUNT,
        PR.MRP, PR.HSNCODE, PR.BRANDID, PR.TYPEID, PR.UOMID,
        ISNULL(PR.SALESCGSTPERCENTAGE, 0) AS SALESCGSTPERCENTAGE,
        ISNULL(PR.SALESSGSTPERCENTAGE, 0) AS SALESSGSTPERCENTAGE,
        ISNULL(PR.SALESIGSTPERCENTAGE, 0) AS SALESIGSTPERCENTAGE,
        ISNULL(PD.PRODUCTDETAILID, 0) AS PRODUCTDETAILID,
        CASE WHEN (L.RATE * L.QTY - L.DISCOUNTAMOUNT) < 0 THEN 0 ELSE (L.RATE * L.QTY - L.DISCOUNTAMOUNT) END AS LINETAXABLE
    INTO #LinePricing
    FROM @LINES L
    INNER JOIN dbo.PRODUCT PR ON PR.PRODUCTID = L.PRODUCTID
    OUTER APPLY (
        -- TOP 1 (not a plain JOIN) so a product with more than one
        -- "current" PRODUCT_DETAILS row (shouldn't happen, but see
        -- 013_product_price_history.sql) can never fan out this line
        -- into duplicates — picks the most recently created one instead.
        SELECT TOP 1 PDI.PRODUCTDETAILID
        FROM dbo.PRODUCT_DETAILS PDI
        WHERE PDI.PRODUCTID = L.PRODUCTID AND PDI.VALID_END_DATE IS NULL AND PDI.VALID = 1
        ORDER BY PDI.PRODUCTDETAILID DESC
    ) PD;

    IF (SELECT COUNT(*) FROM #LinePricing) <> (SELECT COUNT(*) FROM @LINES)
    BEGIN
        RAISERROR('One or more products no longer exist.', 16, 1);
        DROP TABLE #LinePricing;
        RETURN;
    END

    BEGIN TRANSACTION;

    BEGIN TRY
        EXEC dbo.SP_GENERATETRANNO
             @TRANSACTIONNAME = 'SALESORDER',
             @TRANNO = @ENTRYNO OUTPUT,
             @USERSHORTNAME = '',
             @LOCATIONID = @LOCATIONID;

        -- ENTRYDATE uses the wall clock (GETDATE()) — rolled back from
        -- dbo.CHANGE_DATE (see 021_rollback_changedate_for_entries.sql):
        -- the desktop "business date" could sit days behind the real date,
        -- which caused more confusion than it solved for this table.
        DECLARE @RawNetAmount NUMERIC(18,2), @RoundedNetAmount NUMERIC(18,2);

        SELECT @RawNetAmount = SUM(LINETAXABLE)
                              + SUM(ROUND(LINETAXABLE * (SALESCGSTPERCENTAGE + SALESSGSTPERCENTAGE + SALESIGSTPERCENTAGE) / 100.0, 2))
        FROM #LinePricing;

        SET @RoundedNetAmount = ROUND(@RawNetAmount, 0);

        INSERT INTO dbo.SALESORDER
            (ENTRYNO, ENTRYDATE, LOCATIONID, COUNTERID, MOBILENO, CUSTOMERID, PAYMENTMODE,
             TAXABLEVALUE, TOTALTAX, ITEMVALUE, DISCOUNTPERCENTAGE, DISCOUNTAMOUNT, ROUNDOFF, NETAMOUNT,
             SELECTRATE, CASHAMOUNT, CARDAMOUNT, RECEIVEDAMOUNT, REFUNDAMOUNT, SETTLEMENT, SETTLEMENTID, PAYMENT,
             CANCELUSERID, CANCELID, CANCEL, CREATEDLOCATIONID, MODIFYEDLOCATIONID, CREATEDUSERID, LASTMODIFYEDUSERID,
             USERCREATEDDATE, LASTMODIFYEDDATE, CREATEDEMPLOYEEID, MODIFYEDEMPLOYEEID,
             SHIPPINGADDRESS, CUSTOMERNAME, OrderDate, SITEID)
        SELECT
            @ENTRYNO, GETDATE(), @LOCATIONID, 0, @MOBILENO, @CUSTOMERID, 'PENDING',
            SUM(LINETAXABLE), SUM(ROUND(LINETAXABLE * (SALESCGSTPERCENTAGE + SALESSGSTPERCENTAGE + SALESIGSTPERCENTAGE) / 100.0, 2)),
            SUM(RATE * QTY), 0, SUM(RATE * QTY - LINETAXABLE), (@RoundedNetAmount - @RawNetAmount), @RoundedNetAmount,
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, @LOCATIONID, @LOCATIONID, @CREATEDUSERID, @CREATEDUSERID,
            GETDATE(), GETDATE(), @CREATEDEMPLOYEEID, @CREATEDEMPLOYEEID,
            @SHIPPINGADDRESS, @CUSTOMERNAME, CAST(GETDATE() AS DATE), @SITEID
        FROM #LinePricing;

        SET @SALESORDERID = SCOPE_IDENTITY();

        INSERT INTO dbo.SALESORDER_DETAILS
            (SALESORDERID, COMPANYID, COUNTERID, BARCODE, PRODUCTID, PRODUCTCODE, HSNCODE, BRANDID, TYPEID, UOMID,
             WEIGHT, QTY, MRP, RATE, GROSSAMOUNT, DISCOUNTPERCENTAGE, DISCOUNTAMOUNT, OTHERDISCOUNTAMOUNT,
             TAXABLEVALUE, CGSTPERCENTAGE, CGSTAMOUNT, SGSTPERCENTAGE, SGSTAMOUNT, IGSTPERCENTAGE, IGSTAMOUNT,
             TOTALTAX, PERRATE, PRATE, PTAX, TOTALAMOUNT, STOCKQTY, MFGDATE, EXPDATE, ENTRYID,
             PERPOINTS, SALESPOINTS, FREEITEM, SALESQTY, PRODUCTDETAILID)
        SELECT
            @SALESORDERID, 1, 0, '', PRODUCTID, '', HSNCODE, BRANDID, TYPEID, UOMID,
            0, QTY, MRP, RATE, RATE * QTY, 0, (RATE * QTY - LINETAXABLE), 0,
            LINETAXABLE,
            SALESCGSTPERCENTAGE, ROUND(LINETAXABLE * SALESCGSTPERCENTAGE / 100.0, 2),
            SALESSGSTPERCENTAGE, ROUND(LINETAXABLE * SALESSGSTPERCENTAGE / 100.0, 2),
            SALESIGSTPERCENTAGE, ROUND(LINETAXABLE * SALESIGSTPERCENTAGE / 100.0, 2),
            ROUND(LINETAXABLE * (SALESCGSTPERCENTAGE + SALESSGSTPERCENTAGE + SALESIGSTPERCENTAGE) / 100.0, 2),
            RATE, 0, 0,
            LINETAXABLE + ROUND(LINETAXABLE * (SALESCGSTPERCENTAGE + SALESSGSTPERCENTAGE + SALESIGSTPERCENTAGE) / 100.0, 2),
            0, NULL, NULL, 0,
            0, 0, 0, QTY, PRODUCTDETAILID
        FROM #LinePricing;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DROP TABLE IF EXISTS #LinePricing;
        THROW;
    END CATCH

    DROP TABLE #LinePricing;
END
GO

------------------------------------------------------------
-- 5. Trip Entry — mobile equipment-hire billing (see 003_trip_entry.sql
--    for the full header note on the METERORHOURSID convention).
--    Writes ONLY to dbo.TRIPENTRY / dbo.TRIPENTRY_DETAILS.
------------------------------------------------------------
IF OBJECT_ID(N'dbo.SP_MOBILE_CREATE_TRIPENTRY', N'P') IS NOT NULL
    DROP PROCEDURE dbo.SP_MOBILE_CREATE_TRIPENTRY;
GO

IF TYPE_ID(N'dbo.TVP_MOBILE_TRIPENTRY_LINES') IS NOT NULL
    DROP TYPE dbo.TVP_MOBILE_TRIPENTRY_LINES;
GO

CREATE TYPE dbo.TVP_MOBILE_TRIPENTRY_LINES AS TABLE
(
    PRODUCTID      INT           NOT NULL,
    METERORHOURSID INT           NOT NULL,   -- 1 = Hours, 2 = Meter
    TIMESTART      DATETIME      NULL,       -- set when METERORHOURSID = 1
    TIMECLOSE      DATETIME      NULL,
    METERSTART     NUMERIC(18,3) NULL,       -- set when METERORHOURSID = 2
    METERCLOSE     NUMERIC(18,3) NULL,
    VEHICLEID      INT           NULL,
    QTY            NUMERIC(18,3) NOT NULL,
    RATE           NUMERIC(18,2) NOT NULL
);
GO

CREATE PROCEDURE dbo.SP_MOBILE_CREATE_TRIPENTRY
(
    @LOCATIONID        INT,
    @CUSTOMERID        INT,
    @MOBILENO          VARCHAR(50),
    @SITEID            INT,
    @EMPLOYEEID        INT,           -- driver
    @TRIPNO            NVARCHAR(100),
    @TRIPDATE          DATETIME,
    @CREATEDUSERID     INT,
    @CREATEDEMPLOYEEID INT,
    @LINES             dbo.TVP_MOBILE_TRIPENTRY_LINES READONLY,
    @TRIPENTRYID       INT           OUTPUT,
    @ENTRYNO           VARCHAR(MAX)  OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM @LINES)
    BEGIN
        RAISERROR('At least one line item is required.', 16, 1);
        RETURN;
    END

    DECLARE @SITENAME VARCHAR(100);
    SELECT @SITENAME = SITENAME FROM dbo.SITE WHERE SITEID = @SITEID AND STATUS = 1;
    IF @SITENAME IS NULL
    BEGIN
        RAISERROR('Site not found.', 16, 1);
        RETURN;
    END

    IF OBJECT_ID('tempdb..#LinePricing') IS NOT NULL DROP TABLE #LinePricing;

    SELECT
        L.PRODUCTID, L.METERORHOURSID, L.TIMESTART, L.TIMECLOSE, L.METERSTART, L.METERCLOSE,
        L.VEHICLEID, L.QTY, L.RATE,
        PR.MRP, PR.HSNCODE, PR.BRANDID, PR.TYPEID, PR.UOMID,
        ISNULL(PR.SALESCGSTPERCENTAGE, 0) AS SALESCGSTPERCENTAGE,
        ISNULL(PR.SALESSGSTPERCENTAGE, 0) AS SALESSGSTPERCENTAGE,
        ISNULL(PR.SALESIGSTPERCENTAGE, 0) AS SALESIGSTPERCENTAGE
    INTO #LinePricing
    FROM @LINES L
    INNER JOIN dbo.PRODUCT PR ON PR.PRODUCTID = L.PRODUCTID;

    IF (SELECT COUNT(*) FROM #LinePricing) <> (SELECT COUNT(*) FROM @LINES)
    BEGIN
        RAISERROR('One or more products no longer exist.', 16, 1);
        DROP TABLE #LinePricing;
        RETURN;
    END

    BEGIN TRANSACTION;

    BEGIN TRY
        EXEC dbo.SP_GENERATETRANNO
             @TRANSACTIONNAME = 'TRIPENTRY',
             @TRANNO = @ENTRYNO OUTPUT,
             @USERSHORTNAME = '',
             @LOCATIONID = @LOCATIONID;

        -- ENTRYDATE uses the wall clock (GETDATE()) — rolled back from
        -- dbo.CHANGE_DATE (see 021_rollback_changedate_for_entries.sql).
        -- TRIPDATE stays exactly as the rep entered it (@TRIPDATE, below)
        -- — this was never tied to CHANGE_DATE and isn't part of the
        -- rollback.
        DECLARE @TripRawNetAmount NUMERIC(18,2), @TripRoundedNetAmount NUMERIC(18,2);

        SELECT @TripRawNetAmount = SUM(RATE * QTY)
                                   + SUM(ROUND(RATE * QTY * (SALESCGSTPERCENTAGE + SALESSGSTPERCENTAGE + SALESIGSTPERCENTAGE) / 100.0, 2))
        FROM #LinePricing;

        SET @TripRoundedNetAmount = ROUND(@TripRawNetAmount, 0);

        INSERT INTO dbo.TRIPENTRY
            (ENTRYNO, ENTRYDATE, LOCATIONID, COUNTERID, MOBILENO, CUSTOMERID, EMPLOYEEID, SITENAME,
             TAXABLEVALUE, TOTALTAX, ITEMVALUE, ROUNDOFF, NETAMOUNT, SELECTRATE,
             CANCELUSERID, CANCELID, CANCEL, CANCELDATETIME,
             CREATEDLOCATIONID, MODIFYEDLOCATIONID, CREATEDUSERID, LASTMODIFYEDUSERID,
             USERCREATEDDATE, LASTMODIFYEDDATE, CREATEDEMPLOYEEID, MODIFYEDEMPLOYEEID,
             SITEID, TRIPNO, TRIPDATE, CONVERTTOSALES)
        SELECT
            @ENTRYNO, GETDATE(), @LOCATIONID, 0, @MOBILENO, @CUSTOMERID, @EMPLOYEEID, @SITENAME,
            SUM(RATE * QTY), SUM(ROUND(RATE * QTY * (SALESCGSTPERCENTAGE + SALESSGSTPERCENTAGE + SALESIGSTPERCENTAGE) / 100.0, 2)),
            SUM(RATE * QTY), (@TripRoundedNetAmount - @TripRawNetAmount), @TripRoundedNetAmount, 0,
            0, 0, 0, NULL,
            @LOCATIONID, @LOCATIONID, @CREATEDUSERID, @CREATEDUSERID,
            GETDATE(), GETDATE(), @CREATEDEMPLOYEEID, @CREATEDEMPLOYEEID,
            @SITEID, @TRIPNO, @TRIPDATE, 0
        FROM #LinePricing;

        SET @TRIPENTRYID = SCOPE_IDENTITY();

        INSERT INTO dbo.TRIPENTRY_DETAILS
            (TRIPENTRYID, COMPANYID, COUNTERID, PRODUCTID, PRODUCTCODE, HSNCODE, BRANDID, TYPEID, UOMID,
             WEIGHT, QTY, MRP, RATE, GROSSAMOUNT,
             TAXABLEVALUE, CGSTPERCENTAGE, CGSTAMOUNT, SGSTPERCENTAGE, SGSTAMOUNT, IGSTPERCENTAGE, IGSTAMOUNT,
             TOTALTAX, PERRATE, PRATE, TOTALAMOUNT, ENTRYID,
             METERORHOURSID, TIMESTART, TIMECLOSE, METERSTART, METERCLOSE, VEHICLEID)
        SELECT
            @TRIPENTRYID, 1, 0, PRODUCTID, '', HSNCODE, BRANDID, TYPEID, UOMID,
            0, QTY, MRP, RATE, RATE * QTY,
            RATE * QTY,
            SALESCGSTPERCENTAGE, ROUND(RATE * QTY * SALESCGSTPERCENTAGE / 100.0, 2),
            SALESSGSTPERCENTAGE, ROUND(RATE * QTY * SALESSGSTPERCENTAGE / 100.0, 2),
            SALESIGSTPERCENTAGE, ROUND(RATE * QTY * SALESIGSTPERCENTAGE / 100.0, 2),
            ROUND(RATE * QTY * (SALESCGSTPERCENTAGE + SALESSGSTPERCENTAGE + SALESIGSTPERCENTAGE) / 100.0, 2),
            RATE, 0,
            RATE * QTY + ROUND(RATE * QTY * (SALESCGSTPERCENTAGE + SALESSGSTPERCENTAGE + SALESIGSTPERCENTAGE) / 100.0, 2),
            0,
            METERORHOURSID, TIMESTART, TIMECLOSE, METERSTART, METERCLOSE, VEHICLEID
        FROM #LinePricing;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DROP TABLE IF EXISTS #LinePricing;
        THROW;
    END CATCH

    DROP TABLE #LinePricing;
END
GO

------------------------------------------------------------
-- 6. Go-live prerequisites (see 004_prod_prerequisites.sql for the full
--    risk note on the EMPLOYEE.ISDRIVER column add). These three objects
--    exist in the dev/test database but were found missing from real
--    production when compared directly on 2026-08-27.
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

IF OBJECT_ID(N'dbo.PRODUCT_DETAILS', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PRODUCT_DETAILS
    (
        PRODUCTDETAILID  INT IDENTITY(1,1) NOT NULL,
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

-- DELIVERY_DETAILS.SITEID (folded in from 019_delivery_details_siteid.sql
-- — see that file's header) must exist before SP_MOBILE_CREATE_DELIVERY's
-- CREATE PROCEDURE below, same deferred-name-resolution reason as every
-- other prerequisite guard in this script.
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'DELIVERY_DETAILS' AND COLUMN_NAME = 'SITEID'
)
BEGIN
    ALTER TABLE dbo.DELIVERY_DETAILS
        ADD SITEID INT NOT NULL CONSTRAINT DF_DELIVERY_DETAILS_SITEID DEFAULT 0;
END
GO

------------------------------------------------------------
-- 7. Delivery Entry (see 005_delivery_entry.sql for the full design note —
--    DELIVERY_DETAILS has no IDENTITY/PK, IDs are generated via a locked
--    MAX+1, same idiom SP_GENERATETRANNO already uses for TRANSACTIONS).
------------------------------------------------------------
IF OBJECT_ID(N'dbo.SP_MOBILE_CREATE_DELIVERY', N'P') IS NOT NULL
    DROP PROCEDURE dbo.SP_MOBILE_CREATE_DELIVERY;
GO

IF TYPE_ID(N'dbo.TVP_MOBILE_DELIVERY_LINES') IS NOT NULL
    DROP TYPE dbo.TVP_MOBILE_DELIVERY_LINES;
GO

CREATE TYPE dbo.TVP_MOBILE_DELIVERY_LINES AS TABLE
(
    SALESORDERDETID INT           NOT NULL,
    SALESORDERID    INT           NOT NULL,
    PRODUCTID       INT           NOT NULL,
    DELIVERYQTY     NUMERIC(18,3) NOT NULL
);
GO

CREATE PROCEDURE dbo.SP_MOBILE_CREATE_DELIVERY
(
    @LOCATIONID    INT,
    @DRIVERID      INT,
    @VEHICLENUMBER VARCHAR(50),
    @SITEID        INT = 0,
    @CREATEUSER    VARCHAR(50),
    @LINES         dbo.TVP_MOBILE_DELIVERY_LINES READONLY,
    @DELIVERYNO    VARCHAR(MAX) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM @LINES)
    BEGIN
        RAISERROR('At least one line item is required.', 16, 1);
        RETURN;
    END

    BEGIN TRANSACTION;

    BEGIN TRY
        IF OBJECT_ID('tempdb..#DeliveryLines') IS NOT NULL DROP TABLE #DeliveryLines;

        SELECT
            L.SALESORDERDETID, L.SALESORDERID, L.PRODUCTID, L.DELIVERYQTY AS CURRENTDELIVERY,
            SOD.SALESQTY, SOD.DELIVERYQTY AS ALREADYDELIVERED
        INTO #DeliveryLines
        FROM @LINES L
        INNER JOIN dbo.SALESORDER_DETAILS SOD WITH (UPDLOCK, HOLDLOCK) ON SOD.SALESORDERDETID = L.SALESORDERDETID
        INNER JOIN dbo.SALESORDER SO ON SO.SALESORDERID = SOD.SALESORDERID
        WHERE SO.LOCATIONID = @LOCATIONID AND SO.CANCEL = 0;

        IF (SELECT COUNT(*) FROM #DeliveryLines) <> (SELECT COUNT(*) FROM @LINES)
        BEGIN
            RAISERROR('One or more sales order lines no longer exist or belong to a different location.', 16, 1);
            DROP TABLE #DeliveryLines;
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM #DeliveryLines WHERE CURRENTDELIVERY <= 0)
        BEGIN
            RAISERROR('Delivery quantity must be greater than zero.', 16, 1);
            DROP TABLE #DeliveryLines;
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM #DeliveryLines WHERE CURRENTDELIVERY > (SALESQTY - ALREADYDELIVERED))
        BEGIN
            RAISERROR('One or more lines exceed their remaining balance quantity - someone may have already delivered part of this order. Refresh and try again.', 16, 1);
            DROP TABLE #DeliveryLines;
            ROLLBACK TRANSACTION;
            RETURN;
        END

        EXEC dbo.SP_GENERATETRANNO
             @TRANSACTIONNAME = 'DELIVERY',
             @TRANNO = @DELIVERYNO OUTPUT,
             @USERSHORTNAME = '',
             @LOCATIONID = @LOCATIONID;

        -- DELIVERDATE uses the wall clock (GETDATE()) — rolled back from
        -- dbo.CHANGE_DATE (see 021_rollback_changedate_for_entries.sql).
        DECLARE @NextId INT;
        SELECT @NextId = ISNULL(MAX(DELIVERYID), 0) FROM dbo.DELIVERY_DETAILS WITH (TABLOCKX, HOLDLOCK);

        ;WITH Numbered AS (
            SELECT *, ROW_NUMBER() OVER (ORDER BY SALESORDERDETID) AS RN
            FROM #DeliveryLines
        )
        INSERT INTO dbo.DELIVERY_DETAILS
            (DELIVERYID, DELIVERYNO, SALESORDERID, SALESORDERDETID, PRODUCTID, DELIVERYQTY, BALANCEQTY,
             DRIVERID, VEHICLENUMBER, DELIVERDATE, CREATE_DATE, CREATE_USER, SITEID)
        SELECT
            @NextId + RN, @DELIVERYNO, SALESORDERID, SALESORDERDETID, PRODUCTID, CURRENTDELIVERY,
            (SALESQTY - ALREADYDELIVERED - CURRENTDELIVERY),
            @DRIVERID, @VEHICLENUMBER, GETDATE(), GETDATE(), @CREATEUSER, @SITEID
        FROM Numbered;

        UPDATE SOD
        SET SOD.DELIVERYQTY = SOD.DELIVERYQTY + DL.CURRENTDELIVERY
        FROM dbo.SALESORDER_DETAILS SOD
        INNER JOIN #DeliveryLines DL ON DL.SALESORDERDETID = SOD.SALESORDERDETID;

        DROP TABLE #DeliveryLines;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DROP TABLE IF EXISTS #DeliveryLines;
        THROW;
    END CATCH
END
GO

------------------------------------------------------------
-- 8. Delivery numbering prerequisite (see 006_delivery_tranno_seed.sql) —
--    dbo.TRANSACTIONS needs a NAME='DELIVERY' row for EVERY location, or
--    SP_GENERATETRANNO's location-scoped lookup silently returns NULL.
--    Fiscal-year suffix is derived from each location's own SALESORDER
--    row rather than hardcoded — see 006's header for why (a hardcoded
--    value produced a wrongly-stamped row on a database using a
--    different fiscal year than the one this script was first written
--    against).
------------------------------------------------------------
;WITH DeliveryFiscalSuffix AS (
    SELECT LOCATIONID, SUBSTRING(SHORTNAME, CHARINDEX('/', SHORTNAME) + 1, LEN(SHORTNAME)) AS Suffix
    FROM dbo.TRANSACTIONS
    WHERE NAME = 'SALESORDER'
)
INSERT INTO dbo.TRANSACTIONS (NAME, SHORTNAME, LOCATIONID, LASTNO)
SELECT 'DELIVERY', 'DLV/' + FS.Suffix, FS.LOCATIONID, 0
FROM DeliveryFiscalSuffix FS
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.TRANSACTIONS T
    WHERE T.NAME = 'DELIVERY' AND T.LOCATIONID = FS.LOCATIONID
);
GO

------------------------------------------------------------
-- 9. Trip Entry numbering prerequisite (see 009_tripentry_tranno_seed.sql) —
--    same idea as section 8, for NAME='TRIPENTRY'.
------------------------------------------------------------
;WITH TripEntryFiscalSuffix AS (
    SELECT LOCATIONID, SUBSTRING(SHORTNAME, CHARINDEX('/', SHORTNAME) + 1, LEN(SHORTNAME)) AS Suffix
    FROM dbo.TRANSACTIONS
    WHERE NAME = 'SALESORDER'
)
INSERT INTO dbo.TRANSACTIONS (NAME, SHORTNAME, LOCATIONID, LASTNO)
SELECT 'TRIPENTRY', 'TRI/' + FS.Suffix, FS.LOCATIONID, 0
FROM TripEntryFiscalSuffix FS
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.TRANSACTIONS T
    WHERE T.NAME = 'TRIPENTRY' AND T.LOCATIONID = FS.LOCATIONID
);
GO

------------------------------------------------------------
-- 10. Desktop tables the mobile app needs but some databases never had
--     added at all (folded in from 007_db_ams_erp_missing_tables.sql —
--     see that file's header for the full story and where each table's
--     shape was reverse-engineered from). Every piece here is existence-
--     guarded, so this is a no-op wherever it already exists.
------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'SALESORDER_DETAILS' AND COLUMN_NAME = 'DELIVERYQTY'
)
BEGIN
    ALTER TABLE dbo.SALESORDER_DETAILS
        ADD DELIVERYQTY INT NOT NULL CONSTRAINT DF_SALESORDER_DETAILS_DELIVERYQTY DEFAULT 0;
END
GO

IF OBJECT_ID(N'dbo.SITE', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SITE
    (
        SITEID              INT IDENTITY(1,1) NOT NULL,
        SITENAME            VARCHAR(50)  NULL,
        AREANAME            VARCHAR(50)  NULL,
        CITYID              INT          NOT NULL CONSTRAINT DF_SITE_CITYID DEFAULT 0,
        STATUS              BIT          NOT NULL CONSTRAINT DF_SITE_STATUS DEFAULT 0,
        CUSTOMERID          INT          NOT NULL,
        CREATEDLOCATIONID   INT          NOT NULL CONSTRAINT DF_SITE_CREATEDLOCATIONID DEFAULT 0,
        MODIFYEDLOCATIONID  INT          NOT NULL CONSTRAINT DF_SITE_MODIFYEDLOCATIONID DEFAULT 0,
        CREATEDUSERID       INT          NOT NULL CONSTRAINT DF_SITE_CREATEDUSERID DEFAULT 0,
        LASTMODIFYEDUSERID  INT          NOT NULL CONSTRAINT DF_SITE_LASTMODIFYEDUSERID DEFAULT 0,
        USERCREATEDDATE     DATETIME     NULL,
        LASTMODIFYEDDATE    DATETIME     NULL,
        CREATEDEMPLOYEEID   INT          NOT NULL CONSTRAINT DF_SITE_CREATEDEMPLOYEEID DEFAULT 0,
        MODIFYEDEMPLOYEEID  INT          NOT NULL CONSTRAINT DF_SITE_MODIFYEDEMPLOYEEID DEFAULT 0
    );
END
GO

IF OBJECT_ID(N'dbo.TRIPENTRY', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TRIPENTRY
    (
        TRIPENTRYID         INT IDENTITY(1,1) NOT NULL,
        ENTRYNO             VARCHAR(50)   NULL,
        ENTRYDATE           DATETIME      NULL,
        LOCATIONID          INT           NOT NULL CONSTRAINT DF_TRIPENTRY_LOCATIONID DEFAULT 0,
        COUNTERID           INT           NOT NULL CONSTRAINT DF_TRIPENTRY_COUNTERID DEFAULT 0,
        MOBILENO            VARCHAR(50)   NULL,
        CUSTOMERID          INT           NOT NULL CONSTRAINT DF_TRIPENTRY_CUSTOMERID DEFAULT 0,
        EMPLOYEEID          INT           NOT NULL,
        SITENAME            VARCHAR(500)  NULL,
        TAXABLEVALUE        NUMERIC(18,2) NOT NULL CONSTRAINT DF_TRIPENTRY_TAXABLEVALUE DEFAULT 0,
        TOTALTAX            NUMERIC(18,2) NOT NULL CONSTRAINT DF_TRIPENTRY_TOTALTAX DEFAULT 0,
        ITEMVALUE           NUMERIC(18,2) NOT NULL CONSTRAINT DF_TRIPENTRY_ITEMVALUE DEFAULT 0,
        ROUNDOFF            NUMERIC(18,2) NOT NULL CONSTRAINT DF_TRIPENTRY_ROUNDOFF DEFAULT 0,
        NETAMOUNT           NUMERIC(18,2) NOT NULL CONSTRAINT DF_TRIPENTRY_NETAMOUNT DEFAULT 0,
        SELECTRATE          BIT           NOT NULL CONSTRAINT DF_TRIPENTRY_SELECTRATE DEFAULT 0,
        CANCELUSERID        INT           NOT NULL CONSTRAINT DF_TRIPENTRY_CANCELUSERID DEFAULT 0,
        CANCELID            INT           NOT NULL CONSTRAINT DF_TRIPENTRY_CANCELID DEFAULT 0,
        CANCEL              BIT           NOT NULL CONSTRAINT DF_TRIPENTRY_CANCEL DEFAULT 0,
        CANCELDATETIME      DATETIME      NULL,
        CREATEDLOCATIONID   INT           NOT NULL CONSTRAINT DF_TRIPENTRY_CREATEDLOCATIONID DEFAULT 0,
        MODIFYEDLOCATIONID  INT           NOT NULL CONSTRAINT DF_TRIPENTRY_MODIFYEDLOCATIONID DEFAULT 0,
        CREATEDUSERID       INT           NOT NULL CONSTRAINT DF_TRIPENTRY_CREATEDUSERID DEFAULT 0,
        LASTMODIFYEDUSERID  INT           NOT NULL CONSTRAINT DF_TRIPENTRY_LASTMODIFYEDUSERID DEFAULT 0,
        USERCREATEDDATE     DATETIME      NULL,
        LASTMODIFYEDDATE    DATETIME      NULL,
        CREATEDEMPLOYEEID   INT           NOT NULL CONSTRAINT DF_TRIPENTRY_CREATEDEMPLOYEEID DEFAULT 0,
        MODIFYEDEMPLOYEEID  INT           NOT NULL CONSTRAINT DF_TRIPENTRY_MODIFYEDEMPLOYEEID DEFAULT 0,
        SITEID              INT           NOT NULL CONSTRAINT DF_TRIPENTRY_SITEID DEFAULT 0,
        TRIPNO              NVARCHAR(100) NULL,
        TRIPDATE            DATETIME      NULL,
        CONVERTTOSALES      BIT           NOT NULL CONSTRAINT DF_TRIPENTRY_CONVERTTOSALES DEFAULT 0
    );
END
GO

IF OBJECT_ID(N'dbo.TRIPENTRY_DETAILS', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TRIPENTRY_DETAILS
    (
        TRIPENTRYID     INT           NOT NULL CONSTRAINT DF_TRIPENTRY_DETAILS_TRIPENTRYID DEFAULT 0,
        TRIPENTRYDETID  INT IDENTITY(1,1) NOT NULL,
        COMPANYID       INT           NOT NULL CONSTRAINT DF_TRIPENTRY_DETAILS_COMPANYID DEFAULT 0,
        COUNTERID       INT           NOT NULL CONSTRAINT DF_TRIPENTRY_DETAILS_COUNTERID DEFAULT 0,
        PRODUCTID       INT           NOT NULL CONSTRAINT DF_TRIPENTRY_DETAILS_PRODUCTID DEFAULT 0,
        PRODUCTCODE     VARCHAR(50)   NULL,
        HSNCODE         VARCHAR(50)   NULL,
        BRANDID         INT           NOT NULL CONSTRAINT DF_TRIPENTRY_DETAILS_BRANDID DEFAULT 0,
        TYPEID          INT           NOT NULL CONSTRAINT DF_TRIPENTRY_DETAILS_TYPEID DEFAULT 0,
        UOMID           INT           NOT NULL CONSTRAINT DF_TRIPENTRY_DETAILS_UOMID DEFAULT 0,
        WEIGHT          NUMERIC(18,2) NOT NULL CONSTRAINT DF_TRIPENTRY_DETAILS_WEIGHT DEFAULT 0,
        QTY             NUMERIC(18,2) NOT NULL CONSTRAINT DF_TRIPENTRY_DETAILS_QTY DEFAULT 0,
        MRP             NUMERIC(18,2) NOT NULL CONSTRAINT DF_TRIPENTRY_DETAILS_MRP DEFAULT 0,
        RATE            NUMERIC(18,2) NOT NULL CONSTRAINT DF_TRIPENTRY_DETAILS_RATE DEFAULT 0,
        GROSSAMOUNT     NUMERIC(18,2) NOT NULL CONSTRAINT DF_TRIPENTRY_DETAILS_GROSSAMOUNT DEFAULT 0,
        TAXABLEVALUE    NUMERIC(18,2) NOT NULL CONSTRAINT DF_TRIPENTRY_DETAILS_TAXABLEVALUE DEFAULT 0,
        CGSTPERCENTAGE  NUMERIC(18,2) NOT NULL CONSTRAINT DF_TRIPENTRY_DETAILS_CGSTPERCENTAGE DEFAULT 0,
        CGSTAMOUNT      NUMERIC(18,2) NOT NULL CONSTRAINT DF_TRIPENTRY_DETAILS_CGSTAMOUNT DEFAULT 0,
        SGSTPERCENTAGE  NUMERIC(18,2) NOT NULL CONSTRAINT DF_TRIPENTRY_DETAILS_SGSTPERCENTAGE DEFAULT 0,
        SGSTAMOUNT      NUMERIC(18,2) NOT NULL CONSTRAINT DF_TRIPENTRY_DETAILS_SGSTAMOUNT DEFAULT 0,
        IGSTPERCENTAGE  NUMERIC(18,2) NOT NULL CONSTRAINT DF_TRIPENTRY_DETAILS_IGSTPERCENTAGE DEFAULT 0,
        IGSTAMOUNT      NUMERIC(18,2) NOT NULL,
        TOTALTAX        NUMERIC(18,2) NOT NULL,
        PERRATE         NUMERIC(18,2) NOT NULL,
        PRATE           NUMERIC(18,2) NOT NULL,
        TOTALAMOUNT     NUMERIC(18,2) NOT NULL,
        ENTRYID         INT           NOT NULL,
        METERORHOURSID  INT           NULL,
        TIMESTART       DATETIME      NULL,
        TIMECLOSE       DATETIME      NULL,
        METERSTART      NUMERIC(18,1) NULL,
        METERCLOSE      NUMERIC(18,1) NULL,
        VEHICLEID       INT           NULL
    );
END
GO

IF OBJECT_ID(N'dbo.DELIVERY_DETAILS', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DELIVERY_DETAILS
    (
        DELIVERYID       INT           NOT NULL,
        DELIVERYNO       VARCHAR(50)   NOT NULL,
        SALESORDERID     INT           NOT NULL,
        SALESORDERDETID  INT           NOT NULL,
        PRODUCTID        INT           NOT NULL,
        DELIVERYQTY      NUMERIC(12,2) NOT NULL,
        BALANCEQTY       NUMERIC(12,2) NOT NULL,
        DRIVERID         INT           NOT NULL,
        VEHICLENUMBER    VARCHAR(10)   NULL,
        CREATE_DATE      DATETIME      NOT NULL,
        CREATE_USER      VARCHAR(50)   NOT NULL,
        MODIFIED_DATE    DATETIME      NULL,
        MODIFIED_USER    VARCHAR(50)   NULL
    );
END
GO

------------------------------------------------------------
-- 11. TRIPENTRY_DETAILS.METERSTART/METERCLOSE precision fix (folded in
--     from 008_tripentry_meter_precision_fix.sql — see that file's header
--     for the full story). No-op on a database whose TRIPENTRY_DETAILS
--     was just created fresh by section 10 above, which already uses the
--     corrected NUMERIC(18,1).
------------------------------------------------------------
IF EXISTS (
    SELECT 1 FROM sys.columns c
    INNER JOIN sys.tables t ON t.object_id = c.object_id
    WHERE t.name = 'TRIPENTRY_DETAILS' AND c.name = 'METERSTART' AND c.scale = 0
)
BEGIN
    ALTER TABLE dbo.TRIPENTRY_DETAILS ALTER COLUMN METERSTART NUMERIC(18,1) NULL;
    ALTER TABLE dbo.TRIPENTRY_DETAILS ALTER COLUMN METERCLOSE NUMERIC(18,1) NULL;
END
GO

------------------------------------------------------------
-- 12. Product price history prerequisites (folded in from
--     013_product_price_history.sql — see that file's header for the
--     full story). PRODUCT_DETAILS.PRODUCTDETAILID was added directly by
--     hand on db_ams_erp/DB_AMS_ERP_SMS; this makes every other database
--     match. Section 4's SP_MOBILE_CREATE_SALESORDER above already
--     stamps SALESORDER_DETAILS.PRODUCTDETAILID with whichever
--     PRODUCT_DETAILS row is current at the moment of sale.
------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'PRODUCT_DETAILS' AND COLUMN_NAME = 'PRODUCTDETAILID'
)
BEGIN
    ALTER TABLE dbo.PRODUCT_DETAILS ADD PRODUCTDETAILID INT IDENTITY(1,1);
END
GO

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'SALESORDER_DETAILS' AND COLUMN_NAME = 'PRODUCTDETAILID'
)
BEGIN
    ALTER TABLE dbo.SALESORDER_DETAILS
        ADD PRODUCTDETAILID INT NOT NULL CONSTRAINT DF_SALESORDER_DETAILS_PRODUCTDETAILID DEFAULT 0;
END
GO


------------------------------------------------------------
-- 13. Payment Entry + customer ledger report (folded in from
--     017_payment_details.sql — see that file's header for the full
--     design note, including why the ledger's running balance is
--     computed over the customer's entire history rather than just the
--     filtered date window).
------------------------------------------------------------
IF OBJECT_ID(N'dbo.PAYMENT_DETAILS', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PAYMENT_DETAILS
    (
        PAYMENTID   INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PAYMENT_DETAILS PRIMARY KEY,
        PAYMENTNO   VARCHAR(50)   NOT NULL,
        LOCATIONID  INT           NOT NULL,
        CUSTOMERID  INT           NOT NULL,
        AMOUNT      NUMERIC(18,2) NOT NULL,
        PAYMENTTYPE VARCHAR(20)   NOT NULL CONSTRAINT DF_PAYMENT_DETAILS_PAYMENTTYPE_NEW DEFAULT 'Cash',
        PAYMENTDATE DATETIME      NOT NULL,
        CREATE_DATE DATETIME      NOT NULL CONSTRAINT DF_PAYMENT_DETAILS_CREATE_DATE DEFAULT GETDATE(),
        CREATE_USER VARCHAR(50)   NOT NULL
    );
    CREATE INDEX IX_PAYMENT_DETAILS_CUSTOMERID ON dbo.PAYMENT_DETAILS(CUSTOMERID);
END
GO

;WITH PaymentFiscalSuffix AS (
    SELECT LOCATIONID, SUBSTRING(SHORTNAME, CHARINDEX('/', SHORTNAME) + 1, LEN(SHORTNAME)) AS Suffix
    FROM dbo.TRANSACTIONS
    WHERE NAME = 'SALESORDER'
)
INSERT INTO dbo.TRANSACTIONS (NAME, SHORTNAME, LOCATIONID, LASTNO)
SELECT 'PAYMENT', 'PMT/' + FS.Suffix, FS.LOCATIONID, 0
FROM PaymentFiscalSuffix FS
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.TRANSACTIONS T
    WHERE T.NAME = 'PAYMENT' AND T.LOCATIONID = FS.LOCATIONID
);
GO

-- PAYMENT_DETAILS.PAYMENTTYPE (folded in from 023_payment_type.sql — see
-- that file's header) must exist before SP_MOBILE_CREATE_PAYMENT's CREATE
-- PROCEDURE below, same deferred-name-resolution reason as every other
-- prerequisite guard in this script.
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'PAYMENT_DETAILS' AND COLUMN_NAME = 'PAYMENTTYPE'
)
BEGIN
    ALTER TABLE dbo.PAYMENT_DETAILS
        ADD PAYMENTTYPE VARCHAR(20) NOT NULL CONSTRAINT DF_PAYMENT_DETAILS_PAYMENTTYPE DEFAULT 'Cash';
END
GO

IF OBJECT_ID(N'dbo.SP_MOBILE_CREATE_PAYMENT', N'P') IS NOT NULL
    DROP PROCEDURE dbo.SP_MOBILE_CREATE_PAYMENT;
GO

CREATE PROCEDURE dbo.SP_MOBILE_CREATE_PAYMENT
(
    @LOCATIONID INT,
    @CUSTOMERID INT,
    @AMOUNT     NUMERIC(18,2),
    @PAYMENTTYPE VARCHAR(20) = 'Cash',
    @CREATEUSER VARCHAR(50),
    @PAYMENTNO  VARCHAR(MAX) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @AMOUNT IS NULL OR @AMOUNT <= 0
    BEGIN
        RAISERROR('Payment amount must be greater than zero.', 16, 1);
        RETURN;
    END

    EXEC dbo.SP_GENERATETRANNO
         @TRANSACTIONNAME = 'PAYMENT',
         @TRANNO = @PAYMENTNO OUTPUT,
         @USERSHORTNAME = '',
         @LOCATIONID = @LOCATIONID;

    DECLARE @CurrentDate DATETIME;
    SELECT TOP 1 @CurrentDate = CURRENTDATE FROM dbo.CHANGE_DATE;
    IF @CurrentDate IS NULL SET @CurrentDate = GETDATE();

    INSERT INTO dbo.PAYMENT_DETAILS (PAYMENTNO, LOCATIONID, CUSTOMERID, AMOUNT, PAYMENTTYPE, PAYMENTDATE, CREATE_DATE, CREATE_USER)
    VALUES (@PAYMENTNO, @LOCATIONID, @CUSTOMERID, @AMOUNT, @PAYMENTTYPE, @CurrentDate, GETDATE(), @CREATEUSER);
END
GO

IF OBJECT_ID(N'dbo.SP_MOBILE_GET_CUSTOMER_LEDGER', N'P') IS NOT NULL
    DROP PROCEDURE dbo.SP_MOBILE_GET_CUSTOMER_LEDGER;
GO

CREATE PROCEDURE dbo.SP_MOBILE_GET_CUSTOMER_LEDGER
(
    @LOCATIONID INT,
    @CUSTOMERID INT,
    @FROMDATE   DATE = NULL,
    @TODATE     DATE = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH DeliveryTxns AS (
        SELECT
            DD.DELIVERYNO AS TXNNO,
            MIN(DD.DELIVERDATE) AS TXNDATE,
            'Delivery' AS TXNTYPE,
            SUM((SOD.TOTALAMOUNT / NULLIF(SOD.SALESQTY, 0)) * DD.DELIVERYQTY) AS TOTALAMOUNT,
            CAST(0 AS NUMERIC(18,2)) AS RECEIVEDAMOUNT
        FROM dbo.DELIVERY_DETAILS DD
        INNER JOIN dbo.SALESORDER_DETAILS SOD ON SOD.SALESORDERDETID = DD.SALESORDERDETID
        INNER JOIN dbo.SALESORDER SO ON SO.SALESORDERID = DD.SALESORDERID
        WHERE SO.CUSTOMERID = @CUSTOMERID AND SO.LOCATIONID = @LOCATIONID
        GROUP BY DD.DELIVERYNO
    ),
    PaymentTxns AS (
        SELECT
            PD.PAYMENTNO AS TXNNO,
            PD.PAYMENTDATE AS TXNDATE,
            'Payment' AS TXNTYPE,
            CAST(0 AS NUMERIC(18,2)) AS TOTALAMOUNT,
            PD.AMOUNT AS RECEIVEDAMOUNT
        FROM dbo.PAYMENT_DETAILS PD
        WHERE PD.CUSTOMERID = @CUSTOMERID AND PD.LOCATIONID = @LOCATIONID
    ),
    Combined AS (
        SELECT * FROM DeliveryTxns
        UNION ALL
        SELECT * FROM PaymentTxns
    ),
    Running AS (
        SELECT
            TXNDATE, TXNTYPE, TXNNO, TOTALAMOUNT, RECEIVEDAMOUNT,
            SUM(TOTALAMOUNT - RECEIVEDAMOUNT) OVER (
                ORDER BY TXNDATE, TXNNO
                ROWS UNBOUNDED PRECEDING
            ) AS OUTSTANDINGAMOUNT
        FROM Combined
    )
    SELECT TXNDATE, TXNTYPE, TXNNO, TOTALAMOUNT, RECEIVEDAMOUNT, OUTSTANDINGAMOUNT
    FROM Running
    WHERE (@FROMDATE IS NULL OR CAST(TXNDATE AS DATE) >= @FROMDATE)
      AND (@TODATE IS NULL OR CAST(TXNDATE AS DATE) <= @TODATE)
    ORDER BY TXNDATE, TXNNO;
END
GO

------------------------------------------------------------
-- 14. Area master + SITE.AREAID (folded in from 022_area_master.sql —
--     see that file's header for the full design note).
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

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'SITE' AND COLUMN_NAME = 'AREAID'
)
BEGIN
    ALTER TABLE dbo.SITE
        ADD AREAID INT NOT NULL CONSTRAINT DF_SITE_AREAID DEFAULT 0;
END
GO
