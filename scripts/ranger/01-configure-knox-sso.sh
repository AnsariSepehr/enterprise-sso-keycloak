#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
load_env
# Phase 6 - point Ranger Admin at Knox. Run on the Ranger node, AFTER Knox login works (phase 4).
# Needs: Knox's PEM certificate in $KNOX_CERT_FILE (the same file Zeppelin uses as knox-sso.pem).
require_root
conf="$RANGER_CONF_DIR/ranger-admin-site.xml"
[ -f "$conf" ] || die "$conf not found. Run 00-preflight.sh and set RANGER_CONF_DIR to the directory the process reads."
[ -f "$KNOX_CERT_FILE" ] || die "$KNOX_CERT_FILE not found. Copy Knox's certificate here (docs/services/ranger.md, prerequisites)."
openssl x509 -in "$KNOX_CERT_FILE" -noout -subject -enddate || die "$KNOX_CERT_FILE is not a PEM certificate"
warn "Ranger now holds a second copy of Knox's self-signed certificate. Refresh it here AND in Zeppelin when Knox's is replaced."

# The certificate body on ONE line, without the BEGIN/END lines.
KNOX_CERT_BASE64="$(grep -v -- '-----' "$KNOX_CERT_FILE" | tr -d '\n')"
export KNOX_CERT_BASE64
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
render "$REPO_ROOT/config/ranger/ranger-sso.properties.example" "$work/props" 600 root:root

log "Backing up and editing $conf (each property must say replaced, added or unchanged)"
backup_file "$conf"
python3 "$REPO_ROOT/scripts/lib/xml_props.py" "$conf" "$work/props"

log "Restarting Ranger Admin. A stop can take about a minute; the old process is force-killed after its grace period."
systemctl restart ranger-admin
for _ in $(seq 1 90); do
  systemctl is-active --quiet ranger-admin && curl -fsS -o /dev/null http://127.0.0.1:6080/ 2>/dev/null && break
  sleep 3
done
systemctl is-active ranger-admin || die "ranger-admin did not come back. Read catalina.out, NOT only the journal (docs/troubleshooting.md, problem 27)."
log "A browser user agent must now be redirected to Knox:"
curl -s -o /dev/null -w '  %{http_code} -> %{redirect_url}\n' -A "Mozilla/5.0 Chrome" http://127.0.0.1:6080/
log "Next: 02-setup-nginx.sh (HTTPS and the logout rule), then 03-verify.sh."
