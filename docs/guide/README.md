# The Word guide

[`Enterprise_SSO_with_Keycloak_Active_Directory_Jira_Knox_Zeppelin_Ranger_Grafana_and_Nextcloud.docx`](Enterprise_SSO_with_Keycloak_Active_Directory_Jira_Knox_Zeppelin_Ranger_Grafana_and_Nextcloud.docx) is the whole build in **one document**: architecture, every service, the 35 problems and their fixes, the break-glass access plan, the security checklist, seven diagrams and a command reference. It is written for reading top to bottom and for sharing with people who will not open a repository.

**The Markdown documents in `docs/` are the source of truth.** The Word guide was written from the same material; when the two differ, trust `docs/` and the scripts, and update the guide afterwards. All host names, addresses and credentials in it are placeholders (`example.corp`, `<PASSWORD>` ...), exactly as in the repository.

| Part | Where in the repository |
|---|---|
| Architecture and diagrams | [`docs/architecture.md`](../architecture.md), [`docs/img/`](../img/) |
| Keycloak and Active Directory | [`docs/keycloak/`](../keycloak/) |
| Jira, Knox, Zeppelin, Ranger, Grafana, Nextcloud, Exchange | [`docs/services/`](../services/) |
| Break-glass access | [`docs/break-glass.md`](../break-glass.md) |
| Problems and fixes | [`docs/troubleshooting.md`](../troubleshooting.md) |
| Security checklist and limitations | [`docs/security-checklist.md`](../security-checklist.md), [`docs/known-limitations.md`](../known-limitations.md) |
