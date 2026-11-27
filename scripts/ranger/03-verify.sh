#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
load_env
# Phase 6 - read-only end-to-end checks for Ranger. Run from any host that can reach it.
ok(){ printf '  [ok]   %s\n' "$*"; }; bad(){ printf '  [FAIL] %s\n' "$*"; rc=1; }
rc=0
UA="Mozilla/5.0 Chrome"
R="https://$RANGER_HOSTNAME"

echo "Login"
loc="$(curl -sk -o /dev/null -w '%{http_code} %{redirect_url}' -A "$UA" "$R/")"
case "$loc" in
  "302 https://$KNOX_HOSTNAME/gateway/knoxsso/api/v1/websso?originalUrl=$R/"*) ok "browser is sent to Knox and will return to $R/" ;;
  *) bad "unexpected answer for a browser: $loc" ;;
esac

echo "Logout (the nginx rule on this node)"
hdr="$(curl -sk -D - -o /dev/null -A "$UA" "$R/index.html?action=timeout")"
echo "$hdr" | head -1 | grep -q 302 && ok "index.html?action=timeout answers 302" || bad "index.html?action=timeout does not answer 302 (rule missing, or reload not finished)"
echo "$hdr" | grep -i '^location:' | grep -q "https://$KNOX_HOSTNAME/logout/ranger" && ok "redirects to the Knox logout address for Ranger" || bad "wrong or missing Location header"
echo "$hdr" | grep -i '^set-cookie:' | grep -q 'RANGERADMINSESSIONID=;' && ok "expires Ranger's own session cookie" || bad "RANGERADMINSESSIONID is not expired (the user would come back signed in)"

echo "Logout (the address on the Knox host)"
kh="$(curl -sk -D - -o /dev/null "https://$KNOX_HOSTNAME/logout/ranger")"
echo "$kh" | grep -i '^location:' | grep -q "protocol/openid-connect/logout" && ok "Knox sends the browser to Keycloak's logout" || bad "no Keycloak logout redirect from /logout/ranger"
echo "$kh" | grep -i '^location:' | grep -q "$RANGER_HOSTNAME" && ok "and back to $RANGER_HOSTNAME afterwards" || bad "post_logout_redirect_uri does not name $RANGER_HOSTNAME"
echo "$kh" | grep -ci '^set-cookie: hadoop-jwt=;' | grep -q '^1$' && ok "expires hadoop-jwt" || bad "hadoop-jwt is not expired"

echo "Break-glass"
bg="$(curl -sk -o /dev/null -w '%{http_code} %{redirect_url}' -A "$UA" "$R/locallogin")"
case "$bg" in 302*login.jsp) ok "/locallogin leads to Ranger's own login form" ;; *) bad "/locallogin answered: $bg" ;; esac

echo "Monitoring (optional)"
curl -fsS -o /dev/null "http://$RANGER_HOSTNAME:7073/metrics" 2>/dev/null && ok "JMX exporter answers on 7073" || printf '  [info] JMX exporter not reachable from here (fine if firewalled)\n'
exit "$rc"
