#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
load_env
# Phase 8 - register Keycloak in Nextcloud. Run on the Docker host of the Nextcloud container.
# Accounts stay in LDAP (user_ldap); only the sign-in moves to Keycloak. docs/services/nextcloud.md
command -v docker >/dev/null || die "docker not found"
c="${NEXTCLOUD_CONTAINER:-app}"
docker ps --format '{{.Names}}' | grep -qx "$c" || die "container '$c' is not running (set NEXTCLOUD_CONTAINER)"
occ() { docker exec -u www-data "$c" php occ "$@"; }

log "user_oidc app (installed from the app store through occ)"
occ app:list | grep -q '^  - user_oidc:' && log "already installed" || occ app:install user_oidc

log "Behind nginx Nextcloud must build https:// return addresses, or Keycloak refuses the redirect"
occ config:system:set overwriteprotocol --value=https

log "auto_provision OFF: a sign-in that matches no existing account is refused instead of creating an empty duplicate"
occ config:system:set user_oidc auto_provision --type=boolean --value=false

require_secret NEXTCLOUD_OIDC_SECRET "Client secret of the Keycloak client 'nextcloud'"
log "Registering provider 'keycloak'. mapping-uid=ldap_id sends the AD GUID; unique-uid=0 stops the app hashing or prefixing IDs."
warn "The secret is visible in the host's process list for the moment the command runs."
occ user_oidc:provider keycloak \
  --clientid=nextcloud --clientsecret="$NEXTCLOUD_OIDC_SECRET" \
  --discoveryuri="https://$SSO_HOSTNAME/realms/$REALM/.well-known/openid-configuration" \
  --scope="openid email profile" \
  --mapping-uid=ldap_id --unique-uid=0
log "Group sync and display-name/e-mail mapping are left OFF on purpose (the LDAP app maintains them; group sync could strip the admin group)."
occ user_oidc:provider keycloak
log "Next: 02-patch-user-oidc.sh (the case problem), then 03-verify.sh."
