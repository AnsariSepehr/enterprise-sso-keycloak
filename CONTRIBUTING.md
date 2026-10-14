# Contributing

1. **Never commit real values.** Copy `.forbidden-terms.example` to `.forbidden-terms`, list your real domain/hosts/users, and run `bash scripts/tools/check-secrets.sh` before every commit.
2. Install the pre-commit hook:
   ```bash
   printf '#!/bin/sh\nbash scripts/tools/check-secrets.sh\n' > .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
   ```
3. Use only the placeholders from [docs/prerequisites.md](docs/prerequisites.md#masking-conventions).
4. Mark anything unverified as **unverified**.
5. Add each bug to `docs/troubleshooting.md` and each workaround/shortcut to `docs/post-install-changes.md`.
6. New service? Follow [docs/adding-a-service.md](docs/adding-a-service.md).
7. Scripts: `set -euo pipefail`, source `scripts/lib/common.sh`, idempotent where possible, no secrets on the command line.
