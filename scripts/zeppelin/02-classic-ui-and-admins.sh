#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
load_env
# Phase 5b - make Zeppelin's logout reach Keycloak, and limit the admin pages to named users.
# Run on the worker node, AFTER 01-configure-knox-realm.sh. docs/services/zeppelin.md ("Logout", "Administrators").
require_root
site="$ZEPPELIN_HOME/conf/zeppelin-site.xml"
[ -f "$site" ] || { cp "$ZEPPELIN_HOME/conf/zeppelin-site.xml.template" "$site"; chown zeppelin:zeppelin "$site"; log "created $site from the template"; }
backup_file "$site"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
printf 'zeppelin.default.ui=classic\n' > "$work/props"
log "Classic UI as the default front end (the new UI's Logout button never reaches Knox)"
python3 "$REPO_ROOT/scripts/lib/xml_props.py" "$site" "$work/props"

log "Re-rendering shiro.ini with the administrator list: $ZEPPELIN_ADMINS"
render "$REPO_ROOT/config/zeppelin/shiro.ini.example" "$ZEPPELIN_HOME/conf/shiro.ini" 640 zeppelin:zeppelin
systemctl restart zeppelin
sleep 25
systemctl status zeppelin --no-pager | head -6
log "Test: sign in as one user, press Logout, sign in as a different user (the name at the top right must change)."
warn "Keycloak client 'knox' must list https://$ZEPPELIN_HOSTNAME/ under Valid post logout redirect URIs, and the Knox host needs the /logout block (config/nginx/knox.conf.example)."
