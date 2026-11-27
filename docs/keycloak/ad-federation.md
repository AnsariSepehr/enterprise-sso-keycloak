# Phase 2 — Active Directory federation

Keycloak reads users from AD over LDAP and checks passwords by **binding to the directory as the user**, so no password is copied. It works, but over **plain LDAP**, because the domain controllers' LDAPS certificates are expired and could not be renewed (see below and [known limitations](../known-limitations.md#ldaps)).

## Design decisions

| Decision | Choice | Reason |
|---|---|---|
| Password check | LDAP bind to AD | passwords stay in AD, nothing synchronised |
| Direction | read-only | Keycloak must never write to the directory |
| Failover | both DCs listed | one DC rebooting must not stop logins |
| Login name | `sAMAccountName` | the short name users type; `cn` is the display name |

## Create the bind account

No special rights needed: any domain user can read the directory. It must not expire.

```powershell
New-ADUser -Name "keycloak" `
  -SamAccountName "keycloak" `
  -UserPrincipalName "keycloak@example.corp" `
  -AccountPassword (ConvertTo-SecureString "<PASSWORD>" -AsPlainText -Force) `
  -Enabled $true -PasswordNeverExpires $true -CannotChangePassword $true `
  -Description "Read-only bind account for Keycloak"

# read back the exact DN - one wrong character breaks the bind
Get-ADUser -Identity "keycloak" -Properties DistinguishedName | Select DistinguishedName
```

Result in this repo's notation: `CN=keycloak,OU=Service Users,DC=example,DC=corp`. The directory contained OUs, so the first guess `CN=Users` was wrong.

## LDAPS: what we found

```bash
openssl s_client -connect <DC1_IP>:636 -showcerts </dev/null
openssl s_client -connect <DC2_IP>:636 -showcerts </dev/null
```

Both controllers answered (LDAPS is enabled) but **both certificates had expired in 2019** (one from the internal CA, one the public wildcard). A correct client rejects expired certificates.

### Attempt to renew — failed, root cause not found

Requesting a new *Domain Controller Authentication* certificate from the internal CA failed on the first DC:

```
The certificate request could not be submitted to the certification authority.
The RPC server is unavailable. 0x800706ba (WIN32: 1722 RPC_S_SERVER_UNAVAILABLE)
```

Requesting a new certificate does not delete the old ones, so trying was safe. Checked, none explained it:

| Check | Result |
|---|---|
| CA service and certificate validity (`certutil -CAInfo`) | valid, running |
| Templates published on the CA | Domain Controller, Domain Controller Authentication, Kerberos Authentication present |
| DNS resolution of the CA name from the DC | correct |
| TCP 135 both ways; the CA's actual RPC port | open |
| Windows Firewall on both servers | rules enabled; later turned off for the test |
| `certutil -ping` against the CA | succeeded |
| DCOM launch/activation/access permissions on the CA | Domain Controllers had full rights |
| DCOM enabled, authentication level Connect | yes |
| Clock difference | seconds |
| Network adapters on the CA | one adapter, one address |
| CertSvc events in the CA Application log | none for the failed requests |
| Enrolment run on the CA server itself (Computer template) | **succeeded** |

The last result shows the CA can issue; the fault is in the *remote enrolment path*. **Untested ideas, in order:** enrolment permission on the *Domain Controller Authentication* template for the DCs' computer accounts; client-side logs on the DC (CertificateServicesClient, CertEnroll); whether the virtualisation layer filters traffic between the two servers.

**Decision:** continue with plain LDAP so the project was not blocked; recorded as a security gap.

## Create the LDAP provider in Keycloak (UI)

Realm `CORP` → **User federation → Add LDAP provider**:

| Field | Value |
|---|---|
| UI display name | `Corp-AD` |
| Vendor | Active Directory |
| Connection URL | `ldap://<DC1_IP> ldap://<DC2_IP>` (space separated, tried in order) |
| Enable StartTLS | Off (temporary) |
| Bind type | simple |
| Bind DN | `CN=keycloak,OU=Service Users,DC=example,DC=corp` |
| Bind credentials | `<PASSWORD>` |
| Edit mode | **READ_ONLY** |
| Users DN | `OU=Staff,DC=example,DC=corp` |
| Username LDAP attribute | `sAMAccountName` (**the default `cn` must be changed**) |
| RDN LDAP attribute | `cn` |
| UUID LDAP attribute | `objectGUID` |
| User object classes | `person, organizationalPerson, user` |
| Search scope | **Subtree** (default One Level misses users in sub-OUs) |
| Pagination | On |
| Import users | On |
| Sync registrations | Off |
| Remove invalid users during searches | On |
| Kerberos integration | Off |

Click **Test connection** and **Test authentication** before saving, then **Sync all users** from the provider's action menu.

## Result

- First sync: **149 users added, 0 failed**.
- A domain account signs in at `https://sso.example.corp/realms/CORP/account` with its normal password.
- Periodic synchronisation was switched on later: a **full sync every 86,400 seconds** and a **changed-users sync every 3,600 seconds** (users are imported, *Remove invalid users during searches* is on).
- Imported users show a warning icon next to the e-mail: it only means "not verified" in Keycloak; it did not block sign-in.

## Widening the search base: users outside the staff OU

The provider first searched only `OU=Staff,DC=example,DC=corp` (see the table above). Accounts that live elsewhere are **invisible to Keycloak and cannot sign in**. The case that exposed it was the built-in domain **Administrator** account: it sits in the default `CN=Users` container, outside the OU, and searching Keycloak for it returned nothing although the account was enabled in Active Directory.

Confirm where an account lives before changing anything:

```bash
ldapsearch -x -H ldap://<DC1_IP> -D "CN=keycloak,OU=Service Users,DC=example,DC=corp" -W \
  -b "DC=example,DC=corp" "(sAMAccountName=<user>)" distinguishedName
```

There are two ways to include it. A second DN can be added to *Users DN* (recent Keycloak versions accept several DNs separated by a semicolon — **unverified** here). Or the search base can be widened to the whole domain and a filter used to keep out accounts that should not sign in:

| Field | Value |
|---|---|
| Users DN | `DC=example,DC=corp` |
| User LDAP filter | `(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))` |
| Search scope | Subtree |
| Referral | `ignore` |

The filter keeps **enabled person accounts** and leaves out computers and disabled accounts such as Guest. A search from the domain root returns referral entries; setting *Referral* to `ignore` stops Keycloak from following them. **Preview** the result with `ldapsearch` and the same filter before saving, and read the list for **service accounts** — each one becomes a possible Keycloak user. After saving, use *Action → Sync all users*. The change was reported fixed.

> **Consequence.** Enabled domain users outside the staff OU can now sign in to Keycloak too, and therefore to **every application**, including Zeppelin where they can run interpreters. This makes the restriction in the [security checklist](../security-checklist.md) more urgent. A narrower option is `(memberOf=<group DN>)` in the filter, so only one directory group is imported.

## Closing the LDAPS gap later

1. Reissue the DC certificates from the internal CA once enrolment works.
2. Import the CA root certificate into the Keycloak server's truststore.
3. Change the URL to `ldaps://<DC1_IP> ldaps://<DC2_IP>`, keep StartTLS off, set **Use Truststore SPI = Always**.
4. Re-run Test connection and Test authentication.
