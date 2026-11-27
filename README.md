# enterprise-sso-keycloak

> **One login for the whole company.** A documented, reproducible blueprint for Keycloak single sign-on federated to Active Directory, connected to Jira (SAML), Apache Knox, Zeppelin and Ranger (OIDC and signed JWT), Grafana and Nextcloud (OIDC) — with masked configs, deployment scripts, UI runbooks, tests, **every bug we hit and how it was fixed**, a **break-glass login for every service**, and an honest list of what is still open (and what was evaluated and deliberately left out).

![status](https://img.shields.io/badge/status-working%20with%20known%20gaps-yellow)
![keycloak](https://img.shields.io/badge/Keycloak-26.7.4-4d4d4d)
![license](https://img.shields.io/badge/license-MIT-blue)
![tests](https://img.shields.io/badge/tests-offline%20suite-brightgreen)

This repository is the write-up of a real build. Everything specific to the original company (domain, hosts, IPs, DNs, users, secrets) has been replaced by placeholders. See [docs/prerequisites.md](docs/prerequisites.md#masking-conventions).

## What was built

```mermaid
flowchart LR
  AD[(Active Directory<br/>2 domain controllers)] -- LDAP, read-only --> KC[Keycloak 26.7.4<br/>realm CORP]
  KC -- SAML 2.0 --> JIRA[Jira 8.19<br/>miniOrange app]
  KC -- OIDC --> KNOX[Apache Knox 2.1.0<br/>KnoxSSO + pac4j]
  KNOX -- "signed JWT cookie hadoop-jwt" --> ZEP[Apache Zeppelin 0.12.1<br/>KnoxJwtRealm]
  KNOX -- "signed JWT cookie hadoop-jwt" --> RNG[Apache Ranger 2.6.0<br/>SSO filter]
  KC -- OIDC --> GRAF[Grafana 13<br/>groups claim = role]
  KC -- OIDC --> NC[Nextcloud 30<br/>user_oidc + LDAP accounts]
  AD -. direct AD login, no SSO .-> EXCH[Exchange 2016<br/>evaluated, not integrated]
  U((Browser)) --> NGINX[nginx + TLS] --> KC
```

![Logical architecture](docs/img/architecture.png)

| Phase | What | Where to read | Automation |
|---|---|---|---|
| 1 | Keycloak on Rocky Linux 9 + PostgreSQL + nginx | [docs/keycloak/deployment.md](docs/keycloak/deployment.md) | [`scripts/keycloak/`](scripts/keycloak) |
| 1b | Keycloak admin and realm | [docs/keycloak/ui-steps.md](docs/keycloak/ui-steps.md) | UI only |
| 2 | Active Directory federation | [docs/keycloak/ad-federation.md](docs/keycloak/ad-federation.md) | UI only (+ PowerShell snippet) |
| 3 | Jira via SAML | [docs/services/jira.md](docs/services/jira.md) | UI only |
| 4 | Knox gateway + Keycloak OIDC | [docs/services/knox.md](docs/services/knox.md) | [`scripts/knox/`](scripts/knox) |
| 5 | Zeppelin via Knox JWT (logout, administrators) | [docs/services/zeppelin.md](docs/services/zeppelin.md) | [`scripts/zeppelin/`](scripts/zeppelin) |
| 6 | Ranger via Knox JWT | [docs/services/ranger.md](docs/services/ranger.md) | [`scripts/ranger/`](scripts/ranger) |
| 7 | Grafana via OIDC, administrators from a Keycloak group | [docs/services/grafana.md](docs/services/grafana.md) | [`scripts/grafana/`](scripts/grafana) |
| 8 | Nextcloud via OIDC on top of LDAP accounts | [docs/services/nextcloud.md](docs/services/nextcloud.md) | [`scripts/nextcloud/`](scripts/nextcloud) |
| — | Exchange 2016: evaluated, **not integrated** | [docs/services/exchange.md](docs/services/exchange.md) | [`scripts/exchange/`](scripts/exchange) (inventory) |

Cross-cutting documents:

- [Architecture](docs/architecture.md) — how the pieces fit and why
- [Break-glass access: how to get in when SSO is down](docs/break-glass.md) — one fallback per service, with procedures
- [Troubleshooting: 35 problems and fixes](docs/troubleshooting.md)
- [Post-install changes, workarounds and deliberate shortcuts](docs/post-install-changes.md) — the "what we changed after install and why" list
- [Known limitations and open work](docs/known-limitations.md)
- [Security checklist before going public or wider](docs/security-checklist.md)
- [Adding a new service](docs/adding-a-service.md) and the [roadmap](docs/roadmap.md) (GitLab, Dundas, further Hadoop UIs, ...)
- [The Word guide](docs/guide/) (the same content in one document, with diagrams)

## Quick start

```bash
git clone https://github.com/<you>/enterprise-sso-keycloak.git && cd enterprise-sso-keycloak
cp config/env/sso.env.example config/env/sso.env     # edit names, paths; no secrets in it
sudo bash scripts/keycloak/deploy-all.sh             # phase 1 (asks for passwords interactively)
# then follow docs/keycloak/ui-steps.md, ad-federation.md, services/*.md in order
bash tests/run-tests.sh                              # offline checks, any time, no servers needed
```

> **Honesty note.** The scripts were reconstructed from the manual steps that were actually performed. They are linted (ShellCheck), template-rendered and, where they edit files (`xml_props.py`, the Nextcloud patch), **unit-tested against fixtures** — but **not run end to end on a clean machine**. Read each script before running it; they are short on purpose. Anything not verified is labelled *unverified* in the docs.

## Repository layout

```
config/        masked, templated config files (*.example, ${VARS} filled in by scripts)
scripts/       numbered, idempotent where possible; lib/ has shared helpers; tools/ has checks
tests/         offline test suite and fixtures (bash tests/run-tests.sh)
docs/          one document per phase/service + cross-cutting docs; img/ has the diagrams
.github/       CI: ShellCheck, tests, template rendering, link check, secret scan
```

## Safety rules for contributors

1. Never commit real values. Run `bash tests/run-tests.sh` (it includes the secret scan) before every commit; put your real domain/hosts in the git-ignored `.forbidden-terms` file so the scan blocks them.
2. Label unverified statements as such.
3. Every bug and every workaround goes into [troubleshooting](docs/troubleshooting.md) / [post-install-changes](docs/post-install-changes.md).

See [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md).

## License

MIT — see [LICENSE](LICENSE).
