# 🏠 Home NAS Auto Deploy

GitOps-based automatic deployment for a home NAS, run from a self-hosted
GitHub Actions runner on the main server.

```
 git push
    │
    ▼
 ┌──────────────────────────┐
 │  GitHub Actions           │
 │  (self-hosted runner)     │
 │  runs on: homelab         │
 │  10.10.10.20              │
 └────────────┬─────────────┘
              │ SSH / rsync
              ▼
 ┌──────────────────────────┐
 │  NAS (deploy target)      │
 │  10.10.10.21              │
 │  Docker Compose stacks    │
 └──────────────────────────┘
```

## What this repository does

The main server (`homelab`, the same machine that hosts the GitHub Actions
runner) deploys containerised services to the NAS over the local network.
Every push to `main` triggers a pipeline that:

1. **Validates** — Docker Compose configs, Ansible playbooks, shell lint.
2. **Deploys** — syncs compose stacks to the NAS and rolls out containers.
3. **Verifies** — checks that all containers come up healthy.
4. **Notifies** — pushes a status notification on completion.

## Repository structure

```
.
├── .github/
│   └── workflows/
│       ├── ci.yml            # Validation pipeline (lint + syntax checks)
│       └── deploy.yml        # Deploy pipeline (runner → NAS via SSH)
├── ansible/
│   ├── ansible.cfg
│   ├── requirements.yml      # Galaxy collection pins
│   ├── inventory/
│   │   └── hosts.yml         # homelab (runner) + nas (target)
│   └── playbooks/
│       ├── site.yml          # Master playbook
│       ├── ras.yml           # NAS provisioning
│       └── runner.yml        # Runner maintenance (rarely used here)
├── docker/
│   ├── media/                # Jellyfin + the *arr stack
│   ├── backup/               # Borgmatic backups
│   └── monitoring/           # Grafana, Prometheus, node-exporter, kuma
├── scripts/
│   ├── deploy.sh             # rsync + compose rollout (used by deploy.yml)
│   └── healthcheck.sh        # post-deploy container health check
├── docs/
│   ├── setup-guide.md         # Full setup walkthrough
│   ├── variables.md           # All secrets / variables reference
│   └── architecture.md        # Topology and pipeline details
└── .gitignore
```

## Quick start

See [`docs/setup-guide.md`](./docs/setup-guide.md) for the full walkthrough.
In short:

1. Install the runner on `homelab` (10.10.10.20).
2. Add the required [secrets and variables](./docs/variables.md) to the repo.
3. Make sure the NAS (10.10.10.21) is reachable over SSH.
4. Push to `main` — the pipeline runs `ci.yml` then `deploy.yml`.

## Pipeline at a glance

| Workflow | Trigger | Jobs |
|---|---|---|
| `ci.yml`   | push / PR | `lint`, `compose-config`, `ansible-check` |
| `deploy.yml` | push to `main`, `workflow_dispatch` | `deploy`, `verify`, `notify` |

Both workflows run on the self-hosted runner so the NAS is reached over the
LAN without exposing any service to the internet.