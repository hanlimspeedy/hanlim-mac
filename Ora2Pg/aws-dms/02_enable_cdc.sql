-- =============================================================
-- 02_enable_cdc.sql   ★ DB 재시작 동반 — bin/0140 이 NOARCHIVELOG 일 때만 호출 ★
-- AWS DMS CDC(Binary Reader)용 ARCHIVELOG 전환 "전용".
-- 보충 로깅은 04_supplemental_logging.sql 가 담당(온라인, 재시작 불필요).
-- 단독 실행: sqlplus / as sysdba @aws-dms/02_enable_cdc.sql
-- 주의: ARCHIVELOG 전환 후 아카이브 redo 가 계속 쌓인다 → FRA 여유/보존(~24h) 확인.
-- =============================================================
SET DEFINE OFF
ALTER SESSION SET CONTAINER = CDB$ROOT;

-- ARCHIVELOG 전환 (인스턴스 재시작 필요; 단일 인스턴스 기준)
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;

SELECT log_mode FROM v$database;
PROMPT >> 02_enable_cdc.sql 완료: ARCHIVELOG 전환
