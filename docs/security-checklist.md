# Security checklist

## Before this repository (or the Word guide) goes public

- [ ] Every real host, domain, realm name, IP, DN and user replaced by a placeholder ([prerequisites](prerequisites.md#masking-conventions))
- [ ] `bash tests/run-tests.sh` green (it includes `scripts/tools/check-secrets.sh`), with **your real values in `.forbidden-terms`**
- [ ] Secret scan of the **full git history** (e.g. `gitleaks detect`) before the first push — a secret removed later is still in history
- [ ] Never commit topology files, `keycloak.conf`/`keycloak.env`, `shiro.ini` or `*.pem`/`*.key` with real content (`.gitignore` blocks the obvious ones)
- [ ] Screenshots checked for visible names, hosts, tokens, browser tabs
- [ ] **Rotate every secret that was ever pasted** into chats, tickets or logs during the build: Keycloak `knox`, `grafana` and `nextcloud` client secrets, PostgreSQL role password, Keycloak bootstrap admin password, LDAP bind-account password, Knox master secret, **the Grafana built-in admin password** (it was kept in a stack file in plain text)

## Before wider rollout

- [ ] Restrict who can sign in (Keycloak group/role requirement per client); **every enabled directory user** can currently sign in everywhere and run code in Zeppelin as the `zeppelin` OS user — the search base was [widened](keycloak/ad-federation.md#widening-the-search-base-users-outside-the-staff-ou)
- [ ] LDAPS instead of LDAP (fix DC certificates)
- [ ] Turn on SAML client signature validation for Jira
- [ ] Bind Knox :8443 to localhost or firewall it
- [ ] Tighten the Knox redirect whitelist to exact hosts
- [ ] Keep **one break-glass login per service** ([break-glass](break-glass.md)); store the credentials offline and **test every path** after each upgrade (`scripts/tools/check-breakglass.sh`, then sign in by hand)
- [ ] Enable Keycloak login-failure events and brute-force detection; review session lifetimes
- [ ] Plan Jira upgrade (8.19 is end of life); patch Keycloak/Knox regularly
- [ ] Back up the Keycloak database and realm export; test a restore
- [ ] Re-check the Windows Firewall on DC/CA is back **on** after diagnostics
- [ ] Pass client secrets to Swarm services as **Docker secrets** (`__FILE` variables), not environment variables: `docker service inspect` shows environment values to anyone with Docker access
- [ ] Restrict **Ranger port 6080** to the plugin and usersync hosts and start a host firewall on the Ranger node
- [ ] Review the **stock Knox topologies** (`sandbox`, `admin`, `manager`) and remove or secure any that still use the demo user list — they ship with sample accounts and were not inspected during this work
- [ ] Narrow **Nextcloud's LDAP user and login filters** (they admit system mailboxes and accept more than sixty login attributes)
- [ ] Plan upgrades for **Nextcloud 30** and **Exchange 2016** (out of support); re-test the `user_oidc` patch after every app update
- [ ] Check that **Prometheus and Elasticsearch** have a login of their own, or put one in front of them (both were published through nginx with no authentication step at the proxy)
- [ ] Refresh the **Knox certificate copy in Zeppelin and Ranger** before October 2027
