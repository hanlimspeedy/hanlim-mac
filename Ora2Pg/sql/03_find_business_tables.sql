set pagesize 200 linesize 200 heading on feedback on verify off echo off
col owner format a30
col table_name format a30

select owner, table_name
  from dba_tables
 where table_name in (
   'DEPARTMENTS',
   'EMPLOYEES',
   'PRODUCTS',
   'CUSTOMERS',
   'ORDERS',
   'ORDER_ITEMS'
 )
 order by owner, table_name;

exit
