# Setup Guide

One-time initialization of the **Home NAS Auto Deploy** pipeline.

## Prerequisites

| Item | Notes |
|---|---|
| GitHub repo | This repository, under your profile |
| Self-hosted runner | Installed on **homelab** (10.10.10.20) |
| NAS | Reached over SSH as `root@10.10.10.21`, Docker not yet required |
| SSH keys | A dedicated keypair for runner → NAS |
| Ntfy topic | Optional, for push notifications |

## 1. Install the runner on homelab

Skip if the runner already exists on the machine this repo is deployed from.

```bash
mkdir -p ~/actions-runner && cd ~/actions-runner
# Download the runner package for x64 Linux from GitHub → Settings → Actions → Runners
curl -o actions-runner.tar.gz -L <RUNNER_DOWNLOAD_URL>
tar xzf actions-runner.tar.gz
./config.sh --url https://github.com/fofola1/home_nas_auto_deploy \
            --token <RUNNER_TOKEN>
sudo ./svc.sh install && sudo ./svc.sh start
```

Verify with:

```bash
systemctl status actions.runner.* --no-pager
```

The runner is only usable if it is **online** — workflows run on it, not on
GitHub-hosted machines.

## 2. Create the runner → NAS SSH keypair

Both the workflow and the instances run on homelab, but Ansible and the deploy
script authenticate to the NAS separately. Use a dedicated keypair:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/nas_deploy -C "github-actions@homelab" -N ""
ssh-copy-id -i ~/.ssh/nas_deploy.pub root@10.10.10.21
```

> The NAS must be powered on for `ssh-copy-id` to work. If the NAS is off,
> add the public key to `~/.ssh/authorized_keys` on the NAS manually once it
> is reachable.

## 3. Add GitHub Secrets

Go to **Settings → Secrets and variables → Actions** and add:

| Secret | Value |
|---|---|
| `SSH_PRIVATE_KEY` | Contents of `~/.ssh/nas_deploy` |
| `SSH_PUBLIC_KEY` | Contents of `~/.ssh/nas_deploy.pub` |
| `NTFY_URL` | e.g. `https://ntfy.sh/my-homelab-topic` (optional) |

## 4. Add GitHub Variables

| Variable | Value |
|---|---|
| `RUNNER_HOST` | `10.10.10.20` |
| `NAS_HOST` | `10.10.10.21` |
| `NAS_USER` | `root` |

## 5. Configure the NAS storage layout

`ansible/playbooks/nas.yml` mounts the storage directories used by the stacks:

| Path on NAS | Purpose |
|---|---|
| `/opt/stacks` | Docker Compose files (managed by this repo) |
| `/srv/media` | Movies, TV, music for the *arr / Jellyfin stack |
| `/srv/photos` | Immich library and database |
| `/srv/backups` | Borgmatic backup repository target |
| `/srv/monitoring` | Prometheus / Grafana persistent data |

Adjust `ansible/inventory/hosts.yml` if your layout differs, then run the
pipeline — the `validate` job checks everything before anything changes.

## 6. First deploy

Push to `main` (or run the **Deploy** workflow manually from the Actions tab).

Expected result:

```
ci.yml       ✅ validate (lint, compose config, ansible syntax)
deploy.yml   ✅ deploy → verify → notify
```

Confirm containers on the NAS:

```bash
ssh root@10.10.10.21 "docker ps --format 'table {{.Names}}\t{{.Status}}'"
```

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| Workflow never starts | Runner offline — check it on homelab |
| `Permission denied (publickey)` | `SSH_PRIVATE_KEY` wrong or NAS `authorized_keys` missing |
| Job stuck at `rsync` | NAS unreachable / off — `ping 10.10.10.21` |
| Notification missing | `NTFY_URL` unset or topic wrong (non-fatal) |