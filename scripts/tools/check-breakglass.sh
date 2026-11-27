#!/usr/bin/env bash
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
load_env
# Do the break-glass LOGIN PAGES still answer? (docs/break-glass.md)
# This checks reachability only. It cannot test a password: sign in with each fallback account by hand
# after every upgrade, and after every change to SSO settings.
ok(){ printf '  [ok]   %-10s %s\n' "$1" "$2"; }; bad(){ printf '  [FAIL] %-10s %s\n' "$1" "$2"; rc=1; }; info(){ printf '  [info] %-10s %s\n' "$1" "$2"; }
rc=0
code() { curl -sk -o /dev/null -w '%{http_code}' -A "Mozilla/5.0 Chrome" "$1"; }

[ "$(code "https://$SSO_HOSTNAME/admin/master/console/")" = 200 ] && ok Keycloak "master realm console answers" || bad Keycloak "master realm console does not answer 200"
[ "$(code "https://$JIRA_HOSTNAME/login.jsp")" = 200 ] && ok Jira "normal login form answers" || bad Jira "login.jsp does not answer 200"
r="$(curl -sk -o /dev/null -w '%{http_code} %{redirect_url}' -A "Mozilla/5.0 Chrome" "https://$RANGER_HOSTNAME/locallogin")"
case "$r" in 302*login.jsp) ok Ranger "/locallogin leads to Ranger's own form (use a private window)" ;; *) bad Ranger "/locallogin answered: $r" ;; esac
[ "$(code "https://$GRAFANA_HOSTNAME/login?disableAutoLogin=true")" = 200 ] && ok Grafana "form reachable at /login?disableAutoLogin=true" || bad Grafana "fallback form not reachable"
[ "$(code "https://$NEXTCLOUD_HOSTNAME/login?direct=1")" = 200 ] && ok Nextcloud "form reachable at /login?direct=1" || bad Nextcloud "fallback form not reachable"
info Knox "no login page by design: edit knoxsso.xml on the worker node (docs/break-glass.md)"
info Zeppelin "no login page by design: swap shiro.ini on the worker node (docs/break-glass.md)"
info Exchange "not integrated: AD login on OWA"
echo
echo "Reachability only. Now sign in with each fallback account yourself."
exit "$rc"
