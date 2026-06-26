SET search_path = sample, public;

CREATE TABLE IF NOT EXISTS sample.orders (
    order_id BIGINT NOT NULL,
    customer_id INTEGER NOT NULL,
    emp_id INTEGER,
    order_date TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL,
    status CHARACTER VARYING(20),
    total_amount DOUBLE PRECISION,
    ship_ts TIMESTAMP(6) WITH TIME ZONE,
    tax_amount DOUBLE PRECISION
) PARTITION BY RANGE (order_date);

COMMENT ON TABLE sample.orders
    IS '주문 헤더. order_date 기준 RANGE 파티셔닝, 복합 PK(order_id, order_date).';
COMMENT ON COLUMN sample.orders.tax_amount
    IS 'Oracle generated column value loaded as a regular column by AWS DMS.';

CREATE TABLE IF NOT EXISTS sample.orders_p2018 PARTITION OF sample.orders
    FOR VALUES FROM (MINVALUE) TO ('2019-01-01 00:00:00');
CREATE TABLE IF NOT EXISTS sample.orders_p2019 PARTITION OF sample.orders
    FOR VALUES FROM ('2019-01-01 00:00:00') TO ('2020-01-01 00:00:00');
CREATE TABLE IF NOT EXISTS sample.orders_p2020 PARTITION OF sample.orders
    FOR VALUES FROM ('2020-01-01 00:00:00') TO ('2021-01-01 00:00:00');
CREATE TABLE IF NOT EXISTS sample.orders_p2021 PARTITION OF sample.orders
    FOR VALUES FROM ('2021-01-01 00:00:00') TO ('2022-01-01 00:00:00');
CREATE TABLE IF NOT EXISTS sample.orders_p2022 PARTITION OF sample.orders
    FOR VALUES FROM ('2022-01-01 00:00:00') TO ('2023-01-01 00:00:00');
CREATE TABLE IF NOT EXISTS sample.orders_p2023 PARTITION OF sample.orders
    FOR VALUES FROM ('2023-01-01 00:00:00') TO ('2024-01-01 00:00:00');
CREATE TABLE IF NOT EXISTS sample.orders_p2024 PARTITION OF sample.orders
    FOR VALUES FROM ('2024-01-01 00:00:00') TO ('2025-01-01 00:00:00');
CREATE TABLE IF NOT EXISTS sample.orders_p2025 PARTITION OF sample.orders
    FOR VALUES FROM ('2025-01-01 00:00:00') TO ('2026-01-01 00:00:00');
CREATE TABLE IF NOT EXISTS sample.orders_p2026 PARTITION OF sample.orders
    FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2027-01-01 00:00:00');
CREATE TABLE IF NOT EXISTS sample.orders_pmax PARTITION OF sample.orders
    FOR VALUES FROM ('2027-01-01 00:00:00') TO (MAXVALUE);

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'sample' AND table_name = 'audit_log' AND column_name = 'audit_id'
          AND data_type <> 'numeric'
    ) THEN
        ALTER TABLE sample.audit_log ALTER COLUMN audit_id DROP IDENTITY IF EXISTS;
        ALTER TABLE sample.audit_log ALTER COLUMN audit_id TYPE numeric USING audit_id::numeric;
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'sample' AND table_name = 'orders' AND column_name = 'tax_amount'
          AND is_generated = 'ALWAYS'
    ) THEN
        ALTER TABLE sample.orders DROP COLUMN tax_amount;
        ALTER TABLE sample.orders ADD COLUMN tax_amount DOUBLE PRECISION;
        COMMENT ON COLUMN sample.orders.tax_amount
            IS 'Oracle generated column value loaded as a regular column by AWS DMS.';
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'sample' AND table_name = 'order_items' AND column_name = 'line_total'
          AND is_generated = 'ALWAYS'
    ) THEN
        ALTER TABLE sample.order_items DROP COLUMN line_total;
        ALTER TABLE sample.order_items ADD COLUMN line_total NUMERIC;
        COMMENT ON COLUMN sample.order_items.line_total
            IS 'Oracle generated column value loaded as a regular column by AWS DMS.';
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'pk_ord' AND connamespace = 'sample'::regnamespace) THEN
        ALTER TABLE sample.orders ADD CONSTRAINT pk_ord PRIMARY KEY (order_id, order_date);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_ord_total' AND connamespace = 'sample'::regnamespace) THEN
        ALTER TABLE sample.orders ADD CONSTRAINT ck_ord_total CHECK (total_amount >= 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_ord_cust' AND connamespace = 'sample'::regnamespace) THEN
        ALTER TABLE sample.orders ADD CONSTRAINT fk_ord_cust FOREIGN KEY (customer_id)
            REFERENCES sample.customers (customer_id) ON DELETE NO ACTION;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_ord_emp' AND connamespace = 'sample'::regnamespace) THEN
        ALTER TABLE sample.orders ADD CONSTRAINT fk_ord_emp FOREIGN KEY (emp_id)
            REFERENCES sample.employees (emp_id) ON DELETE NO ACTION;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_item_ord' AND connamespace = 'sample'::regnamespace) THEN
        ALTER TABLE sample.order_items ADD CONSTRAINT fk_item_ord FOREIGN KEY (order_id, order_date)
            REFERENCES sample.orders (order_id, order_date) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS ix_ord_cust ON sample.orders USING BTREE (customer_id ASC);
CREATE INDEX IF NOT EXISTS ix_ord_emp ON sample.orders USING BTREE (emp_id ASC);
CREATE INDEX IF NOT EXISTS fx_ord_trunc_date ON sample.orders USING BTREE (order_date ASC);

CREATE OR REPLACE VIEW sample.v_customer_orders (order_id, order_date, customer_id, customer_name, region, status, total_amount) AS
SELECT o.order_id, o.order_date, c.customer_id, c.customer_name, c.region, o.status, o.total_amount
FROM sample.orders AS o
JOIN sample.customers AS c ON c.customer_id = o.customer_id;

CREATE OR REPLACE VIEW sample.v_monthly_sales (order_month, order_cnt, month_sales, prev_month_sales, mom_diff) AS
SELECT order_month,
       order_cnt,
       month_sales,
       LAG(month_sales) OVER (ORDER BY order_month) AS prev_month_sales,
       month_sales - LAG(month_sales) OVER (ORDER BY order_month) AS mom_diff
FROM (
    SELECT date_trunc('month', o.order_date) AS order_month,
           COUNT(*) AS order_cnt,
           SUM(o.total_amount) AS month_sales
    FROM sample.orders AS o
    GROUP BY date_trunc('month', o.order_date)
) AS monthly;

CREATE OR REPLACE VIEW sample.v_top_customers (customer_id, customer_name, region, lifetime_value, order_cnt) AS
SELECT customer_id, customer_name, region, lifetime_value, order_cnt
FROM (
    SELECT c.customer_id, c.customer_name, c.region,
           SUM(o.total_amount) AS lifetime_value,
           COUNT(o.order_id) AS order_cnt
    FROM sample.customers AS c
    JOIN sample.orders AS o ON o.customer_id = c.customer_id
    GROUP BY c.customer_id, c.customer_name, c.region
    ORDER BY SUM(o.total_amount) DESC
) AS ranked
LIMIT 100;

CREATE OR REPLACE VIEW sample.v_org_chart (lvl, emp_id, indented_name, manager_id, path, is_leaf, top_manager) AS
WITH RECURSIVE org (lvl, emp_id, indented_name, manager_id, path, is_leaf, top_manager) AS (
    SELECT 1::numeric AS lvl,
           e.emp_id,
           e.emp_name::text AS indented_name,
           e.manager_id,
           e.emp_name::text AS path,
           CASE WHEN EXISTS (SELECT 1 FROM sample.employees AS child WHERE child.manager_id = e.emp_id) THEN 0 ELSE 1 END AS is_leaf,
           e.emp_name::text AS top_manager
    FROM sample.employees AS e
    WHERE e.manager_id IS NULL
    UNION ALL
    SELECT (org.lvl + 1)::numeric,
           e.emp_id,
           (LPAD('', ((org.lvl + 1 - 1) * 2)::integer) || e.emp_name)::text,
           e.manager_id,
           (org.path || ' / ' || e.emp_name)::text,
           CASE WHEN EXISTS (SELECT 1 FROM sample.employees AS child WHERE child.manager_id = e.emp_id) THEN 0 ELSE 1 END,
           org.top_manager
    FROM sample.employees AS e
    JOIN org ON org.emp_id = e.manager_id
)
SELECT lvl, emp_id, indented_name, manager_id, path, is_leaf, top_manager
FROM org;

CREATE OR REPLACE VIEW sample.v_product_sales_rank (product_id, product_name, category, total_sales, cat_rank, overall_rank, pct_in_category) AS
SELECT p.product_id,
       p.product_name,
       p.category,
       SUM(i.line_amount) AS total_sales,
       RANK() OVER (PARTITION BY p.category ORDER BY SUM(i.line_amount) DESC) AS cat_rank,
       ROW_NUMBER() OVER (ORDER BY SUM(i.line_amount) DESC) AS overall_rank,
       ROUND((aws_oracle_ext.ratio_to_report(SUM(i.line_amount), SUM(SUM(i.line_amount)) OVER (PARTITION BY p.category)) * 100)::numeric, 2) AS pct_in_category
FROM sample.products AS p
JOIN sample.order_items AS i ON i.product_id = p.product_id
GROUP BY p.product_id, p.product_name, p.category;

DROP TRIGGER IF EXISTS trg_order_validate ON sample.orders;
CREATE TRIGGER trg_order_validate
BEFORE INSERT OR UPDATE ON sample.orders
FOR EACH ROW EXECUTE PROCEDURE sample.trg_order_validate$orders();

DROP TRIGGER IF EXISTS trg_vco_upd ON sample.v_customer_orders;
CREATE TRIGGER trg_vco_upd
INSTEAD OF UPDATE ON sample.v_customer_orders
FOR EACH ROW EXECUTE PROCEDURE sample.trg_vco_upd$v_customer_orders();
