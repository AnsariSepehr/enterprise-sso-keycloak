# Apache Knox — gateway and Keycloak OIDC federation

Knox 2.1.0 on the worker node signs users in through Keycloak and hands each browser a signed cookie, `hadoop-jwt`, that other Hadoop-side tools trust. Login works. Knox's own logout does **not** end the Keycloak session; a workaround exists.

**Why Knox:** Zeppelin 0.12.1 has no working direct OIDC in this build ([zeppelin.md](zeppelin.md#the-failed-first-attempt-direct-oidc-in-zeppelin)), and other Hadoop UIs (YARN, Hive, ...) are planned for SSO as well; Knox can front all of them. Knox is a *gateway*, not an IdP: it forwards authentication to Keycloak and then issues its own token.

**Automation:** [`scripts/knox/`](../../scripts/knox)

| Step | Script / UI |
|---|---|
| install | `01-install-knox.sh` |
| service + nginx (+ logout workaround) | `02-install-service-and-nginx.sh` |
| Keycloak client `knox` | [UI, below](#keycloak-client-for-knox) |
| topology | `03-apply-topology.sh` |
| library fix | `04-patch-oidc-sdk.sh` |

## Install

```bash
cd /opt
curl -O https://dlcdn.apache.org/knox/2.1.0/knox-2.1.0.tar.gz
tar -xzf knox-2.1.0.tar.gz && mv knox-2.1.0 knox
sudo useradd -m -s /sbin/nologin knox
sudo chown -R knox:knox /opt/knox
sudo -u knox /opt/knox/bin/knoxcli.sh create-master      # choose a strong master secret, store it safely
```

Knox ships example topologies in `/opt/knox/conf/topologies`, including `knoxsso.xml`, which by default logs users in against a **demo LDAP**. `gateway-site.xml` was already `gateway.port=8443`, `ssl.enabled=false`: Knox speaks plain HTTP internally and nginx provides HTTPS.

> **Check:** make sure port 8443 is only reachable from the worker node itself (or via a firewall). Plain HTTP on a network-reachable port would bypass nginx's TLS. *Not verified in the original build.*

## Service and reverse proxy

Unit: [`config/knox/knox.service.example`](../../config/knox/knox.service.example). nginx: [`config/nginx/knox.conf.example`](../../config/nginx/knox.conf.example) (same wildcard cert, forwards to `http://127.0.0.1:8443`, `proxy_read_timeout 3600s`, larger buffers). Needs a DNS record for `knox.example.corp` and `setsebool -P httpd_can_network_connect 1` on this host too.

Early requests showed `upstream sent no valid HTTP/1.0 header` in the nginx log, which usually means nginx speaks plain HTTP to a TLS port. It was not diagnosed separately; the gateway answered normally after later restarts and changes.

## Keycloak client for Knox

Realm `CORP` → **Clients → Create client**, OpenID Connect:

| Setting | Value |
|---|---|
| Client ID | `knox` |
| Client authentication | **On** (confidential); secret on the *Credentials* tab |
| Authentication flow | Standard flow only |
| Root URL | `https://knox.example.corp` |
| Home URL | `https://knox.example.corp/gateway/homepage/home/` (the first value pointed at a page that does not exist → 404 from the *Back to Application* link) |
| Valid redirect URIs | `https://knox.example.corp/gateway/knoxsso/api/v1/websso*` (wildcard needed: pac4j appends query parameters) |
| Valid post logout redirect URIs | `https://knox.example.corp/gateway/homepage/home/` |
| Web origins | `https://knox.example.corp` |

Copy the client secret **into your password manager and into the script prompt only** — never into a file in this repo.

## Topology: replace the demo login with Keycloak

Template: [`config/knox/knoxsso.xml.example`](../../config/knox/knoxsso.xml.example). In `knoxsso.xml` the ShiroProvider block is removed and a **pac4j federation** provider added. Knox deploys topology changes automatically within seconds.

Key parameters:

| Parameter | Why |
|---|---|
| `pac4j.callbackUrl` | the Knox websso endpoint registered as redirect URI in Keycloak |
| `oidc.discoveryUri` | Keycloak's `.well-known/openid-configuration` |
| `pac4j.id_attribute = preferred_username` | the user name Knox puts in its token |
| `knoxsso.redirect.whitelist.regex` | **default allows only localhost** → otherwise *"The original URL ... is not valid according to the configured whitelist"* |
| `knoxsso.cookie.domain.suffix = .example.corp` | makes `hadoop-jwt` visible to `zeppelin.example.corp` too |
| `knoxsso.token.ttl = 86400000` | 24 h |
| `pac4j.centralLogout`, `pac4j.logoutUrlPattern` | added while chasing logout; **did not help**, kept for reference |
| `KNOXSSOUT` service | provides `webssout`; it is a service **inside** the existing topology |

The rendered file contains the client secret: `chmod 600`, owner `knox`, never committed (the script does this and verifies the XML parses).

## Library fix: HTTP 500 after a successful Keycloak login

Login at Keycloak worked, returning to Knox gave HTTP 500:

```
Caused by: java.lang.NoSuchMethodError: 'net.minidev.json.JSONObject com.nimbusds.jwt.JWTClaimsSet.toJSONObject()'
 at com.nimbusds.openid.connect.sdk.claims.IDTokenClaimsSet.<init> (oauth2-oidc-sdk-8.22.jar)
```

Knox 2.1.0 bundles `oauth2-oidc-sdk-8.22.jar` next to a much newer `nimbus-jose-jwt-10.0.2.jar`; they are incompatible. Replacing the old jar with **9.13** fixed it (`04-patch-oidc-sdk.sh`: downloads, verifies the SHA-1, stops Knox, moves the old jar to a backup dir, copies the new one, starts Knox).

**This is a manual patch to a vendor bundle.** Repeat it after every Knox upgrade, and check whether the newer release fixes it.

## Verify login

Open `https://knox.example.corp/gateway/homepage/home/` in a private window → redirect to Keycloak → password → back on the Knox home page with your name. Two things that look like failures but are not:

- `/gateway/knoxsso/api/v1/websso` with no `originalUrl` returns HTTP 500 — a real login always supplies it.
- Pasting a logout URL into a fresh tab can show *State cannot be determined*: login state lives in cookies from the earlier request.
- (Also cosmetic) `.../webssout` returns `{"loggedOut":true}`; Firefox shows an XML parse error for it.

The landing page is `/gateway/homepage/home/` — `/gateway/homepage/` alone is a 404.

## Logout

After pressing **Logout** on the Knox home page the user came back signed in as the same person. Tracing requests and cookies showed why:

| Session / cookie | Where | Effect if it survives |
|---|---|---|
| `hadoop-jwt` | domain `.example.corp`, path `/` | Knox accepts the browser without asking anyone |
| `pac4j.session.pac4jUserProfiles` | domain `.example.corp`, path `/gateway/knoxsso/api/v1` | if `hadoop-jwt` is missing, Knox quietly issues a new one from this stored profile |
| Keycloak session | Keycloak host | signs the user in again without a password |

The Knox home page's button opens `/gateway/knoxsso/knoxauth/logout.jsp`, which clears only Knox's local state. The `KNOXSSOUT` service (`/gateway/homepage/knoxssout/api/v1/webssout`, found by reading the strings inside the Knox jar) returns `{"loggedOut":true}` but, as far as the tests showed, also clears only Knox's own cookie. Deleting every pac4j cookie one by one changed nothing until `hadoop-jwt` was deleted too; deleting **both** gave the Keycloak login page.

A separate `knoxssout.xml` topology was tried first and returned 404 — **wrong design, removed**.

### Workaround: `/logout` on the Knox host

nginx expires both Knox cookies and redirects to Keycloak's logout endpoint (`location = /logout` in the Knox nginx template). Visiting `https://knox.example.corp/logout` and confirming on Keycloak's page leads to the Keycloak login page and another user can then sign in. Keycloak shows *"Do you want to log out?"* because no `id_token_hint` is sent. Users must be sent to this URL; **the Knox home page's own button still performs only the local logout.**

Cookie names, domains and paths must match the stored cookies exactly or the browser ignores the deletion.
