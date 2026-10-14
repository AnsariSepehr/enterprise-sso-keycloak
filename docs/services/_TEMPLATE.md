# <Service name> — <protocol> integration

> Copy this file to `docs/services/<service>.md`. Fill every section; delete none. Mark anything you did not verify as **unverified**.

**Status:** working / partial / planned   **Version:** x.y.z   **Protocol:** SAML / OIDC / via Knox JWT / ...
**Automation:** `scripts/<service>/` or "UI only"

## Why this service, why this method
(Which protocol the service supports natively, and what alternatives you rejected.)

## Prerequisites
(DNS record, certificate, firewall, accounts, licences.)

## 1. Keycloak side
| Setting | Value |
|---|---|
| Client ID | |
| Client type | |
| Redirect URIs | |
| Logout URLs | |
| Mappers (username, e-mail, groups) | |

## 2. Service side
(Config file or UI path, with masked values. Template goes to `config/<service>/*.example`.)

## 3. Verify
(Exact steps and the expected result.)

## 4. Logout
(Does single logout work? Tested how? Which sessions/cookies exist?)

## 5. Access control
(Who may log in? Group restriction? Admin role mapping?)

## 6. Bugs we hit
| Symptom | Cause | Fix |
|---|---|---|

Also add each row to [../troubleshooting.md](../troubleshooting.md).

## 7. Workarounds and shortcuts
(Everything that deviates from "clean". Also add to [../post-install-changes.md](../post-install-changes.md).)

## 8. Open items
