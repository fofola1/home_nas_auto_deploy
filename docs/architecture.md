# Architecture

## Topology

Two machines on the same LAN subnet (`10.10.10.0/24`):

```
┌────────────────────────────────────────────────────────────┐
│                        LAN 10.10.10.0/24                    │
│                                                            │
│   ┌────────────────────────┐          ┌─────────────────┐   │
│   │  homelab  (10.10.10.20) │          │  nas (10.10.10.21)│   │
│   │                        │          │                 │   │
│   │  • GitHub Actions       │  SSH/rsync │  • Docker Engine │   │
│   │    self-hosted runner   │──────────▶│    + Compose    │   │
│   │  • docker compose host  │          │  • storage pools│   │
│   └────────────────────────┘          └─────────────────┘   │
└────────────────────────────────────────────────────────────┘
                 │
                 │ HTTPS
                 ▼
            github.com / fofola1/home_nas_auto_deploy
```

- **homelab** — the "control plane". It runs the GitHub Actions self-hosted
  runner, so workflow jobs execute on the same LAN as the NAS. No public
  ingress is needed for deployment.
- **nas** — the "data plane". It hosts all deployed services as Docker Compose
  stacks. It is never exposed to the internet directly; management traffic
  originates from homelab.

The NAS IP is deliberately fixed: `10.10.10.21` (= runner host IP + 1). All
secrets and inventory entries refer to it, keeping the pipeline simple.

## Deploy flow

```
push to main
     │
     ▼
┌──────────┐   ┌───────────┐   ┌─────────┐   ┌──────────┐   ┌────────┐
│ ci.yml   │──▶│ deploy.yml │──▶│ rsync   │──▶│ compose  │──▶│ verify │
│ lint ... │   │ (job run)  │   │  stacks │   │ up -d    │   │ health │
└──────────┘   └───────────┘   └─────────┘   └─────────┘   └────────┘
                                     │ SSH         │ SSH
                                     ▼             ▼
                                   homelab       nas
```

1. `ci.yml` runs first: YAML lint, `docker compose config` for every stack,
   `ansible-playbook --syntax-check`.
2. `deploy.yml` runs on the self-hosted runner:
   - `deploy` job syncs `docker/<stack>/` to `/opt/stacks/<stack>/` on the NAS
     and runs `docker compose up -d`.
   - `verify` job waits for containers to be healthy.
   - `notify` job sends an Ntfy push with the outcome.
3. Both workflows are idempotent — re-running with no changes is a no-op.

## Configuration flow

- **Runner host config** (`ansible/playbooks/runner.yml`) rarely changes; it is
  mostly here to document and reapply the runner service if the machine is
  rebuilt.
- **NAS provisioning** (`ansible/playbooks/nas.yml`) installs Docker, creates
  storage directories and mounts, and seeds a baseline stack directory
  structure. It is idempotent.
- **Per-stack config** lives in `docker/<stack>/docker-compose.yml` with
  environment exposed via `.env` files, committed as `.env.example` only.

## Why a self-hosted runner?

- The runner already lives on homelab, so deployment reaches the NAS over the
  LAN with no port forwarding.
- SSH keys stay on the runner / in GitHub Secrets; nothing is exposed to the
  public internet.
- Cost: zero CI minutes for an always-on home machine.