#!/usr/bin/env bash
# scripts/deploy.sh
# Sync docker stacks from this repo to the NAS and roll out containers.
# Used by .github/workflows/deploy.yml (self-hosted runner → NAS).
#
# Usage:
#   ./scripts/deploy.sh [stack...]        # deploy only listed stacks
#   ./scripts/deploy.sh                   # deploy all stacks
#
# Environment (set by the workflow):
#   NAS_HOST      — IP of the NAS deploy target (default: 10.10.10.21)
#   NAS_USER      — SSH user on the NAS
set -euo pipefail

STACKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../docker" && pwd)"
NAS_HOST="${NAS_HOST:-10.10.10.21}"
NAS_USER="${NAS_USER:-root}"
SSH_OPTS=(-o StrictHostKeyChecking=no -o BatchMode=yes)

AVAILABLE_STACKS=(
  media
  backup
  monitoring
)

# Stacks requested via CLI args, or all of them.
if [ "$#" -gt 0 ]; then
  STACKS=("$@")
else
  STACKS=("${AVAILABLE_STACKS[@]}")
fi

for stack in "${STACKS[@]}"; do
  src="${STACKS_DIR}/${stack}"
  if [ ! -d "${src}" ]; then
    echo "ERROR: unknown stack '${stack}' (no ${src})"
    exit 1
  fi

  echo "==> Syncing stack '${stack}' → nas:/opt/stacks/${stack}"
  rsync -avz --delete \
    --exclude='.env' \
    --exclude='*.secret' \
    -e "ssh ${SSH_OPTS[*]}" \
    "${src}/" \
    "${NAS_USER}@${NAS_HOST}:/opt/stacks/${stack}/"

  echo "==> Rolling out '${stack}' on the NAS"
  ssh "${SSH_OPTS[@]}" "${NAS_USER}@${NAS_HOST}" \
    "cd /opt/stacks/${stack} && docker compose pull --quiet && docker compose up -d --remove-orphans"

  echo "✅ ${stack} deployed"
done

echo "All stacks deployed to ${NAS_USER}@${NAS_HOST}."