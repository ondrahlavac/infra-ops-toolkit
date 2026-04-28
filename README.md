# Infrastructure Ops Toolkit

Small, auditable shell scripts and operational notes for Linux, Proxmox VE, networking, and homelab infrastructure.

## Focus Areas

- Proxmox VE administration
- Linux user and access management
- Homelab automation
- Network and service operations
- Repeatable infrastructure setup

## Scripts

| Area    | Script                           | Purpose                                             |
| ------- | -------------------------------- | --------------------------------------------------- |
| Proxmox | `create-local-pam-admins.sh`     | Create local Linux/PAM admin users on Proxmox nodes |
| Proxmox | `apply-pve-admin-permissions.sh` | Apply cluster-wide Proxmox permissions              |

## Usage

Download, inspect, then - and only then - run:

```bash
curl -fsSLO https://raw.githubusercontent.com/ondrahlavac/infra-ops-toolkit/main/proxmox/create-local-pam-admins.sh
less create-local-pam-admins.sh
chmod +x create-local-pam-admins.sh
sudo ./create-local-pam-admins.sh -u ondra,vojta -g betleministrators -p 'temporaryPassword'
```

## Engineering Principles

- Explicit parameters over hidden assumptions
- Idempotent where practical
- Safe defaults
- Human-readable Bash
- Designed for small production-like homelab and SMB environments
