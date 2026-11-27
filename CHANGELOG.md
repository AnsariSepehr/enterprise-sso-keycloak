# Changelog

## 0.2.0 — Ranger, Grafana, Nextcloud, Exchange evaluation, break-glass, tests
**New services**
- Apache Ranger 2.6.0 through the Knox JWT cookie: SSO, logout, administrators, local administrator — `docs/services/ranger.md`, `scripts/ranger/` (preflight, SSO, nginx, verify)
- Grafana 13.2.0 through OpenID Connect, administrators from a Keycloak group (Docker Swarm) — `docs/services/grafana.md`, `scripts/grafana/`, `config/grafana/`
- Nextcloud 30.0.5 through OpenID Connect on top of LDAP accounts, with the one-line `user_oidc` patch (idempotent, tested) — `docs/services/nextcloud.md`, `scripts/nextcloud/`
- Microsoft Exchange 2016 evaluated and deliberately **not integrated**, with the reasons and the options — `docs/services/exchange.md`, `scripts/exchange/inventory.ps1`

**New cross-cutting documents and diagrams**
- `docs/break-glass.md`: one fallback login per service, procedures, rules; `scripts/tools/check-breakglass.sh`
- Seven diagrams in `docs/img/` (architecture, deployment topology, login sequence, logout chain, Grafana role mapping, Nextcloud identity matching, break-glass map)
- Troubleshooting log extended from 23 to **35** problems; post-install changes, known limitations, security checklist, roadmap and the "adding a service" recipe updated with what these services taught
- Keycloak: widening the LDAP search base (`docs/keycloak/ad-federation.md`), client overview table
- The Word guide in `docs/guide/` now covers all of the above, with diagrams

**Changed**
- Knox nginx template: one logout location per application (`/logout`, `/logout/ranger`, `/logout/knox`); `scripts/tools/gen-app-logout.sh` prints the block for a new one
- Zeppelin: classic UI as the default front end (its Logout button reaches Knox) and administrators by user name — `scripts/zeppelin/02-classic-ui-and-admins.sh`, updated `shiro.ini.example`
- Documented the Keycloak LDAP periodic synchronisation that was switched on

**Quality**
- `tests/run-tests.sh`: 23 offline tests (ShellCheck, template rendering with XML and YAML validation, XML property editor and Nextcloud patch against fixtures, logout generator, link checker, secret scan)
- `scripts/tools/check-links.py` verifies every relative link and anchor in the Markdown files
- `scripts/lib/xml_props.py`: safe, idempotent, tested editor for Hadoop-style XML configuration
- CI runs the whole suite; the render test also checks that `${VAR}` placeholders left for another tool are on purpose

**Fixed**
- Four ShellCheck warnings that made CI fail (`SC2034`, `SC1090`, `SC2164`, `SC2044`)

## 0.1.0 — initial release
- Keycloak 26.7.4 deployment (PostgreSQL, nginx, systemd) with scripts
- Active Directory federation (read-only LDAP)
- Jira (SAML / miniOrange), Knox 2.1.0 (OIDC), Zeppelin 0.12.1 (Knox JWT) documentation, configs and scripts
- Troubleshooting log (23 problems), post-install changes, known limitations, security checklist
- Extension guide and roadmap (Grafana, GitLab, Ranger, Nextcloud, Dundas)
