#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
load_env
# Print the nginx location block that gives ONE application its own logout address on the Knox host.
#   usage: gen-app-logout.sh <app> <application host name>
#   e.g.   gen-app-logout.sh gitlab gitlab.example.corp
# Paste the output into the Knox server block (config/nginx/knox.conf.example), reload nginx, add
# https://<host>/ to "Valid post logout redirect URIs" of the Keycloak client 'knox', and point the
# application's Logout at https://$KNOX_HOSTNAME/logout/<app>. docs/adding-a-service.md, step 6.
app="${1:-}"; host="${2:-}"
[[ "$app" =~ ^[a-z0-9-]+$ ]] || die "usage: $0 <app> <host>   (app: lower-case letters, digits, dashes)"
[[ "$host" =~ ^[a-z0-9.-]+\.${DOMAIN_REGEX}$ ]] || die "host must end in .$DOMAIN so that the cookie domain and the Keycloak whitelist match"
cat <<NGINX
    # /logout/$app -> $host
    location = /logout/$app {
        add_header Set-Cookie "hadoop-jwt=; Domain=.$DOMAIN; Path=/; Max-Age=0; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Secure; HttpOnly" always;
        add_header Set-Cookie "pac4j.session.pac4jUserProfiles=; Domain=.$DOMAIN; Path=/gateway/knoxsso/api/v1; Max-Age=0; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Secure; HttpOnly" always;
        add_header Set-Cookie "pac4j.session.pac4jRequestedUrl=; Domain=.$DOMAIN; Path=/gateway/knoxsso/api/v1; Max-Age=0; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Secure; HttpOnly" always;
        add_header Cache-Control "no-store" always;
        return 302 https://$SSO_HOSTNAME/realms/$REALM/protocol/openid-connect/logout?client_id=knox&post_logout_redirect_uri=https%3A%2F%2F$host%2F;
    }
NGINX
echo "# Remember: add https://$host/ to the Keycloak client 'knox' under Valid post logout redirect URIs." >&2
