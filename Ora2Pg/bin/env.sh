#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PERL_BASE="/home/ubuntu/perl5"

export ORACLE_HOME="${ORACLE_HOME:-/opt/oracle/instantclient_19_31}"
export TNS_ADMIN="${TNS_ADMIN:-$PROJECT_DIR/config}"
export LD_LIBRARY_PATH="${ORACLE_HOME}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export PATH="$PROJECT_DIR/bin:$PERL_BASE/usr/local/bin:$PERL_BASE/bin:$ORACLE_HOME:$PATH"
export PERL5LIB="$PERL_BASE/lib/perl5:$PERL_BASE/lib/perl5/x86_64-linux-gnu-thread-multi:$PERL_BASE/usr/local/share/perl/5.38.2:$PERL_BASE/usr/local/lib/x86_64-linux-gnu/perl/5.38.2${PERL5LIB:+:$PERL5LIB}"

if [ -f "$PROJECT_DIR/.oracle.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$PROJECT_DIR/.oracle.env"
  set +a
fi

export ORACLE_HOST="${ORACLE_HOST:-192.168.29.248}"
export ORACLE_PORT="${ORACLE_PORT:-1521}"
export ORACLE_SERVICE="${ORACLE_SERVICE:-ORCLPDB1}"
export ORACLE_SYS_CONTAINER="${ORACLE_SYS_CONTAINER:-$ORACLE_SERVICE}"
export ORACLE_TNS_ALIAS="${ORACLE_TNS_ALIAS:-ORCL248}"
export ORACLE_DSN_DEFAULT="${ORACLE_DSN_DEFAULT:-dbi:Oracle:host=${ORACLE_HOST};port=${ORACLE_PORT};service_name=${ORACLE_SERVICE}}"

export ORA2PG_BIN="${ORA2PG_BIN:-$PERL_BASE/usr/local/bin/ora2pg}"

# Migration target: PostgreSQL (native apt)
export PG_HOST="${PG_HOST:-127.0.0.1}"
export PG_PORT="${PG_PORT:-5432}"
export PG_DB="${PG_DB:-sample_pg}"
export PG_APP_USER="${PG_APP_USER:-ora2pg_app}"
export PG_APP_PASSWORD="${PG_APP_PASSWORD:-}"

# Migration target: IvorySQL (docker)
export IVY_HOST="${IVY_HOST:-127.0.0.1}"
export IVY_PORT="${IVY_PORT:-5433}"
export IVY_DB="${IVY_DB:-sample_ivory}"
export IVY_SUPERUSER="${IVY_SUPERUSER:-ivorysql}"
export IVY_PASSWORD="${IVY_PASSWORD:-}"
export IVY_IMAGE="${IVY_IMAGE:-ivorysql/ivorysql:3.4-ubi8}"
export IVY_CONTAINER="${IVY_CONTAINER:-ora2pg-ivory}"
