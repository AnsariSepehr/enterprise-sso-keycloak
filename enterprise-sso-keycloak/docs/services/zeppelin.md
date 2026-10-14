# Apache Zeppelin — Knox JWT integration

Zeppelin 0.12.1 runs on the worker node as user `zeppelin` under systemd ([unit](../../config/zeppelin/zeppelin.service.example)). Two designs were tried: direct OIDC (failed) and Knox JWT (works for sign-in).

**Automation:** [`scripts/zeppelin/01-configure-knox-realm.sh`](../../scripts/zeppelin/01-configure-knox-realm.sh). Do this **after** [Knox login works](knox.md).

> The reverse proxy / public hostname for Zeppelin itself is not covered by the verified build notes; this document only covers the authentication wiring.

## The failed first attempt: direct OIDC in Zeppelin

**Goal:** skip Knox and let Zeppelin authenticate against Keycloak using **pac4j** through **Shiro** (the authentication framework Zeppelin is built on).

**What was done.** Zeppelin 0.12.1 ships Shiro 1.13 (Jakarta build). The pac4j 6.x family and `buji-pac4j` 9.x were added to `lib/`, plus the jars they need: `pac4j-core`, `pac4j-oidc`, `pac4j-jwt`, `pac4j-http`, `pac4j-jakartaee`, `oauth2-oidc-sdk`, `tink`, `commons-collections4`, `json-smart`, `accessors-smart`, `spring-core`, `spring-jcl`.

**What went wrong.** Each start-up gave a new `ClassNotFoundException`; each missing jar was added in turn. After the chain was complete, the config itself failed: `pac4jConfig.clients` expects a `Clients` object, not a client name. The decisive finding came from listing the jars' contents: the Jakarta builds of pac4j 6 and buji-pac4j 9 contain **no `SecurityFilter`, `CallbackFilter` or `LogoutFilter` classes** — the classes a `shiro.ini`-only setup needs. Without them the wiring cannot be done in configuration alone and would need custom Java code.

**Decision:** abandoned *for this Zeppelin version*. All added jars were moved out of `lib/` (backup dir) so the installation is back to its original library set. This conclusion applies to **Zeppelin 0.12.1 with these library versions only**; a later release may offer a supported path.

## The working design: `KnoxJwtRealm`

Zeppelin includes a Shiro realm for Knox. It does not authenticate anyone itself: it redirects unauthenticated browsers to Knox and trusts a token Knox signed. For the cookie to reach Zeppelin, the Knox topology sets `knoxsso.cookie.domain.suffix` to the parent domain.

### 1. Export the Knox public key

```bash
sudo -u knox /opt/knox/bin/knoxcli.sh export-cert --type PEM
# -> /opt/knox/data/security/keystores/gateway-client-trust.pem
cp /opt/knox/data/security/keystores/gateway-client-trust.pem /opt/zeppelin-<version>-bin-all/conf/knox-sso.pem
```

Derby messages saying *"Another instance may have already booted"* are harmless while Knox is running.

> **Important.** This is the self-signed certificate Knox generated for itself (`CN=localhost`, valid until October 2027). If it is regenerated or expires, export and copy the PEM again, or every login is rejected with an invalid-signature error.

### 2. Hadoop environment variables (first crash)

First start with the Knox realm: `java.lang.ClassNotFoundException: org.apache.hadoop.conf.Configuration`. `KnoxJwtRealm` uses Hadoop classes and Zeppelin was not told where Hadoop is. Fix — append to `conf/zeppelin-env.sh` ([snippet](../../config/zeppelin/zeppelin-env.sh.snippet)):

```bash
export HADOOP_HOME=/opt/hadoop
export HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop
```

Check beforehand: `sudo -u zeppelin /opt/hadoop/bin/hadoop classpath | head -c 300`. A second, smaller regression: `commons-collections-3.2.2.jar` had been renamed to `.bak` during cleanup and the realm needs it — restore the original name.

### 3. `shiro.ini`

Template: [`config/zeppelin/shiro.ini.example`](../../config/zeppelin/shiro.ini.example). The `[users]` section is **deliberately empty**: with sample users (`user1/password2`) present, Shiro could also accept password logins against that list and bypass the SSO. `securityManager.realms = $knoxJwtRealm` makes sure only the Knox realm is used. `globalSessionTimeout` (24 h) matches the Knox token lifetime.

> The file was first pasted through a heredoc and arrived garbled by the terminal. Don't retype it — copy a saved intact version with `cp`, then `chown zeppelin:zeppelin` and `chmod 640`. (The script renders it from the template instead.)

### 4. Restart and verify

```bash
systemctl restart zeppelin; sleep 25
systemctl status zeppelin --no-pager | head -6
grep -E "Caused by|ClassNotFound|NoSuchMethod|Error" <zeppelin-dir>/logs/zeppelin-*.log | tail -5
```

The only "Error" lines should be harmless `FluentPropertyBeanIntrospector` info messages about Shiro properties. Opening Zeppelin in a browser then redirects to Knox → Keycloak → back to Zeppelin with the user name shown.

## Logout

Pressing **Logout** in Zeppelin signs the user out of Zeppelin **only**. Verified from Zeppelin's own front-end JavaScript: the button sends `POST /api/login/logout` as an XHR and then runs the *same* follow-up on success or failure — clears the local ticket, opens Zeppelin's internal `/login` page. It **never navigates** to `knoxJwtRealm.logout`.

So `hadoop-jwt` and the Keycloak session are still valid; the next visit goes to Knox, which finds the cookie, and the user is silently signed back in. The Knox-side `/logout` URL ([knox.md](knox.md#workaround-logout-on-the-knox-host)) does end all sessions, but Zeppelin's button does not send users there.

Options discussed, **none chosen yet**:

| | Option | Note |
|---|---|---|
| A | force a password prompt at each Knox login via a pac4j parameter | not verified for Knox 2.1.0 |
| B | central logout link (the Knox `/logout`) next to Zeppelin + user instruction | simple, relies on users |
| C | accept half logout and rely on the 24 h token lifetime | shared workstations stay signed in |
| D | re-check newer Zeppelin releases | an upstream change unifying REST/WebSocket auth under Shiro 2.x was seen in research; effect on logout *not verified* |

## Roles and administrators

`[urls]` protects interpreter, credential and configuration pages with `roles[admin]`. Mapping a Knox/Keycloak user to the Zeppelin `admin` role is **not configured or tested**, so it is unknown who (if anyone) can open those pages. **Also: every AD user in the realm can currently sign in and run interpreters as the `zeppelin` OS user** — restrict by Keycloak group before wider rollout ([security-checklist](../security-checklist.md)).
