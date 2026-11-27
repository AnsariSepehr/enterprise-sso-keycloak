#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
load_env
# Quick health checks. Read-only.
ok(){ printf '  [ok]   %s\n' "$*"; }; bad(){ printf '  [FAIL] %s\n' "$*"; }
chk(){ local n="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$n"; else bad "$n"; fi; }
echo "Keycloak"
chk "OIDC discovery (https://$SSO_HOSTNAME)" curl -fsS "https://$SSO_HOSTNAME/realms/$REALM/.well-known/openid-configuration"
chk "SAML descriptor (used by Jira)" curl -fsS "https://$SSO_HOSTNAME/realms/$REALM/protocol/saml/descriptor"
echo "Knox"
chk "Home page redirects to login (302/200)" curl -fsS -o /dev/null "https://$KNOX_HOSTNAME/gateway/homepage/home/"
chk "Logout workaround answers 302" bash -c "curl -sI https://$KNOX_HOSTNAME/logout | head -1 | grep -q 302"
echo "Certificates"
for h in "$SSO_HOSTNAME" "$KNOX_HOSTNAME"; do
  echo | openssl s_client -connect "$h:443" -servername "$h" 2>/dev/null | openssl x509 -noout -enddate | sed "s/^/  $h /"
done
