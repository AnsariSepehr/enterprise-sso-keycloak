# Prerequisites, servers and masking conventions

## Servers

| Server | Software | Purpose |
|---|---|---|
| SSO server | Rocky Linux 9, 16 GB RAM, nginx, PostgreSQL 13, OpenJDK 17, Keycloak 26.7.4 | identity provider |
| Two domain controllers | Windows Server, AD DS, DNS | users and LDAP |
| Certificate authority | Windows Server, AD CS (enterprise root CA) | internal certificates |
| Jira server | Jira Software 8.19.1 (Tomcat), PostgreSQL 12 on another host | SAML client |
| Worker node | Hadoop 3.3.6, Zeppelin 0.12.1, Knox 2.1.0, nginx, OpenJDK 17 | notebooks + gateway |
| Ranger node | Rocky Linux 9, Apache Ranger Admin 2.6.0, nginx | policy administration (phase 6) |
| Monitoring node | Docker Swarm: Grafana 13.2.0, Prometheus, ELK stack, nginx | dashboards and logs (phase 7) |
| Nextcloud node | Nextcloud 30.0.5 in Docker, nginx | file sharing (phase 8) |
| Mail server | Windows Server, Exchange Server 2016 Enterprise | mail, **not integrated** ([why](services/exchange.md)) |

The [deployment topology](architecture.md#deployment-topology) shows how these hosts are connected.

## What must exist before you start

1. **DNS records** for `sso`, `knox`, `zeppelin`, `ranger`, `dashboards` and `nextcloud` (and `jira`) pointing at the right servers, created on the DNS server. An `/etc/hosts` entry only helps one machine.
2. **A public wildcard certificate** (cert + key as PEM) for `*.example.corp`, from a commercial CA. nginx on each server uses it. Place the files where `TLS_CERT` / `TLS_KEY` point.
3. **A read-only AD service account** for Keycloak, password never expires ([ad-federation](keycloak/ad-federation.md#create-the-bind-account)).
4. **Firewall rules:** 80/443 to the SSO server and every web host; LDAP (389, or 636 for LDAPS) from the SSO server to both domain controllers.
5. **Time sync** on all servers (SAML/OIDC assertions are time-limited; keep drift under a minute).
6. **Admin access** to Jira, the domain controllers, the SSO server, the worker node, and the Ranger, monitoring and Nextcloud hosts.

## Two certificate systems, two purposes

| | Public wildcard certificate | Internal AD certificate authority |
|---|---|---|
| Issued by | commercial public CA | company's own Windows CA |
| Trusted by | every browser and OS | only domain-joined Windows machines |
| Used for | HTTPS on sso / jira / knox / zeppelin / ranger / dashboards / nextcloud | LDAPS on the domain controllers |
| Related to the other? | no | no |

They only meet because Keycloak must trust the domain controllers' LDAPS certificate (internal CA) — see [known limitations](known-limitations.md#ldaps).

## Masking conventions

Everything below is a placeholder. **Never commit real values.**

| Placeholder | Stands for |
|---|---|
| `example.corp` | company DNS / AD domain |
| `sso.` `jira.` `knox.` `zeppelin.` `ranger.` `nextcloud.` `mail.` + `example.corp` | service URLs |
| `dashboards.example.corp` | the Grafana URL |
| `grafana-admins` | the Keycloak group whose members become Grafana administrators |
| `<admin1>`, `<admin2>` | named administrators (real login names in practice) |
| `<KNOX_CERT_BASE64>`, `<ZEPPELIN_HOME>`, `<RANGER_PID>`, `<RANGER_HOST>`, `<stack>` | values to fill in from your own system: the Knox certificate body, install directory, process ID, host name, Swarm stack name |
| `<GUID>`, `3F2A9C10-….` | an Active Directory `objectGUID` |
| `<SSO_IP>` `<DC1_IP>` `<DC2_IP>` `<CA_IP>` `<WORKER_IP>` | internal server addresses |
| `CORP` | Keycloak realm name |
| `DC=example,DC=corp` | LDAP base DN |
| `CN=keycloak,OU=Service Users,DC=example,DC=corp` | read-only bind account |
| `OU=Staff,DC=example,DC=corp` | Users DN |
| `sso_db`, `sso_db_user` | PostgreSQL database and role for Keycloak |
| `<SECRET>`, `<PASSWORD>` | any password, client secret, key |
| `<user>`, `j.doe` | a real person's login name |
| `<version>` | a version in a path |

`scripts/tools/check-secrets.sh` enforces this; see [CONTRIBUTING.md](../CONTRIBUTING.md).
