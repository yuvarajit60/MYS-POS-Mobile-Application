/*
  Same bug class as 006_delivery_tranno_seed.sql, found on db_ams_erp on
  2026-09-04: dbo.TRANSACTIONS has no NAME='TRIPENTRY' row for ANY
  location on this database (unlike DELIVERY, which deploy_mobile_schema.sql
  seeds for every location itself) — this desktop install never had the
  Trip Entry feature, so TRIPENTRY was never provisioned in TRANSACTIONS
  at all. Once dbo.TRIPENTRY exists (via 007_db_ams_erp_missing_tables.sql),
  calling SP_MOBILE_CREATE_TRIPENTRY would return a NULL @ENTRYNO and fail,
  exactly like SP_MOBILE_CREATE_DELIVERY did before 006 was applied.

  Seeds the missing row for every LOCATION that doesn't already have one.
  SHORTNAME's fiscal-year suffix ("26-27/" etc.) is derived from that same
  location's own SALESORDER row rather than hardcoded — a hardcoded
  '25-26/' (copied from db_ams_pos_test, which really is on that fiscal
  year) is exactly the mistake the original version of
  006_delivery_tranno_seed.sql made, producing a DELIVERY row on
  db_ams_erp stamped '25-26/' while every other transaction type there is
  '26-27/'. SALESORDER is used as the reference because every location
  has one already (it's a core, always-provisioned transaction type).

  Idempotent — safe to re-run, and a no-op on a database that already has
  TRIPENTRY rows for all its locations.
*/

;WITH FiscalSuffix AS (
    SELECT LOCATIONID, SUBSTRING(SHORTNAME, CHARINDEX('/', SHORTNAME) + 1, LEN(SHORTNAME)) AS Suffix
    FROM dbo.TRANSACTIONS
    WHERE NAME = 'SALESORDER'
)
INSERT INTO dbo.TRANSACTIONS (NAME, SHORTNAME, LOCATIONID, LASTNO)
SELECT 'TRIPENTRY', 'TRI/' + FS.Suffix, FS.LOCATIONID, 0
FROM FiscalSuffix FS
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.TRANSACTIONS T
    WHERE T.NAME = 'TRIPENTRY' AND T.LOCATIONID = FS.LOCATIONID
);
