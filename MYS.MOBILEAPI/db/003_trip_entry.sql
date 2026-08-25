/*
  Trip Entry — mobile equipment-hire billing (e.g. excavator hours/meter
  usage), mirroring the desktop app's Trip Entry screen. Writes ONLY to
  dbo.TRIPENTRY / dbo.TRIPENTRY_DETAILS (both pre-existing desktop tables,
  not created here) — never touches SALESORDER/SALES. Additive to
  001_create_mobile_objects.sql / 002_product_redesign.sql. Idempotent
  (drop + recreate).

  METERORHOURSID convention (this column has no lookup table — it's a
  simple two-way toggle in the UI, not DB-driven): 1 = Hours, 2 = Meter.
  This convention is introduced by this script since dbo.TRIPENTRY_DETAILS
  had zero existing rows at the time of writing (confirmed against the live
  DB) — there was no prior desktop-app convention to match.
*/

------------------------------------------------------------
-- 1. Line-items table type
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

------------------------------------------------------------
-- 2. Trip-entry creation proc
------------------------------------------------------------
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

    -- Tax % always looked up fresh from PRODUCT server-side; RATE/QTY are
    -- trusted from the client (rep-editable), same convention as
    -- SP_MOBILE_CREATE_SALESORDER.
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

        DECLARE @RawNetAmount NUMERIC(18,2), @RoundedNetAmount NUMERIC(18,2);

        SELECT @RawNetAmount = SUM(RATE * QTY)
                              + SUM(ROUND(RATE * QTY * (SALESCGSTPERCENTAGE + SALESSGSTPERCENTAGE + SALESIGSTPERCENTAGE) / 100.0, 2))
        FROM #LinePricing;

        SET @RoundedNetAmount = ROUND(@RawNetAmount, 0);

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
            SUM(RATE * QTY), (@RoundedNetAmount - @RawNetAmount), @RoundedNetAmount, 0,
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
