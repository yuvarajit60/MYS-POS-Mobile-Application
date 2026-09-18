/*
  DELIVERY_DETAILS.SITEID — same idea as 018_salesorder_siteid.sql: the
  Delivery Entry screen now lets the rep pick a Site (scoped to the
  selected customer, from dbo.SITE) instead of having no site reference
  at all. Adds DELIVERY_DETAILS.SITEID (INT NOT NULL DEFAULT 0, same
  "unset" sentinel convention as TRIPENTRY.SITEID and SALESORDER.SITEID)
  and updates SP_MOBILE_CREATE_DELIVERY to accept and store it — one
  value per submitted batch, stamped on every line inserted from that
  batch, same as DRIVERID/VEHICLENUMBER already are.

  @SITEID defaults to 0 so existing callers that don't pass it keep
  working unchanged.

  The ALTER TABLE guard is placed BEFORE the CREATE PROCEDURE below, not
  after — a stored procedure referencing a column on a table that already
  exists is validated immediately at CREATE PROCEDURE time, not deferred,
  so the column must already exist by the time this script reaches that
  statement (same gotcha as SALESORDER_DETAILS.PRODUCTDETAILID,
  DELIVERY_DETAILS.DELIVERDATE, and SALESORDER.SITEID before it).

  Idempotent — safe to re-run.
*/

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'DELIVERY_DETAILS' AND COLUMN_NAME = 'SITEID'
)
BEGIN
    ALTER TABLE dbo.DELIVERY_DETAILS
        ADD SITEID INT NOT NULL CONSTRAINT DF_DELIVERY_DETAILS_SITEID DEFAULT 0;
END
GO

IF OBJECT_ID(N'dbo.SP_MOBILE_CREATE_DELIVERY', N'P') IS NOT NULL
    DROP PROCEDURE dbo.SP_MOBILE_CREATE_DELIVERY;
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

        -- DELIVERDATE uses the desktop app's "business date" (CHANGE_DATE),
        -- not the wall clock — falls back to GETDATE() if that's somehow
        -- unset. CREATE_DATE below is untouched.
        DECLARE @CurrentDate DATETIME;
        SELECT TOP 1 @CurrentDate = CURRENTDATE FROM dbo.CHANGE_DATE;
        IF @CurrentDate IS NULL SET @CurrentDate = GETDATE();

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
            @DRIVERID, @VEHICLENUMBER, @CurrentDate, GETDATE(), @CREATEUSER, @SITEID
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
