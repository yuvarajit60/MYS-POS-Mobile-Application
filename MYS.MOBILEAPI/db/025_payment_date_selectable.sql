/*
  Payment Entry's Payment Date becomes rep-selectable (a date picker in
  the app) instead of a fixed read-only value pulled from dbo.CHANGE_DATE.

  SP_MOBILE_CREATE_PAYMENT gets a new required @PAYMENTDATE parameter,
  always trusted from the client with no dbo.CHANGE_DATE/GETDATE()
  fallback — same convention as TRIPENTRY.TRIPDATE, which has always
  been exactly what the rep entered rather than derived server-side.
  The app always supplies this value (defaulting to the business date
  in the picker, but editable), so a fallback would only ever mask a
  client-side bug rather than serve a real caller.

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
    @PAYMENTDATE DATETIME,
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

    -- PAYMENTDATE is always the app's Payment Date picker value — trusted
    -- from the client with no CHANGE_DATE/GETDATE() fallback, same as
    -- TRIPENTRY.TRIPDATE.
    INSERT INTO dbo.PAYMENT_DETAILS (PAYMENTNO, LOCATIONID, CUSTOMERID, AMOUNT, PAYMENTTYPE, PAYMENTDATE, CREATE_DATE, CREATE_USER)
    VALUES (@PAYMENTNO, @LOCATIONID, @CUSTOMERID, @AMOUNT, @PAYMENTTYPE, @PAYMENTDATE, GETDATE(), @CREATEUSER);
END
GO
