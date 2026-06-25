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

- [aws-dms/AWS_DMS_SETUP.md](aws-dms/AWS_DMS_SETUP.md) — endpoints, accounts, CDC notes
- [aws-dms/01_create_dms_users.sql](aws-dms/01_create_dms_users.sql) — DMS account DDL (passwords passed at runtime, not stored)
- [aws-dms/02_enable_cdc.sql](aws-dms/02_enable_cdc.sql) — ARCHIVELOG + supplemental logging (restart required; CDC only)

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
