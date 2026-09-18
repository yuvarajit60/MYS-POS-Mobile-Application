/*
  Payment Entry + Customer Ledger Report — new feature, not a pre-existing
  desktop-app table. Records money received from a customer against their
  running balance from delivered goods.

  dbo.PAYMENT_DETAILS is created fresh here (confirmed not present on any
  of db_ams_pos_test/db_ams_erp/DB_AMS_ERP_SMS). Unlike DELIVERY_DETAILS,
  it gets a proper IDENTITY primary key — there's no legacy desktop table
  shape to match, so no reason to repeat that table's no-identity quirk.

  PAYMENTNO is generated via the existing dbo.SP_GENERATETRANNO, same
  convention as SALESORDER/TRIPENTRY/DELIVERY — needs its own
  TRANSACTIONS row per location (mirrors 006_delivery_tranno_seed.sql /
  009_tripentry_tranno_seed.sql: fiscal-year suffix derived from that
  location's own SALESORDER row, not hardcoded).

  PAYMENTDATE is stamped from dbo.CHANGE_DATE (see 016_current_date_entrydate.sql)
  same as SALESORDER.ENTRYDATE/TRIPENTRY.ENTRYDATE/DELIVERY_DETAILS.DELIVERDATE —
  CREATE_DATE (the real insert timestamp) is separate and unaffected.

  The ledger report has no new table of its own — it derives "Delivery"
  transactions from DELIVERY_DETAILS (grouped by DELIVERYNO, one row per
  delivery submission, valued proportionally against each line's
  SALESORDER_DETAILS.TOTALAMOUNT/SALESQTY since DELIVERY_DETAILS itself
  has no amount column) unioned with "Payment" transactions from
  PAYMENT_DETAILS, with a running Outstanding Amount computed over the
  customer's ENTIRE history (not just the filtered date window) so an
  optional date filter narrows which rows are shown without resetting
  the running balance shown on them — see SP_MOBILE_GET_CUSTOMER_LEDGER.

  Idempotent — safe to re-run.
*/

------------------------------------------------------------
-- 1. PAYMENT_DETAILS table
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
        PAYMENTDATE DATETIME      NOT NULL,
        CREATE_DATE DATETIME      NOT NULL CONSTRAINT DF_PAYMENT_DETAILS_CREATE_DATE DEFAULT GETDATE(),
        CREATE_USER VARCHAR(50)   NOT NULL
    );
    CREATE INDEX IX_PAYMENT_DETAILS_CUSTOMERID ON dbo.PAYMENT_DETAILS(CUSTOMERID);
END
GO

------------------------------------------------------------
-- 2. PAYMENT numbering prerequisite — same idea as DELIVERY/TRIPENTRY.
------------------------------------------------------------
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

------------------------------------------------------------
-- 3. Payment creation proc
------------------------------------------------------------
IF OBJECT_ID(N'dbo.SP_MOBILE_CREATE_PAYMENT', N'P') IS NOT NULL
    DROP PROCEDURE dbo.SP_MOBILE_CREATE_PAYMENT;
GO

CREATE PROCEDURE dbo.SP_MOBILE_CREATE_PAYMENT
(
    @LOCATIONID INT,
    @CUSTOMERID INT,
    @AMOUNT     NUMERIC(18,2),
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

    INSERT INTO dbo.PAYMENT_DETAILS (PAYMENTNO, LOCATIONID, CUSTOMERID, AMOUNT, PAYMENTDATE, CREATE_DATE, CREATE_USER)
    VALUES (@PAYMENTNO, @LOCATIONID, @CUSTOMERID, @AMOUNT, @CurrentDate, GETDATE(), @CREATEUSER);
END
GO

------------------------------------------------------------
-- 4. Customer ledger report proc
------------------------------------------------------------
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
            -- Running balance over the customer's ENTIRE history, so an
            -- optional date filter (applied below) only narrows which
            -- rows are shown, never resets the balance those rows report.
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
