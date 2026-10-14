#!/usr/bin/env bash
# Shared helpers. Source this file; do not run it.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${SSO_ENV_FILE:-$REPO_ROOT/config/env/sso.env}"

# Variables that may appear as ${NAME} in config/*.example files.
RENDER_VARS="DOMAIN DOMAIN_REGEX SSO_HOSTNAME KNOX_HOSTNAME JIRA_HOSTNAME ZEPPELIN_HOSTNAME REALM \
KEYCLOAK_HOME KNOX_HOME ZEPPELIN_HOME HADOOP_HOME TLS_CERT TLS_KEY DB_NAME DB_USER KNOX_OIDC_SECRET KC_DB_PASSWORD KC_BOOTSTRAP_ADMIN_PASSWORD"

log()  { printf '\033[1;34m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

require_root() { [ "$(id -u)" -eq 0 ] || die "Run as root (sudo)."; }

load_env() {
  [ -f "$ENV_FILE" ] || die "Missing $ENV_FILE. Copy config/env/sso.env.example to config/env/sso.env and edit it."
  set -a; . "$ENV_FILE"; set +a
  # "example.corp" -> "example\.corp" for use inside regular expressions
  DOMAIN_REGEX="$(printf '%s' "$DOMAIN" | sed 's/\./\\./g')"
  export DOMAIN_REGEX
}

# require_secret VAR "Prompt text": use the environment value or ask without echo.
require_secret() {
  local var="$1" prompt="$2" val
  if [ -z "${!var:-}" ]; then
    read -rsp "$prompt: " val; echo
    [ -n "$val" ] || die "$var must not be empty"
    export "$var=$val"
  fi
}

# render SRC DEST [MODE] [OWNER:GROUP] : fill ${VARS} from the environment.
# Only the variables in RENDER_VARS are replaced, so nginx's $host etc. survive.
render() {
  local src="$1" dest="$2" mode="${3:-644}" owner="${4:-root:root}" list=""
  command -v envsubst >/dev/null || die "envsubst not found (dnf install gettext)"
  for v in $RENDER_VARS; do list+="\${$v} "; done
  mkdir -p "$(dirname "$dest")"
  backup_file "$dest"
  envsubst "$list" < "$src" > "$dest"
  chmod "$mode" "$dest"; chown "$owner" "$dest"
  log "wrote $dest"
}

backup_file() {
  local f="$1"
  if [ -f "$f" ] && [ ! -f "$f.orig" ]; then cp -p "$f" "$f.orig"; log "backup: $f.orig"; fi
}
