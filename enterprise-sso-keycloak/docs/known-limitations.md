# Known limitations, unverified points and open work

Sign-in works on all three applications. This page lists what is not finished and what is stated without being fully proved.

## Not working or not finished

### LDAPS
Keycloak talks to AD over plain LDAP. Renewing DC certificates failed with an RPC enrolment error; root cause not found. → [ad-federation](keycloak/ad-federation.md)

### SAML client signature
The Jira client has *Client signature required = Off*. → [jira](services/jira.md#3-request-signing-and-the-expired-certificate)

### Single logout
- **Zeppelin:** the button ends only the local session; options A–D not chosen. → [zeppelin](services/zeppelin.md#logout)
- **Knox:** home-page button local only; use the nginx `/logout` workaround. → [knox](services/knox.md#logout)
- **Jira:** never tested end to end.

### Other open items
- Jira directory "Synchronisation failed" (not investigated).
- Zeppelin admin role mapping not configured.
- **Who may log in** is not restricted (all 149 synchronised AD users) — see [security checklist](security-checklist.md).
- Knox listening address / port 8443 exposure not verified.
- Jira 8.19 is end of life.
- Dundas and all [roadmap](roadmap.md) services not started.

## Stated but not fully verified
- Knox logout design (KIP-10) and a Knox issue note that logout is unsupported for some IdPs were read in research, not re-tested here.
- Whether other Zeppelin versions behave like 0.12.1 (direct OIDC, logout). Only 0.12.1 was tested.
- The pac4j parameter that would force a password prompt (option A) is not confirmed for Knox 2.1.0.
- The nginx limit increase that appeared to fix the Jira certificate import is a guess at the cause.
- The scripts in this repository were not run end to end on a clean machine.
