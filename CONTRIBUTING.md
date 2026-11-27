# Contributing

1. **Never commit real values.** Copy `.forbidden-terms.example` to `.forbidden-terms`, list your real domain/hosts/users, and run `bash tests/run-tests.sh (it includes the secret scan)` before every commit.
2. Install the pre-commit hook:
   ```bash
   printf '#!/bin/sh\nbash tests/run-tests.sh (it includes the secret scan)\n' > .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
   ```
3. Use only the placeholders from [docs/prerequisites.md](docs/prerequisites.md#masking-conventions).
4. Mark anything unverified as **unverified**.
5. Add each bug to `docs/troubleshooting.md` and each workaround/shortcut to `docs/post-install-changes.md`.
6. New service? Follow [docs/adding-a-service.md](docs/adding-a-service.md).
7. Scripts: `set -euo pipefail`, source `scripts/lib/common.sh`, idempotent where possible, no secrets on the command line.

## Tests and documentation rules
- Scripts: ShellCheck (`-S warning`) must be clean. A script or tool that **edits a file** gets a fixture and a test in `tests/` (see `xml_props.py` and the Nextcloud patch): it must refuse when its anchor does not match exactly once, and a second run must change nothing.
- Docs: relative links and `#anchors` must resolve (`python3 scripts/tools/check-links.py`); service pages follow `docs/services/_TEMPLATE.md`; diagrams go in `docs/img/`.
- Run `bash tests/run-tests.sh` before every commit.
