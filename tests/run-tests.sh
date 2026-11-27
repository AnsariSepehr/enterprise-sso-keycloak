#!/usr/bin/env bash
# Runs every offline test of this repository. No server, no network, no Docker needed.
#   bash tests/run-tests.sh
# Covers: shell syntax and ShellCheck, template rendering, the XML property editor, the Nextcloud
# patch tool, the logout block generator, the link checker and the secret scan.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
fail=0; pass=0
t() { local name="$1"; shift; if out="$("$@" 2>&1)"; then printf '  [ok]   %s\n' "$name"; pass=$((pass+1)); else printf '  [FAIL] %s\n%s\n' "$name" "$(printf '%s' "$out" | sed 's/^/           /')"; fail=$((fail+1)); fi; }
work="$(mktemp -d)"
created_env=0
[ -f config/env/sso.env ] || { cp config/env/sso.env.example config/env/sso.env; created_env=1; }
trap 'rm -rf "$work"; [ "$created_env" -eq 1 ] && rm -f config/env/sso.env' EXIT

echo "Shell scripts"
t "bash -n on every script" bash -c 'for f in scripts/*/*.sh tests/*.sh; do bash -n "$f" || exit 1; done'
if command -v shellcheck >/dev/null; then
  t "ShellCheck (warnings and errors)" bash -c 'shellcheck -x -S warning scripts/*/*.sh tests/*.sh'
else echo "  [skip] ShellCheck not installed"; fi
t "scripts are executable" bash -c '[ -z "$(find scripts -name "*.sh" ! -perm -u+x)" ]'

echo "Templates"
t "every template renders, XML and YAML are valid" bash scripts/tools/render-test.sh

echo "XML property editor (Ranger, Zeppelin)"
x="$work/ranger.xml"; cp tests/fixtures/ranger-admin-site.xml "$x"
t "first run replaces 3, adds 1, fills the empty value, leaves 2 unchanged" bash -c "python3 scripts/lib/xml_props.py '$x' tests/fixtures/ranger-sso.props | grep -c -E 'replaced|added' | grep -qx 5"
t "result is well-formed XML" xmllint --noout "$x"
t "stale provider is gone, Knox is in" bash -c "! grep -q stale-idp '$x' && grep -q 'https://knox.example.corp/gateway/knoxsso/api/v1/websso' '$x'"
t "special characters are escaped (& in a value)" grep -q 'a=1&amp;b=2' "$x"
t "second run is a no-op (idempotent)" bash -c "python3 scripts/lib/xml_props.py '$x' tests/fixtures/ranger-sso.props | grep -vc unchanged | grep -qx 0"
t "--check exits 0 when nothing would change" python3 scripts/lib/xml_props.py "$x" tests/fixtures/ranger-sso.props --check
cp tests/fixtures/ranger-admin-site.xml "$work/c.xml"
t "--check exits 1 and writes nothing when something would change" bash -c "! python3 scripts/lib/xml_props.py '$work/c.xml' tests/fixtures/ranger-sso.props --check >/dev/null && cmp -s '$work/c.xml' tests/fixtures/ranger-admin-site.xml"
sed 's#</configuration>#<property><name>ranger.sso.enabled</name><value>x</value></property></configuration>#' tests/fixtures/ranger-admin-site.xml > "$work/dup.xml"
t "a property that appears twice aborts instead of guessing" bash -c "! python3 scripts/lib/xml_props.py '$work/dup.xml' tests/fixtures/ranger-sso.props >/dev/null 2>&1"

echo "Nextcloud uppercase patch"
lc="$work/LoginController.php"; cp tests/fixtures/LoginController.php "$lc"
t "patches the fixture" bash -c "python3 scripts/nextcloud/patch_login_controller.py '$lc' | grep -qx patched"
t "the patched line sits after the claim is read and before the null check" bash -c "awk '/getClaimValue/{a=NR} /strtoupper\\(\\\$userId\\)/{b=NR} /\\\$userId === null/{c=NR} END{exit !(a<b && b<c)}' '$lc'"
t "a pristine copy is kept as .orig" cmp -s "$lc.orig" tests/fixtures/LoginController.php
t "second run reports already patched (exit 3)" bash -c "python3 scripts/nextcloud/patch_login_controller.py '$lc' >/dev/null; [ \$? -eq 3 ]"
t "--check sees the patch" python3 scripts/nextcloud/patch_login_controller.py "$lc" --check
t "--revert restores the original byte for byte" bash -c "python3 scripts/nextcloud/patch_login_controller.py '$lc' --revert >/dev/null && cmp -s '$lc' tests/fixtures/LoginController.php"
printf '<?php\n// no anchor here\n' > "$work/other.php"
t "refuses a file without the anchor (exit 2) and leaves it alone" bash -c "python3 scripts/nextcloud/patch_login_controller.py '$work/other.php' >/dev/null 2>&1; [ \$? -eq 2 ] && ! grep -q strtoupper '$work/other.php'"

echo "Logout block generator"
t "generates a block with the three cookies and the return address" bash -c "bash scripts/tools/gen-app-logout.sh demo demo.example.corp 2>/dev/null | grep -c -E 'hadoop-jwt=;|pac4jUserProfiles=;|pac4jRequestedUrl=;|post_logout_redirect_uri=https%3A%2F%2Fdemo.example.corp%2F' | grep -qx 4"
t "rejects a host outside the SSO domain" bash -c "! bash scripts/tools/gen-app-logout.sh demo evil.example.org >/dev/null 2>&1"

echo "Documentation"
t "all relative links and anchors resolve" python3 scripts/tools/check-links.py

echo "Secrets"
t "no real values, addresses or keys are committed" bash scripts/tools/check-secrets.sh

echo
echo "tests: $pass passed, $fail failed"
exit "$fail"
