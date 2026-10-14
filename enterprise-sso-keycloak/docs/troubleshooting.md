# Troubleshooting: every problem we hit, and how it was fixed

Listed roughly in the order they happened. Each row says where the full story is. Some were caused by guessing a path or a setting instead of checking it first; the lesson (inspect the real file or log before changing anything) is as useful as the fix.

| # | Area | Symptom | Cause | Fix | Details |
|---|---|---|---|---|---|
| 1 | Keycloak | Download returned HTTP 404 | A guessed `latest` URL does not exist | Use the exact release tag (26.7.4) | [keycloak/deployment](keycloak/deployment.md) |
| 2 | Keycloak | Port 8080 already in use | A leftover FreeIPA `pki-tomcat` service held the port | Uninstall the FreeIPA server (`ipa-server-install --uninstall -U`), stop and disable `pki-tomcatd@pki-tomcat` | [keycloak/deployment](keycloak/deployment.md) |
| 3 | PostgreSQL | Password authentication failed, also from `psql` | `password_encryption` was `md5` while `pg_hba.conf` required `scram-sha-256` | Set `scram-sha-256`, reload, set the database user password again | [keycloak/deployment](keycloak/deployment.md#3-database-postgresql-instead-of-h2) |
| 4 | nginx | 502 with `connect() failed (13: Permission denied)` | SELinux blocks nginx from connecting to the local service | `setsebool -P httpd_can_network_connect 1` | [keycloak/deployment](keycloak/deployment.md#5-publish-through-nginx) |
| 5 | Keycloak SAML client | Validation error on the post-logout URI field; "not a valid URL" on endpoints | Post-logout field was the wrong place for the logout URL; for the endpoint URLs the cause was not identified | Clear the post-logout field; retype the URLs by hand. (My first diagnosis of the post-logout field was wrong.) | [services/jira](services/jira.md) |
| 6 | Jira SAML | "Could not import certificate" network error | Cause not confirmed; it succeeded after nginx request limits were raised | Raise limits and retry; key import was later reverted | [services/jira](services/jira.md) |
| 7 | Jira SAML | `invalid_signature` on login | Signature check failed and the imported key reverted (cause not established) | Set Client signature required to Off (see known-limitations.md) | [services/jira](services/jira.md) |
| 8 | Jira SAML | Test Configuration shows "Invalid requester" | Not diagnosed | Not used; the real login through the corporate login button works | [services/jira](services/jira.md) |
| 9 | Jira | `cant_signin_check_configuration` | Allow User Creation pointed at a read-only directory | Switch the target to the Jira Internal Directory | [services/jira](services/jira.md) |
| 10 | Jira | Duplicate account after SSO login | NameID differed in case or format from the existing user name | Username mapper in Keycloak plus the User Profile Username attribute | [services/jira](services/jira.md) |
| 11 | Zeppelin | Chain of `ClassNotFoundException`, then a `Clients` type error | pac4j and buji jars incompatible; filter classes absent from the Jakarta builds | Direct OIDC abandoned; jars moved out of `lib` (see zeppelin.md) | [services/zeppelin](services/zeppelin.md) |
| 12 | Knox | HTTP 500 after a successful Keycloak login: `NoSuchMethodError JWTClaimsSet.toJSONObject()` | The bundled `oauth2-oidc-sdk` 8.22 is too old for the pac4j library | Replace it with version 9.13 and verify the checksum | [services/knox](services/knox.md) |
| 13 | Knox | Redirect refused by the whitelist | The return URL did not match the allowed pattern | Set `knoxsso.redirect.whitelist.regex` for the domain | [services/knox](services/knox.md) |
| 14 | Knox | 404 on `/gateway/homepage/` | The landing page lives one level deeper | Use `/gateway/homepage/home/` | [services/knox](services/knox.md) |
| 15 | Knox | `webssout` returns `{"loggedOut":true}`; Firefox shows an XML parse error | The response is JSON, the browser expects XML | Cosmetic; ignore | [services/knox](services/knox.md) |
| 16 | Knox | 404 for the logout URL | A separate `knoxssout.xml` topology was created, which is the wrong design | Removed it; `KNOXSSOUT` is a service inside the existing topology | [services/knox](services/knox.md) |
| 17 | Knox | Logout loop: user is logged straight back in | Both `hadoop-jwt` and `pac4j.session.pac4jUserProfiles` cookies, plus the Keycloak session, keep the user signed in | nginx `/logout` location that expires the cookies and redirects to Keycloak logout (see knox.md, Logout) | [services/knox](services/knox.md) |
| 18 | Keycloak | Logout page asks "Do you want to log out?" | No `id_token_hint` is sent | Accepted as cosmetic | [keycloak/deployment](keycloak/deployment.md) |
| 19 | Zeppelin | Crash with `ClassNotFoundException: org.apache.hadoop.conf.Configuration` | `KnoxJwtRealm` needs Hadoop classes; Hadoop location unknown to Zeppelin | `HADOOP_HOME` and `HADOOP_CONF_DIR` in `zeppelin-env.sh` (see zeppelin.md) | [services/zeppelin](services/zeppelin.md) |
| 20 | Zeppelin | Regression after cleanup: realm fails to load | `commons-collections-3.2.2.jar` had been renamed to `.bak` | Restore the original file name | [services/zeppelin](services/zeppelin.md) |
| 21 | Zeppelin | `shiro.ini` garbled after pasting a heredoc | The terminal mangled the pasted text | Copy the saved intact file with `cp` instead | [services/zeppelin](services/zeppelin.md) |
| 22 | Zeppelin | Logout button does not end the SSO session | The button never calls the Knox logout URL | Open; options in zeppelin.md, Logout | [services/zeppelin](services/zeppelin.md) |
| 23 | Active Directory | Domain controller certificates expired; LDAPS unusable | Certificates not renewed; the automatic enrolment fails with an RPC/DCOM error | Plain LDAP used for now; root cause of the enrolment failure not found (see ad-federation.md) | [keycloak/ad-federation](keycloak/ad-federation.md) |

## Mistakes worth stating plainly

Early on, paths and topology names were proposed before looking at the real files; the post-logout URI field was named as the cause of a validation error when it was not; and one cookie-deletion test removed the cookies in the wrong order and proved nothing. Each was corrected once the real file or log was inspected. **Lesson: read the real config/log first; change one thing at a time.**

## Generic diagnosis recipes

| Situation | Look at |
|---|---|
| Keycloak will not start | `journalctl -u keycloak -n 80 --no-pager`; `ss -tulpn \| grep 8080` |
| nginx 502 | `tail /var/log/nginx/error.log`; `getsebool httpd_can_network_connect`; `ausearch -m avc -ts recent` |
| Knox 500 after login | `/opt/knox/logs/gateway.log` for `Caused by` |
| Zeppelin fails to start | `<zeppelin-dir>/logs/zeppelin-*.log` for `ClassNotFound`/`NoSuchMethod` |
| SAML errors | Keycloak *Events* (enable login error events) and the app's audit log |
| "Logged out but logged straight back in" | check all three sessions: Keycloak, `pac4j.session.*`, `hadoop-jwt` |

