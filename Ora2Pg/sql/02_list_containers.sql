set pagesize 200 linesize 200 heading on feedback on verify off echo off
col name format a30
col open_mode format a20
col cdb format a5
col con_name format a30

select name, cdb from v$database;
select sys_context('USERENV', 'CON_NAME') as con_name from dual;

select name, open_mode
  from v$pdbs
 order by name;

exit
