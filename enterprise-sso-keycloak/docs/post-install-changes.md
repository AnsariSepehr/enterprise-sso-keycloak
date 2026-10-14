# Post-install changes, workarounds and deliberate shortcuts

Everything we changed **after** a clean install, everything that deviates from "textbook clean", and everything that weakens security on purpose or by necessity. Nothing here is hidden: each item says *what*, *why*, *risk* and *how to undo it*.

> Think of this as the list a security reviewer would ask for first.

## A. Temporary shortcuts that weaken security (fix these)

| # | What was done | Why | Risk | How to undo |
|---|---|---|---|---|
| A1 | **Plain LDAP** to AD, StartTLS off, no certificate validation | DC LDAPS certificates expired in 2019; CA enrolment failed (RPC error), root cause unknown | bind and user passwords cross the network in clear text | renew DC certs → import CA root into Keycloak truststore → `ldaps://`, Use Truststore SPI = Always ([ad-federation](keycloak/ad-federation.md#closing-the-ldaps-gap-later)) |
| A2 | **SAML client signature required = Off** (Jira client) | `invalid_signature` errors; imported miniOrange key reverted | unsigned authn requests accepted | re-import miniOrange cert in Keys tab, test, turn on ([jira](services/jira.md#3-request-signing-and-the-expired-certificate)) |
| A3 | **All AD users in the realm may sign in to Zeppelin** and run interpreters as the `zeppelin` OS user | no group restriction configured yet | any directory user can execute code on the worker | Keycloak: require a group/role for client `knox` (or an authentication-flow condition), and map roles in Zeppelin |
| A4 | **Knox listens on plain HTTP :8443** behind nginx | TLS is terminated at nginx | if 8443 is reachable from the network, TLS is bypassed | bind to 127.0.0.1 / firewall it (*not verified in the original build*) |
| A5 | Original build kept the **DB and bootstrap-admin passwords in `keycloak.conf` / the unit file** | quick start | secrets readable by anyone who can read those files | the scripts here already use `/etc/keycloak/keycloak.env` (mode 640) |
| A6 | Jira **password login kept** next to SSO | so nobody gets locked out while testing | bypasses SSO policy for local accounts | keep **one** break-glass admin; disable password login for everyone else once SSO is trusted |
| A7 | Knox `knoxsso.redirect.whitelist.regex` allows **any host under the domain** | default allows only localhost and blocked Zeppelin | an open redirect to any `*.example.corp` host | tighten to the exact hosts (`knox`, `zeppelin`, ...) |

## B. Workarounds for product behaviour (keep, but know them)

| # | What | Why | Where |
|---|---|---|---|
| B1 | **nginx `location = /logout`** on the Knox host expiring `hadoop-jwt` and the `pac4j.session.*` cookies, then redirecting to Keycloak logout | Knox's own logout leaves three sessions alive | [knox](services/knox.md#logout), [`knox.conf.example`](../config/nginx/knox.conf.example) |
| B2 | **Replaced `oauth2-oidc-sdk-8.22.jar` with 9.13** in Knox `dep/` (old jar kept in `/root/knox-jar-backup`) | HTTP 500 `NoSuchMethodError` after login | [knox](services/knox.md#library-fix-http-500-after-a-successful-keycloak-login) — **repeat after every Knox upgrade** |
| B3 | **Copied Knox's self-signed public certificate** to Zeppelin as `conf/knox-sso.pem` | Zeppelin must verify Knox's JWT signature | [zeppelin](services/zeppelin.md#1-export-the-knox-public-key) — re-copy on regeneration, expires Oct 2027 |
| B4 | `HADOOP_HOME` / `HADOOP_CONF_DIR` added to `zeppelin-env.sh` | `KnoxJwtRealm` needs Hadoop classes | [zeppelin](services/zeppelin.md#2-hadoop-environment-variables-first-crash) |
| B5 | `[users]` in `shiro.ini` **emptied**, `securityManager.realms = $knoxJwtRealm` | sample users would allow password logins that bypass SSO | [zeppelin](services/zeppelin.md#3-shiroini) |
| B6 | pac4j/buji jars **moved out of Zeppelin `lib/`** into a backup dir | failed direct-OIDC attempt | [zeppelin](services/zeppelin.md#the-failed-first-attempt-direct-oidc-in-zeppelin) |
| B7 | Jira: *Allow User Creation* off while testing; users matched on the `username` attribute | duplicate accounts due to NameID case/format | [jira](services/jira.md#5-testing-and-the-user-matching-problem) |
| B8 | Keycloak mapper `User Property username → username` on the Jira client | same | [jira](services/jira.md) |
| B9 | nginx upload/timeout limits **raised** on the SSO server | coincided with the certificate import working; cause unconfirmed | [jira](services/jira.md#3-request-signing-and-the-expired-certificate) |

## C. System-level changes on the servers

| # | Change | Reason |
|---|---|---|
| C1 | `setsebool -P httpd_can_network_connect 1` (SSO server **and** worker) | SELinux blocked nginx → upstream (502) |
| C2 | `password_encryption = scram-sha-256` and the DB password re-set | scram/md5 mismatch |
| C3 | FreeIPA server **uninstalled**, `pki-tomcatd@pki-tomcat` disabled | held port 8080, conflicted with Keycloak |
| C4 | firewalld: `http` and `https` services permanently allowed | public entry |
| C5 | Dedicated users `keycloak`, `knox` with `/sbin/nologin`; `zeppelin` runs the notebook service | least privilege for services |
| C6 | Hostname set to the SSO FQDN | Keycloak's hostname setting must match |
| C7 | Keycloak: temporary `admin` deleted after a permanent admin was created; separate realm `CORP` | do not use `master` for company users |
| C8 | Windows Firewall on the DC/CA was **temporarily turned off** during the enrolment test | diagnostics — confirm it was turned back **on** |

## D. Things that were tried and **rolled back** (do not repeat)

- Separate `knoxssout.xml` topology (404) — `KNOXSSOUT` belongs inside the existing topology.
- `pac4j.centralLogout` / `logoutUrlPattern` — no effect on Knox logout; still in the template, commented as "reference only".
- Direct OIDC in Zeppelin via pac4j/buji — impossible with `shiro.ini` only in 0.12.1.
- Importing the miniOrange certificate as the signature key — reverted after refresh; signature validation off.

## Hardening the scripts add over the manual build

Secrets are prompted for and kept out of repo-tracked files; DB password is not in `keycloak.conf`; topology rendered mode 600; the XML secret is escaped; downloads of the Knox patch jar are checksum-verified; nothing destructive (FreeIPA removal) is automated.
