#!/usr/bin/env bash
# Renders every config/*.example with the example values into a temp dir and checks the result.
# Proves the templates are consistent and that no ${VAR} is left unresolved.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
load_env
export KNOX_OIDC_SECRET='<SECRET>' KC_DB_PASSWORD='<PASSWORD>' KC_BOOTSTRAP_ADMIN_PASSWORD='<PASSWORD>'
KNOX_OIDC_SECRET="$(python3 -c 'import sys,xml.sax.saxutils as s; print(s.escape(sys.argv[1]), end="")' "$KNOX_OIDC_SECRET")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
list=""; for v in $RENDER_VARS; do list+="\${$v} "; done
rc=0
for f in $(find "$REPO_ROOT/config" -name '*.example' -o -name '*.snippet'); do
  out="$tmp/$(basename "$f")"; envsubst "$list" < "$f" > "$out"
  if grep -nE '\$\{[A-Z_]+\}' "$out"; then echo "unresolved variable in $f"; rc=1; fi
done
if command -v xmllint >/dev/null; then xmllint --noout "$tmp/knoxsso.xml.example" && echo "knoxsso.xml well-formed" || exit 1; fi
grep -q 'example\\.corp' "$tmp/knoxsso.xml.example" && echo "regex escaping ok" || exit 1
[ "$rc" -eq 0 ] && echo "render-test: ok" || exit 1
