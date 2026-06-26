# Ora2Pg Local Workspace

See [HANDOFF.md](/home/ubuntu/root/Ora2Pg/HANDOFF.md:1) first for project context, current state, and operational rules.

This workspace is set up to run Oracle client tools and `ora2pg` on the current server, not on `192.168.29.248`.

## Installed locally

- Oracle Instant Client 19.31 at `/opt/oracle/instantclient_19_31`
- `sqlplus`
- Perl `DBD::Oracle`
- Perl `DBD::Pg`
- `ora2pg` v25.0 under `/home/ubuntu/perl5/usr/local/bin/ora2pg`
- SSH key-based login to `root@192.168.29.248`
- PostgreSQL 16 server (native apt) on `127.0.0.1:5432` — migration target `sample_pg`
- IvorySQL 3.4 (PG 16 based) in Docker on `127.0.0.1:5433` — migration target `sample_ivory`

## Migration targets (PostgreSQL vs IvorySQL)

The same Ora2Pg export is loaded into two targets and compared. See
[MIGRATION_TEST.md](MIGRATION_TEST.md) for the full, reproducible procedure
(steps 10–23) and the rationale behind every configuration choice.

## AWS DMS path (alternative)

`aws-dms/` holds the AWS DMS / Schema Conversion access guide for reaching this
on-prem Oracle from AWS — connection endpoints, the `C##DMS` / `C##DMS_SC`
accounts, and CDC prerequisites. Moved here from the `oracle-db` repo on 248.
Ora2Pg (above) is full-load/offline only; for incremental **CDC** use this AWS DMS
path (`MIGRATION_TYPE=full-load-and-cdc`). Open-source CDC would need a separate tool
(Debezium/SymmetricDS) — see [MIGRATION_TEST.md](MIGRATION_TEST.md).

- [aws-dms/AWS_DMS_SETUP.md](aws-dms/AWS_DMS_SETUP.md) — endpoints, accounts, CDC notes
- [aws-dms/01_create_dms_users.sql](aws-dms/01_create_dms_users.sql) — DMS account DDL (passwords passed at runtime, not stored)
- [aws-dms/02_enable_cdc.sql](aws-dms/02_enable_cdc.sql) — ARCHIVELOG transition (restart required; CDC only)
- [aws-dms/02_disable_archivelog.sql](aws-dms/02_disable_archivelog.sql) — revert ARCHIVELOG→NOARCHIVELOG (restart; CDC teardown via bin/9200)
- [aws-dms/03_grant_binary_reader_cdc.sql](aws-dms/03_grant_binary_reader_cdc.sql) — Binary Reader CDC grants for C##DMS (CDC only)
- [aws-dms/04_supplemental_logging.sql](aws-dms/04_supplemental_logging.sql) — DB + per-table supplemental logging (online, idempotent; CDC only)

## Project files

- `bin/env.sh`: loads local Oracle/Perl environment
- `bin/ssh-248`: SSH into `192.168.29.248`
- `bin/run-remote-sqlplus-sysdba`: run a local SQL file on `192.168.29.248` as `oracle` OS user with `/ as sysdba`
- `bin/test-oracle`: tests Oracle DB login from the current server
- `bin/sqlplus-248`: opens SQL*Plus from the current server to `192.168.29.248`
- `bin/ora2pg-run`: runs `ora2pg` with a generated config
- `bin/step-01-check-ssh`: verify SSH login to `192.168.29.248`
- `bin/step-02-check-db-state`: verify Oracle instance state via remote SYSDBA
- `bin/step-03-list-containers`: list current container and PDB state via remote SYSDBA
- `bin/step-04-list-schemas`: list candidate application schemas via remote SYSDBA
- `bin/step-05-find-business-tables`: find the business schema by expected table names
- `bin/step-06-profile-business-schema`: verify row counts for the selected business schema
- `bin/step-07-create-ora2pg-user`: create or refresh the Ora2Pg Oracle user from templates
- `bin/step-08-test-oracle-login`: verify direct Oracle client login from the current server
- `bin/step-09-ora2pg-show-report`: run an Ora2Pg assessment report against Oracle
- `bin/step-10-install-postgres`: install native PostgreSQL 16 (idempotent)
- `bin/step-11-create-pg-target`: create the `ora2pg_app`/`sample` roles and `sample_pg` db
- `bin/step-12-start-ivorysql`: start the IvorySQL Docker container on port 5433
- `bin/step-13-create-ivory-target`: create the `sample_ivory` db and `sample` role
- `bin/step-14-check-targets`: print versions/encoding for both targets
- `bin/step-15-export-schema`: export Oracle schema DDL to `output/export/schema/`
- `bin/step-16-export-data`: export Oracle data (COPY) to `output/export/data/`
- `bin/step-17-load-schema-pg` / `step-18-load-data-pg`: load into PostgreSQL
- `bin/step-19-load-schema-ivory` / `step-20-load-data-ivory`: load into IvorySQL
- `bin/step-21-validate-pg` / `step-22-validate-ivory`: Ora2Pg TYPE=TEST structural validation
- `bin/step-23-compatibility-report`: write `output/COMPATIBILITY_REPORT.md`
- `bin/step-24-create-data-only-target <pg|ivory>`: create empty `sample_pg_dataonly`/`sample_ivory_dataonly` (data-only)
- `bin/step-25-apply-developed-schema <pg|ivory>`: apply the hand-developed PostgreSQL schema (shared, in `aws-dms/sql/data-only/`)
- `bin/step-26-export-base-table-data`: provide base-table COPY data (reuses step-16 export; routes orders partitions to parent)
- `bin/step-27-load-base-table-data <pg|ivory>`: load base-table data (superuser + `session_replication_role=replica`)
- `bin/step-28-finalize-data-only <pg|ivory>`: reset sequences + refresh materialized views
- `bin/step-29-verify-data-only <pg|ivory>`: row-count compare Oracle vs the data-only target (PASS/FAIL)
- `bin/pg-psql <pg|ivory>`: run psql against a selected target
- `bin/load-sql-dir <pg|ivory> <dir> <log>`: load all `*.sql` in a dir, logging errors
- `bin/reset-target <pg|ivory>`: drop and recreate a target db for a clean reload
- `bin/clean-conversion`: remove all conversion artifacts and reset both targets (full reset before re-running)
- `config/tnsnames.ora`: local TNS alias for `ORCL248`
- `config/ora2pg.conf.template`: template rendered at runtime
- `sql/01_show_db_state.sql`: remote SYSDBA health check
- `sql/02_create_ora2pg_user.sql.template`: repeatable Ora2Pg user DDL template
- `sql/10_create_pg_target.sql.template`: PostgreSQL role/db creation template
- `sql/11_create_ivory_target.sql.template`: IvorySQL db creation template

## First use

1. Copy `.oracle.env.example` to `.oracle.env`
2. Fill in Oracle and PostgreSQL credentials
3. Run `source bin/env.sh`
4. Run `bin/step-01-check-ssh`
5. Run `bin/step-02-check-db-state`
6. Run `bin/step-03-list-containers`
7. Run `bin/step-04-list-schemas`
8. Run `bin/step-05-find-business-tables`
9. Set `ORA_SCHEMA` in `.oracle.env`
10. Run `bin/step-06-profile-business-schema`
11. Set `ORA2PG_DB_USER` and `ORA2PG_DB_PASSWORD` in `.oracle.env`
12. Run `bin/step-07-create-ora2pg-user`
13. Run `bin/step-08-test-oracle-login`
14. Run `bin/step-09-ora2pg-show-report`

### Migration compatibility test (steps 10–23)

Run one at a time; each must succeed before the next. Full details and rationale
are in [MIGRATION_TEST.md](MIGRATION_TEST.md).

15. `bin/step-10-install-postgres` (sudo)
16. `bin/step-11-create-pg-target` (sudo)
17. `bin/step-12-start-ivorysql`
18. `bin/step-13-create-ivory-target`
19. `bin/step-14-check-targets`
20. `bin/step-15-export-schema`
21. `bin/step-16-export-data`
22. `bin/step-17-load-schema-pg`
23. `bin/step-18-load-data-pg`
24. `bin/step-19-load-schema-ivory`
25. `bin/step-20-load-data-ivory`
26. `bin/step-21-validate-pg`
27. `bin/step-22-validate-ivory`
28. `bin/step-23-compatibility-report` → `output/COMPATIBILITY_REPORT.md`

### Data-only path (developed schema + base-table data, steps 24–29)

Mirrors the AWS DMS data-only path: apply a hand-developed PostgreSQL schema separately, then
load ONLY base-table row data (one-time, `TYPE=COPY`) — into dedicated DBs `sample_pg_dataonly`
/ `sample_ivory_dataonly` so the full-conversion `sample_pg`/`sample_ivory` are kept for comparison.
The developed schema, base-table list, MV refresh and sequence-reset are the SAME shared assets
as the AWS path, referenced in place under `aws-dms/sql/data-only/`. Run one at a time, per target:

```
bin/step-24-create-data-only-target pg     # then: ivory
bin/step-25-apply-developed-schema pg       # then: ivory   (pgcrypto: trusted on pg; stripped on ivory — unused)
bin/step-26-export-base-table-data          # once (reuses step-16 export if present)
bin/step-27-load-base-table-data pg         # then: ivory   (FK/triggers bypassed via replica role)
bin/step-28-finalize-data-only pg           # then: ivory   (sequences + materialized views)
bin/step-29-verify-data-only pg             # then: ivory   (row counts vs Oracle → PASS)
```

**CDC is NOT supported by Ora2Pg** (confirmed: `ora2pg-src/doc/Ora2Pg.pod` — "Ora2Pg does not have
a feature which allows importing data and only applying changes after the first import"). `--cdc_ready`
only records per-table SCN for an external tool; for incremental sync use Debezium/SymmetricDS
(out of scope) or the AWS DMS CDC path (`aws-dms/`, `MIGRATION_TYPE=full-load-and-cdc`).

## Step policy

- Execute one step at a time.
- Do not combine multiple operational steps into one command.
- If a step fails, fix the script or configuration first, then rerun the same step.
- Keep scripts and this document in sync whenever the workflow changes.

## Notes

- The Oracle listener on `192.168.29.248:1521` is reachable directly from this server.
- `ssh` is only needed for server administration or for OS-authenticated Oracle work on the remote host.
- To migrate with `ora2pg`, an Oracle DB account is still required.
- For this server, application data is expected in `ORCLPDB1`, not `CDB$ROOT`.
