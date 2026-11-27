#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
load_env
# Phase 1.5 - HTTPS in front of Keycloak. Includes the SELinux boolean that fixes the 502 (troubleshooting.md #4).
require_root
[ -r "$TLS_CERT" ] && [ -r "$TLS_KEY" ] || die "TLS_CERT / TLS_KEY not readable. Place your wildcard certificate first."
render "$REPO_ROOT/config/nginx/sso.conf.example" /etc/nginx/conf.d/sso.conf 644
setsebool -P httpd_can_network_connect 1
nginx -t
systemctl enable --now nginx
systemctl reload nginx
firewall-cmd --permanent --add-service=http --add-service=https
firewall-cmd --reload
log "Check: curl -s https://$SSO_HOSTNAME/realms/$REALM/.well-known/openid-configuration | head -c 200   (works once the realm exists)"
