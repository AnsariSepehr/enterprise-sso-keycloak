#!/usr/bin/env bash
# Runs phase 1 end to end. Read each script first; they are meant to be understood, not just run.
set -euo pipefail
d="$(dirname "${BASH_SOURCE[0]}")"
for s in 01-prepare-server 02-install-keycloak 03-setup-postgres 04-install-service 05-setup-nginx; do
  echo "==== $s ===="; bash "$d/$s.sh"
done
echo "Now do the UI steps: docs/keycloak/ui-steps.md"
