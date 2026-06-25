-- =============================================================
-- 02_enable_cdc.sql   ★ DB 재시작 동반 — 필요할 때만 수동 실행 ★
-- AWS DMS 의 CDC(변경데이터캡처, ongoing replication)용 전제조건.
-- Full Load / Schema Conversion 만 쓸 경우 실행 불필요.
-- 실행: sqlplus / as sysdba @migration/aws-dms/02_enable_cdc.sql
-- =============================================================
SET DEFINE OFF
ALTER SESSION SET CONTAINER = CDB$ROOT;

-- 1) ARCHIVELOG 전환 (인스턴스 재시작 필요)
--    현재 NOARCHIVELOG. 아래는 단일 인스턴스 기준 절차.
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;

-- 2) 보충 로깅 (온라인, 재시작 불필요 — 1) 이후 적용)
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (PRIMARY KEY) COLUMNS;
-- PK/UNIQUE 없는 테이블이 있으면 테이블별 ALL COLUMNS 보충로깅을 추가:
--   ALTER TABLE sample.<table> ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- 3) 확인
SELECT log_mode, supplemental_log_data_min, supplemental_log_data_pk FROM v$database;

PROMPT >> 02_enable_cdc.sql 완료: ARCHIVELOG + 보충로깅 (CDC 준비)
