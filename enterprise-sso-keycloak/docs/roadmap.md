# Roadmap

Status of services. "Planned" means **not started and not verified**; the notes are starting hypotheses to check against the product's own documentation for the exact version, not instructions.

| Service | Status | Likely route (to verify) |
|---|---|---|
| Keycloak + AD | done (plain LDAP) | LDAPS next |
| Jira | done (SAML) | enable signature validation, test logout |
| Knox | done (OIDC) | tighten whitelist, exposure check |
| Zeppelin | done (Knox JWT) | choose logout option, group restriction, roles |
| Dundas | planned | check which SSO methods the installed edition supports |
| Grafana | planned | generic OAuth/OIDC client against Keycloak; map groups to roles |
| GitLab | planned | OIDC (OmniAuth `openid_connect`) or SAML; plan user matching |
| Apache Ranger | planned | Ranger supports Knox SSO; try the same Knox JWT approach; check version docs |
| Nextcloud | planned | an OIDC login app against Keycloak; decide user-matching |
| Other Hadoop UIs (YARN, Hive, ...) | planned | Knox topologies / KnoxSSO, same hadoop-jwt |

Cross-cutting items: group-based access control, MFA policy, LDAPS, backup/restore of Keycloak, monitoring of certificate expiry (Knox cert Oct 2027), a central logout page.
