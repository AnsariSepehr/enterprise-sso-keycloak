#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
load_env
# Phase 3.3 - replace the demo login in knoxsso.xml with the Keycloak OIDC client.
# Prerequisite (UI): create the OIDC client 'knox' in Keycloak first, copy its secret. docs/services/knox.md
require_root
require_secret KNOX_OIDC_SECRET "Keycloak client secret of client 'knox'"
# the secret is written into XML: escape & < > so a special character cannot break the file
KNOX_OIDC_SECRET="$(python3 -c 'import sys,xml.sax.saxutils as s; print(s.escape(sys.argv[1]), end="")' "$KNOX_OIDC_SECRET")"
export KNOX_OIDC_SECRET
dest="$KNOX_HOME/conf/topologies/knoxsso.xml"
render "$REPO_ROOT/config/knox/knoxsso.xml.example" "$dest" 600 knox:knox
python3 -c "import sys,xml.dom.minidom as m; m.parse(sys.argv[1]); print('XML OK')" "$dest"
log "Knox redeploys topologies on its own within seconds."
