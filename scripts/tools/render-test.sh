#!/usr/bin/env bash
# Renders every config/*.example with the example values into a temp dir and checks the result.
# Proves the templates are consistent, that no ${VAR} is left unresolved, and that the rendered
# XML and YAML are well-formed.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
load_env
export KNOX_OIDC_SECRET='<SECRET>' KC_DB_PASSWORD='<PASSWORD>' KC_BOOTSTRAP_ADMIN_PASSWORD='<PASSWORD>' KNOX_CERT_BASE64='<KNOX_CERT_BASE64>'
KNOX_OIDC_SECRET="$(python3 -c 'import sys,xml.sax.saxutils as s; print(s.escape(sys.argv[1]), end="")' "$KNOX_OIDC_SECRET")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
list=""; for v in $RENDER_VARS; do list+="\${$v} "; done
rc=0
while IFS= read -r -d '' f; do
  out="$tmp/$(basename "$f")"; envsubst "$list" < "$f" > "$out"
  # RUNTIME_VARS are filled in later by another tool (docker stack deploy), on purpose
  if grep -nE '\$\{[A-Z_]+\}' "$out" | grep -vE "\\$\\{($RUNTIME_VARS)\\}"; then echo "unresolved variable in $f"; rc=1; fi
done < <(find "$REPO_ROOT/config" \( -name '*.example' -o -name '*.snippet' \) -print0)

if command -v xmllint >/dev/null; then
  xmllint --noout "$tmp/knoxsso.xml.example" && echo "knoxsso.xml well-formed" || exit 1
  { echo '<configuration>'; cat "$tmp/zeppelin-site.xml.snippet"; echo '</configuration>'; } | xmllint --noout - && echo "zeppelin-site.xml snippet well-formed" || exit 1
fi
grep -q 'example\\.corp' "$tmp/knoxsso.xml.example" && echo "regex escaping ok" || exit 1

# The Grafana stack files must be valid YAML and must carry the settings the docs promise.
if python3 -c 'import yaml' 2>/dev/null; then
  for y in "$tmp"/grafana-stack*.yml.example; do
    python3 - "$y" <<'PY' || rc=1
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1]))
env = doc["services"]["grafana"]["environment"]
role = [e for e in env if e.startswith("GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH=")]
assert role and "'grafana-admins'" in role[0] and "GrafanaAdmin" in role[0], "role expression missing or wrong"
assert any(e.startswith("GF_AUTH_GENERIC_OAUTH_SIGNOUT_REDIRECT_URL=") and "&post_logout_redirect_uri=" in e for e in env), "sign-out address missing"
assert "elk" in doc["networks"] and doc["networks"]["elk"].get("external"), "overlay network must be external"
print("  " + sys.argv[1].split("/")[-1] + ": valid YAML, role expression and sign-out address present")
PY
  done
else
  echo "note: PyYAML not installed; Grafana stack files were not parsed" >&2
fi

# Every app that has a /logout location on the Knox host must also be a legal post-logout target.
for loc in /logout /logout/ranger /logout/knox; do
  grep -q "location = $loc {" "$tmp/knox.conf.example" || { echo "knox.conf.example lacks location $loc"; rc=1; }
done
[ "$rc" -eq 0 ] && echo "render-test: ok" || exit 1
