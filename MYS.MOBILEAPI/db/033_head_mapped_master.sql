/*
  Head Master gains a MAPPEDMASTER column — which other master table a Head
  should pull a picker from in Income or Expenses Entry, as data instead of
  hardcoded logic. Previously IncomeExpenseService.CreateAsync hardcoded
  "SALARY ADVANCE" -> Employee and "FUEL" -> Vehicle by comparing HEADNAME
  strings; now it reads HEAD.MAPPEDMASTER instead, so adding a new Head
  that needs an Employee/Vehicle picker (e.g. a future "TOLL ADVANCE") is a
  Head Master data change, not a code change.

  Only "Employee" and "Vehicle" are meaningful values today (matching the
  EMPLOYEEID/VEHICLEID columns already on INCOMEOREXPENSES, see
  031_income_or_expenses.sql); NULL/blank means no mapped master.

  Backfills the two existing Heads this already applied to, by exact name,
  on every database (confirmed via read-only check: both prod databases
  have a HEAD row named exactly 'SALARY ADVANCE' and 'FUEL').

  Idempotent — safe to re-run.
*/

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'HEAD' AND COLUMN_NAME = 'MAPPEDMASTER')
    ALTER TABLE dbo.HEAD ADD MAPPEDMASTER VARCHAR(20) NULL;
GO

UPDATE dbo.HEAD SET MAPPEDMASTER = 'Employee' WHERE HEADNAME = 'SALARY ADVANCE' AND MAPPEDMASTER IS NULL;
UPDATE dbo.HEAD SET MAPPEDMASTER = 'Vehicle' WHERE HEADNAME = 'FUEL' AND MAPPEDMASTER IS NULL;
GO
