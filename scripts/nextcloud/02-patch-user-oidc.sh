#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
load_env
# Phase 8 - upper-case the user ID in user_oidc. RE-RUN THIS AFTER EVERY UPDATE OF THE user_oidc APP:
# an update replaces the file and removes the patch. docs/services/nextcloud.md, "The case problem".
command -v docker >/dev/null || die "docker not found"
c="${NEXTCLOUD_CONTAINER:-app}"
file="${LOGIN_CONTROLLER_PATH:-/var/www/html/custom_apps/user_oidc/lib/Controller/LoginController.php}"
backup_dir="${PATCH_BACKUP_DIR:-$HOME}"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT

docker cp "$c:$file" "$work/LoginController.php"
set +e
python3 "$REPO_ROOT/scripts/nextcloud/patch_login_controller.py" "$work/LoginController.php"
rc=$?
set -e
case "$rc" in
  0) ;;
  3) log "nothing to do"; exit 0 ;;
  *) die "the patch was NOT applied (exit $rc). Nothing in the container was changed." ;;
esac

# Never put a PHP file with a syntax error into a running Nextcloud.
if command -v php >/dev/null; then php -l "$work/LoginController.php" >/dev/null || die "patched file fails php -l"; fi
cp -n "$work/LoginController.php.orig" "$backup_dir/LoginController.php.orig" && log "pristine copy kept in $backup_dir/LoginController.php.orig" || true
docker cp "$work/LoginController.php" "$c:$file"
docker exec -u root "$c" chown www-data:www-data "$file"
docker exec -u www-data "$c" php -l "$file" | grep -q 'No syntax errors' || die "php -l fails inside the container: restore with  docker cp $backup_dir/LoginController.php.orig $c:$file"
log "patched. Sign in once as an existing user; the account must be the existing one (files present), not a new empty one."
