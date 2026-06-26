\set ON_ERROR_STOP off
\pset tuples_only on
\pset pager off

SET statement_timeout = '10s';
SET search_path TO :"schema", public;

SELECT customer_id AS smoke_customer_id FROM :"schema".customers ORDER BY customer_id LIMIT 1 \gset
SELECT emp_id AS smoke_emp_id FROM :"schema".employees ORDER BY emp_id LIMIT 1 \gset
SELECT dept_id AS smoke_dept_id FROM :"schema".departments ORDER BY dept_id LIMIT 1 \gset
SELECT region_name AS smoke_region FROM :"schema".region_dim ORDER BY region_name LIMIT 1 \gset

\echo routine_smoke common.fn_format_currency
SELECT :"schema".fn_format_currency(1234);

\echo routine_smoke common.get_emp_tenure
SELECT :"schema".get_emp_tenure(:smoke_emp_id);

\echo routine_smoke common.log_audit_rollback
BEGIN;
CALL :"schema".log_audit('ROUTINE_SMOKE', 'TEST', '0', NULL, NULL);
ROLLBACK;

\echo routine_smoke common.prc_upsert_product_rollback
BEGIN;
CALL :"schema".prc_upsert_product(-1450, 'ROUTINE_SMOKE', 'TEST', 1);
ROLLBACK;

\echo routine_smoke common.prc_with_gtt_rollback
BEGIN;
CALL :"schema".prc_with_gtt(:smoke_customer_id);
ROLLBACK;

\if :ora2pg
\echo routine_smoke ora2pg.pkg_order_calc_tax
SELECT :"schema".pkg_order_calc_tax(1000, :'smoke_region');

\echo routine_smoke ora2pg.pkg_order_apply_discount
SELECT :"schema".pkg_order_apply_discount(:smoke_customer_id, 1000);

\echo routine_smoke ora2pg.pkg_report_fn_dept_headcount
SELECT :"schema".pkg_report_fn_dept_headcount((:smoke_dept_id)::smallint);

\echo routine_smoke ora2pg.pkg_hr_give_raise_rollback
BEGIN;
CALL :"schema".pkg_hr_give_raise(:smoke_emp_id, 1);
ROLLBACK;

\echo routine_smoke ora2pg.pkg_report_print_dept_summary
CALL :"schema".pkg_report_print_dept_summary();
\endif

\if :awsdms
\echo routine_smoke awsdms.pkg_order_calc_tax
SELECT :"schema"."pkg_order$calc_tax"(1000, :'smoke_region');

\echo routine_smoke awsdms.pkg_order_apply_discount
SELECT :"schema"."pkg_order$apply_discount"(:smoke_customer_id, 1000);

\echo routine_smoke awsdms.pkg_report_fn_dept_headcount
SELECT :"schema"."pkg_report$fn_dept_headcount"(:smoke_dept_id);

\echo routine_smoke awsdms.pkg_hr_give_raise_rollback
BEGIN;
CALL :"schema"."pkg_hr$give_raise"(:smoke_emp_id, 1);
ROLLBACK;

\echo routine_smoke awsdms.pkg_report_print_dept_summary
CALL :"schema"."pkg_report$print_dept_summary"();
\endif
