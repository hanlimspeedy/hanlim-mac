-- =============================================================
-- 02_disable_archivelog.sql   ★ DB 재시작 동반 ★
-- CDC 종료 후 ARCHIVELOG -> NOARCHIVELOG 로 되돌린다(아카이브 redo 누적 중단).
-- bin/9200 --disable-archivelog 가 호출. 단독: sqlplus / as sysdba @aws-dms/02_disable_archivelog.sql
-- =============================================================
SET DEFINE OFF
ALTER SESSION SET CONTAINER = CDB$ROOT;

SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE NOARCHIVELOG;
ALTER DATABASE OPEN;

SELECT log_mode FROM v$database;
PROMPT >> 02_disable_archivelog.sql 완료: NOARCHIVELOG 전환
