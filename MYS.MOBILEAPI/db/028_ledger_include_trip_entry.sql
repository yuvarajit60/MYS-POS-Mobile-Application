/*
  Customer Ledger report now includes Trip Entry as a third billed
  transaction type, alongside the existing Delivery and Payment rows.
  TRIPENTRY.CONVERTTOSALES is always 0 from this mobile app (there's no
  Trip-Entry-to-Sales-Order conversion flow here), so Trip Entry revenue
  never overlaps with Sales Order/Delivery revenue — safe to union in
  unconditionally, same running-balance treatment as Delivery.

  TXNDATE uses TRIPDATE (the rep-picked business date), not ENTRYDATE (the
  server insert timestamp) — same convention as PAYMENT_DETAILS.PAYMENTDATE
  in this same procedure, both trusted from the client with no
  CHANGE_DATE/GETDATE() fallback (see 025_payment_date_selectable.sql).
  Cancelled trip entries (CANCEL = 1) are excluded, matching every other
  Trip Entry report in this app.

  Idempotent — safe to re-run (DROP + CREATE PROCEDURE only).
*/

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
    TripTxns AS (
        SELECT
            TE.ENTRYNO AS TXNNO,
            TE.TRIPDATE AS TXNDATE,
            'Trip Entry' AS TXNTYPE,
            TE.NETAMOUNT AS TOTALAMOUNT,
            CAST(0 AS NUMERIC(18,2)) AS RECEIVEDAMOUNT
        FROM dbo.TRIPENTRY TE
        WHERE TE.CUSTOMERID = @CUSTOMERID AND TE.LOCATIONID = @LOCATIONID AND TE.CANCEL = 0
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
        SELECT * FROM TripTxns
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
