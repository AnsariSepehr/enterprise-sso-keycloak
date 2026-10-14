# Prerequisites, servers and masking conventions

## Servers

| Server | Software | Purpose |
|---|---|---|
| SSO server | Rocky Linux 9, 16 GB RAM, nginx, PostgreSQL 13, OpenJDK 17, Keycloak 26.7.4 | identity provider |
| Two domain controllers | Windows Server, AD DS, DNS | users and LDAP |
| Certificate authority | Windows Server, AD CS (enterprise root CA) | internal certificates |
| Jira server | Jira Software 8.19.1 (Tomcat), PostgreSQL 12 on another host | SAML client |
| Worker node | Hadoop 3.3.6, Zeppelin 0.12.1, Knox 2.1.0, nginx, OpenJDK 17 | notebooks + gateway |

## What must exist before you start

1. **DNS records** for `sso`, `knox` (and `zeppelin`) pointing at the right servers, created on the DNS server. An `/etc/hosts` entry only helps one machine.
2. **A public wildcard certificate** (cert + key as PEM) for `*.example.corp`, from a commercial CA. nginx on each server uses it. Place the files where `TLS_CERT` / `TLS_KEY` point.
3. **A read-only AD service account** for Keycloak, password never expires ([ad-federation](keycloak/ad-federation.md#create-the-bind-account)).
4. **Firewall rules:** 80/443 to the SSO and worker servers; LDAP (389, or 636 for LDAPS) from the SSO server to both domain controllers.
5. **Time sync** on all servers (SAML/OIDC assertions are time-limited; keep drift under a minute).
6. **Admin access** to Jira, the domain controllers, the SSO server and the worker node.

## Two certificate systems, two purposes

| | Public wildcard certificate | Internal AD certificate authority |
|---|---|---|
| Issued by | commercial public CA | company's own Windows CA |
| Trusted by | every browser and OS | only domain-joined Windows machines |
| Used for | HTTPS on sso / jira / knox / zeppelin | LDAPS on the domain controllers |
| Related to the other? | no | no |

They only meet because Keycloak must trust the domain controllers' LDAPS certificate (internal CA) — see [known limitations](known-limitations.md#ldaps).

## Masking conventions

Everything below is a placeholder. **Never commit real values.**

| Placeholder | Stands for |
|---|---|
| `example.corp` | company DNS / AD domain |
| `sso.` `jira.` `knox.` `zeppelin.` + `example.corp` | service URLs |
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
