#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
load_env
# Phase 1.3 - PostgreSQL for Keycloak, in the order that avoids the scram/md5 trap (troubleshooting.md #3).
require_root
require_secret KC_DB_PASSWORD "Password for database role $DB_USER"

if ! command -v psql >/dev/null; then dnf install -y postgresql-server; fi
if [ ! -f /var/lib/pgsql/data/PG_VERSION ]; then postgresql-setup --initdb; fi
systemctl enable --now postgresql

psql_as_pg() { sudo -u postgres psql -v ON_ERROR_STOP=1 "$@"; }

# 1) hash format FIRST. A password stored while this was 'md5' cannot be used by a scram-sha-256 rule.
psql_as_pg -c "ALTER SYSTEM SET password_encryption = 'scram-sha-256';"
psql_as_pg -c "SELECT pg_reload_conf();"

# 2) role and database (idempotent). Password is passed through a psql variable, not the shell history.
psql_as_pg -v pw="'$KC_DB_PASSWORD'" -v u="$DB_USER" -v d="$DB_NAME" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'u', :pw)
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'u') \gexec
SELECT format('ALTER ROLE %I PASSWORD %L', :'u', :pw) \gexec
SELECT format('CREATE DATABASE %I OWNER %I', :'d', :'u')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'d') \gexec
SQL

# 3) show what pg_hba.conf will demand so a mismatch is visible
log "pg_hba.conf host rules:"; grep -E '^host' /var/lib/pgsql/data/pg_hba.conf || true

# 4) prove it works over TCP, exactly like Keycloak will connect
PGPASSWORD="$KC_DB_PASSWORD" psql -h 127.0.0.1 -U "$DB_USER" -d "$DB_NAME" -c 'SELECT 1;' >/dev/null \
  && log "TCP login as $DB_USER works" || die "TCP login failed - check pg_hba.conf (needs scram-sha-256 for 127.0.0.1)"
