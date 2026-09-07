/*
  Backfills dbo.PRODUCT_DETAILS for products that already existed in
  dbo.PRODUCT before this table did — every legacy desktop-created
  product on db_ams_erp and DB_AMS_ERP_SMS has zero rows here (confirmed
  by direct read-only check on 2026-09-07: 38 products on db_ams_erp, 14
  on DB_AMS_ERP_SMS, 0 PRODUCT_DETAILS rows on either). Only the mobile
  app's own ProductService.CreateAsync writes this table today (on
  creating a NEW product), so nothing has ever populated it for products
  the desktop app already had.

  PRODUCTDETAILID is a new IDENTITY column added directly on
  db_ams_erp/DB_AMS_ERP_SMS (not yet on db_ams_pos_test) — left out of
  the INSERT column list here since it auto-generates.

  Column mapping mirrors ProductService.CreateAsync's own convention
  (SALE_RATE = PRODUCT.MRP, VALID = 1) but — since these are real
  historical products, not blank new ones — uses PRODUCT's own
  RETAILRATE/PRATE instead of hardcoding 0, and PRODUCT.USERCREATEDDATE
  instead of "now" for VALID_START_DATE/CREATE_DATE, so the backfilled
  row reflects when the product actually entered the system.
  CREATE_USER = 'MIGRATION' marks these rows as backfilled rather than
  created through the app, for anyone auditing PRODUCT_DETAILS later.

  Idempotent (NOT EXISTS guard) — safe to re-run, and only inserts for
  products that still have no PRODUCT_DETAILS row at all.
*/

INSERT INTO dbo.PRODUCT_DETAILS
    (PRODUCTID, PRODUCTNAME, SALE_RATE, RETAIL_RATE, PURCHASE_RATE,
     VALID_START_DATE, VALID_END_DATE, CREATE_DATE, CREATE_USER, MODIFIED_DATE, MODIFIED_USER, VALID)
SELECT
    PR.PRODUCTID, PR.PRODUCTNAME, PR.MRP, ISNULL(PR.RETAILRATE, 0), ISNULL(PR.PRATE, 0),
    ISNULL(PR.USERCREATEDDATE, GETDATE()), NULL, ISNULL(PR.USERCREATEDDATE, GETDATE()), 'MIGRATION', NULL, NULL, 1
FROM dbo.PRODUCT PR
WHERE PR.STATUS = 1
  AND NOT EXISTS (SELECT 1 FROM dbo.PRODUCT_DETAILS PD WHERE PD.PRODUCTID = PR.PRODUCTID);
