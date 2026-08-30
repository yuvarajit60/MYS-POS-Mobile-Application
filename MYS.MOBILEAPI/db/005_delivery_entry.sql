/*
  Delivery Entry — records partial/full delivery of already-created Sales
  Order lines. Writes to dbo.DELIVERY_DETAILS and updates
  dbo.SALESORDER_DETAILS.DELIVERYQTY. Both tables are pre-existing (not
  created here) — confirmed against the live DB on 2026-08-30:
  SALESORDER_DETAILS already has SALESQTY/DELIVERYQTY columns, and
  DELIVERY_DETAILS already exists with 0 rows (a genuinely new feature,
  same situation as Trip Entry when it was added).

  DELIVERY_DETAILS.DELIVERYID has NO IDENTITY property and NO primary key
  (confirmed) — IDs are generated here via a locked MAX+1, the same
  concurrency-safety idiom SP_GENERATETRANNO itself already uses
  (`WITH (TABLOCKX)`) elsewhere in this schema, not something new
  introduced by this script.

  DELIVERYNO is generated via the existing dbo.SP_GENERATETRANNO using
  TRANSACTIONS.NAME = 'DELIVERY' (row already present in the live DB,
  SHORTNAME 'DLV/25-26/') — the same convention SALESORDER/TRIPENTRY use
  for their own entry numbers. One number is generated per submitted
  batch and stamped on every line inserted from that batch, since
  DELIVERY_DETAILS has no separate header row to hold it once.

  All-or-nothing: if ANY line in the submitted batch fails its balance
  check (e.g. someone else delivered it in the meantime), the whole
  batch is rolled back — there is no partial save, matching the
  mobile app's "cannot be edited after save" design (a partial save
  would leave the rep unable to correct just the failed lines).

  Idempotent — safe to re-run.
*/

------------------------------------------------------------
-- 1. Line-items table type
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
    DELIVERYQTY     NUMERIC(18,3) NOT NULL   -- "CurrentDelivery" from the app, this submission's qty only
);
GO

------------------------------------------------------------
-- 2. Delivery creation proc
------------------------------------------------------------
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
        -- Lock the exact rows being delivered against for the duration of
        -- this transaction, so a concurrent delivery against the same
        -- lines can't race past the balance check below.
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

        -- One DELIVERYNO per submitted batch (DELIVERY_DETAILS has no header
        -- row, so every line in this batch shares the same number).
        EXEC dbo.SP_GENERATETRANNO
             @TRANSACTIONNAME = 'DELIVERY',
             @TRANNO = @DELIVERYNO OUTPUT,
             @USERSHORTNAME = '',
             @LOCATIONID = @LOCATIONID;

        -- Legacy no-identity table: serialize ID generation the same way
        -- SP_GENERATETRANNO serializes TRANSACTIONS.LASTNO.
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
