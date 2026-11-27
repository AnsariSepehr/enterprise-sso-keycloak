# Known limitations, unverified points and open work

Sign-in works on Jira, Zeppelin, Ranger, Grafana and Nextcloud. This page lists what is not finished and what is stated without being fully proved.

## Not working or not finished

### LDAPS
Keycloak talks to AD over plain LDAP. Renewing DC certificates failed with an RPC enrolment error; root cause not found. → [ad-federation](keycloak/ad-federation.md)

### SAML client signature
The Jira client has *Client signature required = Off*. → [jira](services/jira.md#3-request-signing-and-the-expired-certificate)

### Single logout
- **Zeppelin:** in the new interface the button still ends only the local session; the classic interface is used instead and sends users to the Knox logout address. → [zeppelin](services/zeppelin.md#resolution-the-classic-front-end)
- **Knox:** the home-page button is local only; users are sent to the per-application addresses. → [knox](services/knox.md#one-logout-address-per-application)
- **Ranger:** works through an nginx rule on one URL; re-check after a Ranger upgrade. → [ranger](services/ranger.md#4-logout)
- **Grafana:** sign-out address configured, end-to-end sign-out **not recorded**. → [grafana](services/grafana.md#4-logout)
- **Jira:** never tested end to end.

### Other open items
- Jira directory "Synchronisation failed" (not investigated).
- **Zeppelin administrators** are granted by user name in five rules, not by group. → [zeppelin](services/zeppelin.md#roles-and-administrators)
- **Who may log in** is not restricted: every enabled directory user can sign in everywhere, and the Keycloak search base was widened — see [security checklist](security-checklist.md).
- **Ranger port 6080** is reachable from every host (plugins need it) and a browser can bypass nginx. → [ranger](services/ranger.md#8-open-items)
- **Nextcloud** runs a patched `user_oidc` that an app update removes, and Nextcloud 30.0.5 is old. → [nextcloud](services/nextcloud.md#8-open-items)
- **Exchange 2016** is out of support and cannot use modern authentication. → [exchange](services/exchange.md)
- **Break-glass paths** for Knox, Zeppelin and Keycloak recovery are described but not tested. → [break-glass](break-glass.md)
- Knox listening address / port 8443 exposure not verified.
- Jira 8.19 is end of life.
- Dundas and the remaining [roadmap](roadmap.md) services not started.

## Stated but not fully verified
- Knox logout design (KIP-10) and a Knox issue note that logout is unsupported for some IdPs were read in research, not re-tested here.
- Whether other Zeppelin versions behave like 0.12.1 (direct OIDC, logout). Only 0.12.1 was tested.
- The pac4j parameter that would force a password prompt (option A) is not confirmed for Knox 2.1.0.
- The nginx limit increase that appeared to fix the Jira certificate import is a guess at the cause.
- The Grafana fallback parameter `disableAutoLogin`, Nextcloud's `login?direct=1` and `allow_multiple_user_backends`, and Keycloak's support for several DNs in *Users DN* come from product behaviour and notes and were not all tested.
- The REST route used to promote Ranger users is described from the product's behaviour. Read each role back to confirm it.
- The Keycloak command to recreate a lost administrator, the Grafana and Nextcloud password resets and the Zeppelin fallback `shiro.ini` procedure in [break-glass](break-glass.md) were not run.
- Whether OWA could sit behind AD FS with Keycloak as the outside identity provider ([exchange](services/exchange.md), option B) was not tested.
- The Docker-secret variant of the Grafana stack (`GRAFANA_SECRET_MODE=docker-secret`) is recommended but was not used in the original build.
- Knox's own certificate is self-signed and expires in October 2027; the Zeppelin **and Ranger** copies must be refreshed at that point.
- The scripts in this repository were not run end to end on a clean machine. The file-editing tools (`xml_props.py`, the Nextcloud patch) and the templates **are** tested against fixtures (`bash tests/run-tests.sh`).
