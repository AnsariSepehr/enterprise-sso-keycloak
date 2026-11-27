#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
load_env
# Phase 8 - read-only checks. Optional: TEST_UID=<an existing user ID, any letter case> checks the case problem directly.
ok(){ printf '  [ok]   %s\n' "$*"; }; bad(){ printf '  [FAIL] %s\n' "$*"; rc=1; }; note(){ printf '  [info] %s\n' "$*"; }
rc=0
c="${NEXTCLOUD_CONTAINER:-app}"
file="${LOGIN_CONTROLLER_PATH:-/var/www/html/custom_apps/user_oidc/lib/Controller/LoginController.php}"
N="https://$NEXTCLOUD_HOSTNAME"
occ() { docker exec -u www-data "$c" php occ "$@"; }

if command -v docker >/dev/null && docker ps --format '{{.Names}}' | grep -qx "$c"; then
  echo "Configuration"
  occ app:list | grep -q '^  - user_oidc:' && ok "user_oidc installed" || bad "user_oidc not installed"
  occ app:list | grep -q '^  - user_ldap:' && ok "user_ldap installed (accounts come from LDAP)" || note "user_ldap not installed: this guide assumes LDAP accounts"
  prov="$(occ user_oidc:provider keycloak 2>&1 || true)"
  printf '%s' "$prov" | grep -q 'ldap_id' && ok "provider maps the user ID to ldap_id" || bad "provider keycloak missing or not mapped to ldap_id"
  ap="$(occ config:system:get user_oidc auto_provision 2>/dev/null || true)"
  case "$ap" in true|1) bad "auto_provision is ON: a case mismatch would create duplicate accounts" ;; *) ok "auto_provision is off" ;; esac
  [ "$(occ config:system:get overwriteprotocol 2>/dev/null || true)" = https ] && ok "overwriteprotocol is https" || bad "overwriteprotocol is not https"
  if docker exec "$c" grep -q 'strtoupper($userId)' "$file" 2>/dev/null; then ok "uppercase patch present"; else bad "uppercase patch MISSING (an app update removes it): run 02-patch-user-oidc.sh"; fi
  if [ -n "${TEST_UID:-}" ]; then
    lc="$(printf '%s' "$TEST_UID" | tr '[:upper:]' '[:lower:]')"; uc="$(printf '%s' "$TEST_UID" | tr '[:lower:]' '[:upper:]')"
    occ user:info "$uc" >/dev/null 2>&1 && ok "upper-case ID is found" || bad "upper-case ID not found: wrong TEST_UID?"
    occ user:info "$lc" >/dev/null 2>&1 && note "lower-case ID is also found here (case is not the problem on this setup)" || note "lower-case ID is NOT found: this is why the patch exists"
  fi
else
  note "no local Docker access to container '$c': skipping configuration checks"
fi

echo "Sign-in flow"
r="$(curl -sk -o /dev/null -w '%{http_code} %{redirect_url}' "$N/apps/user_oidc/login/1")"
case "$r" in
  "302 https://$SSO_HOSTNAME/realms/$REALM/protocol/openid-connect/auth?"*client_id=nextcloud*) ok "Keycloak button leads to Keycloak for client nextcloud" ;;
  *) bad "/apps/user_oidc/login/1 answered: $r" ;;
esac
case "$r" in *"redirect_uri=https%3A%2F%2F$NEXTCLOUD_HOSTNAME"*) ok "return address is https (overwriteprotocol works)" ;; *) bad "return address is not https://$NEXTCLOUD_HOSTNAME" ;; esac

echo "Break-glass"
[ "$(curl -sk -o /dev/null -w '%{http_code}' "$N/login?direct=1")" = 200 ] && ok "normal login form reachable at /login?direct=1" || bad "/login?direct=1 does not answer 200"
exit "$rc"
