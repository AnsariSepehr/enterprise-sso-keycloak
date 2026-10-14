# Architecture

Three ideas shape the design:

1. **Passwords live in one place only: Active Directory.** Keycloak checks a password by binding to AD as the user; nothing is copied.
2. **Keycloak is the single broker.** Applications never talk to AD; they redirect users to Keycloak and receive a signed statement of who the user is.
3. **Apache Knox adapts the Hadoop world.** Most Hadoop web tools cannot speak OIDC or SAML, but they can validate a Knox-signed token.

```mermaid
flowchart TB
  subgraph internal["Internal network"]
    AD1[(DC 1)]:::ad
    AD2[(DC 2)]:::ad
  end
  subgraph sso["SSO server"]
    N1[nginx :443] --> KC[Keycloak 127.0.0.1:8080] --> PG[(PostgreSQL)]
  end
  subgraph wn["Worker node"]
    N2[nginx :443] --> KNOX[Knox 127.0.0.1:8443]
    ZEP[Zeppelin]
  end
  JIRA[Jira server]
  KC -- LDAP --> AD1 & AD2
  JIRA -- SAML --> KC
  KNOX -- OIDC --> KC
  ZEP -. validates hadoop-jwt with Knox public key .- KNOX
  classDef ad fill:#eee,stroke:#999
```

## Trust relationships

| Link | Protocol | What travels | Details |
|---|---|---|---|
| Keycloak ↔ AD | LDAP (plain at present) | bind as user to check password; read-only service account for attributes | [ad-federation](keycloak/ad-federation.md) |
| Jira ↔ Keycloak | SAML 2.0 via miniOrange app | signed assertion with the user name | [jira](services/jira.md) |
| Knox ↔ Keycloak | OIDC (pac4j), authorisation code flow, confidential client | code → identity → Knox-signed token | [knox](services/knox.md) |
| Zeppelin ↔ Knox | JWT in cookie `hadoop-jwt` | signature checked with Knox public key; Zeppelin never talks to Keycloak | [zeppelin](services/zeppelin.md) |
| Browser ↔ every host | HTTPS via nginx | TLS ends at nginx with a public wildcard certificate | [keycloak/deployment](keycloak/deployment.md) |

## Login sequence for Zeppelin (the longest chain)

```mermaid
sequenceDiagram
  participant B as Browser
  participant Z as Zeppelin
  participant K as Knox (KnoxSSO)
  participant C as Keycloak
  participant A as Active Directory
  B->>Z: open notebook (no hadoop-jwt cookie)
  Z-->>B: 302 to Knox websso?originalUrl=...
  B->>K: websso
  K-->>B: 302 to Keycloak login (pac4j)
  B->>C: login form
  C->>A: LDAP bind as user
  A-->>C: ok
  C-->>B: 302 back to Knox with code
  B->>K: callback?code=...
  K->>C: exchange code (client secret)
  K-->>B: set hadoop-jwt (domain .example.corp), 302 to Zeppelin
  B->>Z: request with hadoop-jwt
  Z->>Z: verify signature with knox-sso.pem, open session
```

## Sessions you have to think about (important for logout)

A signed-in user has **three** independent sessions: the Keycloak session, Knox's `pac4j.session.*` cookies, and Knox's `hadoop-jwt`. Ending only one of them silently signs the user back in. See [services/knox.md](services/knox.md#logout) and [services/zeppelin.md](services/zeppelin.md#logout).

## Why this shape

A new application needs one client definition in Keycloak and **no change on the domain controllers**. Login policy (MFA, password rules, session lifetime) lives in one place. The price is an extra hop through Knox for Hadoop tools and a more involved logout.
