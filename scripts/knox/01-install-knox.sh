#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
load_env
# Phase 3.1 - install Knox (worker node).
require_root
cd /opt
if [ ! -d "$KNOX_HOME" ]; then
  # dlcdn only keeps current releases; archive.apache.org keeps all of them.
  curl -fLO "https://dlcdn.apache.org/knox/${KNOX_VERSION}/knox-${KNOX_VERSION}.tar.gz" \
   || curl -fLO "https://archive.apache.org/dist/knox/${KNOX_VERSION}/knox-${KNOX_VERSION}.tar.gz"
  tar -xzf "knox-${KNOX_VERSION}.tar.gz"
  mv "knox-${KNOX_VERSION}" "$KNOX_HOME"
  rm -f "knox-${KNOX_VERSION}.tar.gz"
fi
id knox >/dev/null 2>&1 || useradd -m -s /sbin/nologin knox
chown -R knox:knox "$KNOX_HOME"

if [ ! -f "$KNOX_HOME/data/security/master" ]; then
  log "Creating the Knox master secret. You will be asked for it. Store it in a password manager."
  sudo -u knox "$KNOX_HOME/bin/knoxcli.sh" create-master
fi
grep -E 'gateway.port|ssl.enabled' "$KNOX_HOME/conf/gateway-site.xml" -A1 || true
log "Expect gateway.port=8443 and ssl.enabled=false (Knox speaks plain HTTP internally, nginx does TLS)."
