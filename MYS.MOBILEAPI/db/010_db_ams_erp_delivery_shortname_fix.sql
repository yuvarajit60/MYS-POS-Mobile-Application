/*
  db_ams_erp specific — an earlier run of deploy_mobile_schema.sql's
  section 8 (before it derived the fiscal-year suffix dynamically —
  see 006_delivery_tranno_seed.sql's header) inserted dbo.TRANSACTIONS'
  DELIVERY row with a hardcoded SHORTNAME of 'DLV/25-26/', copied from
  db_ams_pos_test. db_ams_erp is actually on fiscal year 26-27 for every
  other transaction type (SALESORDER = 'SO/26-27/', etc.), confirmed via
  read-only comparison on 2026-09-04.

  Safe to correct: the row's LASTNO is still 0 (confirmed not used yet —
  no DELIVERYNO has ever been generated from it), so this only changes
  the label on an as-yet-unused counter, not any already-issued number.

  Idempotent — only touches the row if it still has the old, wrong value.
*/

UPDATE dbo.TRANSACTIONS
SET SHORTNAME = 'DLV/' + FS.Suffix
FROM dbo.TRANSACTIONS T
CROSS APPLY (
    SELECT SUBSTRING(SO.SHORTNAME, CHARINDEX('/', SO.SHORTNAME) + 1, LEN(SO.SHORTNAME)) AS Suffix
    FROM dbo.TRANSACTIONS SO
    WHERE SO.NAME = 'SALESORDER' AND SO.LOCATIONID = T.LOCATIONID
) FS
WHERE T.NAME = 'DELIVERY' AND T.LASTNO = 0 AND T.SHORTNAME <> 'DLV/' + FS.Suffix;
