/*
  dbo.SALES_TAXDETAILS — per-product GST breakdown for a Sales entry,
  alongside (not replacing) the tax columns already on SALES_DETAILS.
  Mobile's SalesEntryService.CreateAsync now writes one row here per
  SALES_DETAILS line, same as the desktop app's own sp_SalesOrderTosales
  already does for desktop-created Sales entries.

  Already exists with this exact shape on both production tenant
  databases (db_ams_erp, DB_AMS_ERP_SMS) — created by the desktop app's
  own install, never run against db_ams_pos_test. This just catches test
  up; nothing to run against prod.

  No PRIMARY KEY/FOREIGN KEY here, matching prod's own definition of this
  table exactly (checked directly against both tenants).

  Idempotent — safe to re-run.
*/

IF OBJECT_ID(N'dbo.SALES_TAXDETAILS', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SALES_TAXDETAILS
    (
        SALESID           INT           NOT NULL CONSTRAINT DF_SALES_TAXDETAILS_SALESID DEFAULT 0,
        SALESTAXDETAILSID INT           IDENTITY(1,1) NOT NULL,
        PRODUCTID         INT           NOT NULL CONSTRAINT DF_SALES_TAXDETAILS_PRODUCTID DEFAULT 0,
        CGSTPERCENTAGE    NUMERIC(18,2) NOT NULL CONSTRAINT DF_SALES_TAXDETAILS_CGSTPERCENTAGE DEFAULT 0,
        CGSTAMOUNT        NUMERIC(18,2) NOT NULL CONSTRAINT DF_SALES_TAXDETAILS_CGSTAMOUNT DEFAULT 0,
        SGSTPERCENTAGE    NUMERIC(18,2) NOT NULL CONSTRAINT DF_SALES_TAXDETAILS_SGSTPERCENTAGE DEFAULT 0,
        SGSTAMOUNT        NUMERIC(18,2) NOT NULL CONSTRAINT DF_SALES_TAXDETAILS_SGSTAMOUNT DEFAULT 0,
        IGSTPERCENTAGE    NUMERIC(18,2) NOT NULL CONSTRAINT DF_SALES_TAXDETAILS_IGSTPERCENTAGE DEFAULT 0,
        IGSTAMOUNT        NUMERIC(18,2) NOT NULL CONSTRAINT DF_SALES_TAXDETAILS_IGSTAMOUNT DEFAULT 0
    );
END
GO
