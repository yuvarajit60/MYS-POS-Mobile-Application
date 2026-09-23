/*
  Payment Entry gets a Payment Type selector (Cash / UPI / Acc Transfer).
  PAYMENT_DETAILS.PAYMENTTYPE (new column, VARCHAR(20), defaults to
  'Cash') stores it, and SP_MOBILE_CREATE_PAYMENT now accepts and saves
  it — @PAYMENTTYPE defaults to 'Cash' too, so any caller that doesn't
  pass it keeps working unchanged.

  This also backs a new standalone Payment Report (Customer/PaymentDate/
  PaymentType/Amount, filterable by the same four fields) — that report
  reads PAYMENT_DETAILS directly with plain parameterized SQL, no new
  stored procedure needed.

  The ALTER TABLE guard is placed BEFORE the CREATE PROCEDURE below, not
  after — a stored procedure referencing a column on a table that already
  exists is validated immediately at CREATE PROCEDURE time, not deferred,
  so the column must already exist by the time this script reaches that
  statement (same gotcha as every other column addition in this project).

  Idempotent — safe to re-run.
*/

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'PAYMENT_DETAILS' AND COLUMN_NAME = 'PAYMENTTYPE'
)
BEGIN
    ALTER TABLE dbo.PAYMENT_DETAILS
        ADD PAYMENTTYPE VARCHAR(20) NOT NULL CONSTRAINT DF_PAYMENT_DETAILS_PAYMENTTYPE DEFAULT 'Cash';
END
GO

IF OBJECT_ID(N'dbo.SP_MOBILE_CREATE_PAYMENT', N'P') IS NOT NULL
    DROP PROCEDURE dbo.SP_MOBILE_CREATE_PAYMENT;
GO

CREATE PROCEDURE dbo.SP_MOBILE_CREATE_PAYMENT
(
    @LOCATIONID  INT,
    @CUSTOMERID  INT,
    @AMOUNT      NUMERIC(18,2),
    @PAYMENTTYPE VARCHAR(20) = 'Cash',
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

    DECLARE @CurrentDate DATETIME;
    SELECT TOP 1 @CurrentDate = CURRENTDATE FROM dbo.CHANGE_DATE;
    IF @CurrentDate IS NULL SET @CurrentDate = GETDATE();

    INSERT INTO dbo.PAYMENT_DETAILS (PAYMENTNO, LOCATIONID, CUSTOMERID, AMOUNT, PAYMENTTYPE, PAYMENTDATE, CREATE_DATE, CREATE_USER)
    VALUES (@PAYMENTNO, @LOCATIONID, @CUSTOMERID, @AMOUNT, @PAYMENTTYPE, @CurrentDate, GETDATE(), @CREATEUSER);
END
GO
