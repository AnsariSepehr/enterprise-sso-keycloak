#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
load_env
# Phase 6 - HTTPS in front of Ranger, plus the logout rule. Run on the Ranger node.
# Needs: wildcard certificate and key already copied to $TLS_CERT / $TLS_KEY, DNS for $RANGER_HOSTNAME.
require_root
[ -f "$TLS_CERT" ] && [ -f "$TLS_KEY" ] || die "Copy the certificate and key to $TLS_CERT and $TLS_KEY first."
command -v nginx >/dev/null || { log "Installing nginx"; dnf install -y nginx; }
chmod 600 "$TLS_KEY"

if command -v getenforce >/dev/null && [ "$(getenforce)" = Enforcing ]; then
  log "SELinux is enforcing: allowing nginx to reach 127.0.0.1:6080 (not a standard web port)"
  setsebool -P httpd_can_network_connect 1
fi

render "$REPO_ROOT/config/nginx/ranger.conf.example" /etc/nginx/conf.d/ranger.conf
nginx -t
systemctl enable --now nginx
systemctl reload nginx
if systemctl is-active --quiet firewalld; then
  firewall-cmd --permanent --add-service=http --add-service=https && firewall-cmd --reload
else
  warn "firewalld is not running: ports 80, 443 and 6080 are open to everyone who can reach this node."
fi
# A reload is graceful: old workers keep answering for a moment. Test a few seconds later or the
# check can show the OLD behaviour (docs/troubleshooting.md, problem 35).
sleep 3
getent hosts "$RANGER_HOSTNAME" >/dev/null || warn "$RANGER_HOSTNAME does not resolve from this node: add the DNS record."
curl -sk -o /dev/null -w '  https://'"$RANGER_HOSTNAME"'/ -> %{http_code} %{redirect_url}\n' -A "Mozilla/5.0 Chrome" "https://$RANGER_HOSTNAME/" || true
log "The redirect must go to Knox with originalUrl=https://$RANGER_HOSTNAME/. If it says http:// or localhost, the forwarded headers are not reaching Ranger."
log "Also add https://$RANGER_HOSTNAME/ to 'Valid post logout redirect URIs' of the Keycloak client 'knox', and put the /logout/ranger block on the Knox host (config/nginx/knox.conf.example)."
