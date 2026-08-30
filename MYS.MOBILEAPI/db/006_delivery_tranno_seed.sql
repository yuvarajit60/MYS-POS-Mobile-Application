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
  one, matching the SHORTNAME/starting LASTNO the existing 1002 row uses.
  Idempotent — safe to re-run.
*/

INSERT INTO dbo.TRANSACTIONS (NAME, SHORTNAME, LOCATIONID, LASTNO)
SELECT 'DELIVERY', 'DLV/25-26/', L.LOCATIONID, 0
FROM dbo.LOCATION L
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.TRANSACTIONS T
    WHERE T.NAME = 'DELIVERY' AND T.LOCATIONID = L.LOCATIONID
);
