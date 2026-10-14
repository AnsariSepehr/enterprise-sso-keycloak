# Jira — SAML 2.0 through the miniOrange app

Jira Software 8.19.1 (self-hosted, no clustering) signs users in via SAML with Keycloak as identity provider. Password login stayed available throughout, so the change could be tested without locking anyone out. **UI only; no scripts.**

## Choosing the app

| Option | Outcome |
|---|---|
| Kantega SSO | not available for this Jira: its current releases require Jira Data Center 11 or newer (according to the research done at the time) |
| **miniOrange SAML SSO for Jira** | supports Server and Data Center, lists Keycloak as a provider, includes SAML single logout — **chosen** |

The Jira server also could not reach the Atlassian Marketplace, so the app was installed and licensed manually. Jira 8.19 is long past vendor support; plan an upgrade separately.

## 1. Service-provider values (app → SP Information tab)

| Item | Value |
|---|---|
| SP Entity ID | `https://jira.example.corp` |
| ACS URL | `https://jira.example.corp/plugins/servlet/saml/auth` |
| Single Logout URL | `https://jira.example.corp/plugins/servlet/saml/logout` |
| Metadata URL | `https://jira.example.corp/plugins/servlet/saml/metadata` |

## 2. Create the SAML client in Keycloak

Realm `CORP` → **Clients → Create client**, type **SAML**.

| Setting | Value |
|---|---|
| Client ID | `https://jira.example.corp` (identical to the SP Entity ID) |
| Root URL / Home URL | `https://jira.example.corp` |
| Valid redirect URIs | the ACS URL |
| Valid post logout redirect URIs | **left empty** |
| Name ID format | `email` at first; changed later (see [user matching](#5-testing-and-the-user-matching-problem)) |
| Force POST binding | On |
| Sign documents | On, `RSA_SHA256` |
| Front channel logout | On |
| Advanced → Assertion Consumer Service POST Binding URL | the ACS URL |
| Advanced → Logout Service POST and Redirect Binding URLs | the Single Logout URL |

**Two validation errors:** typing the logout URL into *Valid post logout redirect URIs* was rejected ("not a valid URI") — that field is not where a SAML client's logout endpoint belongs; clearing it let the client save. The three endpoint fields on the Advanced tab were first rejected with "is not a valid URL"; **retyping by hand instead of pasting** cleared it. (My first diagnosis blamed the wrong field; the point is: check the actual field.)

## 3. Request signing and the expired certificate

miniOrange signs its requests and Keycloak can require that signature, which needs miniOrange's public certificate in the client's **Keys** tab.

1. The certificate in miniOrange's metadata had **expired in July 2025** (it had been generated for two years at install).
2. A new certificate was generated on the app's Certificates page (valid ten years), saved as PEM, imported via *Keys → Import key* (archive format *Certificate PEM*).
3. The first import failed with *NetworkError when attempting to fetch resource*; it succeeded later after nginx upload/timeout limits on the SSO server were raised. **Exact cause unconfirmed.**
4. Keycloak then logged `invalid_signature` login errors, and the imported key reverted to the old one after a page refresh.

**Current state: *Client signature required* = Off.** This is a known security gap: [known-limitations](../known-limitations.md#saml-client-signature).

## 4. Add Keycloak as IdP in the app

App → **Configured IDPs → Manual Setup → Import From Metadata**.

- The metadata URL must be `https://sso.example.corp/realms/CORP/protocol/saml/descriptor`. The first attempt used the bare realm URL (`.../realms/CORP`), which is only the issuer name and failed with *Could not parse metadata*.
- The import defaults the binding to HTTP-Redirect; **switch both SSO and SLO to POST** to match *Force POST binding*.

| Field | Value |
|---|---|
| IDP Entity ID | `https://sso.example.corp/realms/CORP` |
| Send Signed Requests | On |
| SSO / SLO binding | HTTP-POST |
| Single Sign On URL and Single Logout URL | `https://sso.example.corp/realms/CORP/protocol/saml` |
| NameID format | `emailAddress` |
| Signing certificate | filled by the import |

## 5. Testing and the user-matching problem

1. The app's **Test Configuration** button gave Keycloak's *Invalid requester* page. A real login from Jira's login page (**Use Corporate Login**) did reach Keycloak and authenticate, so the button was not used further.
2. After a successful Keycloak login Jira showed *We couldn't sign you in*, code `cant_signin_check_configuration`; the app audit log said *An unknown error occurred*.
3. **Cause one:** *Allow User Creation* was on and the target directory was the read-only AD directory — the app could not create users there. Pointing it at **Jira Internal Directory** removed the error.
4. **Cause two:** the login created a brand-new empty account instead of the person's real one. The real account lives in the read-only AD directory as `J.Doe`, while Keycloak sent the NameID in lower-case e-mail form (`j.doe@example.corp`). Matching by e-mail failed on case and format.
5. **Fix:**
   - Keycloak client → *Client scopes → dedicated scope* → add a mapper of type **User Property**: property `username`, SAML attribute name `username`.
   - App → **User Profile** tab: set *Username* to the `username` attribute instead of NameID.
   - Turn *Allow User Creation* **off** while testing so failed matches stop creating accounts.
   - Delete the accidental duplicate accounts from Jira Internal Directory.
6. After that the integration was reported complete.

## Things to follow up

- Jira has three user directories; the read/write AD directory shows **"Synchronisation failed"** — not investigated.
- **End-to-end logout from Jira was never recorded as tested.** Test it before relying on it.
- Keep a **working local administrator** in Jira (break-glass) in case the IdP is unreachable.
