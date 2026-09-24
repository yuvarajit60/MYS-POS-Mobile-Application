/*
  Gap fix — dbo.TRANSACTIONS is missing a NAME='PAYMENT' row entirely on
  db_ams_erp (found via a manual test/prod comparison on 2026-09-24),
  despite SP_MOBILE_CREATE_PAYMENT already existing there and being fully
  current (has @PAYMENTTYPE). Without this row, SP_GENERATETRANNO's
  location-scoped lookup silently returns NULL for @PAYMENTNO — the same
  bug class as 006_delivery_tranno_seed.sql's original DELIVERY gap.

  This does NOT touch SP_MOBILE_CREATE_PAYMENT or any other object —
  deliberately narrow, since 017_payment_details.sql (which contains this
  same seed logic) would also drop and recreate SP_MOBILE_CREATE_PAYMENT
  using its OLDER, pre-PaymentType body, regressing an already-current
  procedure. Use this standalone file instead when only the seed row is
  missing.

  Same convention as 006/009's own tranno seeds: SHORTNAME's fiscal-year
  suffix is derived from that location's own SALESORDER row rather than
  hardcoded.

  Idempotent — safe to re-run, and safe to run even where the PAYMENT
  row already exists (no-ops via the NOT EXISTS check).
*/

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
