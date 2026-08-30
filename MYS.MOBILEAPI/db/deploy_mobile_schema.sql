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
  returned NULL until seeded — see that file's header).

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
    PRODUCTID INT           NOT NULL,
    QTY       NUMERIC(18,3) NOT NULL,
    RATE      NUMERIC(18,2) NOT NULL   -- rep-editable, defaults to PRODUCT.MRP client-side
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

------------------------------------------------------------
-- 4. Sales-order creation proc (final version)
--    Writes ONLY to dbo.SALESORDER / dbo.SALESORDER_DETAILS.
--    Never touches dbo.STOCK_DETAILS or dbo.SALES / dbo.SALES_DETAILS.
--    Prices off dbo.PRODUCT (MRP, tax %) — RATE is rep-editable and
--    trusted from the client; tax % is always re-derived server-side.
------------------------------------------------------------
CREATE PROCEDURE dbo.SP_MOBILE_CREATE_SALESORDER
(
    @LOCATIONID        INT,
    @CUSTOMERID        INT,
    @CUSTOMERNAME      VARCHAR(100),
    @MOBILENO          VARCHAR(50),
    @SHIPPINGADDRESS   VARCHAR(500),
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
        L.PRODUCTID, L.QTY, L.RATE,
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
             @TRANSACTIONNAME = 'SALESORDER',
             @TRANNO = @ENTRYNO OUTPUT,
             @USERSHORTNAME = '',
             @LOCATIONID = @LOCATIONID;

        DECLARE @RawNetAmount NUMERIC(18,2), @RoundedNetAmount NUMERIC(18,2);

        SELECT @RawNetAmount = SUM(RATE * QTY)
                              + SUM(ROUND(RATE * QTY * (SALESCGSTPERCENTAGE + SALESSGSTPERCENTAGE + SALESIGSTPERCENTAGE) / 100.0, 2))
        FROM #LinePricing;

        SET @RoundedNetAmount = ROUND(@RawNetAmount, 0);

        INSERT INTO dbo.SALESORDER
            (ENTRYNO, ENTRYDATE, LOCATIONID, COUNTERID, MOBILENO, CUSTOMERID, PAYMENTMODE,
             TAXABLEVALUE, TOTALTAX, ITEMVALUE, DISCOUNTPERCENTAGE, DISCOUNTAMOUNT, ROUNDOFF, NETAMOUNT,
             SELECTRATE, CASHAMOUNT, CARDAMOUNT, RECEIVEDAMOUNT, REFUNDAMOUNT, SETTLEMENT, SETTLEMENTID, PAYMENT,
             CANCELUSERID, CANCELID, CANCEL, CREATEDLOCATIONID, MODIFYEDLOCATIONID, CREATEDUSERID, LASTMODIFYEDUSERID,
             USERCREATEDDATE, LASTMODIFYEDDATE, CREATEDEMPLOYEEID, MODIFYEDEMPLOYEEID,
             SHIPPINGADDRESS, CUSTOMERNAME, OrderDate)
        SELECT
            @ENTRYNO, GETDATE(), @LOCATIONID, 0, @MOBILENO, @CUSTOMERID, 'PENDING',
            SUM(RATE * QTY), SUM(ROUND(RATE * QTY * (SALESCGSTPERCENTAGE + SALESSGSTPERCENTAGE + SALESIGSTPERCENTAGE) / 100.0, 2)),
            SUM(RATE * QTY), 0, 0, (@RoundedNetAmount - @RawNetAmount), @RoundedNetAmount,
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, @LOCATIONID, @LOCATIONID, @CREATEDUSERID, @CREATEDUSERID,
            GETDATE(), GETDATE(), @CREATEDEMPLOYEEID, @CREATEDEMPLOYEEID,
            @SHIPPINGADDRESS, @CUSTOMERNAME, CAST(GETDATE() AS DATE)
        FROM #LinePricing;

        SET @SALESORDERID = SCOPE_IDENTITY();

        INSERT INTO dbo.SALESORDER_DETAILS
            (SALESORDERID, COMPANYID, COUNTERID, BARCODE, PRODUCTID, PRODUCTCODE, HSNCODE, BRANDID, TYPEID, UOMID,
             WEIGHT, QTY, MRP, RATE, GROSSAMOUNT, DISCOUNTPERCENTAGE, DISCOUNTAMOUNT, OTHERDISCOUNTAMOUNT,
             TAXABLEVALUE, CGSTPERCENTAGE, CGSTAMOUNT, SGSTPERCENTAGE, SGSTAMOUNT, IGSTPERCENTAGE, IGSTAMOUNT,
             TOTALTAX, PERRATE, PRATE, PTAX, TOTALAMOUNT, STOCKQTY, MFGDATE, EXPDATE, ENTRYID,
             PERPOINTS, SALESPOINTS, FREEITEM, SALESQTY)
        SELECT
            @SALESORDERID, 1, 0, '', PRODUCTID, '', HSNCODE, BRANDID, TYPEID, UOMID,
            0, QTY, MRP, RATE, RATE * QTY, 0, 0, 0,
            RATE * QTY,
            SALESCGSTPERCENTAGE, ROUND(RATE * QTY * SALESCGSTPERCENTAGE / 100.0, 2),
            SALESSGSTPERCENTAGE, ROUND(RATE * QTY * SALESSGSTPERCENTAGE / 100.0, 2),
            SALESIGSTPERCENTAGE, ROUND(RATE * QTY * SALESIGSTPERCENTAGE / 100.0, 2),
            ROUND(RATE * QTY * (SALESCGSTPERCENTAGE + SALESSGSTPERCENTAGE + SALESIGSTPERCENTAGE) / 100.0, 2),
            RATE, 0, 0,
            RATE * QTY + ROUND(RATE * QTY * (SALESCGSTPERCENTAGE + SALESSGSTPERCENTAGE + SALESIGSTPERCENTAGE) / 100.0, 2),
            0, NULL, NULL, 0,
            0, 0, 0, QTY
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

        DECLARE @NextId INT;
        SELECT @NextId = ISNULL(MAX(DELIVERYID), 0) FROM dbo.DELIVERY_DETAILS WITH (TABLOCKX, HOLDLOCK);

        ;WITH Numbered AS (
            SELECT *, ROW_NUMBER() OVER (ORDER BY SALESORDERDETID) AS RN
            FROM #DeliveryLines
        )
        INSERT INTO dbo.DELIVERY_DETAILS
            (DELIVERYID, DELIVERYNO, SALESORDERID, SALESORDERDETID, PRODUCTID, DELIVERYQTY, BALANCEQTY,
             DRIVERID, VEHICLENUMBER, CREATE_DATE, CREATE_USER)
        SELECT
            @NextId + RN, @DELIVERYNO, SALESORDERID, SALESORDERDETID, PRODUCTID, CURRENTDELIVERY,
            (SALESQTY - ALREADYDELIVERED - CURRENTDELIVERY),
            @DRIVERID, @VEHICLENUMBER, GETDATE(), @CREATEUSER
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
------------------------------------------------------------
INSERT INTO dbo.TRANSACTIONS (NAME, SHORTNAME, LOCATIONID, LASTNO)
SELECT 'DELIVERY', 'DLV/25-26/', L.LOCATIONID, 0
FROM dbo.LOCATION L
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.TRANSACTIONS T
    WHERE T.NAME = 'DELIVERY' AND T.LOCATIONID = L.LOCATIONID
);
GO
