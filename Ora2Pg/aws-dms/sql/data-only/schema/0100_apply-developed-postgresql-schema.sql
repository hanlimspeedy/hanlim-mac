-- Final data-only migration target schema for SAMPLE.
--
-- This is the PostgreSQL-owned schema baseline used before the data-only DMS
-- full-load-and-cdc task. DMS loads rows for base tables only; PostgreSQL
-- objects such as sequences, constraints, indexes, views, and materialized views
-- are maintained here.

CREATE SCHEMA IF NOT EXISTS sample;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SEQUENCE IF NOT EXISTS sample.seq_customer START WITH 1 INCREMENT BY 1 CACHE 20;
CREATE SEQUENCE IF NOT EXISTS sample.seq_employee START WITH 1 INCREMENT BY 1 CACHE 1;
CREATE SEQUENCE IF NOT EXISTS sample.seq_item START WITH 1 INCREMENT BY 1 CACHE 100;
CREATE SEQUENCE IF NOT EXISTS sample.seq_order START WITH 1 INCREMENT BY 1 CACHE 50;
CREATE SEQUENCE IF NOT EXISTS sample.seq_product START WITH 1 INCREMENT BY 1 CACHE 20;
CREATE SEQUENCE IF NOT EXISTS sample.audit_log_audit_id_seq START WITH 1 INCREMENT BY 1 CACHE 20;

CREATE TABLE IF NOT EXISTS sample.departments (
  dept_id integer NOT NULL DEFAULT nextval('sample.seq_employee'),
  dept_name varchar(50) NOT NULL,
  location varchar(100),
  CONSTRAINT pk_dept PRIMARY KEY (dept_id)
);

CREATE TABLE IF NOT EXISTS sample.employees (
  emp_id integer NOT NULL DEFAULT nextval('sample.seq_employee'),
  emp_name varchar(100) NOT NULL,
  dept_id integer,
  job_title varchar(50),
  salary double precision,
  hire_date timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
  manager_id integer,
  commission_pct double precision,
  email varchar(120),
  CONSTRAINT pk_emp PRIMARY KEY (emp_id),
  CONSTRAINT ck_salary CHECK (salary > 0),
  CONSTRAINT ck_emp_comm CHECK (commission_pct BETWEEN 0 AND 0.4),
  CONSTRAINT fk_emp_dept FOREIGN KEY (dept_id) REFERENCES sample.departments(dept_id),
  CONSTRAINT fk_emp_mgr FOREIGN KEY (manager_id) REFERENCES sample.employees(emp_id)
);

CREATE TABLE IF NOT EXISTS sample.employee_targets (
  emp_id integer NOT NULL,
  target_year integer NOT NULL,
  target_amount numeric(14,2),
  CONSTRAINT pk_emp_target PRIMARY KEY (emp_id, target_year),
  CONSTRAINT ck_tgt_amt CHECK (target_amount >= 0),
  CONSTRAINT fk_tgt_emp FOREIGN KEY (emp_id) REFERENCES sample.employees(emp_id)
);

CREATE TABLE IF NOT EXISTS sample.region_dim (
  region_code varchar(20) NOT NULL,
  region_name varchar(40) NOT NULL,
  manager_emp_id integer,
  CONSTRAINT pk_region PRIMARY KEY (region_code),
  CONSTRAINT fk_region_mgr FOREIGN KEY (manager_emp_id) REFERENCES sample.employees(emp_id)
);

CREATE TABLE IF NOT EXISTS sample.customers (
  customer_id integer NOT NULL DEFAULT nextval('sample.seq_customer'),
  customer_name varchar(100) NOT NULL,
  email varchar(120),
  phone varchar(30),
  city varchar(50),
  region varchar(20),
  signup_date timestamp(0) without time zone,
  is_active integer DEFAULT 1,
  notes text,
  CONSTRAINT pk_cust PRIMARY KEY (customer_id),
  CONSTRAINT uq_cust_email UNIQUE (email),
  CONSTRAINT ck_cust_active CHECK (is_active IN (0, 1))
);

CREATE TABLE IF NOT EXISTS sample.products (
  product_id integer NOT NULL DEFAULT nextval('sample.seq_product'),
  product_name varchar(100) NOT NULL,
  category varchar(50),
  price double precision,
  stock_qty integer DEFAULT 0,
  created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP,
  description text,
  spec_blob bytea,
  CONSTRAINT pk_prod PRIMARY KEY (product_id),
  CONSTRAINT ck_price CHECK (price >= 0)
);

CREATE TABLE IF NOT EXISTS sample.order_status_dim (
  status_code varchar(20) NOT NULL,
  status_label varchar(40) NOT NULL,
  is_final integer DEFAULT 0,
  CONSTRAINT pk_status PRIMARY KEY (status_code),
  CONSTRAINT ck_status_final CHECK (is_final IN (0, 1))
);

CREATE TABLE IF NOT EXISTS sample.tax_rates (
  region varchar(20) NOT NULL,
  rate double precision,
  valid_from timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_tax PRIMARY KEY (region),
  CONSTRAINT ck_tax_rate CHECK (rate BETWEEN 0 AND 1)
);

CREATE TABLE IF NOT EXISTS sample.orders (
  order_id bigint NOT NULL DEFAULT nextval('sample.seq_order'),
  customer_id integer NOT NULL,
  emp_id integer,
  order_date timestamp(0) without time zone NOT NULL,
  status varchar(20),
  total_amount double precision,
  ship_ts timestamp(6) with time zone,
  tax_amount double precision,
  CONSTRAINT pk_ord PRIMARY KEY (order_id, order_date),
  CONSTRAINT ck_ord_total CHECK (total_amount >= 0),
  CONSTRAINT fk_ord_cust FOREIGN KEY (customer_id) REFERENCES sample.customers(customer_id),
  CONSTRAINT fk_ord_emp FOREIGN KEY (emp_id) REFERENCES sample.employees(emp_id)
) PARTITION BY RANGE (order_date);

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

CREATE TABLE IF NOT EXISTS sample.order_items (
  item_id bigint NOT NULL DEFAULT nextval('sample.seq_item'),
  order_id bigint NOT NULL,
  order_date timestamp(0) without time zone NOT NULL,
  product_id integer NOT NULL,
  quantity integer,
  unit_price double precision,
  line_amount double precision,
  line_total double precision,
  CONSTRAINT pk_item PRIMARY KEY (item_id),
  CONSTRAINT ck_item_qty CHECK (quantity > 0),
  CONSTRAINT ck_item_unit CHECK (unit_price >= 0),
  CONSTRAINT ck_item_line CHECK (line_amount >= 0),
  CONSTRAINT fk_item_order FOREIGN KEY (order_id, order_date) REFERENCES sample.orders(order_id, order_date) ON DELETE CASCADE,
  CONSTRAINT fk_item_prod FOREIGN KEY (product_id) REFERENCES sample.products(product_id)
);

CREATE TABLE IF NOT EXISTS sample.audit_log (
  audit_id numeric NOT NULL DEFAULT nextval('sample.audit_log_audit_id_seq'),
  table_name varchar(30) NOT NULL,
  action_type varchar(10),
  pk_value varchar(100),
  changed_by varchar(40) DEFAULT SESSION_USER,
  changed_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP,
  old_row text,
  new_row text,
  CONSTRAINT pk_audit PRIMARY KEY (audit_id),
  CONSTRAINT ck_audit_act CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE'))
);

ALTER SEQUENCE sample.seq_customer OWNED BY sample.customers.customer_id;
ALTER SEQUENCE sample.seq_employee OWNED BY sample.employees.emp_id;
ALTER SEQUENCE sample.seq_item OWNED BY sample.order_items.item_id;
ALTER SEQUENCE sample.seq_order OWNED BY sample.orders.order_id;
ALTER SEQUENCE sample.seq_product OWNED BY sample.products.product_id;
ALTER SEQUENCE sample.audit_log_audit_id_seq OWNED BY sample.audit_log.audit_id;

CREATE INDEX IF NOT EXISTS ix_emp_dept ON sample.employees (dept_id);
CREATE INDEX IF NOT EXISTS ix_emp_mgr ON sample.employees (manager_id);
CREATE INDEX IF NOT EXISTS fx_cust_email_up ON sample.customers (upper(email));
CREATE INDEX IF NOT EXISTS ix_ord_cust ON sample.orders (customer_id);
CREATE INDEX IF NOT EXISTS ix_ord_emp ON sample.orders (emp_id);
CREATE INDEX IF NOT EXISTS ix_ord_date ON sample.orders (order_date);
CREATE INDEX IF NOT EXISTS ix_item_ord ON sample.order_items (order_id, order_date);
CREATE INDEX IF NOT EXISTS ix_item_prod ON sample.order_items (product_id);

CREATE OR REPLACE VIEW sample.v_customer_orders AS
SELECT o.order_id, o.order_date, c.customer_id, c.customer_name, c.region, o.status, o.total_amount
FROM sample.orders o
JOIN sample.customers c ON c.customer_id = o.customer_id;

CREATE OR REPLACE VIEW sample.v_employee_details AS
SELECT e.emp_id, e.emp_name, d.dept_name, e.job_title, e.salary, e.commission_pct,
       m.emp_name AS manager_name, e.hire_date
FROM sample.employees e
LEFT JOIN sample.departments d ON d.dept_id = e.dept_id
LEFT JOIN sample.employees m ON m.emp_id = e.manager_id;

CREATE OR REPLACE VIEW sample.v_monthly_sales AS
SELECT date_trunc('month', o.order_date)::date AS order_month,
       count(*) AS order_cnt,
       sum(o.total_amount) AS month_sales
FROM sample.orders o
GROUP BY date_trunc('month', o.order_date)::date;

CREATE OR REPLACE VIEW sample.v_order_products AS
SELECT i.order_id,
       count(*) AS line_cnt,
       string_agg(p.product_name, ', ' ORDER BY p.product_name) AS products,
       sum(i.line_amount) AS order_total
FROM sample.order_items i
JOIN sample.products p ON p.product_id = i.product_id
GROUP BY i.order_id;

CREATE OR REPLACE VIEW sample.v_top_customers AS
SELECT c.customer_id, c.customer_name, c.region,
       sum(o.total_amount) AS lifetime_value,
       count(o.order_id) AS order_cnt
FROM sample.customers c
JOIN sample.orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name, c.region
ORDER BY sum(o.total_amount) DESC
LIMIT 100;

CREATE MATERIALIZED VIEW IF NOT EXISTS sample.mv_monthly_revenue AS
SELECT date_trunc('month', order_date)::date AS order_month,
       count(*) AS order_cnt,
       sum(total_amount) AS revenue
FROM sample.orders
GROUP BY date_trunc('month', order_date)::date
WITH NO DATA;

CREATE MATERIALIZED VIEW IF NOT EXISTS sample.mv_product_qty AS
SELECT product_id,
       count(*) AS line_cnt,
       sum(quantity) AS total_qty,
       count(quantity) AS cnt_qty,
       sum(line_amount) AS total_amount,
       count(line_amount) AS cnt_amount
FROM sample.order_items
GROUP BY product_id
WITH NO DATA;
