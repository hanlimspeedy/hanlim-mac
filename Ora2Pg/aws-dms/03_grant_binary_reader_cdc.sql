-- =============================================================
-- 03_grant_binary_reader_cdc.sql
-- AWS DMS CDC(Binary Reader) 소스 계정 C##DMS 추가 권한.
-- PDB 는 LogMiner 연결 불가 → Binary Reader 필수(AWS 문서). 멱등(GRANT 는 반복 무해).
-- 실행: bin/0120_grant-oracle-cdc-privileges (→ bin/run-remote-sqlplus-sysdba)
-- =============================================================
SET DEFINE OFF

-- A) Binary Reader 시스템 권한 (CDB 공통 사용자, CONTAINER=ALL)
ALTER SESSION SET CONTAINER = CDB$ROOT;
GRANT SELECT ON V_$TRANSPORTABLE_PLATFORM TO C##DMS CONTAINER=ALL;
GRANT CREATE ANY DIRECTORY                TO C##DMS CONTAINER=ALL;
GRANT EXECUTE ON DBMS_FILE_TRANSFER       TO C##DMS CONTAINER=ALL;
GRANT EXECUTE ON DBMS_FILE_GROUP          TO C##DMS CONTAINER=ALL;
GRANT SELECT ON SYS.DBA_DIRECTORIES       TO C##DMS CONTAINER=ALL;

-- B) CDC 검증(bin/1160)용 센티넬 DML 권한 — PDB-로컬 객체이므로 PDB 안에서 부여.
--    트리거 없는 참조테이블 SAMPLE.REGION_DIM 사용.
ALTER SESSION SET CONTAINER = ORCLPDB1;
GRANT INSERT, UPDATE, DELETE ON SAMPLE.REGION_DIM TO C##DMS;

PROMPT >> 03_grant_binary_reader_cdc.sql 완료: Binary Reader 권한 + 센티넬 DML 권한
