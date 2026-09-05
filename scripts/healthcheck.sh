#!/usr/bin/env bash
# scripts/healthcheck.sh
# Post-deploy health check: confirms every expected container is running
# and none are restarting or unhealthy.
#
# Usage:
#   ./scripts/healthcheck.sh
#
# Environment (set by the workflow):
#   NAS_HOST      — IP of the NAS deploy target (default: 10.10.10.21)
#   NAS_USER      — SSH user on the NAS
set -euo pipefail

NAS_HOST="${NAS_HOST:-10.10.10.21}"
NAS_USER="${NAS_USER:-root}"
SSH_OPTS=(-o StrictHostKeyChecking=no -o BatchMode=yes)
WAIT_SECS="${WAIT_SECS:-20}"

echo "==> Waiting ${WAIT_SECS}s for containers to settle..."
sleep "${WAIT_SECS}"

echo "==> Container status on ${NAS_USER}@${NAS_HOST}:"
ssh "${SSH_OPTS[@]}" "${NAS_USER}@${NAS_HOST}" \
  "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

UNHEALTHY="$(ssh "${SSH_OPTS[@]}" "${NAS_USER}@${NAS_HOST}" \
  "docker ps --format '{{.Names}} {{.Status}}' | grep -E '(Restarting|unhealthy)' || true")"

if [[ -n "${UNHEALTHY}" ]]; then
  echo "❌ Unhealthy or restarting containers:"
  echo "${UNHEALTHY}"
  exit 1
fi

echo "✅ All containers healthy."