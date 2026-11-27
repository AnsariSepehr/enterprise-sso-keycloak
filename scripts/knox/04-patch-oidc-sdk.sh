#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
load_env
# Phase 3.4 - fix HTTP 500 after login (NoSuchMethodError JWTClaimsSet.toJSONObject()).
# Knox 2.1.0 bundles oauth2-oidc-sdk-8.22 next to nimbus-jose-jwt 10.x; replace it with ${OIDC_SDK_VERSION}.
# Manual patch of a vendor bundle: repeat after every Knox upgrade, and check if the new release fixed it.
require_root
v="$OIDC_SDK_VERSION"; base="https://repo1.maven.org/maven2/com/nimbusds/oauth2-oidc-sdk/$v"
tmp="$(mktemp -d)"; cd "$tmp"
curl -fLO "$base/oauth2-oidc-sdk-$v.jar"
curl -fLO "$base/oauth2-oidc-sdk-$v.jar.sha1"
echo "$(cat oauth2-oidc-sdk-$v.jar.sha1) oauth2-oidc-sdk-$v.jar" | sha1sum -c -
systemctl stop knox
mkdir -p /root/knox-jar-backup
mv "$KNOX_HOME"/dep/oauth2-oidc-sdk-8.*.jar /root/knox-jar-backup/ 2>/dev/null || warn "no 8.x jar found to move"
cp "oauth2-oidc-sdk-$v.jar" "$KNOX_HOME/dep/"
chown knox:knox "$KNOX_HOME/dep/oauth2-oidc-sdk-$v.jar"
systemctl start knox
log "Patched. Old jar kept in /root/knox-jar-backup"
