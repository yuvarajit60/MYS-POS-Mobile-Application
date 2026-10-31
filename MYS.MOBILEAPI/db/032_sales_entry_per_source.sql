/*
  Sales Entry now converts each selected Delivery/Trip Entry into its own
  separate dbo.SALES record, instead of consolidating every selection into
  one shared Sales entry — so SALESID is now storable per source row rather
  than needing a join table, confirmed via read-only check as missing
  everywhere (sandbox and both prod databases).

  Adds nullable SALESID to DELIVERY_DETAILS and TRIPENTRY so a report can
  join straight back to the Sales entry each one was folded into (no FK
  constraint, matching this codebase's general convention of plain
  reference columns without enforced FKs).

  Idempotent — safe to re-run.
*/

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DELIVERY_DETAILS' AND COLUMN_NAME = 'SALESID')
    ALTER TABLE dbo.DELIVERY_DETAILS ADD SALESID INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'TRIPENTRY' AND COLUMN_NAME = 'SALESID')
    ALTER TABLE dbo.TRIPENTRY ADD SALESID INT NULL;
GO
