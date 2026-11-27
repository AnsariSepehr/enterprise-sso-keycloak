# Post-install changes, workarounds and deliberate shortcuts

Everything we changed **after** a clean install, everything that deviates from "textbook clean", and everything that weakens security on purpose or by necessity. Nothing here is hidden: each item says *what*, *why*, *risk* and *how to undo it*.

> Think of this as the list a security reviewer would ask for first.

## A. Temporary shortcuts that weaken security (fix these)

| # | What was done | Why | Risk | How to undo |
|---|---|---|---|---|
| A1 | **Plain LDAP** to AD, StartTLS off, no certificate validation | DC LDAPS certificates expired in 2019; CA enrolment failed (RPC error), root cause unknown | bind and user passwords cross the network in clear text | renew DC certs → import CA root into Keycloak truststore → `ldaps://`, Use Truststore SPI = Always ([ad-federation](keycloak/ad-federation.md#closing-the-ldaps-gap-later)) |
| A2 | **SAML client signature required = Off** (Jira client) | `invalid_signature` errors; imported miniOrange key reverted | unsigned authn requests accepted | re-import miniOrange cert in Keys tab, test, turn on ([jira](services/jira.md#3-request-signing-and-the-expired-certificate)) |
| A3 | **Every enabled directory user may sign in to every application**, in Zeppelin as the `zeppelin` OS user running interpreters (the search base was [widened](keycloak/ad-federation.md#widening-the-search-base-users-outside-the-staff-ou)) | no group restriction configured yet | any directory user can execute code on the worker | Keycloak: require a group/role for client `knox` (or an authentication-flow condition), and map roles in Zeppelin |
| A4 | **Knox listens on plain HTTP :8443** behind nginx | TLS is terminated at nginx | if 8443 is reachable from the network, TLS is bypassed | bind to 127.0.0.1 / firewall it (*not verified in the original build*) |
| A5 | Original build kept the **DB and bootstrap-admin passwords in `keycloak.conf` / the unit file** | quick start | secrets readable by anyone who can read those files | the scripts here already use `/etc/keycloak/keycloak.env` (mode 640) |
| A6 | Jira **password login kept** next to SSO | so nobody gets locked out while testing | bypasses SSO policy for local accounts | keep **one** break-glass admin; disable password login for everyone else once SSO is trusted |
| A7 | Knox `knoxsso.redirect.whitelist.regex` allows **any host under the domain** | default allows only localhost and blocked Zeppelin | an open redirect to any `*.example.corp` host | tighten to the exact hosts (`knox`, `zeppelin`, ...) |
| A8 | **Ranger Admin listens on every interface on 6080**, no host firewall runs on the Ranger node | Ranger plugins and usersync fetch policies there | a browser can bypass nginx and TLS; anyone who can reach the node can reach Ranger | restrict 6080 to the plugin and usersync hosts, start a host firewall ([ranger](services/ranger.md#8-open-items)) |
| A9 | **Client secret for Grafana travels as a Swarm environment variable**; the first build also kept the Grafana admin password **in the stack file in plain text** | `docker stack deploy` substitutes variables from the shell, no secret store was set up | visible in `docker service inspect` to anyone with Docker access | Docker secret (`GRAFANA_SECRET_MODE=docker-secret`, unverified); replace the admin password ([grafana](services/grafana.md#passing-the-secret--and-why-the-first-deployment-failed)) |
| A10 | **Keycloak search base widened** to include accounts outside the staff OU (e.g. the built-in Administrator) | those accounts could not sign in at all | enabled domain users outside the OU can now sign in everywhere | narrow with a `memberOf` filter or a Keycloak group requirement ([ad-federation](keycloak/ad-federation.md#widening-the-search-base-users-outside-the-staff-ou)) |
| A11 | **Local logins kept as break-glass** in Ranger, Grafana, Nextcloud and Jira | so an SSO outage does not lock everybody out | these accounts bypass SSO policy | keep exactly one per service, passwords offline, test regularly, review log entries ([break-glass](break-glass.md)) |

## B. Workarounds for product behaviour (keep, but know them)

| # | What | Why | Where |
|---|---|---|---|
| B1 | **nginx `location = /logout`, `/logout/ranger`, `/logout/knox`** on the Knox host expiring `hadoop-jwt` and the `pac4j.session.*` cookies, then redirecting to Keycloak logout and back to one application each | Knox's own logout leaves three sessions alive | [knox](services/knox.md#one-logout-address-per-application), [`knox.conf.example`](../config/nginx/knox.conf.example) |
| B2 | **Replaced `oauth2-oidc-sdk-8.22.jar` with 9.13** in Knox `dep/` (old jar kept in `/root/knox-jar-backup`) | HTTP 500 `NoSuchMethodError` after login | [knox](services/knox.md#library-fix-http-500-after-a-successful-keycloak-login) — **repeat after every Knox upgrade** |
| B3 | **Copied Knox's self-signed public certificate** to Zeppelin as `conf/knox-sso.pem` | Zeppelin must verify Knox's JWT signature | [zeppelin](services/zeppelin.md#1-export-the-knox-public-key) — re-copy on regeneration, expires Oct 2027 |
| B4 | `HADOOP_HOME` / `HADOOP_CONF_DIR` added to `zeppelin-env.sh` | `KnoxJwtRealm` needs Hadoop classes | [zeppelin](services/zeppelin.md#2-hadoop-environment-variables-first-crash) |
| B5 | `[users]` in `shiro.ini` **emptied**, `securityManager.realms = $knoxJwtRealm` | sample users would allow password logins that bypass SSO | [zeppelin](services/zeppelin.md#3-shiroini) |
| B6 | pac4j/buji jars **moved out of Zeppelin `lib/`** into a backup dir | failed direct-OIDC attempt | [zeppelin](services/zeppelin.md#the-failed-first-attempt-direct-oidc-in-zeppelin) |
| B7 | Jira: *Allow User Creation* off while testing; users matched on the `username` attribute | duplicate accounts due to NameID case/format | [jira](services/jira.md#5-testing-and-the-user-matching-problem) |
| B8 | Keycloak mapper `User Property username → username` on the Jira client | same | [jira](services/jira.md) |
| B9 | nginx upload/timeout limits **raised** on the SSO server | coincided with the certificate import working; cause unconfirmed | [jira](services/jira.md#3-request-signing-and-the-expired-certificate) |
| B10 | Zeppelin's **classic UI is the default** (`zeppelin.default.ui=classic`) | only the classic Logout button follows `knoxJwtRealm.logout` | [zeppelin](services/zeppelin.md#resolution-the-classic-front-end) — optional from 0.12.0, re-check on upgrade |
| B11 | Zeppelin admin pages limited **by user name** with `anyofrolesuser[admin, <names>]` on five URL rules | Knox supplies no role Zeppelin maps | [zeppelin](services/zeppelin.md#roles-and-administrators) — edit all five lines to add an administrator |
| B12 | Ranger's `ranger.sso.*` values **replaced in the live file** (`conf.dist`); a stale earlier attempt removed | wrong provider and wrong key were active | [ranger](services/ranger.md#22-point-ranger-at-knox) — refresh the Knox certificate copy with Zeppelin's |
| B13 | **nginx rule on Ranger's `/index.html?action=timeout`** redirecting to `/logout/ranger` and expiring `RANGERADMINSESSIONID` | Ranger has no logout setting and its UI never calls a logout endpoint with SSO on | [ranger](services/ranger.md#4-logout) — re-check after a Ranger upgrade |
| B14 | Ranger **JMX exporter rules file created by hand** (`/opt/jmx_exporter/ranger-jmx.yml`) | a missing file makes the agent end the JVM at start | [ranger](services/ranger.md#23-the-restart-that-failed-for-an-unrelated-reason) — cause of the missing file unknown |
| B15 | Ranger SSO users **promoted through the REST API** | the UI form cannot be saved for externally created users | [ranger](services/ranger.md#5-access-control) — route unverified, read the role back |
| B16 | Grafana: roles from the `groups` claim (`ALLOW_ASSIGN_GRAFANA_ADMIN`, role expression), `AUTO_LOGIN` on, sign-out address set | administrators managed in Keycloak; Keycloak is the main login | [grafana](services/grafana.md#2-service-side) |
| B17 | Nextcloud: **`user_oidc` patched** (`strtoupper` on the user ID), `auto_provision=false`, `overwriteprotocol=https`, group sync off, `--mapping-uid=ldap_id --unique-uid=0` | existing LDAP accounts use upper-case GUIDs; no duplicates, no stripped admin group | [nextcloud](services/nextcloud.md#the-case-problem-and-the-one-line-patch) — **re-apply after every `user_oidc` update** |
| B18 | Keycloak LDAP provider: **Users DN widened**, enabled-person filter, Referral `ignore`, periodic sync on | accounts outside the staff OU were invisible | [ad-federation](keycloak/ad-federation.md#widening-the-search-base-users-outside-the-staff-ou) |

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
| C9 | Ranger node: **nginx installed**, SELinux boolean `httpd_can_network_connect` on; **firewalld was not running** and was left alone | HTTPS in front of Ranger; 6080 is not a web port |
| C10 | Monitoring node: Grafana deployed into the existing **Docker Swarm stack** without `--prune`, variables exported in the shell | `docker stack deploy` reads no `.env` file |
| C11 | Nextcloud container: `occ app:install user_oidc` (8.11.0) through the app store | the official OpenID Connect app |

## D. Things that were tried and **rolled back** (do not repeat)

- Separate `knoxssout.xml` topology (404) — `KNOXSSOUT` belongs inside the existing topology.
- `pac4j.centralLogout` / `logoutUrlPattern` — no effect on Knox logout; still in the template, commented as "reference only".
- Direct OIDC in Zeppelin via pac4j/buji — impossible with `shiro.ini` only in 0.12.1.
- Importing the miniOrange certificate as the signature key — reverted after refresh; signature validation off.
- Ranger: a guessed dedicated role endpoint for promoting users — HTTP 404; the whole-user update is used instead.
- Grafana: relying on a `.env` file with `docker stack deploy` — it is not read; the secret was empty.
- Nextcloud: loosening the database collation so lower-case IDs match — rejected (a second identity per user could appear); an `AttributeMappedEvent` listener — not pursued (it may not run with `auto_provision` off).
- Exchange: AD FS or a commercial add-on — not attempted (Exchange 2016 has no modern authentication).

## Hardening the scripts add over the manual build

Secrets are prompted for and kept out of repo-tracked files; configuration edits go through tools that **refuse to guess** (`xml_props.py` and the Nextcloud patch abort unless their anchor matches exactly once, and both are idempotent and unit-tested); DB password is not in `keycloak.conf`; topology rendered mode 600; the XML secret is escaped; downloads of the Knox patch jar are checksum-verified; nothing destructive (FreeIPA removal) is automated.
