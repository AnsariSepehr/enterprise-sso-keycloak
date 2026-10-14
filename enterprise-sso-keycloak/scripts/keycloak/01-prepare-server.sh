#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
load_env
# Phase 1.1 - prepare the SSO server (Rocky Linux 9). Mirrors docs/keycloak/deployment.md section 2.
require_root
log "Setting hostname to $SSO_HOSTNAME"
hostnamectl set-hostname "$SSO_HOSTNAME"

log "Installing packages"
dnf update -y
dnf install -y java-17-openjdk java-17-openjdk-devel wget unzip firewalld nginx gettext policycoreutils-python-utils
systemctl enable --now firewalld

id keycloak >/dev/null 2>&1 || useradd -m -s /sbin/nologin keycloak

# Do NOT auto-remove anything: this step only reports. We hit "Port already bound: 8080"
# because an old FreeIPA install (pki-tomcat) was still on the box. See troubleshooting.md #2.
log "Checking for services already using the ports Keycloak/nginx need"
if ss -tulpn | grep -E ':(8080|80|443)\b'; then
  warn "A process already listens on 8080/80/443 (see above)."
  warn "If it is a leftover FreeIPA: 'ipa-server-install --uninstall -U' and"
  warn "'systemctl disable --now pki-tomcatd@pki-tomcat.service'. Decide yourself, this script will not."
fi

log "DNS check (must resolve to this server's address)"
getent hosts "$SSO_HOSTNAME" || warn "$SSO_HOSTNAME does not resolve yet. Create the DNS record first."
log "Done."
