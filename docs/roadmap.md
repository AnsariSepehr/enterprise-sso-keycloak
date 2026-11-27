# Roadmap

Status of services. "Planned" means **not started and not verified**; the notes are starting hypotheses to check against the product's own documentation for the exact version, not instructions.

| Service | Status | Likely route (to verify) |
|---|---|---|
| Keycloak + AD | done (plain LDAP) | LDAPS next |
| Jira | done (SAML) | enable signature validation, test logout |
| Knox | done (OIDC, one logout address per application) | tighten whitelist, exposure check, review the stock topologies |
| Zeppelin | done (Knox JWT, classic UI logout, administrators by name) | group restriction, administrators by group |
| Dundas | planned | check which SSO methods the installed edition supports |
| Grafana | done (OIDC, administrators from a Keycloak group) | Docker secret for the client secret, verify sign-out |
| GitLab | planned | OIDC (OmniAuth `openid_connect`) or SAML; plan user matching |
| Apache Ranger | done (Knox JWT, logout rule, local administrator) | restrict port 6080, group restriction, groups to roles |
| Nextcloud | done (OIDC, accounts stay in LDAP, patched `user_oidc`) | Keycloak mapper instead of the patch, upgrade Nextcloud |
| Exchange 2016 | evaluated, **not integrated** | upgrade first; then AD FS with Keycloak as claims provider (unverified) — [exchange](services/exchange.md) |
| Other Hadoop UIs (YARN, Hive, ...) | planned | Knox topologies / KnoxSSO, same hadoop-jwt |

Cross-cutting items: group-based access control, MFA policy, LDAPS, backup/restore of Keycloak, monitoring of certificate expiry (Knox cert Oct 2027, held by Zeppelin **and** Ranger), testing the [break-glass](break-glass.md) paths, a central logout page (per-application logout addresses exist today).
