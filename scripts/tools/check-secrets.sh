#!/usr/bin/env bash
# Scan the repository for things that must never be published.
#   1. generic patterns (private IPs, private keys, long random strings, assigned passwords)
#   2. YOUR real values: put one regular expression per line in .forbidden-terms (git-ignored),
#      e.g. your real domain, host names, user names. See .forbidden-terms.example.
# Exit code 1 if anything is found. Run before every commit (see CONTRIBUTING.md) and in CI.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
fail=0
files() { git ls-files -co --exclude-standard 2>/dev/null || find . -type f -not -path './.git/*'; }
scan() {  # scan LABEL REGEX
  local out
  out="$(files | grep -vE '\.(docx|png|jpg|pdf)$|^scripts/tools/check-secrets.sh$' | xargs -r grep -nIiE -- "$2" 2>/dev/null)"
  if [ -n "$out" ]; then printf '\n[FOUND] %s\n%s\n' "$1" "$out"; fail=1; fi
}
scan "private IPv4 address (use <SSO_IP>, <DC1_IP> ...)" '(^|[^0-9.])(10\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])|192\.168)\.[0-9]{1,3}\.[0-9]{1,3}'
scan "private key material" '-----BEGIN (RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----'
scan "long random-looking alphanumeric string (possible secret)" '[A-Za-z0-9]{40,}'
scan "password/secret/api key assigned a real-looking value" '(password|passwd|secret|api[_-]?key|client_secret)[[:space:]]*[=:][[:space:]]*["'"'"']?[^<${[:space:]"'"'"'#`][^[:space:]"'"'"']{5,}'
scan "XML secret parameter with a literal value" '(secret|password)</name><value>[^<$]'
if [ -f .forbidden-terms ]; then
  while IFS= read -r term; do
    [ -z "$term" ] && continue; case "$term" in \#*) continue;; esac
    scan "your forbidden term: $term" "$term"
  done < .forbidden-terms
else
  echo "note: no .forbidden-terms file; only generic patterns were checked." >&2
fi
if [ "$fail" -eq 0 ]; then echo "check-secrets: clean"; else echo; echo "check-secrets: FAILED - fix the lines above before committing"; fi
exit "$fail"
