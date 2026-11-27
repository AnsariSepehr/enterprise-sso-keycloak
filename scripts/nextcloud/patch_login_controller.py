#!/usr/bin/env python3
"""Add (or check, or remove) the one-line uppercase patch in user_oidc's LoginController.php.

Why: Nextcloud's LDAP accounts use the AD objectGUID, in UPPER case, as the user ID. Keycloak's
ldap_id claim carries the same GUID in lower case and Nextcloud's lookup is case-sensitive, so every
sign-in ends in "Failed to provision the user". The patch upper-cases the ID right after it is read.

The edit refuses to guess: the anchor line must exist exactly once, otherwise nothing is changed.
An update of the user_oidc app replaces the file and removes the patch: run this again afterwards.

usage: patch_login_controller.py FILE [--check | --revert]
exit codes: 0 patched / reverted / check passed   3 already in that state   2 anchor not found exactly once
"""
import os
import re
import shutil
import sys

MARK = "// enterprise-sso-keycloak: uppercase-uid"
ANCHOR = re.compile(
    r"^(?P<ind>[ \t]*)\$userId = \$this->provisioningService->getClaimValue\(\$idTokenPayload, \$uidAttribute, \$providerId\);[ \t]*$",
    re.M)
PATCH = "{ind}" + MARK + "\n{ind}if ($userId !== null) {{ $userId = strtoupper($userId); }}\n"


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = [a for a in sys.argv[1:] if a.startswith("--")]
    if len(args) != 1 or any(f not in ("--check", "--revert") for f in flags):
        sys.exit(__doc__)
    path = args[0]
    text = open(path, encoding="utf-8").read()
    applied = MARK in text or "strtoupper($userId)" in text

    if "--check" in flags:
        print("patched" if applied else "NOT patched")
        sys.exit(0 if applied else 3)

    if "--revert" in flags:
        if MARK not in text:
            print("nothing to revert (no marker found)")
            sys.exit(3)
        new = re.sub(r"^[ \t]*" + re.escape(MARK) + r"\n[ \t]*if \(\$userId !== null\) \{ \$userId = strtoupper\(\$userId\); \}\n", "", text, flags=re.M)
        open(path, "w", encoding="utf-8").write(new)
        print("patch removed")
        sys.exit(0)

    if applied:
        print("already patched")
        sys.exit(3)
    found = list(ANCHOR.finditer(text))
    if len(found) != 1:
        print(f"anchor line found {len(found)} times (expected exactly 1): this user_oidc version needs a manual look", file=sys.stderr)
        sys.exit(2)
    m = found[0]
    if not os.path.exists(path + ".orig"):
        shutil.copy2(path, path + ".orig")      # keep the pristine file next to the patched one
    new = text[:m.end()] + "\n" + PATCH.format(ind=m.group("ind")).rstrip("\n") + text[m.end():]
    open(path, "w", encoding="utf-8").write(new)
    print("patched")


if __name__ == "__main__":
    main()
