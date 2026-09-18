/*
  Sales Order line-level Discount — the Sales Order screen's line-items
  grid gets a "Discount" checkbox next to each product. Off (default):
  everything behaves exactly as before (Rate is rep-editable, no
  discount). On: the Rate field is hidden and replaced with a Discount
  Amount field; Rate itself keeps tracking MRP underneath but stops
  being rep-editable, and the flat Discount Amount is subtracted from
  RATE*QTY before tax is computed.

  dbo.TVP_MOBILE_SALESORDER_LINES gets a new DISCOUNTAMOUNT column.
  Table-valued parameter TYPEs can't be ALTERed in SQL Server — they can
  only be dropped and recreated — so this drops and recreates both the
  TYPE and SP_MOBILE_CREATE_SALESORDER (which references it), same as
  002_product_redesign.sql originally did when this TVP was last
  restructured. DISCOUNTAMOUNT has no default (TVP columns can't have
  one either) — the app always sends 0 for a line with the checkbox off,
  so this is purely additive for any caller already passing all three
  existing columns via named columns (positional TVP inserts from an
  older client build would now be short one column and fail loudly,
  which is the correct behavior — better than silently mispricing).

  LINETAXABLE = MAX(RATE*QTY - DISCOUNTAMOUNT, 0) is computed once in
  #LinePricing and reused for both the SALESORDER header aggregates and
  the SALESORDER_DETAILS per-line insert, so tax is always computed on
  the post-discount amount, never the pre-discount one. GROSSAMOUNT
  (RATE*QTY, pre-discount) and the applied DISCOUNTAMOUNT are both still
  stored on SALESORDER_DETAILS alongside TAXABLEVALUE (post-discount) —
  same relationship at the SALESORDER header level (ITEMVALUE = gross
  total, DISCOUNTAMOUNT = total discount applied, TAXABLEVALUE = net).

  Idempotent — safe to re-run.
*/

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

        -- ENTRYDATE uses the desktop app's "business date" (CHANGE_DATE),
        -- not the wall clock — falls back to GETDATE() if that's somehow
        -- unset. Every other date column below is untouched.
        DECLARE @CurrentDate DATETIME;
        SELECT TOP 1 @CurrentDate = CURRENTDATE FROM dbo.CHANGE_DATE;
        IF @CurrentDate IS NULL SET @CurrentDate = GETDATE();

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
            @ENTRYNO, @CurrentDate, @LOCATIONID, 0, @MOBILENO, @CUSTOMERID, 'PENDING',
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
