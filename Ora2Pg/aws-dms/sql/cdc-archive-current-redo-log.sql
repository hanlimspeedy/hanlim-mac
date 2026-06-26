-- cdc-archive-current-redo-log.sql
-- Force the current online redo log to be archived (synchronous).
-- A freshly-ARCHIVELOG'd or low-activity DB produces no archived logs, which blocks
-- AWS DMS Binary Reader CDC startup ("Cannot find any Archived Redo log in the current
-- incarnation"). Also used to flush a test change to an archived log so CDC captures it.
-- Used by: bin/0140 (seed at CDC enable) and bin/1160 (flush each validation change).
SET DEFINE OFF
ALTER SESSION SET CONTAINER = CDB$ROOT;
ALTER SYSTEM ARCHIVE LOG CURRENT;
SELECT 'ARCHLOGS:' || COUNT(*) FROM v$archived_log;
PROMPT >> cdc-archive-current-redo-log.sql 완료: 현재 redo 로그 아카이브
