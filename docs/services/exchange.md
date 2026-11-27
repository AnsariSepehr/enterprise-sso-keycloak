# Microsoft Exchange — evaluated, not integrated

**Status:** not integrated (decision: keep Active Directory login)   **Version:** Exchange Server 2016 Enterprise, 15.1 build 2507.6, mailbox role   **Protocol:** none
**Automation:** [`scripts/exchange/inventory.ps1`](../../scripts/exchange/inventory.ps1) — read-only inventory

The mail server runs Exchange Server 2016 with OWA published at `MAIL_HOSTNAME`, **forms and basic authentication** enabled. It was evaluated for Keycloak sign-in and deliberately left unchanged. This page records why, so nobody repeats the research.

## Why this service, why this method

**Exchange has no setting for a third-party OIDC or SAML provider.** Microsoft's on-premises *modern authentication* relies on **AD FS** and starts with Exchange Server 2019 CU13; Hybrid Modern Authentication uses Microsoft Entra ID instead. Keycloak is on neither list. **Exchange 2016 does not support modern authentication at all**, so the AD FS route is closed on this server. A request on the Keycloak forum for exactly this — OWA with Keycloak — ended without a ready solution; a paid third-party add-on was the only lead. Exchange Server 2016 also **reached the end of its support in October 2025**.

## Prerequisites (for the inventory)

Run [`inventory.ps1`](../../scripts/exchange/inventory.ps1) in the **Exchange Management Shell**. In a plain Windows PowerShell window the Exchange cmdlets (`Get-ExchangeServer`, `Get-OwaVirtualDirectory`) do not exist and every command fails with *"not recognized"* — which says nothing about the server's version. This misled the first attempt.

## 1. Keycloak side

None. No client was created.

## 2. Service side — the options

| Option | What it gives | Cost and risk |
|---|---|---|
| **A. Keep AD login** *(chosen)* | The same directory account and password that Keycloak validates. One identity, not one sign-in. | No change, no risk. MFA is not central. |
| **B. Upgrade, then AD FS** | Exchange 2019 CU13 or Subscription Edition with AD FS, which could federate to Keycloak over SAML. Real SSO for OWA. | AD FS must be deployed. **Unverified:** OWA behind AD FS with Keycloak as the outside identity provider was not tested. |
| **C. Commercial add-on** | SAML or OIDC sign-in for OWA from a third-party product. | Third-party software on the mail server. Not evaluated. |

## 3. Verify

Not applicable. Users keep signing in to OWA with the directory account Keycloak also uses.

## 4. Logout

Not applicable.

## 5. Access control

Unchanged: Active Directory and Exchange's own role-based access control. Administration continues through the Exchange Management Shell ([break-glass.md](../break-glass.md)).

## 6. Bugs we hit

| # | Symptom | Cause | Fix |
|---|---|---|---|
| 34 | No way to sign in to OWA with Keycloak | Exchange 2016 has no modern authentication and no third-party OIDC/SAML setting | Left on AD login |

Also in [troubleshooting.md](../troubleshooting.md).

## 7. Workarounds and shortcuts

None; nothing was changed on the mail server.

## 8. Open items

- Upgrading Exchange is a **separate project** (the server is out of support) and would reopen Option B.
- If Option B is ever tried, test OWA behind AD FS with Keycloak as claims provider on a **test mailbox**, not production users.
