/*
  SALESORDER.SITEID — the Sales Order screen's "Site Delivery" field was
  only ever writing a text snapshot into SHIPPINGADDRESS (site name +
  area name); there was no real foreign-key-style link back to dbo.SITE,
  unlike TRIPENTRY.SITEID which already exists for the same relationship.

  Adds SALESORDER.SITEID (INT NOT NULL DEFAULT 0, matching TRIPENTRY.
  SITEID's own convention) and updates SP_MOBILE_CREATE_SALESORDER to
  accept and store it. SHIPPINGADDRESS is untouched — both are saved
  side by side now: SITEID for the real reference, SHIPPINGADDRESS for
  the human-readable snapshot already in use by anything reading it today.

  @SITEID defaults to 0 (same "unset" sentinel TRIPENTRY.SITEID uses) so
  existing callers that don't pass it keep working unchanged.

  The ALTER TABLE guard is placed BEFORE the CREATE PROCEDURE below, not
  after — a stored procedure referencing a column on a table that already
  exists is validated immediately at CREATE PROCEDURE time, not deferred,
  so the column must already exist by the time this script reaches that
  statement (same gotcha previously hit with SALESORDER_DETAILS.
  PRODUCTDETAILID and DELIVERY_DETAILS.DELIVERDATE).

  Idempotent — safe to re-run.
*/

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'SALESORDER' AND COLUMN_NAME = 'SITEID'
)
BEGIN
    ALTER TABLE dbo.SALESORDER
        ADD SITEID INT NOT NULL CONSTRAINT DF_SALESORDER_SITEID DEFAULT 0;
END
GO

IF OBJECT_ID(N'dbo.SP_MOBILE_CREATE_SALESORDER', N'P') IS NOT NULL
    DROP PROCEDURE dbo.SP_MOBILE_CREATE_SALESORDER;
GO

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
        L.PRODUCTID, L.QTY, L.RATE,
        PR.MRP, PR.HSNCODE, PR.BRANDID, PR.TYPEID, PR.UOMID,
        ISNULL(PR.SALESCGSTPERCENTAGE, 0) AS SALESCGSTPERCENTAGE,
        ISNULL(PR.SALESSGSTPERCENTAGE, 0) AS SALESSGSTPERCENTAGE,
        ISNULL(PR.SALESIGSTPERCENTAGE, 0) AS SALESIGSTPERCENTAGE,
        ISNULL(PD.PRODUCTDETAILID, 0) AS PRODUCTDETAILID
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

        -- ENTRYDATE uses the desktop app's "business date" (CHANGE_DATE),
        -- not the wall clock — falls back to GETDATE() if that's somehow
        -- unset. Every other date column below is untouched.
        DECLARE @CurrentDate DATETIME;
        SELECT TOP 1 @CurrentDate = CURRENTDATE FROM dbo.CHANGE_DATE;
        IF @CurrentDate IS NULL SET @CurrentDate = GETDATE();

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
             SHIPPINGADDRESS, CUSTOMERNAME, OrderDate, SITEID)
        SELECT
            @ENTRYNO, @CurrentDate, @LOCATIONID, 0, @MOBILENO, @CUSTOMERID, 'PENDING',
            SUM(RATE * QTY), SUM(ROUND(RATE * QTY * (SALESCGSTPERCENTAGE + SALESSGSTPERCENTAGE + SALESIGSTPERCENTAGE) / 100.0, 2)),
            SUM(RATE * QTY), 0, 0, (@RoundedNetAmount - @RawNetAmount), @RoundedNetAmount,
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
            0, QTY, MRP, RATE, RATE * QTY, 0, 0, 0,
            RATE * QTY,
            SALESCGSTPERCENTAGE, ROUND(RATE * QTY * SALESCGSTPERCENTAGE / 100.0, 2),
            SALESSGSTPERCENTAGE, ROUND(RATE * QTY * SALESSGSTPERCENTAGE / 100.0, 2),
            SALESIGSTPERCENTAGE, ROUND(RATE * QTY * SALESIGSTPERCENTAGE / 100.0, 2),
            ROUND(RATE * QTY * (SALESCGSTPERCENTAGE + SALESSGSTPERCENTAGE + SALESIGSTPERCENTAGE) / 100.0, 2),
            RATE, 0, 0,
            RATE * QTY + ROUND(RATE * QTY * (SALESCGSTPERCENTAGE + SALESSGSTPERCENTAGE + SALESIGSTPERCENTAGE) / 100.0, 2),
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
