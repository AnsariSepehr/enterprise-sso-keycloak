#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
load_env
# Phase 1.2 - download and unpack Keycloak. Use the exact release tag (a guessed 'latest' URL gave HTTP 404).
require_root
cd /opt
if [ -x "$KEYCLOAK_HOME/bin/kc.sh" ]; then log "Keycloak already present at $KEYCLOAK_HOME"; exit 0; fi
url="https://github.com/keycloak/keycloak/releases/download/${KEYCLOAK_VERSION}/keycloak-${KEYCLOAK_VERSION}.tar.gz"
log "Downloading $url"
wget -q "$url" -O keycloak.tar.gz
tar -xzf keycloak.tar.gz
mv "keycloak-${KEYCLOAK_VERSION}" "$KEYCLOAK_HOME"
rm -f keycloak.tar.gz
chown -R keycloak:keycloak "$KEYCLOAK_HOME"
log "Installed Keycloak ${KEYCLOAK_VERSION} in $KEYCLOAK_HOME"
