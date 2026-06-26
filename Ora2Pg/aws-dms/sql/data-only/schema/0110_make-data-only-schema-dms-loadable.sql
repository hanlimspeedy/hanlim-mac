-- DMS PostgreSQL full-load uses COPY without a target column list.
-- Generated columns are skipped by PostgreSQL COPY, so columns that DMS sends
-- must be ordinary loadable columns.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_attribute
    WHERE attrelid = 'sample.order_items'::regclass
      AND attname = 'line_total'
      AND attgenerated <> ''
  ) THEN
    ALTER TABLE sample.order_items ALTER COLUMN line_total DROP EXPRESSION;
  END IF;
END $$;
