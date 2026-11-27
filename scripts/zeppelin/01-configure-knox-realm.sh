#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
load_env
# Phase 4 - switch Zeppelin to the Knox JWT realm. Run on the worker node, AFTER Knox login works.
require_root
cd "$ZEPPELIN_HOME/conf"
pem_src="$KNOX_HOME/data/security/keystores/gateway-client-trust.pem"

log "Exporting the Knox signing certificate (Derby 'Another instance may have already booted' messages are harmless)"
sudo -u knox "$KNOX_HOME/bin/knoxcli.sh" export-cert --type PEM || true
[ -f "$pem_src" ] || die "$pem_src not found"
cp "$pem_src" knox-sso.pem
chown zeppelin:zeppelin knox-sso.pem; chmod 644 knox-sso.pem
openssl x509 -in knox-sso.pem -noout -subject -enddate
warn "Knox's certificate is self-signed. Re-copy this file when it is regenerated or expires."

log "Hadoop variables for KnoxJwtRealm (missing => ClassNotFoundException: org.apache.hadoop.conf.Configuration)"
backup_file zeppelin-env.sh
grep -q 'KnoxJwtRealm (Hadoop Configuration class)' zeppelin-env.sh || envsubst '${HADOOP_HOME}' < "$REPO_ROOT/config/zeppelin/zeppelin-env.sh.snippet" >> zeppelin-env.sh

render "$REPO_ROOT/config/zeppelin/shiro.ini.example" shiro.ini 640 zeppelin:zeppelin

systemctl restart zeppelin
sleep 25
systemctl status zeppelin --no-pager | head -6
grep -E "Caused by|ClassNotFound|NoSuchMethod" "$ZEPPELIN_HOME"/logs/zeppelin-*.log | tail -5 || true
log "Now open Zeppelin in a private window: it must bounce through Knox and Keycloak."
