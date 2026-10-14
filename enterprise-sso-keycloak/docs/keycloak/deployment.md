# Phase 1 — Deploying Keycloak (Rocky Linux 9)

**Why Keycloak:** open source, federates directly to Active Directory over LDAP, speaks SAML 2.0 *and* OpenID Connect, supports single logout, can be themed. It runs on one server here, as a systemd service listening on localhost only, behind nginx which terminates HTTPS.

**Automation:** [`scripts/keycloak/deploy-all.sh`](../../scripts/keycloak/deploy-all.sh) runs steps 1–5 below. Each script maps to one section. The UI part (step 6) is in [ui-steps.md](ui-steps.md).

| Step | Script | Manual section |
|---|---|---|
| 1 | `01-prepare-server.sh` | [Prepare the server](#1-prepare-the-server) |
| 2 | `02-install-keycloak.sh` | [Install](#2-install-keycloak) |
| 3 | `03-setup-postgres.sh` | [Database](#3-database-postgresql-instead-of-h2) |
| 4 | `04-install-service.sh` | [Service](#4-run-keycloak-as-a-service) |
| 5 | `05-setup-nginx.sh` | [nginx](#5-publish-through-nginx) |
| 6 | — | [UI steps](ui-steps.md) |

## 1. Prepare the server

```bash
sudo hostnamectl set-hostname sso.example.corp
sudo dnf update -y
sudo dnf install -y java-17-openjdk java-17-openjdk-devel wget unzip firewalld nginx
sudo systemctl enable --now firewalld
sudo useradd -m -s /sbin/nologin keycloak
```

Check that `sso.example.corp` resolves to `<SSO_IP>` before going on.

### Bug: "Port already bound: 8080" — leftover FreeIPA

The first start failed because an old FreeIPA installation was still on the machine; its certificate service (Tomcat, `pki-tomcat`) held port 8080, and a second Tomcat, a separate PostgreSQL and FreeIPA's DNS/Kerberos/LDAP were present too. Keycloak cannot share the machine with them.

```bash
ss -tulpn | grep 8080                      # find the owner
sudo ipa-server-install --uninstall -U     # destructive: only if you really do not need FreeIPA
sudo systemctl stop pki-tomcatd@pki-tomcat.service
sudo systemctl disable pki-tomcatd@pki-tomcat.service
ss -tulpn | grep -E '8080|389|636|88|53'   # must show nothing from FreeIPA
```

The uninstall reported one failure (the ACME component timed out) but completed the rest; the leftover Tomcat had to be stopped by hand. **The script only reports this situation; it never removes anything on its own.**

## 2. Install Keycloak

```bash
cd /opt
sudo wget https://github.com/keycloak/keycloak/releases/download/26.7.4/keycloak-26.7.4.tar.gz -O keycloak.tar.gz
sudo tar -xzf keycloak.tar.gz && sudo mv keycloak-26.7.4 keycloak
sudo chown -R keycloak:keycloak /opt/keycloak
```

### Bug: HTTP 404 on download
A guessed `releases/latest/download/` URL with a made-up version returns 404. Use the exact release tag in both the path and the file name.

## 3. Database: PostgreSQL instead of H2

Keycloak's default embedded database is not for production. Config: [`config/keycloak/keycloak.conf.example`](../../config/keycloak/keycloak.conf.example).

> **Difference from the original build.** Originally the DB password sat in `keycloak.conf`. The script now keeps it out of the file and passes it as `KC_DB_PASSWORD` from `/etc/keycloak/keycloak.env` (mode 640). See [post-install-changes](../post-install-changes.md#hardening-the-scripts-add-over-the-manual-build).

Switching the database vendor is a *build-time* option, so run the build once after editing:

```bash
sudo -u keycloak /opt/keycloak/bin/kc.sh build
```

### Bug: "password authentication failed for user" although the password is right
Even `psql -h 127.0.0.1 ...` failed, which proved the fault was in PostgreSQL, not Keycloak. `pg_hba.conf` required `scram-sha-256` for the role, but `password_encryption` was still `md5`, so every `ALTER USER ... PASSWORD` stored an MD5 hash the SCRAM handshake cannot use.

```bash
sudo -u postgres psql -c "SHOW password_encryption;"                                  # md5
sudo -u postgres psql -c "ALTER SYSTEM SET password_encryption = 'scram-sha-256';"
sudo -u postgres psql -c "SELECT pg_reload_conf();"
sudo -u postgres psql -c "ALTER USER sso_db_user WITH PASSWORD '<PASSWORD>';"       # must be re-set
PGPASSWORD='<PASSWORD>' psql -h 127.0.0.1 -U sso_db_user -d sso_db -c "SELECT 1;"
```

Existing hashes are **not** converted; the password must be set again. The script sets the encryption first and the password afterwards, so the problem cannot recur.

## 4. Run Keycloak as a service

Unit file: [`config/keycloak/keycloak.service.example`](../../config/keycloak/keycloak.service.example).

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now keycloak
sudo journalctl -u keycloak -n 40 --no-pager     # look for: "Listening on: http://127.0.0.1:8080"
```

The `KC_BOOTSTRAP_ADMIN_*` variables only create the **first, temporary** admin. Remove them once a permanent admin exists ([ui-steps](ui-steps.md#1-permanent-administrator)).

## 5. Publish through nginx

Config: [`config/nginx/sso.conf.example`](../../config/nginx/sso.conf.example). Large proxy buffers matter: SAML and OIDC responses carry big headers.

```bash
sudo nginx -t && sudo systemctl enable --now nginx
sudo firewall-cmd --permanent --add-service=http --add-service=https && sudo firewall-cmd --reload
```

### Bug: 502 Bad Gateway, `connect() ... failed (13: Permission denied)`
SELinux is enforcing on Rocky Linux and blocks web servers from making outbound connections. Permanent fix:

```bash
sudo setsebool -P httpd_can_network_connect 1
sudo systemctl reload nginx
```

## 6. Verify

```bash
curl -I http://127.0.0.1:8080                                                          # 302 to admin console
curl -s https://sso.example.corp/realms/CORP/.well-known/openid-configuration | head -c 200   # JSON, after the realm exists
bash scripts/tools/verify-sso.sh
```

Opening the bare domain redirects to the **master** realm admin console; that is expected. Each realm has its own addresses, e.g. `https://sso.example.corp/realms/CORP/account` for users.
