-- revert-cdc-oracle.sql
-- 0120/0140 이 만든 Oracle CDC 변경을 ONLINE 으로 되돌린다(재시작 없음):
--   - C##DMS 의 Binary Reader CDC 권한 + 센티넬 DML 권한 revoke
--   - DB-level + 테이블별 보충 로깅 drop
--   - DMS 가 CDC 프로브 중 만든 awsdms_dir_test 디렉터리 drop
-- ARCHIVELOG 자체는 재시작이 필요하므로 bin/9200 --disable-archivelog 가 별도 처리.
-- 멱등: 각 동작은 "없음/미부여" 오류를 무시한다.
SET SERVEROUTPUT ON
SET DEFINE OFF

-- A) CDB$ROOT: Binary Reader 시스템 권한 revoke
ALTER SESSION SET CONTAINER = CDB$ROOT;
DECLARE
  PROCEDURE try(p VARCHAR2) IS
  BEGIN EXECUTE IMMEDIATE p; DBMS_OUTPUT.PUT_LINE('OK   : '||p);
  EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('skip('||SQLCODE||'): '||p); END;
BEGIN
  try('REVOKE SELECT ON V_$TRANSPORTABLE_PLATFORM FROM C##DMS');
  try('REVOKE CREATE ANY DIRECTORY FROM C##DMS');
  try('REVOKE EXECUTE ON DBMS_FILE_TRANSFER FROM C##DMS');
  try('REVOKE EXECUTE ON DBMS_FILE_GROUP FROM C##DMS');
  try('REVOKE SELECT ON SYS.DBA_DIRECTORIES FROM C##DMS');
END;
/

-- B) PDB: 테이블별 보충 로깅 drop + 디렉터리 drop + 센티넬 권한 revoke
ALTER SESSION SET CONTAINER = ORCLPDB1;
DECLARE
  PROCEDURE try(p VARCHAR2) IS
  BEGIN EXECUTE IMMEDIATE p; DBMS_OUTPUT.PUT_LINE('OK   : '||p);
  EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('skip('||SQLCODE||'): '||p); END;
BEGIN
  FOR g IN (SELECT table_name, log_group_type FROM dba_log_groups WHERE owner = 'SAMPLE') LOOP
    IF g.log_group_type = 'PRIMARY KEY LOGGING' THEN
      try('ALTER TABLE SAMPLE."'||g.table_name||'" DROP SUPPLEMENTAL LOG DATA (PRIMARY KEY) COLUMNS');
    ELSIF g.log_group_type = 'ALL COLUMN LOGGING' THEN
      try('ALTER TABLE SAMPLE."'||g.table_name||'" DROP SUPPLEMENTAL LOG DATA (ALL) COLUMNS');
    END IF;
  END LOOP;
  try('DROP DIRECTORY awsdms_dir_test');
  try('REVOKE INSERT, UPDATE, DELETE ON SAMPLE.REGION_DIM FROM C##DMS');
END;
/

-- C) CDB$ROOT: DB-level 보충 로깅 drop (테이블별 이후)
ALTER SESSION SET CONTAINER = CDB$ROOT;
DECLARE
  PROCEDURE try(p VARCHAR2) IS
  BEGIN EXECUTE IMMEDIATE p; DBMS_OUTPUT.PUT_LINE('OK   : '||p);
  EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('skip('||SQLCODE||'): '||p); END;
BEGIN
  try('ALTER DATABASE DROP SUPPLEMENTAL LOG DATA (PRIMARY KEY) COLUMNS');
  try('ALTER DATABASE DROP SUPPLEMENTAL LOG DATA');
END;
/

SELECT 'STATE:'||log_mode||':'||supplemental_log_data_min||':'||supplemental_log_data_pk FROM v$database;
PROMPT >> revert-cdc-oracle.sql 완료(온라인). ARCHIVELOG 는 bin/9200 --disable-archivelog 로 별도.
