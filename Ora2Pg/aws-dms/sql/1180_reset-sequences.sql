-- 1180_reset-sequences.sql
-- 컷오버 후 타깃 시퀀스를 소유 컬럼의 MAX 값으로 보정(NEXTVAL 충돌 방지).
-- 테이블/시퀀스명을 하드코딩하지 않고 pg_depend 로 "컬럼이 소유한" 시퀀스를 도출.
-- (identity='i', owned-by='a' 둘 다 포함. 0850 에서 numeric 으로 바뀐 audit_log 처럼
--  시퀀스가 없는 컬럼은 대상에서 자연히 제외된다.)
-- 호출: psql ... -v schema=<lc-schema> -f sql/1180_reset-sequences.sql
-- 주의: psql 변수(:'schema')는 $$...$$ 달러인용 블록 안에서 치환되지 않으므로,
--       블록 밖에서 세션 GUC(mig.schema)에 담아 블록 안에서 current_setting 으로 읽는다.
\set ON_ERROR_STOP on
SELECT set_config('mig.schema', :'schema', false);
DO $$
DECLARE
  r   record;
  mx  bigint;
  sch text := current_setting('mig.schema');
BEGIN
  FOR r IN
    SELECT n.nspname AS sch, s.relname AS seq, t.relname AS tbl, a.attname AS col
    FROM pg_class s
    JOIN pg_namespace n ON n.oid = s.relnamespace
    JOIN pg_depend d    ON d.objid = s.oid AND d.classid = 'pg_class'::regclass AND d.deptype IN ('a', 'i')
    JOIN pg_class t     ON t.oid = d.refobjid
    JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = d.refobjsubid
    WHERE s.relkind = 'S'
      AND n.nspname = sch
  LOOP
    EXECUTE format('SELECT COALESCE(MAX(%I), 0) FROM %I.%I', r.col, r.sch, r.tbl) INTO mx;
    PERFORM setval(format('%I.%I', r.sch, r.seq), GREATEST(mx, 1), mx > 0);
    RAISE NOTICE 'reset %.% -> % (from %.%.%)', r.sch, r.seq, GREATEST(mx, 1), r.sch, r.tbl, r.col;
  END LOOP;
END $$;
