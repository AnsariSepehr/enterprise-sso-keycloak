#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
load_env
# Phase 7 - read-only checks for Grafana's Keycloak sign-in.
ok(){ printf '  [ok]   %s\n' "$*"; }; bad(){ printf '  [FAIL] %s\n' "$*"; rc=1; }; note(){ printf '  [info] %s\n' "$*"; }
rc=0
G="https://$GRAFANA_HOSTNAME"
svc="${SWARM_STACK}_grafana"

echo "Service"
if command -v docker >/dev/null && docker service inspect "$svc" >/dev/null 2>&1; then
  ok "service $svc exists"
  env_lines="$(docker service inspect "$svc" --format '{{range .Spec.TaskTemplate.ContainerSpec.Env}}{{println .}}{{end}}')"
  len="$(printf '%s\n' "$env_lines" | awk -F= '/^GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=/ {print length($2)}')"
  if [ -n "$len" ]; then
    # A Keycloak client secret is 32 characters. 0 = the .env file was not read (problem 31).
    [ "$len" -ge 20 ] && ok "client secret reaches the service as an environment variable (length $len; the value is never printed)" || bad "client secret length is $len: it was EMPTY at deploy time (export it in the shell before docker stack deploy)"
  elif printf '%s\n' "$env_lines" | grep -q '^GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET__FILE='; then
    ok "client secret is read from a Docker secret file"
  else
    bad "no client secret setting found on the service"
  fi
  printf '%s\n' "$env_lines" | grep -q '^GF_AUTH_GENERIC_OAUTH_AUTO_LOGIN=true' && ok "Keycloak is the main login (auto login on)" || note "auto login is off: the form shows a Keycloak button"
  printf '%s\n' "$env_lines" | grep -q 'ROLE_ATTRIBUTE_PATH=.*GrafanaAdmin' && ok "administrators come from the groups claim" || bad "role expression missing"
else
  note "no local Docker access to $svc: skipping service checks"
fi

echo "Client secret against Keycloak (only if GRAFANA_OIDC_SECRET is exported)"
if [ -n "${GRAFANA_OIDC_SECRET:-}" ]; then
  # The client has no service account, so a correct secret is answered with unauthorized_client
  # and a wrong or empty one with invalid_client.
  ans="$(curl -s -X POST "https://$SSO_HOSTNAME/realms/$REALM/protocol/openid-connect/token" \
         -d grant_type=client_credentials -d client_id=grafana --data-urlencode "client_secret=$GRAFANA_OIDC_SECRET")"
  case "$ans" in
    *unauthorized_client*) ok "Keycloak accepts the secret (unauthorized_client is the expected answer)" ;;
    *invalid_client*) bad "Keycloak rejects the secret (invalid_client): wrong or empty" ;;
    *) note "unexpected answer: ${ans:0:120}" ;;
  esac
else
  note "skipped"
fi

echo "Sign-in flow"
loc="$(curl -sk -o /dev/null -w '%{http_code} %{redirect_url}' "$G/login")"
case "$loc" in
  "302 "*generic_oauth*) ok "/login goes straight to Keycloak" ;;
  "200 "*) note "/login shows the form (auto login off)" ;;
  *) bad "/login answered: $loc" ;;
esac
auth="$(curl -sk -o /dev/null -w '%{http_code} %{redirect_url}' "$G/login/generic_oauth")"
case "$auth" in
  "302 https://$SSO_HOSTNAME/realms/$REALM/protocol/openid-connect/auth?"*client_id=grafana*) ok "authorisation request goes to Keycloak for client grafana" ;;
  *) bad "/login/generic_oauth answered: $auth" ;;
esac
case "$auth" in *code_challenge=*) ok "PKCE is on" ;; *) bad "no PKCE code_challenge in the request" ;; esac

echo "Break-glass"
[ "$(curl -sk -o /dev/null -w '%{http_code}' "$G/login?disableAutoLogin=true")" = 200 ] && ok "password form reachable at /login?disableAutoLogin=true" || bad "fallback form not reachable (parameter name may have changed in this Grafana version)"
exit "$rc"
