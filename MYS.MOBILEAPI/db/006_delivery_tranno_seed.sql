/*
  Delivery Entry numbering — dbo.TRANSACTIONS already had a NAME='DELIVERY'
  row (SHORTNAME 'DLV/25-26/'), but only for LOCATIONID=1002. The active
  location (LOCATIONID=1, COIMBATORE) — which every real SALESORDER/
  TRIPENTRY row in this database belongs to — had no DELIVERY row at all,
  so SP_GENERATETRANNO's location-scoped UPDATE/SELECT silently matched
  zero rows and returned a NULL @TRANNO. Found via a direct test call to
  SP_MOBILE_CREATE_DELIVERY on 2026-08-30 (INSERT failed: "Cannot insert
  the value NULL into column 'DELIVERYNO'").

  This seeds the missing row for every LOCATION that doesn't already have
  one. SHORTNAME's fiscal-year suffix ("25-26/", "26-27/", etc.) is derived
  from that same location's own SALESORDER row rather than hardcoded —
  this file originally hardcoded 'DLV/25-26/' (correct for db_ams_pos_test,
  which really is on that fiscal year), and that exact hardcoding produced
  a wrongly-stamped DELIVERY row when later reused against db_ams_erp
  (which is on fiscal year 26-27 for everything else). SALESORDER is used
  as the reference because every location has one already (it's a core,
  always-provisioned transaction type). See 010_db_ams_erp_delivery_shortname_fix.sql
  for the correction on the database that already has the wrong value.

  Idempotent — safe to re-run.
*/

;WITH FiscalSuffix AS (
    SELECT LOCATIONID, SUBSTRING(SHORTNAME, CHARINDEX('/', SHORTNAME) + 1, LEN(SHORTNAME)) AS Suffix
    FROM dbo.TRANSACTIONS
    WHERE NAME = 'SALESORDER'
)
INSERT INTO dbo.TRANSACTIONS (NAME, SHORTNAME, LOCATIONID, LASTNO)
SELECT 'DELIVERY', 'DLV/' + FS.Suffix, FS.LOCATIONID, 0
FROM FiscalSuffix FS
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.TRANSACTIONS T
    WHERE T.NAME = 'DELIVERY' AND T.LOCATIONID = FS.LOCATIONID
);
