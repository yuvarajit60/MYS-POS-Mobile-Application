/*
  TRIPENTRY_DETAILS.METERSTART / METERCLOSE are NUMERIC(18,0) on every
  database checked so far (db_ams_pos_test, and by inheritance
  DB_AMS_ERP_SMS) — meaning a decimal meter reading like 120.4 is
  silently ROUNDED to 120 on insert. Confirmed against real data in
  db_ams_pos_test on 2026-09-04: TRIPENTRYDETID=12 has METERSTART=120,
  METERCLOSE=123 even though 120.4 / 122.6 was what was actually entered
  through the app.

  This does NOT affect billing — TRIPENTRY_DETAILS.QTY is computed
  client-side from the true decimal values before the rounding happens,
  and is stored correctly in its own NUMERIC(18,2) column. This only
  affects the audit-trail readings themselves (what's shown later on the
  Trip Entry Detail screen and its PDF export).

  Widening scale (0 -> 1) is a safe, non-destructive ALTER — existing
  whole-number values are unaffected, it just stops truncating future
  inserts. Idempotent (only alters if still NUMERIC(18,0)).

  db_ams_erp does not need this: 007_db_ams_erp_missing_tables.sql
  creates its TRIPENTRY_DETAILS with the corrected NUMERIC(18,1) directly.
*/

IF EXISTS (
    SELECT 1 FROM sys.columns c
    INNER JOIN sys.tables t ON t.object_id = c.object_id
    WHERE t.name = 'TRIPENTRY_DETAILS' AND c.name = 'METERSTART' AND c.scale = 0
)
BEGIN
    ALTER TABLE dbo.TRIPENTRY_DETAILS ALTER COLUMN METERSTART NUMERIC(18,1) NULL;
    ALTER TABLE dbo.TRIPENTRY_DETAILS ALTER COLUMN METERCLOSE NUMERIC(18,1) NULL;
END
GO
