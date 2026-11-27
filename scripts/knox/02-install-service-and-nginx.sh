#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
load_env
# Phase 3.2 - systemd unit and the nginx front end (includes the /logout workaround).
require_root
render "$REPO_ROOT/config/knox/knox.service.example" /etc/systemd/system/knox.service 644
render "$REPO_ROOT/config/nginx/knox.conf.example" /etc/nginx/conf.d/knox.conf 644
setsebool -P httpd_can_network_connect 1
systemctl daemon-reload
systemctl enable --now knox
nginx -t && systemctl reload nginx
