# Phase 1b — What is done in the Keycloak web UI

Anything that has no script is listed here, in order. Admin console: `https://sso.example.corp/admin/`.

## 1. Permanent administrator

Keycloak warns that the bootstrap user is temporary.

1. **Users → Add user**: create a permanent administrator (not called `admin`).
2. **Credentials**: set a strong, *non-temporary* password.
3. **Role mapping**: assign the `admin` realm role.
4. Log in as that user, then **delete the temporary `admin` user**.
5. On the server: remove `KC_BOOTSTRAP_ADMIN_USERNAME` / `KC_BOOTSTRAP_ADMIN_PASSWORD` from `/etc/keycloak/keycloak.env` and `systemctl restart keycloak`.

## 2. Create the realm

**Create realm → name `CORP`.** The `master` realm holds only Keycloak's own administrators; company users and clients belong in `CORP`.

## 3. Next, in this order

| What | Document |
|---|---|
| LDAP user federation to Active Directory | [ad-federation.md](ad-federation.md) |
| SAML client for Jira | [../services/jira.md](../services/jira.md) |
| OIDC client `knox` (also serves Zeppelin and Ranger) | [../services/knox.md](../services/knox.md#keycloak-client-for-knox) |
| OIDC client `grafana` + group `grafana-admins` + `groups` mapper | [../services/grafana.md](../services/grafana.md#1-keycloak-side) |
| OIDC client `nextcloud` + `ldap_id` mapper | [../services/nextcloud.md](../services/nextcloud.md#1-keycloak-side) |

## Verify

- `https://sso.example.corp/realms/CORP/account` — a domain user can sign in with the normal AD password.
- `https://sso.example.corp/realms/CORP/.well-known/openid-configuration` — returns JSON.
- `https://sso.example.corp/realms/CORP/protocol/saml/descriptor` — returns XML (needed by Jira).

### Every client at a glance

| Client | Protocol | Valid redirect URI | Post-logout URIs |
|---|---|---|---|
| `knox` | OIDC, confidential | `https://<KNOX_HOSTNAME>/gateway/knoxsso/api/v1/websso` | Knox home, Zeppelin and Ranger addresses |
| Jira | SAML 2.0 | assertion consumer address from the app | not used |
| `grafana` | OIDC, confidential | `https://<GRAFANA_HOSTNAME>/login/generic_oauth` | `https://<GRAFANA_HOSTNAME>/login` |
| `nextcloud` | OIDC, confidential | `https://<NEXTCLOUD_HOSTNAME>/apps/user_oidc/code` | `https://<NEXTCLOUD_HOSTNAME>/` |

Redirect and post-logout addresses must match **exactly**: a missing post-logout address is what shows an *invalid redirect URI* error at the end of a logout.

> Screenshots: put masked screenshots in `docs/img/` and link them here. Blur host names, tokens, user names and browser tabs first ([security checklist](../security-checklist.md)).
