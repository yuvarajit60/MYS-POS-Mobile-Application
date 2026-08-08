/*
  Redesign: mobile sales orders now price directly off dbo.PRODUCT (MRP,
  tax %, HSN/brand/type/UOM) instead of joining dbo.STOCK_DETAILS — stock
  availability is no longer a precondition for a field rep to take an order
  (that's still enforced later, at the existing SALESORDERTOSALES conversion
  step). Rate is now editable per line by the rep, defaulting to PRODUCT.MRP.
  Idempotent (drop + recreate), additive to 001_create_mobile_objects.sql.
*/

------------------------------------------------------------
-- 1. Line items TVP now carries the (possibly rep-edited) RATE
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
-- 2. Sales-order creation proc, no longer touches STOCK_DETAILS
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

    -- Tax % is always looked up fresh from PRODUCT server-side (not client
    -- trusted) to avoid tax tampering; RATE itself IS trusted from the
    -- client since the rep is deliberately allowed to edit it per order.
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
