-- =============================================================
-- 04_supplemental_logging.sql   (온라인, 재시작 불필요, 멱등)
-- AWS DMS CDC 보충 로깅:
--   A) DB-level: 최소 + PRIMARY KEY  (CDB$ROOT)
--   B) 테이블별: PK 있으면 PRIMARY KEY COLUMNS, 없으면 ALL COLUMNS (PDB)
--      대상은 DMS selection 과 동일하게 DBA_TABLES 에서 도출(SAMPLE.% , MLOG$% 제외).
-- 실행: bin/0140_enable-oracle-cdc-redo (→ bin/run-remote-sqlplus-sysdba)
-- =============================================================
SET SERVEROUTPUT ON
SET DEFINE OFF

-- A) DB-level (CDB$ROOT). 이미 켜졌으면 스킵(ORA-32588 회피).
ALTER SESSION SET CONTAINER = CDB$ROOT;
DECLARE
  v_min VARCHAR2(32);
  v_pk  VARCHAR2(32);
BEGIN
  SELECT supplemental_log_data_min, supplemental_log_data_pk INTO v_min, v_pk FROM v$database;
  IF v_min NOT IN ('YES', 'IMPLICIT') THEN
    EXECUTE IMMEDIATE 'ALTER DATABASE ADD SUPPLEMENTAL LOG DATA';
    DBMS_OUTPUT.PUT_LINE('added: minimal supplemental log data');
  END IF;
  IF v_pk <> 'YES' THEN
    EXECUTE IMMEDIATE 'ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (PRIMARY KEY) COLUMNS';
    DBMS_OUTPUT.PUT_LINE('added: PK supplemental log data');
  END IF;
END;
/

-- B) 테이블별 (PDB). PK 유무로 PRIMARY KEY / ALL COLUMNS 선택, 이미 있으면 스킵.
ALTER SESSION SET CONTAINER = ORCLPDB1;
DECLARE
  v_has_pk  NUMBER;
  v_has_grp NUMBER;
BEGIN
  FOR t IN (SELECT table_name FROM dba_tables
             WHERE owner = 'SAMPLE'
               AND table_name NOT LIKE 'MLOG$%'
               AND temporary = 'N'
               AND nested = 'NO') LOOP
    SELECT COUNT(*) INTO v_has_pk FROM dba_constraints
      WHERE owner = 'SAMPLE' AND table_name = t.table_name AND constraint_type = 'P';
    IF v_has_pk > 0 THEN
      SELECT COUNT(*) INTO v_has_grp FROM dba_log_groups
        WHERE owner = 'SAMPLE' AND table_name = t.table_name AND log_group_type = 'PRIMARY KEY LOGGING';
      IF v_has_grp = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE SAMPLE."' || t.table_name || '" ADD SUPPLEMENTAL LOG DATA (PRIMARY KEY) COLUMNS';
        DBMS_OUTPUT.PUT_LINE('PK logging : ' || t.table_name);
      END IF;
    ELSE
      SELECT COUNT(*) INTO v_has_grp FROM dba_log_groups
        WHERE owner = 'SAMPLE' AND table_name = t.table_name AND log_group_type = 'ALL COLUMN LOGGING';
      IF v_has_grp = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE SAMPLE."' || t.table_name || '" ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS';
        DBMS_OUTPUT.PUT_LINE('ALL logging: ' || t.table_name);
      END IF;
    END IF;
  END LOOP;
END;
/

-- C) 확인
ALTER SESSION SET CONTAINER = CDB$ROOT;
SELECT log_mode, supplemental_log_data_min, supplemental_log_data_pk FROM v$database;
ALTER SESSION SET CONTAINER = ORCLPDB1;
SELECT table_name, log_group_type FROM dba_log_groups WHERE owner = 'SAMPLE' ORDER BY 1, 2;

PROMPT >> 04_supplemental_logging.sql 완료: DB-level + 테이블별 보충 로깅
