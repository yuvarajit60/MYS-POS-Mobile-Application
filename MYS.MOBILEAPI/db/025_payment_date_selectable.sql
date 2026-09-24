/*
  Payment Entry's Payment Date becomes rep-selectable (a date picker in
  the app) instead of a fixed read-only value pulled from dbo.CHANGE_DATE.

  SP_MOBILE_CREATE_PAYMENT gets a new @PAYMENTDATE parameter, trusted
  from the client — same convention as TRIPENTRY.TRIPDATE, which has
  always been exactly what the rep entered rather than derived
  server-side. @PAYMENTDATE defaults to NULL, and when NULL the proc
  falls back to dbo.CHANGE_DATE then GETDATE(), preserving the previous
  behavior for any caller that doesn't pass it — so this is purely
  additive and safe to run even before the app is updated.

  Idempotent — safe to re-run (DROP + CREATE PROCEDURE only; no table
  changes, since PAYMENT_DETAILS.PAYMENTDATE already exists and just
  receives a client-supplied value now instead of a server-derived one).
*/

IF OBJECT_ID(N'dbo.SP_MOBILE_CREATE_PAYMENT', N'P') IS NOT NULL
    DROP PROCEDURE dbo.SP_MOBILE_CREATE_PAYMENT;
GO

CREATE PROCEDURE dbo.SP_MOBILE_CREATE_PAYMENT
(
    @LOCATIONID  INT,
    @CUSTOMERID  INT,
    @AMOUNT      NUMERIC(18,2),
    @PAYMENTTYPE VARCHAR(20) = 'Cash',
    @PAYMENTDATE DATETIME = NULL,
    @CREATEUSER  VARCHAR(50),
    @PAYMENTNO   VARCHAR(MAX) OUTPUT
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

    -- PAYMENTDATE is rep-selectable (the app's Payment Date picker) —
    -- @PAYMENTDATE is trusted from the client, same as TRIPENTRY.TRIPDATE.
    -- Falls back to dbo.CHANGE_DATE, then GETDATE(), only if the caller
    -- doesn't supply one (keeps older callers working unchanged).
    DECLARE @CurrentDate DATETIME = @PAYMENTDATE;
    IF @CurrentDate IS NULL
    BEGIN
        SELECT TOP 1 @CurrentDate = CURRENTDATE FROM dbo.CHANGE_DATE;
        IF @CurrentDate IS NULL SET @CurrentDate = GETDATE();
    END

    INSERT INTO dbo.PAYMENT_DETAILS (PAYMENTNO, LOCATIONID, CUSTOMERID, AMOUNT, PAYMENTTYPE, PAYMENTDATE, CREATE_DATE, CREATE_USER)
    VALUES (@PAYMENTNO, @LOCATIONID, @CUSTOMERID, @AMOUNT, @PAYMENTTYPE, @CurrentDate, GETDATE(), @CREATEUSER);
END
GO
