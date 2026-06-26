-- Final cutover hook for PostgreSQL-developed materialized views.
-- The data-only DMS task loads base table rows only; refresh derived objects here.

REFRESH MATERIALIZED VIEW sample.mv_monthly_revenue;
REFRESH MATERIALIZED VIEW sample.mv_product_qty;
