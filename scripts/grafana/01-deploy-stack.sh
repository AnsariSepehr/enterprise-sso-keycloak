#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
load_env
# Phase 7 - deploy the Grafana service with Keycloak sign-in. Run on a Docker Swarm manager.
# GRAFANA_SECRET_MODE=env           the way the original build did it (verified)
# GRAFANA_SECRET_MODE=docker-secret the secret stays out of "docker service inspect" (recommended, unverified)
command -v docker >/dev/null || die "docker not found"
[ "$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null)" = active ] || die "This node is not part of an active Swarm."
mode="${GRAFANA_SECRET_MODE:-env}"
require_secret GRAFANA_OIDC_SECRET "Client secret of the Keycloak client 'grafana'"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT

case "$mode" in
  env)
    src="$REPO_ROOT/config/grafana/grafana-stack.yml.example"
    # docker stack deploy substitutes ${GRAFANA_OIDC_SECRET} from THIS shell and never reads a .env file.
    # Forgetting this gives an empty secret and "Failed to get token from provider" (problem 31).
    export GRAFANA_OIDC_SECRET ;;
  docker-secret)
    src="$REPO_ROOT/config/grafana/grafana-stack.docker-secret.yml.example"
    if docker secret inspect grafana_oidc_secret >/dev/null 2>&1; then
      warn "Docker secret grafana_oidc_secret already exists and is reused (secrets are immutable: remove it first to rotate)."
    else
      printf '%s' "$GRAFANA_OIDC_SECRET" | docker secret create grafana_oidc_secret - >/dev/null
      log "created Docker secret grafana_oidc_secret"
    fi ;;
  *) die "GRAFANA_SECRET_MODE must be env or docker-secret" ;;
esac

render "$src" "$work/stack.yml" 600 "$(id -u):$(id -g)"
log "Deploying service grafana into stack '$SWARM_STACK' (no --prune: other services of the stack are left alone)"
docker stack deploy --detach=true -c "$work/stack.yml" "$SWARM_STACK"
log "Give it a minute, then run scripts/grafana/02-verify.sh"
log "Keycloak side first: client 'grafana', group '$GRAFANA_ADMIN_GROUP', Group Membership mapper 'groups' (docs/services/grafana.md, section 1)."
