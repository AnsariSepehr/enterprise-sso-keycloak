#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
load_env
# Phase 1.4 - keycloak.conf, systemd unit, build, start.
require_root
require_secret KC_DB_PASSWORD "Database password for $DB_USER"
require_secret KC_BOOTSTRAP_ADMIN_PASSWORD "Temporary bootstrap admin password"

install -d -m 750 -o root -g keycloak /etc/keycloak
render "$REPO_ROOT/config/keycloak/keycloak.env.example"    /etc/keycloak/keycloak.env 640 root:keycloak
render "$REPO_ROOT/config/keycloak/keycloak.conf.example"   "$KEYCLOAK_HOME/conf/keycloak.conf" 640 keycloak:keycloak
render "$REPO_ROOT/config/keycloak/keycloak.service.example" /etc/systemd/system/keycloak.service 644

log "kc.sh build (the DB vendor is a build-time option)"
sudo -u keycloak "$KEYCLOAK_HOME/bin/kc.sh" build

systemctl daemon-reload
systemctl enable --now keycloak
log "Waiting for Keycloak (up to 120 s)"
for i in $(seq 1 60); do curl -fsI http://127.0.0.1:8080 >/dev/null 2>&1 && break; sleep 2; done
journalctl -u keycloak -n 15 --no-pager
log "Next: create the permanent admin in the UI (docs/keycloak/ui-steps.md), then remove the bootstrap lines from /etc/keycloak/keycloak.env"
