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
| OIDC client `knox` | [../services/knox.md](../services/knox.md#keycloak-client-for-knox) |

## Verify

- `https://sso.example.corp/realms/CORP/account` — a domain user can sign in with the normal AD password.
- `https://sso.example.corp/realms/CORP/.well-known/openid-configuration` — returns JSON.
- `https://sso.example.corp/realms/CORP/protocol/saml/descriptor` — returns XML (needed by Jira).

> Screenshots: put masked screenshots in `docs/img/` and link them here. Blur host names, tokens, user names and browser tabs first ([security checklist](../security-checklist.md)).
