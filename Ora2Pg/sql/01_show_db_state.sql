set pagesize 200 linesize 200 heading on feedback on verify off echo off
col db_name format a20
col open_mode format a20
col instance_name format a20
col status format a20
col host_name format a40

select name as db_name, open_mode from v$database;
select instance_name, status, host_name from v$instance;

exit
