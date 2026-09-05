# Variables Reference

Every configurable value in the repository. Secrets stay in GitHub Actions;
everything else is versioned.

## GitHub Actions Secrets

| Secret | Used by | Purpose |
|---|---|---|
| `SSH_PRIVATE_KEY` | `deploy.yml` | Ed25519 private key for runner → NAS (rsync, ssh) |
| `SSH_PUBLIC_KEY` | `ansible` / docs | Corresponding public key, added to NAS `authorized_keys` |
| `NTFY_URL` | `deploy.yml` | Ntfy topic URL for deployment notifications (optional) |

## GitHub Actions Variables

| Variable | Default | Used by | Purpose |
|---|---|---|---|
| `RUNNER_HOST` | `10.10.10.20` | `deploy.yml` | IP of the machine running the runner (homelab) |
| `NAS_HOST` | `10.10.10.21` | `deploy.yml` | IP of the deploy target (NAS = runner IP + 1) |
| `NAS_USER` | `root` | `deploy.yml` | SSH user on the NAS |

## Ansible

Defined in `ansible/inventory/hosts.yml`:

| Variable | Value | Purpose |
|---|---|---|
| `ansible_user` | `root` | SSH/Ansible user for both hosts |
| `nas_host` | `10.10.10.21` | NAS management IP |
| `runner_host` | `10.10.10.20` | homelab management IP |
| `storage_paths` | see below | Directories created on the NAS |

Default NAS storage paths (`ansible/group_vars/nas.yml`):

```yaml
storage_paths:
  - { path: /opt/stacks,     mode: "0755" }
  - { path: /srv/media,      mode: "0755" }
  - { path: /srv/photos,     mode: "0750" }
  - { path: /srv/backups,    mode: "0750" }
  - { path: /srv/monitoring, mode: "0755" }
```

## Docker Compose stacks

Each stack under `docker/<stack>/` reads a `.env` file. Commit only
`.env.example`. Variables used by the stacks:

| Stack | Variable | Example |
|---|---|---|
| `media` | `TZ` | `Europe/Prague` |
| `media` | `PUID` / `PGID` | `1000` / `1000` |
| `media` | `MEDIA_ROOT` | `/srv/media` |
| `backup` | `BACKUP_ROOT` | `/srv/backups` |
| `backup` | `BORG_REPO` | `ssh://borg@nas/./repo` |
| `photos` | `PHOTOS_ROOT` | `/srv/photos` |
| `photos` | `UPLOAD_LOCATION` | `/srv/photos/immich` |
| `photos` | `DB_PASSWORD` | immich database password |
| `monitoring` | `PROMETHEUS_RETENTION` | `30d` |