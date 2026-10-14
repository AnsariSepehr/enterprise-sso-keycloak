# Security checklist

## Before this repository (or the Word guide) goes public

- [ ] Every real host, domain, realm name, IP, DN and user replaced by a placeholder ([prerequisites](prerequisites.md#masking-conventions))
- [ ] `scripts/tools/check-secrets.sh` clean, with **your real values in `.forbidden-terms`**
- [ ] Secret scan of the **full git history** (e.g. `gitleaks detect`) before the first push — a secret removed later is still in history
- [ ] Never commit topology files, `keycloak.conf`/`keycloak.env`, `shiro.ini` or `*.pem`/`*.key` with real content (`.gitignore` blocks the obvious ones)
- [ ] Screenshots checked for visible names, hosts, tokens, browser tabs
- [ ] **Rotate every secret that was ever pasted** into chats, tickets or logs during the build: Keycloak `knox` client secret, PostgreSQL role password, Keycloak bootstrap admin password, LDAP bind-account password, Knox master secret

## Before wider rollout

- [ ] Restrict who can sign in to Zeppelin (Keycloak group/role requirement); all AD users can currently run code as the `zeppelin` OS user
- [ ] LDAPS instead of LDAP (fix DC certificates)
- [ ] Turn on SAML client signature validation for Jira
- [ ] Bind Knox :8443 to localhost or firewall it
- [ ] Tighten the Knox redirect whitelist to exact hosts
- [ ] Keep one break-glass admin in Jira and in Keycloak; store credentials offline
- [ ] Enable Keycloak login-failure events and brute-force detection; review session lifetimes
- [ ] Plan Jira upgrade (8.19 is end of life); patch Keycloak/Knox regularly
- [ ] Back up the Keycloak database and realm export; test a restore
- [ ] Re-check the Windows Firewall on DC/CA is back **on** after diagnostics
